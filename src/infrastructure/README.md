# 基础设施层 (Infrastructure Layer)

## 概述

基础设施层是 ZigCMS 项目的核心外部服务实现模块。该层负责与外部系统（如数据库、缓存服务器、HTTP 服务）的交互，实现了领域层定义的仓储接口。

## 职责

- **外部服务集成**: 提供数据库、缓存、HTTP 客户端等外部服务的具体实现
- **适配器模式**: 作为外部系统的适配器，实现领域层的接口契约
- **资源管理**: 管理连接池、事务处理、资源生命周期
- **抽象屏蔽**: 对上层屏蔽外部服务的具体实现细节

## 架构原则

遵循清洁架构（Clean Architecture）原则：

- **依赖倒置**: 基础设施层实现领域层定义的接口
- **外部隔离**: 外部服务的变化不会影响业务逻辑
- **可替换性**: 可以轻松替换不同的外部服务实现

## 模块结构

### database/ - 数据库基础设施
- 支持多种数据库驱动（SQLite、PostgreSQL、MySQL）
- 提供连接池管理和事务处理
- 实现领域层的仓储接口

### cache/ - 缓存基础设施
- 统一的缓存接口，支持多种后端（内存、Redis、Memcached）
- TTL（生存时间）管理
- 缓存清理和失效策略

### http/ - HTTP 客户端基础设施
- 提供 HTTP 客户端功能
- 支持各种 HTTP 方法（GET、POST、PUT、DELETE 等）
- 超时设置和重试机制
- 用于与外部 API 交互

### messaging/ - 消息队列基础设施（规划中）
- 异步任务处理
- 事件驱动架构支持

## 配置

基础设施层通过 `InfraConfig` 结构体进行配置：

```zig
const config = infra.InfraConfig{
    // 数据库配置
    .db_host = "localhost",
    .db_port = 5432,
    .db_name = "zigcms",
    .db_user = "postgres",
    .db_password = "password",
    .db_pool_size = 10,

    // 缓存配置
    .cache_enabled = true,
    .cache_backend = .Redis,
    .cache_host = "localhost",
    .cache_port = 6379,
    .cache_ttl = 3600,

    // HTTP 配置
    .http_timeout_ms = 30000,
    .http_max_redirects = 5,
};
```

## 使用方式

### 初始化

```zig
const infra = @import("infrastructure/mod.zig");

// 初始化基础设施层
const db = try infra.init(allocator, config);
defer infra.deinit();
```

### 使用数据库

```zig
// 获取数据库连接
const conn = try infra.database.DatabaseFactory.create(allocator, .SQLite, config);
// 使用连接...
defer conn.close();
```

### 使用缓存

```zig
// 创建缓存实例
const cache = try infra.cache.CacheFactory.create(allocator, config);

// 设置缓存
try cache.set("key", "value", 3600);

// 获取缓存
const value = try cache.get("key");
```

### 使用 HTTP 客户端

```zig
// 创建 HTTP 客户端
const client = infra.http.Client.init(allocator, config);

// 发送请求
const response = try client.get("https://api.example.com/data");
defer response.deinit();
```

## 依赖关系

```
基础设施层
    ↑ 实现接口
领域层 (Domain Layer)
    ↑ 定义接口
应用层 (Application Layer)
    ↑ 调用服务
表现层 (Presentation Layer)
```

- **依赖领域层**: 实现领域层定义的仓储接口
- **被应用层依赖**: 提供外部服务给应用层使用
- **独立性**: 不依赖表现层，保持业务逻辑纯净

### 跨层调用示例

以下是展示各层之间调用关系的完整代码示例：

```zig
// 表现层 (Presentation Layer) - API 控制器
pub fn getUserHandler(request: *HttpRequest, response: *HttpResponse) !void {
    // 表现层调用应用层服务
    const user_service = application.services.UserService{};
    const user = try user_service.getUser(request.params.user_id);
    
    // 返回响应
    try response.json(user);
}

// 应用层 (Application Layer) - 业务服务
pub const UserService = struct {
    user_repository: domain.repositories.UserRepository,

    pub fn getUser(self: *UserService, user_id: []const u8) !domain.entities.User {
        // 应用层调用领域层接口
        return try self.user_repository.findById(user_id);
    }
};

// 领域层 (Domain Layer) - 仓储接口定义
pub const UserRepository = struct {
    // 领域层定义接口，由基础设施层实现
    findByIdFn: *const fn ([]const u8) anyerror!domain.entities.User,

    pub fn findById(self: UserRepository, user_id: []const u8) !domain.entities.User {
        return self.findByIdFn(user_id);
    }
};

// 基础设施层 (Infrastructure Layer) - 接口实现
pub const SqliteUserRepository = struct {
    db: *sql.Database,

    pub fn init(db: *sql.Database) SqliteUserRepository {
        return .{ .db = db };
    }

    // 实现领域层定义的接口
    pub fn findById(self: SqliteUserRepository, user_id: []const u8) !domain.entities.User {
        // 基础设施层直接与外部系统交互
        const query = "SELECT id, name, email FROM users WHERE id = ?";
        var stmt = try self.db.prepare(query);
        defer stmt.deinit();

        const row = try stmt.one(domain.entities.User, .{user_id});
        return row orelse error.UserNotFound;
    }
};

// 在应用启动时组装依赖关系
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // 1. 初始化基础设施层
    const config = infra.InfraConfig{ /* 配置 */ };
    const db = try infra.init(allocator, config);
    defer infra.deinit();
    
    // 2. 创建基础设施层实现
    const user_repo_impl = SqliteUserRepository.init(db);
    
    // 3. 创建领域层接口（注入基础设施实现）
    const user_repository = domain.repositories.UserRepository{
        .findByIdFn = user_repo_impl.findById,
    };
    
    // 4. 创建应用层服务（注入领域层接口）
    const user_service = application.services.UserService{
        .user_repository = user_repository,
    };
    
    // 5. 启动表现层（注入应用层服务）
    var server = presentation.Server.init(allocator, .{
        .user_service = user_service,
    });
    defer server.deinit();
    
    try server.start();
}
```

这个示例展示了清洁架构的依赖倒置原则：

- **表现层** 只依赖应用层，不感知基础设施细节
- **应用层** 只依赖领域层接口，不依赖具体实现
- **领域层** 定义业务规则和接口契约
- **基础设施层** 实现领域接口，与外部系统交互

通过依赖注入，各层解耦，便于测试和替换实现。

## 安全考虑

- **连接安全**: 支持 SSL/TLS 连接
- **认证管理**: 安全存储和管理数据库凭据
- **资源限制**: 连接池大小限制防止资源耗尽
- **错误处理**: 完善的错误处理和日志记录

## 性能优化

- **连接池**: 复用数据库连接减少开销
- **缓存策略**: 多层缓存提高响应速度
- **异步处理**: 支持异步 I/O 操作
- **监控指标**: 提供性能监控和健康检查

## 测试

基础设施层包含完整的单元测试和集成测试：

- **单元测试**: 测试各个组件的独立功能
- **集成测试**: 测试与外部服务的交互
- **模拟测试**: 使用 mock 对象测试依赖关系

### 单元测试示例

```zig
const std = @import("std");
const testing = std.testing;
const infra = @import("infrastructure/mod.zig");

// 测试基础设施层初始化
test "infrastructure init/deinit" {
    const allocator = testing.allocator;

    // 创建测试配置
    const config = infra.InfraConfig{
        .db_name = ":memory:", // 使用内存数据库进行测试
        .cache_enabled = false, // 禁用缓存
    };

    // 测试初始化
    const db = try infra.init(allocator, config);
    defer infra.deinit();

    // 验证数据库连接有效
    try testing.expect(db != null);
}

// 测试缓存功能
test "cache basic operations" {
    const allocator = testing.allocator;

    // 创建内存缓存实例
    const cache = try infra.cache.CacheFactory.create(allocator, .{
        .cache_backend = .Memory,
        .cache_enabled = true,
    });
    defer cache.deinit();

    // 测试设置和获取
    try cache.set("test_key", "test_value", 3600);
    const value = try cache.get("test_key");
    defer if (value) |v| allocator.free(v);

    try testing.expect(value != null);
    try testing.expect(std.mem.eql(u8, value.?, "test_value"));
}
```

### 集成测试示例

```zig
const std = @import("std");
const testing = std.testing;

// 集成测试：数据库和缓存的协同工作
test "database and cache integration" {
    const allocator = testing.allocator;

    // 设置测试数据库
    const config = infra.InfraConfig{
        .db_name = "test.db",
        .cache_enabled = true,
        .cache_backend = .Memory,
    };

    // 初始化基础设施
    const db = try infra.init(allocator, config);
    defer infra.deinit();

    // 创建缓存实例
    const cache = try infra.cache.CacheFactory.create(allocator, config);
    defer cache.deinit();

    // 执行数据库操作
    const user_id = "user_123";
    const user_data = "{\"name\": \"John Doe\", \"email\": \"john@example.com\"}";

    // 模拟业务逻辑：从数据库读取后缓存
    try cache.set(user_id, user_data, 3600);

    // 验证缓存中存在数据
    const cached_data = try cache.get(user_id);
    defer if (cached_data) |data| allocator.free(data);

    try testing.expect(cached_data != null);
    try testing.expect(std.mem.eql(u8, cached_data.?, user_data));

    // 清理测试数据
    _ = std.fs.cwd().deleteFile("test.db") catch {};
}
```

### 模拟测试示例

```zig
const std = @import("std");
const testing = std.testing;

// Mock HTTP 客户端用于测试
const MockHttpClient = struct {
    allocator: std.mem.Allocator,
    responses: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) MockHttpClient {
        return .{
            .allocator = allocator,
            .responses = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MockHttpClient) void {
        var iter = self.responses.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.responses.deinit();
    }

    pub fn mockResponse(self: *MockHttpClient, url: []const u8, response: []const u8) !void {
        const response_copy = try self.allocator.dupe(u8, response);
        try self.responses.put(url, response_copy);
    }

    pub fn get(self: *MockHttpClient, url: []const u8) ![]const u8 {
        return self.responses.get(url) orelse error.MockNotFound;
    }
};

// 使用 Mock 测试 HTTP 客户端集成
test "http client with mock" {
    const allocator = testing.allocator;

    // 创建 Mock HTTP 客户端
    var mock_client = MockHttpClient.init(allocator);
    defer mock_client.deinit();

    // 设置模拟响应
    try mock_client.mockResponse(
        "https://api.example.com/users/123",
        "{\"id\": 123, \"name\": \"Test User\"}"
    );

    // 测试获取模拟数据
    const response = try mock_client.get("https://api.example.com/users/123");
    defer allocator.free(response);

    // 验证响应内容
    try testing.expect(std.mem.indexOf(u8, response, "\"id\": 123") != null);
    try testing.expect(std.mem.indexOf(u8, response, "\"name\": \"Test User\"") != null);
}

// 测试基础设施层的错误处理
test "infrastructure error handling" {
    const allocator = testing.allocator;

    // 使用无效配置测试错误处理
    const invalid_config = infra.InfraConfig{
        .db_name = "", // 无效的数据库名称
        .cache_enabled = false,
    };

    // 验证初始化失败
    const result = infra.init(allocator, invalid_config);
    try testing.expectError(error.InvalidDatabaseConfig, result);
}
```

### 运行测试

```bash
# 运行所有测试
zig build test

# 运行特定模块的测试
zig build test --mod infrastructure

# 运行带覆盖率的测试
zig build test --coverage
```

## 扩展性

模块设计支持轻松扩展：

- **新数据库支持**: 实现新的数据库驱动
- **新缓存后端**: 添加新的缓存存储方式
- **新外部服务**: 集成新的外部 API 或服务

## 注意事项

- 初始化时确保外部服务可用
- 正确处理资源清理（defer 语句）
- 监控连接池使用情况
- 定期检查外部服务健康状态

## 相关文档

- [项目架构文档](../../docs/architecture.md)
- [API 文档](../../docs/api/)
- [部署指南](../../docs/deployment.md)
