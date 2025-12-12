//! 插件接口定义 - 定义可插拔模块的标准接口
//!
//! 该模块定义了插件应当实现的接口和标准函数，确保插件能够被系统动态加载和运行

const std = @import("std");
const builtin = @import("builtin");

pub const PluginError = error{
    InitializationFailed,
    LoadFailed,
    UnloadFailed,
    SymbolNotFound,
    InvalidPlugin,
    NotSupported,
};

/// 插件信息结构
pub const PluginInfo = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    license: []const u8,
};

/// 插件能力定义
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

/// 插件生命周期回调函数签名
pub const PluginInitFn = *const fn (allocator: std.mem.Allocator) PluginError!*anyopaque;
pub const PluginDeinitFn = *const fn (handle: *anyopaque) void;
pub const PluginGetNameFn = *const fn () []const u8;
pub const PluginGetInfoFn = *const fn () PluginInfo;
pub const PluginGetCapabilitiesFn = *const fn () PluginCapabilities;
pub const PluginStartFn = *const fn (handle: *anyopaque) PluginError!void;
pub const PluginStopFn = *const fn (handle: *anyopaque) PluginError!void;

/// 插件接口
pub const PluginInterface = struct {
    /// 插件的名称
    get_name: PluginGetNameFn,

    /// 获取插件信息
    get_info: PluginGetInfoFn,

    /// 获取插件能力
    get_capabilities: PluginGetCapabilitiesFn,

    /// 初始化插件
    init: PluginInitFn,

    /// 销毁插件
    deinit: PluginDeinitFn,

    /// 启动插件
    start: PluginStartFn,

    /// 停止插件
    stop: PluginStopFn,

    /// 插件特定的数据指针
    data: ?*anyopaque = null,
};

/// 插件句柄
pub const PluginHandle = struct {
    /// 动态库句柄
    dynlib: std.DynLib,

    /// 插件接口引用
    interface: PluginInterface,

    /// 插件加载路径
    path: []const u8,

    /// 插件是否已启动
    is_running: bool = false,

    /// 插件名称（缓存）
    name: []const u8,

    /// 插件信息（缓存）
    info: PluginInfo,

    /// 插件能力（缓存）
    capabilities: PluginCapabilities,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !PluginHandle {
        // 加载动态库
        var dynlib = std.DynLib.open(path) catch {
            return PluginError.LoadFailed;
        };

        // 获取必要的插件函数
        const get_name = dynlib.lookup(*const fn () []const u8, "plugin_get_name") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const get_info = dynlib.lookup(*const fn () PluginInfo, "plugin_get_info") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const get_capabilities = dynlib.lookup(*const fn () PluginCapabilities, "plugin_get_capabilities") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const init_fn = dynlib.lookup(*const fn (std.mem.Allocator) PluginError!*anyopaque, "plugin_init") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const deinit_fn = dynlib.lookup(*const fn (*anyopaque) void, "plugin_deinit") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const start_fn = dynlib.lookup(*const fn (*anyopaque) PluginError!void, "plugin_start") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        const stop_fn = dynlib.lookup(*const fn (*anyopaque) PluginError!void, "plugin_stop") orelse {
            dynlib.close();
            return PluginError.SymbolNotFound;
        };

        // 创建插件接口
        const interface = PluginInterface{
            .get_name = get_name,
            .get_info = get_info,
            .get_capabilities = get_capabilities,
            .init = init_fn,
            .deinit = deinit_fn,
            .start = start_fn,
            .stop = stop_fn,
        };

        // 获取插件信息
        const name = get_name();
        const info = get_info();
        const capabilities = get_capabilities();

        return PluginHandle{
            .dynlib = dynlib,
            .interface = interface,
            .path = try allocator.dupe(u8, path),
            .name = try allocator.dupe(u8, name),
            .info = info,
            .capabilities = capabilities,
        };
    }

    pub fn deinit(self: *PluginHandle, allocator: std.mem.Allocator) void {
        // 如果插件正在运行，则先停止
        if (self.is_running) {
            _ = self.stop() catch {};
        }

        // 如果插件已初始化，则销毁
        if (self.interface.data) |data| {
            self.interface.deinit(data);
        }

        // 关闭动态库
        self.dynlib.close();

        // 释放资源
        allocator.free(self.path);
        allocator.free(self.name);
    }

    pub fn load_and_init(self: *PluginHandle, allocator: std.mem.Allocator) !void {
        // 初始化插件实例
        self.interface.data = try self.interface.init(allocator);
    }

    pub fn start(self: *PluginHandle, allocator: std.mem.Allocator) !void {
        if (self.interface.data) |data| {
            try self.interface.start(data);
            self.is_running = true;
        } else {
            try self.load_and_init(allocator);
            if (self.interface.data) |data| {
                try self.interface.start(data);
                self.is_running = true;
            }
        }
    }

    pub fn stop(self: *PluginHandle) !void {
        if (self.interface.data) |data| {
            try self.interface.stop(data);
            self.is_running = false;
        }
    }

    pub fn reload(self: *PluginHandle, allocator: std.mem.Allocator) !void {
        if (self.is_running) {
            try self.stop();
        }

        if (self.interface.data) |data| {
            self.interface.deinit(data);
            self.interface.data = null;
        }

        try self.load_and_init(allocator);

        if (self.is_running) { // 如果原来在运行，重启它
            try self.start(allocator);
        }
    }
};

test "PluginHandle basic operations" {
    // 这个测试需要一个实际的插件库才能运行
    // 这里只验证类型定义
    std.debug.print("Plugin interface types defined correctly\n", .{});
}
