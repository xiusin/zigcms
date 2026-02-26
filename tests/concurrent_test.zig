const std = @import("std");
const testing = std.testing;
const zigcms = @import("zigcms");
const cache_drivers = zigcms.cache_drivers;
const AppContext = zigcms.shared.context.AppContext;
const SystemConfig = zigcms.shared.config.SystemConfig;

const NUM_THREADS = 10;
const NUM_OPERATIONS_PER_THREAD = 100;

test "Cache: 并发读写测试 - 验证线程安全" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n⚠️  Cache 并发测试检测到内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("initial", "value", 300);

    const ThreadContext = struct {
        cache_interface: @TypeOf(cache),
        thread_id: usize,
        allocator: std.mem.Allocator,
    };

    const workerFn = struct {
        fn run(ctx: *ThreadContext) void {
            var i: usize = 0;
            while (i < NUM_OPERATIONS_PER_THREAD) : (i += 1) {
                const key_buffer = std.fmt.allocPrint(
                    ctx.allocator,
                    "thread:{d}:key:{d}",
                    .{ ctx.thread_id, i },
                ) catch |err| {
                    std.debug.print("Failed to allocate key: {}\n", .{err});
                    continue;
                };
                defer ctx.allocator.free(key_buffer);

                const value_buffer = std.fmt.allocPrint(
                    ctx.allocator,
                    "value:{d}:{d}",
                    .{ ctx.thread_id, i },
                ) catch |err| {
                    std.debug.print("Failed to allocate value: {}\n", .{err});
                    continue;
                };
                defer ctx.allocator.free(value_buffer);

                ctx.cache_interface.set(key_buffer, value_buffer, 300) catch |err| {
                    std.debug.print("Set failed: {}\n", .{err});
                    continue;
                };

                if (ctx.cache_interface.get(key_buffer, ctx.allocator) catch null) |retrieved| {
                    defer ctx.allocator.free(retrieved);
                }

                if (i % 3 == 0) {
                    ctx.cache_interface.del(key_buffer) catch |err| {
                        std.debug.print("Del failed: {}\n", .{err});
                    };
                }
            }
        }
    }.run;

    var threads: [NUM_THREADS]std.Thread = undefined;
    var contexts: [NUM_THREADS]ThreadContext = undefined;

    for (&threads, &contexts, 0..) |*thread, *ctx, idx| {
        ctx.* = .{
            .cache_interface = cache,
            .thread_id = idx,
            .allocator = allocator,
        };
        thread.* = try std.Thread.spawn(.{}, workerFn, .{ctx});
    }

    for (threads) |thread| {
        thread.join();
    }

    const stats = cache.stats();
    std.debug.print("\n✅ Cache 并发测试完成:\n", .{});
    std.debug.print("  - 线程数: {d}\n", .{NUM_THREADS});
    std.debug.print("  - 每线程操作数: {d}\n", .{NUM_OPERATIONS_PER_THREAD});
    std.debug.print("  - 最终缓存项: {d}\n", .{stats.count});
    std.debug.print("  - 过期项: {d}\n", .{stats.expired});
}

test "Cache: 并发 get 竞态条件测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("shared_key", "shared_value", 300);

    const ThreadContext = struct {
        cache_interface: @TypeOf(cache),
        allocator: std.mem.Allocator,
        success_count: *std.atomic.Value(u32),
    };

    const workerFn = struct {
        fn run(ctx: *ThreadContext) void {
            var i: usize = 0;
            while (i < 50) : (i += 1) {
                if (ctx.cache_interface.get("shared_key", ctx.allocator) catch null) |value| {
                    defer ctx.allocator.free(value);
                    _ = ctx.success_count.fetchAdd(1, .monotonic);
                }
            }
        }
    }.run;

    var success_count = std.atomic.Value(u32).init(0);
    var threads: [5]std.Thread = undefined;
    var contexts: [5]ThreadContext = undefined;

    for (&threads, &contexts) |*thread, *ctx| {
        ctx.* = .{
            .cache_interface = cache,
            .allocator = allocator,
            .success_count = &success_count,
        };
        thread.* = try std.Thread.spawn(.{}, workerFn, .{ctx});
    }

    for (threads) |thread| {
        thread.join();
    }

    const final_count = success_count.load(.monotonic);
    try testing.expectEqual(@as(u32, 250), final_count);
    std.debug.print("\n✅ 并发 get 测试完成: {d} 次成功读取\n", .{final_count});
}

test "Cache: 前缀删除并发安全性" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("user:1:name", "Alice", 300);
    try cache.set("user:1:email", "alice@example.com", 300);
    try cache.set("user:2:name", "Bob", 300);
    try cache.set("order:100:total", "500", 300);

    const ThreadContext = struct {
        cache_interface: @TypeOf(cache),
        prefix: []const u8,
    };

    const workerFn = struct {
        fn run(ctx: *ThreadContext) void {
            ctx.cache_interface.delByPrefix(ctx.prefix) catch |err| {
                std.debug.print("delByPrefix failed: {}\n", .{err});
            };
        }
    }.run;

    var thread1_ctx = ThreadContext{ .cache_interface = cache, .prefix = "user:1:" };
    var thread2_ctx = ThreadContext{ .cache_interface = cache, .prefix = "user:2:" };

    const thread1 = try std.Thread.spawn(.{}, workerFn, .{&thread1_ctx});
    const thread2 = try std.Thread.spawn(.{}, workerFn, .{&thread2_ctx});

    thread1.join();
    thread2.join();

    try testing.expect(!cache.exists("user:1:name"));
    try testing.expect(!cache.exists("user:1:email"));
    try testing.expect(!cache.exists("user:2:name"));
    try testing.expect(cache.exists("order:100:total"));

    std.debug.print("\n✅ 前缀删除并发测试完成\n", .{});
}

test "AppContext: 多线程并发访问测试" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n⚠️  AppContext 并发测试检测到内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    const sql = zigcms.sql;
    const DIContainer = zigcms.shared.di.container.DIContainer;

    var config = SystemConfig{
        .api = .{
            .host = "127.0.0.1",
            .port = 8080,
        },
        .app = .{
            .enable_cache = true,
        },
    };

    var db = try allocator.create(sql.Database);
    db.* = try sql.Database.sqlite(allocator, ":memory:");
    errdefer {
        db.deinit();
        allocator.destroy(db);
    }

    var container = try allocator.create(DIContainer);
    container.* = DIContainer.init(allocator);
    errdefer {
        container.deinit();
        allocator.destroy(container);
    }

    const app_context = try AppContext.init(allocator, &config, db, container);
    defer app_context.deinit();

    const ThreadContext = struct {
        ctx: *AppContext,
        thread_id: usize,
    };

    const workerFn = struct {
        fn run(ctx: *ThreadContext) void {
            var i: usize = 0;
            while (i < 20) : (i += 1) {
                const db_ref = ctx.ctx.getDatabase();
                _ = db_ref;

                const cfg = ctx.ctx.getConfig();
                _ = cfg;

                const di = ctx.ctx.getContainer();
                _ = di;
            }
        }
    }.run;

    var threads: [8]std.Thread = undefined;
    var contexts: [8]ThreadContext = undefined;

    for (&threads, &contexts, 0..) |*thread, *ctx, idx| {
        ctx.* = .{
            .ctx = app_context,
            .thread_id = idx,
        };
        thread.* = try std.Thread.spawn(.{}, workerFn, .{ctx});
    }

    for (threads) |thread| {
        thread.join();
    }

    std.debug.print("\n✅ AppContext 多线程并发访问测试完成\n", .{});
    std.debug.print("  - 8 个线程，每个线程 20 次访问\n", .{});
}

test "Cache: 压力测试 - 大量键值对操作" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n⚠️  Cache 压力测试检测到内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    const start_time = std.time.milliTimestamp();

    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "stress:key:{d}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value:{d}", .{i});
        defer allocator.free(value);

        try cache.set(key, value, 300);
    }

    i = 0;
    var hit_count: usize = 0;
    while (i < 10000) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "stress:key:{d}", .{i});
        defer allocator.free(key);

        if (try cache.get(key, allocator)) |value| {
            defer allocator.free(value);
            hit_count += 1;
        }
    }

    const end_time = std.time.milliTimestamp();
    const duration = end_time - start_time;

    const stats = cache.stats();

    std.debug.print("\n✅ Cache 压力测试完成:\n", .{});
    std.debug.print("  - 操作数: 20000 (10000 写 + 10000 读)\n", .{});
    std.debug.print("  - 耗时: {d}ms\n", .{duration});
    std.debug.print("  - 缓存命中: {d}/10000\n", .{hit_count});
    std.debug.print("  - 最终缓存项: {d}\n", .{stats.count});

    try testing.expectEqual(@as(usize, 10000), hit_count);
    try testing.expectEqual(@as(usize, 10000), stats.count);
}
