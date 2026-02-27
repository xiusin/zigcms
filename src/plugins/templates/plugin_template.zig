const std = @import("std");
const plugin = @import("../plugin_interface.zig");
const manifest_mod = @import("../plugin_manifest.zig");

pub const info = plugin.PluginInfo{
    .name = "MyPlugin",
    .version = "1.0.0",
    .description = "Example plugin demonstrating the new API",
    .author = "Your Name",
    .license = "MIT",
    .api_version = plugin.PLUGIN_API_VERSION,
};

pub const capabilities = plugin.PluginCapabilities{
    .http_handlers = true,
    .custom_routes = true,
    .event_listener = true,
};

pub const manifest = manifest_mod.Manifest{
    .id = "com.example.myplugin",
    .name = "MyPlugin",
    .version = .{ .major = 1, .minor = 0, .patch = 0 },
    .author = "Your Name",
    .license = "MIT",
    .api_version = plugin.PLUGIN_API_VERSION,
    .capabilities = capabilities,
    .required_permissions = &[_]manifest_mod.Permission{
        .filesystem_read,
        .http_register_routes,
    },
};

const PluginData = struct {
    enabled: bool = true,
    counter: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    start_time: i64 = 0,
    context: ?*plugin.PluginContext = null,

    fn incrementCounter(self: *PluginData) u32 {
        return self.counter.fetchAdd(1, .monotonic) + 1;
    }

    fn getCounter(self: *const PluginData) u32 {
        return self.counter.load(.monotonic);
    }
};

var g_plugin_data: PluginData = .{};
var g_initialized: bool = false;

pub fn plugin_get_info() *const plugin.PluginInfo {
    return &info;
}

pub fn plugin_get_capabilities() u32 {
    return capabilities.toBitmap();
}

pub fn plugin_init() ?*anyopaque {
    if (g_initialized) return @ptrCast(&g_plugin_data);

    g_plugin_data = .{};
    g_initialized = true;

    std.log.info("[{s}] Plugin initialized v{s}", .{ info.name, info.version });
    return @ptrCast(&g_plugin_data);
}

pub fn plugin_deinit(handle: ?*anyopaque) void {
    _ = handle;

    if (g_initialized) {
        const count = g_plugin_data.getCounter();
        std.log.info("[{s}] Plugin destroyed, processed {d} requests", .{ info.name, count });
        g_initialized = false;
        g_plugin_data = .{};
    }
}

pub fn plugin_start(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_plugin_data.start_time = std.time.timestamp();
        g_plugin_data.enabled = true;
        std.log.info("[{s}] Plugin started", .{info.name});
        return true;
    }
    return false;
}

pub fn plugin_stop(handle: ?*anyopaque) bool {
    _ = handle;

    if (g_initialized) {
        g_plugin_data.enabled = false;
        const uptime = std.time.timestamp() - g_plugin_data.start_time;
        std.log.info("[{s}] Plugin stopped, uptime: {d}s", .{ info.name, uptime });
        return true;
    }
    return false;
}

pub fn handle_request() u32 {
    if (!g_initialized or !g_plugin_data.enabled) return 0;
    return g_plugin_data.incrementCounter();
}

pub fn get_counter() u32 {
    if (!g_initialized) return 0;
    return g_plugin_data.getCounter();
}
