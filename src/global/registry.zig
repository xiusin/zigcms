const std = @import("std");

const redis = @import("../modules/redis.zig");

const Allocator = std.mem.Allocator;

pub const Registry = struct {
    allocator: std.mem.Allocator,
    redis: ?redis.Client = null,

    pub fn init(allocator: Allocator) Registry {
        return Registry{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        if (self.redis != null) {
            self.redis.?.deinit();
        }

        self.* = undefined;
        std.log.debug("registry deinit...", .{});
    }

    pub fn get_redis(self: *Registry) *redis.Client {
        // std.once(self.init_redis);
        self.init_redis() catch unreachable;
        return &self.redis.?;
    }

    fn init_redis(self: *Registry) !void {
        if (self.redis != null) return;
        self.redis = try redis.Client.init(self.allocator, .{});
    }
};
