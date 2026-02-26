//! 聚合根测试 (Aggregate Root Tests)
//!
//! 测试 User 聚合根的创建、验证和事件处理。

const std = @import("std");
const testing = std.testing;
const User = @import("../domain/entities/user.model.zig").User;
const UserData = @import("../domain/entities/user.model.zig").UserData;
const UserStatus = @import("../domain/entities/user.model.zig").UserStatus;
const UserCreated = @import("../domain/events/user_events.zig").UserCreated;
const AggregateRoot = @import("../shared_kernel/patterns/aggregate_root.zig").AggregateRoot;

// ============================================================================
// User 聚合根测试
// ============================================================================

test "User.create - valid user" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    try testing.expect(user.data.id == null);
    try testing.expectEqualStrings("testuser", user.data.username);
    try testing.expectEqualStrings("test@example.com", user.data.email);
    try testing.expectEqualStrings("Test User", user.data.nickname);
    try testing.expect(user.data.status == .Active);
}

test "User.create - with events" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    // 检查是否产生了 UserCreated 事件
    const events = user.getUncommittedEvents();
    try testing.expect(events.len > 0);
}

test "User.activate - changes status" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    var user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    try testing.expect(user.data.status == .Active);

    // 禁用用户
    user.disable();
    try testing.expect(user.data.status == .Disabled);

    // 重新启用
    user.activate();
    try testing.expect(user.data.status == .Active);
}

test "User.getDisplayName - returns nickname" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    try testing.expectEqualStrings("Test User", user.getDisplayName());
}

test "User.getDisplayName - falls back to username" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    // 创建不带昵称的用户
    const user = try User.create(username.value, email.value, "", allocator);
    defer user.deinit(allocator);

    try testing.expectEqualStrings("testuser", user.getDisplayName());
}

test "User.getVersion - returns version" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    // 初始版本应该是0（创建事件还没发布）
    try testing.expectEqual(@as(u32, 0), user.getVersion());
}

test "User.getId - returns null for new user" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    try testing.expect(user.getId() == null);
}

test "User.isActive - active user" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    try testing.expect(user.isActive());
}

test "User.isActive - disabled user" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    var user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    user.disable();
    try testing.expect(!user.isActive());
}

test "User.getUncommittedEvents - returns events" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    const user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    const events = user.getUncommittedEvents();
    try testing.expect(events.len > 0);

    // 第一个事件应该是 UserCreated
    const first_event = events[0];
    const event_type = first_event.getEventType();
    try testing.expectEqualStrings("UserCreated", event_type);
}

test "User.markEventsCommitted - clears uncommitted events" {
    const allocator = testing.allocator;
    const email = try @import("../domain/entities/value_objects/email.zig").Email.create("test@example.com", allocator);
    defer email.deinit(allocator);

    const username = try @import("../domain/entities/value_objects/username.zig").Username.create("testuser", allocator);
    defer username.deinit(allocator);

    var user = try User.create(username.value, email.value, "Test User", allocator);
    defer user.deinit(allocator);

    // 初始有未提交事件
    var events = user.getUncommittedEvents();
    try testing.expect(events.len > 0);

    // 标记为已提交
    user.markEventsCommitted();

    // 现在应该没有未提交事件
    events = user.getUncommittedEvents();
    try testing.expect(events.len == 0);
}

// ============================================================================
// UserData 验证测试
// ============================================================================

test "UserData - create with valid data" {
    const user_data = UserData{
        .id = 1,
        .username = "testuser",
        .email = "test@example.com",
        .nickname = "Test User",
        .status = .Active,
        .avatar = "",
    };

    try testing.expectEqual(@as(i32, 1), user_data.id);
    try testing.expectEqualStrings("testuser", user_data.username);
    try testing.expect(user_data.status == .Active);
}

test "UserStatus - enum values" {
    try testing.expectEqual(@as(i32, 0), @intFromEnum(UserStatus.Disabled));
    try testing.expectEqual(@as(i32, 1), @intFromEnum(UserStatus.Active));
    try testing.expectEqual(@as(i32, 2), @intFromEnum(UserStatus.Locked));
}
