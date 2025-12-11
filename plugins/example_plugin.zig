//! 示例插件 - 演示插件系统的基本用法
//!
//! 这是一个简单的插件示例，展示了如何创建可插拔模块

const std = @import("std");
const zap = @import("zap");

// 插件信息
const PLUGIN_NAME = "ExamplePlugin";
const PLUGIN_VERSION = "1.0.0";
const PLUGIN_DESCRIPTION = "示例插件，演示插件系统功能";
const PLUGIN_AUTHOR = "ZigCMS Team";
const PLUGIN_LICENSE = "MIT";

// 插件数据结构
const PluginData = struct {
    enabled: bool = true,
    counter: u32 = 0,
};

// 插件实例
var plugin_data: ?PluginData = null;

// 插件能力声明
const capabilities = .{
    .http_handlers = true,
    .custom_routes = true,
};

// 插件接口函数
export fn plugin_get_name() [*:0]const u8 {
    return PLUGIN_NAME;
}

export fn plugin_get_info() [5][*:0]const u8 {
    return .{
        PLUGIN_NAME,
        PLUGIN_VERSION,
        PLUGIN_DESCRIPTION,
        PLUGIN_AUTHOR,
        PLUGIN_LICENSE,
    };
}

export fn plugin_get_capabilities() u32 {
    // 返回能力位图
    var caps: u32 = 0;
    if (capabilities.http_handlers) caps |= (1 << 0);
    if (capabilities.custom_routes) caps |= (1 << 6);
    return caps;
}

export fn plugin_init(allocator: std.mem.Allocator) !*anyopaque {
    _ = allocator;
    
    // 初始化插件数据
    plugin_data = PluginData{
        .enabled = true,
        .counter = 0,
    };
    
    std.log.info("插件 {s} 已初始化", .{PLUGIN_NAME});
    return &plugin_data.?;
}

export fn plugin_deinit(handle: *anyopaque) void {
    _ = handle;
    
    if (plugin_data) |*data| {
        std.log.info("插件 {s} 已销毁，总计处理了 {d} 个请求", .{ PLUGIN_NAME, data.counter });
    }
    plugin_data = null;
}

export fn plugin_start(handle: *anyopaque) !void {
    _ = handle;
    
    std.log.info("插件 {s} 已启动", .{PLUGIN_NAME});
}

export fn plugin_stop(handle: *anyopaque) !void {
    _ = handle;
    
    std.log.info("插件 {s} 已停止", .{PLUGIN_NAME});
}

// HTTP 处理器示例 - 插件可以注册自己的路由
export fn register_http_handlers(app: anytype) !void {
    // 这是一个示例函数，具体实现取决于框架的 HTTP 接口
    _ = app;
    
    std.log.info("插件 {s} 注册了 HTTP 处理器", .{PLUGIN_NAME});
    
    // 在实际实现中，这里会注册路由处理器
    // try app.route("/plugin/example", example_handler);
}

// 示例处理器函数
export fn example_handler(req: zap.Request) !void {
    if (plugin_data) |*data| {
        data.counter += 1;
        
        try req.sendJson(.{
            .message = "来自插件的响应",
            .plugin_name = PLUGIN_NAME,
            .request_count = data.counter,
            .timestamp = std.time.timestamp(),
        });
    } else {
        try req.sendError(500, "Plugin not initialized");
    }
}

// 自定义路由处理器
export fn handle_custom_route(path: []const u8, req: zap.Request) !bool {
    if (std.mem.eql(u8, path, "/api/plugin/status")) {
        if (plugin_data) |data| {
            try req.sendJson(.{
                .status = "active",
                .name = PLUGIN_NAME,
                .version = PLUGIN_VERSION,
                .enabled = data.enabled,
                .counter = data.counter,
            });
        } else {
            try req.sendJson(.{
                .status = "inactive",
                .name = PLUGIN_NAME,
            });
        }
        return true; // 已处理请求
    }
    
    return false; // 未处理此路由
}

// 插件提供的公共 API
export fn increment_counter() u32 {
    if (plugin_data) |*data| {
        data.counter += 1;
        return data.counter;
    }
    return 0;
}

export fn get_counter() u32 {
    if (plugin_data) |data| {
        return data.counter;
    }
    return 0;
}

test "Example plugin interface" {
    // 测试插件基本接口
    const name = plugin_get_name();
    try std.testing.expect(std.mem.eql(u8, std.cstr.toSlice(name), PLUGIN_NAME));
    
    std.debug.print("插件接口定义正确\n", .{});
}