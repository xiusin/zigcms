//! 用户资料数据传输对象

const std = @import("std");

/// 用户资料 DTO
pub const UserProfileDto = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    nickname: []const u8 = "",
    email: []const u8 = "",
    phone: []const u8 = "",
    avatar: []const u8 = "",
    gender: i32 = 0,
    birthday: []const u8 = "",
    bio: []const u8 = "",
};
