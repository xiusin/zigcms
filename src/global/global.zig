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

pub fn get_pg_pool() *pg.Pool {
    init_pg() catch {};
    return _pool;
}

pub fn sql_exec(sql: []const u8, values: anytype) !i64 {
    if (try get_pg_pool().exec(sql, values)) |result| {
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

// 动态结构体定义 https://github.com/ziglang/zig/issues/12330
// https://github.com/ziglang/zig/issues/4335 提案
// const T = @Type(.{
//     .Struct = .{
//         .layout = .Packed,
//         .fields = &.{
//             .{ .name = "0", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "1", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "2", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//             .{ .name = "3", .field_type = u2, .default_value = null, .is_comptime = false, .alignment = 0 },
//         },
//         .decls = &.{},
//         .is_tuple = true,
//     },
// });
//
//
//

// const ArgTuple = struct {
//     tuple: anytype = .{},
// };
// var arg_list = ArgTuple{};
// for (args) |arg| {
//     if (@TypeOf(arg) == ?u21) {
//         if (arg) |cp| {
//             arg_list.tuple = arg_list.tuple ++ .{ctUtf8EncodeChar(cp)};
//         } else {
//             arg_list.tuple = arg_list.tuple ++ .{"null"};
//         }
//     } else if (@TypeOf(arg) == u21) {
//         arg_list.tuple = arg_list.tuple ++ .{ctUtf8EncodeChar(arg)};
//     } else {
//         arg_list.tuple = arg_list.tuple ++ .{arg};
//     }
// }

// const tuple = Struct2Tuple(Person){ 1, "xiusin", 2}; 动态构建
pub inline fn Struct2Tuple(T: type) type {
    const Type = std.builtin.Type;

    const fields: [std.meta.fields(T).len - 1]Type.StructField = blk: {
        var res: [std.meta.fields(T).len - 1]Type.StructField = undefined;

        var i: usize = 0;
        inline for (std.meta.fields(T)) |field| {
            if (!std.mem.eql(u8, field.name, "id")) {
                res[i] = Type.StructField{
                    .type = field.type,
                    .alignment = @alignOf(field.type),
                    .default_value = field.default_value,
                    .is_comptime = false,
                    .name = std.fmt.comptimePrint("{}", .{i}),
                };
                i += 1;
            }
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
