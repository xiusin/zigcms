const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/menu.model.zig");
const dtos = @import("../dto/dtos.zig");
const GitApi = @import("../modules/github.zig").GitApi;
const Allocator = std.mem.Allocator;
const Self = @This();

clients: std.StringHashMap(GitApi),
allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
        .clients = std.StringHashMap(GitApi).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.clients.deinit();
    self.clients = undefined;
}
