const std = @import("std");
const zap = @import("zap");
const global = @import("../global/global.zig");
const Allocator = std.mem.Allocator;

pub const Login = struct {
    const Self = @This();
    allocator: Allocator,
    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn login(_: *Self, req: zap.Request) !void {
        const pool = try global.get_pg_pool();
        var conn = try pool.acquire();
        defer conn.release();
        var result = conn.query("select 1", .{}) catch {
            return req.sendJson("error");
        };
        defer result.deinit();

        while (try result.next()) |row| {
            const num = row.get(i32, 0);
            std.log.info("User {d}", .{num});
        }
        std.log.err("Error", .{});
        req.setContentType(.JSON) catch return;
        req.setStatus(.ok);
        req.sendBody("hello world!") catch |e| {
            std.log.err("Error: {any}", .{e});
        };
        std.log.err("Error", .{});
        // req.sendJson("ok") catch return;
    }
};
