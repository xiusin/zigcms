//! 插件系统入口模块
//!
//! 该模块组织插件相关的所有功能和服务

const std = @import("std");

// 插件核心接口
pub const PluginInterface = @import("plugin_interface.zig").PluginInterface;
pub const PluginHandle = @import("plugin_interface.zig").PluginHandle;
pub const PluginManager = @import("plugin_manager.zig").PluginManager;
pub const PluginSystemService = @import("plugin_system.zig").PluginSystemService;

// 缓存服务
pub const CacheService = @import("../cache/cache.zig").CacheService;

// 插件能力定义
pub const PluginCapabilities = packed struct(u32) {
    http_handlers: bool = false,
    database_drivers: bool = false,
    authentication: bool = false,
    middleware: bool = false,
    event_listeners: bool = false,
    scheduled_tasks: bool = false,
    custom_routes: bool = false,
    file_processors: bool = false,
    cache_providers: bool = false,
    storage_backends: bool = false,
    encryption: bool = false,
    logging: bool = false,
    _reserved: u20 = 0,
};

/// 插件错误类型
pub const PluginError = error{
    InitializationFailed,
    LoadFailed,
    UnloadFailed,
    SymbolNotFound,
    InvalidPlugin,
    NotSupported,
    AlreadyLoaded,
    NotRunning,
    PermissionDenied,
};

/// 插件信息结构
pub const PluginInfo = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    path: []const u8,
    loaded: bool = false,
    running: bool = false,
    capabilities: PluginCapabilities = .{},
};
