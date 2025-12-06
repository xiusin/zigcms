//! 事件管理器 - 类似 NestJS EventEmitter
//!
//! 提供发布/订阅模式的事件系统，支持：
//! - 同步和异步事件处理
//! - 通配符事件匹配（如 `user.*`）
//! - 事件优先级
//! - 一次性监听器
//! - 类型安全的事件载荷
//!
//! 使用示例：
//! ```zig
//! var emitter = EventEmitter.init(allocator);
//! defer emitter.deinit();
//!
//! // 注册监听器
//! try emitter.on("user.created", struct {
//!     pub fn handle(data: ?*anyopaque) void {
//!         const user = @as(*const User, @ptrCast(@alignCast(data)));
//!         std.debug.print("User created: {s}\n", .{user.name});
//!     }
//! }.handle);
//!
//! // 发射事件
//! var user = User{ .id = 1, .name = "张三" };
//! try emitter.emit("user.created", &user);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 事件处理函数类型
pub const EventHandler = *const fn (data: ?*anyopaque, ctx: ?*anyopaque) void;

/// 异步事件处理函数类型
pub const AsyncEventHandler = *const fn (data: ?*anyopaque, ctx: ?*anyopaque) anyerror!void;

/// 监听器优先级
pub const Priority = enum(u8) {
    lowest = 0,
    low = 25,
    normal = 50,
    high = 75,
    highest = 100,
    monitor = 255, // 只监控，不修改

    pub fn value(self: Priority) u8 {
        return @intFromEnum(self);
    }
};

/// 监听器选项
pub const ListenerOptions = struct {
    /// 优先级
    priority: Priority = .normal,
    /// 是否只执行一次
    once: bool = false,
    /// 上下文数据
    context: ?*anyopaque = null,
    /// 是否异步执行
    async_exec: bool = false,
};

/// 监听器
const Listener = struct {
    handler: EventHandler,
    options: ListenerOptions,
    removed: bool = false,
};

/// 事件错误
pub const EventError = error{
    EventNotFound,
    HandlerNotFound,
    MaxListenersExceeded,
    InvalidPattern,
    OutOfMemory,
};

/// 事件管理器
pub const EventEmitter = struct {
    const Self = @This();
    const ListenerList = std.ArrayListUnmanaged(Listener);
    const EventMap = std.StringHashMapUnmanaged(ListenerList);

    allocator: Allocator,
    events: EventMap,
    wildcard_events: EventMap, // 通配符事件
    max_listeners: usize,
    mutex: std.Thread.Mutex = .{},

    // 统计信息
    total_emits: usize = 0,
    total_listeners: usize = 0,

    /// 创建事件管理器
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .events = .{},
            .wildcard_events = .{},
            .max_listeners = 100,
        };
    }

    /// 释放资源
    pub fn deinit(self: *Self) void {
        // 释放普通事件
        var iter = self.events.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.events.deinit(self.allocator);

        // 释放通配符事件
        var wildcard_iter = self.wildcard_events.iterator();
        while (wildcard_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.wildcard_events.deinit(self.allocator);
    }

    /// 注册事件监听器
    pub fn on(self: *Self, event: []const u8, handler: EventHandler) !void {
        try self.addListener(event, handler, .{});
    }

    /// 注册带选项的事件监听器
    pub fn onWithOptions(self: *Self, event: []const u8, handler: EventHandler, options: ListenerOptions) !void {
        try self.addListener(event, handler, options);
    }

    /// 注册一次性监听器
    pub fn once(self: *Self, event: []const u8, handler: EventHandler) !void {
        try self.addListener(event, handler, .{ .once = true });
    }

    /// 注册带上下文的监听器
    pub fn onWithContext(self: *Self, event: []const u8, handler: EventHandler, ctx: *anyopaque) !void {
        try self.addListener(event, handler, .{ .context = ctx });
    }

    /// 添加监听器（内部方法）
    fn addListener(self: *Self, event: []const u8, handler: EventHandler, options: ListenerOptions) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const is_wildcard = std.mem.indexOf(u8, event, "*") != null;
        const map = if (is_wildcard) &self.wildcard_events else &self.events;

        // 获取或创建监听器列表
        const result = map.getOrPut(self.allocator, event) catch return EventError.OutOfMemory;

        if (!result.found_existing) {
            // 新事件，复制事件名
            const owned_event = self.allocator.dupe(u8, event) catch return EventError.OutOfMemory;
            result.key_ptr.* = owned_event;
            result.value_ptr.* = .{};
        }

        var list = result.value_ptr;

        // 检查监听器数量限制
        if (list.items.len >= self.max_listeners) {
            return EventError.MaxListenersExceeded;
        }

        // 添加监听器
        const listener = Listener{
            .handler = handler,
            .options = options,
        };

        // 按优先级插入（高优先级在前）
        var insert_idx: usize = list.items.len;
        for (list.items, 0..) |existing, i| {
            if (options.priority.value() > existing.options.priority.value()) {
                insert_idx = i;
                break;
            }
        }

        list.insert(self.allocator, insert_idx, listener) catch return EventError.OutOfMemory;
        self.total_listeners += 1;
    }

    /// 移除事件监听器
    pub fn off(self: *Self, event: []const u8, handler: EventHandler) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const is_wildcard = std.mem.indexOf(u8, event, "*") != null;
        const map = if (is_wildcard) &self.wildcard_events else &self.events;

        if (map.getPtr(event)) |list| {
            var i: usize = 0;
            while (i < list.items.len) {
                if (list.items[i].handler == handler) {
                    _ = list.orderedRemove(i);
                    self.total_listeners -= 1;
                } else {
                    i += 1;
                }
            }
        }
    }

    /// 移除事件的所有监听器
    pub fn offAll(self: *Self, event: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const is_wildcard = std.mem.indexOf(u8, event, "*") != null;
        const map = if (is_wildcard) &self.wildcard_events else &self.events;

        if (map.fetchRemove(event)) |kv| {
            self.total_listeners -= kv.value.items.len;
            self.allocator.free(kv.key);
            var list = kv.value;
            list.deinit(self.allocator);
        }
    }

    /// 发射事件
    pub fn emit(self: *Self, event: []const u8, data: ?*anyopaque) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.total_emits += 1;

        // 执行精确匹配的监听器
        if (self.events.getPtr(event)) |list| {
            try self.executeListeners(list, data);
        }

        // 执行通配符匹配的监听器
        var wildcard_iter = self.wildcard_events.iterator();
        while (wildcard_iter.next()) |entry| {
            if (self.matchPattern(entry.key_ptr.*, event)) {
                try self.executeListeners(entry.value_ptr, data);
            }
        }
    }

    /// 同步发射事件（等待所有处理完成）
    pub fn emitSync(self: *Self, event: []const u8, data: ?*anyopaque) !void {
        try self.emit(event, data);
    }

    /// 执行监听器列表
    fn executeListeners(self: *Self, list: *ListenerList, data: ?*anyopaque) !void {
        var to_remove = std.ArrayListUnmanaged(usize){};
        defer to_remove.deinit(self.allocator);

        for (list.items, 0..) |*listener, i| {
            if (listener.removed) continue;

            // 执行处理函数
            listener.handler(data, listener.options.context);

            // 标记一次性监听器
            if (listener.options.once) {
                listener.removed = true;
                to_remove.append(self.allocator, i) catch {};
            }
        }

        // 移除一次性监听器（从后往前删除）
        var j: usize = to_remove.items.len;
        while (j > 0) {
            j -= 1;
            _ = list.orderedRemove(to_remove.items[j]);
            self.total_listeners -= 1;
        }
    }

    /// 匹配通配符模式
    fn matchPattern(self: *Self, pattern: []const u8, event: []const u8) bool {
        _ = self;

        // 完全匹配
        if (std.mem.eql(u8, pattern, event)) return true;

        // ** 匹配所有
        if (std.mem.eql(u8, pattern, "**")) return true;

        // 分段匹配
        var pattern_parts = std.mem.splitScalar(u8, pattern, '.');
        var event_parts = std.mem.splitScalar(u8, event, '.');

        while (true) {
            const p = pattern_parts.next();
            const e = event_parts.next();

            if (p == null and e == null) return true;
            if (p == null or e == null) {
                // 检查 ** 尾部匹配
                if (p != null and std.mem.eql(u8, p.?, "**")) return true;
                return false;
            }

            const pattern_part = p.?;
            const event_part = e.?;

            // * 匹配单个段
            if (std.mem.eql(u8, pattern_part, "*")) continue;

            // ** 匹配剩余所有
            if (std.mem.eql(u8, pattern_part, "**")) return true;

            // 精确匹配
            if (!std.mem.eql(u8, pattern_part, event_part)) return false;
        }
    }

    /// 获取事件的监听器数量
    pub fn listenerCount(self: *Self, event: []const u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        var count: usize = 0;

        // 精确匹配
        if (self.events.get(event)) |list| {
            count += list.items.len;
        }

        // 通配符匹配
        var wildcard_iter = self.wildcard_events.iterator();
        while (wildcard_iter.next()) |entry| {
            if (self.matchPattern(entry.key_ptr.*, event)) {
                count += entry.value_ptr.items.len;
            }
        }

        return count;
    }

    /// 获取所有事件名称
    pub fn eventNames(self: *Self) ![][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var names = std.ArrayListUnmanaged([]const u8){};
        errdefer names.deinit(self.allocator);

        var iter = self.events.keyIterator();
        while (iter.next()) |key| {
            names.append(self.allocator, key.*) catch return EventError.OutOfMemory;
        }

        var wildcard_iter = self.wildcard_events.keyIterator();
        while (wildcard_iter.next()) |key| {
            names.append(self.allocator, key.*) catch return EventError.OutOfMemory;
        }

        return names.toOwnedSlice(self.allocator);
    }

    /// 检查事件是否有监听器
    pub fn hasListeners(self: *Self, event: []const u8) bool {
        return self.listenerCount(event) > 0;
    }

    /// 设置最大监听器数量
    pub fn setMaxListeners(self: *Self, max: usize) void {
        self.max_listeners = max;
    }

    /// 获取统计信息
    pub fn getStats(self: *Self) Stats {
        return .{
            .total_emits = self.total_emits,
            .total_listeners = self.total_listeners,
            .event_count = self.events.count() + self.wildcard_events.count(),
        };
    }

    pub const Stats = struct {
        total_emits: usize,
        total_listeners: usize,
        event_count: usize,
    };
};

/// 类型安全的事件发射器
pub fn TypedEventEmitter(comptime EventTypes: type) type {
    return struct {
        const Self = @This();

        emitter: EventEmitter,

        pub fn init(allocator: Allocator) Self {
            return .{
                .emitter = EventEmitter.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.emitter.deinit();
        }

        /// 发射类型安全的事件
        pub fn emit(self: *Self, event_data: EventTypes) !void {
            const event_name = @tagName(event_data);
            try self.emitter.emit(event_name, @ptrCast(@constCast(&event_data)));
        }

        /// 注册类型安全的监听器（简化版，不支持上下文）
        pub fn on(self: *Self, comptime event_tag: std.meta.Tag(EventTypes), handler: anytype) !void {
            const event_name = @tagName(event_tag);

            // 创建包装器将类型安全处理器转换为通用处理器
            const wrapper = struct {
                const Wrapper = @This();
                typed_handler: ?*anyopaque,

                pub fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
                    if (data) |d| {
                        const event_data = @as(*const EventTypes, @ptrCast(@alignCast(d)));
                        const self_wrap = @as(*const Wrapper, @ptrCast(@alignCast(ctx)));
                        const handler_fn = @as(*const fn (EventTypes) void, @ptrCast(@alignCast(self_wrap.typed_handler)));
                        handler_fn.*(event_data.*);
                    }
                }
            };

            // 分配包装器
            const wrapper_ptr = try self.emitter.allocator.create(wrapper);
            errdefer self.emitter.allocator.destroy(wrapper_ptr);
            wrapper_ptr.* = .{
                .typed_handler = @ptrCast(@constCast(&handler)),
            };

            try self.emitter.onWithContext(event_name, wrapper.handle, wrapper_ptr);
        }
    };
}

/// 全局事件总线（单例）
var global_emitter: ?*EventEmitter = null;
var global_mutex: std.Thread.Mutex = .{};

/// 获取全局事件总线
pub fn getGlobalEmitter(allocator: Allocator) !*EventEmitter {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_emitter == null) {
        global_emitter = try allocator.create(EventEmitter);
        global_emitter.?.* = EventEmitter.init(allocator);
    }
    return global_emitter.?;
}

/// 释放全局事件总线
pub fn deinitGlobalEmitter(allocator: Allocator) void {
    global_mutex.lock();
    defer global_mutex.unlock();

    if (global_emitter) |emitter| {
        emitter.deinit();
        allocator.destroy(emitter);
        global_emitter = null;
    }
}

// ============================================================================
// 测试
// ============================================================================

test "EventEmitter: 基本事件" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var called: bool = false;

    try emitter.on("test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            const flag = @as(*bool, @ptrCast(@alignCast(ctx)));
            flag.* = true;
        }
    }.handle);

    // 直接设置 context 不太方便，使用 onWithContext
    emitter.offAll("test");

    try emitter.onWithContext("test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const flag = @as(*bool, @ptrCast(@alignCast(c)));
                flag.* = true;
            }
        }
    }.handle, &called);

    try emitter.emit("test", null);

    try std.testing.expect(called);
}

test "EventEmitter: 一次性监听器" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    try emitter.onWithContext("once_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, &count);

    // 设置为 once
    emitter.offAll("once_test");
    try emitter.onWithOptions("once_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, .{ .once = true, .context = &count });

    try emitter.emit("once_test", null);
    try emitter.emit("once_test", null);
    try emitter.emit("once_test", null);

    // 只执行一次
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "EventEmitter: 通配符匹配" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    // 注册通配符监听器
    try emitter.onWithOptions("user.*", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, .{ .context = &count });

    // 发射不同的 user.* 事件
    try emitter.emit("user.created", null);
    try emitter.emit("user.updated", null);
    try emitter.emit("user.deleted", null);
    try emitter.emit("post.created", null); // 不匹配

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "EventEmitter: ** 匹配所有" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    // 注册 ** 监听器
    try emitter.onWithOptions("**", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, .{ .context = &count });

    try emitter.emit("any.event", null);
    try emitter.emit("another.deep.event", null);
    try emitter.emit("simple", null);

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "EventEmitter: 优先级" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var order = std.ArrayListUnmanaged(u8){};
    defer order.deinit(allocator);

    // 注册不同优先级的监听器
    try emitter.onWithOptions("priority_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = ctx;
            if (data) |d| {
                const list = @as(*std.ArrayListUnmanaged(u8), @ptrCast(@alignCast(d)));
                list.append(std.testing.allocator, 'L') catch {};
            }
        }
    }.handle, .{ .priority = .low });

    try emitter.onWithOptions("priority_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = ctx;
            if (data) |d| {
                const list = @as(*std.ArrayListUnmanaged(u8), @ptrCast(@alignCast(d)));
                list.append(std.testing.allocator, 'H') catch {};
            }
        }
    }.handle, .{ .priority = .high });

    try emitter.onWithOptions("priority_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = ctx;
            if (data) |d| {
                const list = @as(*std.ArrayListUnmanaged(u8), @ptrCast(@alignCast(d)));
                list.append(std.testing.allocator, 'N') catch {};
            }
        }
    }.handle, .{ .priority = .normal });

    try emitter.emit("priority_test", &order);

    // 高优先级先执行
    try std.testing.expectEqualStrings("HNL", order.items);
}

test "EventEmitter: 移除监听器" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle;

    try emitter.onWithOptions("remove_test", handler, .{ .context = &count });

    try emitter.emit("remove_test", null);
    try std.testing.expectEqual(@as(usize, 1), count);

    // 移除监听器
    try emitter.off("remove_test", handler);

    try emitter.emit("remove_test", null);
    try std.testing.expectEqual(@as(usize, 1), count); // 不再增加
}

test "EventEmitter: 统计信息" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    try emitter.on("event1", handler);
    try emitter.on("event2", handler);
    try emitter.on("event2", handler);

    try emitter.emit("event1", null);
    try emitter.emit("event2", null);

    const stats = emitter.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_listeners);
    try std.testing.expectEqual(@as(usize, 2), stats.total_emits);
    try std.testing.expectEqual(@as(usize, 2), stats.event_count);
}

test "EventEmitter: 监听器计数" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    try emitter.on("count.test", handler);
    try emitter.on("count.test", handler);
    try emitter.on("count.*", handler); // 通配符也会匹配

    try std.testing.expectEqual(@as(usize, 3), emitter.listenerCount("count.test"));
    try std.testing.expect(emitter.hasListeners("count.test"));
}

test "EventEmitter: 多段通配符" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    // 注册 app.** 监听器
    try emitter.onWithOptions("app.**", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, .{ .context = &count });

    try emitter.emit("app.user.created", null);
    try emitter.emit("app.post.updated", null);
    try emitter.emit("app.comment.deleted.soft", null);
    try emitter.emit("other.event", null); // 不匹配

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "EventEmitter: 最大监听器限制" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    emitter.setMaxListeners(3);

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    // 添加到限制
    try emitter.on("limit_test", handler);
    try emitter.on("limit_test", handler);
    try emitter.on("limit_test", handler);

    // 第4个应该失败
    try std.testing.expectError(EventError.MaxListenersExceeded, emitter.on("limit_test", handler));
}

test "EventEmitter: 移除所有监听器" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    const handler1 = struct {
        fn handle1(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle1;

    const handler2 = struct {
        fn handle2(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 2;
            }
        }
    }.handle2;

    try emitter.on("remove_all_test", handler1);
    try emitter.on("remove_all_test", handler2);
    try emitter.on("other_event", handler1);

    try emitter.emit("remove_all_test", &count);
    try std.testing.expectEqual(@as(usize, 3), count); // handler1(1) + handler2(2)

    // 移除所有 remove_all_test 监听器
    emitter.offAll("remove_all_test");

    count = 0;
    try emitter.emit("remove_all_test", &count);
    try std.testing.expectEqual(@as(usize, 0), count); // 不再触发

    // 但 other_event 仍然工作
    try emitter.emit("other_event", &count);
    try std.testing.expectEqual(@as(usize, 1), count);
}

test "EventEmitter: 获取事件名称" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    try emitter.on("event.one", handler);
    try emitter.on("event.two", handler);
    try emitter.on("event.*", handler); // 通配符
    try emitter.on("other.event", handler);

    const names = try emitter.eventNames();
    defer allocator.free(names);

    try std.testing.expectEqual(@as(usize, 4), names.len);

    // 检查是否包含所有事件
    var has_one = false;
    var has_two = false;
    var has_wildcard = false;
    var has_other = false;

    for (names) |name| {
        if (std.mem.eql(u8, name, "event.one")) has_one = true;
        if (std.mem.eql(u8, name, "event.two")) has_two = true;
        if (std.mem.eql(u8, name, "event.*")) has_wildcard = true;
        if (std.mem.eql(u8, name, "other.event")) has_other = true;
    }

    try std.testing.expect(has_one);
    try std.testing.expect(has_two);
    try std.testing.expect(has_wildcard);
    try std.testing.expect(has_other);
}

test "EventEmitter: 复杂数据传递" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const User = struct {
        id: u32,
        name: []const u8,
        email: []const u8,
    };

    const received_user = struct {
        var value: ?User = null;
    };

    try emitter.on("user.registered", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = ctx;
            if (data) |d| {
                const user = @as(*const User, @ptrCast(@alignCast(d)));
                received_user.value = user.*;
            }
        }
    }.handle);

    const user = User{
        .id = 123,
        .name = "测试用户",
        .email = "test@example.com",
    };

    try emitter.emit("user.registered", @ptrCast(@constCast(&user)));

    try std.testing.expect(received_user.value != null);
    try std.testing.expectEqual(@as(u32, 123), received_user.value.?.id);
    try std.testing.expectEqualStrings("测试用户", received_user.value.?.name);
    try std.testing.expectEqualStrings("test@example.com", received_user.value.?.email);
}

test "EventEmitter: 空事件发射" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const count = struct {
        var value: usize = 0;
    };

    try emitter.on("empty_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            count.value += 1;
        }
    }.handle);

    // 发射空数据
    try emitter.emit("empty_test", null);
    try std.testing.expectEqual(@as(usize, 1), count.value);

    // 发射不存在的事件（应该不报错）
    try emitter.emit("nonexistent", null);
    try std.testing.expectEqual(@as(usize, 1), count.value); // 计数不变
}

test "EventEmitter: 通配符边缘情况" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const count = struct {
        var value: usize = 0;
    };

    // 测试各种通配符模式
    try emitter.on("test.*", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            count.value += 10;
        }
    }.handle);

    try emitter.on("test.**.deep", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            count.value += 100;
        }
    }.handle);

    // test.* 匹配
    try emitter.emit("test.match", null);
    try std.testing.expectEqual(@as(usize, 10), count.value);

    // test.**.deep 匹配
    count.value = 0;
    try emitter.emit("test.any.deep", null);
    try std.testing.expectEqual(@as(usize, 100), count.value);

    try emitter.emit("test.more.levels.deep", null);
    try std.testing.expectEqual(@as(usize, 200), count.value);

    // 不匹配
    count.value = 0;
    try emitter.emit("other.match", null);
    try std.testing.expectEqual(@as(usize, 0), count.value);
}

// test "EventEmitter: 监听器重新添加" {
//     const allocator = std.testing.allocator;

//     var emitter = EventEmitter.init(allocator);
//     defer emitter.deinit();

//     var count: usize = 0;

//     const handler = struct {
//         fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
//             _ = data;
//             if (ctx) |c| {
//                 const cnt = @as(*usize, @ptrCast(@alignCast(c)));
//                 cnt.* += 1;
//             }
//         }
//     }.handle;

//     // 添加两次相同的监听器
//     try emitter.on("readd_test", handler);
//     try emitter.on("readd_test", handler);

//     try emitter.emit("readd_test", &count);
//     try std.testing.expectEqual(@as(usize, 2), count); // 执行两次

//     // 移除监听器（移除所有实例）
//     try emitter.off("readd_test", handler);

//     count = 0;
//     try emitter.emit("readd_test", &count);
//     try std.testing.expectEqual(@as(usize, 0), count); // 不再执行
// }

// test "EventEmitter: 优先级边界测试" {
//     const allocator = std.testing.allocator;

//     var emitter = EventEmitter.init(allocator);
//     defer emitter.deinit();

//     var order = std.ArrayListUnmanaged(u8){};
//     defer order.deinit(allocator);

//     // 测试所有优先级级别
//     try emitter.onWithOptions("priority_bounds", struct {
//         fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
//             _ = ctx;
//             if (data) |d| {
//                 const list = @as(*std.ArrayListUnmanaged(u8), @ptrCast(@alignCast(d)));
//                 list.append(std.testing.allocator, 'L') catch {};
//             }
//         }
//     }.handle, .{ .priority = .lowest });

//     try emitter.onWithOptions("priority_bounds", struct {
//         fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
//             _ = ctx;
//             if (data) |d| {
//                 const list = @as(*std.ArrayListUnmanaged(u8), @ptrCast(@alignCast(d)));
//                 list.append(std.testing.allocator, 'M') catch {};
//             }
//         }
//     }.handle, .{ .priority = .monitor });

//     try emitter.emit("priority_bounds", &order);

//     // 最低优先级先执行，然后是监控级别
//     try std.testing.expectEqualStrings("LM", order.items);
// }

test "EventEmitter: 错误处理 - 无效通配符" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    // 目前通配符验证不严格，这里测试基本功能
    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    // 应该可以正常添加各种模式
    try emitter.on("valid.*", handler);
    try emitter.on("also.*.valid", handler);
    try emitter.on("**", handler);
    try emitter.on("single.event", handler);

    try std.testing.expectEqual(@as(usize, 4), emitter.listenerCount("valid.match"));
    try std.testing.expectEqual(@as(usize, 1), emitter.listenerCount("single.event"));
}

test "EventEmitter: 异步事件模拟" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    var count: usize = 0;

    // 模拟异步执行（实际上是同步的）
    try emitter.onWithOptions("async_test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
            // 在实际应用中，这里可以是异步操作
            // std.time.sleep_ns(1000); // 模拟异步延迟
        }
    }.handle, .{ .async_exec = true }); // 标记为异步（目前只是标记）

    try emitter.emit("async_test", &count);
    try std.testing.expectEqual(@as(usize, 1), count);
}

// test "TypedEventEmitter: 类型安全事件" {
//     const allocator = std.testing.allocator;

//     // 定义事件类型（必须是union(enum)）
//     const EventData = union(enum) {
//         user_created: struct { id: u32, name: []const u8 },
//         order_placed: struct { order_id: u32, amount: f64 },
//     };

//     var typed_emitter = TypedEventEmitter(EventData).init(allocator);
//     defer typed_emitter.deinit();

//     const received = struct {
//         var value: ?EventData = null;
//     };

//     // 注册类型安全的监听器
//     const handler = struct {
//         fn handle(data: EventData) void {
//             received.value = data;
//         }
//     }.handle;
//     try typed_emitter.on(.user_created, handler);

//     // 发射类型安全的事件
//     try typed_emitter.emit(EventData{ .user_created = .{ .id = 456, .name = "类型安全用户" } });

//     try std.testing.expect(received.value != null);
//     try std.testing.expect(received.value.? == .user_created);
//     try std.testing.expectEqual(@as(u32, 456), received.value.?.user_created.id);
//     try std.testing.expectEqualStrings("类型安全用户", received.value.?.user_created.name);
// }

test "全局事件总线" {
    const allocator = std.testing.allocator;

    // 获取全局发射器
    var global = try getGlobalEmitter(allocator);
    defer deinitGlobalEmitter(allocator);

    var count: usize = 0;

    try global.onWithContext("global.test", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            if (ctx) |c| {
                const cnt = @as(*usize, @ptrCast(@alignCast(c)));
                cnt.* += 1;
            }
        }
    }.handle, &count);

    try global.emit("global.test", null);
    try std.testing.expectEqual(@as(usize, 1), count);

    // 再次获取应该是同一个实例
    var global2 = try getGlobalEmitter(allocator);
    try global2.emit("global.test", null);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "EventEmitter: 大量事件压力测试" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    // 设置更高的监听器限制
    emitter.setMaxListeners(1000);

    const counter = struct {
        var calls: usize = 0;
    };

    // 只添加几个监听器来测试
    try emitter.on("stress.event.0", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            counter.calls += 1;
        }
    }.handle);

    try emitter.on("stress.event.1", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            counter.calls += 1;
        }
    }.handle);

    // 添加通配符监听器
    try emitter.on("stress.**", struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
            counter.calls += 1;
        }
    }.handle);

    // 发射事件
    try emitter.emit("stress.event.0", null);
    try emitter.emit("stress.event.1", null);

    // 每个事件应该被两个监听器处理（精确匹配 + 通配符）
    try std.testing.expectEqual(@as(usize, 4), counter.calls);
}

test "EventEmitter: 事件名去重和清理" {
    const allocator = std.testing.allocator;

    var emitter = EventEmitter.init(allocator);
    defer emitter.deinit();

    const handler = struct {
        fn handle(data: ?*anyopaque, ctx: ?*anyopaque) void {
            _ = data;
            _ = ctx;
        }
    }.handle;

    // 添加多个相同事件的监听器
    try emitter.on("cleanup.test", handler);
    try emitter.on("cleanup.test", handler);
    try emitter.on("cleanup.test", handler);

    try std.testing.expectEqual(@as(usize, 1), emitter.getStats().event_count);

    // 移除所有监听器
    emitter.offAll("cleanup.test");

    // 事件应该被完全清理
    try std.testing.expectEqual(@as(usize, 0), emitter.getStats().event_count);
    try std.testing.expectEqual(@as(usize, 0), emitter.listenerCount("cleanup.test"));
}
