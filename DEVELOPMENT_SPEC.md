# ZigCMS 开发规范

## 概述

本文档定义了 ZigCMS 项目的开发规范和标准，基于最新的软件工程最佳实践和 Zig 0.15+ 语言特性。该规范旨在确保项目的可维护性、可扩展性、安全性和性能，同时遵循现代软件架构原则。

**版本**: 2.0.0  
**最后更新**: 2025-12-21  
**适用范围**: 所有 ZigCMS 项目参与者  
**基于**: Zig 0.15+, Clean Architecture, DDD, Hexagonal Architecture

## 目录

1. [现代架构原则](#现代架构原则)
2. [Zig 0.15+ 语言规范](#zig-015-语言规范)
3. [整洁架构实践](#整洁架构实践)
4. [领域驱动设计](#领域驱动设计)
5. [错误处理与内存管理](#错误处理与内存管理)
6. [API设计规范](#API设计规范)
7. [数据库设计规范](#数据库设计规范)
8. [测试驱动开发](#测试驱动开发)
9. [性能与可观测性](#性能与可观测性)
10. [安全最佳实践](#安全最佳实践)
11. [DevOps 与部署](#devops-与部署)
12. [代码质量保证](#代码质量保证)

## 现代架构原则

### 1.1 整洁架构 (Clean Architecture)

ZigCMS 采用整洁架构模式，确保业务逻辑独立于框架、数据库和外部服务。

#### 1.1.1 依赖规则
```
外层 → 内层 (允许)
内层 → 外层 (禁止)
```

**分层结构**:
- **API层**: HTTP 控制器、中间件、DTO
- **应用层**: 用例、应用服务、事件处理
- **领域层**: 实体、领域服务、仓储接口
- **基础设施层**: 数据库、缓存、HTTP客户端实现

#### 1.1.2 六边形架构 (Hexagonal Architecture)

```
     ┌─────────────────┐
     │   Primary       │
     │   Adapters      │ ← HTTP, CLI, Tests
     │   (Drivers)     │
     └─────────┬───────┘
               │
    ┌──────────▼──────────┐
    │                     │
    │   Application       │ ← Business Logic
    │      Core           │   (Ports & Use Cases)
    │                     │
    └──────────┬──────────┘
               │
     ┌─────────▼───────┐
     │   Secondary     │
     │   Adapters      │ ← Database, Cache, APIs
     │   (Driven)      │
     └─────────────────┘
```

### 1.2 领域驱动设计 (DDD)

#### 1.2.1 战术模式
- **实体 (Entities)**: 具有唯一标识的业务对象
- **值对象 (Value Objects)**: 不可变的描述性对象
- **聚合 (Aggregates)**: 业务一致性边界
- **领域服务 (Domain Services)**: 跨实体的业务逻辑
- **仓储 (Repositories)**: 数据访问抽象

#### 1.2.2 战略模式
- **限界上下文 (Bounded Context)**: 明确的业务边界
- **上下文映射 (Context Mapping)**: 上下文间的关系
- **防腐层 (Anti-Corruption Layer)**: 外部系统适配

### 1.3 CQRS 与事件驱动

#### 1.3.1 命令查询职责分离
```zig
// 命令 - 修改状态
pub const CreateUserCommand = struct {
    username: []const u8,
    email: []const u8,
    
    pub fn execute(self: @This(), handler: *UserCommandHandler) !UserId {
        return handler.createUser(self);
    }
};

// 查询 - 读取数据
pub const UserQuery = struct {
    pub fn findById(id: UserId, handler: *UserQueryHandler) !?UserView {
        return handler.findUserById(id);
    }
};
```

#### 1.3.2 事件驱动架构
```zig
pub const DomainEvent = union(enum) {
    user_created: UserCreatedEvent,
    user_updated: UserUpdatedEvent,
    
    pub const UserCreatedEvent = struct {
        user_id: UserId,
        username: []const u8,
        email: []const u8,
        occurred_at: i64,
    };
};
```

## Zig 0.15+ 语言规范

### 2.1 现代 Zig 特性

#### 2.1.1 错误处理最佳实践
```zig
// ✅ 推荐：明确的错误类型
pub const UserError = error{
    NotFound,
    InvalidEmail,
    DuplicateUsername,
    ValidationFailed,
};

// ✅ 推荐：错误联合类型
pub fn createUser(data: UserCreateData) UserError!User {
    if (!isValidEmail(data.email)) return error.InvalidEmail;
    if (userExists(data.username)) return error.DuplicateUsername;
    
    return User{
        .id = generateId(),
        .username = data.username,
        .email = data.email,
    };
}

// ✅ 推荐：错误处理链
pub fn registerUser(data: UserCreateData) !User {
    const user = createUser(data) catch |err| switch (err) {
        error.InvalidEmail => {
            log.warn("Invalid email provided: {s}", .{data.email});
            return error.ValidationFailed;
        },
        error.DuplicateUsername => {
            log.info("Username already exists: {s}", .{data.username});
            return error.DuplicateUsername;
        },
        else => return err,
    };
    
    try saveUser(user);
    return user;
}
```

#### 2.1.2 内存管理模式
```zig
// ✅ 推荐：Arena 分配器用于临时分配
pub fn processRequest(allocator: Allocator, request: Request) !Response {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    
    // 所有临时分配都使用 arena_allocator
    const parsed_data = try parseRequestData(arena_allocator, request.body);
    const processed = try processData(arena_allocator, parsed_data);
    
    // 返回前复制到主分配器
    return try allocator.dupe(u8, processed);
}

// ✅ 推荐：RAII 模式
pub const DatabaseConnection = struct {
    handle: *c.sqlite3,
    
    pub fn init(path: []const u8) !DatabaseConnection {
        var handle: ?*c.sqlite3 = null;
        const result = c.sqlite3_open(path.ptr, &handle);
        if (result != c.SQLITE_OK) return error.DatabaseOpenFailed;
        
        return DatabaseConnection{ .handle = handle.? };
    }
    
    pub fn deinit(self: *DatabaseConnection) void {
        _ = c.sqlite3_close(self.handle);
    }
};

// ✅ 推荐：defer 确保资源清理
pub fn readFile(allocator: Allocator, path: []const u8) ![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.err("Failed to open file {s}: {}", .{ path, err });
        return err;
    };
    defer file.close();
    
    const size = try file.getEndPos();
    const content = try allocator.alloc(u8, size);
    errdefer allocator.free(content);
    
    _ = try file.readAll(content);
    return content;
}
```

#### 2.1.3 编译时计算与泛型
```zig
// ✅ 推荐：编译时类型生成
pub fn Repository(comptime T: type) type {
    return struct {
        const Self = @This();
        
        allocator: Allocator,
        db: *Database,
        
        pub fn findById(self: *Self, id: i32) !?T {
            const query = comptime std.fmt.comptimePrint(
                "SELECT * FROM {s} WHERE id = ?", 
                .{T.table_name}
            );
            return self.db.queryOne(T, query, .{id});
        }
        
        pub fn save(self: *Self, entity: T) !T {
            if (entity.id) |_| {
                return self.update(entity);
            } else {
                return self.insert(entity);
            }
        }
    };
}

// 使用示例
const UserRepository = Repository(User);
```

#### 2.1.4 接口与多态
```zig
// ✅ 推荐：虚表模式实现接口
pub const Cache = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        get: *const fn (*anyopaque, []const u8) anyerror!?[]const u8,
        set: *const fn (*anyopaque, []const u8, []const u8, u64) anyerror!void,
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
        clear: *const fn (*anyopaque) anyerror!void,
    };
    
    pub fn get(self: Cache, key: []const u8) !?[]const u8 {
        return self.vtable.get(self.ptr, key);
    }
    
    pub fn set(self: Cache, key: []const u8, value: []const u8, ttl: u64) !void {
        return self.vtable.set(self.ptr, key, value, ttl);
    }
};

// 实现示例
pub const RedisCache = struct {
    connection: RedisConnection,
    
    pub fn toInterface(self: *RedisCache) Cache {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .get = get,
                .set = set,
                .delete = delete,
                .clear = clear,
            },
        };
    }
    
    fn get(ptr: *anyopaque, key: []const u8) !?[]const u8 {
        const self: *RedisCache = @ptrCast(@alignCast(ptr));
        return self.connection.get(key);
    }
    
    // ... 其他方法实现
};
```

### 2.2 代码风格规范

#### 2.2.1 命名约定
```zig
// ✅ 文件命名：snake_case
// user_service.zig, auth_controller.zig

// ✅ 类型命名：PascalCase
pub const UserService = struct { ... };
pub const AuthError = error { ... };

// ✅ 变量和函数：camelCase
pub fn createUser(userData: UserData) !User { ... }
const userCount = 42;

// ✅ 常量：SCREAMING_SNAKE_CASE
const MAX_USERS = 1000;
const DEFAULT_TIMEOUT = 30;

// ✅ 字段：snake_case
pub const User = struct {
    user_id: i32,
    created_at: i64,
    is_active: bool,
};
```

#### 2.2.2 代码组织
```zig
//! 文件头注释
//! 
//! 描述文件的用途和职责

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

// 导入项目模块
const User = @import("../domain/entities/user.zig").User;
const UserRepository = @import("../infrastructure/repositories/user_repository.zig");

// 类型别名
const UserId = i32;
const Timestamp = i64;

// 常量定义
const MAX_USERNAME_LENGTH = 50;
const MIN_PASSWORD_LENGTH = 8;

// 错误类型
pub const UserServiceError = error{
    UserNotFound,
    InvalidCredentials,
    ValidationFailed,
};

// 主要结构体
pub const UserService = struct {
    // 字段
    allocator: Allocator,
    repository: *UserRepository,
    
    // 公共方法
    pub fn init(allocator: Allocator, repository: *UserRepository) UserService {
        return .{
            .allocator = allocator,
            .repository = repository,
        };
    }
    
    pub fn createUser(self: *UserService, data: UserCreateData) !User {
        // 实现
    }
    
    // 私有方法
    fn validateUserData(data: UserCreateData) !void {
        // 实现
    }
};

// 测试
test "UserService.createUser" {
    // 测试实现
}
```

#### 1.1.1 文件命名
- 使用 `snake_case` 命名文件
- 控制器文件: `{module}.controller.zig`
- 服务文件: `{module}.service.zig`
- 模型文件: `{module}.model.zig`
- DTO文件: `{module}_create.dto.zig`
- 示例:
  ```
  user.controller.zig
  auth.service.zig
  material.model.zig
  user_create.dto.zig
  ```

#### 1.1.2 结构体和类型命名
- 使用 `PascalCase` 命名结构体、联合体和枚举
- 使用 `snake_case` 命名字段和变量
- 函数使用 `camelCase`
- 示例:
  ```zig
  pub const UserController = struct {
      allocator: Allocator,
      user_service: *UserService,

      pub fn createUser(self: Self, request: zap.Request) !void {
          // implementation
      }
  };
  ```

#### 1.1.3 常量命名
- 使用 `SCREAMING_SNAKE_CASE` 命名常量
- 示例:
  ```zig
  const MAX_FILE_SIZE = 10 * 1024 * 1024;
  const DEFAULT_PAGE_SIZE = 10;
  ```

#### 1.1.4 导入和别名
- 使用完整的模块路径导入
- 为常用导入创建有意义的别名
- 示例:
  ```zig
  const std = @import("std");
  const zap = @import("zap");
  const Allocator = std.mem.Allocator;
  const json_mod = @import("../../application/services/json/json.zig");
  ```

### 1.2 代码组织结构

#### 1.2.1 项目结构
```
zigcms/
├── api/
│   ├── controllers/     # 控制器层
│   ├── dto/            # 数据传输对象
│   └── middleware/     # 中间件
├── application/
│   ├── services/       # 业务服务层
│   └── config/         # 配置管理
├── domain/
│   ├── entities/       # 领域实体
│   └── repositories/   # 数据访问层
├── shared/
│   ├── utils/          # 工具函数
│   └── primitives/     # 基础类型
├── docs/               # 文档
└── tests/              # 测试代码
```

#### 1.2.2 文件结构规范
每个 `.zig` 文件必须包含：
1. 文件头部注释（用途说明）
2. 必要的导入语句
3. 按逻辑分组的代码段
4. 适当的空行分隔

### 1.3 注释规范

#### 1.3.1 文件注释
```zig
//! 用户管理控制器
//!
//! 提供用户相关的 CRUD 操作和认证功能

const std = @import("std");
// ... 其他导入
```

#### 1.3.2 函数注释
```zig
/// 创建新用户
/// @param request HTTP请求对象
/// @return 成功时返回用户信息，失败时返回错误
pub fn createUser(self: Self, request: zap.Request) !User {
    // implementation
}
```

#### 1.3.3 复杂逻辑注释
```zig
// 计算用户积分
// 积分规则:
// 1. 注册获得10积分
// 2. 每日登录获得1积分
// 3. 发布内容获得5积分
fn calculateUserScore(user: User) i32 {
    // implementation
}
```

## 架构设计原则

### 2.1 分层架构

#### 2.1.1 架构层次
```
┌─────────────────┐
│   Controller    │  # API层，处理HTTP请求
├─────────────────┤
│    Service      │  # 业务逻辑层
├─────────────────┤
│  Repository     │  # 数据访问层
├─────────────────┤
│    Domain       │  # 领域模型层
├─────────────────┤
│   Database      │  # 数据持久化层
└─────────────────┘
```

#### 2.1.2 职责分离
- **Controller**: 仅处理HTTP请求/响应，不包含业务逻辑
- **Service**: 封装业务逻辑，协调多个Repository
- **Repository**: 封装数据访问逻辑
- **Domain**: 定义业务实体和规则

### 2.2 依赖注入原则

#### 2.2.1 构造函数注入
```zig
pub const UserService = struct {
    allocator: Allocator,
    user_repo: *UserRepository,

    pub fn init(allocator: Allocator, user_repo: *UserRepository) Self {
        return .{
            .allocator = allocator,
            .user_repo = user_repo,
        };
    }
};
```

#### 2.2.2 接口抽象
使用函数指针或虚表实现接口抽象：
```zig
pub const UploadProvider = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        upload: *const fn (*anyopaque, []const u8, []const u8) anyerror![]const u8,
        // ... 其他方法
    };
};
```

### 2.3 错误处理规范

#### 2.3.1 错误类型定义
```zig
pub const UserError = error{
    UserNotFound,
    InvalidCredentials,
    DuplicateEmail,
    ValidationError,
};
```

#### 2.3.2 错误处理模式
```zig
pub fn getUser(self: Self, id: i32) !User {
    return self.user_repo.findById(id) catch |err| switch (err) {
        RepositoryError.NotFound => error.UserNotFound,
        else => err,
    };
}
```

## API设计规范

### 3.1 RESTful API 设计

#### 3.1.1 资源命名
- 使用复数名词表示资源集合
- 使用小写字母和连字符
- 示例:
  ```
  GET    /api/users          # 获取用户列表
  POST   /api/users          # 创建用户
  GET    /api/users/{id}     # 获取特定用户
  PUT    /api/users/{id}     # 更新用户
  DELETE /api/users/{id}     # 删除用户
  ```

#### 3.1.2 HTTP状态码使用
- `200 OK`: 成功
- `201 Created`: 资源创建成功
- `204 No Content`: 删除成功
- `400 Bad Request`: 请求参数错误
- `401 Unauthorized`: 未认证
- `403 Forbidden`: 无权限
- `404 Not Found`: 资源不存在
- `422 Unprocessable Entity`: 验证错误
- `500 Internal Server Error`: 服务器错误

### 3.2 请求/响应格式

#### 3.2.1 统一响应格式
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    // 响应数据
  }
}
```

#### 3.2.2 分页响应格式
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "items": [...],
    "total": 100,
    "page": 1,
    "page_size": 10,
    "total_pages": 10
  }
}
```

#### 3.2.3 错误响应格式
```json
{
  "code": 1001,
  "msg": "用户不存在",
  "data": null
}
```

### 3.3 参数验证

#### 3.3.1 DTO定义
```zig
pub const CreateUserDto = struct {
    username: []const u8,
    email: []const u8,
    password: []const u8,

    pub fn validate(self: Self) !void {
        if (self.username.len < 3) return error.UsernameTooShort;
        if (!isValidEmail(self.email)) return error.InvalidEmail;
        if (self.password.len < 6) return error.PasswordTooWeak;
    }
};
```

#### 3.3.2 验证规则
- 必填字段验证
- 数据类型验证
- 长度限制验证
- 格式验证（邮箱、手机号等）
- 业务规则验证

### 3.4 认证和授权

#### 3.4.1 JWT认证
```zig
pub const MW = mw.Controller(Self);

pub const create = MW.requireAuth(createImpl);
pub const update = MW.requireAuth(updateImpl);
```

#### 3.4.2 权限控制
- 基于角色的访问控制(RBAC)
- 资源级权限控制
- API级权限控制

## 数据库设计规范

### 4.1 表设计规范

#### 4.1.1 表命名
- 使用复数形式
- 使用小写字母和下划线
- 示例:
  ```sql
  users, user_roles, categories, articles
  ```

#### 4.1.2 字段命名
- 使用小写字母和下划线
- 外键字段: `{table}_id`
- 示例:
  ```sql
  id, name, email, created_at, user_id, category_id
  ```

#### 4.1.3 必备字段
所有表必须包含以下字段:
```sql
id INT PRIMARY KEY AUTO_INCREMENT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
is_delete TINYINT DEFAULT 0
```

### 4.2 索引设计

#### 4.2.1 主键索引
- 使用自增整数作为主键
- 复合主键仅在必要时使用

#### 4.2.2 外键约束
- 必须为外键创建索引
- 使用级联删除或置空（谨慎使用）

#### 4.2.3 业务索引
```sql
-- 用户名唯一索引
CREATE UNIQUE INDEX idx_users_username ON users(username);

-- 复合索引
CREATE INDEX idx_articles_category_created ON articles(category_id, created_at DESC);
```

### 4.3 ORM使用规范

#### 4.3.1 模型定义
```zig
pub const User = sql.defineWithConfig(struct {
    id: i32,
    username: []const u8,
    email: []const u8,
    created_at: i64,
    is_delete: i8,
}, .{
    .table_name = "zigcms.users",
    .primary_key = "id",
});
```

#### 4.3.2 查询规范
```zig
// 推荐：使用链式调用
var query = User.query(db);
defer query.deinit();

const users = try query
    .where("is_delete", "=", 0)
    .orderBy("created_at", .desc)
    .limit(10)
    .find();

// 避免：直接SQL字符串
const users = try db.query("SELECT * FROM users WHERE is_delete = 0");
```

### 4.4 数据迁移

#### 4.4.1 迁移文件命名
```
YYYYMMDD_HHMMSS_description.up.sql
YYYYMMDD_HHMMSS_description.down.sql
```

#### 4.4.2 迁移内容规范
- 必须包含回滚脚本
- 不能破坏现有数据
- 必须考虑数据兼容性

## 测试规范

### 5.1 测试分类

#### 5.1.1 单元测试
- 测试单个函数或方法
- 模拟外部依赖
- 覆盖正常和异常情况

#### 5.1.2 集成测试
- 测试模块间的交互
- 测试数据库操作
- 测试API端点

#### 5.1.3 端到端测试
- 测试完整用户流程
- 测试系统集成
- 性能和压力测试

### 5.2 测试文件组织

#### 5.2.1 文件命名
```
module_test.zig          # 模块测试
module.integration_test.zig  # 集成测试
```

#### 5.2.2 测试函数命名
```zig
test "create user with valid data" {
    // test implementation
}

test "create user with invalid email" {
    // test implementation
}
```

### 5.3 测试覆盖率要求

#### 5.3.1 最低覆盖率
- 业务逻辑代码: ≥80%
- API控制器: ≥70%
- 工具函数: ≥90%
- 新功能: ≥85%

#### 5.3.2 覆盖范围
- 函数分支覆盖
- 错误处理覆盖
- 边界条件覆盖
- 异常情况覆盖

### 5.4 测试规范

#### 5.4.1 测试数据管理
```zig
const test_allocator = std.testing.allocator;

fn setupTestData() !void {
    // 创建测试数据库
    // 插入测试数据
}

fn cleanupTestData() void {
    // 清理测试数据
}
```

#### 5.4.2 断言使用
```zig
try std.testing.expectEqual(expected, actual);
try std.testing.expectError(error.UserNotFound, userService.getUser(999));
try std.testing.expect(user.name.len > 0);
```

## 文档规范

### 6.1 代码文档

#### 6.1.1 函数文档
```zig
/// 计算用户活跃度评分
///
/// 评分算法：
/// 1. 登录天数权重: 40%
/// 2. 发布内容数权重: 30%
/// 3. 互动次数权重: 20%
/// 4. 注册时长权重: 10%
///
/// @param user 用户对象
/// @param login_days 连续登录天数
/// @param post_count 发布内容数
/// @param interaction_count 互动次数
/// @return 活跃度评分 (0-100)
pub fn calculateActivityScore(
    user: User,
    login_days: i32,
    post_count: i32,
    interaction_count: i32
) f32 {
    // implementation
}
```

#### 6.1.2 结构体文档
```zig
/// 用户实体
/// 表示系统中的用户账号信息
pub const User = struct {
    /// 用户ID，主键
    id: i32,
    /// 用户名，唯一标识
    username: []const u8,
    /// 邮箱地址，用于登录和通知
    email: []const u8,
    /// 创建时间戳
    created_at: i64,
};
```

### 6.2 API文档

#### 6.2.1 接口文档结构
每个API接口必须包含：
1. 接口描述
2. 请求方法和URL
3. 请求参数说明
4. 请求示例
5. 响应格式
6. 响应示例
7. 错误码说明
8. 权限要求

#### 6.2.2 HTML文档规范
```html
<div class="section">
    <h2><span class="method.get">GET</span> 获取用户列表</h2>
    <p>获取系统中的用户列表，支持分页和筛选</p>

    <h3>请求</h3>
    <div class="code-block">GET /api/users</div>

    <h3>查询参数</h3>
    <table class="table">
        <thead>
            <tr>
                <th>参数</th>
                <th>类型</th>
                <th>必填</th>
                <th>说明</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>page</td>
                <td>integer</td>
                <td>❌</td>
                <td>页码，默认1</td>
            </tr>
        </tbody>
    </table>

    <h3>测试接口</h3>
    <div class="test-section">
        <button class="btn success" onclick="testGetUsers()">获取用户列表</button>
        <div id="users-response" class="response-area"></div>
    </div>
</div>
```

### 6.3 项目文档

#### 6.3.1 README文件
必须包含：
- 项目简介
- 快速开始指南
- 开发环境要求
- 部署说明
- 贡献指南

#### 6.3.2 架构文档
- 系统架构图
- 模块依赖关系
- 数据流图
- 部署架构图

## 安全规范

### 7.1 输入验证

#### 7.1.1 参数校验
```zig
pub fn validateInput(input: []const u8) !void {
    // 长度检查
    if (input.len > MAX_LENGTH) return error.InputTooLong;

    // 特殊字符检查
    if (std.mem.indexOfAny(u8, input, "<>\"'&")) |_| {
        return error.InvalidCharacters;
    }

    // SQL注入检查
    if (containsSqlKeywords(input)) return error.SqlInjectionDetected;
}
```

#### 7.1.2 XSS防护
- 对用户输入进行HTML编码
- 使用CSP (Content Security Policy)
- 验证和清理富文本内容

### 7.2 认证和授权

#### 7.2.1 JWT安全
```zig
pub const JwtConfig = struct {
    secret: []const u8,
    expiration: i64 = 3600, // 1小时
    issuer: []const u8 = "zigcms",
    algorithm: jwt.Algorithm = .HS256,
};
```

#### 7.2.2 密码安全
- 使用bcrypt进行密码哈希
- 密码复杂度要求（长度、字符类型）
- 密码重试限制
- 密码过期策略

### 7.3 数据安全

#### 7.3.1 敏感数据处理
```zig
// 密码字段不应该在日志中输出
std.log.info("用户 {} 登录成功", .{user.username});
// 避免：std.log.info("用户 {} 密码 {} 登录成功", .{user.username, user.password});
```

#### 7.3.2 SQL注入防护
- 使用参数化查询
- 避免字符串拼接SQL
- 输入数据转义

### 7.4 HTTPS和传输安全

#### 7.4.1 HTTPS配置
- 生产环境必须使用HTTPS
- 配置适当的SSL证书
- 禁用不安全的SSL版本

#### 7.4.2 安全头设置
```zig
// 设置安全响应头
req.headers.add("X-Content-Type-Options", "nosniff");
req.headers.add("X-Frame-Options", "DENY");
req.headers.add("X-XSS-Protection", "1; mode=block");
req.headers.add("Strict-Transport-Security", "max-age=31536000");
```

## 性能规范

### 8.1 代码性能优化

#### 8.1.1 内存管理
```zig
// 推荐：使用Arena分配器处理临时分配
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_allocator = arena.allocator();

// 使用arena分配器进行临时操作
const temp_buffer = try arena_allocator.alloc(u8, 1024);
defer arena_allocator.free(temp_buffer);
```

#### 8.1.2 避免不必要的分配
```zig
// 不推荐：频繁的小分配
for (items) |item| {
    const json_str = try std.json.stringifyAlloc(allocator, item, .{});
    defer allocator.free(json_str);
    // 使用json_str
}

// 推荐：预分配缓冲区
var buffer = try std.ArrayList(u8).initCapacity(allocator, 4096);
defer buffer.deinit();

// 重用缓冲区
for (items) |item| {
    buffer.clearRetainingCapacity();
    try std.json.stringify(item, .{}, buffer.writer());
    // 使用buffer.items
}
```

### 8.2 数据库性能优化

#### 8.2.1 查询优化
```zig
// 推荐：使用索引字段查询
const users = try User.query(db)
    .where("email", "=", email)  // email有索引
    .find();

// 避免：全表扫描
const users = try User.query(db)
    .where("description", "LIKE", "%keyword%")  // description无索引
    .find();
```

#### 8.2.2 批量操作
```zig
// 推荐：批量插入
var batch = try User.batchInsert(db);
defer batch.deinit();

for (users) |user| {
    try batch.add(user);
}
try batch.execute();

// 避免：循环单条插入
for (users) |user| {
    _ = try User.Create(user);
}
```

### 8.3 API性能优化

#### 8.3.1 响应压缩
```zig
// 启用Gzip压缩
if (std.mem.eql(u8, accept_encoding, "gzip")) {
    // 压缩响应数据
    const compressed = try gzip.compress(allocator, response_data);
    defer allocator.free(compressed);

    req.headers.add("Content-Encoding", "gzip");
    try req.writer().writeAll(compressed);
}
```

#### 8.3.2 缓存策略
```zig
// 应用级缓存
var cache = std.StringHashMap([]const u8).init(allocator);
defer cache.deinit();

// 缓存热点数据
if (cache.get(cache_key)) |cached_data| {
    return cached_data;
}

// 计算数据
const data = try computeData();
// 缓存结果
try cache.put(cache_key, data);
```

### 8.4 监控和性能指标

#### 8.4.1 性能监控点
- API响应时间
- 数据库查询时间
- 内存使用情况
- 错误率统计
- 并发连接数

#### 8.4.2 性能基准
- API响应时间: <200ms (95%)
- 数据库查询: <50ms (95%)
- 内存使用: <512MB (常驻)
- CPU使用率: <70% (峰值)

## 版本控制规范

### 9.1 Git工作流

#### 9.1.1 分支策略
```
main (主分支)          # 生产环境代码
├── develop           # 开发分支
│   ├── feature/*     # 功能分支
│   ├── bugfix/*      # 修复分支
│   └── hotfix/*      # 紧急修复分支
└── release/*         # 发布分支
```

#### 9.1.2 分支命名规范
```
feature/user-authentication
bugfix/login-validation
hotfix/security-patch
release/v1.2.0
```

### 9.2 提交规范

#### 9.2.1 提交信息格式
```
<type>(<scope>): <subject>

<body>

<footer>
```

#### 9.2.2 提交类型
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或工具配置

#### 9.2.3 提交示例
```
feat(auth): add JWT authentication

- Implement JWT token generation and validation
- Add login and logout endpoints
- Update user model with token fields

Closes #123
```

### 9.3 代码审查

#### 9.3.1 审查清单
- [ ] 代码符合风格规范
- [ ] 功能逻辑正确
- [ ] 单元测试覆盖完整
- [ ] 文档更新完整
- [ ] 性能影响评估
- [ ] 安全漏洞检查

#### 9.3.2 审查流程
1. 创建Pull Request
2. 至少一人审查代码
3. 通过CI/CD检查
4. 审查通过后合并

## 部署规范

### 10.1 环境管理

#### 10.1.1 环境分类
- **开发环境(dev)**: 开发调试使用
- **测试环境(test)**: 集成测试使用
- **预发布环境(staging)**: 生产前验证
- **生产环境(prod)**: 线上服务环境

#### 10.1.2 环境配置
```zig
pub const Config = struct {
    database_url: []const u8,
    redis_url: []const u8,
    jwt_secret: []const u8,
    upload_provider: []const u8,
    log_level: std.log.Level,

    pub fn load(env: []const u8) !Config {
        // 根据环境加载不同配置
        if (std.mem.eql(u8, env, "prod")) {
            return Config{
                .database_url = std.os.getenv("DATABASE_URL") orelse return error.ConfigMissing,
                .jwt_secret = std.os.getenv("JWT_SECRET") orelse return error.ConfigMissing,
                // ...
            };
        }
        // ...
    }
};
```

### 10.2 部署流程

#### 10.2.1 自动化部署
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build application
        run: zig build -Drelease-fast
      - name: Run tests
        run: zig build test
      - name: Deploy to server
        run: scp zig-out/bin/zigcms user@server:/opt/zigcms/
```

#### 10.2.2 部署检查清单
- [ ] 代码已通过所有测试
- [ ] 数据库迁移脚本已执行
- [ ] 配置文件已更新
- [ ] 依赖包已更新
- [ ] 备份已完成
- [ ] 监控告警已配置
- [ ] 回滚方案已准备

### 10.3 监控和日志

#### 10.3.1 日志规范
```zig
// 日志级别使用
std.log.info("用户 {} 登录成功", .{user.username});
std.log.warn("数据库连接池已满", .{});
std.log.err("API调用失败: {}", .{err});
```

#### 10.3.2 监控指标
- 应用健康检查: `/health`
- 性能指标: `/metrics`
- 业务指标: 自定义统计

### 10.4 备份和恢复

#### 10.4.1 数据备份策略
- 数据库: 每日全量 + 每小时增量
- 文件存储: 实时同步到备份存储
- 配置: 版本控制存储

#### 10.4.2 恢复测试
- 定期进行恢复演练
- 验证备份数据完整性
- 测试恢复时间目标(RTO)

## 附录

### A.1 错误码规范

| 错误码 | 说明 | HTTP状态码 |
|--------|------|------------|
| 0 | 成功 | 200 |
| 1001 | 参数错误 | 400 |
| 1002 | 未授权 | 401 |
| 1003 | 权限不足 | 403 |
| 1004 | 资源不存在 | 404 |
| 1005 | 服务器错误 | 500 |
| 2001 | 用户不存在 | 404 |
| 2002 | 密码错误 | 401 |

### A.2 工具和依赖

#### 必需工具
- Zig 0.12.0+
- SQLite 3.8+
- Git 2.0+

#### 推荐工具
- zls (Zig Language Server)
- zigmod (依赖管理)
- Docker (容器化)

### A.3 术语表

- **DTO**: Data Transfer Object, 数据传输对象
- **ORM**: Object-Relational Mapping, 对象关系映射
- **JWT**: JSON Web Token, JSON网络令牌
- **RBAC**: Role-Based Access Control, 基于角色的访问控制
- **CSP**: Content Security Policy, 内容安全策略

---

本文档为 ZigCMS 项目的核心开发规范，所有参与者必须严格遵守。如有疑问或需要补充，请提交 Issue 或 Pull Request。

## 整洁架构实践

### 3.1 分层职责

#### 3.1.1 API 层 (Presentation Layer)
```zig
// api/controllers/user_controller.zig
pub const UserController = struct {
    allocator: Allocator,
    create_user_usecase: *CreateUserUseCase,
    
    pub fn create(self: *UserController, req: zap.Request) !void {
        // 1. 解析和验证输入
        const dto = try req.parseJson(CreateUserDto);
        try dto.validate();
        
        // 2. 调用用例
        const user = try self.create_user_usecase.execute(.{
            .username = dto.username,
            .email = dto.email,
            .password = dto.password,
        });
        
        // 3. 返回响应
        const response = UserResponseDto.fromEntity(user);
        try req.sendJson(.{ .code = 0, .data = response });
    }
};

// api/dto/user_dto.zig
pub const CreateUserDto = struct {
    username: []const u8,
    email: []const u8,
    password: []const u8,
    
    pub fn validate(self: @This()) !void {
        if (self.username.len < 3) return error.UsernameTooShort;
        if (!isValidEmail(self.email)) return error.InvalidEmail;
        if (self.password.len < 8) return error.PasswordTooWeak;
    }
};

pub const UserResponseDto = struct {
    id: i32,
    username: []const u8,
    email: []const u8,
    created_at: i64,
    
    pub fn fromEntity(user: User) UserResponseDto {
        return .{
            .id = user.id,
            .username = user.username,
            .email = user.email,
            .created_at = user.created_at,
        };
    }
};
```

#### 3.1.2 应用层 (Application Layer)
```zig
// application/usecases/create_user_usecase.zig
pub const CreateUserUseCase = struct {
    allocator: Allocator,
    user_repository: UserRepository,
    email_service: EmailService,
    password_service: PasswordService,
    
    pub const Input = struct {
        username: []const u8,
        email: []const u8,
        password: []const u8,
    };
    
    pub fn execute(self: *CreateUserUseCase, input: Input) !User {
        // 1. 业务规则验证
        if (try self.user_repository.findByEmail(input.email)) |_| {
            return error.EmailAlreadyExists;
        }
        
        if (try self.user_repository.findByUsername(input.username)) |_| {
            return error.UsernameAlreadyExists;
        }
        
        // 2. 创建领域对象
        const hashed_password = try self.password_service.hash(input.password);
        const user = User{
            .username = input.username,
            .email = input.email,
            .password_hash = hashed_password,
            .created_at = std.time.timestamp(),
            .is_active = true,
        };
        
        // 3. 持久化
        const saved_user = try self.user_repository.save(user);
        
        // 4. 副作用（发送邮件）
        try self.email_service.sendWelcomeEmail(saved_user.email);
        
        return saved_user;
    }
};
```

#### 3.1.3 领域层 (Domain Layer)
```zig
// domain/entities/user.zig
pub const User = struct {
    id: ?i32 = null,
    username: []const u8,
    email: []const u8,
    password_hash: []const u8,
    created_at: i64,
    updated_at: ?i64 = null,
    is_active: bool = true,
    
    // 业务规则
    pub fn canLogin(self: User) bool {
        return self.is_active;
    }
    
    pub fn updateProfile(self: *User, username: ?[]const u8, email: ?[]const u8) void {
        if (username) |new_username| {
            self.username = new_username;
        }
        if (email) |new_email| {
            self.email = new_email;
        }
        self.updated_at = std.time.timestamp();
    }
    
    // 领域事件
    pub fn createRegisteredEvent(self: User) UserRegisteredEvent {
        return .{
            .user_id = self.id.?,
            .username = self.username,
            .email = self.email,
            .occurred_at = std.time.timestamp(),
        };
    }
};

// domain/services/user_domain_service.zig
pub const UserDomainService = struct {
    pub fn isUsernameAvailable(username: []const u8, repository: UserRepository) !bool {
        const existing = try repository.findByUsername(username);
        return existing == null;
    }
    
    pub fn generateUsername(base_name: []const u8, repository: UserRepository, allocator: Allocator) ![]const u8 {
        var counter: u32 = 1;
        while (counter < 1000) : (counter += 1) {
            const candidate = try std.fmt.allocPrint(allocator, "{s}{d}", .{ base_name, counter });
            if (try isUsernameAvailable(candidate, repository)) {
                return candidate;
            }
            allocator.free(candidate);
        }
        return error.CannotGenerateUsername;
    }
};

// domain/repositories/user_repository.zig (接口)
pub const UserRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?User,
        findByEmail: *const fn (*anyopaque, []const u8) anyerror!?User,
        findByUsername: *const fn (*anyopaque, []const u8) anyerror!?User,
        save: *const fn (*anyopaque, User) anyerror!User,
        delete: *const fn (*anyopaque, i32) anyerror!void,
    };
    
    pub fn findById(self: @This(), id: i32) !?User {
        return self.vtable.findById(self.ptr, id);
    }
    
    pub fn findByEmail(self: @This(), email: []const u8) !?User {
        return self.vtable.findByEmail(self.ptr, email);
    }
    
    pub fn save(self: @This(), user: User) !User {
        return self.vtable.save(self.ptr, user);
    }
};
```

#### 3.1.4 基础设施层 (Infrastructure Layer)
```zig
// infrastructure/repositories/sqlite_user_repository.zig
pub const SqliteUserRepository = struct {
    allocator: Allocator,
    db: *Database,
    
    pub fn init(allocator: Allocator, db: *Database) SqliteUserRepository {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }
    
    pub fn toInterface(self: *SqliteUserRepository) UserRepository {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .findById = findByIdImpl,
                .findByEmail = findByEmailImpl,
                .findByUsername = findByUsernameImpl,
                .save = saveImpl,
                .delete = deleteImpl,
            },
        };
    }
    
    fn findByIdImpl(ptr: *anyopaque, id: i32) !?User {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));
        
        const query = 
            \\SELECT id, username, email, password_hash, created_at, updated_at, is_active
            \\FROM users WHERE id = ? AND deleted_at IS NULL
        ;
        
        return self.db.queryOne(User, query, .{id});
    }
    
    fn saveImpl(ptr: *anyopaque, user: User) !User {
        const self: *SqliteUserRepository = @ptrCast(@alignCast(ptr));
        
        if (user.id) |id| {
            // 更新现有用户
            const query = 
                \\UPDATE users 
                \\SET username = ?, email = ?, password_hash = ?, updated_at = ?
                \\WHERE id = ?
            ;
            
            try self.db.execute(query, .{
                user.username,
                user.email,
                user.password_hash,
                std.time.timestamp(),
                id,
            });
            
            return user;
        } else {
            // 创建新用户
            const query = 
                \\INSERT INTO users (username, email, password_hash, created_at, is_active)
                \\VALUES (?, ?, ?, ?, ?)
                \\RETURNING id, username, email, password_hash, created_at, updated_at, is_active
            ;
            
            return self.db.queryOne(User, query, .{
                user.username,
                user.email,
                user.password_hash,
                user.created_at,
                user.is_active,
            }) orelse return error.InsertFailed;
        }
    }
};
```

### 3.2 依赖注入容器

```zig
// shared/container/service_container.zig
pub const ServiceContainer = struct {
    allocator: Allocator,
    services: std.StringHashMap(*anyopaque),
    
    pub fn init(allocator: Allocator) ServiceContainer {
        return .{
            .allocator = allocator,
            .services = std.StringHashMap(*anyopaque).init(allocator),
        };
    }
    
    pub fn deinit(self: *ServiceContainer) void {
        self.services.deinit();
    }
    
    pub fn register(self: *ServiceContainer, comptime T: type, service: *T) !void {
        const type_name = @typeName(T);
        try self.services.put(type_name, @ptrCast(service));
    }
    
    pub fn resolve(self: *ServiceContainer, comptime T: type) !*T {
        const type_name = @typeName(T);
        const ptr = self.services.get(type_name) orelse return error.ServiceNotFound;
        return @ptrCast(@alignCast(ptr));
    }
};

// 使用示例
pub fn setupContainer(allocator: Allocator) !ServiceContainer {
    var container = ServiceContainer.init(allocator);
    
    // 注册服务
    const db = try allocator.create(Database);
    db.* = try Database.init(allocator, "zigcms.db");
    try container.register(Database, db);
    
    const user_repo = try allocator.create(SqliteUserRepository);
    user_repo.* = SqliteUserRepository.init(allocator, db);
    try container.register(SqliteUserRepository, user_repo);
    
    const email_service = try allocator.create(EmailService);
    email_service.* = EmailService.init(allocator);
    try container.register(EmailService, email_service);
    
    const create_user_usecase = try allocator.create(CreateUserUseCase);
    create_user_usecase.* = .{
        .allocator = allocator,
        .user_repository = user_repo.toInterface(),
        .email_service = email_service.toInterface(),
        .password_service = PasswordService.init(),
    };
    try container.register(CreateUserUseCase, create_user_usecase);
    
    return container;
}
```

## 领域驱动设计

### 4.1 聚合设计

```zig
// domain/aggregates/user_aggregate.zig
pub const UserAggregate = struct {
    // 聚合根
    user: User,
    // 值对象
    profile: UserProfile,
    preferences: UserPreferences,
    // 领域事件
    events: std.ArrayListUnmanaged(DomainEvent),
    
    pub fn init(allocator: Allocator, user_data: UserCreateData) !UserAggregate {
        const user = User{
            .username = user_data.username,
            .email = user_data.email,
            .password_hash = try hashPassword(user_data.password),
            .created_at = std.time.timestamp(),
        };
        
        var aggregate = UserAggregate{
            .user = user,
            .profile = UserProfile.default(),
            .preferences = UserPreferences.default(),
            .events = .{},
        };
        
        // 记录领域事件
        try aggregate.addEvent(allocator, .{
            .user_registered = .{
                .user_id = user.id.?,
                .username = user.username,
                .email = user.email,
                .occurred_at = user.created_at,
            },
        });
        
        return aggregate;
    }
    
    pub fn updateProfile(self: *UserAggregate, allocator: Allocator, data: ProfileUpdateData) !void {
        // 业务规则验证
        if (data.display_name.len > 100) return error.DisplayNameTooLong;
        
        // 更新状态
        self.profile.display_name = data.display_name;
        self.profile.bio = data.bio;
        self.user.updated_at = std.time.timestamp();
        
        // 记录事件
        try self.addEvent(allocator, .{
            .user_profile_updated = .{
                .user_id = self.user.id.?,
                .occurred_at = self.user.updated_at.?,
            },
        });
    }
    
    pub fn changeEmail(self: *UserAggregate, allocator: Allocator, new_email: []const u8) !void {
        // 业务规则
        if (!isValidEmail(new_email)) return error.InvalidEmail;
        if (std.mem.eql(u8, self.user.email, new_email)) return error.EmailUnchanged;
        
        const old_email = self.user.email;
        self.user.email = new_email;
        self.user.email_verified = false; // 需要重新验证
        self.user.updated_at = std.time.timestamp();
        
        try self.addEvent(allocator, .{
            .user_email_changed = .{
                .user_id = self.user.id.?,
                .old_email = old_email,
                .new_email = new_email,
                .occurred_at = self.user.updated_at.?,
            },
        });
    }
    
    fn addEvent(self: *UserAggregate, allocator: Allocator, event: DomainEvent) !void {
        try self.events.append(allocator, event);
    }
    
    pub fn clearEvents(self: *UserAggregate) void {
        self.events.clearRetainingCapacity();
    }
};

// 值对象
pub const UserProfile = struct {
    display_name: ?[]const u8 = null,
    bio: ?[]const u8 = null,
    avatar_url: ?[]const u8 = null,
    
    pub fn default() UserProfile {
        return .{};
    }
};

pub const UserPreferences = struct {
    language: []const u8 = "en",
    timezone: []const u8 = "UTC",
    email_notifications: bool = true,
    
    pub fn default() UserPreferences {
        return .{};
    }
};
```

### 4.2 领域事件

```zig
// domain/events/domain_events.zig
pub const DomainEvent = union(enum) {
    user_registered: UserRegisteredEvent,
    user_profile_updated: UserProfileUpdatedEvent,
    user_email_changed: UserEmailChangedEvent,
    user_deactivated: UserDeactivatedEvent,
    
    pub const UserRegisteredEvent = struct {
        user_id: i32,
        username: []const u8,
        email: []const u8,
        occurred_at: i64,
    };
    
    pub const UserProfileUpdatedEvent = struct {
        user_id: i32,
        occurred_at: i64,
    };
    
    pub const UserEmailChangedEvent = struct {
        user_id: i32,
        old_email: []const u8,
        new_email: []const u8,
        occurred_at: i64,
    };
    
    pub const UserDeactivatedEvent = struct {
        user_id: i32,
        reason: []const u8,
        occurred_at: i64,
    };
};

// application/events/event_dispatcher.zig
pub const EventDispatcher = struct {
    handlers: std.ArrayListUnmanaged(EventHandler),
    allocator: Allocator,
    
    pub const EventHandler = struct {
        ptr: *anyopaque,
        handle_fn: *const fn (*anyopaque, DomainEvent) anyerror!void,
        
        pub fn handle(self: EventHandler, event: DomainEvent) !void {
            return self.handle_fn(self.ptr, event);
        }
    };
    
    pub fn init(allocator: Allocator) EventDispatcher {
        return .{
            .handlers = .{},
            .allocator = allocator,
        };
    }
    
    pub fn subscribe(self: *EventDispatcher, handler: EventHandler) !void {
        try self.handlers.append(self.allocator, handler);
    }
    
    pub fn dispatch(self: *EventDispatcher, event: DomainEvent) !void {
        for (self.handlers.items) |handler| {
            handler.handle(event) catch |err| {
                std.log.err("Event handler failed: {}", .{err});
                // 继续处理其他处理器
            };
        }
    }
};

// 事件处理器示例
pub const EmailNotificationHandler = struct {
    email_service: EmailService,
    
    pub fn toHandler(self: *EmailNotificationHandler) EventDispatcher.EventHandler {
        return .{
            .ptr = @ptrCast(self),
            .handle_fn = handle,
        };
    }
    
    fn handle(ptr: *anyopaque, event: DomainEvent) !void {
        const self: *EmailNotificationHandler = @ptrCast(@alignCast(ptr));
        
        switch (event) {
            .user_registered => |e| {
                try self.email_service.sendWelcomeEmail(e.email);
            },
            .user_email_changed => |e| {
                try self.email_service.sendEmailVerification(e.new_email);
            },
            else => {}, // 忽略其他事件
        }
    }
};
```
## 错误处理与内存管理

### 5.1 现代错误处理模式

#### 5.1.1 分层错误处理
```zig
// 领域层错误
pub const DomainError = error{
    // 业务规则错误
    InvalidEmail,
    UsernameTooShort,
    PasswordTooWeak,
    EmailAlreadyExists,
    UsernameAlreadyExists,
    
    // 聚合错误
    AggregateNotFound,
    ConcurrencyConflict,
    InvariantViolation,
};

// 应用层错误
pub const ApplicationError = error{
    // 用例错误
    UseCaseExecutionFailed,
    ValidationFailed,
    AuthorizationFailed,
    
    // 服务错误
    ExternalServiceUnavailable,
    ConfigurationError,
} || DomainError;

// API层错误
pub const ApiError = error{
    // HTTP相关错误
    InvalidRequestFormat,
    MissingRequiredParameter,
    UnsupportedMediaType,
    RateLimitExceeded,
} || ApplicationError;

// 错误映射
pub fn mapToHttpStatus(err: anyerror) u16 {
    return switch (err) {
        // 4xx 客户端错误
        error.InvalidEmail,
        error.UsernameTooShort,
        error.PasswordTooWeak,
        error.ValidationFailed,
        error.InvalidRequestFormat,
        error.MissingRequiredParameter => 400, // Bad Request
        
        error.AuthorizationFailed => 401, // Unauthorized
        error.RateLimitExceeded => 429, // Too Many Requests
        
        error.EmailAlreadyExists,
        error.UsernameAlreadyExists => 409, // Conflict
        
        error.AggregateNotFound => 404, // Not Found
        
        // 5xx 服务器错误
        error.ExternalServiceUnavailable => 503, // Service Unavailable
        error.ConfigurationError => 500, // Internal Server Error
        
        else => 500, // Internal Server Error
    };
}
```

#### 5.1.2 Result 模式
```zig
// shared/result.zig
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,
        
        const Self = @This();
        
        pub fn isOk(self: Self) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }
        
        pub fn isErr(self: Self) bool {
            return !self.isOk();
        }
        
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |value| value,
                .err => @panic("Called unwrap on error result"),
            };
        }
        
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |value| value,
                .err => default,
            };
        }
        
        pub fn map(self: Self, comptime U: type, func: fn(T) U) Result(U, E) {
            return switch (self) {
                .ok => |value| .{ .ok = func(value) },
                .err => |e| .{ .err = e },
            };
        }
        
        pub fn mapErr(self: Self, comptime F: type, func: fn(E) F) Result(T, F) {
            return switch (self) {
                .ok => |value| .{ .ok = value },
                .err => |e| .{ .err = func(e) },
            };
        }
    };
}

// 使用示例
pub fn parseUserId(input: []const u8) Result(i32, ParseError) {
    const id = std.fmt.parseInt(i32, input, 10) catch |err| {
        return .{ .err = switch (err) {
            error.InvalidCharacter => .InvalidFormat,
            error.Overflow => .ValueTooLarge,
        }};
    };
    
    if (id <= 0) {
        return .{ .err = .InvalidValue };
    }
    
    return .{ .ok = id };
}

const ParseError = enum {
    InvalidFormat,
    ValueTooLarge,
    InvalidValue,
};
```

#### 5.1.3 错误上下文
```zig
// shared/error_context.zig
pub const ErrorContext = struct {
    message: []const u8,
    file: []const u8,
    line: u32,
    function: []const u8,
    cause: ?*ErrorContext = null,
    
    pub fn create(
        allocator: Allocator,
        message: []const u8,
        comptime file: []const u8,
        comptime line: u32,
        comptime function: []const u8,
        cause: ?*ErrorContext,
    ) !*ErrorContext {
        const ctx = try allocator.create(ErrorContext);
        ctx.* = .{
            .message = try allocator.dupe(u8, message),
            .file = file,
            .line = line,
            .function = function,
            .cause = cause,
        };
        return ctx;
    }
    
    pub fn deinit(self: *ErrorContext, allocator: Allocator) void {
        allocator.free(self.message);
        if (self.cause) |cause| {
            cause.deinit(allocator);
            allocator.destroy(cause);
        }
        allocator.destroy(self);
    }
    
    pub fn format(self: *const ErrorContext, writer: anytype) !void {
        try writer.print("Error: {s}\n", .{self.message});
        try writer.print("  at {s}:{d} in {s}\n", .{ self.file, self.line, self.function });
        
        if (self.cause) |cause| {
            try writer.writeAll("Caused by:\n");
            try cause.format(writer);
        }
    }
};

// 错误包装宏
pub fn wrapError(
    allocator: Allocator,
    err: anyerror,
    message: []const u8,
    comptime file: []const u8,
    comptime line: u32,
    comptime function: []const u8,
) !*ErrorContext {
    return ErrorContext.create(allocator, message, file, line, function, null);
}

// 使用示例
pub fn createUser(allocator: Allocator, data: UserCreateData) !User {
    const user = userService.create(data) catch |err| {
        const ctx = try wrapError(
            allocator,
            err,
            "Failed to create user",
            @src().file,
            @src().line,
            @src().fn_name,
        );
        return error.UserCreationFailed;
    };
    
    return user;
}
```

### 5.2 内存管理最佳实践

#### 5.2.1 分配器策略
```zig
// shared/allocators.zig
pub const AllocatorStrategy = struct {
    // 长期存储：使用 GPA
    pub fn createPersistent() std.mem.Allocator {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        return gpa.allocator();
    }
    
    // 请求处理：使用 Arena
    pub fn createRequestScoped(parent: std.mem.Allocator) std.heap.ArenaAllocator {
        return std.heap.ArenaAllocator.init(parent);
    }
    
    // 高频小对象：使用 Pool
    pub fn createPooled(comptime T: type, parent: std.mem.Allocator, count: usize) !std.heap.MemoryPool(T) {
        return std.heap.MemoryPool(T).init(parent, count);
    }
    
    // 固定大小缓冲区：使用 FixedBuffer
    pub fn createFixed(buffer: []u8) std.heap.FixedBufferAllocator {
        return std.heap.FixedBufferAllocator.init(buffer);
    }
};

// 使用示例
pub const RequestProcessor = struct {
    persistent_allocator: std.mem.Allocator,
    
    pub fn processRequest(self: *RequestProcessor, request: Request) !Response {
        // 为请求创建临时分配器
        var arena = AllocatorStrategy.createRequestScoped(self.persistent_allocator);
        defer arena.deinit();
        const temp_allocator = arena.allocator();
        
        // 所有临时分配使用 arena
        const parsed_data = try parseRequest(temp_allocator, request);
        const processed = try processData(temp_allocator, parsed_data);
        
        // 返回结果需要复制到持久分配器
        return try copyResponse(self.persistent_allocator, processed);
    }
};
```

#### 5.2.2 RAII 模式
```zig
// shared/raii.zig
pub fn RAII(comptime T: type) type {
    return struct {
        const Self = @This();
        
        resource: T,
        cleanup_fn: *const fn (*T) void,
        
        pub fn init(resource: T, cleanup_fn: *const fn (*T) void) Self {
            return .{
                .resource = resource,
                .cleanup_fn = cleanup_fn,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.cleanup_fn(&self.resource);
        }
        
        pub fn get(self: *Self) *T {
            return &self.resource;
        }
    };
}

// 使用示例
pub const FileHandle = struct {
    file: std.fs.File,
    
    pub fn open(path: []const u8) !RAII(FileHandle) {
        const file = try std.fs.cwd().openFile(path, .{});
        const handle = FileHandle{ .file = file };
        
        return RAII(FileHandle).init(handle, cleanup);
    }
    
    fn cleanup(self: *FileHandle) void {
        self.file.close();
    }
};

// 使用
pub fn readConfig(path: []const u8) ![]u8 {
    var file_handle = try FileHandle.open(path);
    defer file_handle.deinit();
    
    const file = file_handle.get();
    return try file.file.readToEndAlloc(allocator, 1024 * 1024);
}
```

#### 5.2.3 内存池管理
```zig
// shared/memory_pool.zig
pub fn ObjectPool(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: T,
            next: ?*Node = null,
        };
        
        allocator: std.mem.Allocator,
        free_list: ?*Node = null,
        allocated_nodes: std.ArrayListUnmanaged(*Node) = .{},
        mutex: std.Thread.Mutex = .{},
        
        pub fn init(allocator: std.mem.Allocator, initial_size: usize) !Self {
            var pool = Self{
                .allocator = allocator,
            };
            
            // 预分配对象
            try pool.grow(initial_size);
            return pool;
        }
        
        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            for (self.allocated_nodes.items) |node| {
                self.allocator.destroy(node);
            }
            self.allocated_nodes.deinit(self.allocator);
        }
        
        pub fn acquire(self: *Self) !*T {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            if (self.free_list) |node| {
                self.free_list = node.next;
                return &node.data;
            }
            
            // 池为空，扩容
            try self.grow(10);
            return self.acquire();
        }
        
        pub fn release(self: *Self, obj: *T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            const node = @fieldParentPtr(Node, "data", obj);
            node.next = self.free_list;
            self.free_list = node;
        }
        
        fn grow(self: *Self, count: usize) !void {
            for (0..count) |_| {
                const node = try self.allocator.create(Node);
                node.* = .{ .data = std.mem.zeroes(T) };
                
                try self.allocated_nodes.append(self.allocator, node);
                
                node.next = self.free_list;
                self.free_list = node;
            }
        }
    };
}

// 使用示例
var user_pool: ObjectPool(User) = undefined;

pub fn initUserPool(allocator: std.mem.Allocator) !void {
    user_pool = try ObjectPool(User).init(allocator, 100);
}

pub fn createUserFromPool() !*User {
    const user = try user_pool.acquire();
    user.* = std.mem.zeroes(User); // 重置状态
    return user;
}

pub fn releaseUser(user: *User) void {
    user_pool.release(user);
}
```

### 5.3 性能监控与内存追踪

```zig
// shared/performance.zig
pub const PerformanceMonitor = struct {
    allocator: std.mem.Allocator,
    metrics: std.StringHashMap(Metric),
    
    const Metric = struct {
        count: u64 = 0,
        total_time: u64 = 0,
        min_time: u64 = std.math.maxInt(u64),
        max_time: u64 = 0,
        
        pub fn record(self: *Metric, duration: u64) void {
            self.count += 1;
            self.total_time += duration;
            self.min_time = @min(self.min_time, duration);
            self.max_time = @max(self.max_time, duration);
        }
        
        pub fn average(self: Metric) f64 {
            if (self.count == 0) return 0;
            return @as(f64, @floatFromInt(self.total_time)) / @as(f64, @floatFromInt(self.count));
        }
    };
    
    pub fn init(allocator: std.mem.Allocator) PerformanceMonitor {
        return .{
            .allocator = allocator,
            .metrics = std.StringHashMap(Metric).init(allocator),
        };
    }
    
    pub fn deinit(self: *PerformanceMonitor) void {
        self.metrics.deinit();
    }
    
    pub fn startTimer(self: *PerformanceMonitor, name: []const u8) Timer {
        return Timer{
            .monitor = self,
            .name = name,
            .start_time = std.time.nanoTimestamp(),
        };
    }
    
    pub const Timer = struct {
        monitor: *PerformanceMonitor,
        name: []const u8,
        start_time: i128,
        
        pub fn stop(self: Timer) void {
            const end_time = std.time.nanoTimestamp();
            const duration = @as(u64, @intCast(end_time - self.start_time));
            
            const result = self.monitor.metrics.getOrPut(self.name) catch return;
            if (!result.found_existing) {
                result.value_ptr.* = .{};
            }
            result.value_ptr.record(duration);
        }
    };
    
    pub fn getMetrics(self: *PerformanceMonitor) std.StringHashMap(Metric) {
        return self.metrics;
    }
};

// 使用示例
var perf_monitor: PerformanceMonitor = undefined;

pub fn initPerformanceMonitoring(allocator: std.mem.Allocator) void {
    perf_monitor = PerformanceMonitor.init(allocator);
}

pub fn createUser(data: UserCreateData) !User {
    const timer = perf_monitor.startTimer("create_user");
    defer timer.stop();
    
    // 实际的用户创建逻辑
    return doCreateUser(data);
}
```
## API设计规范

### 6.1 RESTful API 设计原则

#### 6.1.1 资源导向设计
```zig
// ✅ 推荐：资源导向的 URL 设计
// GET    /api/v1/users              # 获取用户列表
// POST   /api/v1/users              # 创建用户
// GET    /api/v1/users/{id}         # 获取特定用户
// PUT    /api/v1/users/{id}         # 完整更新用户
// PATCH  /api/v1/users/{id}         # 部分更新用户
// DELETE /api/v1/users/{id}         # 删除用户

// 嵌套资源
// GET    /api/v1/users/{id}/posts   # 获取用户的文章
// POST   /api/v1/users/{id}/posts   # 为用户创建文章

// ❌ 避免：动词导向的 URL
// POST   /api/v1/createUser
// POST   /api/v1/getUserById
// POST   /api/v1/updateUser
```

#### 6.1.2 统一响应格式
```zig
// api/dto/response.zig
pub const ApiResponse = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value = null,
    meta: ?ResponseMeta = null,
    
    pub const ResponseMeta = struct {
        timestamp: i64,
        request_id: []const u8,
        version: []const u8 = "v1",
    };
    
    // 成功响应
    pub fn success(allocator: Allocator, data: anytype) !ApiResponse {
        return .{
            .code = 0,
            .message = "success",
            .data = try std.json.valueFromArbitrary(allocator, data),
            .meta = .{
                .timestamp = std.time.timestamp(),
                .request_id = generateRequestId(),
            },
        };
    }
    
    // 错误响应
    pub fn error(code: i32, message: []const u8) ApiResponse {
        return .{
            .code = code,
            .message = message,
            .meta = .{
                .timestamp = std.time.timestamp(),
                .request_id = generateRequestId(),
            },
        };
    }
    
    // 分页响应
    pub fn paginated(
        allocator: Allocator,
        items: anytype,
        page: u32,
        page_size: u32,
        total: u64,
    ) !ApiResponse {
        const pagination_data = .{
            .items = items,
            .pagination = .{
                .page = page,
                .page_size = page_size,
                .total = total,
                .total_pages = (total + page_size - 1) / page_size,
                .has_next = page * page_size < total,
                .has_prev = page > 1,
            },
        };
        
        return success(allocator, pagination_data);
    }
};
```

#### 6.1.3 HTTP 状态码规范
```zig
// shared/http_status.zig
pub const HttpStatus = enum(u16) {
    // 2xx 成功
    ok = 200,
    created = 201,
    accepted = 202,
    no_content = 204,
    
    // 3xx 重定向
    moved_permanently = 301,
    found = 302,
    not_modified = 304,
    
    // 4xx 客户端错误
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    unprocessable_entity = 422,
    too_many_requests = 429,
    
    // 5xx 服务器错误
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
    
    pub fn phrase(self: HttpStatus) []const u8 {
        return switch (self) {
            .ok => "OK",
            .created => "Created",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .conflict => "Conflict",
            .unprocessable_entity => "Unprocessable Entity",
            .internal_server_error => "Internal Server Error",
            else => "Unknown",
        };
    }
};
```

#### 6.1.4 请求验证与中间件
```zig
// api/middleware/validation.zig
pub const ValidationMiddleware = struct {
    pub fn validate(comptime T: type) MiddlewareHandler {
        return struct {
            pub fn handle(req: *Request, res: *Response, next: NextFn) !void {
                const body = req.body() orelse {
                    try res.status(.bad_request).json(.{
                        .code = 400,
                        .message = "Request body is required",
                    });
                    return;
                };
                
                const dto = std.json.parseFromSlice(T, req.allocator, body, .{}) catch {
                    try res.status(.bad_request).json(.{
                        .code = 400,
                        .message = "Invalid JSON format",
                    });
                    return;
                };
                defer dto.deinit();
                
                // 验证 DTO
                dto.value.validate() catch |err| {
                    const error_msg = switch (err) {
                        error.InvalidEmail => "Invalid email format",
                        error.PasswordTooWeak => "Password must be at least 8 characters",
                        error.UsernameTooShort => "Username must be at least 3 characters",
                        else => "Validation failed",
                    };
                    
                    try res.status(.unprocessable_entity).json(.{
                        .code = 422,
                        .message = error_msg,
                    });
                    return;
                };
                
                // 将验证后的数据存储到请求上下文
                req.setContext("validated_data", dto.value);
                try next(req, res);
            }
        }.handle;
    }
};

// 使用示例
pub fn setupRoutes(app: *App) !void {
    const validation = ValidationMiddleware.validate(CreateUserDto);
    
    try app.post("/api/v1/users", &[_]MiddlewareHandler{
        validation,
        UserController.create,
    });
}
```

### 6.2 GraphQL 支持（未来扩展）

```zig
// api/graphql/schema.zig
pub const GraphQLSchema = struct {
    pub const UserType = struct {
        id: i32,
        username: []const u8,
        email: []const u8,
        created_at: i64,
        
        // 解析器
        pub fn posts(self: @This(), ctx: *GraphQLContext) ![]Post {
            return ctx.post_service.findByUserId(self.id);
        }
    };
    
    pub const Query = struct {
        pub fn user(ctx: *GraphQLContext, args: struct { id: i32 }) !?UserType {
            return ctx.user_service.findById(args.id);
        }
        
        pub fn users(ctx: *GraphQLContext, args: struct {
            first: ?i32 = null,
            after: ?[]const u8 = null,
        }) !Connection(UserType) {
            return ctx.user_service.findMany(.{
                .limit = args.first orelse 10,
                .cursor = args.after,
            });
        }
    };
    
    pub const Mutation = struct {
        pub fn createUser(ctx: *GraphQLContext, args: struct {
            input: CreateUserInput,
        }) !UserType {
            return ctx.user_service.create(args.input);
        }
    };
};
```

## 测试驱动开发

### 7.1 测试金字塔

```
    ┌─────────────────┐
    │   E2E Tests     │ ← 少量，覆盖关键用户流程
    │   (5-10%)       │
    ├─────────────────┤
    │ Integration     │ ← 中等数量，测试模块协作
    │ Tests (20-30%)  │
    ├─────────────────┤
    │   Unit Tests    │ ← 大量，测试单个函数/类
    │   (60-70%)      │
    └─────────────────┘
```

#### 7.1.1 单元测试
```zig
// tests/unit/user_service_test.zig
const std = @import("std");
const testing = std.testing;
const UserService = @import("../../application/services/user_service.zig");
const MockUserRepository = @import("../mocks/mock_user_repository.zig");

test "UserService.createUser - success" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Arrange
    var mock_repo = MockUserRepository.init(allocator);
    mock_repo.expectFindByEmail("test@example.com", null);
    mock_repo.expectSave(User{
        .username = "testuser",
        .email = "test@example.com",
    }, User{
        .id = 1,
        .username = "testuser",
        .email = "test@example.com",
        .created_at = 1234567890,
    });
    
    var user_service = UserService.init(allocator, mock_repo.toInterface());
    
    // Act
    const result = try user_service.createUser(.{
        .username = "testuser",
        .email = "test@example.com",
        .password = "password123",
    });
    
    // Assert
    try testing.expect(result.id == 1);
    try testing.expectEqualStrings("testuser", result.username);
    try testing.expectEqualStrings("test@example.com", result.email);
    
    // Verify mock expectations
    try mock_repo.verifyExpectations();
}

test "UserService.createUser - email already exists" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Arrange
    var mock_repo = MockUserRepository.init(allocator);
    mock_repo.expectFindByEmail("test@example.com", User{
        .id = 999,
        .username = "existing",
        .email = "test@example.com",
    });
    
    var user_service = UserService.init(allocator, mock_repo.toInterface());
    
    // Act & Assert
    try testing.expectError(
        error.EmailAlreadyExists,
        user_service.createUser(.{
            .username = "testuser",
            .email = "test@example.com",
            .password = "password123",
        })
    );
}
```

#### 7.1.2 集成测试
```zig
// tests/integration/user_api_test.zig
const std = @import("std");
const testing = std.testing;
const TestServer = @import("../helpers/test_server.zig");
const TestDatabase = @import("../helpers/test_database.zig");

test "POST /api/v1/users - create user successfully" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Setup test database
    var test_db = try TestDatabase.init(allocator);
    defer test_db.deinit();
    
    // Setup test server
    var server = try TestServer.init(allocator, test_db.database);
    defer server.deinit();
    
    // Prepare request
    const request_body = 
        \\{
        \\  "username": "testuser",
        \\  "email": "test@example.com",
        \\  "password": "password123"
        \\}
    ;
    
    // Make request
    const response = try server.post("/api/v1/users", request_body);
    defer response.deinit();
    
    // Assert response
    try testing.expect(response.status_code == 201);
    
    const json = try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        response.body,
        .{}
    );
    defer json.deinit();
    
    try testing.expect(json.value.object.get("code").?.integer == 0);
    try testing.expectEqualStrings("success", json.value.object.get("message").?.string);
    
    const data = json.value.object.get("data").?.object;
    try testing.expectEqualStrings("testuser", data.get("username").?.string);
    try testing.expectEqualStrings("test@example.com", data.get("email").?.string);
    
    // Verify database state
    const user = try test_db.findUserByEmail("test@example.com");
    try testing.expect(user != null);
    try testing.expectEqualStrings("testuser", user.?.username);
}
```

#### 7.1.3 端到端测试
```zig
// tests/e2e/user_registration_flow_test.zig
const std = @import("std");
const testing = std.testing;
const WebDriver = @import("../helpers/webdriver.zig");

test "User registration flow - complete journey" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var driver = try WebDriver.init(allocator);
    defer driver.deinit();
    
    // 1. Navigate to registration page
    try driver.navigate("http://localhost:3000/register");
    
    // 2. Fill registration form
    try driver.findElement("#username").sendKeys("testuser");
    try driver.findElement("#email").sendKeys("test@example.com");
    try driver.findElement("#password").sendKeys("password123");
    try driver.findElement("#confirm-password").sendKeys("password123");
    
    // 3. Submit form
    try driver.findElement("#register-button").click();
    
    // 4. Verify success message
    const success_message = try driver.findElement(".success-message");
    try testing.expectEqualStrings(
        "Registration successful! Please check your email.",
        try success_message.getText()
    );
    
    // 5. Verify redirect to login page
    try driver.waitForUrl("http://localhost:3000/login");
    
    // 6. Verify email was sent (mock email service)
    const email_service = try driver.getMockEmailService();
    try testing.expect(email_service.getEmailCount() == 1);
    
    const sent_email = email_service.getLastEmail();
    try testing.expectEqualStrings("test@example.com", sent_email.to);
    try testing.expect(std.mem.indexOf(u8, sent_email.subject, "Welcome") != null);
}
```

### 7.2 测试工具与辅助函数

#### 7.2.1 Mock 对象
```zig
// tests/mocks/mock_user_repository.zig
pub const MockUserRepository = struct {
    allocator: Allocator,
    expectations: std.ArrayListUnmanaged(Expectation),
    call_count: usize = 0,
    
    const Expectation = union(enum) {
        find_by_email: struct {
            email: []const u8,
            result: ?User,
        },
        save: struct {
            input: User,
            result: User,
        },
    };
    
    pub fn init(allocator: Allocator) MockUserRepository {
        return .{
            .allocator = allocator,
            .expectations = .{},
        };
    }
    
    pub fn deinit(self: *MockUserRepository) void {
        self.expectations.deinit(self.allocator);
    }
    
    pub fn expectFindByEmail(self: *MockUserRepository, email: []const u8, result: ?User) void {
        self.expectations.append(self.allocator, .{
            .find_by_email = .{ .email = email, .result = result },
        }) catch unreachable;
    }
    
    pub fn expectSave(self: *MockUserRepository, input: User, result: User) void {
        self.expectations.append(self.allocator, .{
            .save = .{ .input = input, .result = result },
        }) catch unreachable;
    }
    
    pub fn toInterface(self: *MockUserRepository) UserRepository {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .findByEmail = findByEmailImpl,
                .save = saveImpl,
                // ... 其他方法
            },
        };
    }
    
    fn findByEmailImpl(ptr: *anyopaque, email: []const u8) !?User {
        const self: *MockUserRepository = @ptrCast(@alignCast(ptr));
        
        if (self.call_count >= self.expectations.items.len) {
            @panic("Unexpected call to findByEmail");
        }
        
        const expectation = self.expectations.items[self.call_count];
        self.call_count += 1;
        
        switch (expectation) {
            .find_by_email => |exp| {
                if (!std.mem.eql(u8, email, exp.email)) {
                    @panic("findByEmail called with unexpected email");
                }
                return exp.result;
            },
            else => @panic("Expected findByEmail call"),
        }
    }
    
    pub fn verifyExpectations(self: *MockUserRepository) !void {
        if (self.call_count != self.expectations.items.len) {
            return error.UnmetExpectations;
        }
    }
};
```

#### 7.2.2 测试数据构建器
```zig
// tests/builders/user_builder.zig
pub const UserBuilder = struct {
    user: User,
    
    pub fn init() UserBuilder {
        return .{
            .user = .{
                .id = 1,
                .username = "testuser",
                .email = "test@example.com",
                .password_hash = "hashed_password",
                .created_at = 1234567890,
                .is_active = true,
            },
        };
    }
    
    pub fn withId(self: UserBuilder, id: i32) UserBuilder {
        var result = self;
        result.user.id = id;
        return result;
    }
    
    pub fn withUsername(self: UserBuilder, username: []const u8) UserBuilder {
        var result = self;
        result.user.username = username;
        return result;
    }
    
    pub fn withEmail(self: UserBuilder, email: []const u8) UserBuilder {
        var result = self;
        result.user.email = email;
        return result;
    }
    
    pub fn inactive(self: UserBuilder) UserBuilder {
        var result = self;
        result.user.is_active = false;
        return result;
    }
    
    pub fn build(self: UserBuilder) User {
        return self.user;
    }
};

// 使用示例
test "user builder example" {
    const user = UserBuilder.init()
        .withId(42)
        .withUsername("john_doe")
        .withEmail("john@example.com")
        .inactive()
        .build();
    
    try testing.expect(user.id == 42);
    try testing.expectEqualStrings("john_doe", user.username);
    try testing.expect(!user.is_active);
}
```

### 7.3 属性测试（Property-Based Testing）

```zig
// tests/property/user_property_test.zig
const std = @import("std");
const testing = std.testing;
const PropertyTesting = @import("../helpers/property_testing.zig");

test "User.validate - property: valid email always passes validation" {
    var prng = std.rand.DefaultPrng.init(12345);
    const random = prng.random();
    
    const property = PropertyTesting.forAll(
        PropertyTesting.emailGenerator(random),
        struct {
            fn test_property(email: []const u8) !void {
                const user = User{
                    .username = "testuser",
                    .email = email,
                    .password_hash = "hash",
                    .created_at = std.time.timestamp(),
                };
                
                // 如果 email 是有效的，验证应该通过
                if (isValidEmail(email)) {
                    try testing.expect(user.validate());
                }
            }
        }.test_property,
    );
    
    try PropertyTesting.check(testing.allocator, property, 100);
}

// tests/helpers/property_testing.zig
pub const PropertyTesting = struct {
    pub fn forAll(
        generator: anytype,
        test_fn: anytype,
    ) Property(@TypeOf(generator), @TypeOf(test_fn)) {
        return .{
            .generator = generator,
            .test_fn = test_fn,
        };
    }
    
    pub fn Property(comptime G: type, comptime F: type) type {
        return struct {
            generator: G,
            test_fn: F,
        };
    }
    
    pub fn check(
        allocator: Allocator,
        property: anytype,
        iterations: u32,
    ) !void {
        for (0..iterations) |_| {
            const test_data = try property.generator.generate(allocator);
            defer if (@hasDecl(@TypeOf(test_data), "deinit")) test_data.deinit();
            
            try property.test_fn(test_data);
        }
    }
    
    pub fn emailGenerator(random: std.rand.Random) EmailGenerator {
        return .{ .random = random };
    }
    
    pub const EmailGenerator = struct {
        random: std.rand.Random,
        
        pub fn generate(self: @This(), allocator: Allocator) ![]const u8 {
            const domains = [_][]const u8{ "example.com", "test.org", "demo.net" };
            const domain = domains[self.random.uintLessThan(usize, domains.len)];
            
            const username_len = self.random.uintLessThan(u8, 10) + 3;
            var username = try allocator.alloc(u8, username_len);
            
            for (username) |*c| {
                c.* = 'a' + self.random.uintLessThan(u8, 26);
            }
            
            return try std.fmt.allocPrint(allocator, "{s}@{s}", .{ username, domain });
        }
    };
};
```
## 性能与可观测性

### 8.1 性能监控

#### 8.1.1 应用性能监控 (APM)
```zig
// shared/monitoring/apm.zig
pub const APM = struct {
    allocator: Allocator,
    metrics: MetricsCollector,
    tracer: Tracer,
    
    pub fn init(allocator: Allocator) !APM {
        return .{
            .allocator = allocator,
            .metrics = try MetricsCollector.init(allocator),
            .tracer = try Tracer.init(allocator),
        };
    }
    
    pub fn startTransaction(self: *APM, name: []const u8) Transaction {
        return Transaction{
            .apm = self,
            .name = name,
            .start_time = std.time.nanoTimestamp(),
            .span_id = generateSpanId(),
        };
    }
    
    pub const Transaction = struct {
        apm: *APM,
        name: []const u8,
        start_time: i128,
        span_id: u64,
        spans: std.ArrayListUnmanaged(Span) = .{},
        
        pub fn startSpan(self: *Transaction, operation: []const u8) Span {
            return Span{
                .transaction = self,
                .operation = operation,
                .start_time = std.time.nanoTimestamp(),
                .span_id = generateSpanId(),
                .parent_id = self.span_id,
            };
        }
        
        pub fn finish(self: *Transaction) void {
            const duration = std.time.nanoTimestamp() - self.start_time;
            
            // 记录事务指标
            self.apm.metrics.recordTransaction(.{
                .name = self.name,
                .duration = duration,
                .span_count = self.spans.items.len,
            });
            
            // 发送追踪数据
            self.apm.tracer.sendTransaction(self.*);
            
            // 清理
            self.spans.deinit(self.apm.allocator);
        }
    };
    
    pub const Span = struct {
        transaction: *Transaction,
        operation: []const u8,
        start_time: i128,
        span_id: u64,
        parent_id: u64,
        tags: std.StringHashMap([]const u8) = .{},
        
        pub fn setTag(self: *Span, key: []const u8, value: []const u8) !void {
            try self.tags.put(key, value);
        }
        
        pub fn finish(self: *Span) !void {
            const duration = std.time.nanoTimestamp() - self.start_time;
            
            try self.transaction.spans.append(self.transaction.apm.allocator, self.*);
            
            // 记录 span 指标
            self.transaction.apm.metrics.recordSpan(.{
                .operation = self.operation,
                .duration = duration,
            });
        }
    };
};

// 使用示例
pub fn handleUserRequest(apm: *APM, request: Request) !Response {
    var transaction = apm.startTransaction("handle_user_request");
    defer transaction.finish();
    
    // 数据库查询 span
    var db_span = transaction.startSpan("database.query");
    try db_span.setTag("query", "SELECT * FROM users WHERE id = ?");
    const user = try database.findUser(request.user_id);
    try db_span.finish();
    
    // 业务逻辑 span
    var business_span = transaction.startSpan("business.process");
    const result = try processUser(user);
    try business_span.finish();
    
    return result;
}
```

#### 8.1.2 指标收集
```zig
// shared/monitoring/metrics.zig
pub const MetricsCollector = struct {
    allocator: Allocator,
    counters: std.StringHashMap(Counter),
    histograms: std.StringHashMap(Histogram),
    gauges: std.StringHashMap(Gauge),
    
    pub const Counter = struct {
        value: std.atomic.Atomic(u64) = std.atomic.Atomic(u64).init(0),
        labels: std.StringHashMap([]const u8),
        
        pub fn increment(self: *Counter) void {
            _ = self.value.fetchAdd(1, .Monotonic);
        }
        
        pub fn add(self: *Counter, delta: u64) void {
            _ = self.value.fetchAdd(delta, .Monotonic);
        }
        
        pub fn get(self: *Counter) u64 {
            return self.value.load(.Monotonic);
        }
    };
    
    pub const Histogram = struct {
        buckets: []f64,
        counts: []std.atomic.Atomic(u64),
        sum: std.atomic.Atomic(f64) = std.atomic.Atomic(f64).init(0),
        count: std.atomic.Atomic(u64) = std.atomic.Atomic(u64).init(0),
        
        pub fn observe(self: *Histogram, value: f64) void {
            // 更新总和和计数
            _ = self.sum.fetchAdd(value, .Monotonic);
            _ = self.count.fetchAdd(1, .Monotonic);
            
            // 找到合适的桶
            for (self.buckets, 0..) |bucket, i| {
                if (value <= bucket) {
                    _ = self.counts[i].fetchAdd(1, .Monotonic);
                    break;
                }
            }
        }
        
        pub fn quantile(self: *Histogram, q: f64) f64 {
            const total = self.count.load(.Monotonic);
            const target = @as(u64, @intFromFloat(@as(f64, @floatFromInt(total)) * q));
            
            var cumulative: u64 = 0;
            for (self.buckets, 0..) |bucket, i| {
                cumulative += self.counts[i].load(.Monotonic);
                if (cumulative >= target) {
                    return bucket;
                }
            }
            
            return self.buckets[self.buckets.len - 1];
        }
    };
    
    pub const Gauge = struct {
        value: std.atomic.Atomic(f64) = std.atomic.Atomic(f64).init(0),
        
        pub fn set(self: *Gauge, value: f64) void {
            self.value.store(value, .Monotonic);
        }
        
        pub fn get(self: *Gauge) f64 {
            return self.value.load(.Monotonic);
        }
    };
    
    pub fn recordHttpRequest(self: *MetricsCollector, method: []const u8, status: u16, duration: f64) !void {
        // 计数器：HTTP 请求总数
        const counter_key = try std.fmt.allocPrint(self.allocator, "http_requests_total_{s}_{d}", .{ method, status });
        defer self.allocator.free(counter_key);
        
        var counter = try self.getOrCreateCounter(counter_key);
        counter.increment();
        
        // 直方图：请求持续时间
        const histogram_key = try std.fmt.allocPrint(self.allocator, "http_request_duration_{s}", .{method});
        defer self.allocator.free(histogram_key);
        
        var histogram = try self.getOrCreateHistogram(histogram_key);
        histogram.observe(duration);
    }
    
    pub fn exportPrometheus(self: *MetricsCollector, writer: anytype) !void {
        // 导出计数器
        var counter_iter = self.counters.iterator();
        while (counter_iter.next()) |entry| {
            try writer.print("# TYPE {s} counter\n", .{entry.key_ptr.*});
            try writer.print("{s} {d}\n", .{ entry.key_ptr.*, entry.value_ptr.get() });
        }
        
        // 导出直方图
        var histogram_iter = self.histograms.iterator();
        while (histogram_iter.next()) |entry| {
            const histogram = entry.value_ptr;
            try writer.print("# TYPE {s} histogram\n", .{entry.key_ptr.*});
            
            var cumulative: u64 = 0;
            for (histogram.buckets, 0..) |bucket, i| {
                cumulative += histogram.counts[i].load(.Monotonic);
                try writer.print("{s}_bucket{{le=\"{d}\"}} {d}\n", .{ entry.key_ptr.*, bucket, cumulative });
            }
            
            try writer.print("{s}_sum {d}\n", .{ entry.key_ptr.*, histogram.sum.load(.Monotonic) });
            try writer.print("{s}_count {d}\n", .{ entry.key_ptr.*, histogram.count.load(.Monotonic) });
        }
    }
};
```

### 8.2 日志系统

#### 8.2.1 结构化日志
```zig
// shared/logging/structured_logger.zig
pub const StructuredLogger = struct {
    allocator: Allocator,
    level: LogLevel,
    outputs: std.ArrayListUnmanaged(LogOutput),
    
    pub const LogLevel = enum(u8) {
        trace = 0,
        debug = 1,
        info = 2,
        warn = 3,
        err = 4,
        fatal = 5,
        
        pub fn toString(self: LogLevel) []const u8 {
            return switch (self) {
                .trace => "TRACE",
                .debug => "DEBUG",
                .info => "INFO",
                .warn => "WARN",
                .err => "ERROR",
                .fatal => "FATAL",
            };
        }
    };
    
    pub const LogEntry = struct {
        timestamp: i64,
        level: LogLevel,
        message: []const u8,
        fields: std.StringHashMap(std.json.Value),
        source: SourceLocation,
        
        pub const SourceLocation = struct {
            file: []const u8,
            line: u32,
            function: []const u8,
        };
        
        pub fn toJson(self: LogEntry, allocator: Allocator) ![]const u8 {
            var json_obj = std.json.ObjectMap.init(allocator);
            defer json_obj.deinit();
            
            try json_obj.put("timestamp", .{ .integer = self.timestamp });
            try json_obj.put("level", .{ .string = self.level.toString() });
            try json_obj.put("message", .{ .string = self.message });
            try json_obj.put("source", .{
                .object = blk: {
                    var source_obj = std.json.ObjectMap.init(allocator);
                    try source_obj.put("file", .{ .string = self.source.file });
                    try source_obj.put("line", .{ .integer = @intCast(self.source.line) });
                    try source_obj.put("function", .{ .string = self.source.function });
                    break :blk source_obj;
                },
            });
            
            // 添加自定义字段
            var fields_iter = self.fields.iterator();
            while (fields_iter.next()) |entry| {
                try json_obj.put(entry.key_ptr.*, entry.value_ptr.*);
            }
            
            return try std.json.stringifyAlloc(allocator, .{ .object = json_obj }, .{});
        }
    };
    
    pub const LogOutput = union(enum) {
        console: ConsoleOutput,
        file: FileOutput,
        network: NetworkOutput,
        
        pub const ConsoleOutput = struct {
            colored: bool = true,
        };
        
        pub const FileOutput = struct {
            path: []const u8,
            max_size: usize = 100 * 1024 * 1024, // 100MB
            max_files: u32 = 10,
        };
        
        pub const NetworkOutput = struct {
            endpoint: []const u8,
            batch_size: u32 = 100,
            flush_interval: u64 = 5000, // 5 seconds
        };
    };
    
    pub fn log(
        self: *StructuredLogger,
        level: LogLevel,
        comptime message: []const u8,
        fields: anytype,
        comptime src: std.builtin.SourceLocation,
    ) !void {
        if (@intFromEnum(level) < @intFromEnum(self.level)) return;
        
        var field_map = std.StringHashMap(std.json.Value).init(self.allocator);
        defer field_map.deinit();
        
        // 转换字段到 JSON 值
        inline for (std.meta.fields(@TypeOf(fields))) |field| {
            const value = @field(fields, field.name);
            const json_value = try valueToJson(self.allocator, value);
            try field_map.put(field.name, json_value);
        }
        
        const entry = LogEntry{
            .timestamp = std.time.milliTimestamp(),
            .level = level,
            .message = message,
            .fields = field_map,
            .source = .{
                .file = src.file,
                .line = src.line,
                .function = src.fn_name,
            },
        };
        
        // 输出到所有配置的输出
        for (self.outputs.items) |output| {
            try self.writeToOutput(output, entry);
        }
    }
    
    fn valueToJson(allocator: Allocator, value: anytype) !std.json.Value {
        const T = @TypeOf(value);
        return switch (@typeInfo(T)) {
            .Int => .{ .integer = @intCast(value) },
            .Float => .{ .float = @floatCast(value) },
            .Bool => .{ .bool = value },
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Slice => if (ptr_info.child == u8) .{ .string = value } else .{ .string = "unsupported" },
                else => .{ .string = "unsupported" },
            },
            else => .{ .string = "unsupported" },
        };
    }
};

// 使用示例
var logger: StructuredLogger = undefined;

pub fn initLogging(allocator: Allocator) !void {
    logger = StructuredLogger.init(allocator, .info);
    
    try logger.addOutput(.{ .console = .{ .colored = true } });
    try logger.addOutput(.{ .file = .{ .path = "logs/app.log" } });
}

pub fn handleUserLogin(user_id: i32, ip_address: []const u8) !void {
    try logger.log(.info, "User login attempt", .{
        .user_id = user_id,
        .ip_address = ip_address,
        .user_agent = "Mozilla/5.0...",
    }, @src());
    
    // 业务逻辑...
    
    try logger.log(.info, "User login successful", .{
        .user_id = user_id,
        .session_id = "abc123",
        .login_duration_ms = 150,
    }, @src());
}
```

### 8.3 分布式追踪

#### 8.3.1 OpenTelemetry 集成
```zig
// shared/tracing/opentelemetry.zig
pub const OpenTelemetry = struct {
    allocator: Allocator,
    tracer: Tracer,
    exporter: TraceExporter,
    
    pub const Tracer = struct {
        service_name: []const u8,
        service_version: []const u8,
        
        pub fn startSpan(self: *Tracer, name: []const u8) Span {
            return Span{
                .tracer = self,
                .name = name,
                .span_id = generateSpanId(),
                .trace_id = getCurrentTraceId() orelse generateTraceId(),
                .parent_span_id = getCurrentSpanId(),
                .start_time = std.time.nanoTimestamp(),
                .attributes = std.StringHashMap(AttributeValue).init(self.tracer.allocator),
            };
        }
    };
    
    pub const Span = struct {
        tracer: *Tracer,
        name: []const u8,
        span_id: u128,
        trace_id: u128,
        parent_span_id: ?u128,
        start_time: i128,
        end_time: ?i128 = null,
        status: SpanStatus = .ok,
        attributes: std.StringHashMap(AttributeValue),
        events: std.ArrayListUnmanaged(SpanEvent) = .{},
        
        pub const SpanStatus = enum {
            ok,
            error,
            timeout,
        };
        
        pub const AttributeValue = union(enum) {
            string: []const u8,
            int: i64,
            float: f64,
            bool: bool,
        };
        
        pub const SpanEvent = struct {
            name: []const u8,
            timestamp: i128,
            attributes: std.StringHashMap(AttributeValue),
        };
        
        pub fn setAttribute(self: *Span, key: []const u8, value: anytype) !void {
            const attr_value = switch (@TypeOf(value)) {
                []const u8 => AttributeValue{ .string = value },
                i32, i64 => AttributeValue{ .int = @intCast(value) },
                f32, f64 => AttributeValue{ .float = @floatCast(value) },
                bool => AttributeValue{ .bool = value },
                else => @compileError("Unsupported attribute type"),
            };
            
            try self.attributes.put(key, attr_value);
        }
        
        pub fn addEvent(self: *Span, name: []const u8, attributes: anytype) !void {
            var event_attrs = std.StringHashMap(AttributeValue).init(self.tracer.allocator);
            
            inline for (std.meta.fields(@TypeOf(attributes))) |field| {
                const value = @field(attributes, field.name);
                const attr_value = switch (@TypeOf(value)) {
                    []const u8 => AttributeValue{ .string = value },
                    i32, i64 => AttributeValue{ .int = @intCast(value) },
                    f32, f64 => AttributeValue{ .float = @floatCast(value) },
                    bool => AttributeValue{ .bool = value },
                    else => continue,
                };
                try event_attrs.put(field.name, attr_value);
            }
            
            try self.events.append(self.tracer.allocator, .{
                .name = name,
                .timestamp = std.time.nanoTimestamp(),
                .attributes = event_attrs,
            });
        }
        
        pub fn setStatus(self: *Span, status: SpanStatus) void {
            self.status = status;
        }
        
        pub fn finish(self: *Span) void {
            self.end_time = std.time.nanoTimestamp();
            
            // 发送到导出器
            self.tracer.exporter.export(self.*) catch |err| {
                std.log.err("Failed to export span: {}", .{err});
            };
        }
    };
    
    pub const TraceExporter = struct {
        endpoint: []const u8,
        headers: std.StringHashMap([]const u8),
        batch_size: u32 = 100,
        batch_timeout: u64 = 5000, // 5 seconds
        pending_spans: std.ArrayListUnmanaged(Span) = .{},
        
        pub fn export(self: *TraceExporter, span: Span) !void {
            try self.pending_spans.append(span);
            
            if (self.pending_spans.items.len >= self.batch_size) {
                try self.flush();
            }
        }
        
        pub fn flush(self: *TraceExporter) !void {
            if (self.pending_spans.items.len == 0) return;
            
            const json_data = try self.spansToJson();
            defer self.allocator.free(json_data);
            
            // 发送到 OTLP 端点
            try self.sendToOTLP(json_data);
            
            // 清空批次
            self.pending_spans.clearRetainingCapacity();
        }
        
        fn spansToJson(self: *TraceExporter) ![]const u8 {
            // 转换 spans 到 OTLP JSON 格式
            // 这里简化实现，实际需要完整的 OTLP 格式
            return try std.json.stringifyAlloc(self.allocator, .{
                .resourceSpans = .{
                    .resource = .{
                        .attributes = .{},
                    },
                    .scopeSpans = .{
                        .spans = self.pending_spans.items,
                    },
                },
            }, .{});
        }
    };
};

// 使用示例
var otel: OpenTelemetry = undefined;

pub fn initTracing(allocator: Allocator) !void {
    otel = try OpenTelemetry.init(allocator, .{
        .service_name = "zigcms",
        .service_version = "1.0.0",
        .exporter = .{
            .endpoint = "http://localhost:4318/v1/traces",
        },
    });
}

pub fn handleApiRequest(request: Request) !Response {
    var span = otel.tracer.startSpan("handle_api_request");
    defer span.finish();
    
    try span.setAttribute("http.method", request.method);
    try span.setAttribute("http.url", request.url);
    try span.setAttribute("user.id", request.user_id);
    
    // 数据库操作
    var db_span = otel.tracer.startSpan("database.query");
    defer db_span.finish();
    
    try db_span.setAttribute("db.system", "sqlite");
    try db_span.setAttribute("db.statement", "SELECT * FROM users WHERE id = ?");
    
    const user = database.findUser(request.user_id) catch |err| {
        span.setStatus(.error);
        try span.addEvent("database_error", .{
            .error = @errorName(err),
            .query = "SELECT * FROM users WHERE id = ?",
        });
        return err;
    };
    
    try db_span.setAttribute("db.rows_affected", 1);
    
    return processUser(user);
}
```
## 安全最佳实践

### 9.1 认证与授权

#### 9.1.1 JWT 安全实现
```zig
// shared/auth/jwt.zig
pub const JWT = struct {
    allocator: Allocator,
    secret: []const u8,
    algorithm: Algorithm = .HS256,
    
    pub const Algorithm = enum {
        HS256,
        HS384,
        HS512,
        RS256,
    };
    
    pub const Claims = struct {
        // 标准声明
        iss: ?[]const u8 = null, // issuer
        sub: ?[]const u8 = null, // subject
        aud: ?[]const u8 = null, // audience
        exp: ?i64 = null,        // expiration time
        nbf: ?i64 = null,        // not before
        iat: ?i64 = null,        // issued at
        jti: ?[]const u8 = null, // JWT ID
        
        // 自定义声明
        user_id: ?i32 = null,
        username: ?[]const u8 = null,
        roles: ?[]const []const u8 = null,
        permissions: ?[]const []const u8 = null,
        
        pub fn validate(self: Claims) !void {
            const now = std.time.timestamp();
            
            // 检查过期时间
            if (self.exp) |exp| {
                if (now >= exp) return error.TokenExpired;
            }
            
            // 检查生效时间
            if (self.nbf) |nbf| {
                if (now < nbf) return error.TokenNotYetValid;
            }
            
            // 检查必需字段
            if (self.user_id == null) return error.MissingUserId;
        }
    };
    
    pub fn sign(self: *JWT, claims: Claims) ![]const u8 {
        // 验证声明
        try claims.validate();
        
        // 创建 header
        const header = .{
            .alg = switch (self.algorithm) {
                .HS256 => "HS256",
                .HS384 => "HS384",
                .HS512 => "HS512",
                .RS256 => "RS256",
            },
            .typ = "JWT",
        };
        
        const header_json = try std.json.stringifyAlloc(self.allocator, header, .{});
        defer self.allocator.free(header_json);
        
        const payload_json = try std.json.stringifyAlloc(self.allocator, claims, .{});
        defer self.allocator.free(payload_json);
        
        // Base64URL 编码
        const header_b64 = try base64UrlEncode(self.allocator, header_json);
        defer self.allocator.free(header_b64);
        
        const payload_b64 = try base64UrlEncode(self.allocator, payload_json);
        defer self.allocator.free(payload_b64);
        
        // 创建签名数据
        const signing_input = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ header_b64, payload_b64 });
        defer self.allocator.free(signing_input);
        
        // 生成签名
        const signature = try self.createSignature(signing_input);
        defer self.allocator.free(signature);
        
        const signature_b64 = try base64UrlEncode(self.allocator, signature);
        defer self.allocator.free(signature_b64);
        
        // 组合最终 JWT
        return try std.fmt.allocPrint(self.allocator, "{s}.{s}.{s}", .{ header_b64, payload_b64, signature_b64 });
    }
    
    pub fn verify(self: *JWT, token: []const u8) !Claims {
        var parts = std.mem.split(u8, token, ".");
        
        const header_b64 = parts.next() orelse return error.InvalidTokenFormat;
        const payload_b64 = parts.next() orelse return error.InvalidTokenFormat;
        const signature_b64 = parts.next() orelse return error.InvalidTokenFormat;
        
        if (parts.next() != null) return error.InvalidTokenFormat;
        
        // 验证签名
        const signing_input = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ header_b64, payload_b64 });
        defer self.allocator.free(signing_input);
        
        const expected_signature = try self.createSignature(signing_input);
        defer self.allocator.free(expected_signature);
        
        const expected_signature_b64 = try base64UrlEncode(self.allocator, expected_signature);
        defer self.allocator.free(expected_signature_b64);
        
        if (!std.mem.eql(u8, signature_b64, expected_signature_b64)) {
            return error.InvalidSignature;
        }
        
        // 解码 payload
        const payload_json = try base64UrlDecode(self.allocator, payload_b64);
        defer self.allocator.free(payload_json);
        
        const claims = try std.json.parseFromSlice(Claims, self.allocator, payload_json, .{});
        defer claims.deinit();
        
        // 验证声明
        try claims.value.validate();
        
        return claims.value;
    }
    
    fn createSignature(self: *JWT, data: []const u8) ![]const u8 {
        return switch (self.algorithm) {
            .HS256 => try hmacSha256(self.allocator, self.secret, data),
            .HS384 => try hmacSha384(self.allocator, self.secret, data),
            .HS512 => try hmacSha512(self.allocator, self.secret, data),
            .RS256 => return error.RSANotImplemented,
        };
    }
};
```

#### 9.1.2 基于角色的访问控制 (RBAC)
```zig
// shared/auth/rbac.zig
pub const RBAC = struct {
    allocator: Allocator,
    roles: std.StringHashMap(Role),
    permissions: std.StringHashMap(Permission),
    
    pub const Permission = struct {
        name: []const u8,
        resource: []const u8,
        action: []const u8,
        description: ?[]const u8 = null,
        
        pub fn matches(self: Permission, resource: []const u8, action: []const u8) bool {
            return (std.mem.eql(u8, self.resource, "*") or std.mem.eql(u8, self.resource, resource)) and
                   (std.mem.eql(u8, self.action, "*") or std.mem.eql(u8, self.action, action));
        }
    };
    
    pub const Role = struct {
        name: []const u8,
        permissions: std.ArrayListUnmanaged([]const u8) = .{},
        parent_roles: std.ArrayListUnmanaged([]const u8) = .{},
        description: ?[]const u8 = null,
        
        pub fn hasPermission(self: Role, rbac: *RBAC, permission_name: []const u8) bool {
            // 直接权限检查
            for (self.permissions.items) |perm_name| {
                if (std.mem.eql(u8, perm_name, permission_name)) return true;
            }
            
            // 继承权限检查
            for (self.parent_roles.items) |parent_name| {
                if (rbac.roles.get(parent_name)) |parent_role| {
                    if (parent_role.hasPermission(rbac, permission_name)) return true;
                }
            }
            
            return false;
        }
    };
    
    pub const User = struct {
        id: i32,
        username: []const u8,
        roles: std.ArrayListUnmanaged([]const u8) = .{},
        
        pub fn hasPermission(self: User, rbac: *RBAC, resource: []const u8, action: []const u8) bool {
            for (self.roles.items) |role_name| {
                if (rbac.roles.get(role_name)) |role| {
                    // 检查角色的所有权限
                    for (role.permissions.items) |perm_name| {
                        if (rbac.permissions.get(perm_name)) |permission| {
                            if (permission.matches(resource, action)) return true;
                        }
                    }
                    
                    // 检查继承的权限
                    if (role.hasPermissionForResource(rbac, resource, action)) return true;
                }
            }
            return false;
        }
        
        pub fn hasRole(self: User, role_name: []const u8) bool {
            for (self.roles.items) |user_role| {
                if (std.mem.eql(u8, user_role, role_name)) return true;
            }
            return false;
        }
    };
    
    pub fn init(allocator: Allocator) RBAC {
        return .{
            .allocator = allocator,
            .roles = std.StringHashMap(Role).init(allocator),
            .permissions = std.StringHashMap(Permission).init(allocator),
        };
    }
    
    pub fn definePermission(self: *RBAC, name: []const u8, resource: []const u8, action: []const u8) !void {
        try self.permissions.put(name, .{
            .name = name,
            .resource = resource,
            .action = action,
        });
    }
    
    pub fn defineRole(self: *RBAC, name: []const u8, permissions: []const []const u8) !void {
        var role = Role{ .name = name };
        
        for (permissions) |perm_name| {
            try role.permissions.append(self.allocator, perm_name);
        }
        
        try self.roles.put(name, role);
    }
    
    pub fn checkPermission(self: *RBAC, user: User, resource: []const u8, action: []const u8) bool {
        return user.hasPermission(self, resource, action);
    }
};

// 使用示例
pub fn setupRBAC(allocator: Allocator) !RBAC {
    var rbac = RBAC.init(allocator);
    
    // 定义权限
    try rbac.definePermission("users.read", "users", "read");
    try rbac.definePermission("users.write", "users", "write");
    try rbac.definePermission("users.delete", "users", "delete");
    try rbac.definePermission("admin.all", "*", "*");
    
    // 定义角色
    try rbac.defineRole("viewer", &[_][]const u8{"users.read"});
    try rbac.defineRole("editor", &[_][]const u8{ "users.read", "users.write" });
    try rbac.defineRole("admin", &[_][]const u8{"admin.all"});
    
    return rbac;
}
```

#### 9.1.3 认证中间件
```zig
// api/middleware/auth.zig
pub const AuthMiddleware = struct {
    jwt: *JWT,
    rbac: *RBAC,
    
    pub fn requireAuth(self: *AuthMiddleware) MiddlewareHandler {
        return struct {
            middleware: *AuthMiddleware,
            
            pub fn handle(middleware: *AuthMiddleware, req: *Request, res: *Response, next: NextFn) !void {
                const auth_header = req.header("Authorization") orelse {
                    try res.status(.unauthorized).json(.{
                        .code = 401,
                        .message = "Missing Authorization header",
                    });
                    return;
                };
                
                if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
                    try res.status(.unauthorized).json(.{
                        .code = 401,
                        .message = "Invalid Authorization header format",
                    });
                    return;
                }
                
                const token = auth_header[7..]; // Skip "Bearer "
                
                const claims = middleware.jwt.verify(token) catch |err| {
                    const message = switch (err) {
                        error.TokenExpired => "Token has expired",
                        error.InvalidSignature => "Invalid token signature",
                        error.InvalidTokenFormat => "Invalid token format",
                        else => "Invalid token",
                    };
                    
                    try res.status(.unauthorized).json(.{
                        .code = 401,
                        .message = message,
                    });
                    return;
                };
                
                // 将用户信息存储到请求上下文
                req.setContext("user_id", claims.user_id.?);
                req.setContext("username", claims.username.?);
                req.setContext("roles", claims.roles.?);
                
                try next(req, res);
            }
        }{ .middleware = self }.handle;
    }
    
    pub fn requirePermission(self: *AuthMiddleware, resource: []const u8, action: []const u8) MiddlewareHandler {
        return struct {
            middleware: *AuthMiddleware,
            required_resource: []const u8,
            required_action: []const u8,
            
            pub fn handle(
                middleware: *AuthMiddleware,
                req: *Request,
                res: *Response,
                next: NextFn,
            ) !void {
                const user_id = req.getContext(i32, "user_id") orelse {
                    try res.status(.unauthorized).json(.{
                        .code = 401,
                        .message = "Authentication required",
                    });
                    return;
                };
                
                const username = req.getContext([]const u8, "username") orelse {
                    try res.status(.unauthorized).json(.{
                        .code = 401,
                        .message = "Invalid user context",
                    });
                    return;
                };
                
                const roles = req.getContext([]const []const u8, "roles") orelse &[_][]const u8{};
                
                var user_roles = std.ArrayListUnmanaged([]const u8){};
                defer user_roles.deinit(req.allocator);
                
                for (roles) |role| {
                    try user_roles.append(req.allocator, role);
                }
                
                const user = RBAC.User{
                    .id = user_id,
                    .username = username,
                    .roles = user_roles,
                };
                
                if (!middleware.rbac.checkPermission(user, this.required_resource, this.required_action)) {
                    try res.status(.forbidden).json(.{
                        .code = 403,
                        .message = "Insufficient permissions",
                    });
                    return;
                }
                
                try next(req, res);
            }
        }{
            .middleware = self,
            .required_resource = resource,
            .required_action = action,
        }.handle;
    }
};
```

### 9.2 输入验证与防护

#### 9.2.1 输入清理
```zig
// shared/security/input_sanitizer.zig
pub const InputSanitizer = struct {
    pub fn sanitizeHtml(allocator: Allocator, input: []const u8) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);
        
        var i: usize = 0;
        while (i < input.len) {
            switch (input[i]) {
                '<' => try result.appendSlice(allocator, "&lt;"),
                '>' => try result.appendSlice(allocator, "&gt;"),
                '&' => try result.appendSlice(allocator, "&amp;"),
                '"' => try result.appendSlice(allocator, "&quot;"),
                '\'' => try result.appendSlice(allocator, "&#x27;"),
                '/' => try result.appendSlice(allocator, "&#x2F;"),
                else => try result.append(allocator, input[i]),
            }
            i += 1;
        }
        
        return result.toOwnedSlice(allocator);
    }
    
    pub fn sanitizeSql(allocator: Allocator, input: []const u8) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);
        
        for (input) |char| {
            switch (char) {
                '\'' => try result.appendSlice(allocator, "''"), // SQL 转义单引号
                '\\' => try result.appendSlice(allocator, "\\\\"), // 转义反斜杠
                '\x00' => continue, // 移除 null 字节
                '\n' => try result.append(allocator, ' '), // 替换换行符
                '\r' => try result.append(allocator, ' '), // 替换回车符
                '\x1a' => continue, // 移除 substitute 字符
                else => try result.append(allocator, char),
            }
        }
        
        return result.toOwnedSlice(allocator);
    }
    
    pub fn validateEmail(email: []const u8) bool {
        if (email.len == 0 or email.len > 254) return false;
        
        const at_pos = std.mem.indexOf(u8, email, "@") orelse return false;
        if (at_pos == 0 or at_pos == email.len - 1) return false;
        
        const local_part = email[0..at_pos];
        const domain_part = email[at_pos + 1 ..];
        
        // 验证本地部分
        if (local_part.len == 0 or local_part.len > 64) return false;
        if (local_part[0] == '.' or local_part[local_part.len - 1] == '.') return false;
        
        // 验证域名部分
        if (domain_part.len == 0 or domain_part.len > 253) return false;
        if (std.mem.indexOf(u8, domain_part, ".") == null) return false;
        
        // 简单的字符验证
        for (email) |char| {
            if (!std.ascii.isAlphanumeric(char) and 
                char != '@' and char != '.' and char != '-' and char != '_') {
                return false;
            }
        }
        
        return true;
    }
    
    pub fn validatePassword(password: []const u8) !void {
        if (password.len < 8) return error.PasswordTooShort;
        if (password.len > 128) return error.PasswordTooLong;
        
        var has_upper = false;
        var has_lower = false;
        var has_digit = false;
        var has_special = false;
        
        for (password) |char| {
            if (std.ascii.isUpper(char)) has_upper = true;
            if (std.ascii.isLower(char)) has_lower = true;
            if (std.ascii.isDigit(char)) has_digit = true;
            if (!std.ascii.isAlphanumeric(char)) has_special = true;
        }
        
        if (!has_upper) return error.PasswordNeedsUppercase;
        if (!has_lower) return error.PasswordNeedsLowercase;
        if (!has_digit) return error.PasswordNeedsDigit;
        if (!has_special) return error.PasswordNeedsSpecialChar;
    }
};
```

#### 9.2.2 速率限制
```zig
// shared/security/rate_limiter.zig
pub const RateLimiter = struct {
    allocator: Allocator,
    windows: std.StringHashMap(Window),
    cleanup_timer: std.time.Timer,
    
    const Window = struct {
        requests: std.ArrayListUnmanaged(i64) = .{},
        limit: u32,
        window_size: u64, // 毫秒
        
        pub fn isAllowed(self: *Window, now: i64) bool {
            // 清理过期的请求
            self.cleanup(now);
            
            // 检查是否超过限制
            if (self.requests.items.len >= self.limit) {
                return false;
            }
            
            // 记录新请求
            self.requests.append(self.allocator, now) catch return false;
            return true;
        }
        
        fn cleanup(self: *Window, now: i64) void {
            const cutoff = now - @as(i64, @intCast(self.window_size));
            
            var i: usize = 0;
            while (i < self.requests.items.len) {
                if (self.requests.items[i] < cutoff) {
                    _ = self.requests.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    };
    
    pub fn init(allocator: Allocator) RateLimiter {
        return .{
            .allocator = allocator,
            .windows = std.StringHashMap(Window).init(allocator),
            .cleanup_timer = std.time.Timer.start() catch unreachable,
        };
    }
    
    pub fn deinit(self: *RateLimiter) void {
        var iter = self.windows.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.requests.deinit(self.allocator);
        }
        self.windows.deinit();
    }
    
    pub fn checkLimit(
        self: *RateLimiter,
        key: []const u8,
        limit: u32,
        window_ms: u64,
    ) !bool {
        const now = std.time.milliTimestamp();
        
        // 定期清理过期窗口
        if (self.cleanup_timer.read() > 60_000_000_000) { // 60 seconds
            try self.cleanupExpiredWindows(now);
            self.cleanup_timer.reset();
        }
        
        const result = try self.windows.getOrPut(key);
        if (!result.found_existing) {
            result.value_ptr.* = Window{
                .limit = limit,
                .window_size = window_ms,
            };
        }
        
        return result.value_ptr.isAllowed(now);
    }
    
    fn cleanupExpiredWindows(self: *RateLimiter, now: i64) !void {
        var keys_to_remove = std.ArrayListUnmanaged([]const u8){};
        defer keys_to_remove.deinit(self.allocator);
        
        var iter = self.windows.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.cleanup(now);
            
            // 如果窗口为空且过期，标记删除
            if (entry.value_ptr.requests.items.len == 0) {
                try keys_to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }
        
        // 删除过期窗口
        for (keys_to_remove.items) |key| {
            if (self.windows.fetchRemove(key)) |removed| {
                removed.value.requests.deinit(self.allocator);
            }
        }
    }
};

// 中间件实现
pub const RateLimitMiddleware = struct {
    rate_limiter: *RateLimiter,
    
    pub fn limit(self: *RateLimitMiddleware, requests_per_minute: u32) MiddlewareHandler {
        return struct {
            middleware: *RateLimitMiddleware,
            limit: u32,
            
            pub fn handle(
                middleware: *RateLimitMiddleware,
                req: *Request,
                res: *Response,
                next: NextFn,
            ) !void {
                const client_ip = req.clientIP();
                const key = try std.fmt.allocPrint(req.allocator, "rate_limit:{s}", .{client_ip});
                defer req.allocator.free(key);
                
                const allowed = try middleware.rate_limiter.checkLimit(key, this.limit, 60_000);
                
                if (!allowed) {
                    try res.status(.too_many_requests).json(.{
                        .code = 429,
                        .message = "Too many requests",
                        .retry_after = 60,
                    });
                    return;
                }
                
                try next(req, res);
            }
        }{ .middleware = self, .limit = requests_per_minute }.handle;
    }
};
```
## DevOps 与部署

### 10.1 容器化

#### 10.1.1 Docker 配置
```dockerfile
# Dockerfile
FROM alpine:3.18 AS builder

# 安装构建依赖
RUN apk add --no-cache \
    zig \
    musl-dev \
    sqlite-dev \
    curl-dev \
    openssl-dev

WORKDIR /app
COPY . .

# 构建应用
RUN zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl

# 运行时镜像
FROM alpine:3.18

# 安装运行时依赖
RUN apk add --no-cache \
    sqlite \
    curl \
    ca-certificates \
    tzdata

# 创建非 root 用户
RUN addgroup -g 1001 -S zigcms && \
    adduser -u 1001 -S zigcms -G zigcms

# 创建应用目录
WORKDIR /app
RUN chown -R zigcms:zigcms /app

# 复制构建产物
COPY --from=builder --chown=zigcms:zigcms /app/zig-out/bin/zigcms /app/
COPY --from=builder --chown=zigcms:zigcms /app/resources /app/resources/
COPY --from=builder --chown=zigcms:zigcms /app/configs /app/configs/

# 切换到非 root 用户
USER zigcms

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["./zigcms"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  zigcms:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=sqlite:///data/zigcms.db
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    volumes:
      - zigcms_data:/data
      - ./logs:/app/logs
    depends_on:
      - redis
      - postgres
    restart: unless-stopped
    networks:
      - zigcms_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=zigcms
      - POSTGRES_USER=zigcms
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - zigcms_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U zigcms"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped
    networks:
      - zigcms_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
      - zigcms_static:/var/www/static
    depends_on:
      - zigcms
    restart: unless-stopped
    networks:
      - zigcms_network

volumes:
  zigcms_data:
  postgres_data:
  redis_data:
  zigcms_static:

networks:
  zigcms_network:
    driver: bridge
```

#### 10.1.2 Kubernetes 部署
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: zigcms
  labels:
    name: zigcms

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: zigcms-config
  namespace: zigcms
data:
  app.toml: |
    enable_cache = true
    cache_ttl_seconds = 3600
    max_concurrent_tasks = 100
    enable_plugins = true
    plugin_directory = "plugins"
  
  api.toml: |
    host = "0.0.0.0"
    port = 3000
    max_clients = 10000
    timeout = 30000
    public_folder = "resources/public"

---
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: zigcms-secrets
  namespace: zigcms
type: Opaque
data:
  jwt-secret: <base64-encoded-jwt-secret>
  database-password: <base64-encoded-db-password>

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zigcms
  namespace: zigcms
  labels:
    app: zigcms
spec:
  replicas: 3
  selector:
    matchLabels:
      app: zigcms
  template:
    metadata:
      labels:
        app: zigcms
    spec:
      containers:
      - name: zigcms
        image: zigcms:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: zigcms-secrets
              key: jwt-secret
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: zigcms-secrets
              key: database-password
        volumeMounts:
        - name: config-volume
          mountPath: /app/configs
        - name: data-volume
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config-volume
        configMap:
          name: zigcms-config
      - name: data-volume
        persistentVolumeClaim:
          claimName: zigcms-pvc

---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: zigcms-service
  namespace: zigcms
spec:
  selector:
    app: zigcms
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: ClusterIP

---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zigcms-ingress
  namespace: zigcms
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - zigcms.example.com
    secretName: zigcms-tls
  rules:
  - host: zigcms.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: zigcms-service
            port:
              number: 80

---
# k8s/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zigcms-pvc
  namespace: zigcms
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-ssd
```

### 10.2 CI/CD 流水线

#### 10.2.1 GitHub Actions
```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: zigcms_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Zig
      uses: goto-bus-stop/setup-zig@v2
      with:
        version: 0.15.1

    - name: Cache Zig dependencies
      uses: actions/cache@v3
      with:
        path: |
          ~/.cache/zig
          .zig-cache
        key: ${{ runner.os }}-zig-${{ hashFiles('build.zig.zon') }}
        restore-keys: |
          ${{ runner.os }}-zig-

    - name: Install system dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y libsqlite3-dev libcurl4-openssl-dev

    - name: Run linter
      run: zig fmt --check .

    - name: Build project
      run: zig build

    - name: Run unit tests
      run: zig build test-unit
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/zigcms_test
        REDIS_URL: redis://localhost:6379

    - name: Run integration tests
      run: zig build test-integration
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/zigcms_test
        REDIS_URL: redis://localhost:6379

    - name: Run property tests
      run: zig build test-property

    - name: Generate coverage report
      run: |
        zig build test --summary all > coverage.txt
        echo "Coverage report generated"

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.txt
        flags: unittests
        name: codecov-umbrella

  security:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run security scan
      uses: securecodewarrior/github-action-add-sarif@v1
      with:
        sarif-file: security-scan.sarif

    - name: Check for vulnerabilities
      run: |
        # 检查依赖漏洞
        echo "Checking for security vulnerabilities..."
        # 这里可以集成安全扫描工具

  build-and-push:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy-staging:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment: staging
    
    steps:
    - name: Deploy to staging
      run: |
        echo "Deploying to staging environment..."
        # 这里集成部署脚本

  deploy-production:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - name: Deploy to production
      run: |
        echo "Deploying to production environment..."
        # 这里集成生产部署脚本
```

#### 10.2.2 部署脚本
```bash
#!/bin/bash
# scripts/deploy.sh

set -euo pipefail

# 配置
ENVIRONMENT=${1:-staging}
IMAGE_TAG=${2:-latest}
NAMESPACE="zigcms-${ENVIRONMENT}"

echo "🚀 Deploying ZigCMS to ${ENVIRONMENT} environment..."

# 验证环境
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "Usage: $0 <staging|production> [image-tag]"
    exit 1
fi

# 检查 kubectl 连接
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# 创建命名空间（如果不存在）
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 应用配置
echo "📝 Applying configuration..."
envsubst < k8s/configmap.yaml | kubectl apply -f -
envsubst < k8s/secret.yaml | kubectl apply -f -

# 更新部署
echo "🔄 Updating deployment..."
kubectl set image deployment/zigcms zigcms="ghcr.io/zigcms/zigcms:${IMAGE_TAG}" -n "$NAMESPACE"

# 等待部署完成
echo "⏳ Waiting for deployment to complete..."
kubectl rollout status deployment/zigcms -n "$NAMESPACE" --timeout=300s

# 验证部署
echo "✅ Verifying deployment..."
kubectl get pods -n "$NAMESPACE" -l app=zigcms

# 运行健康检查
echo "🏥 Running health checks..."
HEALTH_URL="https://zigcms-${ENVIRONMENT}.example.com/health"
for i in {1..10}; do
    if curl -f "$HEALTH_URL" &> /dev/null; then
        echo "✅ Health check passed"
        break
    fi
    echo "⏳ Health check attempt $i/10 failed, retrying..."
    sleep 10
done

echo "🎉 Deployment completed successfully!"
```

### 10.3 监控与告警

#### 10.3.1 Prometheus 配置
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "zigcms_rules.yml"

scrape_configs:
  - job_name: 'zigcms'
    static_configs:
      - targets: ['zigcms:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 5s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

```yaml
# monitoring/zigcms_rules.yml
groups:
- name: zigcms
  rules:
  - alert: ZigCMSDown
    expr: up{job="zigcms"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "ZigCMS instance is down"
      description: "ZigCMS instance {{ $labels.instance }} has been down for more than 1 minute."

  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High response time"
      description: "95th percentile response time is {{ $value }}s"

  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate"
      description: "Error rate is {{ $value | humanizePercentage }}"

  - alert: DatabaseConnectionsHigh
    expr: pg_stat_activity_count > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High database connections"
      description: "Database has {{ $value }} active connections"

  - alert: MemoryUsageHigh
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage"
      description: "Memory usage is {{ $value | humanizePercentage }}"
```

#### 10.3.2 Grafana 仪表板
```json
{
  "dashboard": {
    "title": "ZigCMS Monitoring",
    "tags": ["zigcms"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ],
        "yAxes": [
          {
            "label": "Requests/sec"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "50th percentile"
          },
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "99th percentile"
          }
        ],
        "yAxes": [
          {
            "label": "Seconds"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])",
            "format": "percent"
          }
        ],
        "thresholds": "0.01,0.05",
        "colorBackground": true
      },
      {
        "title": "Active Users",
        "type": "singlestat",
        "targets": [
          {
            "expr": "zigcms_active_users"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_activity_count",
            "legendFormat": "Active connections"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes",
            "legendFormat": "Memory usage"
          }
        ],
        "yAxes": [
          {
            "max": 1,
            "min": 0,
            "unit": "percentunit"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

## 代码质量保证

### 11.1 静态分析

#### 11.1.1 代码格式化
```bash
#!/bin/bash
# scripts/format.sh

echo "🎨 Formatting Zig code..."
zig fmt .

echo "📝 Checking format compliance..."
if ! zig fmt --check .; then
    echo "❌ Code is not properly formatted"
    echo "Run 'zig fmt .' to fix formatting issues"
    exit 1
fi

echo "✅ All code is properly formatted"
```

#### 11.1.2 代码质量检查
```zig
// tools/quality_check.zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <directory>\n", .{args[0]});
        return;
    }

    const dir_path = args[1];
    try analyzeDirectory(allocator, dir_path);
}

fn analyzeDirectory(allocator: std.mem.Allocator, path: []const u8) !void {
    var dir = std.fs.cwd().openIterableDir(path, .{}) catch |err| {
        std.debug.print("Error opening directory {s}: {}\n", .{ path, err });
        return;
    };
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var total_files: u32 = 0;
    var total_lines: u32 = 0;
    var issues: u32 = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        total_files += 1;
        const file_issues = try analyzeFile(allocator, entry.path);
        issues += file_issues;

        // 计算行数
        const file = try dir.dir.openFile(entry.path, .{});
        defer file.close();
        
        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);
        
        const lines = std.mem.count(u8, content, "\n") + 1;
        total_lines += @intCast(lines);
    }

    std.debug.print("\n📊 Quality Report\n");
    std.debug.print("================\n");
    std.debug.print("Files analyzed: {d}\n", .{total_files});
    std.debug.print("Total lines: {d}\n", .{total_lines});
    std.debug.print("Issues found: {d}\n", .{issues});
    
    if (issues == 0) {
        std.debug.print("✅ No quality issues found!\n");
    } else {
        std.debug.print("⚠️  Please address the issues above\n");
    }
}

fn analyzeFile(allocator: std.mem.Allocator, file_path: []const u8) !u32 {
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.debug.print("Error opening file {s}: {}\n", .{ file_path, err });
        return 0;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    var issues: u32 = 0;
    var line_num: u32 = 1;
    var lines = std.mem.split(u8, content, "\n");

    while (lines.next()) |line| {
        defer line_num += 1;

        // 检查行长度
        if (line.len > 120) {
            std.debug.print("⚠️  {s}:{d} Line too long ({d} chars)\n", .{ file_path, line_num, line.len });
            issues += 1;
        }

        // 检查尾随空格
        if (line.len > 0 and line[line.len - 1] == ' ') {
            std.debug.print("⚠️  {s}:{d} Trailing whitespace\n", .{ file_path, line_num });
            issues += 1;
        }

        // 检查 TODO/FIXME 注释
        if (std.mem.indexOf(u8, line, "TODO") != null or std.mem.indexOf(u8, line, "FIXME") != null) {
            std.debug.print("📝 {s}:{d} TODO/FIXME found\n", .{ file_path, line_num });
        }

        // 检查复杂的嵌套
        const indent_level = countIndentation(line);
        if (indent_level > 6) {
            std.debug.print("⚠️  {s}:{d} Deep nesting (level {d})\n", .{ file_path, line_num, indent_level });
            issues += 1;
        }
    }

    return issues;
}

fn countIndentation(line: []const u8) u32 {
    var level: u32 = 0;
    for (line) |char| {
        switch (char) {
            ' ' => level += 1,
            '\t' => level += 4,
            else => break,
        }
    }
    return level / 4; // 假设 4 个空格为一级缩进
}
```

### 11.2 文档生成

#### 11.2.1 API 文档自动生成
```zig
// tools/doc_generator.zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try generateApiDocs(allocator);
}

fn generateApiDocs(allocator: std.mem.Allocator) !void {
    const controllers_dir = "api/controllers";
    var dir = try std.fs.cwd().openIterableDir(controllers_dir, .{});
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var docs = std.ArrayListUnmanaged(u8){};
    defer docs.deinit(allocator);

    const writer = docs.writer(allocator);

    try writer.writeAll("# ZigCMS API Documentation\n\n");
    try writer.writeAll("Auto-generated API documentation.\n\n");

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".controller.zig")) continue;

        try parseControllerFile(allocator, entry.path, writer);
    }

    try std.fs.cwd().writeFile("docs/api.md", docs.items);
    std.debug.print("✅ API documentation generated: docs/api.md\n");
}

fn parseControllerFile(allocator: std.mem.Allocator, file_path: []const u8, writer: anytype) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    // 简单的解析逻辑，实际应该使用 AST
    var lines = std.mem.split(u8, content, "\n");
    var in_function = false;
    var current_function: ?[]const u8 = null;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");

        // 检查函数定义
        if (std.mem.startsWith(u8, trimmed, "pub fn ") and std.mem.indexOf(u8, trimmed, "req: zap.Request") != null) {
            const fn_start = std.mem.indexOf(u8, trimmed, "fn ").? + 3;
            const fn_end = std.mem.indexOf(u8, trimmed[fn_start..], "(").? + fn_start;
            current_function = trimmed[fn_start..fn_end];
            in_function = true;

            try writer.print("## {s}\n\n", .{current_function.?});
        }

        // 检查注释
        if (std.mem.startsWith(u8, trimmed, "///") and in_function) {
            const comment = std.mem.trim(u8, trimmed[3..], " ");
            try writer.print("{s}\n", .{comment});
        }

        // 函数结束
        if (in_function and std.mem.startsWith(u8, trimmed, "}")) {
            in_function = false;
            current_function = null;
            try writer.writeAll("\n");
        }
    }
}
```

---

## 总结

本开发规范文档涵盖了现代软件开发的各个方面，基于 Zig 0.15+ 的最新特性和最佳实践。主要包括：

### 核心原则
- **整洁架构**: 分层清晰，依赖倒置
- **领域驱动设计**: 业务逻辑为核心
- **测试驱动开发**: 高质量代码保证
- **安全第一**: 全方位安全防护
- **性能优化**: 内存安全与高性能并重

### 技术栈
- **语言**: Zig 0.15+ 
- **架构**: Clean Architecture + DDD + CQRS
- **数据库**: PostgreSQL/MySQL/SQLite
- **缓存**: Redis
- **监控**: Prometheus + Grafana + OpenTelemetry
- **部署**: Docker + Kubernetes
- **CI/CD**: GitHub Actions

### 质量保证
- 单元测试覆盖率 ≥ 80%
- 集成测试覆盖关键流程
- 属性测试验证业务规则
- 静态分析和代码格式化
- 安全扫描和漏洞检测

这份规范将确保 ZigCMS 项目的高质量、可维护性和可扩展性，为团队提供统一的开发标准。