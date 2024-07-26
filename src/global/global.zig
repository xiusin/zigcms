const std = @import("std");
const pg = @import("pg");

var _allocator: std.mem.Allocator = undefined;
var _pool: *pg.Pool = undefined;
var inited: bool = false;

fn init_pg() !void {
    if (!inited) {
        inited = true;
        const password = try std.process.getEnvVarOwned(_allocator, "DB_PASSWORD");
        defer _allocator.free(password);

        _pool = try pg.Pool.init(_allocator, .{ .size = 5, .connect = .{
            .port = 5432,
            .host = "124.222.103.232",
        }, .auth = .{
            .username = "postgres",
            .database = "postgres",
            .password = password,
            .timeout = 10_000,
        } });
    }
}

pub fn set_allocator(allocator: std.mem.Allocator) void {
    _allocator = allocator;
}

pub fn get_pg_pool() !*pg.Pool {
    try init_pg();
    return _pool;
}
