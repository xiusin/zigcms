//! 用户注册数据传输对象

const std = @import("std");
const core_io = @import("../../core/io.zig");

/// 用户注册 DTO
pub const UserRegisterDto = struct {
    username: []const u8 = "",
    password: []const u8 = "",
    confirm_password: []const u8 = "",
    email: []const u8 = "",
    phone: []const u8 = "",
    captcha: []const u8 = "",
    captcha_key: []const u8 = "",
};
