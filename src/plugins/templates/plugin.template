//! 插件模板 - {{PLUGIN_NAME}}
//!
//! 本文件由插件生成器自动创建
//! 创建时间: {{CREATE_TIME}}
//!
//! 功能描述: {{DESCRIPTION}}

const std = @import("std");
const plugin = @import("../plugin_interface.zig");

// ============================================================================
// 插件元信息
// ============================================================================

/// 插件静态信息
pub const info = plugin.PluginInfo{
    .name = "{{PLUGIN_NAME}}",
    .version = "1.0.0",
    .description = "{{DESCRIPTION}}",
    .author = "{{AUTHOR}}",
    .license = "MIT",
    .api_version = plugin.PLUGIN_API_VERSION,
};

/// 插件能力声明
pub const capabilities = plugin.PluginCapabilities{
    .http_handlers = {{CAP_HTTP}},
    .middleware = {{CAP_MIDDLEWARE}},
    .scheduler = {{CAP_SCHEDULER}},
    .database_hooks = {{CAP_DB_HOOKS}},
    .event_listener = {{CAP_EVENTS}},
    .template_extension = {{CAP_TEMPLATE}},
    .custom_routes = {{CAP_ROUTES}},
    .websocket = {{CAP_WEBSOCKET}},
};

// ============================================================================
// 插件运行时数据
// ============================================================================

/// 插件私有数据结构
const PluginData = struct {
    enabled: bool = true,
    counter: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    start_time: i64 = 0,
    // TODO: 添加插件私有数据字段

    /// 原子递增计数器
    fn incrementCounter(self: *PluginData) u32 {
        return self.counter.fetchAdd(1, .monotonic) + 1;
    }

    /// 获取当前计数
    fn getCounter(self: *const PluginData) u32 {
        return self.counter.load(.monotonic);
    }
};

/// 全局插件实例
var g_data: PluginData = .{};
var g_initialized: bool = false;

// ============================================================================
// 标准插件接口
// ============================================================================

/// 获取插件信息
pub fn plugin_get_info() *const plugin.PluginInfo {
    return &info;
}

/// 获取插件能力位图
pub fn plugin_get_capabilities() u32 {
    return capabilities.toBitmap();
}

/// 初始化插件
pub fn plugin_init() ?*anyopaque {
    if (g_initialized) return @ptrCast(&g_data);

    g_data = .{};
    g_initialized = true;

    std.log.info("[{s}] 插件初始化完成 v{s}", .{ info.name, info.version });
    return @ptrCast(&g_data);
}

/// 清理插件资源
pub fn plugin_deinit(handle: ?*anyopaque) void {
    _ = handle;

    if (g_initialized) {
        const count = g_data.getCounter();
        std.log.info("[{s}] 插件已销毁，共处理 {d} 个请求", .{ info.name, count });
        g_initialized = false;
        g_data = .{};
    }
}

/// 启动插件
pub fn plugin_start(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_data.start_time = std.time.timestamp();
        g_data.enabled = true;
        std.log.info("[{s}] 插件已启动", .{info.name});
        // TODO: 添加启动逻辑
        return true;
    }
    return false;
}

/// 停止插件
pub fn plugin_stop(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_data.enabled = false;
        const uptime = std.time.timestamp() - g_data.start_time;
        std.log.info("[{s}] 插件已停止，运行时长: {d}秒", .{ info.name, uptime });
        // TODO: 添加停止逻辑
        return true;
    }
    return false;
}

// ============================================================================
// 插件业务功能
// ============================================================================

// TODO: 在此添加插件的业务功能函数

/// 处理请求示例
pub fn handle_request() u32 {
    if (!g_initialized or !g_data.enabled) return 0;
    return g_data.incrementCounter();
}

/// 获取插件状态
pub fn get_status(buffer: []u8) usize {
    if (!g_initialized) return 0;

    const status_fmt = "{{\"name\":\"{s}\",\"version\":\"{s}\",\"enabled\":{},\"counter\":{d},\"uptime\":{d}}}";
    const uptime = if (g_data.start_time > 0) std.time.timestamp() - g_data.start_time else 0;

    const result = std.fmt.bufPrint(
        buffer,
        status_fmt,
        .{ info.name, info.version, g_data.enabled, g_data.getCounter(), uptime },
    ) catch return 0;

    return result.len;
}

// ============================================================================
// 测试
// ============================================================================

test "插件信息验证" {
    try std.testing.expectEqualStrings("{{PLUGIN_NAME}}", info.name);
    try std.testing.expect(info.api_version == plugin.PLUGIN_API_VERSION);
}

test "插件生命周期" {
    g_initialized = false;
    g_data = .{};

    const handle = plugin_init();
    try std.testing.expect(handle != null);
    try std.testing.expect(g_initialized);

    try std.testing.expect(plugin_start(handle));
    _ = handle_request();
    try std.testing.expect(g_data.getCounter() == 1);

    try std.testing.expect(plugin_stop(handle));
    plugin_deinit(handle);
    try std.testing.expect(!g_initialized);
}
