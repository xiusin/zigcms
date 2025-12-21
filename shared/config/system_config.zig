//! 系统配置结构体定义
//!
//! 本模块定义 ZigCMS 的配置结构体，每个配置文件对应一个结构体：
//! - api.toml → ApiConfig
//! - app.toml → AppConfig
//! - domain.toml → DomainConfig
//! - infra.toml → InfraConfig
//!
//! ## 使用示例
//! ```zig
//! const config = @import("shared/config/system_config.zig");
//!
//! var sys_config = config.SystemConfig{
//!     .api = .{ .port = 8080 },
//!     .app = .{ .enable_cache = true },
//! };
//! ```

const std = @import("std");

/// API 层配置 (对应 api.toml)
///
/// 配置 HTTP 服务器的运行参数。
pub const ApiConfig = struct {
    /// 监听地址
    /// 默认: "127.0.0.1"
    host: []const u8 = "127.0.0.1",

    /// 监听端口
    /// 默认: 3000
    port: u16 = 3000,

    /// 最大客户端连接数
    /// 默认: 10000
    max_clients: u32 = 10000,

    /// 请求超时时间（秒）
    /// 默认: 30
    timeout: u32 = 30,

    /// 静态资源目录
    /// 默认: "resources"
    public_folder: []const u8 = "resources",

    /// 打印配置信息
    pub fn print(self: *const ApiConfig) void {
        std.debug.print("API 配置:\n", .{});
        std.debug.print("  - host: {s}\n", .{self.host});
        std.debug.print("  - port: {}\n", .{self.port});
        std.debug.print("  - max_clients: {}\n", .{self.max_clients});
        std.debug.print("  - timeout: {}s\n", .{self.timeout});
        std.debug.print("  - public_folder: {s}\n", .{self.public_folder});
    }
};

/// 应用层配置 (对应 app.toml)
///
/// 控制应用层的行为，如缓存策略、插件系统等。
pub const AppConfig = struct {
    /// 是否启用缓存
    /// 默认: true
    enable_cache: bool = true,

    /// 缓存默认 TTL（秒）
    /// 默认: 3600
    cache_ttl_seconds: u64 = 3600,

    /// 最大并发任务数
    /// 默认: 100
    max_concurrent_tasks: u32 = 100,

    /// 是否启用插件系统
    /// 默认: true
    enable_plugins: bool = true,

    /// 插件目录
    /// 默认: "plugins"
    plugin_directory: []const u8 = "plugins",

    /// 是否启用事件系统
    /// 默认: true
    enable_events: bool = true,

    /// 事件队列大小
    /// 默认: 1000
    event_queue_size: u32 = 1000,

    /// 打印配置信息
    pub fn print(self: *const AppConfig) void {
        std.debug.print("应用配置:\n", .{});
        std.debug.print("  - enable_cache: {}\n", .{self.enable_cache});
        std.debug.print("  - cache_ttl_seconds: {}\n", .{self.cache_ttl_seconds});
        std.debug.print("  - max_concurrent_tasks: {}\n", .{self.max_concurrent_tasks});
        std.debug.print("  - enable_plugins: {}\n", .{self.enable_plugins});
        std.debug.print("  - plugin_directory: {s}\n", .{self.plugin_directory});
    }
};

/// 领域层配置 (对应 domain.toml)
///
/// 控制领域层的行为，如模型验证、业务规则执行等。
pub const DomainConfig = struct {
    /// 是否验证模型数据
    /// 默认: true
    validate_models: bool = true,

    /// 是否强制执行业务规则
    /// 默认: true
    enforce_business_rules: bool = true,

    /// 打印配置信息
    pub fn print(self: *const DomainConfig) void {
        std.debug.print("领域配置:\n", .{});
        std.debug.print("  - validate_models: {}\n", .{self.validate_models});
        std.debug.print("  - enforce_business_rules: {}\n", .{self.enforce_business_rules});
    }
};

/// 基础设施层配置 (对应 infra.toml)
///
/// 配置数据库连接、缓存服务、HTTP 客户端等外部服务参数。
pub const InfraConfig = struct {
    // ========================================================================
    // 数据库配置
    // ========================================================================

    /// 数据库主机地址
    /// 默认: "localhost"
    db_host: []const u8 = "localhost",

    /// 数据库端口
    /// 默认: 5432 (PostgreSQL)
    db_port: u16 = 5432,

    /// 数据库名称
    /// 默认: "zigcms"
    db_name: []const u8 = "zigcms",

    /// 数据库用户名
    /// 默认: "postgres"
    db_user: []const u8 = "postgres",

    /// 数据库密码
    /// 默认: "password"
    /// 注意: 生产环境应通过环境变量 ZIGCMS_DB_PASSWORD 设置
    db_password: []const u8 = "password",

    /// 数据库连接池大小
    /// 默认: 10
    db_pool_size: u32 = 10,

    // ========================================================================
    // 缓存配置
    // ========================================================================

    /// 是否启用缓存
    /// 默认: true
    cache_enabled: bool = true,

    /// 缓存主机地址
    /// 默认: "localhost"
    cache_host: []const u8 = "localhost",

    /// 缓存端口
    /// 默认: 6379 (Redis)
    cache_port: u16 = 6379,

    /// 缓存密码（可选）
    /// 默认: null
    cache_password: ?[]const u8 = null,

    /// 缓存默认 TTL（秒）
    /// 默认: 3600
    cache_ttl: u64 = 3600,

    // ========================================================================
    // HTTP 客户端配置
    // ========================================================================

    /// HTTP 请求超时时间（毫秒）
    /// 默认: 5000
    http_timeout_ms: u32 = 5000,

    /// HTTP 最大重定向次数
    /// 默认: 5
    http_max_redirects: u32 = 5,

    /// 打印配置信息
    pub fn print(self: *const InfraConfig) void {
        std.debug.print("基础设施配置:\n", .{});
        std.debug.print("  数据库:\n", .{});
        std.debug.print("    - host: {s}\n", .{self.db_host});
        std.debug.print("    - port: {}\n", .{self.db_port});
        std.debug.print("    - name: {s}\n", .{self.db_name});
        std.debug.print("    - user: {s}\n", .{self.db_user});
        std.debug.print("    - password: ****\n", .{});
        std.debug.print("    - pool_size: {}\n", .{self.db_pool_size});
        std.debug.print("  缓存:\n", .{});
        std.debug.print("    - enabled: {}\n", .{self.cache_enabled});
        std.debug.print("    - host: {s}\n", .{self.cache_host});
        std.debug.print("    - port: {}\n", .{self.cache_port});
        std.debug.print("    - ttl: {}s\n", .{self.cache_ttl});
        std.debug.print("  HTTP:\n", .{});
        std.debug.print("    - timeout: {}ms\n", .{self.http_timeout_ms});
        std.debug.print("    - max_redirects: {}\n", .{self.http_max_redirects});
    }
};

/// 系统主配置
///
/// 包含所有层的配置选项，对应 configs/ 目录下的 TOML 文件。
pub const SystemConfig = struct {
    /// API 层配置 (api.toml)
    api: ApiConfig = .{},

    /// 应用层配置 (app.toml)
    app: AppConfig = .{},

    /// 领域层配置 (domain.toml)
    domain: DomainConfig = .{},

    /// 基础设施层配置 (infra.toml)
    infra: InfraConfig = .{},

    /// 打印所有配置信息
    pub fn print(self: *const SystemConfig) void {
        std.debug.print("\n========== ZigCMS 配置 ==========\n", .{});
        self.api.print();
        std.debug.print("\n", .{});
        self.app.print();
        std.debug.print("\n", .{});
        self.domain.print();
        std.debug.print("\n", .{});
        self.infra.print();
        std.debug.print("=================================\n\n", .{});
    }

    /// 获取数据库连接字符串
    pub fn getDatabaseUrl(self: *const SystemConfig, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "postgresql://{s}:{s}@{s}:{}/{s}", .{
            self.infra.db_user,
            self.infra.db_password,
            self.infra.db_host,
            self.infra.db_port,
            self.infra.db_name,
        });
    }

    /// 获取缓存连接字符串
    pub fn getCacheUrl(self: *const SystemConfig, allocator: std.mem.Allocator) ![]const u8 {
        if (self.infra.cache_password) |password| {
            return std.fmt.allocPrint(allocator, "redis://:{s}@{s}:{}", .{
                password,
                self.infra.cache_host,
                self.infra.cache_port,
            });
        } else {
            return std.fmt.allocPrint(allocator, "redis://{s}:{}", .{
                self.infra.cache_host,
                self.infra.cache_port,
            });
        }
    }
};

// ============================================================================
// 测试
// ============================================================================

test "SystemConfig - default values" {
    const config = SystemConfig{};

    // API 默认值
    try std.testing.expectEqualStrings("127.0.0.1", config.api.host);
    try std.testing.expectEqual(@as(u16, 3000), config.api.port);
    try std.testing.expectEqual(@as(u32, 10000), config.api.max_clients);

    // App 默认值
    try std.testing.expect(config.app.enable_cache);
    try std.testing.expectEqual(@as(u64, 3600), config.app.cache_ttl_seconds);

    // Domain 默认值
    try std.testing.expect(config.domain.validate_models);
    try std.testing.expect(config.domain.enforce_business_rules);

    // Infra 默认值
    try std.testing.expectEqualStrings("localhost", config.infra.db_host);
    try std.testing.expectEqual(@as(u16, 5432), config.infra.db_port);
}

test "ApiConfig - custom values" {
    const config = ApiConfig{
        .host = "0.0.0.0",
        .port = 8080,
        .max_clients = 5000,
    };

    try std.testing.expectEqualStrings("0.0.0.0", config.host);
    try std.testing.expectEqual(@as(u16, 8080), config.port);
    try std.testing.expectEqual(@as(u32, 5000), config.max_clients);
}

test "InfraConfig - database url" {
    var config = SystemConfig{};
    config.infra.db_host = "db.example.com";
    config.infra.db_port = 5433;
    config.infra.db_name = "testdb";
    config.infra.db_user = "testuser";
    config.infra.db_password = "testpass";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const url = try config.getDatabaseUrl(allocator);
    defer allocator.free(url);

    try std.testing.expectEqualStrings("postgresql://testuser:testpass@db.example.com:5433/testdb", url);
}
