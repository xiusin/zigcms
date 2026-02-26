//! 领域事件测试 (Domain Event Tests)
//!
//! 测试领域事件的创建、序列化和反序列化。

const std = @import("std");
const testing = std.testing;
const DomainEvent = @import("../shared_kernel/patterns/domain_event.zig").DomainEvent;
const UserCreated = @import("../domain/events/user_events.zig").UserCreated;
const UserActivated = @import("../domain/events/user_events.zig").UserActivated;
const UserDisabled = @import("../domain/events/user_events.zig").UserDisabled;

// ============================================================================
// UserCreated 事件测试
// ============================================================================

test "UserCreated - create event" {
    const allocator = testing.allocator;

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    try testing.expectEqual(@as(i32, 1), event.payload.id);
    try testing.expectEqualStrings("test@example.com", event.payload.email);
}

test "UserCreated - event metadata" {
    const allocator = testing.allocator;

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    try testing.expect(event.metadata.occurred_on > 0);
    try testing.expectEqualStrings("UserCreated", event.metadata.event_type);
    try testing.expect(event.metadata.aggregate_id == null);
    try testing.expect(event.metadata.aggregate_type == null);
}

test "UserCreated - with aggregate info" {
    const allocator = testing.allocator;

    const event = try UserCreated.createWithAggregate(allocator, 1, "test@example.com", "User", "1");
    defer event.deinit(allocator);

    try testing.expectEqualStrings("User", event.metadata.aggregate_type.?);
    try testing.expectEqualStrings("1", event.metadata.aggregate_id.?);
}

test "UserCreated - getEventType" {
    const allocator = testing.allocator;

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    try testing.expectEqualStrings("UserCreated", event.getEventType());
}

// ============================================================================
// UserActivated 事件测试
// ============================================================================

test "UserActivated - create event" {
    const allocator = testing.allocator;

    const event = try UserActivated.create(allocator, 1);
    defer event.deinit(allocator);

    try testing.expectEqual(@as(i32, 1), event.payload.user_id);
}

test "UserActivated - event metadata" {
    const allocator = testing.allocator;

    const event = try UserActivated.create(allocator, 1);
    defer event.deinit(allocator);

    try testing.expect(event.metadata.occurred_on > 0);
    try testing.expectEqualStrings("UserActivated", event.metadata.event_type);
}

// ============================================================================
// UserDisabled 事件测试
// ============================================================================

test "UserDisabled - create event" {
    const allocator = testing.allocator;

    const event = try UserDisabled.create(allocator, 1, "Spam violation");
    defer event.deinit(allocator);

    try testing.expectEqual(@as(i32, 1), event.payload.user_id);
    try testing.expectEqualStrings("Spam violation", event.payload.reason);
}

test "UserDisabled - event metadata" {
    const allocator = testing.allocator;

    const event = try UserDisabled.create(allocator, 1, "Spam violation");
    defer event.deinit(allocator);

    try testing.expect(event.metadata.occurred_on > 0);
    try testing.expectEqualStrings("UserDisabled", event.metadata.event_type);
}

// ============================================================================
// DomainEvent 通用测试
// ============================================================================

test "DomainEvent - toJson serialization" {
    const allocator = testing.allocator;

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    const json_str = try event.toJson(allocator);
    defer allocator.free(json_str);

    // JSON 应该包含事件类型
    try testing.expect(std.mem.indexOf(u8, json_str, "UserCreated") != null);
}

test "DomainEvent - createSimple" {
    const allocator = testing.allocator;

    const event = try DomainEvent(struct { id: i32 }).createSimple(allocator, "TestEvent", .{.id = 42});
    defer event.deinit(allocator);

    try testing.expectEqualStrings("TestEvent", event.metadata.event_type);
}

test "DomainEvent - equality" {
    const allocator = testing.allocator;

    const event1 = try UserCreated.create(allocator, 1, "test@example.com");
    defer event1.deinit(allocator);

    const event2 = try UserCreated.create(allocator, 1, "test@example.com");
    defer event2.deinit(allocator);

    // 相同参数创建的事件应该相等
    try testing.expect(event1.equals(event2));
}

test "DomainEvent - inequality - different type" {
    const allocator = testing.allocator;

    const event1 = try UserCreated.create(allocator, 1, "test@example.com");
    defer event1.deinit(allocator);

    const event2 = try UserActivated.create(allocator, 1);
    defer event2.deinit(allocator);

    // 不同类型的事件不应该相等
    try testing.expect(!event1.equals(event2));
}

test "DomainEvent - inequality - different payload" {
    const allocator = testing.allocator;

    const event1 = try UserCreated.create(allocator, 1, "test1@example.com");
    defer event1.deinit(allocator);

    const event2 = try UserCreated.create(allocator, 2, "test2@example.com");
    defer event2.deinit(allocator);

    // payload 不同的事件不应该相等
    try testing.expect(!event1.equals(event2));
}

test "DomainEvent - metadata timestamp" {
    const allocator = testing.allocator;
    const before = std.time.timestamp();

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    const after = std.time.timestamp();

    try testing.expect(event.metadata.occurred_on >= before);
    try testing.expect(event.metadata.occurred_on <= after);
}

test "DomainEvent - version is zero" {
    const allocator = testing.allocator;

    const event = try UserCreated.create(allocator, 1, "test@example.com");
    defer event.deinit(allocator);

    try testing.expectEqual(@as(u32, 0), event.metadata.version);
}
