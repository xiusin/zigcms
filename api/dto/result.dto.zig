//! 响应结果数据传输对象

const std = @import("std");

/// 响应结果 DTO
pub const ResultDto = struct {
    code: i32 = 0,
    msg: []const u8 = "success",
    data: ?*anyopaque = null,
};
