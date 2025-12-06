//! SQLite 集成测试 - 无需外部数据库服务
//!
//! 使用 SQLite 内存数据库进行测试，无需安装任何数据库服务。
//!
//! 运行测试：
//! ```bash
//! zig build test-sqlite
//! ```

const std = @import("std");
const db = @import("mod.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          ZigCMS SQLite 集成测试                          ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // 使用内存数据库
    std.debug.print("📡 创建 SQLite 内存数据库...\n", .{});

    var conn = db.Driver.sqlite(allocator, ":memory:") catch |err| {
        std.debug.print("❌ 创建失败: {any}\n", .{err});
        return;
    };
    defer conn.deinit();

    std.debug.print("✅ 数据库创建成功! (驱动: {s})\n\n", .{@tagName(conn.getDriverType())});

    // 运行测试
    try runTests(&conn, allocator);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          ✅ 所有测试完成!                                ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
}

fn runTests(conn: *db.UnifiedConnection, allocator: std.mem.Allocator) !void {
    // 测试1: 创建表
    try testCreateTables(conn);

    // 测试2: 插入数据
    try testInsert(conn);

    // 测试3: 查询数据
    try testQuery(conn, allocator);

    // 测试4: 更新数据
    try testUpdate(conn);

    // 测试5: 事务
    try testTransaction(conn);

    // 测试6: 删除数据
    try testDelete(conn);
}

fn testCreateTables(conn: *db.UnifiedConnection) !void {
    std.debug.print("📋 测试1: 创建表\n", .{});

    // 创建用户表
    _ = try conn.exec(
        \\CREATE TABLE users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    email TEXT NOT NULL UNIQUE,
        \\    age INTEGER DEFAULT 0,
        \\    active INTEGER DEFAULT 1,
        \\    created_at TEXT DEFAULT CURRENT_TIMESTAMP
        \\)
    );

    // 创建文章表
    _ = try conn.exec(
        \\CREATE TABLE posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    title TEXT NOT NULL,
        \\    content TEXT,
        \\    views INTEGER DEFAULT 0,
        \\    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        \\)
    );

    std.debug.print("   ✓ users 表创建成功\n", .{});
    std.debug.print("   ✓ posts 表创建成功\n", .{});
}

fn testInsert(conn: *db.UnifiedConnection) !void {
    std.debug.print("\n📝 测试2: 插入数据\n", .{});

    // 插入用户
    _ = try conn.exec("INSERT INTO users (name, email, age, active) VALUES ('张三', 'zhangsan@example.com', 25, 1)");
    _ = try conn.exec("INSERT INTO users (name, email, age, active) VALUES ('李四', 'lisi@example.com', 30, 1)");
    _ = try conn.exec("INSERT INTO users (name, email, age, active) VALUES ('王五', 'wangwu@example.com', 22, 0)");
    _ = try conn.exec("INSERT INTO users (name, email, age, active) VALUES ('赵六', 'zhaoliu@example.com', 35, 1)");
    _ = try conn.exec("INSERT INTO users (name, email, age, active) VALUES ('钱七', 'qianqi@example.com', 28, 1)");

    std.debug.print("   ✓ 插入 5 个用户\n", .{});

    // 插入文章
    _ = try conn.exec("INSERT INTO posts (user_id, title, content, views) VALUES (1, 'Zig语言入门', 'Zig是一种系统编程语言...', 100)");
    _ = try conn.exec("INSERT INTO posts (user_id, title, content, views) VALUES (1, 'Zig与SQLite', '如何在Zig中使用SQLite...', 50)");
    _ = try conn.exec("INSERT INTO posts (user_id, title, content, views) VALUES (2, 'Go vs Zig', '两种语言的对比...', 200)");
    _ = try conn.exec("INSERT INTO posts (user_id, title, content, views) VALUES (3, '学习笔记', '今天学习了...', 10)");

    std.debug.print("   ✓ 插入 4 篇文章\n", .{});
    std.debug.print("   ✓ 最后插入ID: {d}\n", .{conn.lastInsertId()});
}

fn testQuery(conn: *db.UnifiedConnection, allocator: std.mem.Allocator) !void {
    std.debug.print("\n🔍 测试3: 查询数据\n", .{});

    // 查询所有用户
    var result = try conn.query("SELECT id, name, email, age FROM users ORDER BY id");
    defer result.deinit();

    std.debug.print("   用户列表 (共 {d} 条):\n", .{result.rowCount()});
    std.debug.print("   ┌────┬──────────┬─────────────────────────┬─────┐\n", .{});
    std.debug.print("   │ ID │ 姓名     │ 邮箱                    │ 年龄│\n", .{});
    std.debug.print("   ├────┼──────────┼─────────────────────────┼─────┤\n", .{});

    while (result.next()) |row| {
        const id = row.getInt("id") orelse 0;
        const name = row.getString("name") orelse "";
        const email = row.getString("email") orelse "";
        const age = row.getInt("age") orelse 0;

        std.debug.print("   │ {d:<2} │ {s:<8} │ {s:<23} │ {d:<3} │\n", .{
            id,
            name,
            email,
            age,
        });
    }
    std.debug.print("   └────┴──────────┴─────────────────────────┴─────┘\n", .{});

    // 条件查询
    var result2 = try conn.query("SELECT COUNT(*) as cnt FROM users WHERE age > 25");
    defer result2.deinit();

    if (result2.next()) |row| {
        const count = row.getInt("cnt") orelse 0;
        std.debug.print("   ✓ 年龄大于25的用户: {d} 人\n", .{count});
    }

    // 聚合查询
    var result3 = try conn.query(
        \\SELECT 
        \\    COUNT(*) as total,
        \\    AVG(age) as avg_age,
        \\    MIN(age) as min_age,
        \\    MAX(age) as max_age
        \\FROM users
    );
    defer result3.deinit();

    if (result3.next()) |row| {
        std.debug.print("   统计:\n", .{});
        std.debug.print("   - 总用户数: {d}\n", .{row.getInt("total") orelse 0});
        std.debug.print("   - 平均年龄: {d:.1}\n", .{row.getFloat("avg_age") orelse 0});
        std.debug.print("   - 最小年龄: {d}\n", .{row.getInt("min_age") orelse 0});
        std.debug.print("   - 最大年龄: {d}\n", .{row.getInt("max_age") orelse 0});
    }

    // JOIN 查询
    var result4 = try conn.query(
        \\SELECT u.name, COUNT(p.id) as post_count, COALESCE(SUM(p.views), 0) as total_views
        \\FROM users u
        \\LEFT JOIN posts p ON u.id = p.user_id
        \\GROUP BY u.id, u.name
        \\ORDER BY post_count DESC
    );
    defer result4.deinit();

    std.debug.print("\n   用户文章统计:\n", .{});
    std.debug.print("   ┌──────────┬──────────┬──────────┐\n", .{});
    std.debug.print("   │ 用户     │ 文章数   │ 总浏览量 │\n", .{});
    std.debug.print("   ├──────────┼──────────┼──────────┤\n", .{});

    while (result4.next()) |row| {
        std.debug.print("   │ {s:<8} │ {d:<8} │ {d:<8} │\n", .{
            row.getString("name") orelse "",
            row.getInt("post_count") orelse 0,
            row.getInt("total_views") orelse 0,
        });
    }
    std.debug.print("   └──────────┴──────────┴──────────┘\n", .{});

    _ = allocator;
}

fn testUpdate(conn: *db.UnifiedConnection) !void {
    std.debug.print("\n✏️  测试4: 更新数据\n", .{});

    const affected = try conn.exec("UPDATE users SET age = age + 1 WHERE name = '张三'");
    std.debug.print("   ✓ 更新张三年龄, 影响行数: {d}\n", .{affected});
}

fn testTransaction(conn: *db.UnifiedConnection) !void {
    std.debug.print("\n🔄 测试5: 事务\n", .{});

    // 开始事务
    try conn.beginTransaction();
    std.debug.print("   ✓ 开始事务\n", .{});

    // 插入新用户
    _ = try conn.exec("INSERT INTO users (name, email, age) VALUES ('测试用户', 'test@example.com', 20)");
    std.debug.print("   ✓ 插入测试用户\n", .{});

    // 提交事务
    try conn.commit();
    std.debug.print("   ✓ 提交事务\n", .{});

    // 测试回滚
    try conn.beginTransaction();
    _ = try conn.exec("INSERT INTO users (name, email, age) VALUES ('回滚用户', 'rollback@example.com', 99)");
    try conn.rollback();
    std.debug.print("   ✓ 回滚测试完成\n", .{});
}

fn testDelete(conn: *db.UnifiedConnection) !void {
    std.debug.print("\n🗑️  测试6: 删除数据\n", .{});

    const affected = try conn.exec("DELETE FROM users WHERE name = '测试用户'");
    std.debug.print("   ✓ 删除测试用户, 影响行数: {d}\n", .{affected});
}

// ============================================================================
// 单元测试
// ============================================================================

test "SQLite 内存数据库" {
    const allocator = std.testing.allocator;

    var conn = try db.Driver.sqlite(allocator, ":memory:");
    defer conn.deinit();

    try std.testing.expectEqual(db.DriverType.sqlite, conn.getDriverType());

    // 创建表
    _ = try conn.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");

    // 插入
    _ = try conn.exec("INSERT INTO test (name) VALUES ('hello')");
    try std.testing.expectEqual(@as(u64, 1), conn.lastInsertId());

    // 查询
    var result = try conn.query("SELECT * FROM test");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.rowCount());
}

test "统一驱动接口" {
    const allocator = std.testing.allocator;

    // 测试内存驱动
    var mem_conn = try db.Driver.memory(allocator);
    defer mem_conn.deinit();

    try std.testing.expectEqual(db.DriverType.memory, mem_conn.getDriverType());

    _ = try mem_conn.exec("CREATE TABLE test (id INT)");
    try mem_conn.beginTransaction();
    try mem_conn.commit();
}
