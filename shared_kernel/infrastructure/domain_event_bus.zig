//! 领域事件总线 (Domain Event Bus)
//!
//! 实现领域事件的发布/订阅机制，支持同步和异步事件处理。

const std = @import("std");
const DomainEvent = @import("../../shared_kernel/patterns/domain_event.zig").DomainEvent;

/// 领域事件处理函数类型
pub fn DomainEventHandlerFunc(comptime EventType: type) type {
    return fn (event: EventType) void;
}

/// 领域事件处理器接口
pub const DomainEventHandler = struct {
    allocator: std.mem.Allocator,
    event_type: []const u8,
    callback: *const fn (event: *anyopaque) void,

    pub fn init(
        allocator: std.mem.Allocator,
        event_type: []const u8,
        callback: *const fn (event: *anyopaque) void,
    ) DomainEventHandler {
        return .{
            .allocator = allocator,
            .event_type = event_type,
            .callback = callback,
        };
    }

    pub fn deinit(self: *DomainEventHandler) void {
        self.allocator.free(self.event_type);
    }
};

/// 领域事件总线接口
pub const DomainEventBus = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(std.ArrayListUnmanaged(*DomainEventHandler)),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) DomainEventBus {
        return .{
            .allocator = allocator,
            .handlers = std.StringHashMap(std.ArrayListUnmanaged(*DomainEventHandler)).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *DomainEventBus) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |*handler| {
                handler.deinit();
                self.allocator.destroy(handler);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.handlers.deinit();
    }

    /// 订阅领域事件
    pub fn subscribe(
        self: *DomainEventBus,
        event_type: []const u8,
        handler: *DomainEventHandler,
    ) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const event_type_copy = try self.allocator.dupe(u8, event_type);
        errdefer self.allocator.free(event_type_copy);

        const result = try self.handlers.getOrPut(event_type_copy);
        if (!result.found_existing) {
            result.value_ptr.* = .{};
        }

        try result.value_ptr.append(self.allocator, handler);
        std.log.debug("Handler subscribed to domain event '{s}'", .{event_type});
    }

    /// 发布领域事件（同步处理）
    pub fn publish(self: *DomainEventBus, event: *anyopaque, event_type: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.handlers.get(event_type)) |handlers| {
            std.log.debug("Publishing domain event '{s}' to {d} handlers", .{
                event_type,
                handlers.items.len,
            });

            for (handlers.items) |handler| {
                handler.callback(event);
            }
        }
    }

    /// 获取事件处理器数量
    pub fn getHandlerCount(self: *DomainEventBus, event_type: []const u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.handlers.get(event_type)) |handlers| {
            return handlers.items.len;
        }
        return 0;
    }

    /// 获取所有已注册的事件类型
    pub fn getRegisteredEventTypes(self: *DomainEventBus, allocator: std.mem.Allocator) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var types = std.ArrayList([]const u8).init(allocator);
        defer types.deinit();

        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            try types.append(entry.key_ptr.*);
        }

        return types.toOwnedSlice();
    }
};

/// 事件发布者 trait - 聚合根实现此接口以支持事件发布
pub const EventPublisher = struct {
    publishFn: *const fn (self: *anyopaque, event: *anyopaque, event_type: []const u8) void,

    pub fn publish(self: *anyopaque, comptime EventType: type, event: EventType) void {
        const ptr = @as(*EventPublisher, @ptrCast(@alignCast(self)));
        ptr.publishFn(self, event, EventType.metadata.event_type);
    }
};

test "DomainEventBus subscribe and publish" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var event_bus = DomainEventBus.init(allocator);
    defer event_bus.deinit();

    var received_events = std.ArrayList(bool).init(allocator);
    defer received_events.deinit();

    const TestEvent = struct {
        value: i32,
    };

    const callback = struct {
        fn callback(event: *anyopaque) void {
            _ = event;
        }
    }.callback;

    const handler = try allocator.create(DomainEventHandler);
    handler.* = DomainEventHandler.init(allocator, "TestEvent", callback);

    try event_bus.subscribe("TestEvent", handler);
    try std.testing.expectEqual(@as(usize, 1), event_bus.getHandlerCount("TestEvent"));

    event_bus.publish(undefined, "TestEvent");
    try std.testing.expectEqual(@as(usize, 1), event_bus.getHandlerCount("TestEvent"));

    handler.deinit();
    allocator.destroy(handler);
}
