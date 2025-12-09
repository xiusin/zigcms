//! PostgreSQL 完整测试
//!
//! 编译运行：
//! cd src/services/sql
//! zig build (必须通过 build.zig，因为需要 pg 模块)
//!
//! 或者创建临时的 build 脚本来编译
//!
//! 注意：
//! 1. 需要 PostgreSQL 服务器运行
//! 2. 需要创建测试数据库: CREATE DATABASE test_zigcms;
//! 3. 修改下面的连接配置

const std = @import("std");

// 只导入需要的模块
const interface = @import("interface.zig");
const orm = @import("orm.zig");
const query = @import("query.zig");

const Database = orm.Database;

// ============================================================================
// PostgreSQL 连接配置（根据实际情况修改）
// ============================================================================

const pgsql_config = interface.PostgreSQLConfig{
    .host = "localhost",
    .port = 5432,
    .user = "postgres",
    .password = "", // 修改为你的密码
    .database = "test_zigcms",
    .connect_timeout = 10,
};

// ============================================================================
// 主测试入口
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║          PostgreSQL ORM 完整测试                         ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    try testPostgreSQL(allocator);
}

// ============================================================================
// PostgreSQL 完整测试
// ============================================================================

fn testPostgreSQL(allocator: std.mem.Allocator) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 1: PostgreSQL 驱动（pg.Pool 内部线程安全）\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 创建数据库连接
    var db = try Database.postgres(allocator, pgsql_config);
    defer db.deinit();

    std.debug.print("✓ 数据库连接创建成功\n", .{});
    std.debug.print("  驱动类型: {s}\n", .{@tagName(db.getDriverType())});
    std.debug.print("  连接池: pg.Pool 内部管理\n", .{});
    std.debug.print("  特性: 支持 SERIAL、JSON、数组、全文搜索\n\n", .{});

    // 创建测试表
    try setupTables(&db);

    // 运行所有测试
    try testCRUD(allocator, &db);
    try testQueryBuilder(allocator, &db);
    try testTransactions(&db);
    try testAdvancedQueries(allocator, &db);
    try testJoins(allocator, &db);
    try testORM(allocator, &db);
    try testPostgreSQLFeatures(allocator, &db);

    std.debug.print("\n✓ PostgreSQL 所有测试通过！\n\n", .{});
}

// ============================================================================
// 创建测试表
// ============================================================================

fn setupTables(db: *Database) !void {
    std.debug.print("准备测试环境...\n", .{});

    // 创建 users 表（使用 SERIAL）
    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS comments CASCADE
    );

    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS posts CASCADE
    );

    _ = try db.rawExec(
        \\DROP TABLE IF EXISTS users CASCADE
    );

    _ = try db.rawExec(
        \\CREATE TABLE users (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(100) NOT NULL,
        \\    email VARCHAR(100) NOT NULL UNIQUE,
        \\    age INTEGER,
        \\    city VARCHAR(50),
        \\    active BOOLEAN DEFAULT true,
        \\    metadata JSONB,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    );

    // 创建 posts 表
    _ = try db.rawExec(
        \\CREATE TABLE posts (
        \\    id SERIAL PRIMARY KEY,
        \\    user_id INTEGER NOT NULL REFERENCES users(id),
        \\    title VARCHAR(200) NOT NULL,
        \\    content TEXT,
        \\    tags TEXT[],
        \\    views INTEGER DEFAULT 0,
        \\    published BOOLEAN DEFAULT false,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    );

    // 创建 comments 表
    _ = try db.rawExec(
        \\CREATE TABLE comments (
        \\    id SERIAL PRIMARY KEY,
        \\    post_id INTEGER NOT NULL REFERENCES posts(id),
        \\    content TEXT NOT NULL,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    );

    // 创建索引
    _ = try db.rawExec(
        \\CREATE INDEX idx_posts_user_id ON posts(user_id)
    );

    _ = try db.rawExec(
        \\CREATE INDEX idx_posts_published ON posts(published)
    );

    _ = try db.rawExec(
        \\CREATE INDEX idx_comments_post_id ON comments(post_id)
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

    // 2.1 创建（使用 RETURNING）
    {
        std.debug.print("2.1 创建记录（PostgreSQL RETURNING 子句）\n", .{});

        var result = try db.rawQuery(
            \\INSERT INTO users (name, email, age, city) 
            \\VALUES ('张三', 'zhangsan@example.com', 25, '北京')
            \\RETURNING id, name
        );
        defer result.deinit();

        if (result.next()) |row| {
            std.debug.print("  ✓ 插入成功，ID: {s}, 名字: {s}\n\n", .{
                row.getString("id") orelse "?",
                row.getString("name") orelse "?",
            });
        }
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
        std.debug.print("3.2 分页查询（PostgreSQL OFFSET）\n", .{});

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

    // 3.3 使用 debug()
    {
        std.debug.print("3.3 使用 debug() 调试\n", .{});

        var builder = query.QueryBuilder(struct {}).init(allocator, "users");
        defer builder.deinit();

        _ = builder
            .where("age > ?", .{25})
            .debug()
            .orderBy("name", .asc)
            .debugWith("✓ 添加排序后");

        std.debug.print("\n", .{});
    }
}

// ============================================================================
// 测试 4: 事务
// ============================================================================

fn testTransactions(db: *Database) !void {
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 4: 事务\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 4.1 手动事务（提交）
    {
        std.debug.print("4.1 手动事务（提交）\n", .{});

        try db.beginTransaction();
        _ = try db.rawExec(
            \\INSERT INTO users (name, email, age) VALUES ('事务1', 'tx1@example.com', 20)
        );
        try db.commit();

        std.debug.print("  ✓ 事务提交成功\n\n", .{});
    }

    // 4.2 手动事务（回滚）
    {
        std.debug.print("4.2 手动事务（回滚）\n", .{});

        try db.beginTransaction();
        _ = try db.rawExec(
            \\INSERT INTO users (name, email, age) VALUES ('回滚', 'rollback@example.com', 99)
        );
        try db.rollback();

        std.debug.print("  ✓ 事务回滚成功\n\n", .{});
    }

    // 4.3 自动事务
    {
        std.debug.print("4.3 自动事务（成功）\n", .{});

        try db.transaction(struct {
            fn run(db_ref: anytype) !void {
                _ = try db_ref.rawExec(
                    \\INSERT INTO users (name, email, age) VALUES ('自动', 'auto@example.com', 25)
                );
            }
        }.run, .{});

        std.debug.print("  ✓ 自动事务成功\n\n", .{});
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
        \\INSERT INTO posts (user_id, title, content, views, published, tags) VALUES
        \\(1, 'Zig 编程入门', 'Zig 是一门现代系统编程语言...', 100, true, ARRAY['zig', '编程']),
        \\(1, '如何使用 ORM', '本文介绍 ORM 的使用方法...', 50, true, ARRAY['orm', '数据库']),
        \\(2, 'SQL 优化技巧', '数据库查询优化的几个技巧...', 200, true, ARRAY['sql', '优化']),
        \\(3, '草稿文章', '这是一篇草稿...', 0, false, ARRAY['草稿'])
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
            .whereInSub("id", "SELECT DISTINCT user_id FROM posts WHERE published = true")
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
            .where("posts.published = ?", .{true})
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
    _ = try db.rawExec("DROP TABLE IF EXISTS orders CASCADE");
    _ = try db.rawExec("DROP TABLE IF EXISTS products CASCADE");

    _ = try db.rawExec(
        \\CREATE TABLE products (
        \\    id SERIAL PRIMARY KEY,
        \\    name VARCHAR(200) NOT NULL,
        \\    price DECIMAL(10,2) NOT NULL,
        \\    stock INTEGER DEFAULT 0,
        \\    category VARCHAR(100),
        \\    is_active INTEGER DEFAULT 1,
        \\    description TEXT,
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
    );

    _ = try db.rawExec(
        \\CREATE TABLE orders (
        \\    id SERIAL PRIMARY KEY,
        \\    user_id INTEGER NOT NULL,
        \\    product_id INTEGER NOT NULL,
        \\    quantity INTEGER NOT NULL,
        \\    total_price DECIMAL(10,2) NOT NULL,
        \\    status VARCHAR(50) DEFAULT 'pending',
        \\    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        \\)
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

        std.debug.print("  ✓ 创建产品: ID={d}, 名称={s}\n\n", .{ product.id, product.name });
    }

    // 7.2 ORM find
    {
        std.debug.print("7.2 ORM find - 查找单条记录\n", .{});
        if (try Product.find(db, 1)) |*product| {
            var p = product.*;
            defer Product.freeModel(allocator, &p);
            std.debug.print("  ✓ 找到产品: {s}\n\n", .{p.name});
        }
    }

    // 7.3 ORM find 不存在
    {
        std.debug.print("7.3 ORM find - 查找不存在的记录\n", .{});
        const result = try Product.find(db, 999);
        std.debug.print("  ✓ ID=999 返回 {s}\n\n", .{if (result == null) "null" else "found"});
    }

    // 7.4 ORM all
    {
        std.debug.print("7.4 ORM all - 获取所有记录\n", .{});
        var p2 = try Product.create(db, .{ .name = "键盘", .price = 299.00, .stock = 50, .category = "电子产品", .is_active = 1 });
        defer Product.freeModel(allocator, &p2);
        var p3 = try Product.create(db, .{ .name = "鼠标", .price = 99.00, .stock = 200, .category = "电子产品", .is_active = 1, .description = "无线鼠标" });
        defer Product.freeModel(allocator, &p3);
        var p4 = try Product.create(db, .{ .name = "显示器", .price = 1999.00, .stock = 30, .category = "电子产品", .is_active = 1, .description = "4K 显示器" });
        defer Product.freeModel(allocator, &p4);

        const products = try Product.all(db);
        defer Product.freeModels(allocator, products);
        std.debug.print("  ✓ 获取所有产品: {d} 个\n\n", .{products.len});
    }

    // 7.5 ORM update
    {
        std.debug.print("7.5 ORM update - 更新记录\n", .{});
        const affected = try Product.update(db, 1, .{ .price = 79.99, .stock = 150 });
        std.debug.print("  ✓ 更新 {d} 条记录\n\n", .{affected});
    }

    // 7.6 ORM count
    {
        std.debug.print("7.6 ORM count - 统计记录数\n", .{});
        const total = try Product.count(db);
        std.debug.print("  ✓ 产品总数: {d}\n\n", .{total});
    }

    // 7.7 ORM exists
    {
        std.debug.print("7.7 ORM exists - 检查记录是否存在\n", .{});
        const exists1 = try Product.exists(db, 1);
        const exists999 = try Product.exists(db, 999);
        std.debug.print("  ✓ ID=1: {}, ID=999: {}\n\n", .{ exists1, exists999 });
    }

    // 7.8 ORM first
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

    // 7.11 ORM destroy
    {
        std.debug.print("7.11 ORM destroy - 删除记录\n", .{});
        const before = try Product.count(db);
        _ = try Product.destroy(db, 1);
        const after = try Product.count(db);
        std.debug.print("  ✓ 删除前: {d}, 删除后: {d}\n\n", .{ before, after });
    }

    // 7.12 ORM 关联数据
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
        std.debug.print("  ✓ 创建订单: {d} 个\n\n", .{order_count});
    }

    // 7.13 ORM 分页查询
    {
        std.debug.print("7.13 ORM 分页查询\n", .{});
        var q = Product.query(db);
        defer q.deinit();
        _ = q.page(1, 2);
        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.14 ORM distinct 查询
    {
        std.debug.print("7.14 ORM distinct 查询\n", .{});
        var q = Product.query(db);
        defer q.deinit();
        _ = q.select(&.{"category"}).distinct();
        const sql = try q.toSql();
        defer allocator.free(sql);
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
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.19 新 API: collect() 自动内存管理
    {
        std.debug.print("7.19 新 API: collect() 自动内存管理\n", .{});

        var list = try Product.collect(db);
        defer list.deinit(); // 一行释放所有内存

        std.debug.print("  ✓ 产品数量: {d}\n", .{list.count()});
        std.debug.print("  ✓ 是否为空: {}\n", .{list.isEmpty()});
        if (list.first()) |p| {
            std.debug.print("  ✓ 第一个: {s}\n", .{p.name});
        }
        std.debug.print("\n", .{});
    }

    // 7.20 新 API: 简化的 where 方法
    {
        std.debug.print("7.20 新 API: 简化的 where 方法\n", .{});

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

    // 7.21 新 API: whereLike 模糊查询
    {
        std.debug.print("7.21 新 API: whereLike 模糊查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereLike("name", "%鼠标%");

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.22 新 API: exists/doesntExist
    {
        std.debug.print("7.22 新 API: exists/doesntExist\n", .{});

        var q1 = Product.query(db);
        defer q1.deinit();
        const has_products = try q1.exists();

        var q2 = Product.query(db);
        defer q2.deinit();
        _ = q2.whereEq("category", "不存在的分类XYZ");
        const no_category = try q2.doesntExist();

        std.debug.print("  ✓ 有产品: {}, 无不存在分类: {}\n\n", .{ has_products, no_category });
    }

    // 7.23 新 API: query().collect() 链式调用
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
        std.debug.print("7.24 新 API: whereInSub 子查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereInSub("id", "SELECT product_id FROM orders WHERE quantity > 0");

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.25 新 API: whereInQuery 子查询 (QueryBuilder)
    {
        std.debug.print("7.25 新 API: whereInQuery 子查询 (QueryBuilder)\n", .{});

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

    // 7.26 新 API: whereExists 子查询
    {
        std.debug.print("7.26 新 API: whereExists 子查询\n", .{});

        var q = Product.query(db);
        defer q.deinit();
        _ = q.whereExists("SELECT 1 FROM orders WHERE orders.product_id = products.id");

        const sql = try q.toSql();
        defer allocator.free(sql);
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
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.28 Laravel 风格: Product.where(db, ...).get()
    {
        std.debug.print("7.28 Laravel 风格: Product.where(db, ...).get()\n", .{});

        var q = Product.where(db, "category", "=", "电子产品");
        defer q.deinit();

        var list = try q.orderBy("price", .asc).collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.29 Laravel 风格: Product.latest(db).take(5)
    {
        std.debug.print("7.29 Laravel 风格: Product.latest(db).take(5)\n", .{});

        var q = Product.latest(db);
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.30 Laravel 风格: Product.paginate(db, 2, 10)
    {
        std.debug.print("7.30 Laravel 风格: Product.paginate(db, 2, 10)\n", .{});

        var q = Product.paginate(db, 2, 10);
        defer q.deinit();

        const sql = try q.toSql();
        defer allocator.free(sql);
        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.31 完美 Laravel 风格: 无 db 参数调用
    {
        std.debug.print("7.31 完美 Laravel 风格: 无 db 参数调用\n", .{});

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

    // 7.32 完美 Laravel 风格: Product.WhereEq().get()
    {
        std.debug.print("7.32 完美 Laravel 风格: Product.WhereEq().get()\n", .{});

        var q = Product.WhereEq("category", "电子产品");
        defer q.deinit();

        var list = try q.collect();
        defer list.deinit();

        std.debug.print("  ✓ 电子产品: {d} 个\n\n", .{list.count()});
    }

    // 7.33 完美 Laravel 风格: Product.Latest().Take(5)
    {
        std.debug.print("7.33 完美 Laravel 风格: Product.Latest().Take(5)\n", .{});

        var q = Product.Latest();
        defer q.deinit();
        _ = q.take(5);

        const sql = try q.toSql();
        defer allocator.free(sql);

        std.debug.print("  ✓ SQL: {s}\n\n", .{sql});
    }

    // 7.34 完美 Laravel 风格: Product.Count() / Product.Collect()
    {
        std.debug.print("7.34 完美 Laravel 风格: Product.Count() / Product.Collect()\n", .{});

        const total = try Product.Count();
        std.debug.print("  ✓ 产品总数: {d}\n", .{total});

        var list = try Product.Collect();
        defer list.deinit();
        std.debug.print("  ✓ 获取所有: {d} 个\n\n", .{list.count()});
    }

    // 7.35 完美 Laravel 风格: Product.Find(id)
    {
        std.debug.print("7.35 完美 Laravel 风格: Product.Find(id)\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);
            std.debug.print("  ✓ 找到产品: {s}\n\n", .{product.name});
        } else {
            std.debug.print("  ✓ 产品 ID=1 不存在\n\n", .{});
        }
    }

    // 7.36 关联模型: HasMany
    {
        std.debug.print("7.36 关联模型: Product.HasMany(Order)\n", .{});

        if (try Product.Find(1)) |*p| {
            var product = p.*;
            defer Product.freeModel(allocator, &product);

            var rel = Product.HasMany(Order.Model, "product_id", product.id);
            const orders = try rel.get();
            defer Order.freeModels(allocator, orders);

            std.debug.print("  ✓ 产品 '{s}' 有 {d} 个订单\n\n", .{ product.name, orders.len });
        }
    }

    // 7.37 关联模型: BelongsTo
    {
        std.debug.print("7.37 关联模型: Order.BelongsTo(Product)\n", .{});

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

    // 7.38 withDB 事务支持
    {
        std.debug.print("7.38 withDB 事务支持\n", .{});

        // 测试 withDB().Create
        var new_product = try Product.withDB(db).Create(.{
            .name = "事务测试产品",
            .price = 88.88,
            .stock = 10,
            .category = "测试",
            .is_active = true,
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
// 测试 8: PostgreSQL 特有功能
// ============================================================================

fn testPostgreSQLFeatures(allocator: std.mem.Allocator, db: *Database) !void {
    _ = allocator;

    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("测试 8: PostgreSQL 特有功能\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // 8.1 SERIAL 自增
    {
        std.debug.print("8.1 SERIAL 主键（自动递增）\n", .{});

        var result = try db.rawQuery(
            \\INSERT INTO users (name, email, age)
            \\VALUES ('SERIAL测试', 'serial@example.com', 30)
            \\RETURNING id
        );
        defer result.deinit();

        if (result.next()) |row| {
            std.debug.print("  ✓ 自动生成 ID: {s}\n\n", .{row.getString("id") orelse "?"});
        }
    }

    // 8.2 数组类型
    {
        std.debug.print("8.2 数组类型（tags）\n", .{});

        var result = try db.rawQuery(
            \\SELECT title, tags FROM posts WHERE published = true LIMIT 3
        );
        defer result.deinit();

        std.debug.print("  文章标签:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}: {s}\n", .{
                row.getString("title") orelse "",
                row.getString("tags") orelse "[]",
            });
        }
        std.debug.print("\n", .{});
    }

    // 8.3 JSONB 类型
    {
        std.debug.print("8.3 JSONB 类型（元数据）\n", .{});

        _ = try db.rawExec(
            \\UPDATE users SET metadata = '{"level": "VIP", "points": 100}'::jsonb
            \\WHERE name = '张三'
        );

        var result = try db.rawQuery(
            \\SELECT name, metadata FROM users WHERE metadata IS NOT NULL
        );
        defer result.deinit();

        std.debug.print("  用户元数据:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - {s}: {s}\n", .{
                row.getString("name") orelse "",
                row.getString("metadata") orelse "{}",
            });
        }
        std.debug.print("\n", .{});
    }

    // 8.4 RETURNING 子句
    {
        std.debug.print("8.4 RETURNING 子句（批量插入返回）\n", .{});

        var result = try db.rawQuery(
            \\INSERT INTO users (name, email, age) VALUES
            \\('批量A', 'batchA@example.com', 25),
            \\('批量B', 'batchB@example.com', 26)
            \\RETURNING id, name
        );
        defer result.deinit();

        std.debug.print("  插入的记录:\n", .{});
        while (result.next()) |row| {
            std.debug.print("    - ID: {s}, 名字: {s}\n", .{
                row.getString("id") orelse "?",
                row.getString("name") orelse "",
            });
        }
        std.debug.print("\n", .{});
    }

    // 8.5 BOOLEAN 类型
    {
        std.debug.print("8.5 BOOLEAN 类型（true/false）\n", .{});

        var result = try db.rawQuery(
            \\SELECT title, published FROM posts ORDER BY id LIMIT 3
        );
        defer result.deinit();

        std.debug.print("  文章发布状态:\n", .{});
        while (result.next()) |row| {
            const published = row.getString("published") orelse "false";
            std.debug.print("    - {s}: {s}\n", .{
                row.getString("title") orelse "",
                if (std.mem.eql(u8, published, "t") or std.mem.eql(u8, published, "true")) "已发布" else "草稿",
            });
        }
        std.debug.print("\n", .{});
    }

    // 8.6 性能优势
    {
        std.debug.print("8.6 PostgreSQL 优势\n", .{});
        std.debug.print("  ✓ pg.Pool: 内部线程安全，无需外部连接池\n", .{});
        std.debug.print("  ✓ SERIAL: 自动递增主键\n", .{});
        std.debug.print("  ✓ JSONB: 高性能 JSON 存储和查询\n", .{});
        std.debug.print("  ✓ 数组类型: 原生支持数组\n", .{});
        std.debug.print("  ✓ RETURNING: 插入后立即返回数据\n", .{});
        std.debug.print("  ✓ 全文搜索: 内置全文搜索引擎\n", .{});
        std.debug.print("  ✓ 外键约束: 数据完整性保证\n\n", .{});
    }
}
