# ZigCMS MySQL ORM

完整的 MySQL ORM 解决方案，支持真正的数据库连接。

## 安装依赖

### macOS
```bash
brew install mysql-client
```

### Ubuntu/Debian
```bash
sudo apt install libmysqlclient-dev
```

### Arch Linux
```bash
sudo pacman -S mariadb-libs
```

## 构建配置

在 `build.zig` 中添加：

```zig
const mysql = b.addModule("mysql", .{
    .root_source_file = .{ .cwd_relative = "src/services/mysql/mod.zig" },
});

// 链接 MySQL C 库
mysql.linkSystemLibrary("mysqlclient");

// macOS 需要额外的路径
if (target.result.os.tag == .macos) {
    mysql.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/lib" });
    mysql.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/mysql-client/include" });
}
```

## 使用方式

### 1. 基础连接

```zig
const mysql = @import("mysql");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 连接数据库
    var conn = try mysql.Connection.init(allocator, .{
        .host = "localhost",
        .port = 3306,
        .user = "root",
        .password = "password",
        .database = "myapp",
    });
    defer conn.deinit();

    // 执行查询
    var result = try conn.query("SELECT * FROM users LIMIT 10");
    defer result.deinit();

    while (try result.next()) |row| {
        const id = row.getInt("id") orelse 0;
        const name = row.getString("name") orelse "";
        std.debug.print("User: {d} - {s}\n", .{id, name});
    }
}
```

### 2. Eloquent 风格 ORM

```zig
const mysql = @import("mysql");

// 定义模型
const User = mysql.define(struct {
    pub const table_name = "users";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
    created_at: ?[]const u8 = null,
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 数据库管理器
    var db = try mysql.Database.init(allocator, .{
        .host = "localhost",
        .user = "root",
        .password = "password",
        .database = "myapp",
    });
    defer db.deinit();

    // 查询所有用户
    const users = try User.all(&db);
    for (users) |user| {
        std.debug.print("User: {s}\n", .{user.name});
    }

    // 条件查询
    const adults = try User.query(&db)
        .where("age", ">", 18)
        .orderBy("created_at", .desc)
        .limit(10)
        .get();

    // 查找单条
    if (try User.find(&db, 1)) |user| {
        std.debug.print("Found: {s}\n", .{user.name});
    }

    // 创建
    const new_user = try User.create(&db, .{
        .name = "张三",
        .email = "zhangsan@example.com",
        .age = 25,
    });
    std.debug.print("Created user ID: {d}\n", .{new_user.id});

    // 更新
    _ = try User.update(&db, 1, .{
        .name = "李四",
    });

    // 删除
    _ = try User.destroy(&db, 1);
}
```

### 3. 高级查询

```zig
const mysql = @import("mysql");

// 聚合查询
var query = mysql.AdvancedQueryBuilder(struct {}).init(allocator, "orders");
defer query.deinit();

_ = query
    .selectSum("amount", "total_amount")
    .selectCount("*", "order_count")
    .selectAvg("price", "avg_price")
    .where("status = ?", .{@as(i64, 1)})
    .groupBy(&.{"user_id"})
    .havingRaw("SUM(amount) > 1000")
    .orderBy("total_amount", .desc);

const sql = try query.toSql();
defer allocator.free(sql);
// SELECT SUM(amount) AS total_amount, COUNT(*) AS order_count, ...
// FROM orders WHERE status = 1 GROUP BY user_id HAVING SUM(amount) > 1000
```

### 4. 事务

```zig
var db = try mysql.Database.init(allocator, config);
defer db.deinit();

// 手动事务
try db.beginTransaction();
errdefer db.rollback() catch {};

_ = try User.create(&db, .{ .name = "用户1" });
_ = try User.create(&db, .{ .name = "用户2" });

try db.commit();
```

### 5. 预处理语句（防SQL注入）

```zig
var builder = mysql.core.QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();

_ = builder
    .where("name = ?", .{@as([]const u8, "张三")})
    .where("age > ?", .{@as(i64, 18)});

// 获取预处理语句
var stmt = try builder.buildPreparedSelect();
defer stmt.deinit();

// stmt.sql = "SELECT * FROM users WHERE name = ? AND age > ?"
// stmt.params = ["张三", 18]

// 转为可执行SQL（参数会被安全转义）
const exec_sql = try stmt.toExecutableSql(allocator);
defer allocator.free(exec_sql);
```

### 6. 模型事件

```zig
const mysql = @import("mysql");

var observer = mysql.ModelObserver.init(allocator, "User");
defer observer.deinit();

// 创建前钩子
try observer.on(.creating, struct {
    fn handler(payload: *mysql.ModelEventPayload) void {
        std.debug.print("Creating user...\n", .{});
        // 可以取消操作
        // payload.cancel();
    }
}.handler);

// 创建后钩子
try observer.on(.created, struct {
    fn handler(payload: *mysql.ModelEventPayload) void {
        std.debug.print("User created!\n", .{});
    }
}.handler);
```

## 模块结构

```
src/services/mysql/
├── mod.zig       # 模块入口
├── mysql.zig     # 核心类型和SQL构建器
├── model.zig     # Eloquent模型定义
├── advanced.zig  # 高级查询（聚合、子查询等）
├── driver.zig    # MySQL C API 驱动
├── orm.zig       # 高阶ORM（真正数据库交互）
└── README.md     # 本文档
```

## API 速览

| 功能 | 方法 |
|------|------|
| 连接 | `Connection.init()` |
| 查询 | `conn.query()`, `conn.exec()` |
| 事务 | `conn.beginTransaction()`, `conn.commit()`, `conn.rollback()` |
| 模型查询 | `Model.query()`, `Model.find()`, `Model.all()` |
| 创建 | `Model.create()` |
| 更新 | `Model.update()` |
| 删除 | `Model.destroy()` |
| 软删除 | `Model.softDelete()`, `Model.restore()` |
| 聚合 | `selectCount()`, `selectSum()`, `selectAvg()` |
| 子查询 | `whereExists()`, `fromSubquery()` |
| 预处理 | `buildPreparedSelect()`, `toExecutableSql()` |

## 测试

```bash
# 运行所有测试
zig test src/services/mysql/mod.zig

# 运行特定模块测试
zig test src/services/mysql/mysql.zig
zig test src/services/mysql/model.zig
zig test src/services/mysql/advanced.zig
```

## 集成测试（真实数据库连接）

### 1. 安装 MySQL 客户端库

```bash
# macOS
brew install mysql-client

# Ubuntu/Debian
sudo apt install libmysqlclient-dev
```

### 2. 创建测试数据库和用户

```sql
-- 连接 MySQL
mysql -u root -p

-- 创建测试数据库
CREATE DATABASE IF NOT EXISTS zigcms_test;

-- 创建测试用户
CREATE USER IF NOT EXISTS 'zigtest'@'localhost' IDENTIFIED BY 'zigtest123';
GRANT ALL PRIVILEGES ON zigcms_test.* TO 'zigtest'@'localhost';
FLUSH PRIVILEGES;
```

### 3. 运行集成测试

```bash
# 构建并运行 MySQL 集成测试
zig build test-mysql

# 或直接运行
./zig-out/bin/mysql-test
```

### 4. 预期输出

```
╔══════════════════════════════════════════════════════════╗
║          ZigCMS MySQL 集成测试                           ║
╚══════════════════════════════════════════════════════════╝

📡 连接数据库 zigtest@localhost:3306/zigcms_test...
✅ 连接成功!

📋 测试1: 创建表
   ✓ test_users 表创建成功
   ✓ test_posts 表创建成功

📝 测试2: 插入数据
   ✓ 插入 5 个用户
   ✓ 插入 4 篇文章

🔍 测试3: 查询数据
   用户列表:
   ┌────┬──────────┬─────────────────────────┬─────┐
   │ ID │ 姓名     │ 邮箱                    │ 年龄│
   ├────┼──────────┼─────────────────────────┼─────┤
   │ 1  │ 张三     │ zhangsan@example.com    │ 25  │
   │ 2  │ 李四     │ lisi@example.com        │ 30  │
   ...

╔══════════════════════════════════════════════════════════╗
║          ✅ 所有测试完成!                                ║
╚══════════════════════════════════════════════════════════╝
```

### 5. 修改测试配置

如需修改数据库连接配置，编辑 `integration_test.zig`：

```zig
const TestConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 3306,
    user: []const u8 = "zigtest",
    password: []const u8 = "zigtest123",
    database: []const u8 = "zigcms_test",
};
```

## 状态

- ✅ SQL构建器
- ✅ 预处理语句
- ✅ Eloquent模型
- ✅ 聚合函数
- ✅ 子查询
- ✅ 事件监听
- ✅ 全局作用域
- ✅ C API驱动绑定
- ✅ 高阶ORM
- 🔧 真实数据库连接（需要安装mysql-client）
