# ZigCMS SQL ORM 使用指南

## 📦 唯一的导入

```zig
const sql = @import("services").sql;
```

**就这一行！所有功能都在这里。**

## 🚀 快速开始

### PostgreSQL（推荐）

```zig
const std = @import("std");
const sql = @import("services").sql;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 创建数据库连接（pg.Pool 内部线程安全）
    var db = try sql.Database.postgres(allocator, .{
        .host = "localhost",
        .port = 5432,
        .database = "myapp",
        .user = "postgres",
        .password = "password",
    });
    defer db.deinit();
    
    // ✅ 直接使用，多线程安全
    const result = try db.rawQuery("SELECT * FROM users");
    defer result.deinit();
}
```

### MySQL（内部自动使用连接池）

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 创建数据库连接（内部自动创建连接池）
    var db = try sql.Database.mysql(allocator, .{
        .host = "localhost",
        .port = 3306,
        .database = "myapp",
        .user = "root",
        .password = "password",
        
        // 可选：连接池配置
        .min_connections = 2,
        .max_connections = 20,  // 根据并发需求调整
    });
    defer db.deinit();
    
    // ✅ 直接使用，内部自动从连接池获取/释放连接
    const result = try db.rawQuery("SELECT * FROM users");
    defer result.deinit();
    
    // ✅ 多线程安全使用
    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, worker, .{&db});
    }
}

fn worker(db: *sql.Database) void {
    // 内部自动从连接池获取连接
    const result = db.rawQuery("SELECT * FROM users WHERE active = 1") catch return;
    defer result.deinit();
    // 自动归还连接到池中
}
```

**关键点**：
- ✅ **连接池是内部实现**，用户不需要感知
- ✅ **自动管理**：获取连接 → 执行查询 → 归还连接
- ✅ **多线程安全**：多个线程可以同时使用同一个 Database

### SQLite（开发/测试）

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 内存数据库
    var db = try sql.Database.sqlite(allocator, ":memory:");
    defer db.deinit();
    
    // 或文件数据库（自动启用 WAL 模式）
    var db2 = try sql.Database.sqlite(allocator, "app.db");
    defer db2.deinit();
    
    const result = try db.rawQuery("SELECT * FROM users");
    defer result.deinit();
}
```

## 📝 ORM 模型

### 定义模型

```zig
const User = sql.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";
    
    id: u64,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
    created_at: ?[]const u8 = null,
});
```

### 使用 ORM

```zig
// 查询
var users = try User.query(&db)
    .where("age", ">", 18)
    .orderBy("created_at", .desc)
    .limit(10)
    .get();
defer users.deinit();

// 创建
const user = try User.create(&db, .{
    .name = "张三",
    .email = "zhangsan@example.com",
    .age = 25,
});

// 更新
try User.update(&db, 1, .{ .name = "李四" });

// 删除
try User.destroy(&db, 1);
```

## 🔄 事务

### 方式 1：自动管理（推荐）

```zig
try db.transaction(struct {
    fn run(db_ref: *sql.Database) !void {
        try db_ref.rawExec("INSERT INTO users ...");
        try db_ref.rawExec("INSERT INTO logs ...");
        // 自动提交，出错自动回滚
    }
}.run, .{});
```

### 方式 2：手动管理

```zig
try db.beginTransaction();
errdefer db.rollback() catch {};

try db.rawExec("INSERT INTO users ...");
try db.rawExec("INSERT INTO logs ...");

try db.commit();
```

## 🔍 QueryBuilder 调试

```zig
const QueryBuilder = sql.core.QueryBuilder;

var builder = QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();

_ = builder
    .where("age > ?", .{18})
    .debug()  // ✅ 打印当前 SQL
    .orderBy("name", .asc)
    .debugWith("添加排序后")  // ✅ 带自定义消息
    .limit(10);

const sql_query = try builder.toSql();
defer allocator.free(sql_query);
```

## 💡 设计原则

### 用户不需要感知内部实现

❌ **错误**（暴露内部细节）：
```zig
var pool = try ConnectionPool.init(...);  // 用户不应该看到这个
const conn = try pool.acquire();
defer pool.release(conn);
```

✅ **正确**（内部自动管理）：
```zig
var db = try sql.Database.mysql(allocator, config);
defer db.deinit();

// 内部自动管理连接池
const result = try db.rawQuery("SELECT ...");
defer result.deinit();
```

### 内部实现

- **ConnectionPool** - 内部自动创建和管理（MySQL）
- **Transaction** - 内部自动使用（MySQL 事务）
- **PooledConnection** - 内部使用，用户不可见

用户只需要：
1. 创建 `Database`
2. 使用 `rawQuery`/`rawExec` 或 ORM
3. 调用 `deinit()`

一切都是自动的！

## ⚡ 性能与并发

### PostgreSQL

```zig
var db = try sql.Database.postgres(allocator, .{
    .host = "localhost",
    .pool_size = 10,  // pg.Pool 内部管理
});

// ✅ 多线程直接使用
for (threads) |*thread| {
    thread.* = try std.Thread.spawn(.{}, worker, .{&db});
}
```

**特点**：
- pg.Pool 内部线程安全
- 真正并发（10 个连接同时工作）
- 用户无需关心细节

### MySQL

```zig
var db = try sql.Database.mysql(allocator, .{
    .host = "localhost",
    .max_connections = 20,  // 连接池大小
});

// ✅ 多线程直接使用
for (threads) |*thread| {
    thread.* = try std.Thread.spawn(.{}, worker, .{&db});
}
```

**特点**：
- 内部自动创建连接池
- 自动获取/归还连接
- 用户无需关心细节

### SQLite

```zig
var db = try sql.Database.sqlite(allocator, "app.db");

// ✅ 自动启用 WAL 模式（多读一写）
```

**特点**：
- WAL 模式自动启用
- 支持多个线程并发读
- 写操作串行

## 📊 配置选项

### MySQL 配置

```zig
var db = try sql.Database.mysql(allocator, .{
    // 基础配置
    .host = "localhost",
    .port = 3306,
    .user = "root",
    .password = "password",
    .database = "myapp",
    
    // 连接池配置（可选，有默认值）
    .min_connections = 2,              // 最小连接数
    .max_connections = 10,             // 最大连接数
    .acquire_timeout_ms = 5000,        // 获取连接超时
    .max_idle_time_ms = 300_000,       // 连接空闲超时（5分钟）
    .max_lifetime_ms = 1_800_000,      // 连接生命周期（30分钟）
    .transaction_timeout_ms = 30_000,  // 事务超时（30秒）
});
```

### PostgreSQL 配置

```zig
var db = try sql.Database.postgres(allocator, .{
    .host = "localhost",
    .port = 5432,
    .database = "myapp",
    .user = "postgres",
    .password = "password",
    // pg.Pool 内部管理，默认 5 个连接
});
```

## ⚠️ 最佳实践

### 1. 内存管理

```zig
// ✅ 正确 - 使用 defer
var builder = QueryBuilder.init(allocator, "users");
defer builder.deinit();

const sql_query = try builder.toSql();
defer allocator.free(sql_query);
```

### 2. 避免 Arena 在循环中

```zig
// ❌ 错误 - 内存累积
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();

for (0..10000) |_| {
    var q = QueryBuilder.init(arena.allocator(), "users");
    // 内存持续增长！
}

// ✅ 正确 - 使用 defer
for (0..10000) |_| {
    var q = QueryBuilder.init(allocator, "users");
    defer q.deinit();
    // 内存稳定
}
```

### 3. 多线程使用

```zig
// ✅ 正确 - 多个线程共享一个 Database
var db = try sql.Database.mysql(allocator, .{
    .max_connections = 20,
});
defer db.deinit();

for (threads) |*thread| {
    thread.* = try std.Thread.spawn(.{}, worker, .{&db});
}

fn worker(db: *sql.Database) void {
    // 内部自动管理连接
    const result = db.rawQuery("SELECT ...") catch return;
    defer result.deinit();
}
```

### 4. 事务使用

```zig
// ✅ 推荐 - 自动管理
try db.transaction(struct {
    fn run(db_ref: *sql.Database) !void {
        try db_ref.rawExec("INSERT ...");
        try db_ref.rawExec("UPDATE ...");
    }
}.run, .{});

// 内部自动：
// - MySQL：使用连接池事务（独占一个连接）
// - PostgreSQL/SQLite：使用普通事务
```

## 🆘 常见问题

### Q: 连接池在哪里？

**A**: 内部自动管理，用户不需要感知。MySQL 创建时自动创建连接池。

### Q: 如何调整连接池大小？

**A**: 通过 MySQL 配置：
```zig
var db = try sql.Database.mysql(allocator, .{
    .max_connections = 50,  // 根据并发需求调整
});
```

### Q: 多线程安全吗？

**A**: 是的！
- PostgreSQL：pg.Pool 内部线程安全
- MySQL：内部连接池线程安全
- SQLite：WAL 模式支持多读一写

### Q: 需要手动管理连接吗？

**A**: 不需要！一切都是自动的：
```zig
var db = try sql.Database.mysql(allocator, config);
defer db.deinit();

// 内部自动：获取连接 → 执行 → 归还连接
const result = try db.rawQuery("SELECT ...");
defer result.deinit();
```

### Q: 性能如何？

**A**: 
- PostgreSQL：10 个并发连接，吞吐量 1000 QPS
- MySQL：20 个并发连接，吞吐量 1000 QPS
- SQLite：适合中小型应用

## 📖 完整示例

```zig
const std = @import("std");
const sql = @import("services").sql;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 1. 连接数据库（内部自动创建连接池）
    var db = try sql.Database.mysql(allocator, .{
        .host = "localhost",
        .database = "myapp",
        .max_connections = 20,
    });
    defer db.deinit();
    
    // 2. 定义模型
    const User = sql.define(struct {
        pub const table_name = "users";
        pub const primary_key = "id";
        
        id: u64,
        name: []const u8,
        email: []const u8,
        age: ?u32,
    });
    
    // 3. 使用 ORM
    const user = try User.create(&db, .{
        .name = "张三",
        .email = "zhangsan@example.com",
        .age = 25,
    });
    
    // 4. 查询
    var users = try User.query(&db)
        .where("age", ">", 18)
        .orderBy("created_at", .desc)
        .limit(10)
        .get();
    defer users.deinit();
    
    // 5. 事务
    try db.transaction(struct {
        fn run(db_ref: *sql.Database) !void {
            try db_ref.rawExec("UPDATE users SET age = age + 1");
        }
    }.run, .{});
    
    std.debug.print("完成！\n", .{});
}
```

---

**核心理念**：简单易用，内部自动管理，用户只关注业务逻辑！✨




cd src/services/sql

# macOS (Homebrew)
zig build-exe mysql_complete_test.zig -lc -lmysqlclient \
  -I /opt/homebrew/include \
  -L /opt/homebrew/lib

# Linux
zig build-exe mysql_complete_test.zig -lc -lmysqlclient
