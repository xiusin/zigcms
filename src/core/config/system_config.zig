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
const SharedConfig = @import("../mod.zig").SharedConfig;
pub const DomainConfig = @import("../../domain/mod.zig").DomainConfig;
pub const AppConfig = @import("../../application/mod.zig").AppConfig;
pub const ServerConfig = @import("../../api/Api.zig").ServerConfig;

/// API 层配置 (对应 api.toml)
pub const ApiConfig = ServerConfig;

/// 基础设施层配置
pub const InfraConfig = @import("../../infrastructure/mod.zig").InfraConfig;

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

    /// 共享层配置 (shared.toml)
    shared: SharedConfig = .{},

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
