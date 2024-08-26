const std = @import("std");
const Allocator = std.mem.Allocator;
const pg = @import("pg");
const pretty = @import("pretty");
const models = @import("../models/models.zig");
const strings = @import("../modules/strings.zig");
const base = @import("../controllers/base.fn.zig");

var _allocator: Allocator = undefined;
var _pool: *pg.Pool = undefined;

pub const JwtTokenSecret = "this is a secret";
var init = std.once(init_some);

fn init_some() void {
    const password = std.process.getEnvVarOwned(_allocator, "DB_PASSWORD") catch unreachable;
    defer _allocator.free(password);

    var buf: [4096]u8 = undefined;
    @memcpy(buf[0..password.len], password);
    _pool = pg.Pool.init(_allocator, .{
        .size = 10,
        .connect = .{
            .port = 5432,
            .host = "124.222.103.232",
        },
        .auth = .{
            .username = "postgres",
            .database = "postgres",
            .application_name = "zigcms",
            .password = buf[0..password.len],
            .timeout = std.time.ms_per_s,
        },
    }) catch unreachable;
}

pub fn set_allocator(allocator: Allocator) void {
    _allocator = allocator;
    init.call();
}

pub fn get_allocator() Allocator {
    return _allocator;
}

pub fn get_pg_pool() *pg.Pool {
    return _pool;
}

pub fn sql_exec(sql: []const u8, values: anytype) !i64 {
    if (try get_pg_pool().exec(sql, values)) |result| {
        return result;
    }
    return error.@"sql执行错误";
}

pub fn get_setting(allocator: Allocator, key: []const u8) ![]const u8 {
    var pool = try get_pg_pool();
    const sql = strings.sprinf("SELECT * FROM {s}", .{base.get_table_name(models.Setting)});
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
    return error.@"无法找到配置";
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

/// 动态将结构体转换为对应字段数量的元组
pub inline fn struct_2_tuple(T: type) type {
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
