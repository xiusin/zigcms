//! 应用层入口文件
//!
//! 职责：
//! - 定义业务用例和应用服务
//! - 协调领域对象执行业务逻辑
//! - 处理事务管理
//! - 提供应用级别的接口

const std = @import("std");
const logger = @import("services/logger/logger.zig");

// ============================================================================
// 导出应用层模块
// ============================================================================

/// 业务用例模块（业务流程编排）
pub const usecases = @import("usecases/mod.zig");

/// 应用服务模块（通用功能服务）
pub const services = struct {
    pub const manager = @import("services/services.zig").ServiceManager;
    pub const orm = @import("services/orm/orm.zig");
    pub const cache = @import("services/cache/cache.zig");
    pub const logger = @import("services/logger/logger.zig");
    pub const validator = @import("services/validator/validator.zig");
};

// ============================================================================
// 应用层配置
// ============================================================================

/// 应用层配置
pub const AppConfig = struct {
    // 业务逻辑相关的配置参数

    /// 是否启用缓存
    enable_cache: bool = true,
    /// 缓存默认 TTL（秒）
    cache_ttl_seconds: u64 = 3600,
    /// 最大并发任务数
    max_concurrent_tasks: u32 = 100,

    /// 是否启用插件系统
    enable_plugins: bool = true,
    /// 插件目录
    plugin_directory: []const u8 = "plugins",

    /// 是否启用事件系统
    enable_events: bool = true,
    /// 事件队列大小
    event_queue_size: u32 = 1000,
};

// ============================================================================
// 初始化和清理
// ============================================================================

/// 应用层初始化函数
pub fn init(allocator: std.mem.Allocator, config: AppConfig) !void {
    _ = allocator;
    _ = config;

    std.debug.print("✅ 应用层初始化完成\n", .{});

    // 初始化用例模块
    _ = usecases;

    // 初始化服务
    _ = services;
}

/// 应用层清理函数
pub fn deinit() void {
    std.debug.print("👋 应用层已清理\n", .{});
}
