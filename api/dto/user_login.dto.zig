//! 用户登录数据传输对象

const std = @import("std");

/// 用户登录 DTO
pub const UserLoginDto = struct {
    username: []const u8 = "",
    password: []const u8 = "",
    captcha: []const u8 = "",
    captcha_key: []const u8 = "",
    remember: bool = false,
};
