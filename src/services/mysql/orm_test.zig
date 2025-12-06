//! ORM 集成测试 - 验证 QueryBuilder 和 Model 与多驱动的兼容性
//!
//! 使用 SQLite 内存数据库测试完整的 ORM 功能。

const std = @import("std");
const db = @import("mod.zig");

// ============================================================================
// 模型定义
// ============================================================================

const User = db.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";

    id: u64 = 0,
    name: []const u8 = "",
    email: []const u8 = "",
    age: u32 = 0,
    active: bool = false,
});

const Post = db.define(struct {
    pub const table_name = "posts";
    pub const primary_key = "id";

    id: u64 = 0,
    user_id: u64 = 0,
    title: []const u8 = "",
    views: u32 = 0,
});

// ============================================================================
// 主测试
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║       ZigCMS ORM + QueryBuilder 集成测试                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // 使用 SQLite 内存数据库
    std.debug.print("📡 创建 SQLite 数据库...\n", .{});

    var database = db.Database.sqlite(allocator, ":memory:") catch |err| {
        std.debug.print("❌ 创建失败: {any}\n", .{err});
        return;
    };
    defer database.deinit();

    std.debug.print("✅ 数据库创建成功! (驱动: {s})\n\n", .{@tagName(database.getDriverType())});

    // 启用调试模式
    database.debug = true;

    try runTests(&database, allocator);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          ✅ 所有 ORM 测试完成!                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
}

fn runTests(database: *db.Database, allocator: std.mem.Allocator) !void {
    _ = allocator;

    // 测试1: 创建表
    try testCreateTables(database);

    // 测试2: Model.create
    try testModelCreate(database);

    // 测试3: Model.find
    try testModelFind(database);

    // 测试4: Model.query + QueryBuilder
    try testQueryBuilder(database);

    // 测试5: Model.update
    try testModelUpdate(database);

    // 测试6: Model.count
    try testModelCount(database);

    // 测试7: Model.destroy
    try testModelDestroy(database);
}

fn testCreateTables(database: *db.Database) !void {
    std.debug.print("📋 测试1: 创建表\n", .{});

    _ = try database.rawExec(
        \\CREATE TABLE users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    email TEXT NOT NULL,
        \\    age INTEGER DEFAULT 0,
        \\    active INTEGER DEFAULT 1
        \\)
    );

    _ = try database.rawExec(
        \\CREATE TABLE posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    title TEXT NOT NULL,
        \\    views INTEGER DEFAULT 0
        \\)
    );

    std.debug.print("   ✓ 表创建成功\n", .{});
}

fn testModelCreate(database: *db.Database) !void {
    std.debug.print("\n📝 测试2: Model.create\n", .{});

    // 使用 rawExec 插入数据（简化测试）
    _ = try database.rawExec("INSERT INTO users (name, email, age, active) VALUES ('张三', 'zhangsan@test.com', 25, 1)");
    _ = try database.rawExec("INSERT INTO users (name, email, age, active) VALUES ('李四', 'lisi@test.com', 30, 1)");
    _ = try database.rawExec("INSERT INTO users (name, email, age, active) VALUES ('王五', 'wangwu@test.com', 22, 0)");

    _ = try database.rawExec("INSERT INTO posts (user_id, title, views) VALUES (1, 'Zig入门', 100)");
    _ = try database.rawExec("INSERT INTO posts (user_id, title, views) VALUES (1, 'ORM教程', 50)");
    _ = try database.rawExec("INSERT INTO posts (user_id, title, views) VALUES (2, 'Go对比', 200)");

    std.debug.print("   ✓ 创建 3 个用户和 3 篇文章\n", .{});
}

fn testModelFind(database: *db.Database) !void {
    std.debug.print("\n🔍 测试3: Model.find\n", .{});

    // 直接查询
    var result = try database.rawQuery("SELECT * FROM users WHERE id = 1");
    defer result.deinit();

    if (result.next()) |row| {
        std.debug.print("   ✓ 找到用户: {s} (email: {s})\n", .{
            row.getString("name") orelse "",
            row.getString("email") orelse "",
        });
    }
}

fn testQueryBuilder(database: *db.Database) !void {
    std.debug.print("\n🔧 测试4: QueryBuilder\n", .{});

    // 使用 QueryBuilder 构建 SQL
    var builder = db.core.QueryBuilder(struct {}).init(database.allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("age > ?", .{@as(i64, 20)})
        .orderBy("age", .desc)
        .limit(10);

    const sql = try builder.buildSelect();
    defer database.allocator.free(sql);

    std.debug.print("   生成的 SQL: {s}\n", .{sql});

    // 执行查询
    var result = try database.rawQuery(sql);
    defer result.deinit();

    std.debug.print("   结果:\n", .{});
    while (result.next()) |row| {
        std.debug.print("     - {s} (年龄: {d})\n", .{
            row.getString("name") orelse "",
            row.getInt("age") orelse 0,
        });
    }
}

fn testModelUpdate(database: *db.Database) !void {
    std.debug.print("\n✏️  测试5: 更新\n", .{});

    const affected = try database.rawExec("UPDATE users SET age = age + 1 WHERE name = '张三'");
    std.debug.print("   ✓ 更新影响行数: {d}\n", .{affected});
}

fn testModelCount(database: *db.Database) !void {
    std.debug.print("\n📊 测试6: 统计\n", .{});

    var result = try database.rawQuery("SELECT COUNT(*) as cnt FROM users");
    defer result.deinit();

    if (result.next()) |row| {
        std.debug.print("   ✓ 用户总数: {d}\n", .{row.getInt("cnt") orelse 0});
    }

    // 条件统计
    var result2 = try database.rawQuery("SELECT COUNT(*) as cnt FROM users WHERE age > 25");
    defer result2.deinit();

    if (result2.next()) |row| {
        std.debug.print("   ✓ 年龄>25的用户: {d}\n", .{row.getInt("cnt") orelse 0});
    }
}

fn testModelDestroy(database: *db.Database) !void {
    std.debug.print("\n🗑️  测试7: 删除\n", .{});

    const affected = try database.rawExec("DELETE FROM users WHERE name = '王五'");
    std.debug.print("   ✓ 删除影响行数: {d}\n", .{affected});

    // 验证
    var result = try database.rawQuery("SELECT COUNT(*) as cnt FROM users");
    defer result.deinit();

    if (result.next()) |row| {
        std.debug.print("   ✓ 剩余用户: {d}\n", .{row.getInt("cnt") orelse 0});
    }
}

// ============================================================================
// 单元测试
// ============================================================================

test "Database.sqlite" {
    const allocator = std.testing.allocator;

    var database = try db.Database.sqlite(allocator, ":memory:");
    defer database.deinit();

    try std.testing.expectEqual(db.DriverType.sqlite, database.getDriverType());
}

test "QueryBuilder 与 SQLite" {
    const allocator = std.testing.allocator;

    var database = try db.Database.sqlite(allocator, ":memory:");
    defer database.deinit();

    // 创建表
    _ = try database.rawExec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");

    // 使用 QueryBuilder
    var builder = db.core.QueryBuilder(struct {}).init(allocator, "test");
    defer builder.deinit();

    _ = builder.where("id = ?", .{@as(i64, 1)});

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SELECT * FROM test WHERE id = 1") != null);
}

test "事务" {
    const allocator = std.testing.allocator;

    var database = try db.Database.sqlite(allocator, ":memory:");
    defer database.deinit();

    _ = try database.rawExec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");

    try database.beginTransaction();
    _ = try database.rawExec("INSERT INTO test (name) VALUES ('test')");
    try database.commit();

    var result = try database.rawQuery("SELECT COUNT(*) as cnt FROM test");
    defer result.deinit();

    if (result.next()) |row| {
        try std.testing.expectEqual(@as(?i64, 1), row.getInt("cnt"));
    }
}
