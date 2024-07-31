const zap = @import("zap");
const json = @import("json");
const std = @import("std");

// send_error 响应异常信息
pub fn send_error(req: zap.Request, e: anyerror) void {
    req.sendError(
        e,
        if (@errorReturnTrace()) |t| t.* else null,
        505,
    );
}

//  send_ok 响应成功消息
pub fn send_ok(allocator: std.mem.Allocator, req: zap.Request, v: anytype) void {
    const ser = json.toSlice(allocator, .{
        .code = 0,
        .msg = "ok",
        .data = v,
    }) catch return;
    defer allocator.free(ser);
    req.sendJson(ser) catch return;
}

// send_failed 响应失败消息
pub fn send_failed(allocator: std.mem.Allocator, req: zap.Request, message: []const u8) void {
    const ser = json.toSlice(allocator, .{
        .code = 0,
        .msg = message,
    }) catch return;
    defer allocator.free(ser);
    req.sendJson(ser) catch return;
}

pub fn build_insert_sql(comptime T: type, allocator: std.mem.Allocator) []const u8 {
    var fields = std.ArrayList([]const u8).init(allocator);
    defer fields.deinit();
    var values = std.ArrayList([]const u8).init(allocator);
    defer values.deinit();

    inline for (std.meta.fields(T), 0..) |field, index| {
        fields.append(field.name) or {};
        values.append(std.fmt.allocPrint(allocator, "${d}", .{index + 1})) or {};
    }

    return std.fmt.allocPrint(allocator, "INSERT INTO {s} ({s}) VALUES ({s})", .{
        @typeName(T),
        std.mem.join(allocator, ",", fields.items),
        std.mem.join(allocator, ",", values.items),
    }) catch "";
}
