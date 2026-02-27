const std = @import("std");
const AutoConfigLoader = @import("auto_loader.zig").AutoConfigLoader;
const SystemConfig = @import("system_config.zig").SystemConfig;
const ApiConfig = @import("system_config.zig").ApiConfig;
const AppConfig = @import("system_config.zig").AppConfig;
const DomainConfig = @import("system_config.zig").DomainConfig;
const InfraConfig = @import("system_config.zig").InfraConfig;

pub const ConfigLoaderV2 = struct {
    auto_loader: AutoConfigLoader,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) Self {
        return .{
            .auto_loader = AutoConfigLoader.init(allocator, config_dir),
        };
    }

    pub fn deinit(self: *Self) void {
        self.auto_loader.deinit();
    }

    pub fn loadAll(self: *Self) !SystemConfig {
        var config = SystemConfig{};

        config.api = self.auto_loader.loadConfigOr(ApiConfig, "api.json", .{});
        config.app = self.auto_loader.loadConfigOr(AppConfig, "app.json", .{});
        config.domain = self.auto_loader.loadConfigOr(DomainConfig, "domain.json", .{});
        config.infra = self.auto_loader.loadConfigOr(InfraConfig, "infra.json", .{});

        try self.applyEnvOverrides(&config);

        return config;
    }

    fn applyEnvOverrides(self: *Self, sys_config: *SystemConfig) !void {
        try self.auto_loader.applyEnvOverrides(InfraConfig, &sys_config.infra, &.{
            .{ .field = "db_host", .env = "ZIGCMS_DB_HOST" },
            .{ .field = "db_port", .env = "ZIGCMS_DB_PORT" },
            .{ .field = "db_name", .env = "ZIGCMS_DB_NAME" },
            .{ .field = "db_user", .env = "ZIGCMS_DB_USER" },
            .{ .field = "db_password", .env = "ZIGCMS_DB_PASSWORD" },
            .{ .field = "db_pool_size", .env = "ZIGCMS_DB_POOL_SIZE" },
            .{ .field = "cache_enabled", .env = "ZIGCMS_CACHE_ENABLED" },
            .{ .field = "cache_host", .env = "ZIGCMS_CACHE_HOST" },
            .{ .field = "cache_port", .env = "ZIGCMS_CACHE_PORT" },
            .{ .field = "cache_ttl", .env = "ZIGCMS_CACHE_TTL" },
            .{ .field = "http_timeout_ms", .env = "ZIGCMS_HTTP_TIMEOUT_MS" },
        });

        try self.auto_loader.applyEnvOverrides(ApiConfig, &sys_config.api, &.{
            .{ .field = "host", .env = "ZIGCMS_API_HOST" },
            .{ .field = "port", .env = "ZIGCMS_API_PORT" },
            .{ .field = "max_clients", .env = "ZIGCMS_API_MAX_CLIENTS" },
            .{ .field = "timeout", .env = "ZIGCMS_API_TIMEOUT" },
        });

        try self.auto_loader.applyEnvOverrides(AppConfig, &sys_config.app, &.{
            .{ .field = "enable_plugins", .env = "ZIGCMS_ENABLE_PLUGINS" },
            .{ .field = "plugin_directory", .env = "ZIGCMS_PLUGIN_DIR" },
            .{ .field = "enable_cache", .env = "ZIGCMS_ENABLE_CACHE" },
            .{ .field = "cache_ttl_seconds", .env = "ZIGCMS_APP_CACHE_TTL" },
        });
    }

    pub fn validate(self: *Self, config_ptr: *const SystemConfig) !void {
        _ = self;

        if (config_ptr.api.port == 0) {
            std.debug.print("❌ 配置错误: API 端口不能为 0\n", .{});
            return error.InvalidValue;
        }
        if (config_ptr.api.host.len == 0) {
            std.debug.print("❌ 配置错误: API 主机地址不能为空\n", .{});
            return error.MissingRequiredField;
        }

        if (config_ptr.infra.db_host.len == 0) {
            std.debug.print("❌ 配置错误: 数据库主机地址不能为空\n", .{});
            return error.MissingRequiredField;
        }
        if (config_ptr.infra.db_port == 0) {
            std.debug.print("❌ 配置错误: 数据库端口不能为 0\n", .{});
            return error.InvalidValue;
        }
        if (config_ptr.infra.db_name.len == 0) {
            std.debug.print("❌ 配置错误: 数据库名称不能为空\n", .{});
            return error.MissingRequiredField;
        }

        if (config_ptr.infra.cache_enabled) {
            if (config_ptr.infra.cache_host.len == 0) {
                std.debug.print("❌ 配置错误: 缓存已启用但主机地址为空\n", .{});
                return error.MissingRequiredField;
            }
            if (config_ptr.infra.cache_port == 0) {
                std.debug.print("❌ 配置错误: 缓存已启用但端口为 0\n", .{});
                return error.InvalidValue;
            }
        }
    }
};
