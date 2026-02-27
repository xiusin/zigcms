//! 插件管理器 - 可插拔模块载入服务
//!
//! 功能特性：
//! - 动态加载/卸载共享库 (.so/.dylib/.dll)
//! - 线程安全的插件管理
//! - 完善的异常处理与错误恢复
//! - 内存安全保证
//! - 插件生命周期管理
//! - 热重载支持

const std = @import("std");
const interface = @import("plugin_interface.zig");
const manifest_mod = @import("plugin_manifest.zig");
const security_mod = @import("security_policy.zig");
const verifier_mod = @import("plugin_verifier.zig");
const registry_mod = @import("plugin_registry.zig");
const event_bus_mod = @import("event_bus.zig");
const resource_tracker_mod = @import("resource_tracker.zig");
const dependency_resolver_mod = @import("dependency_resolver.zig");

pub const PluginCapabilities = interface.PluginCapabilities;
pub const PluginInfo = interface.PluginInfo;
pub const PluginState = interface.PluginState;
pub const PluginError = interface.PluginError;
pub const PluginVTable = interface.PluginVTable;
pub const PluginContext = interface.PluginContext;
pub const PLUGIN_API_VERSION = interface.PLUGIN_API_VERSION;
pub const Manifest = manifest_mod.Manifest;
pub const SecurityPolicy = security_mod.SecurityPolicy;
pub const PluginVerifier = verifier_mod.PluginVerifier;
pub const PluginRegistry = registry_mod.PluginRegistry;
pub const EventBus = event_bus_mod.EventBus;
pub const ResourceTracker = resource_tracker_mod.ResourceTracker;
pub const DependencyResolver = dependency_resolver_mod.DependencyResolver;

/// 已加载的插件实例
pub const LoadedPlugin = struct {
    /// 插件名称
    name: []const u8,
    /// 插件文件路径
    path: []const u8,
    /// 动态库句柄
    handle: ?std.DynLib = null,
    /// 插件状态
    state: PluginState = .unloaded,
    /// 插件信息
    info: PluginInfo = PluginInfo.default(),
    /// 插件清单
    manifest: ?Manifest = null,
    /// 插件能力
    capabilities: PluginCapabilities = .{},
    /// 虚函数表
    vtable: PluginVTable = .{},
    /// 插件私有数据句柄
    plugin_handle: ?*anyopaque = null,
    /// 插件上下文
    context: ?PluginContext = null,
    /// Arena 分配器
    arena: ?std.heap.ArenaAllocator = null,
    /// 资源追踪器
    resource_tracker: ?ResourceTracker = null,
    /// 加载时间戳
    loaded_at: i64 = 0,
    /// 错误信息
    last_error: ?[]const u8 = null,
    /// 内存分配器
    allocator: std.mem.Allocator,

    /// 释放资源
    pub fn deinit(self: *LoadedPlugin) void {
        if (self.last_error) |err| {
            self.allocator.free(err);
        }
        if (self.arena) |*a| {
            a.deinit();
        }
        self.allocator.free(self.name);
        self.allocator.free(self.path);
    }
};

/// 插件管理器
pub const PluginManager = struct {
    /// 内存分配器
    allocator: std.mem.Allocator,
    /// 已加载的插件列表
    plugins: std.StringHashMap(LoadedPlugin),
    /// 插件目录
    plugin_dir: []const u8,
    /// 线程安全锁
    mutex: std.Thread.Mutex = .{},
    /// 是否启用热重载
    hot_reload_enabled: bool = false,
    /// 插件加载回调
    on_plugin_loaded: ?*const fn (*LoadedPlugin) void = null,
    /// 插件卸载回调
    on_plugin_unloaded: ?*const fn ([]const u8) void = null,
    /// 安全策略
    security_policy: SecurityPolicy,
    /// 插件验证器
    verifier: PluginVerifier,
    /// 插件注册表
    registry: PluginRegistry,
    /// 事件总线
    event_bus: EventBus,
    /// 依赖解析器
    dependency_resolver: DependencyResolver,

    const Self = @This();

    /// 初始化插件管理器
    pub fn init(allocator: std.mem.Allocator, plugin_dir: []const u8, policy: SecurityPolicy) !Self {
        const dir_copy = try allocator.dupe(u8, plugin_dir);

        var registry = PluginRegistry.init(allocator);
        var event_bus = EventBus.init(allocator);
        var dependency_resolver = DependencyResolver.init(allocator, &registry);

        return Self{
            .allocator = allocator,
            .plugins = std.StringHashMap(LoadedPlugin).init(allocator),
            .plugin_dir = dir_copy,
            .security_policy = policy,
            .verifier = PluginVerifier.init(allocator),
            .registry = registry,
            .event_bus = event_bus,
            .dependency_resolver = dependency_resolver,
        };
    }

    /// 清理所有资源
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            self.unloadPluginInternal(entry.value_ptr) catch {};
            entry.value_ptr.deinit();
        }
        self.plugins.deinit();
        self.event_bus.deinit();
        self.registry.deinit();
        self.allocator.free(self.plugin_dir);
    }

    /// 加载单个插件
    pub fn loadPlugin(self: *Self, plugin_name: []const u8, plugin_manifest: ?Manifest) PluginError!*LoadedPlugin {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.contains(plugin_name)) {
            return PluginError.AlreadyLoaded;
        }

        const path = self.buildPluginPath(plugin_name) catch return PluginError.OutOfMemory;
        defer self.allocator.free(path);

        std.fs.cwd().access(path, .{}) catch {
            return PluginError.PluginNotFound;
        };

        var plugin = LoadedPlugin{
            .name = self.allocator.dupe(u8, plugin_name) catch return PluginError.OutOfMemory,
            .path = self.allocator.dupe(u8, path) catch return PluginError.OutOfMemory,
            .allocator = self.allocator,
            .manifest = plugin_manifest,
        };

        if (plugin.manifest) |*m| {
            m.validate() catch {
                std.log.err("Invalid manifest for plugin: {s}", .{plugin_name});
                return PluginError.InitFailed;
            };

            self.verifier.checkPolicy(m, &self.security_policy) catch {
                std.log.err("Plugin {s} failed security policy check", .{plugin_name});
                return PluginError.InitFailed;
            };

            self.verifier.verifyAll(path, m, &self.security_policy) catch |err| {
                std.log.err("Plugin {s} failed verification: {}", .{ plugin_name, err });
                return PluginError.InitFailed;
            };
        }

        plugin.handle = std.DynLib.open(path) catch {
            plugin.state = .error_state;
            plugin.last_error = self.allocator.dupe(u8, "动态库加载失败") catch null;
            return PluginError.LoadFailed;
        };

        self.resolveSymbols(&plugin) catch |err| {
            if (plugin.handle) |*h| h.close();
            plugin.state = .error_state;
            return err;
        };

        plugin.state = .loaded;
        plugin.loaded_at = std.time.timestamp();

        if (plugin.vtable.get_info) |get_info| {
            const info = get_info();
            plugin.info = info.*;
        }

        if (plugin.vtable.get_capabilities) |get_caps| {
            plugin.capabilities = PluginCapabilities.fromBitmap(get_caps());
        }

        const max_memory_mb = if (plugin.manifest) |m| m.max_memory_mb orelse self.security_policy.max_plugin_memory_mb else self.security_policy.max_plugin_memory_mb;
        plugin.resource_tracker = ResourceTracker.init(max_memory_mb, 100, 10);

        plugin.arena = std.heap.ArenaAllocator.init(self.allocator);
        plugin.context = PluginContext{
            .arena = &plugin.arena.?,
            .event_bus = &self.event_bus,
            .resource_tracker = &plugin.resource_tracker.?,
        };

        self.plugins.put(plugin.name, plugin) catch return PluginError.OutOfMemory;

        const loaded = self.plugins.getPtr(plugin.name).?;

        if (self.on_plugin_loaded) |callback| {
            callback(loaded);
        }

        std.log.info("插件 '{s}' v{s} 加载成功", .{ plugin.info.name, plugin.info.version });
        return loaded;
    }

    /// 初始化插件
    pub fn initPlugin(self: *Self, plugin_name: []const u8) PluginError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.getPtr(plugin_name) orelse return PluginError.NotLoaded;

        if (plugin.state != .loaded) {
            return PluginError.InvalidHandle;
        }

        if (plugin.vtable.init) |init_fn| {
            plugin.plugin_handle = init_fn();
            if (plugin.plugin_handle == null) {
                plugin.state = .error_state;
                return PluginError.InitFailed;
            }
        }

        plugin.state = .initialized;
        std.log.info("插件 '{s}' 初始化完成", .{plugin.info.name});
    }

    /// 启动插件
    pub fn startPlugin(self: *Self, plugin_name: []const u8) PluginError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.getPtr(plugin_name) orelse return PluginError.NotLoaded;

        if (plugin.state != .initialized and plugin.state != .stopped) {
            return PluginError.InvalidHandle;
        }

        if (plugin.vtable.start) |start_fn| {
            if (!start_fn(plugin.plugin_handle)) {
                plugin.state = .error_state;
                return PluginError.StartFailed;
            }
        }

        plugin.state = .running;
        std.log.info("插件 '{s}' 已启动", .{plugin.info.name});
    }

    /// 停止插件
    pub fn stopPlugin(self: *Self, plugin_name: []const u8) PluginError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const plugin = self.plugins.getPtr(plugin_name) orelse return PluginError.NotLoaded;

        if (plugin.state != .running) {
            return PluginError.InvalidHandle;
        }

        if (plugin.vtable.stop) |stop_fn| {
            if (!stop_fn(plugin.plugin_handle)) {
                plugin.state = .error_state;
                return PluginError.StopFailed;
            }
        }

        plugin.state = .stopped;
        std.log.info("插件 '{s}' 已停止", .{plugin.info.name});
    }

    /// 卸载插件
    pub fn unloadPlugin(self: *Self, plugin_name: []const u8) PluginError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var plugin = self.plugins.fetchRemove(plugin_name) orelse return PluginError.NotLoaded;

        self.unloadPluginInternal(&plugin.value) catch {};
        plugin.value.deinit();

        // 触发回调
        if (self.on_plugin_unloaded) |callback| {
            callback(plugin_name);
        }
    }

    /// 热重载插件
    pub fn reloadPlugin(self: *Self, plugin_name: []const u8) PluginError!*LoadedPlugin {
        const manifest_backup = if (self.getPlugin(plugin_name)) |p| p.manifest else null;
        self.unloadPlugin(plugin_name) catch {};
        return self.loadPlugin(plugin_name, manifest_backup);
    }

    /// 获取插件
    pub fn getPlugin(self: *Self, plugin_name: []const u8) ?*LoadedPlugin {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.plugins.getPtr(plugin_name);
    }

    /// 获取所有已加载插件
    pub fn getAllPlugins(self: *Self) ![]*LoadedPlugin {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList(*LoadedPlugin).init(self.allocator);
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            try list.append(entry.value_ptr);
        }
        return list.toOwnedSlice();
    }

    /// 扫描并加载目录下所有插件
    pub fn loadAllFromDirectory(self: *Self) !usize {
        var count: usize = 0;

        var dir = std.fs.cwd().openDir(self.plugin_dir, .{ .iterate = true }) catch {
            std.log.warn("无法打开插件目录: {s}", .{self.plugin_dir});
            return 0;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            const ext = std.fs.path.extension(entry.name);
            const valid_ext = comptime switch (@import("builtin").os.tag) {
                .macos => ".dylib",
                .windows => ".dll",
                else => ".so",
            };

            if (!std.mem.eql(u8, ext, valid_ext)) continue;

            const name_end = std.mem.lastIndexOf(u8, entry.name, ".") orelse continue;
            var name_start: usize = 0;
            if (std.mem.startsWith(u8, entry.name, "lib")) {
                name_start = 3;
            }
            const plugin_name = entry.name[name_start..name_end];

            if (self.loadPlugin(plugin_name, null)) |_| {
                count += 1;
            } else |err| {
                std.log.warn("加载插件 '{s}' 失败: {}", .{ plugin_name, err });
            }
        }

        return count;
    }

    /// 获取具有特定能力的插件列表
    pub fn getPluginsByCapability(self: *Self, capability: anytype) ![]*LoadedPlugin {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList(*LoadedPlugin).init(self.allocator);
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            const caps = entry.value_ptr.capabilities;
            const has_cap = switch (@TypeOf(capability)) {
                bool => capability,
                else => @field(caps, @tagName(capability)),
            };
            if (has_cap) {
                try list.append(entry.value_ptr);
            }
        }
        return list.toOwnedSlice();
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// 解析插件符号
    fn resolveSymbols(self: *Self, plugin: *LoadedPlugin) PluginError!void {
        _ = self;
        var handle = &(plugin.handle orelse return PluginError.InvalidHandle);

        // 必需符号
        plugin.vtable.get_info = handle.lookup(interface.GetInfoFn, interface.SymbolNames.get_info);
        plugin.vtable.get_capabilities = handle.lookup(interface.GetCapsFn, interface.SymbolNames.get_capabilities);
        plugin.vtable.init = handle.lookup(interface.InitFn, interface.SymbolNames.init);
        plugin.vtable.deinit = handle.lookup(interface.DeinitFn, interface.SymbolNames.deinit);

        // 可选符号
        plugin.vtable.start = handle.lookup(interface.StartFn, interface.SymbolNames.start);
        plugin.vtable.stop = handle.lookup(interface.StopFn, interface.SymbolNames.stop);

        // 验证必需符号
        if (!plugin.vtable.isValid()) {
            return PluginError.MissingSymbol;
        }
    }

    /// 构建插件路径
    fn buildPluginPath(self: *Self, plugin_name: []const u8) ![]const u8 {
        const ext = comptime switch (@import("builtin").os.tag) {
            .macos => ".dylib",
            .windows => ".dll",
            else => ".so",
        };

        const prefix = comptime switch (@import("builtin").os.tag) {
            .windows => "",
            else => "lib",
        };

        return std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}{s}{s}",
            .{ self.plugin_dir, prefix, plugin_name, ext },
        );
    }

    /// 内部卸载逻辑
    fn unloadPluginInternal(self: *Self, plugin: *LoadedPlugin) !void {
        _ = self;

        // 停止运行中的插件
        if (plugin.state == .running) {
            if (plugin.vtable.stop) |stop_fn| {
                _ = stop_fn(plugin.plugin_handle);
            }
        }

        // 清理插件
        if (plugin.state == .initialized or plugin.state == .running or plugin.state == .stopped) {
            if (plugin.vtable.deinit) |deinit_fn| {
                deinit_fn(plugin.plugin_handle);
            }
        }

        // 关闭动态库
        if (plugin.handle) |*h| {
            h.close();
            plugin.handle = null;
        }

        plugin.state = .unloaded;
        std.log.info("插件 '{s}' 已卸载", .{plugin.info.name});
    }
};

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建全局插件管理器实例
var global_manager: ?PluginManager = null;

/// 获取全局插件管理器
pub fn getGlobalManager() ?*PluginManager {
    return if (global_manager) |*m| m else null;
}

/// 初始化全局插件管理器
pub fn initGlobalManager(allocator: std.mem.Allocator, plugin_dir: []const u8) !*PluginManager {
    if (global_manager != null) {
        return &global_manager.?;
    }
    global_manager = try PluginManager.init(allocator, plugin_dir);
    return &global_manager.?;
}

/// 清理全局插件管理器
pub fn deinitGlobalManager() void {
    if (global_manager) |*m| {
        m.deinit();
        global_manager = null;
    }
}

// ============================================================================
// 测试
// ============================================================================

test "PluginManager 基础功能" {
    const allocator = std.testing.allocator;

    var manager = try PluginManager.init(allocator, "plugins", SecurityPolicy.Default);
    defer manager.deinit();

    const result = manager.loadPlugin("nonexistent", null);
    try std.testing.expectError(PluginError.PluginNotFound, result);
}

test "PluginCapabilities 转换" {
    const caps = PluginCapabilities{
        .http_handlers = true,
        .middleware = true,
    };

    const bitmap = caps.toBitmap();
    try std.testing.expect(bitmap != 0);

    const restored = PluginCapabilities.fromBitmap(bitmap);
    try std.testing.expect(restored.http_handlers);
    try std.testing.expect(restored.middleware);
}
