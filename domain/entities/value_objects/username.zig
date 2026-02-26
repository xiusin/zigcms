//! 用户名值对象 (Username Value Object)
//!
//! 用户名是用户实体的重要标识，使用值对象封装可以确保：
//! - 用户名长度和字符的合法性
//! - 用户名的不变性
//! - 值的相等性比较

const std = @import("std");
const ValueObject = @import("../../../shared_kernel/patterns/value_object.zig").ValueObject;

/// 用户名值对象
pub const Username = ValueObject([]const u8);

/// 验证用户名格式
pub fn validateUsername(value: []const u8) !void {
    if (value.len < 3) {
        return error.UsernameTooShort;
    }
    if (value.len > 20) {
        return error.UsernameTooLong;
    }

    // 只允许字母、数字和下划线
    for (value) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return error.InvalidUsernameCharacter;
        }
    }
}

/// 便捷创建方法
pub fn createUsername(value: []const u8) !Username {
    return Username.create(value, validateUsername);
}

/// 用户名值对象错误
pub const UsernameError = error{
    UsernameTooShort,
    UsernameTooLong,
    InvalidUsernameCharacter,
};
