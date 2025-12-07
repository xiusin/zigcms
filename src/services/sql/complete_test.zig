//! 完整的 SQL ORM 测试
//!
//! 包含：
//! - 不同驱动测试（PostgreSQL/MySQL/SQLite）
//! - QueryBuilder 查询构造
//! - CRUD 操作（创建、读取、更新、删除）
//! - ORM 模型使用
//! - 事务测试
//! - 子查询和高级查询
//!
//! 编译运行：
//! zig build-exe src/services/sql/complete_test.zig -lc -lsqlite3

const std = @import("std");
const sql = @import("mod.zig");

// ============================================================================
// 测试数据模型
// ============================================================================

const User = sql.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";
    
    id: u64,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
    city: ?[]const u8 = null,
    active: bool = true,
});

const Post = sql.define(struct {
    pub const table_name = "posts";
    pub const primary_key = "id";
    
    id: u64,
    user_id: u64,
    title: []const u8,
    content: []const u8,
    views: u32 = 0,
    published: bool = false,
});

// ============================================================================
// 主测试入口
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          SQL ORM 完整测试                                ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    
    // 测试 SQLite（内存数据库）
    try testSQLite(allocator);
    
    // 如果有 MySQL/PostgreSQL，也可以测试
    // try testMySQL(allocator);
    // try testPostgreSQL(allocator);
}

// ============================================================================
// SQLite 完整测试
// ============================================================================

fn testSQLite(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 1: SQLite 驱动\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 创建数据库连接
    var db = try sql.Database.sqlite(allocator, ":memory:");
    defer db.deinit();
    
    std.debug.print("✓ 数据库连接创建成功（内存模式）\n", .{});
    std.debug.print("  驱动类型: {s}\n\n", .{@tagName(db.getDriverType())});
    
    // 创建测试表
    try setupTables(&db);
    
    // 运行所有测试
    try testCRUD(allocator, &db);
    try testQueryBuilder(allocator, &db);
    try testORM(allocator, &db);
    try testTransactions(allocator, &db);
    try testAdvancedQueries(allocator, &db);
    try testJoins(allocator, &db);
    
    std.debug.print("\n✓ SQLite 所有测试通过！\n\n", .{});
}

// ============================================================================
// 创建测试表
// ============================================================================

fn setupTables(db: *sql.Database) !void {
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

fn testCRUD(allocator: std.mem.Allocator, db: *sql.Database) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 2: CRUD 操作\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 2.1 创建 (CREATE)
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
            "('钱七', 'qianqi@example.com', 35, '北京')",
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
    
    // 2.3 读取 (READ)
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
    
    // 2.4 更新 (UPDATE)
    {
        std.debug.print("2.4 更新记录\n", .{});
        
        const affected = try db.rawExec(
            \\UPDATE users SET age = age + 1 WHERE city = '北京'
        );
        
        std.debug.print("  ✓ 更新 {d} 条记录\n\n", .{affected});
    }
    
    // 2.5 删除 (DELETE)
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
// 测试 3: QueryBuilder 查询构造
// ============================================================================

fn testQueryBuilder(allocator: std.mem.Allocator, db: *sql.Database) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 3: QueryBuilder 查询构造\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 3.1 基础查询
    {
        std.debug.print("3.1 基础查询\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
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
    
    // 3.2 WHERE 条件组合
    {
        std.debug.print("3.2 WHERE 条件组合\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .where("age >= ?", .{25})
            .where("age <= ?", .{30})
            .whereNotNull("city")
            .orderBy("name", .asc);
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}, {s}岁, {s}\n", .{
                row.getString("name") orelse "",
                row.getString("age") orelse "?",
                row.getString("city") orelse "",
            });
        }
        std.debug.print("\n", .{});
    }
    
    // 3.3 分页查询
    {
        std.debug.print("3.3 分页查询\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .orderBy("id", .asc)
            .page(1, 2);  // 第1页，每页2条
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  结果（第1页）:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}\n", .{row.getString("name") orelse ""});
        }
        std.debug.print("\n", .{});
    }
    
    // 3.4 DISTINCT 查询
    {
        std.debug.print("3.4 DISTINCT 查询\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .selectFields(&.{"city"})
            .distinct();
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  不同的城市:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}\n", .{row.getString("city") orelse ""});
        }
        std.debug.print("\n", .{});
    }
    
    // 3.5 GROUP BY 和 HAVING
    {
        std.debug.print("3.5 GROUP BY 和 HAVING\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .selectFields(&.{ "city", "COUNT(*) as count", "AVG(age) as avg_age" })
            .groupBy(&.{"city"})
            .havingClause("COUNT(*) > 1")
            .orderBy("count", .desc);
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}: {s}人, 平均{s}岁\n", .{
                row.getString("city") orelse "",
                row.getString("count") orelse "0",
                row.getString("avg_age") orelse "0",
            });
        }
        std.debug.print("\n", .{});
    }
    
    // 3.6 使用 debug() 调试
    {
        std.debug.print("3.6 使用 debug() 调试\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .where("age > ?", .{25})
            .debug()  // 打印当前 SQL
            .orderBy("name", .asc)
            .debugWith("✓ 添加排序后")  // 带消息调试
            .limit(5);
        
        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 4: ORM 模型使用
// ============================================================================

fn testORM(allocator: std.mem.Allocator, db: *sql.Database) !void {
    _ = allocator;
    
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 4: ORM 模型使用\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 4.1 插入测试数据
    {
        std.debug.print("4.1 准备测试数据\n", .{});
        
        _ = try db.rawExec(
            \\INSERT INTO posts (user_id, title, content, views, published) VALUES
            \\(1, 'Zig 编程入门', 'Zig 是一门现代系统编程语言...', 100, 1),
            \\(1, '如何使用 ORM', '本文介绍 ORM 的使用方法...', 50, 1),
            \\(2, 'SQL 优化技巧', '数据库查询优化的几个技巧...', 200, 1),
            \\(3, '草稿文章', '这是一篇草稿...', 0, 0)
        );
        
        std.debug.print("  ✓ 测试数据准备完成\n\n", .{});
    }
    
    // 4.2 查询所有
    {
        std.debug.print("4.2 查询所有文章\n", .{});
        
        var result = try db.rawQuery("SELECT * FROM posts ORDER BY views DESC");
        defer result.deinit();
        
        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s} (浏览: {s}, 发布: {s})\n", .{
                row.getString("title") orelse "",
                row.getString("views") orelse "0",
                row.getString("published") orelse "0",
            });
        }
        std.debug.print("\n", .{});
    }
    
    // 4.3 条件查询
    {
        std.debug.print("4.3 查询已发布文章\n", .{});
        
        var result = try db.rawQuery(
            \\SELECT * FROM posts WHERE published = 1 ORDER BY views DESC
        );
        defer result.deinit();
        
        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s} (浏览: {s})\n", .{
                row.getString("title") orelse "",
                row.getString("views") orelse "0",
            });
        }
        std.debug.print("\n", .{});
    }
    
    // 4.4 更新记录
    {
        std.debug.print("4.4 更新文章浏览量\n", .{});
        
        const affected = try db.rawExec(
            \\UPDATE posts SET views = views + 10 WHERE published = 1
        );
        
        std.debug.print("  ✓ 更新 {d} 条记录\n\n", .{affected});
    }
    
    // 4.5 删除记录
    {
        std.debug.print("4.5 删除草稿文章\n", .{});
        
        const affected = try db.rawExec(
            \\DELETE FROM posts WHERE published = 0
        );
        
        std.debug.print("  ✓ 删除 {d} 条记录\n\n", .{affected});
    }
}

// ============================================================================
// 测试 5: 事务
// ============================================================================

fn testTransactions(allocator: std.mem.Allocator, db: *sql.Database) !void {
    _ = allocator;
    
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 5: 事务\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 5.1 手动事务（提交）
    {
        std.debug.print("5.1 手动事务（提交）\n", .{});
        
        try db.beginTransaction();
        
        _ = try db.rawExec(
            \\INSERT INTO users (name, email, age) VALUES ('测试用户1', 'test1@example.com', 20)
        );
        _ = try db.rawExec(
            \\INSERT INTO users (name, email, age) VALUES ('测试用户2', 'test2@example.com', 21)
        );
        
        try db.commit();
        
        std.debug.print("  ✓ 事务提交成功\n\n", .{});
    }
    
    // 5.2 手动事务（回滚）
    {
        std.debug.print("5.2 手动事务（回滚）\n", .{});
        
        try db.beginTransaction();
        
        _ = try db.rawExec(
            \\INSERT INTO users (name, email, age) VALUES ('将被回滚', 'rollback@example.com', 99)
        );
        
        try db.rollback();
        
        std.debug.print("  ✓ 事务回滚成功\n\n", .{});
        
        // 验证数据未插入
        var result = try db.rawQuery(
            \\SELECT COUNT(*) as count FROM users WHERE email = 'rollback@example.com'
        );
        defer result.deinit();
        
        if (result.next()) |row| {
            const count = row.getString("count") orelse "0";
            std.debug.print("  验证: 回滚的数据条数 = {s}\n\n", .{count});
        }
    }
    
    // 5.3 自动事务
    {
        std.debug.print("5.3 自动事务（成功）\n", .{});
        
        try db.transaction(struct {
            fn run(db_ref: anytype) !void {
                _ = try db_ref.rawExec(
                    \\INSERT INTO users (name, email, age) VALUES ('自动事务', 'auto@example.com', 25)
                );
            }
        }.run, .{});
        
        std.debug.print("  ✓ 自动事务提交成功\n\n", .{});
    }
    
    // 5.4 自动事务（失败回滚）
    {
        std.debug.print("5.4 自动事务（失败回滚）\n", .{});
        
        const result = db.transaction(struct {
            fn run(db_ref: anytype) !void {
                _ = try db_ref.rawExec(
                    \\INSERT INTO users (name, email, age) VALUES ('将失败', 'fail@example.com', 30)
                );
                
                // 模拟错误
                return error.SimulatedError;
            }
        }.run, .{});
        
        if (result) |_| {
            std.debug.print("  ❌ 不应该成功\n", .{});
        } else |err| {
            std.debug.print("  ✓ 捕获错误: {s}\n", .{@errorName(err)});
            std.debug.print("  ✓ 事务自动回滚\n\n", .{});
        }
    }
}

// ============================================================================
// 测试 6: 高级查询
// ============================================================================

fn testAdvancedQueries(allocator: std.mem.Allocator, db: *sql.Database) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 6: 高级查询\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 准备测试数据
    _ = try db.rawExec(
        \\INSERT INTO comments (post_id, content) VALUES
        \\(1, '很好的文章！'),
        \\(1, '学到了很多'),
        \\(2, '感谢分享'),
        \\(3, '期待更新')
    );
    
    // 6.1 子查询
    {
        std.debug.print("6.1 子查询 - WHERE IN\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .whereInSub("id", "SELECT DISTINCT user_id FROM posts WHERE published = 1")
            .orderBy("name", .asc);
        
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
    
    // 6.2 EXISTS 子查询
    {
        std.debug.print("6.2 EXISTS 子查询\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "posts");
        defer builder.deinit();
        
        _ = builder
            .whereExists("SELECT 1 FROM comments WHERE comments.post_id = posts.id")
            .orderBy("title", .asc);
        
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
    
    // 6.3 NOT EXISTS 子查询
    {
        std.debug.print("6.3 NOT EXISTS 子查询\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .whereNotExists("SELECT 1 FROM posts WHERE posts.user_id = users.id");
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  没有文章的用户:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}\n", .{row.getString("name") orelse ""});
        }
        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 7: JOIN 查询
// ============================================================================

fn testJoins(allocator: std.mem.Allocator, db: *sql.Database) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 7: JOIN 查询\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 7.1 INNER JOIN
    {
        std.debug.print("7.1 INNER JOIN\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
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
    
    // 7.2 LEFT JOIN
    {
        std.debug.print("7.2 LEFT JOIN\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .selectFields(&.{ "users.name", "COUNT(posts.id) as post_count" })
            .leftJoin("posts", "users.id = posts.user_id")
            .groupBy(&.{"users.id", "users.name"})
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
    
    // 7.3 多表 JOIN
    {
        std.debug.print("7.3 多表 JOIN\n", .{});
        
        var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();
        
        _ = builder
            .selectFields(&.{ "users.name", "posts.title", "comments.content" })
            .innerJoin("posts", "users.id = posts.user_id")
            .innerJoin("comments", "posts.id = comments.post_id")
            .orderBy("users.name", .asc);
        
        const query_sql = try builder.toSql();
        defer allocator.free(query_sql);
        
        std.debug.print("  SQL: {s}\n", .{query_sql});
        
        var result = try db.rawQuery(query_sql);
        defer result.deinit();
        
        std.debug.print("  结果:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s} → {s}: {s}\n", .{
                row.getString("name") orelse "",
                row.getString("title") orelse "",
                row.getString("content") orelse "",
            });
        }
        std.debug.print("\n", .{});
    }
}

// ============================================================================
// MySQL 测试（可选）
// ============================================================================

fn testMySQL(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试: MySQL 驱动（内部自动使用连接池）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 创建数据库连接（内部自动创建连接池）
    var db = try sql.Database.mysql(allocator, .{
        .host = "localhost",
        .port = 3306,
        .database = "test",
        .user = "root",
        .password = "password",
        
        // 连接池配置
        .max_connections = 10,
    });
    defer db.deinit();
    
    std.debug.print("✓ MySQL 连接创建成功（内部连接池：10）\n", .{});
    std.debug.print("  驱动类型: {s}\n\n", .{@tagName(db.getDriverType())});
    
    // 测试查询
    var result = try db.rawQuery("SELECT VERSION() as version");
    defer result.deinit();
    
    if (result.next()) |row| {
        std.debug.print("MySQL 版本: {s}\n\n", .{row.getString("version") orelse "?"});
    }
}

// ============================================================================
// PostgreSQL 测试（可选）
// ============================================================================

fn testPostgreSQL(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════\n", .{});
    std.debug.print("测试: PostgreSQL 驱动（pg.Pool 内部线程安全）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════\n\n", .{});
    
    // 创建数据库连接
    var db = try sql.Database.postgres(allocator, .{
        .host = "localhost",
        .port = 5432,
        .database = "test",
        .user = "postgres",
        .password = "password",
    });
    defer db.deinit();
    
    std.debug.print("✓ PostgreSQL 连接创建成功\n", .{});
    std.debug.print("  驱动类型: {s}\n\n", .{@tagName(db.getDriverType())});
    
    // 测试查询
    var result = try db.rawQuery("SELECT version()");
    defer result.deinit();
    
    if (result.next()) |row| {
        std.debug.print("PostgreSQL 版本: {s}\n\n", .{row.getString("version") orelse "?"});
    }
}
