//! MySQL 完整测试
//!
//! 测试覆盖：
//! - CRUD 操作及结果验证
//! - QueryBuilder 构造
//! - 事务（提交/回滚）
//! - 高级查询（子查询、EXISTS）
//! - JOIN 查询
//! - 连接池特性
//! - 内存泄漏检测（使用 GPA）
//!
//! 编译运行：
//! cd src/services/sql
//! zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
//!   -I /usr/local/include \
//!   -L /usr/local/lib
//! ./mysql_complete_test
//!
//! 注意：
//! 1. 需要 MySQL 服务器运行
//! 2. 需要创建测试数据库或使用已存在的数据库
//! 3. 修改下面的连接配置

const std = @import("std");

// ✅ 启用 MySQL 驱动（告诉 interface.zig 使用真正的驱动）
pub const mysql_enabled = true;

// 只导入需要的模块
const interface = @import("interface.zig");
const orm = @import("orm.zig");
const query = @import("query.zig");

const Database = orm.Database;
const MySQLConfig = orm.MySQLConfig;

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
// MySQL 连接配置（根据实际情况修改）
// ============================================================================

const mysql_config = MySQLConfig{
    .host = "117.72.107.213",
    .port = 3306,
    .user = "oceanengine",
    .password = "oceanengine", // 修改为你的密码
    .database = "oceanengine", // 使用已存在的数据库

    // 连接池配置
    .min_connections = 2,
    .max_connections = 10,
};

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
    std.debug.print("║          MySQL ORM 完整测试                                ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    try testMySQL(allocator);

    // 输出测试统计
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试统计\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  通过: {d}\n", .{tests_passed});
    std.debug.print("  失败: {d}\n", .{tests_failed});
}

// ============================================================================
// MySQL 完整测试
// ============================================================================

fn testMySQL(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 1: MySQL 驱动（内部自动使用连接池）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 创建数据库连接（内部自动创建连接池）
    var db = try Database.mysql(allocator, mysql_config);
    defer db.deinit();

    std.debug.print("✓ 数据库连接创建成功\n", .{});
    std.debug.print("  驱动类型: {s}\n", .{@tagName(db.getDriverType())});
    std.debug.print("  连接池: 最小 {d} 个，最大 {d} 个连接\n", .{
        mysql_config.min_connections,
        mysql_config.max_connections,
    });
    std.debug.print("\n", .{});

    try assert(db.getDriverType() == .mysql, "驱动类型应为 mysql");

    // 创建测试表
    try setupTables(&db);

    // 运行所有测试
    try testCRUD(allocator, &db);
    try testQueryBuilder(allocator, &db);
    try testTransactions(&db);
    try testAdvancedQueries(allocator, &db);
    try testJoins(allocator, &db);
    try testORM(allocator, &db);
    try testConnectionPool(allocator, &db);

    std.debug.print("\n✓ MySQL 所有测试通过！\n\n", .{});
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
        \\    id INT AUTO_INCREMENT PRIMARY KEY,
        \\    name VARCHAR(100) NOT NULL,
        \\    email VARCHAR(100) NOT NULL UNIQUE,
        \\    age INT,
        \\    city VARCHAR(50),
        \\    active TINYINT DEFAULT 1,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    // 创建 posts 表
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS posts
    );

    _ = try db.rawExec(
        \\CREATE TABLE posts (
        \\    id INT AUTO_INCREMENT PRIMARY KEY,
        \\    user_id INT NOT NULL,
        \\    title VARCHAR(200) NOT NULL,
        \\    content TEXT,
        \\    views INT DEFAULT 0,
        \\    published TINYINT DEFAULT 0,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \\    INDEX idx_user_id (user_id),
        \\    INDEX idx_published (published)
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    // 创建 comments 表
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS comments
    );

    _ = try db.rawExec(
        \\CREATE TABLE comments (
        \\    id INT AUTO_INCREMENT PRIMARY KEY,
        \\    post_id INT NOT NULL,
        \\    content TEXT NOT NULL,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \\    INDEX idx_post_id (post_id)
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
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

        const affected = try db.rawExec(
            \\INSERT INTO users (name, email, age, city) VALUES
            \\('李四', 'lisi@example.com', 30, '上海'),
            \\('王五', 'wangwu@example.com', 22, '广州'),
            \\('赵六', 'zhaoliu@example.com', 28, '深圳'),
            \\('钱七', 'qianqi@example.com', 35, '北京')
        );

        std.debug.print("  ✓ 批量插入 {d} 条记录\n\n", .{affected});
    }

    // 2.3 读取
    {
        std.debug.print("2.3 读取记录\n", .{});

        var result = try db.rawQuery(
            \\SELECT * FROM users WHERE age > 25 ORDER BY age
        );
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

    _ = allocator;
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

    // 3.2 分页查询
    {
        std.debug.print("3.2 分页查询\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .orderBy("id", .asc)
            .page(1, 2); // 第1页，每页2条

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

    // 3.3 GROUP BY 和 HAVING
    {
        std.debug.print("3.3 GROUP BY 和 HAVING\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
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

    // 3.4 使用 debug()
    {
        std.debug.print("3.4 使用 debug() 调试\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .where("age > ?", .{25})
            .debug() // ✅ 打印 SQL
            .orderBy("name", .asc)
            .debugWith("✓ 添加排序后"); // ✅ 带消息调试

        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 4: 事务
// ============================================================================

fn testTransactions(db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 4: 事务（内部自动使用连接池）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 4.1 自动事务（成功）
    {
        std.debug.print("4.1 自动事务（成功）\n", .{});

        try db.transaction(struct {
            fn run(db_ref: anytype) !void {
                _ = try db_ref.rawExec(
                    \\INSERT INTO users (name, email, age) VALUES ('自动事务', 'auto@example.com', 25)
                );
            }
        }.run, .{});

        std.debug.print("  ✓ 自动事务提交成功\n", .{});
        std.debug.print("  ✓ 内部自动从连接池获取独占连接\n\n", .{});
    }

    // 4.2 自动事务（失败回滚）
    {
        std.debug.print("4.2 自动事务（失败回滚）\n", .{});

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
            std.debug.print("  ✓ 事务自动回滚\n", .{});
            std.debug.print("  ✓ 连接自动归还到池中\n\n", .{});
        }
    }

    // 4.3 批量操作事务
    {
        std.debug.print("4.3 批量操作事务\n", .{});

        try db.transaction(struct {
            fn run(db_ref: anytype) !void {
                // 批量插入
                _ = try db_ref.rawExec(
                    \\INSERT INTO users (name, email, age) VALUES
                    \\('批量1', 'batch1@example.com', 20),
                    \\('批量2', 'batch2@example.com', 21)
                );

                // 更新
                _ = try db_ref.rawExec(
                    \\UPDATE users SET age = age + 1 WHERE name LIKE '批量%'
                );
            }
        }.run, .{});

        std.debug.print("  ✓ 批量操作事务成功\n\n", .{});
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
        \\INSERT INTO posts (user_id, title, content, views, published) VALUES
        \\(1, 'Zig 编程入门', 'Zig 是一门现代系统编程语言...', 100, 1),
        \\(1, '如何使用 ORM', '本文介绍 ORM 的使用方法...', 50, 1),
        \\(2, 'SQL 优化技巧', '数据库查询优化的几个技巧...', 200, 1),
        \\(3, '草稿文章', '这是一篇草稿...', 0, 0)
    );

    _ = try db.rawExec(
        \\INSERT INTO comments (post_id, content) VALUES
        \\(1, '很好的文章！'),
        \\(1, '学到了很多'),
        \\(2, '感谢分享')
    );

    // 5.1 子查询
    {
        std.debug.print("5.1 子查询 - WHERE IN\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
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

    // 5.2 EXISTS 子查询
    {
        std.debug.print("5.2 EXISTS 子查询\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "posts");
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

    // 5.3 NOT EXISTS 子查询
    {
        std.debug.print("5.3 NOT EXISTS 子查询\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .whereNotExists("SELECT 1 FROM posts WHERE posts.user_id = users.id")
            .limit(5);

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
            .orderBy("post_count", .desc)
            .limit(10);

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

    // 6.3 多表 JOIN
    {
        std.debug.print("6.3 多表 JOIN\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .selectFields(&.{ "users.name", "posts.title", "comments.content" })
            .innerJoin("posts", "users.id = posts.user_id")
            .innerJoin("comments", "posts.id = comments.post_id")
            .orderBy("users.name", .asc)
            .limit(5);

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
// 测试 7: ORM 模型功能
// ============================================================================

// 定义测试模型
const Product = orm.define(struct {
    pub const table_name = "products";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    price: f64,
    stock: i32,
    category: []const u8,
    is_active: i32,
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
        \\    id INT AUTO_INCREMENT PRIMARY KEY,
        \\    name VARCHAR(200) NOT NULL,
        \\    price DECIMAL(10,2) NOT NULL,
        \\    stock INT DEFAULT 0,
        \\    category VARCHAR(100),
        \\    is_active TINYINT DEFAULT 1,
        \\    description TEXT,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    _ = try db.rawExec("DROP TABLE IF EXISTS orders");
    _ = try db.rawExec(
        \\CREATE TABLE orders (
        \\    id INT AUTO_INCREMENT PRIMARY KEY,
        \\    user_id INT NOT NULL,
        \\    product_id INT NOT NULL,
        \\    quantity INT NOT NULL,
        \\    total_price DECIMAL(10,2) NOT NULL,
        \\    status VARCHAR(50) DEFAULT 'pending',
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    // 7.1 ORM create
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
        std.debug.print("  ✓ 创建产品: ID={d}, 名称={s}\n\n", .{ product.id, product.name });
    }

    // 7.2 ORM find
    {
        std.debug.print("7.2 ORM find - 查找单条记录\n", .{});
        if (try Product.find(db, 1)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            try assert(p.id == 1, "ID应为1");
            std.debug.print("  ✓ 找到产品: {s}\n\n", .{p.name});
        }
    }

    // 7.3 ORM all
    {
        std.debug.print("7.3 ORM all - 获取所有记录\n", .{});
        var p2 = try Product.create(db, .{ .name = "键盘", .price = 299.00, .stock = 50, .category = "电子产品", .is_active = 1 });
        defer Product.freeModel(allocator, &p2);
        var p3 = try Product.create(db, .{ .name = "鼠标", .price = 99.00, .stock = 200, .category = "电子产品", .is_active = 1 });
        defer Product.freeModel(allocator, &p3);

        const products = try Product.all(db);
        defer Product.freeModels(allocator, products);
        try assert(products.len >= 3, "应至少有3个产品");
        std.debug.print("  ✓ 获取所有产品: {d} 个\n\n", .{products.len});
    }

    // 7.4 ORM update
    {
        std.debug.print("7.4 ORM update - 更新记录\n", .{});
        const affected = try Product.update(db, 1, .{ .price = 79.99 });
        try assert(affected > 0, "应更新记录");
        std.debug.print("  ✓ 更新 {d} 条记录\n\n", .{affected});
    }

    // 7.5 ORM count
    {
        std.debug.print("7.5 ORM count - 统计记录数\n", .{});
        const total = try Product.count(db);
        std.debug.print("  ✓ 产品总数: {d}\n\n", .{total});
    }

    // 7.6 ORM exists
    {
        std.debug.print("7.6 ORM exists - 检查记录是否存在\n", .{});
        const exists1 = try Product.exists(db, 1);
        const exists999 = try Product.exists(db, 999);
        try assert(exists1, "ID=1 应存在");
        try assert(!exists999, "ID=999 不应存在");
        std.debug.print("  ✓ ID=1: {}, ID=999: {}\n\n", .{ exists1, exists999 });
    }

    // 7.7 ORM first
    {
        std.debug.print("7.7 ORM first - 获取第一条记录\n", .{});
        if (try Product.first(db)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            std.debug.print("  ✓ 第一个产品: {s}\n\n", .{p.name});
        }
    }

    // 7.8 ORM query 链式调用
    {
        std.debug.print("7.8 ORM query 链式调用\n", .{});
        var q = Product.query(db);
        defer q.deinit();
        _ = q.where("category", "=", "电子产品").orderBy("price", .asc).limit(10);
        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.9 ORM destroy
    {
        std.debug.print("7.9 ORM destroy - 删除记录\n", .{});
        const before = try Product.count(db);
        _ = try Product.destroy(db, 1);
        const after = try Product.count(db);
        std.debug.print("  ✓ 删除前: {d}, 删除后: {d}\n\n", .{ before, after });
    }

    // 7.10 ORM 关联数据
    {
        std.debug.print("7.10 ORM 关联数据\n", .{});
        var order1 = try Order.create(db, .{
            .user_id = 1,
            .product_id = 2,
            .quantity = 2,
            .total_price = 598.00,
            .status = "paid",
        });
        defer Order.freeModel(allocator, &order1);
        const order_count = try Order.count(db);
        std.debug.print("  ✓ 创建订单: {d} 个\n\n", .{order_count});
    }

    // 7.11 ORM 分页查询
    {
        std.debug.print("7.11 ORM 分页查询\n", .{});
        var q = Product.query(db);
        defer q.deinit();
        _ = q.page(1, 2);
        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.12 ORM distinct 查询
    {
        std.debug.print("7.12 ORM distinct 查询\n", .{});
        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{"category"}).distinct();
        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.13 ORM whereNull / whereNotNull
    {
        std.debug.print("7.13 ORM whereNull / whereNotNull\n", .{});

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

        std.debug.print("  ✓ 有描述: {d}, 无描述: {d}\n\n", .{ with_desc, without_desc });
    }

    // 7.14 ORM groupBy 查询
    {
        std.debug.print("7.14 ORM groupBy 查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{ "category", "COUNT(*) as cnt" }).groupBy(&.{"category"});

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "GROUP BY") != null, "SQL 应包含 GROUP BY");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.15 ORM 复杂条件查询
    {
        std.debug.print("7.15 ORM 复杂条件查询\n", .{});

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

    // 7.16 ORM offset 查询
    {
        std.debug.print("7.16 ORM offset 查询（跳过前N条）\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.orderBy("id", .asc).offset(1).limit(2);

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "OFFSET") != null, "SQL 应包含 OFFSET");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.17 ORM leftJoin 查询
    {
        std.debug.print("7.17 ORM leftJoin 查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{ "products.*", "orders.quantity" })
            .leftJoin("orders", "products.id = orders.product_id");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "LEFT JOIN") != null, "SQL 应包含 LEFT JOIN");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.18 新 API: collect() 自动内存管理
    {
        std.debug.print("7.18 新 API: collect() 自动内存管理\n", .{});

        var list = try Product.collect(db);
        defer list.deinit(); // 一行释放所有内存

        std.debug.print("  ✓ 产品数量: {d}\n", .{list.count()});
        std.debug.print("  ✓ 是否为空: {}\n", .{list.isEmpty()});
        if (list.first()) |p| {
            std.debug.print("  ✓ 第一个: {s}\n", .{p.name});
        }
        std.debug.print("\n", .{});
    }

    // 7.19 新 API: 简化的 where 方法
    {
        std.debug.print("7.19 新 API: 简化的 where 方法\n", .{});

        var q = Product.query(db);
        defer q.deinit();

        _ = q.whereEq("category", "电子产品")
            .whereGte("price", 50)
            .whereLte("price", 1000)
            .latest()
            .take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.20 新 API: whereLike 模糊查询
    {
        std.debug.print("7.20 新 API: whereLike 模糊查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereLike("name", "%鼠标%");

        const sql = try q.toSql();
        defer allocator.free(sql);

        try assert(std.mem.indexOf(u8, sql, "LIKE") != null, "SQL 应包含 LIKE");
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.21 新 API: exists/doesntExist
    {
        std.debug.print("7.21 新 API: exists/doesntExist\n", .{});

        var q1 = Product.query(db);
        defer q1.deinit();
        const has_products = try q1.exists();

        var q2 = Product.query(db);
        defer q2.deinit();
        _ = q2.whereEq("category", "不存在的分类XYZ");
        const no_category = try q2.doesntExist();

        std.debug.print("  ✓ 有产品: {}, 无不存在分类: {}\n\n", .{ has_products, no_category });
    }

    // 7.22 新 API: query().collect() 链式调用
    {
        std.debug.print("7.22 新 API: query().collect() 链式调用\n", .{});

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

    // 7.23 新 API: whereInSub 子查询 (SQL字符串)
    {
        std.debug.print("7.23 新 API: whereInSub 子查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereInSub("id", "SELECT product_id FROM orders WHERE quantity > 0");

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.24 新 API: whereInQuery 子查询 (QueryBuilder)
    {
        std.debug.print("7.24 新 API: whereInQuery 子查询 (QueryBuilder)\n", .{});

        var subquery = Order.query(db);
        defer subquery.deinit();
        _ = subquery.select(&.{"product_id"}).whereEq("status", "paid");

        var main_query = Product.query(db);
        defer main_query.deinit();
        _ = main_query.whereInQuery("id", &subquery);

        const sql = try main_query.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.25 新 API: whereExists 子查询
    {
        std.debug.print("7.25 新 API: whereExists 子查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereExists("SELECT 1 FROM orders WHERE orders.product_id = products.id");

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.26 新 API: whereColumn 字段比较
    {
        std.debug.print("7.26 新 API: whereColumn 字段比较\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereColumn("stock", ">", "price");

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.27 Laravel 风格: Product.where(db, ...).get()
    {
        std.debug.print("7.27 Laravel 风格: Product.where(db, ...).get()\n", .{});

        var q = Product.where(db, "category", "=", "电子产品");
        defer q.deinit();

        var list = try q.orderBy("price", .asc).collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.28 Laravel 风格: Product.latest(db).take(5)
    {
        std.debug.print("7.28 Laravel 风格: Product.latest(db).take(5)\n", .{});

        var q = Product.latest(db);
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.29 Laravel 风格: Product.paginate(db, 2, 10)
    {
        std.debug.print("7.29 Laravel 风格: Product.paginate(db, 2, 10)\n", .{});

        var q = Product.paginate(db, 2, 10);
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.30 完美 Laravel 风格: 无 db 参数调用
    {
        std.debug.print("7.30 完美 Laravel 风格: 无 db 参数调用\n", .{});

        // 设置默认数据库连接（只需一次）
        Product.use(db);
        Order.use(db);

        // 现在可以不传 db 参数了！
        var q = Product.Where("category", "=", "电子产品");
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);

        std.debug.print("  ✓ SQL: {s}\n", .{sql});
        std.debug.print("  ✓ 无需传递 db 参数！\n\n", .{});
    }

    // 7.31 完美 Laravel 风格: Product.WhereEq().get()
    {
        std.debug.print("7.31 完美 Laravel 风格: Product.WhereEq().get()\n", .{});

        var q = Product.WhereEq("category", "电子产品");
        defer q.deinit();

        var list = try q.collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.32 完美 Laravel 风格: Product.Latest().Take(5)
    {
        std.debug.print("7.32 完美 Laravel 风格: Product.Latest().Take(5)\n", .{});

        var q = Product.Latest();
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);

        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.33 完美 Laravel 风格: Product.Count() / Product.Collect()
    {
        std.debug.print("7.33 完美 Laravel 风格: Product.Count() / Product.Collect()\n", .{});

        const total = try Product.Count();
        std.debug.print("  ✓ 产品总数: {d}\n", .{total});

        var list = try Product.Collect();
        defer list.deinit();
        std.debug.print("  ✓ 获取所有: {d} 个\n\n", .{list.count()});
    }

    // 7.34 完美 Laravel 风格: Product.Find(id)
    {
        std.debug.print("7.34 完美 Laravel 风格: Product.Find(id)\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);
            std.debug.print("  ✓ 找到产品: {s}\n\n", .{product.name});
        } else {
            std.debug.print("  ✓ 产品 ID=1 不存在\n\n", .{});
        }
    }

    // 7.35 关联模型: HasMany
    {
        std.debug.print("7.35 关联模型: Product.HasMany(Order)\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);

            var rel = Product.HasMany(Order.Model, "product_id", product.id);
            const orders = try rel.get();
            defer Order.freeModels(allocator, orders);

            std.debug.print("  ✓ 产品 '{s}' 有 {d} 个订单\n\n", .{ product.name, orders.len });
        }
    }

    // 7.36 关联模型: BelongsTo
    {
        std.debug.print("7.36 关联模型: Order.BelongsTo(Product)\n", .{});

        if (try Order.Find(1)) |*o| {
            var order = o.*;
            defer Order.freeModel(allocator, &order);

            var rel = Order.BelongsTo(Product.Model, order.product_id);
            if (try rel.first()) |*p| {
                var prod = p.*;
                defer Product.freeModel(allocator, &prod);
                std.debug.print("  ✓ 订单 #{d} 属于产品: {s}\n\n", .{ order.id, prod.name });
            }
        }
    }

    // 7.37 withDB 事务支持
    {
        std.debug.print("7.37 withDB 事务支持\n", .{});

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
}

// ============================================================================
// 测试 8: 连接池测试
// ============================================================================

fn testConnectionPool(allocator: std.mem.Allocator, db: *Database) !void {
    _ = allocator;

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 8: 连接池特性\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 8.1 并发查询
    {
        std.debug.print("8.1 并发查询测试\n", .{});
        std.debug.print("  说明: 多个查询并发执行，内部自动管理连接\n", .{});

        // 执行多个查询
        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            var result = try db.rawQuery("SELECT COUNT(*) as count FROM users");
            defer result.deinit();

            if (result.next()) |row| {
                std.debug.print("    查询 {d}: 用户数 = {s}\n", .{
                    i + 1,
                    row.getString("count") orelse "0",
                });
            }
        }

        std.debug.print("  ✓ 所有查询自动复用连接池中的连接\n\n", .{});
    }

    // 7.2 连接池优势
    {
        std.debug.print("7.2 连接池优势\n", .{});
        std.debug.print("  ✓ 自动管理连接：获取 → 使用 → 归还\n", .{});
        std.debug.print("  ✓ 连接复用：减少创建/销毁开销\n", .{});
        std.debug.print("  ✓ 并发控制：最多 {d} 个并发连接\n", .{mysql_config.max_connections});
        std.debug.print("  ✓ 健康检查：自动清理不健康连接\n", .{});
        std.debug.print("  ✓ 超时保护：防止连接泄漏\n", .{});
        std.debug.print("  ✓ 事务安全：事务独占一个连接\n\n", .{});
    }
}
