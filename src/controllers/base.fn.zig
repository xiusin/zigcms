const zap = @import("zap");
const json = @import("json");
const std = @import("std");
const global = @import("../global/global.zig");
const Allocator = std.mem.Allocator;

pub const Response = struct {
    code: u32 = 0,
    count: ?u32 = null,
    msg: ?[]const u8 = null,
    data: *void = null,
};

// send_error 响应异常信息
pub fn send_error(req: zap.Request, e: anyerror) void {
    std.log.err("错误信息 = {?}", .{e});
    req.sendError(
        e,
        if (@errorReturnTrace()) |t| t.* else null,
        500,
    );
}

//  send_ok 响应成功消息
pub fn send_ok(req: zap.Request, v: anytype) void {
    const ser = json.toSlice(global.get_allocator(), .{
        .code = 0,
        .msg = "操作成功",
        .data = v,
    }) catch |e| return send_error(req, e);
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

//  send_response 响应成功消息
pub fn send_response(req: zap.Request, v: anytype, count: u64) void {
    const ser = json.toSlice(global.get_allocator(), .{
        .code = 0,
        .count = count,
        .msg = "获取列表成功",
        .data = v,
    }) catch |e| return send_error(req, e);
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

// send_failed 响应失败消息
pub fn send_failed(req: zap.Request, message: []const u8) void {
    const ser = json.toSlice(global.get_allocator(), .{
        .code = 500,
        .msg = message,
    }) catch return;
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

pub fn build_insert_sql(comptime T: type, allocator: Allocator) ![]const u8 {
    var fields = std.ArrayList([]const u8).init(allocator);
    defer fields.deinit();
    var values = std.ArrayList([]const u8).init(allocator);
    defer values.deinit();

    var index: usize = 0;
    inline for (std.meta.fields(T)) |field| {
        if (!std.mem.eql(u8, field.name, "id")) { // 忽略id字段
            try fields.append(field.name);
            var buf: [1024]u8 = undefined;
            try values.append(try std.fmt.bufPrint(buf[0..], "${d}", .{index + 1}));
            index += 1;
        }
    }
    var iter = std.mem.split(u8, @typeName(T), ".");
    var tablename: []const u8 = undefined;
    while (iter.next()) |v| {
        tablename = v;
    }
    const output: []u8 = undefined;
    const fields_arg = try std.mem.join(allocator, ", ", fields.items);
    const values_arg = try std.mem.join(allocator, ", ", values.items);
    defer allocator.free(fields_arg);
    defer allocator.free(values_arg);

    const query = "INSERT INTO zigcms.{s} ({s}) VALUES ({s})";
    return try std.fmt.allocPrint(allocator, query, .{
        std.ascii.lowerString(output, tablename),
        fields_arg,
        values_arg,
    });
}

// build_update_sql 构建更新sql语句, 仅支持简单语句生成
pub fn build_update_sql(comptime T: type, allocator: Allocator) ![]const u8 {
    var fields = std.ArrayList([]const u8).init(allocator);
    defer fields.deinit();

    var index: usize = 0;
    inline for (std.meta.fields(T)) |field| {
        if (!std.mem.eql(u8, field.name, "id")) { // 忽略id字段
            var buf: [1024]u8 = undefined;
            try fields.append(try std.fmt.bufPrint(buf[0..], "{s} = ${d}", .{ field.name, index + 1 }));
            index += 1;
        }
    }

    var iter = std.mem.split(u8, @typeName(T), ".");
    var tablename: []const u8 = undefined;
    while (iter.next()) |v| {
        tablename = v;
    }
    const output: []u8 = undefined;
    const low_tablename = std.ascii.lowerString(output, tablename);

    const fields_arg = try std.mem.join(allocator, ", ", fields.items);
    defer allocator.free(fields_arg);

    const query = "UPDATE zigcms.{s} SET {s} WHERE id = ${d}";
    return try std.fmt.allocPrint(allocator, query, .{ low_tablename, fields_arg, index + 1 });
}
