# ZigCMS 项目结构规范

## 目录结构

```
zigcms/
├── api/                    # API 层 - HTTP 接口
│   ├── controllers/        # 控制器
│   │   ├── admin/         # 管理员控制器
│   │   ├── auth/          # 认证控制器
│   │   ├── common/        # 通用控制器（CRUD）
│   │   └── dict/          # 字典控制器
│   ├── dto/               # 数据传输对象
│   ├── middleware/        # 中间件
│   ├── Api.zig           # API 层入口
│   └── App.zig           # 应用框架
│
├── application/           # 应用层 - 业务逻辑
│   ├── services/         # 应用服务
│   │   ├── ai/          # AI 服务
│   │   ├── cache/       # 缓存服务
│   │   ├── events/      # 事件系统
│   │   ├── http/        # HTTP 客户端
│   │   ├── logger/      # 日志服务
│   │   ├── plugins/     # 插件系统
│   │   ├── redis/       # Redis 客户端
│   │   └── sql/         # ORM 和数据库
│   └── mod.zig          # 应用层入口
│
├── domain/               # 领域层 - 核心业务
│   ├── entities/        # 实体模型
│   │   ├── models.zig   # 数据模型定义
│   │   └── orm_models.zig # ORM 模型注册
│   └── mod.zig          # 领域层入口
│
├── infrastructure/       # 基础设施层 - 外部集成
│   └── mod.zig          # 基础设施层入口
│
├── shared/              # 共享层 - 跨层组件
│   ├── primitives/      # 基础原语
│   │   └── global.zig   # 全局资源管理
│   ├── utils/           # 工具函数
│   └── mod.zig          # 共享层入口
│
├── resources/           # 静态资源
│   ├── page/           # 前端页面
│   └── js/             # JavaScript 文件
│
├── docs/               # 文档
│   ├── MEMORY_SAFETY.md      # 内存安全指南
│   ├── PROJECT_STRUCTURE.md  # 项目结构说明
│   └── API.md               # API 文档
│
├── build.zig           # 构建配置
├── main.zig            # 程序入口
└── root.zig            # 根模块

```

## 分层架构

### 1. API 层 (api/)

**职责**：
- 处理 HTTP 请求和响应
- 路由管理
- 请求验证
- 响应格式化

**规范**：
- 控制器只负责请求处理，不包含业务逻辑
- 使用 DTO 进行数据传输
- 统一的错误处理和响应格式

**示例**：
```zig
// api/controllers/user/user.controller.zig
pub const User = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) User {
        return .{ .allocator = allocator };
    }
    
    pub fn list(self: *User, req: *zap.Request) !void {
        // 1. 验证请求
        // 2. 调用应用层服务
        // 3. 格式化响应
    }
};
```

### 2. 应用层 (application/)

**职责**：
- 实现业务用例
- 协调领域对象
- 事务管理
- 应用服务

**规范**：
- 服务类命名：`XxxService`
- 每个服务负责一个业务领域
- 使用依赖注入

**示例**：
```zig
// application/services/user/user_service.zig
pub const UserService = struct {
    allocator: Allocator,
    db: *Database,
    cache: *CacheService,
    
    pub fn init(allocator: Allocator, db: *Database, cache: *CacheService) UserService {
        return .{
            .allocator = allocator,
            .db = db,
            .cache = cache,
        };
    }
    
    pub fn getUserById(self: *UserService, id: u64) !User {
        // 业务逻辑实现
    }
};
```

### 3. 领域层 (domain/)

**职责**：
- 定义核心业务实体
- 实现业务规则
- 领域服务

**规范**：
- 实体应该是自包含的
- 业务规则在实体内部实现
- 避免依赖外层

**示例**：
```zig
// domain/entities/user.zig
pub const User = struct {
    id: u64,
    username: []const u8,
    email: []const u8,
    created_at: i64,
    
    pub fn validate(self: User) !void {
        if (self.username.len < 3) {
            return error.UsernameTooShort;
        }
        // 更多验证规则
    }
};
```

### 4. 基础设施层 (infrastructure/)

**职责**：
- 外部系统集成
- 数据持久化实现
- 第三方服务适配器

### 5. 共享层 (shared/)

**职责**：
- 跨层通用组件
- 工具函数
- 全局资源管理

## 命名规范

### 文件命名

- **模块文件**：`mod.zig`
- **实现文件**：`xxx.zig`（小写，下划线分隔）
- **测试文件**：`xxx_test.zig`

### 类型命名

- **结构体**：`PascalCase`
- **函数**：`camelCase`
- **常量**：`SCREAMING_SNAKE_CASE`
- **变量**：`snake_case`

```zig
// ✅ 正确
pub const UserService = struct {
    const MAX_RETRY = 3;
    
    allocator: Allocator,
    retry_count: u32,
    
    pub fn init(allocator: Allocator) UserService {
        return .{
            .allocator = allocator,
            .retry_count = 0,
        };
    }
    
    pub fn getUserById(self: *UserService, user_id: u64) !User {
        // ...
    }
};
```

## 依赖规则

### 依赖方向

```
API 层 → 应用层 → 领域层
  ↓         ↓
基础设施层 ←┘
  ↓
共享层（所有层都可以依赖）
```

### 规则

1. **外层依赖内层**：API 层可以依赖应用层，但应用层不能依赖 API 层
2. **领域层独立**：领域层不依赖任何外层
3. **共享层通用**：所有层都可以依赖共享层
4. **避免循环依赖**

## 错误处理

### 错误类型定义

```zig
// 在各层定义特定的错误类型
pub const ApiError = error{
    InvalidRequest,
    Unauthorized,
    NotFound,
};

pub const ServiceError = error{
    UserNotFound,
    DuplicateEmail,
    InvalidPassword,
};

pub const DomainError = error{
    InvalidEntity,
    BusinessRuleViolation,
};
```

### 错误传播

```zig
// 从内层向外层传播错误
pub fn handleRequest(req: *Request) !void {
    const user = try userService.getUser(id);  // ServiceError
    try sendResponse(req, user);                // ApiError
}
```

## 测试策略

### 测试文件组织

```
src/
├── user.zig
└── user_test.zig

tests/
├── integration/
│   └── user_api_test.zig
└── e2e/
    └── user_flow_test.zig
```

### 测试类型

1. **单元测试**：测试单个函数/方法
2. **集成测试**：测试模块间交互
3. **端到端测试**：测试完整流程

```zig
// 单元测试
test "User.validate - valid user" {
    const user = User{
        .id = 1,
        .username = "john",
        .email = "john@example.com",
        .created_at = 0,
    };
    try user.validate();
}

// 集成测试
test "UserService.createUser - integration" {
    var db = try TestDatabase.init(testing.allocator);
    defer db.deinit();
    
    var service = UserService.init(testing.allocator, &db);
    const user = try service.createUser(.{
        .username = "john",
        .email = "john@example.com",
    });
    
    try testing.expect(user.id > 0);
}
```

## 配置管理

### 配置文件

```
config/
├── development.zig
├── production.zig
└── test.zig
```

### 配置结构

```zig
pub const Config = struct {
    server: ServerConfig,
    database: DatabaseConfig,
    cache: CacheConfig,
    
    pub const ServerConfig = struct {
        host: []const u8 = "127.0.0.1",
        port: u16 = 3000,
        max_clients: u32 = 10000,
    };
    
    pub const DatabaseConfig = struct {
        host: []const u8,
        port: u16,
        database: []const u8,
        user: []const u8,
        password: []const u8,
    };
};
```

## 日志规范

### 日志级别使用

- **DEBUG**：详细的调试信息
- **INFO**：一般信息（启动、关闭、重要操作）
- **WARN**：警告信息（可恢复的错误）
- **ERROR**：错误信息（需要关注的问题）
- **FATAL**：致命错误（导致程序终止）

### 日志格式

```zig
// ✅ 结构化日志
logger.info("用户登录成功", .{});
logger.with(.{ .user_id = 123, .ip = "192.168.1.1" })
      .info("用户操作", .{});

// ✅ 带上下文的错误日志
logger.err("数据库连接失败: {}", .{err});
```

## 性能优化

### 内存分配策略

1. **栈分配优先**：小对象使用栈
2. **池化重用**：频繁分配的对象使用对象池
3. **批量分配**：减少分配次数

```zig
// ✅ 使用 ArenaAllocator 批量分配
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

const arena_alloc = arena.allocator();
// 所有分配都会在 arena.deinit() 时一次性释放
```

### 数据库查询优化

1. **使用连接池**
2. **批量操作**
3. **索引优化**
4. **查询缓存**

## 安全规范

### 输入验证

```zig
pub fn validateInput(input: []const u8) !void {
    if (input.len == 0) return error.EmptyInput;
    if (input.len > MAX_LENGTH) return error.InputTooLong;
    // SQL 注入防护
    // XSS 防护
}
```

### 密码处理

```zig
// ✅ 使用加密库
const hash = try bcrypt.hash(allocator, password, .{});
defer allocator.free(hash);
```

### 敏感信息

- 不在日志中输出密码、token
- 使用环境变量存储敏感配置
- 加密存储敏感数据

## 代码审查清单

- [ ] 符合分层架构
- [ ] 命名规范一致
- [ ] 错误处理完善
- [ ] 内存安全（无泄漏）
- [ ] 有单元测试
- [ ] 日志记录适当
- [ ] 文档完整
- [ ] 性能考虑
- [ ] 安全检查

## 持续改进

1. 定期代码审查
2. 性能分析和优化
3. 安全审计
4. 文档更新
5. 技术债务管理
