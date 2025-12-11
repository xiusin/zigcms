//! 插件系统集成测试
//!
//! 测试内容：
//! - 插件管理器生命周期
//! - 插件加载与卸载
//! - 能力检测
//! - 异常处理
//! - 内存安全

const std = @import("std");
const plugin_manager = @import("plugin_manager.zig");
const interface = @import("plugin_interface.zig");

const PluginManager = plugin_manager.PluginManager;
const PluginCapabilities = interface.PluginCapabilities;
const PluginInfo = interface.PluginInfo;
const PluginError = interface.PluginError;

// ============================================================================
// 插件管理器测试
// ============================================================================

test "PluginManager 初始化与清理" {
    const allocator = std.testing.allocator;

    var manager = try PluginManager.init(allocator, "plugins");
    defer manager.deinit();

    try std.testing.expectEqualStrings("plugins", manager.plugin_dir);
}

test "加载不存在的插件返回正确错误" {
    const allocator = std.testing.allocator;

    var manager = try PluginManager.init(allocator, "plugins");
    defer manager.deinit();

    const result = manager.loadPlugin("this_plugin_does_not_exist_12345");
    try std.testing.expectError(PluginError.PluginNotFound, result);
}

test "获取未加载的插件返回 null" {
    const allocator = std.testing.allocator;

    var manager = try PluginManager.init(allocator, "plugins");
    defer manager.deinit();

    const plugin = manager.getPlugin("nonexistent");
    try std.testing.expect(plugin == null);
}

// ============================================================================
// 插件能力测试
// ============================================================================

test "PluginCapabilities 默认值全为 false" {
    const caps = PluginCapabilities{};

    try std.testing.expect(!caps.http_handlers);
    try std.testing.expect(!caps.middleware);
    try std.testing.expect(!caps.scheduler);
    try std.testing.expect(!caps.database_hooks);
    try std.testing.expect(!caps.event_listener);
    try std.testing.expect(!caps.template_extension);
    try std.testing.expect(!caps.custom_routes);
    try std.testing.expect(!caps.websocket);
}

test "PluginCapabilities 位图往返转换" {
    const original = PluginCapabilities{
        .http_handlers = true,
        .middleware = true,
        .scheduler = false,
        .database_hooks = true,
        .event_listener = false,
        .template_extension = true,
        .custom_routes = true,
        .websocket = false,
    };

    const bitmap = original.toBitmap();
    const restored = PluginCapabilities.fromBitmap(bitmap);

    try std.testing.expect(restored.http_handlers == original.http_handlers);
    try std.testing.expect(restored.middleware == original.middleware);
    try std.testing.expect(restored.scheduler == original.scheduler);
    try std.testing.expect(restored.database_hooks == original.database_hooks);
    try std.testing.expect(restored.event_listener == original.event_listener);
    try std.testing.expect(restored.template_extension == original.template_extension);
    try std.testing.expect(restored.custom_routes == original.custom_routes);
    try std.testing.expect(restored.websocket == original.websocket);
}

test "空能力位图为 0" {
    const caps = PluginCapabilities{};
    try std.testing.expect(caps.toBitmap() == 0);
}

test "单一能力位图正确" {
    const http_only = PluginCapabilities{ .http_handlers = true };
    try std.testing.expect(http_only.toBitmap() == 1);

    const middleware_only = PluginCapabilities{ .middleware = true };
    try std.testing.expect(middleware_only.toBitmap() == 2);

    const scheduler_only = PluginCapabilities{ .scheduler = true };
    try std.testing.expect(scheduler_only.toBitmap() == 4);
}

// ============================================================================
// 插件信息测试
// ============================================================================

test "PluginInfo 默认值" {
    const info = PluginInfo.default();

    try std.testing.expectEqualStrings("Unknown", info.name);
    try std.testing.expectEqualStrings("0.0.0", info.version);
    try std.testing.expectEqualStrings("MIT", info.license);
    try std.testing.expect(info.api_version == 1);
}

test "PluginInfo 自定义值" {
    const info = PluginInfo{
        .name = "TestPlugin",
        .version = "1.2.3",
        .description = "测试插件",
        .author = "Test Author",
        .license = "Apache-2.0",
        .api_version = 2,
    };

    try std.testing.expectEqualStrings("TestPlugin", info.name);
    try std.testing.expectEqualStrings("1.2.3", info.version);
    try std.testing.expectEqualStrings("测试插件", info.description);
    try std.testing.expectEqualStrings("Test Author", info.author);
    try std.testing.expectEqualStrings("Apache-2.0", info.license);
    try std.testing.expect(info.api_version == 2);
}

// ============================================================================
// VTable 验证测试
// ============================================================================

test "空 VTable 无效" {
    const vtable = interface.PluginVTable{};
    try std.testing.expect(!vtable.isValid());
}

test "部分 VTable 无效" {
    // 只设置部分必需函数，验证 isValid 返回 false
    const vtable = interface.PluginVTable{
        .get_info = null,
        .get_capabilities = null,
        // 缺少 init 和 deinit
    };
    try std.testing.expect(!vtable.isValid());
}

// ============================================================================
// 插件状态测试
// ============================================================================

test "PluginState 枚举值" {
    try std.testing.expect(@intFromEnum(interface.PluginState.unloaded) == 0);
    try std.testing.expect(@intFromEnum(interface.PluginState.loaded) == 1);
    try std.testing.expect(@intFromEnum(interface.PluginState.initialized) == 2);
    try std.testing.expect(@intFromEnum(interface.PluginState.running) == 3);
    try std.testing.expect(@intFromEnum(interface.PluginState.stopped) == 4);
    try std.testing.expect(@intFromEnum(interface.PluginState.error_state) == 5);
}

// ============================================================================
// 符号名称测试
// ============================================================================

test "符号名称常量正确" {
    try std.testing.expectEqualStrings("plugin_get_info", interface.SymbolNames.get_info);
    try std.testing.expectEqualStrings("plugin_get_capabilities", interface.SymbolNames.get_capabilities);
    try std.testing.expectEqualStrings("plugin_init", interface.SymbolNames.init);
    try std.testing.expectEqualStrings("plugin_deinit", interface.SymbolNames.deinit);
    try std.testing.expectEqualStrings("plugin_start", interface.SymbolNames.start);
    try std.testing.expectEqualStrings("plugin_stop", interface.SymbolNames.stop);
}

// ============================================================================
// API 版本测试
// ============================================================================

test "API 版本常量" {
    try std.testing.expect(interface.PLUGIN_API_VERSION == 1);
}

// ============================================================================
// 内存安全测试
// ============================================================================

test "PluginManager 多次初始化和清理" {
    const allocator = std.testing.allocator;

    // 多次创建和销毁，检测内存泄漏
    for (0..10) |_| {
        var manager = try PluginManager.init(allocator, "test_plugins");
        manager.deinit();
    }
}

test "插件目录路径复制独立" {
    const allocator = std.testing.allocator;

    var dir_buf: [64]u8 = undefined;
    const dir_slice = "plugins".*;
    @memcpy(dir_buf[0..dir_slice.len], &dir_slice);

    var manager = try PluginManager.init(allocator, dir_buf[0..dir_slice.len]);
    defer manager.deinit();

    // 修改原始缓冲区不应影响管理器
    dir_buf[0] = 'X';
    try std.testing.expectEqualStrings("plugins", manager.plugin_dir);
}
