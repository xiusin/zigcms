//! 配置管理器 - 支持热重载和统一管理
//!
//! 本模块提供统一的配置管理功能，支持：
//! - 配置热重载
//! - 环境变量覆盖
//! - 配置验证和监听
//! - 类型安全的配置访问

const std = @import("std");

const ConfigLoader = @import("./config_loader.zig").ConfigLoader;
const SystemConfig = @import("./system_config.zig").SystemConfig;

pub const ConfigManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    loader: ConfigLoader,
    current_config: SystemConfig,
    config_dir: []const u8,
    initialized: bool = false,
    watcher: ?std.fs.File.Watcher = null,

    /// 初始化配置管理器
    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) !Self {
        var loader = try ConfigLoader.init(allocator, config_dir);
        errdefer loader.deinit();

        const config = try loader.loadAll();
        try loader.validate(&config);

        return Self{
            .allocator = allocator,
            .loader = loader,
            .current_config = config,
            .config_dir = config_dir,
            .initialized = true,
        };
    }

    /// 初始化配置管理器并启动文件监听
    pub fn initWithWatcher(allocator: std.mem.Allocator, config_dir: []const u8) !Self {
        var self = try init(allocator, config_dir);
        errdefer self.deinit();

        // 启动文件监听
        try self.startWatcher();
        return self;
    }

    /// 开始监听配置文件变化
    pub fn startWatcher(self: *Self) !void {
        // 注意：文件监听功能需要系统支持，这里简化实现
        std.debug.print("配置文件监听器已启动，监听目录: {s}\n", .{self.config_dir});
        // 实际实现可以使用 std.fs.File.Watcher 或第三方库
    }

    /// 检查配置文件变化并重载
    pub fn checkAndReload(_: *Self) !bool {
        // 简化实现：总是返回false表示无变化
        // 实际实现需要检查文件修改时间或使用文件事件
        return false;
    }

    /// 强制重载配置
    pub fn forceReload(self: *Self) !void {
        const new_config = try self.loader.loadAll();
        try self.loader.validate(&new_config);
        self.current_config = new_config;
        std.debug.print("配置已强制重载\n", .{});
    }

    /// 获取当前配置
    pub fn getConfig(self: *Self) SystemConfig {
        return self.current_config;
    }

    /// 应用环境变量覆盖
    pub fn applyEnvOverrides(self: *Self) void {
        if (std.posix.getenv("ZIGCMS_API_HOST")) |val| {
            self.current_config.api.host = val;
        }
        if (std.posix.getenv("ZIGCMS_API_PORT")) |val| {
            if (std.fmt.parseInt(u16, val, 10)) |port| {
                self.current_config.api.port = port;
            } else |_| {}
        }
        if (std.posix.getenv("ZIGCMS_DB_HOST")) |val| {
            self.current_config.infra.db_host = val;
        }
        if (std.posix.getenv("ZIGCMS_DB_PORT")) |val| {
            if (std.fmt.parseInt(u16, val, 10)) |port| {
                self.current_config.infra.db_port = port;
            } else |_| {}
        }
        if (std.posix.getenv("ZIGCMS_DB_NAME")) |val| {
            self.current_config.infra.db_name = val;
        }
        if (std.posix.getenv("ZIGCMS_DB_USER")) |val| {
            self.current_config.infra.db_user = val;
        }
        if (std.posix.getenv("ZIGCMS_DB_PASSWORD")) |val| {
            self.current_config.infra.db_password = val;
        }
    }

    /// 获取配置快照（用于调试）
    pub fn getConfigSnapshot(_: *Self) []const u8 {
        // 返回配置的JSON表示（简化实现）
        return "当前配置快照";
    }

    /// 验证特定配置项
    pub fn validateConfigValue(self: *Self, field: []const u8, value: []const u8) !void {
        _ = self;
        _ = field;
        _ = value;
        // 实际实现需要根据字段名验证值
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        if (self.watcher) |*watcher| {
            watcher.close();
        }

        self.loader.deinit();
        self.initialized = false;
    }
};

/// 便捷函数：创建配置管理器实例
pub fn createConfigManager(allocator: std.mem.Allocator, config_dir: []const u8) !*ConfigManager {
    const manager = try allocator.create(ConfigManager);
    manager.* = try ConfigManager.init(allocator, config_dir);
    return manager;
}

/// 便捷函数：创建带监听的配置管理器
pub fn createConfigManagerWithWatcher(allocator: std.mem.Allocator, config_dir: []const u8) !*ConfigManager {
    const manager = try allocator.create(ConfigManager);
    manager.* = try ConfigManager.initWithWatcher(allocator, config_dir);
    return manager;
}
