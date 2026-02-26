//! 性能基准测试 (Performance Benchmark Tests)
//!
//! 测试 DDD 模式、事件系统、CQRS 的性能开销。

const std = @import("std");
const testing = std.testing;
const ValueObject = @import("../shared_kernel/patterns/value_object.zig").ValueObject;
const DomainEvent = @import("../shared_kernel/patterns/domain_event.zig").DomainEvent;
const AggregateRoot = @import("../shared_kernel/patterns/aggregate_root.zig").AggregateRoot;
const CommandBus = @import("../shared_kernel/patterns/command.zig").CommandBus;
const QueryBus = @import("../shared_kernel/patterns/query.zig").QueryBus;
const Query = @import("../shared_kernel/patterns/query.zig").Query;
const QueryHandler = @import("../shared_kernel/patterns/query.zig").QueryHandler;

// ============================================================================
// 测试辅助类型
// ============================================================================

/// 测试用 Email 值对象
const TestEmail = struct {
    const Self = @This();
    value: []const u8,

    pub fn create(email: []const u8) !Self {
        if (email.len == 0) return error.EmailRequired;
        const at_pos = std.mem.indexOf(u8, email, "@") orelse return error.InvalidEmail;
        if (at_pos == 0 or at_pos == email.len - 1) return error.InvalidEmail;
        return Self{ .value = email };
    }
};

/// 测试用用户数据
const TestUserData = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    email: []const u8 = "",
};

/// 测试用用户事件
const TestUserEvent = DomainEvent(struct {
    user_id: i32,
    action: []const u8,
});

/// 测试用用户聚合根
const TestUserAgg = AggregateRoot(TestUserData, TestUserEvent);

// ============================================================================
// 值对象性能测试
// ============================================================================

test "ValueObject - Email creation performance" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const email = TestEmail.create("test@example.com") catch continue;
        _ = email;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ Email 值对象创建性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 500); // 预期平均 < 500ns
}

test "ValueObject - Email equality comparison performance" {
    const allocator = testing.allocator;
    const iterations = 10000;

    const email1 = TestEmail.create("test@example.com") catch unreachable;
    const email2 = TestEmail.create("test@example.com") catch unreachable;
    const email3 = TestEmail.create("other@example.com") catch unreachable;

    var timer = try std.time.Timer.start();
    var equal_count: usize = 0;
    for (0..iterations) |_| {
        if (std.meta.eql(email1.value, email2.value)) equal_count += 1;
        if (std.meta.eql(email1.value, email3.value)) equal_count += 1;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ Email 相等性比较性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 100); // 预期平均 < 100ns
}

// ============================================================================
// 聚合根性能测试
// ============================================================================

test "AggregateRoot - creation performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var timer = try std.time.Timer.start();
    for (0..iterations) |i| {
        const data = TestUserData{
            .id = @intCast(i),
            .username = "testuser",
            .email = "test@example.com",
        };
        const agg = try TestUserAgg.create(data, allocator);
        agg.deinit();
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 聚合根创建性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 10000); // 预期平均 < 10μs
}

test "AggregateRoot - event publishing performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    const data = TestUserData{ .id = 1, .username = "test", .email = "test@example.com" };
    var agg = try TestUserAgg.create(data, allocator);
    defer agg.deinit();

    var timer = try std.time.Timer.start();
    for (0..iterations) |i| {
        const event = try TestUserEvent.create(.{
            .user_id = i,
            .action = "test_action",
        }, allocator, "test.event");
        agg.publish(event);
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 事件发布性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 2000); // 预期平均 < 2μs
}

test "AggregateRoot - event drain performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var agg = try TestUserAgg.create(.{
        .id = 1,
        .username = "test",
        .email = "test@example.com",
    }, allocator);
    defer agg.deinit();

    // 预填充事件
    for (0..100) |i| {
        const event = try TestUserEvent.create(.{
            .user_id = i,
            .action = "test",
        }, allocator, "test");
        agg.publish(event);
    }

    timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const events = agg.drainEvents();
        events.deinit();
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 事件清空性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 500); // 预期平均 < 500ns
}

// ============================================================================
// 领域事件性能测试
// ============================================================================

test "DomainEvent - creation performance" {
    const allocator = testing.allocator;
    const iterations = 5000;

    var timer = try std.time.Timer.start();
    for (0..iterations) |i| {
        const event = try TestUserEvent.create(.{
            .user_id = @intCast(i),
            .action = "user.created",
        }, allocator, "user.created");
        _ = event;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 领域事件创建性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 2000); // 预期平均 < 2μs
}

test "DomainEvent - metadata access performance" {
    const allocator = testing.allocator;
    const iterations = 10000;

    const event = try TestUserEvent.create(.{
        .user_id = 1,
        .action = "test",
    }, allocator, "test.event");

    var timer = try std.time.Timer.start();
    var metadata_access_count: usize = 0;
    for (0..iterations) |_| {
        if (event.getOccurredAt() > 0) metadata_access_count += 1;
        if (event.getEventType()) |t| if (t.len > 0) _ = t;
        if (event.getAggregateId()) |id| _ = id;
        if (event.getAggregateVersion()) |v| _ = v;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 事件元数据访问性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 200); // 预期平均 < 200ns
}

// ============================================================================
// CQRS 性能测试
// ============================================================================

test "CommandBus - command dispatch performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    const handler = try allocator.create(CommandHandler);
    handler.* = CommandHandler.init(allocator, "TestCommand", struct {
        fn handle(cmd: *anyopaque) struct { success: bool } {
            _ = cmd;
            return .{ .success = true };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("TestCommand", handler);

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const result = bus.send(undefined, "TestCommand");
        _ = result;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 命令分发性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 3000); // 预期平均 < 3μs
}

test "QueryBus - query execution performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var bus = QueryBus.init(allocator);
    defer bus.deinit();

    const handler = try allocator.create(QueryHandler);
    handler.* = QueryHandler.init(allocator, "TestQuery", struct {
        fn handle(query: *const Query) struct { success: bool, count: usize } {
            _ = query;
            return .{ .success = true, .count = 10 };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("TestQuery", handler);

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var query = Query.init(allocator, "TestQuery");
        defer query.deinit(allocator);
        const result = bus.fetch(&query);
        _ = result;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 查询执行性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 5000); // 预期平均 < 5μs
}

test "Query - pagination calculation performance" {
    const allocator = testing.allocator;
    const iterations = 10000;

    var timer = try std.time.Timer.start();
    for (0..iterations) |i| {
        const page = (i % 100) + 1;
        const page_size = 20;
        const offset = (page - 1) * page_size;
        _ = offset;
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 分页计算性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 50); // 预期平均 < 50ns
}

// ============================================================================
// 内存分配性能测试
// ============================================================================

test "Memory allocation - small string duplication" {
    const allocator = testing.allocator;
    const iterations = 5000;
    const test_string = "test@example.com";

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        const copy = try allocator.dupe(u8, test_string);
        allocator.free(copy);
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ 小字符串复制性能: {d} ns/次 ({d} 次迭代)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 500); // 预期平均 < 500ns
}

test "Memory allocation - ArrayList append performance" {
    const allocator = testing.allocator;
    const iterations = 1000;

    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        var list = std.ArrayList(i32).init(allocator);
        for (0..100) |j| {
            try list.append(@intCast(j));
        }
        list.deinit();
    }
    const elapsed_ns = timer.read();
    const avg_ns = elapsed_ns / iterations;

    std.debug.print("\n✅ ArrayList 追加性能: {d} ns/次 ({d} 次迭代，每项100个元素)\n", .{ avg_ns, iterations });
    try testing.expect(avg_ns < 10000); // 预期平均 < 10μs
}

// ============================================================================
// 基准测试总结
// ============================================================================

test "Performance benchmark summary" {
    std.debug.print("\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("  性能基准测试总结\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  所有性能测试已完成。\n", .{});
    std.debug.print("  预期性能目标：\n", .{});
    std.debug.print("  - 值对象操作: < 500ns\n", .{});
    std.debug.print("  - 聚合根创建: < 10μs\n", .{});
    std.debug.print("  - 事件发布: < 2μs\n", .{});
    std.debug.print("  - 命令分发: < 3μs\n", .{});
    std.debug.print("  - 查询执行: < 5μs\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("========================================\n", .{});
}
