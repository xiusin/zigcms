//! 领域事件总线测试 (Domain Event Bus Tests)
//!
//! 测试领域事件的发布/订阅机制。

const std = @import("std");
const testing = std.testing;
const DomainEvent = @import("../shared_kernel/patterns/domain_event.zig").DomainEvent;
const DomainEventBus = @import("../shared_kernel/infrastructure/domain_event_bus.zig").DomainEventBus;
const UserCreated = @import("../domain/events/user_events.zig").UserCreated;
const UserActivated = @import("../domain/events/user_events.zig").UserActivated;

// ============================================================================
// DomainEventBus 测试
// ============================================================================

test "DomainEventBus - init and deinit" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    try testing.expect(event_bus.handlers.count() == 0);
}

test "DomainEventBus - subscribe handler" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    const callback = struct {
        fn callback(event: *anyopaque) void {
            _ = event;
        }
    }.callback;

    const handler = try allocator.create(DomainEventHandler);
    handler.* = DomainEventHandler.init(allocator, "TestEvent", callback);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try event_bus.subscribe("TestEvent", handler);
    try testing.expectEqual(@as(usize, 1), event_bus.getHandlerCount("TestEvent"));
}

test "DomainEventBus - multiple handlers for same event" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    const callback = struct {
        fn callback(event: *anyopaque) void {
            _ = event;
        }
    }.callback;

    var handler1 = try allocator.create(DomainEventHandler);
    handler1.* = DomainEventHandler.init(allocator, "MultiEvent", callback);
    defer {
        handler1.deinit();
        allocator.destroy(handler1);
    }

    var handler2 = try allocator.create(DomainEventHandler);
    handler2.* = DomainEventHandler.init(allocator, "MultiEvent", callback);
    defer {
        handler2.deinit();
        allocator.destroy(handler2);
    }

    try event_bus.subscribe("MultiEvent", handler1);
    try event_bus.subscribe("MultiEvent", handler2);

    try testing.expectEqual(@as(usize, 2), event_bus.getHandlerCount("MultiEvent"));
}

test "DomainEventBus - publish to no handlers" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    // 发布到不存在的处理器应该是静默的
    event_bus.publish(undefined, "NonExistentEvent");
    try testing.expect(true); // 没有panic就是成功
}

test "DomainEventBus - getHandlerCount returns 0 for unknown event" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    try testing.expectEqual(@as(usize, 0), event_bus.getHandlerCount("UnknownEvent"));
}

test "DomainEventBus - getRegisteredEventTypes" {
    const allocator = testing.allocator;

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    const callback = struct {
        fn callback(event: *anyopaque) void {
            _ = event;
        }
    }.callback;

    var handler1 = try allocator.create(DomainEventHandler);
    handler1.* = DomainEventHandler.init(allocator, "Event1", callback);
    defer {
        handler1.deinit();
        allocator.destroy(handler1);
    }

    var handler2 = try allocator.create(DomainEventHandler);
    handler2.* = DomainEventHandler.init(allocator, "Event2", callback);
    defer {
        handler2.deinit();
        allocator.destroy(handler2);
    }

    try event_bus.subscribe("Event1", handler1);
    try event_bus.subscribe("Event2", handler2);

    const types = try event_bus.getRegisteredEventTypes(allocator);
    defer allocator.free(types);

    try testing.expectEqual(@as(usize, 2), types.len);
}

// ============================================================================
// DomainEvent 工厂测试
// ============================================================================

test "DomainEvent - UserCreated event creation" {
    const allocator = testing.allocator;

    const event = try UserCreated.createSimple(allocator, "user.created", .{
        .user_id = 1,
        .username = "testuser",
        .email = "test@example.com",
        .created_at = 1234567890,
    });
    defer event.deinit(allocator);

    try testing.expectEqualStrings("user.created", event.metadata.event_type);
    try testing.expectEqual(@as(i32, 1), event.payload.user_id);
    try testing.expectEqualStrings("testuser", event.payload.username);
}

test "DomainEvent - UserActivated event creation" {
    const allocator = testing.allocator;

    const event = try UserActivated.createSimple(allocator, "user.activated", .{
        .user_id = 1,
        .activated_at = 1234567890,
    });
    defer event.deinit(allocator);

    try testing.expectEqualStrings("user.activated", event.metadata.event_type);
    try testing.expectEqual(@as(i32, 1), event.payload.user_id);
}

test "DomainEvent - event with metadata" {
    const allocator = testing.allocator;

    const event = try UserCreated.createSimple(allocator, "user.created", .{
        .user_id = 1,
        .username = "testuser",
        .email = "test@example.com",
        .created_at = 1234567890,
    });
    defer event.deinit(allocator);

    // 验证元数据
    try testing.expect(event.metadata.occurred_on > 0);
    try testing.expectEqual(@as(u32, 0), event.metadata.version);
}
