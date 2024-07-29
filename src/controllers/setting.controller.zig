const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");

pub const Setting = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }
};
