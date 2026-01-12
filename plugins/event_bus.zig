const std = @import("std");

pub const Event = struct {
    type: []const u8,
    source: []const u8,
    data: ?*anyopaque = null,
    timestamp: i64,

    pub fn init(event_type: []const u8, source: []const u8) Event {
        return .{
            .type = event_type,
            .source = source,
            .timestamp = std.time.timestamp(),
        };
    }
};

pub const EventHandler = struct {
    plugin_id: []const u8,
    callback: *const fn (event: Event) void,
};

pub const EventBus = struct {
    allocator: std.mem.Allocator,
    subscribers: std.StringHashMap(std.ArrayListUnmanaged(EventHandler)),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) EventBus {
        return .{
            .allocator = allocator,
            .subscribers = std.StringHashMap(std.ArrayListUnmanaged(EventHandler)).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *EventBus) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.subscribers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.subscribers.deinit();
    }

    pub fn subscribe(self: *EventBus, event_type: []const u8, handler: EventHandler) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const event_type_copy = try self.allocator.dupe(u8, event_type);
        errdefer self.allocator.free(event_type_copy);

        const result = try self.subscribers.getOrPut(event_type_copy);
        if (!result.found_existing) {
            result.value_ptr.* = .{};
        }

        const handler_copy = EventHandler{
            .plugin_id = try self.allocator.dupe(u8, handler.plugin_id),
            .callback = handler.callback,
        };

        try result.value_ptr.append(self.allocator, handler_copy);

        std.log.info("Plugin '{s}' subscribed to event '{s}'", .{ handler.plugin_id, event_type });
    }

    pub fn unsubscribe(self: *EventBus, event_type: []const u8, plugin_id: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.subscribers.getPtr(event_type)) |handlers| {
            var i: usize = 0;
            while (i < handlers.items.len) {
                if (std.mem.eql(u8, handlers.items[i].plugin_id, plugin_id)) {
                    const handler = handlers.orderedRemove(i);
                    self.allocator.free(handler.plugin_id);
                    std.log.info("Plugin '{s}' unsubscribed from event '{s}'", .{ plugin_id, event_type });
                } else {
                    i += 1;
                }
            }
            
            if (handlers.items.len == 0) {
                if (self.subscribers.fetchRemove(event_type)) |kv| {
                    self.allocator.free(kv.key);
                    var list = kv.value;
                    list.deinit(self.allocator);
                }
            }
        }
    }

    pub fn unsubscribeAll(self: *EventBus, plugin_id: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var to_remove = std.ArrayListUnmanaged([]const u8){};
        defer to_remove.deinit(self.allocator);

        var iter = self.subscribers.iterator();
        while (iter.next()) |entry| {
            var handlers = entry.value_ptr;
            var i: usize = 0;
            while (i < handlers.items.len) {
                if (std.mem.eql(u8, handlers.items[i].plugin_id, plugin_id)) {
                    const handler = handlers.orderedRemove(i);
                    self.allocator.free(handler.plugin_id);
                } else {
                    i += 1;
                }
            }
            
            if (handlers.items.len == 0) {
                try to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }

        for (to_remove.items) |key| {
            if (self.subscribers.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
                var list = kv.value;
                list.deinit(self.allocator);
            }
        }

        std.log.info("Plugin '{s}' unsubscribed from all events", .{plugin_id});
    }

    pub fn publish(self: *EventBus, event: Event) !void {
        self.mutex.lock();
        var handlers_opt = if (self.subscribers.get(event.type)) |handlers|
            try handlers.clone(self.allocator)
        else
            null;
        self.mutex.unlock();

        if (handlers_opt) |*handlers| {
            defer handlers.deinit(self.allocator);

            std.log.debug("Publishing event '{s}' from '{s}' to {d} subscribers", .{
                event.type,
                event.source,
                handlers.items.len,
            });

            for (handlers.items) |handler| {
                handler.callback(event);
            }
        }
    }

    pub fn getSubscriberCount(self: *EventBus, event_type: []const u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.subscribers.get(event_type)) |handlers| {
            return handlers.items.len;
        }
        return 0;
    }
};

test "EventBus subscribe and publish" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var event_bus = EventBus.init(allocator);
    defer event_bus.deinit();

    const TestCallback = struct {
        fn callback(event: Event) void {
            _ = event;
        }
    };

    const handler = EventHandler{
        .plugin_id = "test_plugin",
        .callback = TestCallback.callback,
    };

    try event_bus.subscribe("test.event", handler);
    try std.testing.expectEqual(@as(usize, 1), event_bus.getSubscriberCount("test.event"));

    const event = Event.init("test.event", "test_source");
    try event_bus.publish(event);

    try event_bus.unsubscribe("test.event", "test_plugin");
    try std.testing.expectEqual(@as(usize, 0), event_bus.getSubscriberCount("test.event"));
}

test "EventBus unsubscribeAll" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var event_bus = EventBus.init(allocator);
    defer event_bus.deinit();

    const TestCallback = struct {
        fn callback(event: Event) void {
            _ = event;
        }
    };

    const handler = EventHandler{
        .plugin_id = "test_plugin",
        .callback = TestCallback.callback,
    };

    try event_bus.subscribe("event1", handler);
    try event_bus.subscribe("event2", handler);

    try std.testing.expectEqual(@as(usize, 1), event_bus.getSubscriberCount("event1"));
    try std.testing.expectEqual(@as(usize, 1), event_bus.getSubscriberCount("event2"));

    try event_bus.unsubscribeAll("test_plugin");

    try std.testing.expectEqual(@as(usize, 0), event_bus.getSubscriberCount("event1"));
    try std.testing.expectEqual(@as(usize, 0), event_bus.getSubscriberCount("event2"));
}
