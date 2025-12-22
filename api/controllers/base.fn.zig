//! 控制器基础函数模块 (Base Functions)
//!
//! 提供控制器通用的响应处理函数，简化 HTTP 响应的构建。
//!
//! ## 功能
//! - `send_ok`: 发送成功响应
//! - `send_failed`: 发送失败响应
//! - `send_error`: 发送错误响应（包含详细错误信息）
//! - `send_layui_table_response`: 发送 LayUI 表格格式响应
//!
//! ## 使用示例
//! ```zig
//! const base = @import("base.fn.zig");
//!
//! // 成功响应
//! base.send_ok(req, .{ .id = 1, .name = "test" });
//!
//! // 失败响应
//! base.send_failed(req, "参数错误");
//!
//! // 错误响应
//! base.send_error(req, error.DatabaseError);
//! ```

// 标准库
const std = @import("std");
const Allocator = std.mem.Allocator;

// 第三方库
const zap = @import("zap");

// 项目内部模块
const logger = @import("../../application/services/logger/logger.zig");
const global = @import("../../shared/primitives/global.zig");
const strings = @import("../../shared/utils/strings.zig");
const json_mod = @import("../../application/services/json/json.zig");
const sql_errors = @import("../../application/services/sql/sql_errors.zig");

pub const Response = struct {
    code: u32 = 0,
    count: ?u32 = null,
    msg: ?[]const u8 = null,
    data: *void = null,
};

/// 响应异常信息
pub fn send_error(req: zap.Request, e: anyerror) void {
    // 检查是否有详细的 SQL 错误信息
    const sql_err = sql_errors.getLastError();
    if (sql_err) |detail| {
        // 构建详细错误响应
        const error_msg = std.fmt.allocPrint(global.get_allocator(), "数据库操作失败: {s}", .{detail.message()}) catch {
            // 如果内存分配失败，回退到简单错误
            var buf: [40960]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{}", .{e}) catch return req.sendError(e, null, 500);
            return send_failed(req, msg[6..]);
        };
        defer global.get_allocator().free(error_msg);

        // 构建结构化的错误响应
        const response = .{
            .success = false,
            .code = detail.getCode() orelse 500,
            .message = error_msg,
            .data = .{
                .sql_error = detail.message(),
                .native_error = detail.getNativeMessage() orelse null,
                .sql_statement = detail.getSql() orelse null,
                .table_name = detail.table_name orelse null,
                .duration_ms = detail.duration_ms orelse null,
                .retryable = detail.retryable,
                .error_type = "sql_error",
            },
        };

        // 发送 JSON 响应
        const json = json_mod.JSON.encode(global.get_allocator(), response) catch {
            // 如果 JSON 编码失败，回退到简单错误
            var buf: [40960]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{}", .{e}) catch return req.sendError(e, null, 500);
            return send_failed(req, msg[6..]);
        };
        defer global.get_allocator().free(json);

        req.setStatus(.internal_server_error);
        req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
        req.sendBody(json) catch {};

        // 同时打印到日志
        logger.err("SQL错误详情: {s}", .{detail.format(global.get_allocator()) catch "格式化错误失败"});
        return;
    }

    // 普通错误处理
    var buf: [40960]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{}", .{e}) catch return req.sendError(e, null, 500);
    send_failed(req, msg[6..]);
}

/// 响应成功消息
pub fn send_ok(req: zap.Request, v: anytype) void {
    const ser = json_mod.JSON.encode(global.get_allocator(), .{
        .code = 0,
        .msg = "操作成功",
        .data = v,
    }) catch |e| return send_error(req, e);
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

/// 响应前端table结构（标准格式）
pub fn send_layui_table_response(req: zap.Request, v: anytype, count: u64, extra: anytype) void {
    const ser = json_mod.JSON.encode(global.get_allocator(), .{
        .code = 0,
        .count = count,
        .msg = "获取列表成功",
        .data = v,
        .extra = extra,
    }) catch |e| return send_error(req, e);
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

/// 响应前端table结构（自定义数据格式）
pub fn send_layui_table_custom(allocator: Allocator, response: zap.Response, data: std.StringHashMap(json_mod.Value)) !void {
    const ser = json_mod.JSON.encode(allocator, data) catch |e| return send_error(response, e);
    defer allocator.free(ser);
    response.sendJson(ser) catch return;
}

/// 响应失败消息
pub fn send_failed(req: zap.Request, message: []const u8) void {
    const ser = json_mod.JSON.encode(global.get_allocator(), .{
        .code = 500,
        .msg = message,
    }) catch return;
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

/// 获取请求中的排序字段
pub fn get_sort_field(str: ?[]const u8) ?[]const u8 {
    if (str) |field| {
        if (strings.starts_with(field, "sort[") and strings.ends_with(field, "]")) {
            return field[5 .. field.len - 1];
        }
    }
    return str;
}
