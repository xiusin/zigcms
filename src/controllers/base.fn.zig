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
