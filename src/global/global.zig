const std = @import("std");
const Allocator = std.mem.Allocator;
const pg = @import("pg");
const pretty = @import("pretty");
const models = @import("../models/models.zig");

var _allocator: Allocator = undefined;
var _pool: *pg.Pool = undefined;
var inited: bool = false;

fn init_pg() !void {
    if (!inited) {
        inited = true;
        const password = try std.process.getEnvVarOwned(_allocator, "DB_PASSWORD");
        defer _allocator.free(password);
        std.log.debug("DB_PASSWORD = {s}", .{password});

        _pool = try pg.Pool.init(_allocator, .{ .size = 5, .connect = .{
            .port = 5432,
            .host = "124.222.103.232",
        }, .auth = .{
            .username = "postgres",
            .database = "postgres",
            .application_name = "zigcms",
            .password = password,
            .timeout = 10_0000,
        } });
    }
}

pub fn set_allocator(allocator: Allocator) void {
    _allocator = allocator;
}

pub fn get_allocator() Allocator {
    return _allocator;
}

pub fn get_pg_pool() !*pg.Pool {
    try init_pg();
    return _pool;
}

pub fn get_conn() !*pg.Conn {
    const pool = try get_pg_pool();
    return pool.acquire();
}

pub fn sql_exec(sql: []const u8, values: anytype) !i64 {
    var conn = try get_conn();
    defer conn.release();
    if (try conn.exec(sql, values)) |result| {
        return result;
    }
    return error.SqlExecFailed;
}

pub fn get_setting(allocator: Allocator, key: []const u8) ![]const u8 {
    var pool = try get_pg_pool();
    const sql = "SELECT * FROM zigcms.setting";
    var result = try pool.queryOpts(sql, .{}, .{ .column_names = true });

    defer result.deinit();
    const mapper = result.mapper(models.Setting, .{ .allocator = allocator });
    var config = std.StringHashMap([]const u8).init(allocator);
    defer config.deinit();
    while (try mapper.next()) |item| {
        try config.put(item.key, item.value);
    }
    if (config.get(key)) |val| {
        return val;
    }
    return error.SettingNotFound;
}

pub fn Struct2Tuple(comptime T: anytype) type {
    const Type = std.builtin.Type;
    const fields: [std.meta.fields(T).len]Type.StructField = blk: {
        var res: [std.meta.fields(T).len]Type.StructField = undefined;

        inline for (std.meta.fields(T), 0..) |field, i| {
            res[i] = Type.StructField{
                .type = field.type,
                .alignment = @alignOf(field.type),
                .default_value = null,
                .is_comptime = false,
                .name = std.fmt.comptimePrint("{}", .{i}),
            };
        }
        break :blk res;
    };

    return @Type(.{
        .Struct = std.builtin.Type.Struct{
            .layout = .auto,
            .is_tuple = true,
            .decls = &.{},
            .fields = &fields,
        },
    });
}
