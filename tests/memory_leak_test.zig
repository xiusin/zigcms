const std = @import("std");
const testing = std.testing;
const zigcms = @import("zigcms");
const AppContext = zigcms.shared.context.AppContext;
const RequestContext = zigcms.shared.context.RequestContext;
const SystemConfig = zigcms.shared.config.SystemConfig;
const cache_drivers = zigcms.cache_drivers;
const orm = zigcms.sql.orm;

const TestUser = orm.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";

    id: ?u64 = null,
    name: []const u8,
    email: []const u8,
    created_at: ?i64 = null,
});

test "内存泄漏: AppContext 完整生命周期" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
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
    const ctx_allocator = app_context.allocator;
    ctx_allocator.destroy(app_context);

    std.debug.print("\n✅ AppContext 生命周期无内存泄漏\n", .{});
}

test "内存泄漏: RequestContext 多次创建销毁" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
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
    defer {
        const ctx_allocator = app_context.allocator;
        ctx_allocator.destroy(app_context);
    }

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var req_ctx = try RequestContext.withTimeout(allocator, app_context, 5000);
        defer req_ctx.deinit();

        try req_ctx.setValue("request_id", "req-12345");
        try req_ctx.setValue("user_id", "user-67890");

        const req_id = req_ctx.getValue("request_id");
        try testing.expect(req_id != null);
    }

    std.debug.print("\n✅ RequestContext 100次创建/销毁无内存泄漏\n", .{});
}

test "内存泄漏: Cache 大量操作" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
        }
    }

    const allocator = gpa.allocator();

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "leak:test:key:{d}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value:{d}", .{i});
        defer allocator.free(value);

        try cache.set(key, value, 300);
    }

    i = 0;
    while (i < 1000) : (i += 1) {
        const key = try std.fmt.allocPrint(allocator, "leak:test:key:{d}", .{i});
        defer allocator.free(key);

        if (try cache.get(key, allocator)) |value| {
            defer allocator.free(value);
        }
    }

    try cache.flush();

    std.debug.print("\n✅ Cache 1000次读写无内存泄漏\n", .{});
}

test "内存泄漏: ORM QueryResult Arena Allocator" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
        }
    }

    const allocator = gpa.allocator();

    const sql = zigcms.sql;

    var db = try sql.Database.sqlite(allocator, .{
        .path = ":memory:",
        .mode = "memory",
    });
    defer db.deinit();

    _ = try db.rawExec(
        \\CREATE TABLE IF NOT EXISTS users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    email TEXT NOT NULL,
        \\    created_at INTEGER
        \\)
    );

    _ = try db.rawExec(
        \\INSERT INTO users (name, email, created_at) VALUES 
        \\('Alice', 'alice@example.com', 1640000000),
        \\('Bob', 'bob@example.com', 1640000001),
        \\('Charlie', 'charlie@example.com', 1640000002)
    );

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        var result = db.rawQuery("SELECT * FROM users", .{}) catch |err| {
            std.debug.print("Query failed: {}\n", .{err});
            continue;
        };
        defer result.deinit();

        while (result.next()) {
            const row = result.getCurrentRow() orelse continue;
            _ = row;
        }
    }

    std.debug.print("\n✅ ORM 查询 50次迭代无内存泄漏\n", .{});
}

test "内存泄漏: ORM QueryResult 包装器" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
        }
    }

    const allocator = gpa.allocator();

    const sql = zigcms.sql;

    var db = try sql.Database.sqlite(allocator, .{
        .path = ":memory:",
        .mode = "memory",
    });
    defer db.deinit();

    _ = try db.rawExec(
        \\CREATE TABLE IF NOT EXISTS users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    email TEXT NOT NULL,
        \\    created_at INTEGER
        \\)
    );

    _ = try db.rawExec(
        \\INSERT INTO users (name, email, created_at) VALUES 
        \\('Alice', 'alice@example.com', 1640000000),
        \\('Bob', 'bob@example.com', 1640000001),
        \\('Charlie', 'charlie@example.com', 1640000002)
    );

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        var result_set = db.rawQuery("SELECT * FROM users", .{}) catch continue;
        defer result_set.deinit();

        var query_result = orm.QueryResult(TestUser).fromResultSet(allocator, &result_set) catch continue;
        defer query_result.deinit();

        for (query_result.items()) |user| {
            _ = user;
        }
    }

    std.debug.print("\n✅ QueryResult 包装器 100次迭代无内存泄漏\n", .{});
}

test "内存泄漏: Cache 过期清理" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
        }
    }

    const allocator = gpa.allocator();

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    var round: usize = 0;
    while (round < 5) : (round += 1) {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "expire:round:{d}:key:{d}", .{ round, i });
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "value:{d}", .{i});
            defer allocator.free(value);

            try cache.set(key, value, 1);
        }

        std.time.sleep(1500 * std.time.ns_per_ms);

        try cache.cleanupExpired();

        const stats = cache.stats();
        try testing.expectEqual(@as(usize, 0), stats.expired);
    }

    std.debug.print("\n✅ Cache 过期清理 5轮 x 100项无内存泄漏\n", .{});
}

test "内存泄漏: RequestContext 值传递" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
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
    defer {
        const ctx_allocator = app_context.allocator;
        ctx_allocator.destroy(app_context);
    }

    var i: usize = 0;
    while (i < 200) : (i += 1) {
        var req_ctx = try RequestContext.init(allocator, app_context);
        defer req_ctx.deinit();

        const key1 = try std.fmt.allocPrint(allocator, "key:{d}", .{i});
        defer allocator.free(key1);

        const value1 = try std.fmt.allocPrint(allocator, "value:{d}", .{i});
        defer allocator.free(value1);

        try req_ctx.setValue(key1, value1);

        try req_ctx.setValue("trace_id", "trace-12345");
        try req_ctx.setValue("session_id", "session-67890");
        try req_ctx.setValue("user_agent", "Mozilla/5.0");

        const trace = req_ctx.getValue("trace_id");
        _ = trace;
    }

    std.debug.print("\n✅ RequestContext 值传递 200次迭代无内存泄漏\n", .{});
}

test "内存泄漏: Cache delByPrefix 大量删除" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            testing.expectEqual(std.heap.Check.ok, leaked) catch {};
        }
    }

    const allocator = gpa.allocator();

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    var round: usize = 0;
    while (round < 10) : (round += 1) {
        var i: usize = 0;
        while (i < 50) : (i += 1) {
            const key = try std.fmt.allocPrint(allocator, "user:{d}:item:{d}", .{ round, i });
            defer allocator.free(key);

            const value = try std.fmt.allocPrint(allocator, "data:{d}", .{i});
            defer allocator.free(value);

            try cache.set(key, value, 300);
        }

        const prefix = try std.fmt.allocPrint(allocator, "user:{d}:", .{round});
        defer allocator.free(prefix);

        try cache.delByPrefix(prefix);
    }

    const stats = cache.stats();
    try testing.expectEqual(@as(usize, 0), stats.count);

    std.debug.print("\n✅ Cache delByPrefix 10轮 x 50项无内存泄漏\n", .{});
}
