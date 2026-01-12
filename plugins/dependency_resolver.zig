const std = @import("std");
const manifest_mod = @import("plugin_manifest.zig");
const registry_mod = @import("plugin_registry.zig");

pub const Manifest = manifest_mod.Manifest;
pub const PluginDependency = manifest_mod.PluginDependency;
pub const SemanticVersion = manifest_mod.SemanticVersion;
pub const PluginRegistry = registry_mod.PluginRegistry;

pub const DependencyError = error{
    CircularDependency,
    MissingDependency,
    IncompatibleVersion,
    ConflictingPlugin,
};

pub const DependencyResolver = struct {
    allocator: std.mem.Allocator,
    registry: *PluginRegistry,

    pub fn init(allocator: std.mem.Allocator, registry: *PluginRegistry) DependencyResolver {
        return .{
            .allocator = allocator,
            .registry = registry,
        };
    }

    pub fn checkDependencies(self: *DependencyResolver, plugin_manifest: *const Manifest) !void {
        for (plugin_manifest.dependencies) |dep| {
            if (dep.optional) continue;

            const dep_entry = self.registry.getPlugin(dep.id) orelse {
                std.log.err("Plugin {s} requires dependency {s} which is not registered", .{
                    plugin_manifest.name,
                    dep.id,
                });
                return DependencyError.MissingDependency;
            };

            const dep_version = dep_entry.manifest.version;
            const satisfies = try dep_version.satisfies(dep.version_constraint);
            if (!satisfies) {
                std.log.err("Plugin {s} requires {s} {s}, but found version {}", .{
                    plugin_manifest.name,
                    dep.id,
                    dep.version_constraint,
                    dep_version,
                });
                return DependencyError.IncompatibleVersion;
            }
        }

        const all_plugin_ids = try self.registry.getAllPluginIds();
        defer self.allocator.free(all_plugin_ids);

        for (all_plugin_ids) |plugin_id| {
            if (plugin_manifest.conflictsWith(plugin_id)) {
                const entry = self.registry.getPlugin(plugin_id).?;
                if (entry.loaded) {
                    std.log.err("Plugin {s} conflicts with loaded plugin {s}", .{
                        plugin_manifest.name,
                        plugin_id,
                    });
                    return DependencyError.ConflictingPlugin;
                }
            }
        }
    }

    pub fn resolveLoadOrder(self: *DependencyResolver, plugin_ids: []const []const u8) ![][]const u8 {
        var visited = std.StringHashMap(bool).init(self.allocator);
        defer visited.deinit();

        var temp_marks = std.StringHashMap(bool).init(self.allocator);
        defer temp_marks.deinit();

        var result = std.ArrayList([]const u8).init(self.allocator);
        errdefer result.deinit();

        for (plugin_ids) |plugin_id| {
            if (!visited.contains(plugin_id)) {
                try self.visitDependency(plugin_id, &visited, &temp_marks, &result);
            }
        }

        return result.toOwnedSlice();
    }

    pub fn detectCycles(self: *DependencyResolver, plugin_ids: []const []const u8) !bool {
        var visited = std.StringHashMap(bool).init(self.allocator);
        defer visited.deinit();

        var rec_stack = std.StringHashMap(bool).init(self.allocator);
        defer rec_stack.deinit();

        for (plugin_ids) |plugin_id| {
            if (!visited.contains(plugin_id)) {
                if (try self.detectCycleUtil(plugin_id, &visited, &rec_stack)) {
                    return true;
                }
            }
        }

        return false;
    }

    fn visitDependency(
        self: *DependencyResolver,
        plugin_id: []const u8,
        visited: *std.StringHashMap(bool),
        temp_marks: *std.StringHashMap(bool),
        result: *std.ArrayList([]const u8),
    ) !void {
        if (temp_marks.get(plugin_id)) |_| {
            std.log.err("Circular dependency detected involving plugin: {s}", .{plugin_id});
            return DependencyError.CircularDependency;
        }

        if (visited.get(plugin_id)) |_| {
            return;
        }

        try temp_marks.put(plugin_id, true);

        const entry = self.registry.getPlugin(plugin_id) orelse {
            return DependencyError.MissingDependency;
        };

        for (entry.manifest.dependencies) |dep| {
            if (!dep.optional) {
                try self.visitDependency(dep.id, visited, temp_marks, result);
            }
        }

        try visited.put(plugin_id, true);
        _ = temp_marks.remove(plugin_id);
        try result.append(plugin_id);
    }

    fn detectCycleUtil(
        self: *DependencyResolver,
        plugin_id: []const u8,
        visited: *std.StringHashMap(bool),
        rec_stack: *std.StringHashMap(bool),
    ) !bool {
        try visited.put(plugin_id, true);
        try rec_stack.put(plugin_id, true);

        const entry = self.registry.getPlugin(plugin_id) orelse {
            return false;
        };

        for (entry.manifest.dependencies) |dep| {
            if (!dep.optional) {
                if (!visited.contains(dep.id)) {
                    if (try self.detectCycleUtil(dep.id, visited, rec_stack)) {
                        return true;
                    }
                } else if (rec_stack.contains(dep.id)) {
                    std.log.err("Cycle detected: {s} -> {s}", .{ plugin_id, dep.id });
                    return true;
                }
            }
        }

        _ = rec_stack.remove(plugin_id);
        return false;
    }
};

test "DependencyResolver basic checks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var registry = PluginRegistry.init(allocator);
    defer registry.deinit();

    var resolver = DependencyResolver.init(allocator, &registry);

    const manifest1 = Manifest{
        .id = "com.test.plugin1",
        .name = "Plugin 1",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
    };

    const dep = PluginDependency{
        .id = "com.test.plugin1",
        .version_constraint = ">=1.0.0",
        .optional = false,
    };

    const manifest2 = Manifest{
        .id = "com.test.plugin2",
        .name = "Plugin 2",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
        .dependencies = &[_]PluginDependency{dep},
    };

    try registry.registerPlugin(manifest1, "/path/plugin1.so");
    try registry.registerPlugin(manifest2, "/path/plugin2.so");

    try resolver.checkDependencies(&manifest2);
}

test "DependencyResolver load order" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var registry = PluginRegistry.init(allocator);
    defer registry.deinit();

    var resolver = DependencyResolver.init(allocator, &registry);

    const manifest1 = Manifest{
        .id = "com.test.plugin1",
        .name = "Plugin 1",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
    };

    const dep = PluginDependency{
        .id = "com.test.plugin1",
        .version_constraint = ">=1.0.0",
        .optional = false,
    };

    const manifest2 = Manifest{
        .id = "com.test.plugin2",
        .name = "Plugin 2",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
        .dependencies = &[_]PluginDependency{dep},
    };

    try registry.registerPlugin(manifest1, "/path/plugin1.so");
    try registry.registerPlugin(manifest2, "/path/plugin2.so");

    const plugin_ids = &[_][]const u8{ "com.test.plugin2", "com.test.plugin1" };
    const load_order = try resolver.resolveLoadOrder(plugin_ids);
    defer allocator.free(load_order);

    try std.testing.expectEqual(@as(usize, 2), load_order.len);
    try std.testing.expectEqualStrings("com.test.plugin1", load_order[0]);
    try std.testing.expectEqualStrings("com.test.plugin2", load_order[1]);
}
