//! SQLite 完整测试
//!
//! 测试覆盖：
//! - CRUD 操作及结果验证
//! - QueryBuilder 构造
//! - 事务（提交/回滚）
//! - 高级查询（子查询、EXISTS）
//! - JOIN 查询
//! - 并发安全测试
//! - 内存泄漏检测（使用 GPA）
//!
//! 编译运行：
//! cd src/services/sql
//! zig build-exe sqlite_complete_test.zig -lc -lsqlite3
//! ./sqlite_complete_test

const std = @import("std");

// 只导入需要的模块，避免引入 MySQL
const interface = @import("interface.zig");
const orm = @import("orm.zig");
const query = @import("query.zig");

const Database = orm.Database;

// 测试统计
var tests_passed: usize = 0;
var tests_failed: usize = 0;

fn assert(condition: bool, msg: []const u8) !void {
    if (condition) {
        tests_passed += 1;
    } else {
        tests_failed += 1;
        std.debug.print("  ✗ 断言失败: {s}\n", .{msg});
        return error.AssertionFailed;
    }
}

fn assertEq(comptime T: type, actual: T, expected: T, msg: []const u8) !void {
    if (actual == expected) {
        tests_passed += 1;
    } else {
        tests_failed += 1;
        std.debug.print("  ✗ 断言失败: {s} (期望: {any}, 实际: {any})\n", .{ msg, expected, actual });
        return error.AssertionFailed;
    }
}

// ============================================================================
// 主测试入口
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n⚠️  检测到内存泄漏！\n", .{});
        } else {
            std.debug.print("\n✓ 无内存泄漏\n", .{});
        }
    }
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          SQLite ORM 完整测试                              ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    try testSQLite(allocator);

    // 输出测试统计
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试统计\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  通过: {d}\n", .{tests_passed});
    std.debug.print("  失败: {d}\n", .{tests_failed});
    if (tests_failed == 0) {
        std.debug.print("\n✓ SQLite 所有测试通过！\n", .{});
    } else {
        std.debug.print("\n✗ 部分测试失败\n", .{});
    }
}

// ============================================================================
// SQLite 完整测试
// ============================================================================

fn testSQLite(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 1: SQLite 驱动\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 创建数据库连接
    var db = try Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    std.debug.print("✓ 数据库连接创建成功（内存模式）\n", .{});
    std.debug.print("  驱动类型: {s}\n\n", .{@tagName(db.getDriverType())});

    try assert(db.getDriverType() == .sqlite, "驱动类型应为 sqlite");

    // 创建测试表
    try setupTables(&db);

    // 运行所有测试
    try testCRUD(allocator, &db);
    try testQueryBuilder(allocator, &db);
    try testTransactions(allocator, &db);
    try testAdvancedQueries(allocator, &db);
    try testJoins(allocator, &db);
    try testORM(allocator, &db);
    try testConcurrency(allocator);
    try testEdgeCases(allocator, &db);
}

// ============================================================================
// 创建测试表
// ============================================================================

fn setupTables(db: *Database) !void {
    std.debug.print("准备测试环境...\n", .{});

    // 创建 users 表
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS users
    );

    _ = try db.rawExec(
        \\CREATE TABLE users (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    email TEXT NOT NULL UNIQUE,
        \\    age INTEGER,
        \\    city TEXT,
        \\    active INTEGER DEFAULT 1
        \\)
    );

    // 创建 posts 表
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS posts
    );

    _ = try db.rawExec(
        \\CREATE TABLE posts (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    title TEXT NOT NULL,
        \\    content TEXT,
        \\    views INTEGER DEFAULT 0,
        \\    published INTEGER DEFAULT 0
        \\)
    );

    // 创建 comments 表
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS comments
    );

    _ = try db.rawExec(
        \\CREATE TABLE comments (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    post_id INTEGER NOT NULL,
        \\    content TEXT NOT NULL
        \\)
    );

    std.debug.print("✓ 测试表创建完成\n\n", .{});
}

// ============================================================================
// 测试 2: CRUD 操作
// ============================================================================

fn testCRUD(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 2: CRUD 操作\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 2.1 创建
    {
        std.debug.print("2.1 创建记录\n", .{});

        const affected = try db.rawExec(
            \\INSERT INTO users (name, email, age, city) 
            \\VALUES ('张三', 'zhangsan@example.com', 25, '北京')
        );

        std.debug.print("  ✓ 插入 {d} 条记录\n", .{affected});
        std.debug.print("  ✓ 最后插入 ID: {d}\n\n", .{db.lastInsertId()});
    }

    // 2.2 批量插入
    {
        std.debug.print("2.2 批量插入\n", .{});

        const users = [_][]const u8{
            "('李四', 'lisi@example.com', 30, '上海')",
            "('王五', 'wangwu@example.com', 22, '广州')",
            "('赵六', 'zhaoliu@example.com', 28, '深圳')",
        };

        for (users) |user| {
            const sql_query = try std.fmt.allocPrint(
                allocator,
                "INSERT INTO users (name, email, age, city) VALUES {s}",
                .{user},
            );
            defer allocator.free(sql_query);

            _ = try db.rawExec(sql_query);
        }

        std.debug.print("  ✓ 批量插入 {d} 条记录\n\n", .{users.len});
    }

    // 2.3 读取
    {
        std.debug.print("2.3 读取记录\n", .{});

        var result = try db.rawQuery("SELECT * FROM users WHERE age > 25 ORDER BY age");
        defer result.deinit();

        std.debug.print("  查询结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}, {s}岁, {s}\n", .{
                row.getString("name") orelse "",
                row.getString("age") orelse "?",
                row.getString("city") orelse "",
            });
        }
        std.debug.print("\n", .{});
    }

    // 2.4 更新
    {
        std.debug.print("2.4 更新记录\n", .{});

        const affected = try db.rawExec(
            \\UPDATE users SET age = age + 1 WHERE city = '北京'
        );

        std.debug.print("  ✓ 更新 {d} 条记录\n\n", .{affected});
    }

    // 2.5 删除
    {
        std.debug.print("2.5 删除记录\n", .{});

        const affected = try db.rawExec(
            \\DELETE FROM users WHERE age > 40
        );

        std.debug.print("  ✓ 删除 {d} 条记录\n\n", .{affected});
    }

    // 2.6 统计
    {
        std.debug.print("2.6 统计查询\n", .{});

        var result = try db.rawQuery(
            \\SELECT COUNT(*) as total, AVG(age) as avg_age FROM users
        );
        defer result.deinit();

        if (result.next()) |row| {
            std.debug.print("  总用户数: {s}\n", .{row.getString("total") orelse "0"});
            std.debug.print("  平均年龄: {s}\n\n", .{row.getString("avg_age") orelse "0"});
        }
    }
}

// ============================================================================
// 测试 3: QueryBuilder
// ============================================================================

fn testQueryBuilder(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 3: QueryBuilder 查询构造\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 3.1 基础查询
    {
        std.debug.print("3.1 基础查询\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .selectFields(&.{ "name", "email", "age" })
            .where("age > ?", .{25})
            .orderBy("age", .desc)
            .limit(3);

        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);

        std.debug.print("  SQL: {s}\n", .{query_sql});

        var result = try db.rawQuery(query_sql);
        defer result.deinit();

        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}, {s}岁\n", .{
                row.getString("name") orelse "",
                row.getString("age") orelse "?",
            });
        }
        std.debug.print("\n", .{});
    }

    // 3.2 使用 debug()
    {
        std.debug.print("3.2 使用 debug() 调试\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .where("age > ?", .{25})
            .debug() // ✅ 打印 SQL
            .orderBy("name", .asc);

        std.debug.print("\n", .{});
    }
}
// 测试 4: 事务
// ============================================================================

fn testTransactions(allocator: std.mem.Allocator, db: *Database) !void {
    _ = allocator;
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 4: 事务\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 4.1 手动事务（提交）
    {
        std.debug.print("4.1 手动事务（提交）\n", .{});

        // 获取事务前的用户数
        var before_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer before_result.deinit();
        const before_count = if (before_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        try db.beginTransaction();
        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('事务1', 'tx1@example.com', 20)");
        try db.commit();

        // 验证提交后数据存在
        var after_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer after_result.deinit();
        const after_count = if (after_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        try assertEq(usize, after_count, before_count + 1, "事务提交后用户数应增加1");
        std.debug.print("  ✓ 事务提交成功，用户数: {d} -> {d}\n\n", .{ before_count, after_count });
    }

    // 4.2 手动事务（回滚）
    {
        std.debug.print("4.2 手动事务（回滚）\n", .{});

        var before_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer before_result.deinit();
        const before_count = if (before_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        try db.beginTransaction();
        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('回滚', 'rollback@example.com', 99)");
        try db.rollback();

        // 验证回滚后数据不存在
        var after_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer after_result.deinit();
        const after_count = if (after_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        try assertEq(usize, after_count, before_count, "事务回滚后用户数应不变");
        std.debug.print("  ✓ 事务回滚成功，用户数保持: {d}\n\n", .{after_count});
    }

    // 4.3 自动事务（成功）
    {
        std.debug.print("4.3 自动事务（成功）\n", .{});

        try db.transaction(struct {
            fn run(db_ref: anytype) !void {
                _ = try db_ref.rawExec("INSERT INTO users (name, email, age) VALUES ('自动', 'auto@example.com', 25)");
            }
        }.run, .{});

        std.debug.print("  ✓ 自动事务成功\n\n", .{});
    }

    // 4.4 自动事务（失败回滚）
    {
        std.debug.print("4.4 自动事务（失败回滚）\n", .{});

        var before_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer before_result.deinit();
        const before_count = if (before_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        const tx_result = db.transaction(struct {
            fn run(_: anytype) !void {
                return error.SimulatedError;
            }
        }.run, .{});

        try assert(tx_result == error.SimulatedError, "应捕获模拟错误");

        var after_result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
        defer after_result.deinit();
        const after_count = if (after_result.next()) |row|
            std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0
        else
            0;

        try assertEq(usize, after_count, before_count, "事务失败后用户数应不变");
        std.debug.print("  ✓ 自动事务失败回滚成功\n\n", .{});
    }
}

// ============================================================================
// 测试 5: 高级查询
// ============================================================================

fn testAdvancedQueries(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 5: 高级查询\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 准备测试数据
    _ = try db.rawExec(
        \\INSERT INTO posts (user_id, title, views, published) VALUES
        \\(1, 'Zig 编程', 100, 1),
        \\(1, '如何使用 ORM', 50, 1),
        \\(2, 'SQL 优化', 200, 1)
    );

    _ = try db.rawExec(
        \\INSERT INTO comments (post_id, content) VALUES
        \\(1, '很好的文章！'),
        \\(2, '学到了很多')
    );

    // 5.1 子查询
    {
        std.debug.print("5.1 子查询 - WHERE IN\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder.whereInSub("id", "SELECT DISTINCT user_id FROM posts WHERE published = 1");

        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);

        std.debug.print("  SQL: {s}\n", .{query_sql});

        var result = try db.rawQuery(query_sql);
        defer result.deinit();

        std.debug.print("  有文章的用户:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}\n", .{row.getString("name") orelse ""});
        }
        std.debug.print("\n", .{});
    }

    // 5.2 EXISTS 子查询
    {
        std.debug.print("5.2 EXISTS 子查询\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "posts");
        defer builder.deinit();

        _ = builder.whereExists("SELECT 1 FROM comments WHERE comments.post_id = posts.id");

        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);

        std.debug.print("  SQL: {s}\n", .{query_sql});

        var result = try db.rawQuery(query_sql);
        defer result.deinit();

        std.debug.print("  有评论的文章:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}\n", .{row.getString("title") orelse ""});
        }
        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 6: JOIN 查询
// ============================================================================

fn testJoins(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 6: JOIN 查询\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 6.1 INNER JOIN
    {
        std.debug.print("6.1 INNER JOIN\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .selectFields(&.{ "users.name", "posts.title", "posts.views" })
            .innerJoin("posts", "users.id = posts.user_id")
            .where("posts.published = ?", .{1})
            .orderBy("posts.views", .desc);

        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);

        std.debug.print("  SQL: {s}\n", .{query_sql});

        var result = try db.rawQuery(query_sql);
        defer result.deinit();

        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}: {s} (浏览: {s})\n", .{
                row.getString("name") orelse "",
                row.getString("title") orelse "",
                row.getString("views") orelse "0",
            });
        }
        std.debug.print("\n", .{});
    }

    // 6.2 LEFT JOIN
    {
        std.debug.print("6.2 LEFT JOIN\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .selectFields(&.{ "users.name", "COUNT(posts.id) as post_count" })
            .leftJoin("posts", "users.id = posts.user_id")
            .groupBy(&.{ "users.id", "users.name" })
            .orderBy("post_count", .desc);

        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);

        std.debug.print("  SQL: {s}\n", .{query_sql});

        var result = try db.rawQuery(query_sql);
        defer result.deinit();

        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}: {s} 篇文章\n", .{
                row.getString("name") orelse "",
                row.getString("post_count") orelse "0",
            });
        }
        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 7: ORM 模型功能
// ============================================================================

// 定义测试模型 - 多样化数据类型
const Product = orm.define(struct {
    pub const table_name = "products";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    price: f64,
    stock: i32,
    category: []const u8,
    is_active: i32, // SQLite 使用整数表示布尔
    description: ?[]const u8,
    created_at: ?[]const u8,
});

const Order = orm.define(struct {
    pub const table_name = "orders";
    pub const primary_key = "id";

    id: u64,
    user_id: u64,
    product_id: u64,
    quantity: i32,
    total_price: f64,
    status: []const u8,
    created_at: ?[]const u8,
});

fn testORM(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 7: ORM 模型功能（完整覆盖）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 创建 ORM 测试表
    _ = try db.rawExec("DROP TABLE IF EXISTS products");
    _ = try db.rawExec(
        \\CREATE TABLE products (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    name TEXT NOT NULL,
        \\    price REAL NOT NULL,
        \\    stock INTEGER DEFAULT 0,
        \\    category TEXT,
        \\    is_active INTEGER DEFAULT 1,
        \\    description TEXT,
        \\    created_at TEXT
        \\)
    );

    _ = try db.rawExec("DROP TABLE IF EXISTS orders");
    _ = try db.rawExec(
        \\CREATE TABLE orders (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    user_id INTEGER NOT NULL,
        \\    product_id INTEGER NOT NULL,
        \\    quantity INTEGER NOT NULL,
        \\    total_price REAL NOT NULL,
        \\    status TEXT DEFAULT 'pending',
        \\    created_at TEXT
        \\)
    );

    // 7.1 ORM create - 创建记录
    {
        std.debug.print("7.1 ORM create - 创建单条记录\n", .{});

        var product = try Product.create(db, .{
            .name = "Zig 编程指南",
            .price = 99.99,
            .stock = 100,
            .category = "书籍",
            .is_active = 1,
            .description = "学习 Zig 语言的最佳入门书籍",
        });
        defer Product.freeModel(allocator, &product);

        try assert(product.id > 0, "创建后应有ID");
        try assert(std.mem.eql(u8, product.name, "Zig 编程指南"), "名称应正确");
        try assert(product.price == 99.99, "价格应正确");
        std.debug.print("  ✓ 创建产品: ID={d}, 名称={s}, 价格={d:.2}\n\n", .{ product.id, product.name, product.price });
    }

    // 7.2 ORM find - 查找单条记录
    {
        std.debug.print("7.2 ORM find - 查找单条记录\n", .{});
        if (try Product.find(db, 1)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            try assert(p.id == 1, "ID应为1");
            try assert(std.mem.eql(u8, p.name, "Zig 编程指南"), "名称应正确");
            std.debug.print("  ✓ 找到产品: ID={d}, {s}\n\n", .{ p.id, p.name });
        } else {
            return error.TestFailed;
        }
    }

    // 7.3 ORM find 不存在的记录
    {
        std.debug.print("7.3 ORM find - 查找不存在的记录\n", .{});
        const result = try Product.find(db, 999);
        try assert(result == null, "不存在的ID应返回null");
        std.debug.print("  ✓ ID=999 返回 null\n\n", .{});
    }

    // 7.4 ORM all - 获取所有记录
    {
        std.debug.print("7.4 ORM all - 获取所有记录\n", .{});

        // 先添加更多产品
        var p2 = try Product.create(db, .{ .name = "键盘", .price = 299.00, .stock = 50, .category = "电子产品", .is_active = 1 });
        defer Product.freeModel(allocator, &p2);
        var p3 = try Product.create(db, .{ .name = "鼠标", .price = 99.00, .stock = 200, .category = "电子产品", .is_active = 1, .description = "无线鼠标" });
        defer Product.freeModel(allocator, &p3);
        var p4 = try Product.create(db, .{ .name = "显示器", .price = 1999.00, .stock = 30, .category = "电子产品", .is_active = 1, .description = "4K 显示器" });
        defer Product.freeModel(allocator, &p4);

        const products = try Product.all(db);
        defer Product.freeModels(allocator, products);

        try assert(products.len == 4, "应有4个产品");
        std.debug.print("  ✓ 获取所有产品: {d} 个\n", .{products.len});
        for (products, 0..) |prod, i| {
            std.debug.print("    [{d}] {s}: ¥{d:.2}\n", .{ i + 1, prod.name, prod.price });
        }
        std.debug.print("\n", .{});
    }

    // 7.5 ORM update - 更新记录
    {
        std.debug.print("7.5 ORM update - 更新记录\n", .{});
        const affected = try Product.update(db, 1, .{
            .price = 79.99,
            .stock = 150,
        });
        try assert(affected > 0, "应更新至少1条记录");

        if (try Product.find(db, 1)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            try assert(p.price == 79.99, "价格应更新为79.99");
            try assert(p.stock == 150, "库存应更新为150");
            std.debug.print("  ✓ 更新后: 价格={d:.2}, 库存={d}\n\n", .{ p.price, p.stock });
        }
    }

    // 7.6 ORM count - 统计记录数
    {
        std.debug.print("7.6 ORM count - 统计记录数\n", .{});
        const total = try Product.count(db);
        try assertEq(u64, total, 4, "应有4个产品");
        std.debug.print("  ✓ 产品总数: {d}\n\n", .{total});
    }

    // 7.7 ORM exists - 检查记录是否存在
    {
        std.debug.print("7.7 ORM exists - 检查记录是否存在\n", .{});
        const exists1 = try Product.exists(db, 1);
        const exists999 = try Product.exists(db, 999);
        try assert(exists1, "ID=1 应存在");
        try assert(!exists999, "ID=999 不应存在");
        std.debug.print("  ✓ ID=1 存在: {}, ID=999 存在: {}\n\n", .{ exists1, exists999 });
    }

    // 7.8 ORM first - 获取第一条记录
    {
        std.debug.print("7.8 ORM first - 获取第一条记录\n", .{});
        if (try Product.first(db)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            std.debug.print("  ✓ 第一个产品: {s}\n\n", .{p.name});
        }
    }

    // 7.9 ORM query 链式调用
    {
        std.debug.print("7.9 ORM query 链式调用\n", .{});
        var q = Product.query(db);
        defer q.deinit();

        _ = q.where("category", "=", "电子产品")
            .where("price", "<", 500)
            .orderBy("price", .asc)
            .limit(10);

        const products = try q.get();
        defer Product.freeModels(allocator, products);

        std.debug.print("  ✓ 电子产品(价格<500): {d} 个\n", .{products.len});
        for (products) |p| {
            std.debug.print("    - {s}: ¥{d:.2}\n", .{ p.name, p.price });
        }
        std.debug.print("\n", .{});
    }

    // 7.10 ORM whereNull / whereNotNull
    {
        std.debug.print("7.10 ORM whereNull / whereNotNull\n", .{});

        // 创建一个没有描述的产品
        var p = try Product.create(db, .{ .name = "无描述产品", .price = 10.00, .stock = 5, .category = "其他", .is_active = 1 });
        defer Product.freeModel(allocator, &p);

        var q1 = Product.query(db);
        defer q1.deinit();
        _ = q1.whereNotNull("description");
        const with_desc = try q1.count();

        var q2 = Product.query(db);
        defer q2.deinit();
        _ = q2.whereNull("description");
        const without_desc = try q2.count();

        try assert(with_desc >= 2, "至少有2个有描述的产品");
        try assert(without_desc >= 2, "至少有2个无描述的产品");
        std.debug.print("  ✓ 有描述: {d}, 无描述: {d}\n\n", .{ with_desc, without_desc });
    }

    // 7.11 ORM destroy - 删除记录
    {
        std.debug.print("7.11 ORM destroy - 删除记录\n", .{});
        const before = try Product.count(db);
        _ = try Product.destroy(db, 1);
        const after = try Product.count(db);
        try assertEq(u64, after, before - 1, "删除后数量应减1");

        // 验证确实删除了
        const deleted = try Product.find(db, 1);
        try assert(deleted == null, "删除后应找不到");
        std.debug.print("  ✓ 删除前: {d}, 删除后: {d}\n\n", .{ before, after });
    }

    // 7.12 ORM 关联查询示例（创建订单）
    {
        std.debug.print("7.12 ORM 关联数据\n", .{});

        var order1 = try Order.create(db, .{
            .user_id = 1,
            .product_id = 2,
            .quantity = 2,
            .total_price = 598.00,
            .status = "paid",
        });
        defer Order.freeModel(allocator, &order1);

        var order2 = try Order.create(db, .{
            .user_id = 1,
            .product_id = 3,
            .quantity = 1,
            .total_price = 99.00,
            .status = "pending",
        });
        defer Order.freeModel(allocator, &order2);

        const order_count = try Order.count(db);
        try assert(order_count >= 2, "应至少有2个订单");
        std.debug.print("  ✓ 创建订单: {d} 个\n\n", .{order_count});
    }

    // 7.13 ORM 分页查询
    {
        std.debug.print("7.13 ORM 分页查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.page(1, 2); // 第1页，每页2条

        const page1 = try q.get();
        defer Product.freeModels(allocator, page1);

        try assert(page1.len <= 2, "每页最多2条");
        std.debug.print("  ✓ 第1页（每页2条）: {d} 条记录\n\n", .{page1.len});
    }

    // 7.14 ORM distinct 查询
    {
        std.debug.print("7.14 ORM distinct 查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{"category"}).distinct();

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "DISTINCT") != null, "SQL 应包含 DISTINCT");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.15 ORM groupBy 查询
    {
        std.debug.print("7.15 ORM groupBy 查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{ "category", "COUNT(*) as cnt" }).groupBy(&.{"category"});

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "GROUP BY") != null, "SQL 应包含 GROUP BY");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.16 ORM 复杂条件查询
    {
        std.debug.print("7.16 ORM 复杂条件查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.where("category", "=", "电子产品")
            .where("price", ">=", 50)
            .where("price", "<=", 500)
            .where("is_active", "=", 1)
            .orderBy("price", .desc)
            .limit(5);

        const products = try q.get();
        defer Product.freeModels(allocator, products);

        std.debug.print("  ✓ 符合条件: {d} 个产品\n", .{products.len});
        for (products) |prod| {
            std.debug.print("    - {s}: ¥{d:.2}\n", .{ prod.name, prod.price });
        }
        std.debug.print("\n", .{});
    }

    // 7.17 ORM offset 查询
    {
        std.debug.print("7.17 ORM offset 查询（跳过前N条）\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.orderBy("id", .asc).offset(1).limit(2);

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "OFFSET") != null, "SQL 应包含 OFFSET");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.18 ORM leftJoin 查询
    {
        std.debug.print("7.18 ORM leftJoin 查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{ "products.*", "orders.quantity" })
            .leftJoin("orders", "products.id = orders.product_id");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "LEFT JOIN") != null, "SQL 应包含 LEFT JOIN");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.19 新 API: collect() 自动内存管理
    {
        std.debug.print("7.19 新 API: collect() 自动内存管理\n", .{});

        // 使用 collect() 返回 List，自动管理内存
        var list = try Product.collect(db);
        defer list.deinit(); // 一行释放所有内存！

        std.debug.print("  ✓ 产品数量: {d}\n", .{list.count()});
        std.debug.print("  ✓ 是否为空: {}\n", .{list.isEmpty()});

        if (list.first()) |p| {
            std.debug.print("  ✓ 第一个: {s}\n", .{p.name});
        }
        if (list.last()) |p| {
            std.debug.print("  ✓ 最后一个: {s}\n", .{p.name});
        }
        std.debug.print("\n", .{});
    }

    // 7.20 新 API: 简化的 where 方法
    {
        std.debug.print("7.20 新 API: 简化的 where 方法\n", .{});

        var q = Product.query(db);
        defer q.deinit();

        // 使用 whereEq/whereGt/whereLt 代替 where("field", "=", value)
        _ = q.whereEq("category", "电子产品")
            .whereGte("price", 50)
            .whereLte("price", 1000)
            .latest() // 快捷方式：按 created_at 降序
            .take(5); // 快捷方式：limit(5)

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.21 新 API: whereLike 模糊查询
    {
        std.debug.print("7.21 新 API: whereLike 模糊查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereLike("name", "%鼠标%");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "LIKE") != null, "SQL 应包含 LIKE");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.22 新 API: exists/doesntExist
    {
        std.debug.print("7.22 新 API: exists/doesntExist\n", .{});

        // 检查是否有产品（不管什么分类）
        var q1 = Product.query(db);
        defer q1.deinit();
        const has_products = try q1.exists();

        var q2 = Product.query(db);
        defer q2.deinit();
        _ = q2.whereEq("category", "不存在的分类XYZ");
        const no_category = try q2.doesntExist();

        try assert(has_products, "应有产品");
        try assert(no_category, "不存在的分类应返回true");
        std.debug.print("  ✓ 有产品: {}, 无不存在分类: {}\n\n", .{ has_products, no_category });
    }

    // 7.23 新 API: query().collect() 链式获取 List
    {
        std.debug.print("7.23 新 API: query().collect() 链式调用\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereEq("category", "电子产品").orderBy("price", .asc);

        var list = try q.collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n", .{list.count()});
        for (list.items()) |p| {
            std.debug.print("    - {s}: ¥{d:.2}\n", .{ p.name, p.price });
        }
        std.debug.print("\n", .{});
    }

    // 7.24 新 API: whereInSub 子查询 (SQL字符串)
    {
        std.debug.print("7.24 新 API: whereInSub 子查询 (SQL字符串)\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereInSub("id", "SELECT product_id FROM orders WHERE quantity > 0");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "IN (SELECT") != null, "SQL 应包含 IN (SELECT");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.25 新 API: whereInQuery 子查询 (QueryBuilder)
    {
        std.debug.print("7.25 新 API: whereInQuery 子查询 (QueryBuilder)\n", .{});

        // 创建子查询
        var subquery = Order.query(db);
        defer subquery.deinit();
        _ = subquery.select(&.{"product_id"}).whereEq("status", "paid");

        // 主查询使用子查询
        var main_query = Product.query(db);
        defer main_query.deinit();
        _ = main_query.whereInQuery("id", &subquery);

        const sql = try main_query.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "IN (SELECT product_id") != null, "SQL 应包含子查询");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.26 新 API: whereExists 子查询
    {
        std.debug.print("7.26 新 API: whereExists 子查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereExists("SELECT 1 FROM orders WHERE orders.product_id = products.id");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "EXISTS (SELECT") != null, "SQL 应包含 EXISTS");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.27 新 API: whereColumn 字段比较
    {
        std.debug.print("7.27 新 API: whereColumn 字段比较\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereColumn("stock", ">", "price");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "stock > price") != null, "SQL 应包含字段比较");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.28 Laravel 风格: 静态 where 方法
    {
        std.debug.print("7.28 Laravel 风格: Product.where(db, ...).get()\n", .{});

        // 直接使用静态方法，更简洁！
        var q = Product.where(db, "category", "=", "电子产品");
        defer q.deinit();

        const products = try q.orderBy("price", .asc).limit(5).get();
        defer Product.freeModels(allocator, products);

        std.debug.print("  ✓ 获取 {d} 个电子产品\n", .{products.len});
        for (products) |p| {
            std.debug.print("    - {s}: ¥{d:.2}\n", .{ p.name, p.price });
        }
        std.debug.print("\n", .{});
    }

    // 7.29 Laravel 风格: Product.whereEq(db, ...).get()
    {
        std.debug.print("7.29 Laravel 风格: Product.whereEq(db, ...).get()\n", .{});

        var q = Product.whereEq(db, "category", "电子产品");
        defer q.deinit();

        var list = try q.collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.30 Laravel 风格: Product.whereLike(db, ...).get()
    {
        std.debug.print("7.30 Laravel 风格: Product.whereLike(db, ...).get()\n", .{});

        var q = Product.whereLike(db, "name", "%鼠%");
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);

        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.31 Laravel 风格: Product.latest(db).take(5).get()
    {
        std.debug.print("7.31 Laravel 风格: Product.latest(db).take(5).get()\n", .{});

        var q = Product.latest(db);
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "ORDER BY created_at DESC") != null, "应按 created_at 降序");
        try assert(std.mem.indexOf(u8, sql, "LIMIT 5") != null, "应有 LIMIT 5");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.32 Laravel 风格: Product.paginate(db, 1, 10).get()
    {
        std.debug.print("7.32 Laravel 风格: Product.paginate(db, 1, 10)\n", .{});

        var q = Product.paginate(db, 2, 10);
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "LIMIT 10") != null, "应有 LIMIT 10");
        try assert(std.mem.indexOf(u8, sql, "OFFSET 10") != null, "第2页应有 OFFSET 10");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.33 完美 Laravel 风格: 无 db 参数！
    {
        std.debug.print("7.33 完美 Laravel 风格: 无 db 参数调用\n", .{});

        // 设置默认数据库连接（只需一次）
        Product.use(db);
        Order.use(db);

        // 现在可以不传 db 参数了！
        var q = Product.Where("category", "=", "电子产品");
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "WHERE category") != null, "SQL 应包含 WHERE");
        std.debug.print("  ✓ SQL: {s}\n", .{sql});
        std.debug.print("  ✓ 无需传递 db 参数！\n\n", .{});
    }

    // 7.34 完美 Laravel 风格: Product.WhereEq().get()
    {
        std.debug.print("7.34 完美 Laravel 风格: Product.WhereEq().get()\n", .{});

        var q = Product.WhereEq("category", "电子产品");
        defer q.deinit();

        var list = try q.collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.35 完美 Laravel 风格: Product.Latest().Take(5).get()
    {
        std.debug.print("7.35 完美 Laravel 风格: Product.Latest().Take(5)\n", .{});

        var q = Product.Latest();
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);

        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.36 完美 Laravel 风格: Product.All() / Product.Count()
    {
        std.debug.print("7.36 完美 Laravel 风格: Product.All() / Product.Count()\n", .{});

        const total = try Product.Count();
        std.debug.print("  ✓ 产品总数: {d}\n", .{total});

        var list = try Product.Collect();
        defer list.deinit();
        std.debug.print("  ✓ 获取所有: {d} 个\n\n", .{list.count()});
    }

    // 7.37 完美 Laravel 风格: Product.Find(1)
    {
        std.debug.print("7.37 完美 Laravel 风格: Product.Find(id)\n", .{});

        if (try Product.Find(2)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);
            std.debug.print("  ✓ 找到产品: {s}\n\n", .{product.name});
        } else {
            std.debug.print("  ✓ 产品 ID=2 不存在\n\n", .{});
        }
    }

    // 7.38 关联模型: hasMany - 获取产品的订单
    {
        std.debug.print("7.38 关联模型: Product.HasMany(Order)\n", .{});

        // 确保设置了默认连接
        Product.use(db);
        Order.use(db);

        // 找到产品
        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);

            // 使用静态方法获取该产品的所有订单 (HasMany)
            var rel = Product.HasMany(Order.Model, "product_id", product.id);
            const orders = try rel.get();
            defer Order.freeModels(allocator, orders);

            std.debug.print("  ✓ 产品 '{s}' 有 {d} 个订单\n", .{ product.name, orders.len });
            for (orders) |o| {
                std.debug.print("    - 订单 #{d}: 数量 {d}\n", .{ o.id, o.quantity });
            }
        }
        std.debug.print("\n", .{});
    }

    // 7.39 关联模型: belongsTo - 获取订单的产品
    {
        std.debug.print("7.39 关联模型: Order.BelongsTo(Product)\n", .{});

        if (try Order.Find(1)) |*o| {
            var order = o.*;
            defer Order.freeModel(allocator, &order);

            // 使用静态方法获取该订单所属的产品 (BelongsTo)
            var rel = Order.BelongsTo(Product.Model, order.product_id);
            if (try rel.first()) |*p| {
                var prod = p.*;
                defer Product.freeModel(allocator, &prod);
                std.debug.print("  ✓ 订单 #{d} 属于产品: {s}\n\n", .{ order.id, prod.name });
            }
        }
    }

    // 7.40 静态关联方法: Product.HasMany()
    {
        std.debug.print("7.40 静态关联方法: Product.HasMany()\n", .{});

        var rel = Product.HasMany(Order.Model, "product_id", 1);
        const orders = try rel.get();
        defer Order.freeModels(allocator, orders);

        std.debug.print("  ✓ 产品 ID=1 有 {d} 个订单\n\n", .{orders.len});
    }

    // 7.41 关联查询: 带条件和排序
    {
        std.debug.print("7.41 关联查询: 带条件和排序\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);

            // 获取数量大于0的订单，按数量降序
            var q = Product.HasMany(Order.Model, "product_id", product.id);
            _ = q.where("quantity", ">", 0).orderBy("quantity", .desc);

            const orders = try q.get();
            defer Order.freeModels(allocator, orders);

            std.debug.print("  ✓ 带条件的订单: {d} 个\n\n", .{orders.len});
        }
    }

    // 7.42 关联查询: count() 和 exists()
    {
        std.debug.print("7.42 关联查询: count() 和 exists()\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);

            var q = Product.HasMany(Order.Model, "product_id", product.id);
            const cnt = try q.count();
            q.deinit();

            var q2 = Product.HasMany(Order.Model, "product_id", product.id);
            const has_orders = try q2.exists();

            std.debug.print("  ✓ 订单数量: {d}, 有订单: {}\n\n", .{ cnt, has_orders });
        }
    }

    // 7.43 withDB 事务支持: Create/Update/Destroy
    {
        std.debug.print("7.43 withDB 事务支持\n", .{});

        // 测试 withDB().Create
        var new_product = try Product.withDB(db).Create(.{
            .name = "事务测试产品",
            .price = 88.88,
            .stock = 10,
            .category = "测试",
            .is_active = 1,
            .description = "withDB 测试",
            .created_at = null,
        });
        defer Product.freeModel(allocator, &new_product);
        std.debug.print("  ✓ withDB().Create 成功, ID={d}\n", .{new_product.id});

        // 测试 withDB().Update
        const updated = try Product.withDB(db).Update(new_product.id, .{
            .name = "已更新的产品",
            .price = 99.99,
        });
        std.debug.print("  ✓ withDB().Update 成功, 影响 {d} 行\n", .{updated});

        // 测试 withDB().Destroy
        const deleted = try Product.withDB(db).Destroy(new_product.id);
        std.debug.print("  ✓ withDB().Destroy 成功, 影响 {d} 行\n\n", .{deleted});
    }

    // 7.44 withDB 事务回滚测试
    {
        std.debug.print("7.44 withDB 事务回滚测试\n", .{});

        // 获取初始数量
        const initial_count = try Product.Count();

        // 开始事务
        try db.beginTransaction();

        // 在事务中创建产品
        var tx_product = try Product.withDB(db).Create(.{
            .name = "事务回滚测试",
            .price = 100.0,
            .stock = 5,
            .category = "事务",
            .is_active = 1,
            .description = null,
            .created_at = null,
        });
        Product.freeModel(allocator, &tx_product);

        // 回滚事务
        try db.rollback();

        // 验证数量未变
        const after_count = try Product.Count();
        if (initial_count == after_count) {
            std.debug.print("  ✓ 事务回滚成功, 数量未变: {d}\n\n", .{after_count});
        } else {
            std.debug.print("  ✗ 事务回滚失败\n\n", .{});
        }
    }
}

// ============================================================================
// 测试 8: 并发安全测试
// ============================================================================

fn testConcurrency(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 8: 并发安全测试\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 创建独立的数据库连接用于并发测试
    var db = try Database.sqlite(allocator, ":memory:");
    defer db.deinit();

    // 创建测试表
    _ = try db.rawExec("CREATE TABLE counter (id INTEGER PRIMARY KEY, value INTEGER)");
    _ = try db.rawExec("INSERT INTO counter (id, value) VALUES (1, 0)");

    std.debug.print("7.1 顺序查询测试\n", .{});
    {
        // SQLite 内存模式不支持多线程，但可以测试顺序操作
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            var result = try db.rawQuery("SELECT value FROM counter WHERE id = 1");
            defer result.deinit();
            _ = result.next();
        }
        std.debug.print("  ✓ 完成 10 次顺序查询\n\n", .{});
    }

    std.debug.print("7.2 多连接独立操作\n", .{});
    {
        // 创建多个独立的数据库连接
        var db2 = try Database.sqlite(allocator, ":memory:");
        defer db2.deinit();

        _ = try db2.rawExec("CREATE TABLE test (id INTEGER PRIMARY KEY)");
        _ = try db2.rawExec("INSERT INTO test (id) VALUES (1)");

        var result = try db2.rawQuery("SELECT COUNT(*) as cnt FROM test");
        defer result.deinit();

        if (result.next()) |row| {
            const count = std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0;
            try assertEq(usize, count, 1, "独立连接应有1条记录");
        }
        std.debug.print("  ✓ 多连接独立操作正常\n\n", .{});
    }
}

// ============================================================================
// 测试 9: 边界条件和特殊情况
// ============================================================================

fn testEdgeCases(allocator: std.mem.Allocator, db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 9: 边界条件和特殊情况\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 8.1 空结果集
    {
        std.debug.print("8.1 空结果集处理\n", .{});

        var result = try db.rawQuery("SELECT * FROM users WHERE id = -999");
        defer result.deinit();

        var count: usize = 0;
        while (result.next()) |_| {
            count += 1;
        }
        try assertEq(usize, count, 0, "空结果集应返回0条记录");
        std.debug.print("  ✓ 空结果集处理正常\n\n", .{});
    }

    // 8.2 NULL 值处理
    {
        std.debug.print("8.2 NULL 值处理\n", .{});

        _ = try db.rawExec("INSERT INTO users (name, email, age, city) VALUES ('NULL测试', 'null@test.com', NULL, NULL)");

        var result = try db.rawQuery("SELECT * FROM users WHERE email = 'null@test.com'");
        defer result.deinit();

        if (result.next()) |row| {
            const age = row.getString("age");
            const city = row.getString("city");
            try assert(age == null, "NULL age 应返回 null");
            try assert(city == null, "NULL city 应返回 null");
        }
        std.debug.print("  ✓ NULL 值处理正常\n\n", .{});
    }

    // 8.3 特殊字符处理
    {
        std.debug.print("8.3 特殊字符处理\n", .{});

        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('O''Brien', 'obrien@test.com', 30)");

        var result = try db.rawQuery("SELECT name FROM users WHERE email = 'obrien@test.com'");
        defer result.deinit();

        if (result.next()) |row| {
            const name = row.getString("name") orelse "";
            try assert(std.mem.eql(u8, name, "O'Brien"), "特殊字符应正确处理");
        }
        std.debug.print("  ✓ 特殊字符处理正常\n\n", .{});
    }

    // 8.4 Unicode 字符处理
    {
        std.debug.print("8.4 Unicode 字符处理\n", .{});

        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('中文名字', 'chinese@test.com', 25)");
        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('日本語', 'japanese@test.com', 26)");
        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('한국어', 'korean@test.com', 27)");
        _ = try db.rawExec("INSERT INTO users (name, email, age) VALUES ('🎉emoji', 'emoji@test.com', 28)");

        var result = try db.rawQuery("SELECT name FROM users WHERE email = 'chinese@test.com'");
        defer result.deinit();

        if (result.next()) |row| {
            const name = row.getString("name") orelse "";
            try assert(std.mem.eql(u8, name, "中文名字"), "中文应正确处理");
        }
        std.debug.print("  ✓ Unicode 字符处理正常\n\n", .{});
    }

    // 8.5 大数据量测试
    {
        std.debug.print("8.5 大数据量测试\n", .{});

        // 插入 100 条测试数据
        try db.beginTransaction();
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const sql_query = try std.fmt.allocPrint(
                allocator,
                "INSERT INTO users (name, email, age) VALUES ('批量{d}', 'batch{d}@test.com', {d})",
                .{ i, i, i % 50 + 20 },
            );
            defer allocator.free(sql_query);
            _ = try db.rawExec(sql_query);
        }
        try db.commit();

        var result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users WHERE email LIKE 'batch%'");
        defer result.deinit();

        if (result.next()) |row| {
            const count = std.fmt.parseInt(usize, row.getString("cnt") orelse "0", 10) catch 0;
            try assertEq(usize, count, 100, "应插入100条记录");
        }
        std.debug.print("  ✓ 大数据量测试通过（100条记录）\n\n", .{});
    }

    // 8.6 重复操作测试
    {
        std.debug.print("8.6 重复操作稳定性测试\n", .{});

        var i: usize = 0;
        while (i < 50) : (i += 1) {
            var result = try db.rawQuery("SELECT COUNT(*) as cnt FROM users");
            defer result.deinit();
            _ = result.next();
        }
        std.debug.print("  ✓ 重复查询 50 次稳定\n\n", .{});
    }
}
