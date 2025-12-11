//! 设置保存数据传输对象

const std = @import("std");

/// 设置保存 DTO
pub const SettingSaveDto = struct {
    key: []const u8 = "",
    value: []const u8 = "",
    group: []const u8 = "default",
    remark: []const u8 = "",
};
