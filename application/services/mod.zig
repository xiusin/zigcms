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
// const PluginSystemService = @import("../services/plugins/mod.zig").PluginSystemService;
const PluginSystemService = struct {
    /// 初始化插件系统
    pub fn init(_: std.mem.Allocator) PluginSystemService {
        return .{};
    }

    /// 关闭插件系统
    pub fn shutdown(self: *PluginSystemService) !void {
        _ = self;
    }

    /// 清理插件系统
    pub fn deinit(self: *PluginSystemService) void {
        _ = self;
    }
};
const root = @import("../../root.zig");

// 指标服务
const MetricsRegistry = @import("../../shared/utils/metrics.zig").Registry;
// JSON 编解码服务
const JsonCodec = @import("../services/json/json.zig").Codec;
// 事件总线服务
const EventEmitter = @import("../services/events/events.zig").EventEmitter;
// 日志服务
const Logger = @import("../services/logger/logger.zig").Logger;

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

    // 指标服务（ServiceManager 拥有所有权）
    metrics: ?*MetricsRegistry = null,

    // JSON 编解码服务（ServiceManager 拥有所有权）
    json_codec: ?*JsonCodec = null,

    // 事件总线服务（ServiceManager 拥有所有权）
    event_emitter: ?*EventEmitter = null,

    // 日志服务（ServiceManager 拥有所有权）
    logger: ?*Logger = null,

    // 标记是否已初始化，用于防止重复清理
    initialized: bool = false,

    /// 初始化服务管理器
    ///
    /// 初始化顺序：cache → plugin_system → metrics → json_codec → event_emitter → logger
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

        // 步骤2：初始化插件系统
        var plugin_system = PluginSystemService.init(allocator);
        errdefer plugin_system.deinit();

        // 步骤3：初始化指标服务
        var metrics = try allocator.create(MetricsRegistry);
        metrics.* = MetricsRegistry.init(allocator);
        errdefer {
            metrics.deinit();
            allocator.destroy(metrics);
        }

        // 步骤4：初始化 JSON 编解码服务
        var json_codec = try allocator.create(JsonCodec);
        json_codec.* = try JsonCodec.init(allocator, .{});
        errdefer {
            json_codec.deinit();
            allocator.destroy(json_codec);
        }

        // 步骤5：初始化事件总线服务
        var event_emitter = try allocator.create(EventEmitter);
        event_emitter.* = EventEmitter.init(allocator);
        errdefer {
            event_emitter.deinit();
            allocator.destroy(event_emitter);
        }

        // 步骤6：初始化日志服务
        var logger = try allocator.create(Logger);
        logger.* = Logger.init(allocator, .{});
        errdefer {
            logger.deinit();
            allocator.destroy(logger);
        }

        return .{
            .allocator = allocator,
            .config = config,
            .db = db,
            .cache = cache,
            .plugin_system = plugin_system,
            .metrics = metrics,
            .json_codec = json_codec,
            .event_emitter = event_emitter,
            .logger = logger,
            .initialized = true,
        };
    }

    /// 清理服务管理器
    ///
    /// 清理顺序（与初始化相反）：logger → event_emitter → json_codec → metrics → plugin_system → cache
    /// 注意：db 由调用者管理，不在此处清理
    pub fn deinit(self: *ServiceManager) void {
        if (!self.initialized) return;

        // 步骤1：清理日志服务
        if (self.logger) |logger| {
            logger.deinit();
            self.allocator.destroy(logger);
            self.logger = null;
        }

        // 步骤2：清理事件总线服务
        if (self.event_emitter) |emitter| {
            emitter.deinit();
            self.allocator.destroy(emitter);
            self.event_emitter = null;
        }

        // 步骤3：清理 JSON 编解码服务
        if (self.json_codec) |codec| {
            codec.deinit();
            self.allocator.destroy(codec);
            self.json_codec = null;
        }

        // 步骤4：清理指标服务
        if (self.metrics) |metrics| {
            metrics.deinit();
            self.allocator.destroy(metrics);
            self.metrics = null;
        }

        // 步骤5：停止和清理插件系统
        self.plugin_system.shutdown() catch |err| {
            std.log.err("插件系统关闭失败: {}", .{err});
        };
        self.plugin_system.deinit();

        // 步骤6：清理缓存服务
        self.cache.deinit();

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
        // 字典缓存预加载逻辑可根据需要实现
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

    /// 获取指标服务
    ///
    /// 返回：指标注册表的可变引用
    pub fn getMetricsService(self: *ServiceManager) *MetricsRegistry {
        return self.metrics.?;
    }

    /// 获取 JSON 编解码服务
    ///
    /// 返回：JSON 编解码服务的可变引用
    pub fn getJsonCodecService(self: *ServiceManager) *JsonCodec {
        return self.json_codec.?;
    }

    /// 获取事件总线服务
    ///
    /// 返回：事件总线服务的可变引用
    pub fn getEventEmitterService(self: *ServiceManager) *EventEmitter {
        return self.event_emitter.?;
    }

    /// 获取日志服务
    ///
    /// 返回：日志服务的可变引用
    pub fn getLoggerService(self: *ServiceManager) *Logger {
        return self.logger.?;
    }

    /// 获取分配器
    ///
    /// 返回：ServiceManager 持有的内存分配器
    pub fn getAllocator(self: *const ServiceManager) std.mem.Allocator {
        return self.allocator;
    }
};

// New exports
pub const template = @import("template/mod.zig");
pub const cookie = @import("cookie/mod.zig");
pub const session = @import("session/mod.zig");
