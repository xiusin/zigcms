//! 值对象模式 (Value Object Pattern)
//!
//! 值对象是一种不可变的领域对象，它通过其属性值来定义相等性，
//! 而不是通过标识符。值对象没有生命周期标识，不应该被单独追踪。
//!
//! ## 特性
//! - 不可变性：创建后不能修改
//! - 值相等性：相等的属性值意味着相等的对象
//! - 自验证性：在创建时验证所有约束
//!
//! ## 使用示例
//! ```zig
//! const Email = ValueObject([]const u8).create("user@example.com", validateEmail);
//!
//! // 验证失败时返回错误
//! const result = Email.create("invalid-email", validateEmail);
//! if (result) |email| {
//!     std.debug.print("Email: {s}\n", .{email.value});
//! } else |err| {
//!     std.debug.print("Invalid email: {}\n", .{err});
//! }
//! ```
//!
//! ## 与实体的区别
//! - 实体有唯一标识，相等性基于ID
//! - 值对象无标识，相等性基于属性值

const std = @import("std");

/// 值对象基类
///
/// ## 类型参数
/// - `T`: 值对象的底层类型（如 []const u8, i32 等）
///
/// ## 泛型约束
/// - `T` 必须是可比较的类型（支持 == 运算符）
pub fn ValueObject(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 值对象的实际值
        value: T,

        /// 验证函数类型
        pub const ValidateFn = fn (T) anyerror!void;

        /// 创建值对象
        ///
        /// ## 参数
        /// - `value`: 原始值
        /// - `validate_fn`: 验证函数（可选，如果不提供则不验证）
        ///
        /// ## 错误
        /// - 如果验证失败，返回相应的错误
        pub fn create(value: T, validate_fn: ?ValidateFn) !Self {
            if (validate_fn) |vf| {
                try vf(value);
            }
            return Self{ .value = value };
        }

        /// 创建一个不可验证的值对象（仅用于测试或已知有效的值）
        pub fn createUnchecked(value: T) Self {
            return Self{ .value = value };
        }

        /// 获取值对象的值
        pub fn getValue(self: Self) T {
            return self.value;
        }

        /// 比较两个值对象是否相等
        pub fn equals(self: Self, other: Self) bool {
            return std.meta.eql(self.value, other.value);
        }

        /// 获取值对象的字符串表示
        pub fn toString(self: Self, allocator: std.mem.Allocator) ![]u8 {
            if (comptime std.meta.trait.isZigString(T)) {
                return try allocator.dupe(u8, self.value);
            }
            return std.fmt.allocPrint(allocator, "{any}", .{self.value});
        }

        /// 检查值是否为默认值
        pub fn isDefault(self: Self) bool {
            return std.meta.eql(self.value, std.mem.zeroes(T));
        }
    };
}

/// 检查类型是否是值对象
pub fn isValueObject(comptime T: type) bool {
    // 检查是否有 value 字段
    if (!@hasField(T, "value")) return false;

    // 检查是否有 create 静态方法
    if (!@hasDecl(T, "create")) return false;

    // 检查是否有 equals 方法
    if (!@hasDecl(T, "equals")) return false;

    return true;
}

/// 便捷宏：定义一个简单的值对象类型
///
/// ## 使用示例
/// ```zig
/// // 定义 Email 值对象
/// const Email = DefineValueObject(.{
///     .name = "Email",
///     .UnderlyingType = []const u8,
///     .validate = validateEmailFn,
/// });
/// ```
pub fn DefineValueObject(comptime config: struct {
    name: []const u8,
    comptime UnderlyingType: type,
    validate: fn (UnderlyingType) anyerror!void,
}) type {
    _ = config.name;
    return struct {
        const Self = @This();
        pub usingnamespace ValueObject(UnderlyingType);

        /// 便捷创建方法
        pub fn new(value: UnderlyingType) !Self {
            return Self.create(value, config.validate);
        }
    };
}

/// 常用验证函数集合
pub const Validators = struct {
    /// 验证邮箱格式
    pub fn email(value: []const u8) !void {
        if (value.len == 0) return error.EmailRequired;

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

    /// 验证用户名格式（3-20位字母数字下划线）
    pub fn username(value: []const u8) !void {
        if (value.len < 3) return error.UsernameTooShort;
        if (value.len > 20) return error.UsernameTooLong;

        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                return error.InvalidUsernameCharacter;
            }
        }
    }

    /// 验证密码强度（至少6位，包含字母和数字）
    pub fn password(value: []const u8) !void {
        if (value.len < 6) return error.PasswordTooWeak;
        if (value.len > 50) return error.PasswordTooLong;

        var has_digit = false;
        var has_alpha = false;

        for (value) |c| {
            if (std.ascii.isDigit(c)) has_digit = true;
            if (std.ascii.isAlphabetic(c)) has_alpha = true;
        }

        if (!has_digit or !has_alpha) {
            return error.PasswordMustContainAlphaAndDigit;
        }
    }
};

// 错误类型
pub const ValueObjectError = error{
    ValidationFailed,
    EmailRequired,
    InvalidEmailFormat,
    UsernameTooShort,
    UsernameTooLong,
    InvalidUsernameCharacter,
    PasswordTooWeak,
    PasswordTooLong,
    PasswordMustContainAlphaAndDigit,
};
