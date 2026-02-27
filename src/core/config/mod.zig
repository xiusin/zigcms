//! 配置管理模块 (Config Module)
//!
//! 提供配置加载和管理功能，从原 shared/config 迁移而来。

const std = @import("std");

/// 系统配置
pub const SystemConfig = struct {
    api: ApiConfig = .{},
    app: AppConfig = .{},
    domain: DomainConfig = .{},
    infra: InfraConfig = .{},
    shared: SharedConfig = .{},
};

/// API 层配置
pub const ApiConfig = struct {
    host: []const u8 = "0.0.0.0",
    port: u16 = 8080,
    max_clients: u32 = 1000,
    timeout: u32 = 30,
    public_folder: []const u8 = "public",
};

/// 应用层配置
pub const AppConfig = struct {
    enable_cache: bool = true,
    cache_ttl_seconds: u64 = 3600,
    max_concurrent_tasks: u32 = 100,
    enable_plugins: bool = true,
    plugin_directory: []const u8 = "plugins",
};

/// 领域层配置
pub const DomainConfig = struct {
    validate_models: bool = true,
    enforce_business_rules: bool = true,
};

/// 基础设施层配置
pub const InfraConfig = struct {
    pub const DatabaseEngine = enum { sqlite, mysql };

    db_engine: DatabaseEngine = .sqlite,
    db_host: []const u8 = "localhost",
    db_port: u16 = 3306,
    db_name: []const u8 = "zigcms",
    db_user: []const u8 = "root",
    db_password: []const u8 = "",
    db_pool_size: u32 = 10,

    cache_enabled: bool = true,
    cache_host: []const u8 = "localhost",
    cache_port: u16 = 6379,
    cache_password: ?[]const u8 = null,
    cache_ttl: u64 = 3600,

    http_timeout_ms: u32 = 30000,
};

/// 共享层配置
pub const SharedConfig = struct {
    log_level: LogLevel = .Info,
    debug_mode: bool = false,

    pub const LogLevel = enum {
        Debug,
        Info,
        Warn,
        Error,
    };
};

/// 配置加载器
pub const ConfigLoader = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .config_dir = config_dir,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 加载所有配置
    pub fn loadAll(self: *Self) !SystemConfig {
        _ = self;
        return SystemConfig{};
    }

    /// 验证配置
    pub fn validate(self: *Self, config: *const SystemConfig) !void {
        _ = self;
        _ = config;
    }
};
