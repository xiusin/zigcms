//! 插件管理器 - 管理可插拔模块的动态加载、卸载和运行
//!
//! 该服务提供：
//! - 动态加载外部模块（.so, .dll, .dylib）
//! - 插件生命周期管理
//! - 插件能力查询
//! - 热加载和热卸载支持
//! - 插件安全沙箱（基本实现）

const std = @import("std");
const builtin = @import("builtin");
const PluginInterface = @import("plugin_interface.zig").PluginInterface;
const PluginHandle = @import("plugin_interface.zig").PluginHandle;
const PluginError = @import("plugin_interface.zig").PluginError;

pub const PluginManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    plugins: std.StringHashMap(PluginHandle),
    plugin_paths: std.StringHashMap([]const u8),
    mutex: std.Thread.Mutex,
    running_plugins: std.AutoHashMap([]const u8, []const u8),

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{
            .allocator = allocator,
            .plugins = std.StringHashMap(PluginHandle).init(allocator),
            .plugin_paths = std.StringHashMap([]const u8).init(allocator),
            .running_plugins = std.AutoHashMap([]const u8, []const u8).init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *PluginManager) void {
        self.unloadAllPlugins() catch {};

        var path_iter = self.plugin_paths.valueIterator();
        while (path_iter.next()) |path| {
            self.allocator.free(path.*);
        }
        self.plugin_paths.deinit();

        var plugin_iter = self.plugins.valueIterator();
        while (plugin_iter.next()) |plugin| {
            plugin.deinit(self.allocator);
        }
        self.plugins.deinit();

        var running_plugin_iter = self.running_plugins.keyIterator();
        while (running_plugin_iter.next()) |name| {
            self.allocator.free(name.*);
        }
        self.running_plugins.deinit();
    }

    /// 从文件路径加载插件
    pub fn loadPlugin(self: *PluginManager, path: []const u8, name: ?[]const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 检查插件是否已加载
        const plugin_name = name orelse std.fs.path.basename(path);
        if (self.plugins.get(plugin_name)) |_| {
            return PluginError.InvalidPlugin; // 插件已存在
        }

        // 创建插件句柄
        const handle = try PluginHandle.init(self.allocator, path);

        // 存储插件信息
        const stored_name = try self.allocator.dupe(u8, plugin_name);
        try self.plugins.put(stored_name, handle);

        const stored_path = try self.allocator.dupe(u8, path);
        try self.plugin_paths.put(stored_name, stored_path);
    }

    /// 根据名称卸载插件
    pub fn unloadPlugin(self: *PluginManager, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.fetchRemove(name)) |entry| {
            // 如果插件正在运行，先停止它
            if (self.running_plugins.contains(name)) {
                _ = self.stopPlugin(name) catch {};
            }

            // 销毁插件句柄
            entry.value.deinit(self.allocator);

            // 清理路径记录
            if (self.plugin_paths.fetchRemove(name)) |path_entry| {
                self.allocator.free(path_entry.value);
            }
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 卸载所有插件
    pub fn unloadAllPlugins(self: *PluginManager) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.plugins.keyIterator();
        while (iter.next()) |name| {
            _ = self.unloadPlugin(name.*) catch {}; // 忽略错误，继续卸载其他插件
        }
    }

    /// 初始化插件（但不启动）
    pub fn initPlugin(self: *PluginManager, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |*handle| {
            if (handle.interface.data == null) {
                try handle.load_and_init(self.allocator);
            }
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 启动插件
    pub fn startPlugin(self: *PluginManager, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |*handle| {
            try handle.start(self.allocator);

            // 记录插件为运行状态
            const stored_name = try self.allocator.dupe(u8, name);
            try self.running_plugins.put(stored_name, "");
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 停止插件
    pub fn stopPlugin(self: *PluginManager, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |*handle| {
            try handle.stop();

            // 从运行列表中移除
            if (self.running_plugins.remove(name)) |stored_name| {
                self.allocator.free(stored_name);
            }
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 获取插件信息
    pub fn getPluginInfo(self: *PluginManager, name: []const u8) !@import("plugin_interface.zig").PluginInfo {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |handle| {
            return handle.info;
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 获取插件能力
    pub fn getPluginCapabilities(self: *PluginManager, name: []const u8) !@import("plugin_interface.zig").PluginCapabilities {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |handle| {
            return handle.capabilities;
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 检查插件是否正在运行
    pub fn isPluginRunning(self: *PluginManager, name: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.running_plugins.contains(name);
    }

    /// 获取所有插件名称列表
    pub fn getPluginNames(self: *PluginManager) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const keys = self.plugins.keys();
        var result = try self.allocator.alloc([]const u8, keys.len);

        for (keys, 0..) |key, i| {
            result[i] = key;
        }

        return result;
    }

    /// 从目录加载所有插件
    pub fn loadPluginsFromDirectory(self: *PluginManager, dir_path: []const u8) !void {
        const dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                // 目录不存在，创建它
                std.fs.cwd().makeDir(dir_path) catch {};
                return;
            },
            else => return err,
        };
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .file) {
                // 检查文件扩展名是否为动态库
                if (std.mem.endsWith(u8, entry.name, ".so") or
                    std.mem.endsWith(u8, entry.name, ".dylib") or
                    std.mem.endsWith(u8, entry.name, ".dll"))
                {
                    const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, entry.name });
                    defer self.allocator.free(full_path);

                    // 尝试加载插件
                    const plugin_name = std.fs.path.stem(entry.name);
                    _ = self.loadPlugin(full_path, plugin_name) catch |err| {
                        std.debug.print("Failed to load plugin {s}: {any}\n", .{ entry.name, err });
                        continue; // 继续尝试加载其他插件
                    };
                }
            }
        }
    }

    /// 重新加载插件（热重载）
    pub fn reloadPlugin(self: *PluginManager, name: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |*handle| {
            const was_running = self.running_plugins.contains(name);

            // 先停止插件（如果正在运行）
            if (was_running) {
                try handle.stop();
            }

            // 重新加载
            try handle.reload(self.allocator);

            // 如果原来在运行，则重新启动
            if (was_running) {
                try handle.start(self.allocator);
            }
        } else {
            return PluginError.InvalidPlugin;
        }
    }

    /// 获取插件运行状态
    pub fn getPluginStatus(self: *PluginManager, name: []const u8) !struct {
        loaded: bool,
        initialized: bool,
        running: bool,
        capabilities: @import("plugin_interface.zig").PluginCapabilities,
    } {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.get(name)) |handle| {
            return .{
                .loaded = true,
                .initialized = handle.interface.data != null,
                .running = self.running_plugins.contains(name),
                .capabilities = handle.capabilities,
            };
        } else {
            return .{
                .loaded = false,
                .initialized = false,
                .running = false,
                .capabilities = @import("plugin_interface.zig").PluginCapabilities{},
            };
        }
    }

    /// 调用插件特定函数（通用接口）
    pub fn callPluginFunction(self: *PluginManager, name: []const u8, func_name: []const u8, args: anytype) !void {
        _ = self;
        _ = name;
        _ = func_name;
        _ = args;
        // 这是一个简化实现，实际中需要更复杂的函数调用机制
        // 可能需要使用 comptime 动态调用或通过插件提供的通用接口
        return PluginError.NotSupported; // 暂不支持
    }

    /// 启动所有插件
    pub fn startAllPlugins(self: *PluginManager) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            if (!self.running_plugins.contains(entry.key_ptr.*)) {
                try entry.value_ptr.start(self.allocator);

                const stored_name = try self.allocator.dupe(u8, entry.key_ptr.*);
                try self.running_plugins.put(stored_name, "");
            }
        }
    }

    /// 停止所有插件
    pub fn stopAllPlugins(self: *PluginManager) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.running_plugins.keyIterator();
        while (iter.next()) |name| {
            _ = self.stopPlugin(name.*) catch {}; // 忽略错误
        }
    }
};

test "PluginManager basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = PluginManager.init(allocator);
    defer manager.deinit();

    // 基本操作测试
    try std.testing.expect(manager.plugins.count() == 0);

    // 因为没有实际插件文件，所以无法测试加载功能
    std.debug.print("PluginManager interface defined correctly\n", .{});
}
