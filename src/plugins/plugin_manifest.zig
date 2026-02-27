const std = @import("std");

pub const SemanticVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn parse(str: []const u8) !SemanticVersion {
        var iter = std.mem.splitScalar(u8, str, '.');
        const major = try std.fmt.parseInt(u32, iter.next() orelse return error.InvalidVersion, 10);
        const minor = try std.fmt.parseInt(u32, iter.next() orelse return error.InvalidVersion, 10);
        const patch = try std.fmt.parseInt(u32, iter.next() orelse return error.InvalidVersion, 10);

        return SemanticVersion{
            .major = major,
            .minor = minor,
            .patch = patch,
        };
    }

    pub fn format(
        self: SemanticVersion,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }

    pub fn compare(self: SemanticVersion, other: SemanticVersion) std.math.Order {
        if (self.major != other.major) return std.math.order(self.major, other.major);
        if (self.minor != other.minor) return std.math.order(self.minor, other.minor);
        return std.math.order(self.patch, other.patch);
    }

    pub fn satisfies(self: SemanticVersion, constraint: []const u8) !bool {
        if (std.mem.startsWith(u8, constraint, ">=")) {
            const ver = try parse(constraint[2..]);
            return self.compare(ver) != .lt;
        } else if (std.mem.startsWith(u8, constraint, "<=")) {
            const ver = try parse(constraint[2..]);
            return self.compare(ver) != .gt;
        } else if (std.mem.startsWith(u8, constraint, ">")) {
            const ver = try parse(constraint[1..]);
            return self.compare(ver) == .gt;
        } else if (std.mem.startsWith(u8, constraint, "<")) {
            const ver = try parse(constraint[1..]);
            return self.compare(ver) == .lt;
        } else if (std.mem.startsWith(u8, constraint, "==") or std.mem.startsWith(u8, constraint, "=")) {
            const offset: usize = if (std.mem.startsWith(u8, constraint, "==")) 2 else 1;
            const ver = try parse(constraint[offset..]);
            return self.compare(ver) == .eq;
        } else {
            const ver = try parse(constraint);
            return self.compare(ver) == .eq;
        }
    }
};

pub const Permission = enum {
    filesystem_read,
    filesystem_write,
    network_client,
    network_server,
    database_read,
    database_write,
    execute_commands,
    access_env,
    http_register_routes,
    event_publish,
    event_subscribe,

    pub fn toString(self: Permission) []const u8 {
        return @tagName(self);
    }
};

pub const PluginDependency = struct {
    id: []const u8,
    version_constraint: []const u8,
    optional: bool = false,
};

pub const Manifest = struct {
    id: []const u8,
    name: []const u8,
    version: SemanticVersion,
    author: []const u8,
    license: []const u8 = "MIT",
    homepage: ?[]const u8 = null,
    description: []const u8 = "",

    api_version: u32,
    zig_version_min: []const u8 = "0.15.0",
    zig_version_max: ?[]const u8 = null,
    host_version_min: ?[]const u8 = null,

    dependencies: []const PluginDependency = &[_]PluginDependency{},
    conflicts: []const []const u8 = &[_][]const u8{},

    capabilities: @import("plugin_interface.zig").PluginCapabilities = .{},
    required_permissions: []const Permission = &[_]Permission{},

    max_memory_mb: ?u32 = null,
    max_threads: ?u32 = null,

    checksum_sha256: ?[32]u8 = null,
    signature: ?[]const u8 = null,

    pub fn validate(self: *const Manifest) !void {
        if (self.id.len == 0) return error.InvalidManifest;
        if (self.name.len == 0) return error.InvalidManifest;
        if (self.author.len == 0) return error.InvalidManifest;
    }

    pub fn hasPermission(self: *const Manifest, permission: Permission) bool {
        for (self.required_permissions) |p| {
            if (p == permission) return true;
        }
        return false;
    }

    pub fn hasDependency(self: *const Manifest, plugin_id: []const u8) bool {
        for (self.dependencies) |dep| {
            if (std.mem.eql(u8, dep.id, plugin_id)) return true;
        }
        return false;
    }

    pub fn conflictsWith(self: *const Manifest, plugin_id: []const u8) bool {
        for (self.conflicts) |conflict| {
            if (std.mem.eql(u8, conflict, plugin_id)) return true;
        }
        return false;
    }
};

test "SemanticVersion parsing" {
    const v1 = try SemanticVersion.parse("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v1.major);
    try std.testing.expectEqual(@as(u32, 2), v1.minor);
    try std.testing.expectEqual(@as(u32, 3), v1.patch);
}

test "SemanticVersion comparison" {
    const v1 = SemanticVersion{ .major = 1, .minor = 2, .patch = 3 };
    const v2 = SemanticVersion{ .major = 1, .minor = 2, .patch = 4 };
    const v3 = SemanticVersion{ .major = 2, .minor = 0, .patch = 0 };

    try std.testing.expectEqual(std.math.Order.lt, v1.compare(v2));
    try std.testing.expectEqual(std.math.Order.lt, v1.compare(v3));
    try std.testing.expectEqual(std.math.Order.eq, v1.compare(v1));
}

test "SemanticVersion satisfies constraints" {
    const v = SemanticVersion{ .major = 1, .minor = 5, .patch = 0 };

    try std.testing.expect(try v.satisfies(">=1.0.0"));
    try std.testing.expect(try v.satisfies("<=2.0.0"));
    try std.testing.expect(try v.satisfies(">1.0.0"));
    try std.testing.expect(try v.satisfies("<2.0.0"));
    try std.testing.expect(try v.satisfies("==1.5.0"));
}
