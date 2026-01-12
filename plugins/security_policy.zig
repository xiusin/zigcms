const std = @import("std");
const manifest = @import("plugin_manifest.zig");

pub const Permission = manifest.Permission;

pub const SecurityPolicy = struct {
    allowed_permissions: []const Permission,
    denied_permissions: []const Permission,
    require_signature: bool = false,
    max_plugin_memory_mb: u32 = 256,
    sandbox_enabled: bool = false,

    pub const Default = SecurityPolicy{
        .allowed_permissions = &[_]Permission{
            .filesystem_read,
            .http_register_routes,
            .event_publish,
            .event_subscribe,
        },
        .denied_permissions = &[_]Permission{
            .execute_commands,
        },
        .require_signature = false,
        .max_plugin_memory_mb = 256,
        .sandbox_enabled = false,
    };

    pub const Permissive = SecurityPolicy{
        .allowed_permissions = &[_]Permission{
            .filesystem_read,
            .filesystem_write,
            .network_client,
            .network_server,
            .database_read,
            .database_write,
            .access_env,
            .http_register_routes,
            .event_publish,
            .event_subscribe,
        },
        .denied_permissions = &[_]Permission{
            .execute_commands,
        },
        .require_signature = false,
        .max_plugin_memory_mb = 512,
        .sandbox_enabled = false,
    };

    pub const Strict = SecurityPolicy{
        .allowed_permissions = &[_]Permission{
            .filesystem_read,
            .event_subscribe,
        },
        .denied_permissions = &[_]Permission{
            .filesystem_write,
            .network_client,
            .network_server,
            .database_write,
            .execute_commands,
        },
        .require_signature = true,
        .max_plugin_memory_mb = 128,
        .sandbox_enabled = true,
    };

    pub fn isPermissionAllowed(self: *const SecurityPolicy, permission: Permission) bool {
        for (self.denied_permissions) |denied| {
            if (denied == permission) return false;
        }

        for (self.allowed_permissions) |allowed| {
            if (allowed == permission) return true;
        }

        return false;
    }

    pub fn checkManifest(self: *const SecurityPolicy, plugin_manifest: *const manifest.Manifest) !void {
        for (plugin_manifest.required_permissions) |perm| {
            if (!self.isPermissionAllowed(perm)) {
                std.log.err("Plugin {s} requires denied permission: {s}", .{
                    plugin_manifest.name,
                    perm.toString(),
                });
                return error.PermissionDenied;
            }
        }

        if (self.require_signature and plugin_manifest.signature == null) {
            std.log.err("Plugin {s} requires signature but none provided", .{plugin_manifest.name});
            return error.SignatureRequired;
        }

        if (plugin_manifest.max_memory_mb) |max_mem| {
            if (max_mem > self.max_plugin_memory_mb) {
                std.log.err("Plugin {s} requests {d}MB but policy allows max {d}MB", .{
                    plugin_manifest.name,
                    max_mem,
                    self.max_plugin_memory_mb,
                });
                return error.MemoryLimitExceeded;
            }
        }
    }
};

test "SecurityPolicy permission checks" {
    const policy = SecurityPolicy.Default;

    try std.testing.expect(policy.isPermissionAllowed(.filesystem_read));
    try std.testing.expect(!policy.isPermissionAllowed(.execute_commands));
}

test "SecurityPolicy manifest validation" {
    const policy = SecurityPolicy.Strict;

    const valid_manifest = manifest.Manifest{
        .id = "com.test.plugin",
        .name = "Test Plugin",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
        .required_permissions = &[_]Permission{.filesystem_read},
        .signature = &[_]u8{0} ** 64,
    };

    try policy.checkManifest(&valid_manifest);

    const invalid_manifest = manifest.Manifest{
        .id = "com.test.plugin",
        .name = "Test Plugin",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .author = "Test",
        .api_version = 1,
        .required_permissions = &[_]Permission{.execute_commands},
        .signature = &[_]u8{0} ** 64,
    };

    try std.testing.expectError(error.PermissionDenied, policy.checkManifest(&invalid_manifest));
}
