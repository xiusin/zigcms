//! 插件系统实现 (占位符)
//!
//! 插件系统功能待完整实现。

const std = @import("std");

pub const PluginSystemService = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn startup(self: *Self) !void {
        _ = self;
    }

    pub fn shutdown(self: *Self) !void {
        _ = self;
    }
};

pub const PluginSystem = PluginSystemService;
