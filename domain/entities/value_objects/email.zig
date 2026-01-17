//! 邮箱值对象 (Email Value Object)
//!
//! 邮箱是用户实体的一个重要属性，使用值对象封装可以确保：
//! - 邮箱格式的正确性
//! - 邮箱的不变性（创建后不可修改）
//! - 值的相等性比较

const std = @import("std");
const ValueObject = @import("../../../shared_kernel/patterns/value_object.zig").ValueObject;

/// 邮箱值对象
pub const Email = ValueObject([]const u8);

/// 验证邮箱格式
pub fn validateEmail(value: []const u8) !void {
    if (value.len == 0) {
        return error.EmailRequired;
    }

    // 简单的邮箱格式验证
    const at_pos = std.mem.indexOf(u8, value, "@") orelse {
        return error.InvalidEmailFormat;
    };

    const dot_pos = std.mem.lastIndexOf(u8, value, ".") orelse {
        return error.InvalidEmailFormat;
    };

    if (at_pos == 0 or dot_pos <= at_pos + 1 or dot_pos == value.len - 1) {
        return error.InvalidEmailFormat;
    }
}

/// 便捷创建方法
pub fn createEmail(value: []const u8) !Email {
    return Email.create(value, validateEmail);
}

/// 邮箱值对象错误
pub const EmailError = error{
    EmailRequired,
    InvalidEmailFormat,
};
