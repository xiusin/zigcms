//! 插件接口定义
//! 定义插件必须实现的标准接口和数据结构

const std = @import("std");

/// 插件能力位图 - 声明插件支持的功能
pub const PluginCapabilities = packed struct(u32) {
    /// 支持 HTTP 请求处理
    http_handlers: bool = false,
    /// 支持中间件
    middleware: bool = false,
    /// 支持定时任务
    scheduler: bool = false,
    /// 支持数据库钩子
    database_hooks: bool = false,
    /// 支持事件监听
    event_listener: bool = false,
    /// 支持模板扩展
    template_extension: bool = false,
    /// 支持自定义路由
    custom_routes: bool = false,
    /// 支持 WebSocket
    websocket: bool = false,
    _padding: u24 = 0,

    /// 转换为 u32 位图
    pub fn toBitmap(self: PluginCapabilities) u32 {
        return @bitCast(self);
    }

    /// 从 u32 位图转换
    pub fn fromBitmap(bitmap: u32) PluginCapabilities {
        return @bitCast(bitmap);
    }
};

/// 插件元信息
pub const PluginInfo = struct {
    name: [:0]const u8,
    version: [:0]const u8,
    description: [:0]const u8,
    author: [:0]const u8,
    license: [:0]const u8,
    api_version: u32 = 1,

    /// 创建默认信息
    pub fn default() PluginInfo {
        return .{
            .name = "Unknown",
            .version = "0.0.0",
            .description = "",
            .author = "",
            .license = "MIT",
        };
    }
};

/// 插件状态
pub const PluginState = enum(u8) {
    /// 未加载
    unloaded = 0,
    /// 已加载但未初始化
    loaded = 1,
    /// 已初始化
    initialized = 2,
    /// 运行中
    running = 3,
    /// 已停止
    stopped = 4,
    /// 错误状态
    error_state = 5,
};

/// 插件错误类型
pub const PluginError = error{
    /// 插件文件不存在
    PluginNotFound,
    /// 加载动态库失败
    LoadFailed,
    /// 缺少必要符号
    MissingSymbol,
    /// 初始化失败
    InitFailed,
    /// 版本不兼容
    IncompatibleVersion,
    /// 重复加载
    AlreadyLoaded,
    /// 插件未加载
    NotLoaded,
    /// 无效句柄
    InvalidHandle,
    /// 启动失败
    StartFailed,
    /// 停止失败
    StopFailed,
    /// 内存分配失败
    OutOfMemory,
};

/// 插件生命周期回调函数类型
/// 注意：使用 Zig 调用约定，插件使用静态存储避免跨边界内存分配
pub const InitFn = *const fn () ?*anyopaque;
pub const DeinitFn = *const fn (?*anyopaque) void;
pub const StartFn = *const fn (?*anyopaque) bool;
pub const StopFn = *const fn (?*anyopaque) bool;
pub const GetInfoFn = *const fn () *const PluginInfo;
pub const GetCapsFn = *const fn () u32;

/// 插件虚函数表 - 所有插件必须提供的标准接口
pub const PluginVTable = struct {
    /// 获取插件信息
    get_info: ?GetInfoFn = null,
    /// 获取插件能力
    get_capabilities: ?GetCapsFn = null,
    /// 初始化插件
    init: ?InitFn = null,
    /// 清理插件
    deinit: ?DeinitFn = null,
    /// 启动插件
    start: ?StartFn = null,
    /// 停止插件
    stop: ?StopFn = null,

    /// 检查 VTable 是否有效
    pub fn isValid(self: *const PluginVTable) bool {
        return self.get_info != null and
            self.get_capabilities != null and
            self.init != null and
            self.deinit != null;
    }
};

/// 插件上下文 - 传递给插件的运行时信息
pub const PluginContext = struct {
    arena: *std.heap.ArenaAllocator,
    config: ?*anyopaque = null,
    logger: ?*anyopaque = null,
    event_bus: ?*anyopaque = null,
    resource_tracker: ?*anyopaque = null,

    pub fn allocator(self: *const PluginContext) std.mem.Allocator {
        return self.arena.allocator();
    }
};

/// 当前插件 API 版本
pub const PLUGIN_API_VERSION: u32 = 1;

/// 插件符号名称常量
pub const SymbolNames = struct {
    pub const get_info = "plugin_get_info";
    pub const get_capabilities = "plugin_get_capabilities";
    pub const init = "plugin_init";
    pub const deinit = "plugin_deinit";
    pub const start = "plugin_start";
    pub const stop = "plugin_stop";
};

test "PluginCapabilities 位图转换" {
    const caps = PluginCapabilities{
        .http_handlers = true,
        .custom_routes = true,
    };

    const bitmap = caps.toBitmap();
    const restored = PluginCapabilities.fromBitmap(bitmap);

    try std.testing.expect(restored.http_handlers);
    try std.testing.expect(restored.custom_routes);
    try std.testing.expect(!restored.middleware);
}
