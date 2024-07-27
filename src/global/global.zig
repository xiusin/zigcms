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
            .application_name = "zigcms",
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

pub fn get_conn() !*pg.Conn {
    const pool = try get_pg_pool();
    return pool.acquire();
}

pub fn sql_get_count(sql: []const u8, values: anytype) i32 {
    var conn = get_conn() catch return 0;
    defer conn.release();

    var result = conn.query(sql, values) catch return 0;
    defer result.deinit();
    while (result.next() catch return 0) |row| {
        const num = row.get(i32, 0);
        return num;
    }
    return 0;
}

pub fn sql_exec(sql: []const u8, values: anytype) !i64 {
    var conn = try get_conn();
    defer conn.release();
    std.log.debug("exec {s}", .{sql});
    if (try conn.exec(sql, values)) |result| {
        std.log.debug("exec {d}", .{result});
        return result;
    }
    return error.SqlExecFailed;
}
