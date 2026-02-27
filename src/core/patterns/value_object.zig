//! 值对象模式 (Value Object Pattern)
//!
//! 值对象是通过其属性值来定义的对象，没有唯一标识。
//! 值对象是不可变的，相等性由属性值决定。

const std = @import("std");

/// 值对象生成器
pub fn ValueObject(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        /// 创建值对象
        pub fn create(value: T) Self {
            return .{ .value = value };
        }

        /// 判断是否相等
        pub fn equals(self: Self, other: Self) bool {
            return std.meta.eql(self.value, other.value);
        }

        /// 获取值
        pub fn get(self: Self) T {
            return self.value;
        }
    };
}

/// 常用验证函数
pub const Validators = struct {
    /// 验证非空
    pub fn notEmpty(s: []const u8) bool {
        return s.len > 0;
    }

    /// 验证长度范围
    pub fn lengthBetween(s: []const u8, min: usize, max: usize) bool {
        return s.len >= min and s.len <= max;
    }

    /// 验证正数
    pub fn positive(comptime T: type, n: T) bool {
        return n > 0;
    }

    /// 验证非负数
    pub fn nonNegative(comptime T: type, n: T) bool {
        return n >= 0;
    }

    /// 验证范围
    pub fn inRange(comptime T: type, n: T, min: T, max: T) bool {
        return n >= min and n <= max;
    }
};
