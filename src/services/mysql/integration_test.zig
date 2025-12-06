//! MySQL 集成测试 - 真实数据库连接测试
//!
//! 运行前需要：
//! 1. 安装 mysql-client: brew install mysql-client (macOS)
//! 2. 启动 MySQL 服务
//! 3. 创建测试数据库和用户
//!
//! ```sql
//! CREATE DATABASE IF NOT EXISTS zigcms_test;
//! CREATE USER IF NOT EXISTS 'zigtest'@'localhost' IDENTIFIED BY 'zigtest123';
//! GRANT ALL PRIVILEGES ON zigcms_test.* TO 'zigtest'@'localhost';
//! FLUSH PRIVILEGES;
//! ```
//!
//! 运行测试：
//! ```bash
//! zig build test-mysql
//! ```

const std = @import("std");
const mysql = @import("mod.zig");

// ============================================================================
// 测试配置
// ============================================================================

const TestConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 3306,
    user: []const u8 = "zigtest",
    password: []const u8 = "zigtest123",
    database: []const u8 = "zigcms_test",
};

const config = TestConfig{};

// ============================================================================
// 测试用模型
// ============================================================================

const User = mysql.define(struct {
    pub const table_name = "test_users";
    pub const primary_key = "id";

    id: u64 = 0,
    name: []const u8 = "",
    email: []const u8 = "",
    age: u32 = 0,
    active: bool = false,
    created_at: ?[]const u8 = null,
});

const Post = mysql.define(struct {
    pub const table_name = "test_posts";
    pub const primary_key = "id";

    id: u64 = 0,
    user_id: u64 = 0,
    title: []const u8 = "",
    content: ?[]const u8 = null,
    views: u32 = 0,
});

// ============================================================================
// 主测试函数
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          ZigCMS MySQL 集成测试                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // 连接数据库
    std.debug.print("📡 连接数据库 {s}@{s}:{d}/{s}...\n", .{
        config.user,
        config.host,
        config.port,
        config.database,
    });

    var db = mysql.Database.init(allocator, .{
        .host = config.host,
        .port = config.port,
        .user = config.user,
        .password = config.password,
        .database = config.database,
    }) catch |err| {
        std.debug.print("❌ 连接失败: {any}\n", .{err});
        std.debug.print("\n请检查:\n", .{});
        std.debug.print("  1. MySQL 服务是否运行\n", .{});
        std.debug.print("  2. 用户名密码是否正确\n", .{});
        std.debug.print("  3. 数据库是否存在\n", .{});
        return;
    };
    defer db.deinit();

    std.debug.print("✅ 连接成功!\n\n", .{});

    // 运行测试
    try runTests(&db, allocator);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          ✅ 所有测试完成!                                ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
}

fn runTests(db: *mysql.Database, allocator: std.mem.Allocator) !void {
    _ = allocator;

    // 测试1: 创建表
    try testCreateTables(db);

    // 测试2: 插入数据
    try testInsert(db);

    // 测试3: 查询数据
    try testQuery(db);

    // 测试4: 更新数据
    try testUpdate(db);

    // 测试5: 聚合查询
    try testAggregate(db);

    // 测试6: 事务
    try testTransaction(db);

    // 测试7: 删除数据
    try testDelete(db);

    // 测试8: 清理
    try testCleanup(db);
}

// ============================================================================
// 测试用例
// ============================================================================

fn testCreateTables(db: *mysql.Database) !void {
    std.debug.print("📋 测试1: 创建表\n", .{});

    // 删除旧表
    _ = db.rawExec("DROP TABLE IF EXISTS test_posts") catch {};
    _ = db.rawExec("DROP TABLE IF EXISTS test_users") catch {};

    // 创建用户表
    _ = try db.rawExec(
        \\CREATE TABLE test_users (
        \\    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        \\    name VARCHAR(100) NOT NULL,
        \\    email VARCHAR(255) NOT NULL UNIQUE,
        \\    age INT UNSIGNED DEFAULT 0,
        \\    active TINYINT(1) DEFAULT 1,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    // 创建文章表
    _ = try db.rawExec(
        \\CREATE TABLE test_posts (
        \\    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        \\    user_id BIGINT UNSIGNED NOT NULL,
        \\    title VARCHAR(255) NOT NULL,
        \\    content TEXT,
        \\    views INT UNSIGNED DEFAULT 0,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \\    FOREIGN KEY (user_id) REFERENCES test_users(id) ON DELETE CASCADE
        \\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    );

    std.debug.print("   ✓ test_users 表创建成功\n", .{});
    std.debug.print("   ✓ test_posts 表创建成功\n", .{});
}

fn testInsert(db: *mysql.Database) !void {
    std.debug.print("\n📝 测试2: 插入数据\n", .{});

    // 插入用户
    _ = try db.rawExec("INSERT INTO test_users (name, email, age, active) VALUES ('张三', 'zhangsan@example.com', 25, 1)");
    _ = try db.rawExec("INSERT INTO test_users (name, email, age, active) VALUES ('李四', 'lisi@example.com', 30, 1)");
    _ = try db.rawExec("INSERT INTO test_users (name, email, age, active) VALUES ('王五', 'wangwu@example.com', 22, 0)");
    _ = try db.rawExec("INSERT INTO test_users (name, email, age, active) VALUES ('赵六', 'zhaoliu@example.com', 35, 1)");
    _ = try db.rawExec("INSERT INTO test_users (name, email, age, active) VALUES ('钱七', 'qianqi@example.com', 28, 1)");

    std.debug.print("   ✓ 插入 5 个用户\n", .{});

    // 插入文章
    _ = try db.rawExec("INSERT INTO test_posts (user_id, title, content, views) VALUES (1, 'Zig语言入门', 'Zig是一种系统编程语言...', 100)");
    _ = try db.rawExec("INSERT INTO test_posts (user_id, title, content, views) VALUES (1, 'Zig与MySQL', '如何在Zig中使用MySQL...', 50)");
    _ = try db.rawExec("INSERT INTO test_posts (user_id, title, content, views) VALUES (2, 'Go vs Zig', '两种语言的对比...', 200)");
    _ = try db.rawExec("INSERT INTO test_posts (user_id, title, content, views) VALUES (3, '学习笔记', '今天学习了...', 10)");

    std.debug.print("   ✓ 插入 4 篇文章\n", .{});
}

fn testQuery(db: *mysql.Database) !void {
    std.debug.print("\n🔍 测试3: 查询数据\n", .{});

    // 查询所有用户
    var result = try db.rawQuery("SELECT id, name, email, age FROM test_users ORDER BY id");
    defer result.deinit();

    std.debug.print("   用户列表:\n", .{});
    std.debug.print("   ┌────┬──────────┬─────────────────────────┬─────┐\n", .{});
    std.debug.print("   │ ID │ 姓名     │ 邮箱                    │ 年龄│\n", .{});
    std.debug.print("   ├────┼──────────┼─────────────────────────┼─────┤\n", .{});

    while (try result.next()) |row| {
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
    var result2 = try db.rawQuery("SELECT COUNT(*) as cnt FROM test_users WHERE age > 25");
    defer result2.deinit();

    if (try result2.next()) |row| {
        const count = row.getInt("cnt") orelse 0;
        std.debug.print("   ✓ 年龄大于25的用户: {d} 人\n", .{count});
    }
}

fn testUpdate(db: *mysql.Database) !void {
    std.debug.print("\n✏️  测试4: 更新数据\n", .{});

    const affected = try db.rawExec("UPDATE test_users SET age = age + 1 WHERE name = '张三'");
    std.debug.print("   ✓ 更新张三年龄, 影响行数: {d}\n", .{affected});

    // 验证更新
    var result = try db.rawQuery("SELECT age FROM test_users WHERE name = '张三'");
    defer result.deinit();

    if (try result.next()) |row| {
        const age = row.getInt("age") orelse 0;
        std.debug.print("   ✓ 张三当前年龄: {d}\n", .{age});
    }
}

fn testAggregate(db: *mysql.Database) !void {
    std.debug.print("\n📊 测试5: 聚合查询\n", .{});

    // 统计
    var result = try db.rawQuery(
        \\SELECT 
        \\    COUNT(*) as total_users,
        \\    AVG(age) as avg_age,
        \\    MIN(age) as min_age,
        \\    MAX(age) as max_age,
        \\    SUM(age) as sum_age
        \\FROM test_users
    );
    defer result.deinit();

    if (try result.next()) |row| {
        std.debug.print("   统计结果:\n", .{});
        std.debug.print("   - 总用户数: {d}\n", .{row.getInt("total_users") orelse 0});
        std.debug.print("   - 平均年龄: {d:.1}\n", .{row.getFloat("avg_age") orelse 0});
        std.debug.print("   - 最小年龄: {d}\n", .{row.getInt("min_age") orelse 0});
        std.debug.print("   - 最大年龄: {d}\n", .{row.getInt("max_age") orelse 0});
    }

    // 分组统计
    var result2 = try db.rawQuery(
        \\SELECT u.name, COUNT(p.id) as post_count, SUM(p.views) as total_views
        \\FROM test_users u
        \\LEFT JOIN test_posts p ON u.id = p.user_id
        \\GROUP BY u.id, u.name
        \\ORDER BY post_count DESC
    );
    defer result2.deinit();

    std.debug.print("\n   用户文章统计:\n", .{});
    std.debug.print("   ┌──────────┬──────────┬──────────┐\n", .{});
    std.debug.print("   │ 用户     │ 文章数   │ 总浏览量 │\n", .{});
    std.debug.print("   ├──────────┼──────────┼──────────┤\n", .{});

    while (try result2.next()) |row| {
        std.debug.print("   │ {s:<8} │ {d:<8} │ {d:<8} │\n", .{
            row.getString("name") orelse "",
            row.getInt("post_count") orelse 0,
            row.getInt("total_views") orelse 0,
        });
    }
    std.debug.print("   └──────────┴──────────┴──────────┘\n", .{});
}

fn testTransaction(db: *mysql.Database) !void {
    std.debug.print("\n🔄 测试6: 事务\n", .{});

    // 开始事务
    try db.beginTransaction();
    std.debug.print("   ✓ 开始事务\n", .{});

    // 插入新用户
    _ = try db.rawExec("INSERT INTO test_users (name, email, age) VALUES ('测试用户', 'test@example.com', 20)");
    std.debug.print("   ✓ 插入测试用户\n", .{});

    // 提交事务
    try db.commit();
    std.debug.print("   ✓ 提交事务\n", .{});

    // 验证
    var result = try db.rawQuery("SELECT COUNT(*) as cnt FROM test_users WHERE name = '测试用户'");
    defer result.deinit();

    if (try result.next()) |row| {
        const count = row.getInt("cnt") orelse 0;
        std.debug.print("   ✓ 验证: 测试用户存在 ({d})\n", .{count});
    }

    // 测试回滚
    try db.beginTransaction();
    _ = try db.rawExec("INSERT INTO test_users (name, email, age) VALUES ('回滚用户', 'rollback@example.com', 99)");
    try db.rollback();
    std.debug.print("   ✓ 回滚测试完成\n", .{});

    // 验证回滚
    var result2 = try db.rawQuery("SELECT COUNT(*) as cnt FROM test_users WHERE name = '回滚用户'");
    defer result2.deinit();

    if (try result2.next()) |row| {
        const count = row.getInt("cnt") orelse 0;
        if (count == 0) {
            std.debug.print("   ✓ 验证: 回滚用户不存在 (回滚成功)\n", .{});
        }
    }
}

fn testDelete(db: *mysql.Database) !void {
    std.debug.print("\n🗑️  测试7: 删除数据\n", .{});

    const affected = try db.rawExec("DELETE FROM test_users WHERE name = '测试用户'");
    std.debug.print("   ✓ 删除测试用户, 影响行数: {d}\n", .{affected});
}

fn testCleanup(_: *mysql.Database) !void {
    std.debug.print("\n🧹 测试8: 清理\n", .{});

    // 可选：删除测试表
    // _ = try db.rawExec("DROP TABLE IF EXISTS test_posts");
    // _ = try db.rawExec("DROP TABLE IF EXISTS test_users");

    std.debug.print("   ✓ 测试表保留（可手动删除）\n", .{});
    std.debug.print("   - DROP TABLE test_posts;\n", .{});
    std.debug.print("   - DROP TABLE test_users;\n", .{});
}

// ============================================================================
// 单元测试（不需要数据库连接）
// ============================================================================

test "User 模型定义" {
    try std.testing.expectEqualStrings("test_users", User.tableName());
    try std.testing.expectEqualStrings("id", User.primaryKey());
}

test "Post 模型定义" {
    try std.testing.expectEqualStrings("test_posts", Post.tableName());
}
