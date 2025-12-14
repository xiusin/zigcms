# ZigCMS 开发规范

## 概述

本文档定义了 ZigCMS 项目的开发规范和标准，用于指导所有开发人员（包括人类和AI）进行一致、高质量的代码开发。该规范旨在确保项目的可维护性、可扩展性、安全性和性能。

**版本**: 1.0.0
**最后更新**: 2025-12-14
**适用范围**: 所有 ZigCMS 项目参与者

## 目录

1. [代码风格与命名规范](#代码风格与命名规范)
2. [架构设计原则](#架构设计原则)
3. [API设计规范](#API设计规范)
4. [数据库设计规范](#数据库设计规范)
5. [测试规范](#测试规范)
6. [文档规范](#文档规范)
7. [安全规范](#安全规范)
8. [性能规范](#性能规范)
9. [版本控制规范](#版本控制规范)
10. [部署规范](#部署规范)

## 代码风格与命名规范

### 1.1 Zig 语言规范

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
