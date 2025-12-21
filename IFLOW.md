# ZigCMS - iFlow 项目指南

> 本文档为 iFlow AI 助手提供项目上下文和开发指导，帮助快速理解项目结构和开发规范。

## 📋 项目概览

**项目名称**: ZigCMS  
**语言**: Zig 0.15.0+  
**架构**: 整洁架构 (Clean Architecture)  
**类型**: 高性能内容管理系统  
**Git**: https://github.com/xiusin/zigcms

### 核心特性

- ✅ **高性能**: 基于 Zig 语言，零抽象开销，内存安全
- ✅ **整洁架构**: API、应用、领域、基础设施、共享五层分离
- ✅ **多数据库**: 支持 PostgreSQL、MySQL、SQLite
- ✅ **自动 CRUD**: 基于模型自动生成 RESTful API
- ✅ **插件系统**: 动态插件加载和管理
- ✅ **完整后台**: 基于 LayUI 的管理界面
- ✅ **中间件链**: 认证、日志、安全等中间件支持

## 🏗️ 项目架构

### 整洁架构分层

```
zigcms/
├── api/                    # API 层 - HTTP 请求处理
│   ├── App.zig            # 应用框架核心
│   ├── controllers/       # 控制器 (使用 mod.zig)
│   ├── dto/               # 数据传输对象 (使用 mod.zig)
│   └── middleware/        # 中间件 (使用 mod.zig)
│
├── application/           # 应用层 - 业务流程协调
│   ├── services/          # 应用服务
│   │   ├── orm/          # ORM 服务
│   │   ├── cache/        # 缓存服务
│   │   ├── logger/       # 日志服务
│   │   ├── sql/          # SQL 驱动 (MySQL/SQLite/PostgreSQL)
│   │   ├── upload/       # 文件上传服务
│   │   ├── validator/    # 验证服务
│   │   └── ...
│   └── mod.zig           # 应用层入口
│
├── domain/                # 领域层 - 核心业务逻辑
│   ├── entities/         # 业务实体模型
│   │   ├── admin.model.zig
│   │   ├── category.model.zig
│   │   ├── cms_model.model.zig
│   │   └── ...
│   └── repositories/     # 仓库接口
│
├── infrastructure/        # 基础设施层 - 外部服务
│   ├── database/         # 数据库实现
│   ├── cache/            # 缓存实现
│   └── http/             # HTTP 客户端
│
├── shared/                # 共享层 - 通用组件
│   ├── utils/            # 工具函数
│   ├── primitives/       # 基础原语
│   └── types/            # 通用类型
│
├── plugins/               # 插件系统
│   ├── plugin_interface.zig  # 插件接口定义
│   ├── plugin_manager.zig    # 插件管理器
│   └── templates/            # 插件模板
│
├── commands/              # 命令行工具
│   ├── codegen.zig       # 代码生成器
│   ├── migrate.zig       # 数据库迁移
│   ├── plugin_gen.zig    # 插件生成器
│   └── config_gen.zig    # 配置生成器
│
├── resources/             # 前端资源
│   ├── page/             # HTML 页面
│   ├── css/              # 样式文件
│   ├── js/               # JavaScript
│   └── lib/              # 第三方库 (LayUI 等)
│
├── main.zig              # 程序入口
├── root.zig              # 项目根模块
└── build.zig             # 构建配置
```

### 依赖规则

- **API 层** → 依赖应用层
- **应用层** → 依赖领域层
- **领域层** → 无外部依赖（核心）
- **基础设施层** → 实现领域层接口
- **共享层** → 被所有层使用

## 🚀 快速开始

### 环境要求

```bash
# Zig 版本
zig version  # 需要 0.15.0+

# 数据库（任选其一或多个）
- PostgreSQL 12+
- MySQL 8.0+ / MariaDB 10.5+
- SQLite 3.8+

# 可选依赖
- Redis 6.0+ (缓存)
```

### 安装和运行

```bash
# 1. 克隆项目
git clone https://github.com/xiusin/zigcms
cd zigcms

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，配置数据库连接等

# 3. 构建项目
zig build

# 4. 运行开发服务器
zig build run

# 5. 生产环境构建（优化）
zig build -Doptimize=ReleaseSafe
./zig-out/bin/vendor
```

### 访问系统

- **管理后台**: http://localhost:3030/admin
- **API 文档**: http://localhost:3030/docs/api/
- **前端界面**: http://localhost:3030/

## 🔧 开发命令

### 构建命令

```bash
# 基础构建
zig build                          # 调试构建
zig build -Doptimize=ReleaseFast   # 性能优化
zig build -Doptimize=ReleaseSafe   # 安全优化
zig build -Doptimize=ReleaseSmall  # 体积优化

# 运行服务器
zig build run                      # 运行开发服务器
zig build run -- --port 8080       # 指定端口运行
```

### 测试命令

```bash
# 运行所有测试
zig build test

# 运行单元测试
zig build test -- lib              # 库测试
zig build test -- exe              # 可执行文件测试

# 运行集成测试
zig build test -- integration

# 数据库测试（需要配置数据库）
# MySQL 测试
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS test_zigcms;"
zig build test-mysql

# SQLite 测试（无需外部数据库）
zig build test-sqlite

# PostgreSQL 测试
psql -U postgres -c "CREATE DATABASE test_zigcms;"
# 配置 .env 后运行主测试
```

### 开发工具

```bash
# 代码生成
zig build codegen -- --help        # 查看代码生成帮助
zig build codegen -- model User    # 生成 User 模型

# 数据库迁移
zig build migrate -- up            # 执行迁移
zig build migrate -- down          # 回滚迁移
zig build migrate -- status        # 查看迁移状态

# 插件生成
zig build plugin-gen -- MyPlugin   # 生成插件模板

# 配置生成（从 .env 生成配置结构）
zig build config-gen
```

## 📦 依赖管理

### 主要依赖（build.zig.zon）

```zig
.dependencies = .{
    .zap = "0.10.6",           // HTTP 框架
    .regex = "0.1.3",          // 正则表达式
    .pretty = "0.10.6",        // 格式化输出
    .sqlite = "3.48.0",        // SQLite 驱动
    .curl = "0.3.2",           // HTTP 客户端
    .pg = "latest",            // PostgreSQL 驱动
    .smtp_client = "latest",   // SMTP 客户端
    .dotenv = "0.1.0",         // 环境变量
}
```

### 系统依赖

```bash
# macOS (Homebrew)
brew install mysql-client          # MySQL 客户端库
brew install postgresql@14         # PostgreSQL (可选)
brew install redis                 # Redis (可选)

# Linux (Ubuntu/Debian)
sudo apt install libmysqlclient-dev
sudo apt install postgresql-client
sudo apt install redis-server
```

## 💻 开发规范

### 1. 代码风格与命名规范

#### 1.1 文件命名规范

```bash
# 控制器文件
{module}.controller.zig         # 例: user.controller.zig

# 服务文件
{module}.service.zig            # 例: auth.service.zig

# 模型文件
{module}.model.zig              # 例: employee.model.zig

# DTO 文件
{module}_{action}.dto.zig       # 例: user_create.dto.zig
                                #     employee_response.dto.zig

# 中间件文件
{name}.middleware.zig           # 例: auth.middleware.zig

# 工具文件
{name}.zig                      # 例: strings.zig, time.zig
```

#### 1.2 类型命名规范

```zig
// ✅ 推荐的命名规范

// 结构体、枚举、联合体: PascalCase
pub const UserController = struct { ... };
pub const HttpMethod = enum { GET, POST, PUT, DELETE };
pub const Result = union(enum) { ok: i32, err: []const u8 };

// 字段、变量: snake_case
allocator: Allocator,
user_service: *UserService,
const new_user = User{ ... };

// 函数: camelCase
pub fn createUser(self: *Self) !void { ... }
pub fn getUserById(id: i32) !User { ... }

// 常量: SCREAMING_SNAKE_CASE
const MAX_FILE_SIZE = 10 * 1024 * 1024;
const DEFAULT_PAGE_SIZE = 10;
const API_VERSION = "v1";

// 类型别名
const Self = @This();
const Allocator = std.mem.Allocator;
```

#### 1.3 注释规范

```zig
//! 文件级文档注释
//! 
//! 用户管理控制器
//! 提供用户相关的 CRUD 操作和认证功能

const std = @import("std");

/// 结构体文档注释
/// 
/// 用户实体，表示系统中的用户账号信息
pub const User = struct {
    /// 用户ID，主键
    id: i32,
    /// 用户名，唯一标识，长度3-20字符
    username: []const u8,
    /// 邮箱地址，用于登录和通知
    email: []const u8,
    /// 创建时间戳（Unix时间）
    created_at: i64,
    
    /// 函数文档注释
    /// 
    /// 验证用户数据的有效性
    /// 
    /// @return 验证通过返回 void，否则返回错误
    pub fn validate(self: Self) !void {
        // 实现注释：说明复杂逻辑
        if (self.username.len < 3) return error.UsernameTooShort;
        if (!isValidEmail(self.email)) return error.InvalidEmail;
    }
};

// ============================================================================
// 使用分隔符组织代码块
// ============================================================================

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
/// @return 活跃度评分 (0-100)
pub fn calculateActivityScore(user: User, login_days: i32) f32 {
    // 实现...
}
```

#### 1.4 导入和模块组织

```zig
// 导入顺序：标准库 → 第三方库 → 项目内部模块
const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const json_mod = @import("../../application/services/json/json.zig");
const global = @import("../../shared/primitives/global.zig");

// 使用 mod.zig 约定
const controllers = @import("api/controllers/mod.zig");
const dto = @import("api/dto/mod.zig");

// 访问具体类型
const Login = controllers.auth.Login;
const UserDto = dto.user.UserCreate;
```

### 2. 架构设计原则

#### 2.1 整洁架构分层

```
┌──────────────────────────────────────┐
│         API 层 (api/)                │  ← HTTP 请求/响应处理
│  - controllers/  控制器              │
│  - dto/          数据传输对象        │
│  - middleware/   中间件              │
├──────────────────────────────────────┤
│      应用层 (application/)           │  ← 业务流程协调
│  - services/     应用服务            │
│  - usecases/     业务用例            │
├──────────────────────────────────────┤
│       领域层 (domain/)               │  ← 核心业务逻辑
│  - entities/     业务实体            │
│  - repositories/ 仓库接口            │
├──────────────────────────────────────┤
│   基础设施层 (infrastructure/)       │  ← 外部服务实现
│  - database/     数据库实现          │
│  - cache/        缓存实现            │
│  - http/         HTTP 客户端         │
├──────────────────────────────────────┤
│       共享层 (shared/)               │  ← 通用组件
│  - utils/        工具函数            │
│  - primitives/   基础原语            │
│  - types/        通用类型            │
└──────────────────────────────────────┘
```

**依赖规则**：
- ✅ 外层可以依赖内层
- ❌ 内层不能依赖外层
- ✅ 领域层无外部依赖（最核心）
- ✅ 共享层被所有层使用

#### 2.2 职责分离原则

```zig
// ✅ 推荐：Controller 只处理 HTTP，不包含业务逻辑
pub fn createUser(self: *Self, req: zap.Request) !void {
    // 1. 解析请求
    const dto = try req.parseBody(UserCreateDto);
    
    // 2. 调用 Service 处理业务逻辑
    const user = try self.user_service.create(dto);
    
    // 3. 返回响应
    try req.sendJson(.{ .code = 0, .data = user });
}

// ✅ 推荐：Service 封装业务逻辑
pub fn create(self: *Self, dto: UserCreateDto) !User {
    // 1. 验证
    try dto.validate();
    
    // 2. 检查重复
    if (try self.repo.findByEmail(dto.email)) |_| {
        return error.DuplicateEmail;
    }
    
    // 3. 创建实体
    const user = User{
        .username = dto.username,
        .email = dto.email,
        .password = try hashPassword(dto.password),
    };
    
    // 4. 持久化
    return try self.repo.save(user);
}

// ✅ 推荐：Repository 只负责数据访问
pub fn save(self: *Self, user: User) !User {
    return try self.db.insert("users", user);
}
```

#### 2.3 依赖注入模式

```zig
// ✅ 推荐：构造函数注入
pub const UserService = struct {
    allocator: Allocator,
    user_repo: *UserRepository,
    email_service: *EmailService,

    pub fn init(
        allocator: Allocator,
        user_repo: *UserRepository,
        email_service: *EmailService,
    ) Self {
        return .{
            .allocator = allocator,
            .user_repo = user_repo,
            .email_service = email_service,
        };
    }
};

// ✅ 推荐：接口抽象（使用虚表）
pub const UploadProvider = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        upload: *const fn (*anyopaque, []const u8) anyerror![]const u8,
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
    };
    
    pub fn upload(self: Self, file: []const u8) ![]const u8 {
        return self.vtable.upload(self.ptr, file);
    }
};
```

### 3. 错误处理规范

```zig
// ✅ 定义明确的错误类型
pub const UserError = error{
    UserNotFound,
    InvalidCredentials,
    DuplicateEmail,
    ValidationError,
    PasswordTooWeak,
};

// ✅ 推荐：使用 Zig 错误联合类型
pub fn getUser(id: u32) !User {
    const user = try db.query("SELECT * FROM users WHERE id = ?", .{id});
    return user orelse error.UserNotFound;
}

// ✅ 推荐：错误转换和上下文
pub fn getUserById(self: Self, id: i32) !User {
    return self.user_repo.findById(id) catch |err| switch (err) {
        RepositoryError.NotFound => error.UserNotFound,
        RepositoryError.DatabaseError => error.InternalError,
        else => err,
    };
}

// ✅ 推荐：错误日志记录
pub fn processPayment(amount: f64) !void {
    payment_service.charge(amount) catch |err| {
        logger.err("支付失败: {} - 金额: {d}", .{ err, amount });
        return err;
    };
}

// ❌ 避免：忽略错误
pub fn getUser(id: u32) User {
    return db.query(...) catch unreachable;  // 不推荐！
}

// ❌ 避免：捕获所有错误
pub fn getUser(id: u32) ?User {
    return db.query(...) catch null;  // 丢失错误信息
}
```

### 4. 内存管理规范

```zig
// ✅ 推荐：明确的内存生命周期
pub fn processData(allocator: Allocator) ![]u8 {
    const data = try allocator.alloc(u8, 1024);
    defer allocator.free(data);  // 确保释放
    
    // 处理数据...
    return try allocator.dupe(u8, data);  // 返回副本
}

// ✅ 推荐：使用 GPA 检测泄漏
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("⚠️ 内存泄漏检测\n", .{});
        }
    }
    const allocator = gpa.allocator();
    
    // 应用逻辑...
}

// ✅ 推荐：Arena 分配器用于临时数据
pub fn handleRequest(allocator: Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();  // 自动释放所有分配
    
    const temp_allocator = arena.allocator();
    // 使用 temp_allocator 进行临时分配
}

// ✅ 推荐：明确所有权
pub fn createUser(allocator: Allocator, name: []const u8) !User {
    // 调用者拥有返回的 User，负责释放
    const owned_name = try allocator.dupe(u8, name);
    return User{ .name = owned_name };
}

pub fn destroyUser(allocator: Allocator, user: User) void {
    allocator.free(user.name);
}
```

### 5. API 设计规范

#### 5.1 RESTful API 设计

```bash
# ✅ 资源命名：使用复数名词，小写字母
GET    /api/users              # 获取用户列表
POST   /api/users              # 创建用户
GET    /api/users/{id}         # 获取特定用户
PUT    /api/users/{id}         # 更新用户（完整）
PATCH  /api/users/{id}         # 更新用户（部分）
DELETE /api/users/{id}         # 删除用户

# ✅ 嵌套资源
GET    /api/users/{id}/posts   # 获取用户的文章
POST   /api/users/{id}/posts   # 为用户创建文章

# ✅ 过滤和查询
GET    /api/users?status=active&role=admin
GET    /api/users?page=1&page_size=20
GET    /api/users?sort=-created_at  # 按创建时间倒序
```

#### 5.2 HTTP 状态码规范

```zig
// ✅ 正确使用 HTTP 状态码
200 OK                  // 成功
201 Created             // 资源创建成功
204 No Content          // 删除成功，无返回内容
400 Bad Request         // 请求参数错误
401 Unauthorized        // 未认证
403 Forbidden           // 无权限
404 Not Found           // 资源不存在
422 Unprocessable Entity // 验证错误
500 Internal Server Error // 服务器错误
```

#### 5.3 统一响应格式

```zig
// ✅ 成功响应
{
    "code": 0,
    "msg": "success",
    "data": {
        "id": 1,
        "name": "张三"
    }
}

// ✅ 分页响应（LayUI 格式）
{
    "code": 0,
    "msg": "",
    "count": 100,        // 总记录数
    "data": [...]        // 当前页数据
}

// ✅ 错误响应
{
    "code": 1001,
    "msg": "用户不存在",
    "data": null
}

// ✅ 验证错误响应
{
    "code": 422,
    "msg": "验证失败",
    "data": {
        "errors": {
            "email": "邮箱格式不正确",
            "password": "密码长度至少6位"
        }
    }
}
```

### 6. 数据库设计规范

#### 6.1 表设计规范

```sql
-- ✅ 表命名：复数形式，小写字母加下划线
CREATE TABLE users (...);
CREATE TABLE user_roles (...);
CREATE TABLE article_categories (...);

-- ✅ 字段命名：小写字母加下划线
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_delete TINYINT DEFAULT 0
);

-- ✅ 外键命名：{table}_id
CREATE TABLE articles (
    id INT PRIMARY KEY,
    user_id INT NOT NULL,           -- 外键
    category_id INT NOT NULL,       -- 外键
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);
```

#### 6.2 标准字段规范

```zig
// ✅ 所有实体模型必须包含的标准字段
pub const StandardFields = struct {
    /// 主键ID（可空，创建时为null）
    id: ?i32 = null,
    
    /// 创建时间（Unix时间戳）
    create_time: ?i64 = null,
    
    /// 更新时间（Unix时间戳）
    update_time: ?i64 = null,
    
    /// 软删除标记（0正常 1已删除）
    is_delete: i32 = 0,
};

// ✅ 常用可选字段
pub const CommonFields = struct {
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    
    /// 排序权重
    sort: i32 = 0,
    
    /// 备注
    remark: []const u8 = "",
};
```

#### 6.3 索引设计规范

```sql
-- ✅ 主键索引
PRIMARY KEY (id)

-- ✅ 唯一索引
CREATE UNIQUE INDEX idx_users_username ON users(username);
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- ✅ 普通索引（高频查询字段）
CREATE INDEX idx_articles_user_id ON articles(user_id);
CREATE INDEX idx_articles_status ON articles(status);

-- ✅ 复合索引（多字段联合查询）
CREATE INDEX idx_articles_category_created 
    ON articles(category_id, created_at DESC);

-- ✅ 全文索引（搜索场景）
CREATE FULLTEXT INDEX idx_articles_content 
    ON articles(title, content);
```

### 7. ORM 使用规范

```zig
// ✅ 模型定义
pub const User = sql.defineWithConfig(struct {
    id: ?i32 = null,
    username: []const u8,
    email: []const u8,
    status: i32 = 1,
    created_at: ?i64 = null,
    is_delete: i32 = 0,
}, .{
    .table_name = "zigcms.users",
    .primary_key = "id",
});

// ✅ 推荐：使用查询构建器
var query = User.query(db);
defer query.deinit();

const users = try query
    .where("is_delete", "=", 0)
    .where("status", "=", 1)
    .orderBy("created_at", .DESC)
    .limit(10)
    .offset(0)
    .get();

// ✅ 推荐：关联查询
const articles = try QueryBuilder.init(allocator, "articles")
    .join("categories", "articles.category_id", "=", "categories.id")
    .join("users", "articles.user_id", "=", "users.id")
    .select(&[_][]const u8{
        "articles.*",
        "categories.name as category_name",
        "users.username as author_name",
    })
    .where("articles.is_delete", "=", 0)
    .get();

// ✅ 推荐：事务处理
const tx = try db.begin();
errdefer tx.rollback();

try tx.insert("users", user_data);
try tx.insert("profiles", profile_data);

try tx.commit();

// ❌ 避免：直接拼接 SQL（SQL 注入风险）
const sql = try std.fmt.allocPrint(
    allocator,
    "SELECT * FROM users WHERE name = '{s}'",
    .{user_input}
);  // 危险！
```

## 📝 标准代码模板

### 1. Model 模板

```zig
//! {实体名}管理模型
//!
//! {简要描述实体的业务用途}

/// {实体名}实体
pub const {Entity} = struct {
    // ========================================================================
    // 标准字段（必需）
    // ========================================================================
    
    /// 主键ID
    id: ?i32 = null,
    
    /// 创建时间（Unix时间戳）
    create_time: ?i64 = null,
    
    /// 更新时间（Unix时间戳）
    update_time: ?i64 = null,
    
    /// 软删除标记（0正常 1已删除）
    is_delete: i32 = 0,
    
    // ========================================================================
    // 业务字段
    // ========================================================================
    
    /// 名称
    name: []const u8 = "",
    
    /// 编码（可选）
    code: []const u8 = "",
    
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    
    /// 排序权重
    sort: i32 = 0,
    
    /// 备注
    remark: []const u8 = "",
    
    // ========================================================================
    // 扩展字段（根据业务需要添加）
    // ========================================================================
    
    /// 父级ID（树形结构）
    parent_id: ?i32 = null,
    
    /// 创建人ID
    creator_id: ?i32 = null,
};
```

### 2. Controller 模板

```zig
//! {实体名}管理控制器
//!
//! 提供{实体名}的 CRUD 操作和业务功能

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

// ============================================================================
// ORM 模型定义
// ============================================================================

const Orm{Entity} = sql.defineWithConfig(models.{Entity}, .{
    .table_name = "zigcms.{table_name}",
    .primary_key = "id",
});

// ============================================================================
// 初始化
// ============================================================================

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!Orm{Entity}.hasDb()) {
        Orm{Entity}.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

/// 分页列表查询
pub const list = MW.requireAuth(listImpl);

/// 获取单条记录
pub const get = MW.requireAuth(getImpl);

/// 保存（新增/更新）
pub const save = MW.requireAuth(saveImpl);

/// 删除记录
pub const delete = MW.requireAuth(deleteImpl);

/// 批量修改
pub const modify = MW.requireAuth(modifyImpl);

/// 下拉选择列表
pub const select = MW.requireAuth(selectImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: *Self, req: zap.Request) !void {
    // 1. 解析分页参数
    const page = try base.getQueryInt(req, "page", 1);
    const limit = try base.getQueryInt(req, "limit", 10);
    
    // 2. 解析搜索条件
    const keyword = base.getQuery(req, "keyword");
    const status = base.getQuery(req, "status");
    
    // 3. 构建查询
    var query = Orm{Entity}.query();
    defer query.deinit();
    
    try query.where("is_delete", "=", 0);
    
    if (keyword) |kw| {
        try query.whereLike("name", kw);
    }
    
    if (status) |s| {
        try query.where("status", "=", s);
    }
    
    // 4. 执行查询
    try query.orderBy("sort", .ASC);
    try query.orderBy("id", .DESC);
    
    const total = try query.count();
    const list = try query.paginate(page, limit);
    defer self.allocator.free(list);
    
    // 5. 返回响应（LayUI 格式）
    try base.sendLayuiTable(req, list, total);
}

/// 获取单条记录实现
fn getImpl(self: *Self, req: zap.Request) !void {
    const id = try base.getQueryInt(req, "id", 0);
    if (id == 0) return base.error_msg(req, "ID不能为空");
    
    var query = Orm{Entity}.query();
    defer query.deinit();
    
    const item = try query.find(id) orelse {
        return base.error_msg(req, "记录不存在");
    };
    defer self.allocator.free(item);
    
    try base.success(req, item);
}

/// 保存实现（新增/更新）
fn saveImpl(self: *Self, req: zap.Request) !void {
    // 1. 解析请求体
    const body = try base.getBody(req);
    const data = try json_mod.parseFromSlice(
        models.{Entity},
        self.allocator,
        body,
        .{ .ignore_unknown_fields = true },
    );
    defer data.deinit();
    
    const item = data.value;
    
    // 2. 数据验证
    if (item.name.len == 0) {
        return base.error_msg(req, "名称不能为空");
    }
    
    // 3. 检查重复（可选）
    var check_query = Orm{Entity}.query();
    defer check_query.deinit();
    
    try check_query.where("name", "=", item.name);
    try check_query.where("is_delete", "=", 0);
    
    if (item.id) |id| {
        try check_query.where("id", "!=", id);
    }
    
    if (try check_query.exists()) {
        return base.error_msg(req, "名称已存在");
    }
    
    // 4. 保存数据
    if (item.id) |id| {
        // 更新
        try Orm{Entity}.updateById(id, item);
        try base.success_msg(req, "更新成功");
    } else {
        // 新增
        const new_id = try Orm{Entity}.insert(item);
        try base.success(req, .{ .id = new_id });
    }
}

/// 删除实现（软删除）
fn deleteImpl(self: *Self, req: zap.Request) !void {
    const id = try base.getQueryInt(req, "id", 0);
    if (id == 0) return base.error_msg(req, "ID不能为空");
    
    // 软删除
    try Orm{Entity}.updateById(id, .{ .is_delete = 1 });
    try base.success_msg(req, "删除成功");
}

/// 批量修改实现
fn modifyImpl(self: *Self, req: zap.Request) !void {
    const body = try base.getBody(req);
    const data = try json_mod.parseFromSlice(
        struct { ids: []i32, field: []const u8, value: []const u8 },
        self.allocator,
        body,
        .{ .ignore_unknown_fields = true },
    );
    defer data.deinit();
    
    const params = data.value;
    
    // 批量更新
    var query = Orm{Entity}.query();
    defer query.deinit();
    
    try query.whereIn("id", params.ids);
    try query.update(.{
        .{params.field, params.value},
    });
    
    try base.success_msg(req, "修改成功");
}

/// 下拉选择列表实现
fn selectImpl(self: *Self, req: zap.Request) !void {
    var query = Orm{Entity}.query();
    defer query.deinit();
    
    try query.select(&[_][]const u8{ "id", "name" });
    try query.where("status", "=", 1);
    try query.where("is_delete", "=", 0);
    try query.orderBy("sort", .ASC);
    
    const list = try query.get();
    defer self.allocator.free(list);
    
    try base.success(req, list);
}
```

### 3. DTO 模板

#### 3.1 CreateDto（创建请求）

```zig
//! {实体名}创建数据传输对象
//!
//! 用于创建{实体名}实体的数据结构

const std = @import("std");

/// {实体名}创建 DTO
pub const {Entity}CreateDto = struct {
    /// 名称（必填）
    name: []const u8,
    
    /// 编码
    code: []const u8 = "",
    
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    
    /// 排序权重
    sort: i32 = 0,
    
    /// 备注
    remark: []const u8 = "",
    
    /// 验证方法
    pub fn validate(self: @This()) !void {
        if (self.name.len == 0) {
            return error.NameRequired;
        }
        if (self.name.len > 100) {
            return error.NameTooLong;
        }
    }
};
```

#### 3.2 UpdateDto（更新请求）

```zig
//! {实体名}更新数据传输对象

const std = @import("std");

/// {实体名}更新 DTO
pub const {Entity}UpdateDto = struct {
    /// ID（必填）
    id: i32,
    
    /// 名称（可选）
    name: ?[]const u8 = null,
    
    /// 编码（可选）
    code: ?[]const u8 = null,
    
    /// 状态（可选）
    status: ?i32 = null,
    
    /// 排序（可选）
    sort: ?i32 = null,
    
    /// 备注（可选）
    remark: ?[]const u8 = null,
    
    /// 验证方法
    pub fn validate(self: @This()) !void {
        if (self.id <= 0) {
            return error.InvalidId;
        }
        if (self.name) |n| {
            if (n.len == 0 or n.len > 100) {
                return error.InvalidName;
            }
        }
    }
};
```

#### 3.3 ResponseDto（响应数据）

```zig
//! {实体名}响应数据传输对象

const std = @import("std");

/// {实体名}响应 DTO
pub const {Entity}ResponseDto = struct {
    /// ID
    id: ?i32 = null,
    
    /// 名称
    name: []const u8 = "",
    
    /// 编码
    code: []const u8 = "",
    
    /// 状态
    status: i32 = 1,
    
    /// 状态文本
    status_text: []const u8 = "",
    
    /// 排序
    sort: i32 = 0,
    
    /// 备注
    remark: []const u8 = "",
    
    /// 创建时间
    create_time: ?i64 = null,
    
    /// 创建时间格式化
    create_time_format: []const u8 = "",
    
    /// 更新时间
    update_time: ?i64 = null,
};
```

### 4. 中间件模板

```zig
//! {功能名}中间件
//!
//! {中间件功能描述}

const std = @import("std");
const zap = @import("zap");

/// {功能名}中间件
pub fn {name}Middleware(
    req: *zap.Request,
    res: *zap.Response,
    next: NextFn,
) !void {
    // 1. 前置处理
    // 例如：验证、日志记录等
    
    // 2. 调用下一个中间件或处理器
    try next(req, res);
    
    // 3. 后置处理（可选）
    // 例如：响应修改、清理资源等
}
```

### 5. Service 模板

```zig
//! {功能名}服务
//!
//! {服务功能描述}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
// 依赖的其他服务...

/// 初始化服务
pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

/// 清理资源
pub fn deinit(self: *Self) void {
    // 清理资源
}

/// 业务方法示例
pub fn doSomething(self: *Self, param: []const u8) !Result {
    // 1. 参数验证
    if (param.len == 0) {
        return error.InvalidParameter;
    }
    
    // 2. 业务逻辑处理
    // ...
    
    // 3. 返回结果
    return Result{ .success = true };
}
```

## 🎯 核心功能

### 1. 自动 CRUD API

```zig
// main.zig - 注册模型自动生成 CRUD 路由
try app.crud("category", models.Category);
try app.crud("article", models.Article);
try app.crud("user", models.User);

// 自动生成以下路由：
// POST   /category/save      - 创建/更新
// GET    /category/list      - 列表查询（分页）
// GET    /category/get       - 获取单条
// POST   /category/delete    - 删除
// POST   /category/modify    - 批量修改
// GET    /category/select    - 下拉选择数据
```

### 2. 自定义控制器

```zig
// api/controllers/auth/login.controller.zig
pub const Login = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) Login {
        return .{ .allocator = allocator };
    }
    
    pub fn login(self: *Login, req: *Request, res: *Response) !void {
        const dto = try req.parseBody(UserLoginDto);
        // 业务逻辑...
        try res.json(.{ .code = 0, .data = token });
    }
};

// main.zig - 注册路由
var login = controllers.auth.Login.init(allocator);
try app.route("/login", &login, &controllers.auth.Login.login);
```

### 3. 中间件系统

```zig
// api/middleware/auth.middleware.zig
pub fn authMiddleware(req: *Request, res: *Response, next: NextFn) !void {
    const token = req.header("Authorization") orelse {
        return res.status(401).json(.{ .msg = "未授权" });
    };
    
    // 验证 token...
    try next(req, res);
}

// 使用中间件
try app.use(authMiddleware);
try app.route("/admin/*", &handler, &Handler.handle)
    .middleware(authMiddleware);
```

### 4. ORM 查询

```zig
// 查询构建器
const users = try QueryBuilder.init(allocator, "users")
    .select(&[_][]const u8{ "id", "name", "email" })
    .where("status", "=", "active")
    .where("age", ">", "18")
    .orderBy("created_at", .DESC)
    .limit(10)
    .offset(0)
    .get();

// 关联查询
const articles = try QueryBuilder.init(allocator, "articles")
    .join("categories", "articles.category_id", "=", "categories.id")
    .select(&[_][]const u8{ "articles.*", "categories.name as category_name" })
    .get();

// 事务处理
const tx = try db.begin();
errdefer tx.rollback();

try tx.insert("users", user_data);
try tx.insert("profiles", profile_data);

try tx.commit();
```

### 5. 插件系统

```zig
// 生成插件模板
zig build plugin-gen -- MyPlugin

// plugins/my_plugin.zig
pub const MyPlugin = struct {
    pub fn init(allocator: Allocator) !*MyPlugin {
        // 初始化插件
    }
    
    pub fn onRequest(req: *Request) !void {
        // 请求钩子
    }
    
    pub fn onResponse(res: *Response) !void {
        // 响应钩子
    }
};

// 注册插件
try app.registerPlugin(MyPlugin);
```

## 📚 重要文档

### 核心文档

- **[README.md](README.md)** - 项目简介和快速开始
- **[STRUCTURE.md](STRUCTURE.md)** - 详细的项目结构说明
- **[DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md)** - 完整的开发规范
- **[DOCS.md](DOCS.md)** - 技术文档和 API 说明
- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - 使用指南和教程

### 代码文档

- **[docs/CODE_STYLE.md](docs/CODE_STYLE.md)** - 代码风格指南
- **[docs/MEMORY_SAFETY.md](docs/MEMORY_SAFETY.md)** - 内存安全实践
- **[docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)** - 架构设计文档

### API 文档

- **[docs/api/](docs/api/)** - 交互式 API 文档
  - auth.html - 认证接口
  - category.html - 分类管理
  - cms-model.html - CMS 模型
  - document.html - 文档管理
  - member.html - 会员管理
  - role.html - 角色权限

## 🔐 配置管理

### 环境变量（.env）

```bash
# 数据库配置
PG_DATABASE_HOST=localhost
PG_DATABASE_PORT=5432
PG_DATABASE_USER=postgres
PG_DATABASE_PASS=your_password
PG_DATABASE_CLIENT_NAME=zigcms
PG_DATABASE_POOL_SIZE=10

# 服务器配置
SERVER_HOST=localhost
SERVER_PORT=3030
SERVER_ENV=development

# 缓存配置
CACHE_ENABLED=true
CACHE_TTL=3600
CACHE_HOST=127.0.0.1
CACHE_PORT=6379
```

### 生成配置结构

```bash
# 从 .env 自动生成 Zig 配置结构
zig build config-gen

# 生成的配置可在代码中使用
const config = @import("config.zig");
const db_host = config.PG_DATABASE_HOST;
```

## 🧪 测试规范

### 1. 测试分类

#### 1.1 单元测试（Unit Tests）

```zig
//! 单元测试：测试单个函数或方法
//! 文件命名: {module}_test.zig

const std = @import("std");
const testing = std.testing;

// 被测试模块
const strings = @import("strings.zig");

// ============================================================================
// 正常情况测试
// ============================================================================

test "strings.trim removes leading and trailing spaces" {
    const input = "  hello world  ";
    const result = strings.trim(input);
    try testing.expectEqualStrings("hello world", result);
}

test "strings.split splits string by delimiter" {
    const allocator = testing.allocator;
    const input = "a,b,c";
    const result = try strings.split(allocator, input, ",");
    defer allocator.free(result);
    
    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqualStrings("a", result[0]);
    try testing.expectEqualStrings("b", result[1]);
    try testing.expectEqualStrings("c", result[2]);
}

// ============================================================================
// 边界条件测试
// ============================================================================

test "strings.trim handles empty string" {
    const result = strings.trim("");
    try testing.expectEqualStrings("", result);
}

test "strings.trim handles string with only spaces" {
    const result = strings.trim("     ");
    try testing.expectEqualStrings("", result);
}

// ============================================================================
// 错误情况测试
// ============================================================================

test "strings.split returns error on null input" {
    const allocator = testing.allocator;
    try testing.expectError(
        error.InvalidInput,
        strings.split(allocator, null, ",")
    );
}

// ============================================================================
// 内存泄漏检测
// ============================================================================

test "strings functions do not leak memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();
    
    const result = try strings.duplicate(allocator, "test");
    defer allocator.free(result);
    
    try testing.expectEqualStrings("test", result);
}
```

#### 1.2 集成测试（Integration Tests）

```zig
//! 集成测试：测试模块间的交互
//! 文件命名: {module}.integration_test.zig

const std = @import("std");
const testing = std.testing;

const UserService = @import("user_service.zig");
const UserRepository = @import("user_repository.zig");
const Database = @import("database.zig");

// ============================================================================
// 测试设置和清理
// ============================================================================

var test_db: *Database = undefined;
var test_repo: *UserRepository = undefined;
var test_service: *UserService = undefined;

fn setupTest(allocator: std.mem.Allocator) !void {
    // 1. 创建测试数据库
    test_db = try Database.initTest(allocator, ":memory:");
    
    // 2. 运行迁移
    try test_db.migrate();
    
    // 3. 初始化仓库和服务
    test_repo = try UserRepository.init(allocator, test_db);
    test_service = try UserService.init(allocator, test_repo);
}

fn cleanupTest() void {
    test_service.deinit();
    test_repo.deinit();
    test_db.deinit();
}

// ============================================================================
// 完整流程测试
// ============================================================================

test "User registration and login flow" {
    const allocator = testing.allocator;
    try setupTest(allocator);
    defer cleanupTest();
    
    // 1. 注册用户
    const register_dto = UserRegisterDto{
        .username = "testuser",
        .email = "test@example.com",
        .password = "password123",
    };
    
    const user = try test_service.register(register_dto);
    try testing.expect(user.id != null);
    try testing.expectEqualStrings("testuser", user.username);
    
    // 2. 登录验证
    const login_dto = UserLoginDto{
        .username = "testuser",
        .password = "password123",
    };
    
    const token = try test_service.login(login_dto);
    try testing.expect(token.len > 0);
    
    // 3. 获取用户信息
    const found_user = try test_service.getUserById(user.id.?);
    try testing.expectEqualStrings(user.username, found_user.username);
    try testing.expectEqualStrings(user.email, found_user.email);
}

test "User CRUD operations" {
    const allocator = testing.allocator;
    try setupTest(allocator);
    defer cleanupTest();
    
    // 创建
    const create_dto = UserCreateDto{
        .username = "newuser",
        .email = "new@example.com",
        .password = "pass123",
    };
    const user = try test_service.createUser(create_dto);
    const user_id = user.id.?;
    
    // 读取
    const fetched = try test_service.getUserById(user_id);
    try testing.expectEqualStrings("newuser", fetched.username);
    
    // 更新
    const update_dto = UserUpdateDto{
        .id = user_id,
        .username = "updateduser",
    };
    try test_service.updateUser(update_dto);
    
    const updated = try test_service.getUserById(user_id);
    try testing.expectEqualStrings("updateduser", updated.username);
    
    // 删除
    try test_service.deleteUser(user_id);
    try testing.expectError(
        error.UserNotFound,
        test_service.getUserById(user_id)
    );
}

// ============================================================================
// 事务测试
// ============================================================================

test "Transaction rollback on error" {
    const allocator = testing.allocator;
    try setupTest(allocator);
    defer cleanupTest();
    
    const initial_count = try test_repo.count();
    
    // 尝试在事务中创建多个用户，但会失败
    const result = test_service.createMultipleUsers(&[_]UserCreateDto{
        .{ .username = "user1", .email = "user1@test.com", .password = "pass" },
        .{ .username = "user2", .email = "user2@test.com", .password = "pass" },
        .{ .username = "user1", .email = "duplicate@test.com", .password = "pass" }, // 重复用户名
    });
    
    try testing.expectError(error.DuplicateUsername, result);
    
    // 验证事务已回滚，没有创建任何用户
    const final_count = try test_repo.count();
    try testing.expectEqual(initial_count, final_count);
}
```

#### 1.3 数据库测试

```zig
//! 数据库测试：测试 ORM 和 SQL 操作

test "ORM query builder - basic operations" {
    const allocator = testing.allocator;
    const db = try Database.initTest(allocator, ":memory:");
    defer db.deinit();
    
    // 插入
    const user_id = try db.insert("users", .{
        .username = "testuser",
        .email = "test@example.com",
    });
    
    // 查询
    const user = try db.query("users")
        .where("id", "=", user_id)
        .first();
    
    try testing.expectEqualStrings("testuser", user.username);
    
    // 更新
    try db.update("users")
        .where("id", "=", user_id)
        .set(.{ .username = "updated" });
    
    const updated = try db.query("users")
        .where("id", "=", user_id)
        .first();
    
    try testing.expectEqualStrings("updated", updated.username);
    
    // 删除
    try db.delete("users")
        .where("id", "=", user_id)
        .execute();
    
    const count = try db.query("users")
        .where("id", "=", user_id)
        .count();
    
    try testing.expectEqual(@as(usize, 0), count);
}

test "ORM query builder - complex queries" {
    const allocator = testing.allocator;
    const db = try Database.initTest(allocator, ":memory:");
    defer db.deinit();
    
    // 准备测试数据
    try setupTestData(db);
    
    // JOIN 查询
    const articles = try db.query("articles")
        .join("users", "articles.user_id", "=", "users.id")
        .join("categories", "articles.category_id", "=", "categories.id")
        .select(&[_][]const u8{
            "articles.*",
            "users.username as author",
            "categories.name as category",
        })
        .where("articles.status", "=", 1)
        .orderBy("articles.created_at", .DESC)
        .limit(10)
        .get();
    
    defer allocator.free(articles);
    try testing.expect(articles.len > 0);
    
    // 子查询
    const popular_users = try db.query("users")
        .whereIn("id", db.query("articles")
            .select(&[_][]const u8{"user_id"})
            .groupBy("user_id")
            .having("COUNT(*) > ?", .{5}))
        .get();
    
    defer allocator.free(popular_users);
    
    // 聚合查询
    const stats = try db.query("articles")
        .select(&[_][]const u8{
            "category_id",
            "COUNT(*) as count",
            "AVG(views) as avg_views",
        })
        .groupBy("category_id")
        .having("count > ?", .{10})
        .get();
    
    defer allocator.free(stats);
}

test "Database connection pool" {
    const allocator = testing.allocator;
    const pool = try ConnectionPool.init(allocator, .{
        .min_size = 2,
        .max_size = 10,
        .connection_string = ":memory:",
    });
    defer pool.deinit();
    
    // 并发获取连接
    var threads: [5]std.Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, testPoolConnection, .{ pool, i });
    }
    
    for (threads) |thread| {
        thread.join();
    }
    
    // 验证连接池状态
    const stats = pool.getStats();
    try testing.expect(stats.active_connections <= 10);
    try testing.expect(stats.idle_connections >= 2);
}
```

#### 1.4 API 测试

```zig
//! API 测试：测试 HTTP 端点

const TestClient = @import("test_client.zig");

test "User API - registration" {
    const allocator = testing.allocator;
    const client = try TestClient.init(allocator);
    defer client.deinit();
    
    // 发送注册请求
    const response = try client.post("/api/users/register", .{
        .username = "testuser",
        .email = "test@example.com",
        .password = "password123",
    });
    
    // 验证响应
    try testing.expectEqual(@as(u16, 201), response.status);
    try testing.expectEqual(@as(i32, 0), response.json.code);
    try testing.expect(response.json.data.id != null);
}

test "User API - authentication required" {
    const allocator = testing.allocator;
    const client = try TestClient.init(allocator);
    defer client.deinit();
    
    // 未认证请求
    const response = try client.get("/api/users/profile");
    try testing.expectEqual(@as(u16, 401), response.status);
    
    // 登录获取 token
    const login_response = try client.post("/api/users/login", .{
        .username = "testuser",
        .password = "password123",
    });
    const token = login_response.json.data.token;
    
    // 带 token 的请求
    client.setAuthToken(token);
    const profile_response = try client.get("/api/users/profile");
    try testing.expectEqual(@as(u16, 200), profile_response.status);
}
```

### 2. 测试覆盖率要求

| 代码类型 | 最低覆盖率 | 推荐覆盖率 |
|---------|-----------|-----------|
| 业务逻辑（Service） | 80% | 90% |
| 数据访问（Repository） | 75% | 85% |
| API 控制器 | 70% | 80% |
| 工具函数 | 90% | 95% |
| 新功能代码 | 85% | 90% |

### 3. 测试最佳实践

#### 3.1 测试命名规范

```zig
// ✅ 推荐：描述性测试名称
test "createUser returns error when email is invalid" { }
test "getUserById returns UserNotFound when user does not exist" { }
test "updateUser updates only provided fields" { }

// ❌ 避免：模糊的测试名称
test "test1" { }
test "user test" { }
test "it works" { }
```

#### 3.2 AAA 模式（Arrange-Act-Assert）

```zig
test "User service creates user with valid data" {
    // Arrange（准备）
    const allocator = testing.allocator;
    const service = try UserService.init(allocator);
    defer service.deinit();
    
    const dto = UserCreateDto{
        .username = "testuser",
        .email = "test@example.com",
        .password = "pass123",
    };
    
    // Act（执行）
    const user = try service.createUser(dto);
    
    // Assert（断言）
    try testing.expect(user.id != null);
    try testing.expectEqualStrings("testuser", user.username);
    try testing.expectEqualStrings("test@example.com", user.email);
}
```

#### 3.3 测试数据管理

```zig
// ✅ 推荐：使用 fixture 或 factory
const TestFixtures = struct {
    pub fn createTestUser(allocator: Allocator) !User {
        return User{
            .id = 1,
            .username = "testuser",
            .email = "test@example.com",
            .created_at = std.time.timestamp(),
        };
    }
    
    pub fn createTestArticle(allocator: Allocator, user_id: i32) !Article {
        return Article{
            .id = 1,
            .title = "Test Article",
            .content = "Test content",
            .user_id = user_id,
            .created_at = std.time.timestamp(),
        };
    }
};

test "Article belongs to user" {
    const allocator = testing.allocator;
    const user = try TestFixtures.createTestUser(allocator);
    const article = try TestFixtures.createTestArticle(allocator, user.id.?);
    
    try testing.expectEqual(user.id, article.user_id);
}
```

#### 3.4 Mock 和 Stub

```zig
// Mock 接口实现
const MockUserRepository = struct {
    allocator: Allocator,
    users: std.ArrayList(User),
    
    pub fn init(allocator: Allocator) !*MockUserRepository {
        const self = try allocator.create(MockUserRepository);
        self.* = .{
            .allocator = allocator,
            .users = std.ArrayList(User).init(allocator),
        };
        return self;
    }
    
    pub fn deinit(self: *MockUserRepository) void {
        self.users.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn save(self: *MockUserRepository, user: User) !User {
        var new_user = user;
        new_user.id = @intCast(self.users.items.len + 1);
        try self.users.append(new_user);
        return new_user;
    }
    
    pub fn findById(self: *MockUserRepository, id: i32) !?User {
        for (self.users.items) |user| {
            if (user.id == id) return user;
        }
        return null;
    }
};

test "UserService uses repository correctly" {
    const allocator = testing.allocator;
    const mock_repo = try MockUserRepository.init(allocator);
    defer mock_repo.deinit();
    
    const service = UserService.init(allocator, mock_repo);
    
    const dto = UserCreateDto{
        .username = "test",
        .email = "test@test.com",
        .password = "pass",
    };
    
    const user = try service.createUser(dto);
    try testing.expect(user.id != null);
    
    // 验证 mock 被正确调用
    try testing.expectEqual(@as(usize, 1), mock_repo.users.items.len);
}
```

### 4. 测试工具和辅助函数

```zig
// 测试辅助函数
pub const TestHelpers = struct {
    /// 比较两个结构体是否相等（忽略某些字段）
    pub fn expectEqualIgnoring(
        comptime T: type,
        expected: T,
        actual: T,
        comptime ignore_fields: []const []const u8,
    ) !void {
        inline for (@typeInfo(T).Struct.fields) |field| {
            var should_ignore = false;
            for (ignore_fields) |ignore| {
                if (std.mem.eql(u8, field.name, ignore)) {
                    should_ignore = true;
                    break;
                }
            }
            if (!should_ignore) {
                try testing.expectEqual(
                    @field(expected, field.name),
                    @field(actual, field.name),
                );
            }
        }
    }
    
    /// 断言数组包含特定元素
    pub fn expectContains(
        comptime T: type,
        haystack: []const T,
        needle: T,
    ) !void {
        for (haystack) |item| {
            if (std.meta.eql(item, needle)) return;
        }
        return error.ElementNotFound;
    }
    
    /// 断言函数在指定时间内完成
    pub fn expectCompletesWithin(
        comptime func: anytype,
        args: anytype,
        max_duration_ms: u64,
    ) !void {
        const start = std.time.milliTimestamp();
        _ = try @call(.auto, func, args);
        const duration = std.time.milliTimestamp() - start;
        
        if (duration > max_duration_ms) {
            return error.TookTooLong;
        }
    }
};
```

## 🚢 部署指南

### 生产构建

```bash
# 优化构建
zig build -Doptimize=ReleaseSafe

# 输出位置
./zig-out/bin/vendor

# 运行
./zig-out/bin/vendor --port 3030
```

### Docker 部署（推荐）

```dockerfile
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    libstdc++ \
    mysql-client \
    postgresql-client

# 复制二进制文件
COPY zig-out/bin/vendor /app/vendor
COPY resources /app/resources
COPY .env /app/.env

WORKDIR /app
EXPOSE 3030

CMD ["./vendor"]
```

### 系统服务（systemd）

```ini
[Unit]
Description=ZigCMS Service
After=network.target

[Service]
Type=simple
User=zigcms
WorkingDirectory=/opt/zigcms
ExecStart=/opt/zigcms/vendor
Restart=always

[Install]
WantedBy=multi-user.target
```

## 🐛 调试技巧

### 日志级别

```zig
const logger = @import("application/services/logger/logger.zig");

logger.debug("调试信息: {}", .{value});
logger.info("普通信息: {s}", .{message});
logger.warn("警告: {}", .{error_code});
logger.err("错误: {}", .{err});
```

### 内存调试

```bash
# 使用 GPA 检测内存泄漏
zig build run

# 使用 Valgrind (Linux)
valgrind --leak-check=full ./zig-out/bin/vendor

# 使用 ASAN (Address Sanitizer)
zig build -Doptimize=Debug -fsanitize=address
```

### 性能分析

```bash
# 使用 perf (Linux)
perf record -g ./zig-out/bin/vendor
perf report

# 使用 Instruments (macOS)
instruments -t "Time Profiler" ./zig-out/bin/vendor
```

## 📊 项目状态

### 已实现功能

- ✅ 整洁架构分层
- ✅ 自动 CRUD API
- ✅ 多数据库支持（MySQL、SQLite、PostgreSQL）
- ✅ ORM 和查询构建器
- ✅ 中间件系统
- ✅ 插件系统
- ✅ JWT 认证
- ✅ 文件上传
- ✅ 缓存服务
- ✅ 日志系统
- ✅ 后台管理界面
- ✅ API 文档生成

### 开发中功能

- 🚧 GraphQL 支持
- 🚧 WebSocket 实时通信
- 🚧  任务队列
- 🚧 全文搜索
- 🚧 多语言支持

### 计划功能

- 📋 微服务支持
- 📋 分布式缓存
- 📋 消息队列集成
- 📋 监控和告警

## 🤝 贡献指南

### 开发流程

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

### 代码审查

- 遵循 [DEVELOPMENT_SPEC.md](DEVELOPMENT_SPEC.md) 规范
- 确保所有测试通过
- 添加必要的文档
- 保持代码简洁和可读

## 📞 支持和反馈

- **GitHub Issues**: https://github.com/xiusin/zigcms/issues
- **文档**: 查看 docs/ 目录
- **示例**: 查看 tests/ 目录

## 📝 许可证

本项目采用 MIT 许可证 - 详见 LICENSE 文件

---

**最后更新**: 2025-12-17  
**维护者**: ZigCMS Team  
**版本**: 0.0.0

---

## 🎓 iFlow AI 助手提示

### 常见任务

当用户请求以下任务时，请参考：

1. **创建新控制器**
   - 位置: `api/controllers/`
   - 命名: `{module}.controller.zig`
   - 参考: `api/controllers/auth/login.controller.zig`

2. **添加新模型**
   - 位置: `domain/entities/`
   - 命名: `{model}.model.zig`
   - 参考: `domain/entities/admin.model.zig`

3. **创建 DTO**
   - 位置: `api/dto/`
   - 命名: `{model}_{action}.dto.zig`
   - 参考: `api/dto/user_login.dto.zig`

4. **添加中间件**
   - 位置: `api/middleware/`
   - 命名: `{name}.middleware.zig`
   - 参考: `api/middleware/auth.middleware.zig`

5. **创建服务**
   - 位置: `application/services/`
   - 参考现有服务结构

### 重要提醒

- ⚠️ 始终使用 `try` 处理错误，不要使用 `catch unreachable`
- ⚠️ 明确内存分配器来源，使用 `defer` 释放资源
- ⚠️ 遵循整洁架构依赖规则
- ⚠️ 使用 `mod.zig` 约定组织模块
- ⚠️ 参考 DEVELOPMENT_SPEC.md 了解详细规范
- ⚠️ 运行测试确保代码质量 (`zig build test`)

### 快速参考

```bash
# 常用命令
zig build                    # 构建
zig build run               # 运行
zig build test              # 测试
zig build codegen -- help   # 代码生成帮助
```

### 关键文件

- `main.zig` - 程序入口，路由注册
- `build.zig` - 构建配置，依赖管理
- `api/App.zig` - 应用框架核心
- `root.zig` - 项目根模块
- `.env` - 环境配置

祝您开发愉快！🚀
