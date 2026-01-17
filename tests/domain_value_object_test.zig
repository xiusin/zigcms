//! 值对象测试 (Value Object Tests)
//!
//! 测试 Email 和 Username 值对象的创建和验证逻辑。

const std = @import("std");
const testing = std.testing;
const Email = @import("../domain/entities/value_objects/email.zig").Email;
const Username = @import("../domain/entities/value_objects/username.zig").Username;

// ============================================================================
// Email 值对象测试
// ============================================================================

test "Email.create - valid email" {
    const email = try Email.create("user@example.com", testing.allocator);
    defer email.deinit(testing.allocator);

    try testing.expectEqualStrings("user@example.com", email.value);
}

test "Email.create - invalid email - missing @" {
    const result = Email.create("userexample.com", testing.allocator);
    try testing.expectError(error.InvalidEmailFormat, result);
}

test "Email.create - invalid email - missing domain" {
    const result = Email.create("user@", testing.allocator);
    try testing.expectError(error.InvalidEmailFormat, result);
}

test "Email.create - invalid email - empty" {
    const result = Email.create("", testing.allocator);
    try testing.expectError(error.EmailRequired, result);
}

test "Email.create - invalid email - starts with @" {
    const result = Email.create("@example.com", testing.allocator);
    try testing.expectError(error.InvalidEmailFormat, result);
}

test "Email.create - invalid email - ends with ." {
    const result = Email.create("user@example.", testing.allocator);
    try testing.expectError(error.InvalidEmailFormat, result);
}

test "Email.create - multiple @" {
    const result = Email.create("user@@example.com", testing.allocator);
    try testing.expectError(error.InvalidEmailFormat, result);
}

test "Email.create - special characters" {
    // 邮箱允许的特殊字符
    const email = try Email.create("user.name+tag@example.co.uk", testing.allocator);
    defer email.deinit(testing.allocator);
    try testing.expectEqualStrings("user.name+tag@example.co.uk", email.value);
}

test "Email.equals - same email" {
    const email1 = try Email.create("user@example.com", testing.allocator);
    defer email1.deinit(testing.allocator);

    const email2 = try Email.create("user@example.com", testing.allocator);
    defer email2.deinit(testing.allocator);

    try testing.expect(email1.equals(email2));
}

test "Email.equals - different email" {
    const email1 = try Email.create("user1@example.com", testing.allocator);
    defer email1.deinit(testing.allocator);

    const email2 = try Email.create("user2@example.com", testing.allocator);
    defer email2.deinit(testing.allocator);

    try testing.expect(!email1.equals(email2));
}

test "Email.equals - case sensitivity" {
    const email1 = try Email.create("User@Example.com", testing.allocator);
    defer email1.deinit(testing.allocator);

    const email2 = try Email.create("user@example.com", testing.allocator);
    defer email2.deinit(testing.allocator);

    // 邮箱应该区分大小写
    try testing.expect(!email1.equals(email2));
}

// ============================================================================
// Username 值对象测试
// ============================================================================

test "Username.create - valid username" {
    const username = try Username.create("john_doe123", testing.allocator);
    defer username.deinit(testing.allocator);

    try testing.expectEqualStrings("john_doe123", username.value);
}

test "Username.create - too short" {
    const result = Username.create("ab", testing.allocator);
    try testing.expectError(error.UsernameTooShort, result);
}

test "Username.create - too long" {
    const long_name = "a" ** 51;
    const result = Username.create(long_name, testing.allocator);
    try testing.expectError(error.UsernameTooLong, result);
}

test "Username.create - invalid characters - space" {
    const result = Username.create("john doe", testing.allocator);
    try testing.expectError(error.InvalidUsernameCharacter, result);
}

test "Username.create - invalid characters - special" {
    const result = Username.create("john@doe", testing.allocator);
    try testing.expectError(error.InvalidUsernameCharacter, result);
}

test "Username.create - valid - underscore only" {
    const username = try Username.create("_____", testing.allocator);
    defer username.deinit(testing.allocator);
    try testing.expectEqualStrings("_____", username.value);
}

test "Username.create - valid - numbers only" {
    const username = try Username.create("12345", testing.allocator);
    defer username.deinit(testing.allocator);
    try testing.expectEqualStrings("12345", username.value);
}

test "Username.create - valid - mixed case" {
    const username = try Username.create("JohnDoe123", testing.allocator);
    defer username.deinit(testing.allocator);
    try testing.expectEqualStrings("JohnDoe123", username.value);
}

test "Username.equals - same username" {
    const username1 = try Username.create("john_doe", testing.allocator);
    defer username1.deinit(testing.allocator);

    const username2 = try Username.create("john_doe", testing.allocator);
    defer username2.deinit(testing.allocator);

    try testing.expect(username1.equals(username2));
}

test "Username.equals - different username" {
    const username1 = try Username.create("john_doe", testing.allocator);
    defer username1.deinit(testing.allocator);

    const username2 = try Username.create("jane_doe", testing.allocator);
    defer username2.deinit(testing.allocator);

    try testing.expect(!username1.equals(username2));
}

test "Username.length - boundary" {
    // 最小长度测试
    const min_name = "ab";
    const result1 = Username.create(min_name, testing.allocator);
    try testing.expectError(error.UsernameTooShort, result1);

    // 刚好最小长度
    const min_ok = "abc";
    const username1 = try Username.create(min_ok, testing.allocator);
    defer username1.deinit(testing.allocator);

    // 最大长度测试
    const max_name = "a" ** 50;
    const username2 = try Username.create(max_name, testing.allocator);
    defer username2.deinit(testing.allocator);

    // 超过最大长度
    const max_error = "a" ** 51;
    const result2 = Username.create(max_error, testing.allocator);
    try testing.expectError(error.UsernameTooLong, result2);
}
