//! 服务管理器
//!
//! 这个模块管理应用程序中的各种服务实例
//! 包括数据库服务、缓存服务、字典服务和插件系统
//!
//! 内存所有权说明：
//! - ServiceManager 拥有 cache, dict_service, plugin_system 的所有权
//! - db 由调用者管理，ServiceManager 只持有引用
//! - 初始化顺序：cache → dict_service → plugin_system
//! - 清理顺序（逆序）：plugin_system → dict_service → cache

const std = @import("std");
const sql = @import("../services/sql/orm.zig");
const CacheService = @import("../services/cache/cache.zig").CacheService;
const PluginSystemService = @import("../services/plugins/mod.zig").PluginSystemService;
const root = @import("../../root.zig");

pub const ServiceManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // 系统配置
    config: root.SystemConfig,

    // 数据库连接（由调用者管理，ServiceManager 只持有引用）
    db: *sql.Database,

    // 缓存服务（ServiceManager 拥有所有权）
    cache: CacheService,

    // 插件系统服务（ServiceManager 拥有所有权）
    plugin_system: PluginSystemService,

    // 标记是否已初始化，用于防止重复清理
    initialized: bool = false,

    /// 初始化服务管理器
    ///
    /// 初始化顺序：cache → dict_service → plugin_system
    /// 如果任何步骤失败，已初始化的服务会通过 errdefer 自动清理
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - db: 数据库连接（由调用者管理生命周期）
    /// - config: 系统配置
    ///
    /// 返回：初始化的 ServiceManager 实例
    /// 错误：如果任何服务初始化失败
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database, config: root.SystemConfig) !ServiceManager {
        // 步骤1：初始化缓存服务
        var cache = CacheService.init(allocator);
        errdefer cache.deinit();

        // 步骤3：初始化插件系统
        var plugin_system = PluginSystemService.init(allocator);
        errdefer plugin_system.deinit();

        return .{
            .allocator = allocator,
            .config = config,
            .db = db,
            .cache = cache,
            .plugin_system = plugin_system,
            .initialized = true,
        };
    }

    /// 清理服务管理器
    ///
    /// 清理顺序（与初始化相反）：plugin_system → dict_service → cache
    /// 注意：db 由调用者管理，不在此处清理
    pub fn deinit(self: *ServiceManager) void {
        if (!self.initialized) return;

        // 步骤1：停止和清理插件系统（最后初始化，最先清理）
        self.plugin_system.shutdown() catch |err| {
            std.log.err("插件系统关闭失败: {}", .{err});
        };
        self.plugin_system.deinit();

        self.initialized = false;
        // 注意：db 由调用者管理，不在此处清理
    }

    /// 获取系统配置
    ///
    /// 返回：系统配置的只读引用
    pub fn getConfig(self: *const ServiceManager) *const root.SystemConfig {
        return &self.config;
    }

    /// 获取缓存服务
    ///
    /// 返回：缓存服务的可变引用
    pub fn getCacheService(self: *ServiceManager) *CacheService {
        return &self.cache;
    }

    /// 获取插件系统服务
    ///
    /// 返回：插件系统服务的可变引用
    pub fn getPluginSystemService(self: *ServiceManager) *PluginSystemService {
        return &self.plugin_system;
    }

    /// 初始化插件系统
    ///
    /// 启动插件系统，加载并初始化所有插件
    pub fn initPluginSystem(self: *ServiceManager) !void {
        try self.plugin_system.startup();
    }

    /// 清理所有服务的缓存
    ///
    /// 清空缓存服务中的所有缓存项
    pub fn clearAllCaches(self: *ServiceManager) !void {
        try self.cache.flush();
    }

    /// 刷新所有缓存
    ///
    /// 清空所有缓存并重新预加载常用数据
    pub fn refreshAllCaches(self: *ServiceManager) !void {
        // 清理所有缓存
        try self.clearAllCaches();

        // 预加载常用数据到缓存
        try self.dict_service.refreshDictCache();
    }

    /// 获取缓存统计
    ///
    /// 返回：缓存统计信息，包括缓存项数量和过期项数量
    pub fn getCacheStats(self: *ServiceManager) CacheService.CacheStats {
        return self.cache.stats();
    }

    /// 清理过期缓存项
    ///
    /// 移除所有已过期的缓存项以释放内存
    pub fn cleanupExpiredCache(self: *ServiceManager) !void {
        try self.cache.cleanupExpired();
    }

    /// 获取插件统计信息
    ///
    /// 返回：插件统计信息，包括总数、运行中和已加载的插件数量
    pub fn getPluginStats(self: *ServiceManager) !struct {
        total_plugins: usize,
        running_plugins: usize,
        loaded_plugins: usize,
    } {
        return try self.plugin_system.getStatistics();
    }
};

// New exports
pub const template = @import("template/mod.zig");
pub const cookie = @import("cookie/mod.zig");
pub const session = @import("session/mod.zig");
