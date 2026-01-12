const std = @import("std");
const manifest_mod = @import("plugin_manifest.zig");
const interface = @import("plugin_interface.zig");

pub const Manifest = manifest_mod.Manifest;
pub const PluginCapabilities = interface.PluginCapabilities;

pub const PluginEntry = struct {
    manifest: Manifest,
    path: []const u8,
    loaded: bool = false,
    handle: ?*anyopaque = null,

    pub fn deinit(self: *PluginEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const PluginRegistry = struct {
    allocator: std.mem.Allocator,
    plugins: std.StringHashMap(PluginEntry),
    by_capability: std.AutoHashMap(u32, std.ArrayList([]const u8)),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) PluginRegistry {
        return .{
            .allocator = allocator,
            .plugins = std.StringHashMap(PluginEntry).init(allocator),
            .by_capability = std.AutoHashMap(u32, std.ArrayList([]const u8)).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *PluginRegistry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.plugins.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.plugins.deinit();

        var cap_iter = self.by_capability.iterator();
        while (cap_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.by_capability.deinit();
    }

    pub fn registerPlugin(self: *PluginRegistry, plugin_manifest: Manifest, path: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.contains(plugin_manifest.id)) {
            return error.PluginAlreadyRegistered;
        }

        const path_copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(path_copy);

        const entry = PluginEntry{
            .manifest = plugin_manifest,
            .path = path_copy,
        };

        try self.plugins.put(plugin_manifest.id, entry);

        try self.indexByCapability(plugin_manifest.id, plugin_manifest.capabilities);

        std.log.info("Registered plugin: {s} v{}", .{ plugin_manifest.name, plugin_manifest.version });
    }

    pub fn unregisterPlugin(self: *PluginRegistry, plugin_id: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.fetchRemove(plugin_id)) |entry| {
            entry.value.deinit(self.allocator);

            self.removeFromCapabilityIndex(plugin_id);

            std.log.info("Unregistered plugin: {s}", .{plugin_id});
        } else {
            return error.PluginNotFound;
        }
    }

    pub fn getPlugin(self: *PluginRegistry, plugin_id: []const u8) ?PluginEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.plugins.get(plugin_id);
    }

    pub fn getPluginPtr(self: *PluginRegistry, plugin_id: []const u8) ?*PluginEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.plugins.getPtr(plugin_id);
    }

    pub fn setLoaded(self: *PluginRegistry, plugin_id: []const u8, handle: *anyopaque) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.getPtr(plugin_id)) |entry| {
            entry.loaded = true;
            entry.handle = handle;
        } else {
            return error.PluginNotFound;
        }
    }

    pub fn setUnloaded(self: *PluginRegistry, plugin_id: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.plugins.getPtr(plugin_id)) |entry| {
            entry.loaded = false;
            entry.handle = null;
        } else {
            return error.PluginNotFound;
        }
    }

    pub fn findByCapability(self: *PluginRegistry, capability: PluginCapabilities) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const bitmap = capability.toBitmap();
        if (self.by_capability.get(bitmap)) |list| {
            return try self.allocator.dupe([]const u8, list.items);
        }
        return &[_][]const u8{};
    }

    pub fn discoverPlugins(self: *PluginRegistry, dir: []const u8) !usize {
        var count: usize = 0;

        var plugin_dir = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.warn("Plugin directory not found: {s}", .{dir});
                return 0;
            },
            else => return err,
        };
        defer plugin_dir.close();

        var iter = plugin_dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;

            const ext = std.fs.path.extension(entry.name);
            const valid_ext = comptime switch (@import("builtin").os.tag) {
                .macos => ".dylib",
                .windows => ".dll",
                else => ".so",
            };

            if (!std.mem.eql(u8, ext, valid_ext)) continue;

            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, entry.name });
            defer self.allocator.free(full_path);

            std.log.debug("Discovered plugin: {s}", .{full_path});
            count += 1;
        }

        return count;
    }

    pub fn checkCompatibility(self: *PluginRegistry, plugin_id: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry = self.plugins.get(plugin_id) orelse return error.PluginNotFound;

        const builtin_version = @import("builtin").zig_version;
        const zig_version_str = try std.fmt.allocPrint(
            self.allocator,
            "{d}.{d}.{d}",
            .{ builtin_version.major, builtin_version.minor, builtin_version.patch },
        );
        defer self.allocator.free(zig_version_str);

        const min_ver = try manifest_mod.SemanticVersion.parse(entry.manifest.zig_version_min);
        const current_ver = try manifest_mod.SemanticVersion.parse(zig_version_str);

        if (current_ver.compare(min_ver) == .lt) {
            std.log.err("Plugin {s} requires Zig >= {s}, current: {s}", .{
                entry.manifest.name,
                entry.manifest.zig_version_min,
                zig_version_str,
            });
            return false;
        }

        if (entry.manifest.zig_version_max) |max_ver_str| {
            const max_ver = try manifest_mod.SemanticVersion.parse(max_ver_str);
            if (current_ver.compare(max_ver) == .gt) {
                std.log.err("Plugin {s} requires Zig <= {s}, current: {s}", .{
                    entry.manifest.name,
                    max_ver_str,
                    zig_version_str,
                });
                return false;
            }
        }

        return true;
    }

    pub fn getAllPluginIds(self: *PluginRegistry) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var list = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.plugins.keyIterator();
        while (iter.next()) |key| {
            try list.append(key.*);
        }
        return list.toOwnedSlice();
    }

    fn indexByCapability(self: *PluginRegistry, plugin_id: []const u8, capabilities: PluginCapabilities) !void {
        const bitmap = capabilities.toBitmap();

        const result = try self.by_capability.getOrPut(bitmap);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList([]const u8).init(self.allocator);
        }

        try result.value_ptr.append(plugin_id);
    }

    fn removeFromCapabilityIndex(self: *PluginRegistry, plugin_id: []const u8) void {
        var iter = self.by_capability.iterator();
        while (iter.next()) |entry| {
            var list = entry.value_ptr;
            var i: usize = 0;
            while (i < list.items.len) {
                if (std.mem.eql(u8, list.items[i], plugin_id)) {
                    _ = list.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }
};

test "PluginRegistry basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var registry = PluginRegistry.init(allocator);
    defer registry.deinit();

    const test_manifest = Manifest{
        .id = "com.test.plugin",
        .name = "Test Plugin",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test Author",
        .api_version = 1,
    };

    try registry.registerPlugin(test_manifest, "/path/to/plugin.so");

    const entry = registry.getPlugin("com.test.plugin");
    try std.testing.expect(entry != null);
    try std.testing.expectEqualStrings("Test Plugin", entry.?.manifest.name);

    try registry.unregisterPlugin("com.test.plugin");
    try std.testing.expect(registry.getPlugin("com.test.plugin") == null);
}
