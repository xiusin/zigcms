# ZigCMS MVC 架构与职责划分

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                         main.zig                             │
│  职责：程序入口，内存分配器初始化，应用生命周期管理          │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    Application.zig                           │
│  职责：应用初始化，配置加载，系统启动，路由注册              │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
┌────────▼────────┐ ┌───▼────────┐ ┌───▼──────────┐
│   Bootstrap     │ │    App     │ │  AppContext  │
│  路由注册       │ │  HTTP服务  │ │  全局上下文  │
└─────────────────┘ └────────────┘ └──────────────┘
```

## 目录结构与职责

### 1. 根目录文件

#### main.zig
**职责**：
- 创建 GPA 分配器（线程安全 + 泄漏检测）
- 创建 Application 实例
- 启动应用
- 程序退出时检查内存泄漏

**原则**：
- ✅ 只包含程序入口逻辑
- ✅ 不包含业务逻辑
- ✅ 不包含配置加载
- ✅ 不包含路由注册

**代码示例**：
```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            std.debug.print("⚠️ 检测到内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var app = try Application.create(allocator);
    defer app.destroy();

    try app.run();
}
```

#### root.zig
**职责**：
- 导出所有模块（api, application, domain, infrastructure, core）
- 提供系统初始化/清理函数（initSystem, deinitSystem）
- 管理全局资源（数据库连接、服务管理器）
- 注册应用服务到 DI 容器

**原则**：
- ✅ 作为模块聚合点
- ✅ 管理全局生命周期
- ✅ 不包含业务逻辑

### 2. src/ 目录结构

```
src/
├── api/                    # 接口层（HTTP 入口）
│   ├── Application.zig     # 应用初始化
│   ├── App.zig             # HTTP 服务器
│   ├── bootstrap.zig       # 路由注册
│   ├── controllers/        # 控制器
│   ├── dto/                # 数据传输对象
│   └── middleware/         # 中间件
│
├── application/            # 应用层（业务编排）
│   ├── services/           # 应用服务
│   │   ├── sql/            # ORM/QueryBuilder
│   │   ├── cache/          # 缓存服务
│   │   ├── logger/         # 日志服务
│   │   ├── redis/          # Redis 服务
│   │   └── ...
│   └── use_cases/          # 用例（可选）
│
├── domain/                 # 领域层（业务规则）
│   ├── entities/           # 实体模型
│   ├── repositories/       # 仓储接口
│   └── services/           # 领域服务
│
├── infrastructure/         # 基础设施层（技术实现）
│   ├── database/           # 数据库实现
│   ├── cache/              # 缓存实现
│   └── external/           # 外部服务
│
├── core/                   # 核心层（通用能力）
│   ├── di/                 # 依赖注入
│   ├── config/             # 配置管理
│   ├── context/            # 上下文
│   ├── errors/             # 错误定义
│   └── utils/              # 工具函数
│
└── plugins/                # 插件层
    ├── plugin_manager.zig  # 插件管理器
    └── plugin_registry.zig # 插件注册表
```

### 3. 各层职责详解

#### 3.1 API 层（src/api/）

**Application.zig**
```zig
pub const Application = struct {
    allocator: std.mem.Allocator,
    config: SystemConfig,
    app: App,
    bootstrap: Bootstrap,
    global_logger: *logger.Logger,
    app_context: ?*AppContext,

    // 创建应用实例
    pub fn create(allocator: std.mem.Allocator) !*Self

    // 销毁应用实例
    pub fn destroy(self: *Self) void

    // 运行应用
    pub fn run(self: *Self) !void
};
```

**职责**：
- 加载配置（loadSystemConfig）
- 初始化系统（initSystem）
- 初始化日志（initDefault）
- 创建 HTTP 服务器（App.init）
- 创建应用上下文（AppContext.init）
- 注册路由（Bootstrap.registerRoutes）
- 启动服务器（app.listen）

**App.zig**
```zig
pub const App = struct {
    allocator: std.mem.Allocator,
    listener: zap.HttpListener,

    pub fn init(allocator: std.mem.Allocator) !App
    pub fn deinit(self: *App) void
    pub fn listen(self: *App) !void
};
```

**职责**：
- 封装 HTTP 服务器（zap）
- 处理请求监听
- 管理服务器生命周期

**bootstrap.zig**
```zig
pub const Bootstrap = struct {
    allocator: std.mem.Allocator,
    app: *App,
    logger: *logger.Logger,
    container: *DIContainer,
    app_context: *AppContext,

    pub fn init(...) !Bootstrap
    pub fn registerRoutes(self: *Self) !void
    pub fn printStartupSummary(self: *const Self) void
};
```

**职责**：
- 注册所有路由
- 注册中间件
- 打印启动信息

**controllers/**
```zig
pub fn list(req: zap.Request) !void {
    // 1. 参数解析
    const page = req.getParamInt("page") orelse 1;

    // 2. 调用 ORM
    var q = OrmModel.Query();
    defer q.deinit();
    _ = q.where("status", "=", 1).limit(20);
    const items = try q.get();
    defer OrmModel.freeModels(items);

    // 3. 返回响应
    try base.send_success(req, items);
}
```

**职责**：
- 解析请求参数
- 调用应用服务/ORM
- 返回响应
- **不包含**业务逻辑

#### 3.2 Application 层（src/application/）

**services/**
```zig
pub const UserService = struct {
    allocator: std.mem.Allocator,
    repository: UserRepository,

    pub fn init(allocator: std.mem.Allocator, repository: UserRepository) UserService
    pub fn createUser(self: *Self, dto: CreateUserDto) !User
    pub fn updateUser(self: *Self, id: i32, dto: UpdateUserDto) !void
    pub fn deleteUser(self: *Self, id: i32) !void
};
```

**职责**：
- 业务流程编排
- 调用多个仓储
- 事务管理
- 业务规则验证

**sql/orm.zig**
```zig
pub fn defineWithConfig(comptime Model: type, config: OrmConfig) type {
    return struct {
        pub fn Query() QueryBuilder(Model)
        pub fn Where(field: []const u8, op: WhereOp, value: anytype) QueryBuilder(Model)
        pub fn Find(id: anytype) !?Model
        pub fn Create(data: Model) !Model
        pub fn Update(id: anytype, data: Model) !void
        pub fn Delete(id: anytype) !void
        pub fn freeModels(models: []Model) void
    };
}
```

**职责**：
- 提供 Laravel 风格的 ORM API
- 参数化查询（SQL 注入防护）
- 内存管理（freeModels, getWithArena）
- 支持链式调用

#### 3.3 Domain 层（src/domain/）

**entities/**
```zig
pub const User = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    email: []const u8 = "",
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    // 业务方法
    pub fn isActive(self: *const User) bool {
        return self.status == 1;
    }
};
```

**职责**：
- 定义实体结构
- 包含业务规则方法
- 不依赖基础设施

**repositories/**
```zig
pub const UserRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?User,
        save: *const fn (*anyopaque, User) anyerror!void,
        delete: *const fn (*anyopaque, i32) anyerror!void,
    };

    pub fn findById(self: *Self, id: i32) !?User {
        return self.vtable.findById(self.ptr, id);
    }
};
```

**职责**：
- 定义仓储接口
- 不包含实现细节

#### 3.4 Infrastructure 层（src/infrastructure/）

**database/**
```zig
pub const SqliteUserRepository = struct {
    allocator: std.mem.Allocator,
    db: *Database,

    pub fn init(allocator: std.mem.Allocator, db: *Database) SqliteUserRepository
    pub fn findById(self: *Self, id: i32) !?User
    pub fn save(self: *Self, user: User) !void
    pub fn delete(self: *Self, id: i32) !void

    pub fn vtable() UserRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .save = saveImpl,
            .delete = deleteImpl,
        };
    }
};
```

**职责**：
- 实现仓储接口
- 使用 ORM 访问数据库
- 处理数据转换

#### 3.5 Core 层（src/core/）

**di/container.zig**
```zig
pub const DIContainer = struct {
    arena: std.heap.ArenaAllocator,
    services: std.StringHashMap(ServiceEntry),

    pub fn init(allocator: std.mem.Allocator) !*DIContainer
    pub fn deinit(self: *DIContainer) void
    pub fn registerSingleton(...) !void
    pub fn registerTransient(...) !void
    pub fn registerInstance(...) !void
    pub fn resolve(comptime T: type) !*T
};
```

**职责**：
- 服务注册
- 依赖解析
- 生命周期管理（Arena 托管）

**config/system_config.zig**
```zig
pub const SystemConfig = struct {
    api: ApiConfig,
    app: AppConfig,
    infra: InfraConfig,
    domain: DomainConfig,
    shared: SharedConfig,
};
```

**职责**：
- 定义配置结构
- 提供配置加载函数

### 4. 命令行工具（cmd/）

```
cmd/
├── codegen/            # 代码生成器
│   └── main.zig
├── migrate/            # 数据库迁移
│   └── main.zig
└── plugingen/          # 插件生成器
    └── main.zig
```

**职责**：
- 提供开发工具
- 独立于主程序
- 通过 `zig build <command>` 调用

### 5. 数据流向

```
┌─────────────┐
│   HTTP 请求  │
└──────┬──────┘
       │
┌──────▼──────────────────────────────────────────┐
│  Controller (api/)                               │
│  - 解析参数                                      │
│  - 调用 Service/ORM                              │
│  - 返回响应                                      │
└──────┬──────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────┐
│  Service (application/)                          │
│  - 业务流程编排                                  │
│  - 调用 Repository                               │
│  - 事务管理                                      │
└──────┬──────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────┐
│  Repository (domain/ + infrastructure/)          │
│  - 接口定义（domain）                            │
│  - 实现（infrastructure）                        │
│  - 使用 ORM                                      │
└──────┬──────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────┐
│  ORM/QueryBuilder (application/services/sql/)    │
│  - 构建 SQL                                      │
│  - 参数化查询                                    │
│  - 执行查询                                      │
└──────┬──────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────┐
│  Database Driver (infrastructure/)               │
│  - MySQL/SQLite/PostgreSQL                       │
│  - 执行 SQL                                      │
│  - 返回结果                                      │
└─────────────────────────────────────────────────┘
```

### 6. 依赖关系

```
┌─────────────────────────────────────────────────┐
│                    main.zig                      │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│                 Application                      │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
┌────────▼────┐ ┌───▼────┐ ┌───▼──────┐
│     API     │ │  App   │ │  Core    │
└────────┬────┘ └────────┘ └───┬──────┘
         │                      │
┌────────▼────────────────┐    │
│     Application         │◄───┘
└────────┬────────────────┘
         │
┌────────▼────────────────┐
│       Domain            │
└────────┬────────────────┘
         │
┌────────▼────────────────┐
│    Infrastructure       │
└─────────────────────────┘
```

**依赖原则**：
- ✅ 高层不依赖低层（依赖倒置）
- ✅ 依赖抽象不依赖实现
- ✅ 核心层被所有层依赖
- ✅ 领域层不依赖基础设施

### 7. 最佳实践

#### 7.1 控制器

```zig
// ✅ 推荐：简洁的控制器
pub fn list(req: zap.Request) !void {
    const page = req.getParamInt("page") orelse 1;

    var q = OrmModel.Query();
    defer q.deinit();
    _ = q.where("status", "=", 1).limit(20);
    const items = try q.get();
    defer OrmModel.freeModels(items);

    try base.send_success(req, items);
}

// ❌ 避免：包含业务逻辑的控制器
pub fn list(req: zap.Request) !void {
    // 复杂的业务规则
    // 多个数据库操作
    // 事务管理
    // ...
}
```

#### 7.2 服务

```zig
// ✅ 推荐：编排多个仓储
pub fn createOrder(self: *Self, dto: CreateOrderDto) !Order {
    // 1. 验证用户
    const user = try self.user_repo.findById(dto.user_id) orelse return error.UserNotFound;

    // 2. 验证库存
    const product = try self.product_repo.findById(dto.product_id) orelse return error.ProductNotFound;
    if (product.stock < dto.quantity) return error.InsufficientStock;

    // 3. 创建订单
    const order = try self.order_repo.create(dto);

    // 4. 扣减库存
    try self.product_repo.decreaseStock(dto.product_id, dto.quantity);

    return order;
}
```

#### 7.3 ORM

```zig
// ✅ 推荐：链式调用 + defer 清理
var q = OrmUser.Query();
defer q.deinit();

_ = q.where("age", ">", 18)
     .where("status", "=", 1)
     .whereIn("role_id", &[_]i32{1, 2, 3})
     .orderBy("created_at", .desc)
     .limit(20);

const users = try q.get();
defer OrmUser.freeModels(users);

// ✅ 推荐：使用 Arena 简化内存管理
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

var result = try q.getWithArena(arena.allocator());
// 无需手动释放
```

### 8. 总结

#### 8.1 架构优点

1. **职责清晰**：每层有明确的职责边界
2. **依赖倒置**：高层不依赖低层实现
3. **易于测试**：接口抽象便于 Mock
4. **易于扩展**：新增功能不影响现有代码
5. **内存安全**：Arena + defer 模式零泄漏

#### 8.2 代码规范

| 层级 | 职责 | 禁止 |
|------|------|------|
| **main.zig** | 程序入口 | 业务逻辑、配置加载 |
| **Application.zig** | 应用初始化 | 业务逻辑、路由处理 |
| **Controller** | 参数解析、响应返回 | 业务逻辑、直接 SQL |
| **Service** | 业务编排 | 直接 SQL、HTTP 细节 |
| **Repository** | 数据访问 | 业务规则 |
| **Domain** | 业务规则 | 基础设施依赖 |

#### 8.3 开发流程

1. **新增功能**：
   - 定义实体（domain/entities）
   - 定义仓储接口（domain/repositories）
   - 实现仓储（infrastructure/database）
   - 创建服务（application/services）
   - 创建控制器（api/controllers）
   - 注册路由（api/bootstrap.zig）

2. **修改功能**：
   - 修改实体（domain/entities）
   - 修改仓储接口（domain/repositories）
   - 修改仓储实现（infrastructure/database）
   - 修改服务（application/services）
   - 修改控制器（api/controllers）

3. **删除功能**：
   - 删除路由（api/bootstrap.zig）
   - 删除控制器（api/controllers）
   - 删除服务（application/services）
   - 删除仓储实现（infrastructure/database）
   - 删除仓储接口（domain/repositories）
   - 删除实体（domain/entities）

**ZigCMS 采用整洁架构，职责清晰，易于维护和扩展！**
