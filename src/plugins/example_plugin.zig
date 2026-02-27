//! 示例插件 - 演示插件系统的标准用法
//!
//! 本插件展示如何使用新的插件接口框架创建可插拔模块
//! 包含完整的生命周期管理和能力声明

const std = @import("std");
const plugin = @import("plugin_interface.zig");

// ============================================================================
// 插件元信息定义
// ============================================================================

/// 插件静态信息
pub const info = plugin.PluginInfo{
    .name = "ExamplePlugin",
    .version = "2.0.0",
    .description = "示例插件 - 演示插件系统的标准接口",
    .author = "ZigCMS Team",
    .license = "MIT",
    .api_version = plugin.PLUGIN_API_VERSION,
};

/// 插件能力声明
pub const capabilities = plugin.PluginCapabilities{
    .http_handlers = true,
    .custom_routes = true,
    .event_listener = true,
};

// ============================================================================
// 插件运行时数据
// ============================================================================

/// 插件私有数据结构
const PluginData = struct {
    enabled: bool = true,
    counter: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    start_time: i64 = 0,

    /// 原子递增计数器
    fn incrementCounter(self: *PluginData) u32 {
        return self.counter.fetchAdd(1, .monotonic) + 1;
    }

    /// 获取当前计数
    fn getCounter(self: *const PluginData) u32 {
        return self.counter.load(.monotonic);
    }
};

/// 全局插件实例（使用静态存储避免动态分配）
var g_plugin_data: PluginData = .{};
var g_initialized: bool = false;

// ============================================================================
// 标准插件接口导出函数
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
    if (g_initialized) return @ptrCast(&g_plugin_data);

    g_plugin_data = .{};
    g_initialized = true;

    std.log.info("[{s}] 插件初始化完成 v{s}", .{ info.name, info.version });
    return @ptrCast(&g_plugin_data);
}

/// 清理插件资源
pub fn plugin_deinit(handle: ?*anyopaque) void {
    _ = handle;

    if (g_initialized) {
        const count = g_plugin_data.getCounter();
        std.log.info("[{s}] 插件已销毁，共处理 {d} 个请求", .{ info.name, count });
        g_initialized = false;
        g_plugin_data = .{};
    }
}

/// 启动插件
pub fn plugin_start(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_plugin_data.start_time = std.time.timestamp();
        g_plugin_data.enabled = true;
        std.log.info("[{s}] 插件已启动", .{info.name});
        return true;
    }
    return false;
}

/// 停止插件
pub fn plugin_stop(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_plugin_data.enabled = false;
        const uptime = std.time.timestamp() - g_plugin_data.start_time;
        std.log.info("[{s}] 插件已停止，运行时长: {d}秒", .{ info.name, uptime });
        return true;
    }
    return false;
}

// ============================================================================
// 插件业务功能导出
// ============================================================================

/// 处理请求（递增计数器）
pub fn handle_request() u32 {
    if (!g_initialized or !g_plugin_data.enabled) return 0;
    return g_plugin_data.incrementCounter();
}

/// 获取当前计数
pub fn get_counter() u32 {
    if (!g_initialized) return 0;
    return g_plugin_data.getCounter();
}

/// 获取插件状态信息
pub fn get_status(buffer: []u8) usize {
    if (!g_initialized) return 0;

    const status_fmt = "{{\"name\":\"{s}\",\"version\":\"{s}\",\"enabled\":{},\"counter\":{d},\"uptime\":{d}}}";
    const uptime = if (g_plugin_data.start_time > 0) std.time.timestamp() - g_plugin_data.start_time else 0;

    const result = std.fmt.bufPrint(
        buffer,
        status_fmt,
        .{ info.name, info.version, g_plugin_data.enabled, g_plugin_data.getCounter(), uptime },
    ) catch return 0;

    return result.len;
}

// ============================================================================
// 测试
// ============================================================================

test "插件信息验证" {
    try std.testing.expectEqualStrings("ExamplePlugin", info.name);
    try std.testing.expectEqualStrings("2.0.0", info.version);
    try std.testing.expect(info.api_version == plugin.PLUGIN_API_VERSION);
}

test "插件能力位图" {
    const bitmap = capabilities.toBitmap();
    try std.testing.expect(bitmap != 0);

    const restored = plugin.PluginCapabilities.fromBitmap(bitmap);
    try std.testing.expect(restored.http_handlers);
    try std.testing.expect(restored.custom_routes);
    try std.testing.expect(restored.event_listener);
    try std.testing.expect(!restored.middleware);
}

test "插件生命周期" {
    // 确保测试开始时状态干净
    g_initialized = false;
    g_plugin_data = .{};

    // 测试信息获取
    const plugin_info = plugin_get_info();
    try std.testing.expectEqualStrings("ExamplePlugin", plugin_info.name);

    // 测试能力获取
    const caps = plugin_get_capabilities();
    try std.testing.expect(caps != 0);

    // 测试初始化
    const handle = plugin_init();
    try std.testing.expect(handle != null);
    try std.testing.expect(g_initialized);

    // 测试启动
    try std.testing.expect(plugin_start(handle));

    // 测试业务功能
    const count1 = handle_request();
    try std.testing.expect(count1 == 1);
    const count2 = handle_request();
    try std.testing.expect(count2 == 2);
    try std.testing.expect(get_counter() == 2);

    // 测试停止
    try std.testing.expect(plugin_stop(handle));

    // 测试清理
    plugin_deinit(handle);
    try std.testing.expect(!g_initialized);
}
