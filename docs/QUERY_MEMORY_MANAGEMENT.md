# QueryBuilder 内存管理优化方案

## 📋 问题说明

当前 QueryBuilder 使用方式：

```zig
var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();  // 必须调用

_ = builder.where("age", ">", 18)
    .orderBy("name", .asc)
    .limit(10);

const query_sql = try builder.toSql();
defer allocator.free(query_sql);  // 还要释放 SQL

var result = try db.rawQuery(query_sql);
defer result.deinit();  // 还要释放结果
```

**繁琐点**：
1. 每次都要 `defer builder.deinit()`
2. 还要 `defer allocator.free(sql)`
3. 还要 `defer result.deinit()`

## 🤔 能否完全去掉 deinit？

### 答案：不能，但可以优化

**为什么不能完全去掉？**

在 Zig 中，如果结构体内部动态分配了内存，就**必须手动释放**。这是 Zig 的核心设计哲学：

- ✅ **显式内存管理** - 内存何时分配、何时释放都是明确的
- ✅ **零隐藏代价** - 没有 GC，没有隐藏的开销
- ✅ **内存安全** - 编译器帮助你检查内存泄漏

QueryBuilder 内部使用了 `ArrayList` 存储：
- 条件列表 (`conditions`)
- 排序项 (`order_items`)
- 分组字段 (`group_fields`)
- JOIN 项 (`join_items`)
- 动态分配的 SQL 字符串

**这些必须被释放，否则会内存泄漏。**

## ✅ 最佳实践方案

### 方案 1：使用 defer（当前最佳，推荐）

```zig
// ✅ 这就是 Zig 的惯用法！
var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();

const result = try builder
    .where("age", ">", 18)
    .debug()  // 新增：可以随时调试
    .limit(10)
    .toSql();
defer allocator.free(result);
```

**优点**：
- 清晰明确
- 编译器保证释放
- 零运行时开销
- 这是 Zig 社区的标准做法

### 方案 2：使用 errdefer（处理错误）

```zig
var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();

const sql = try builder.where("age", ">", 18).toSql();
errdefer allocator.free(sql);  // 如果后续出错，释放 SQL

var result = try db.rawQuery(sql);
defer result.deinit();
allocator.free(sql);  // 查询完成，立即释放
```

### 方案 3：Arena 模式（适合批量查询）

```zig
// 为一组查询创建 arena
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();  // 一次性释放所有内存

const arena_allocator = arena.allocator();

// 多个查询共享 arena
var builder1 = sql.core.QueryBuilder(struct {}).init(arena_allocator, "users");
var builder2 = sql.core.QueryBuilder(struct {}).init(arena_allocator, "posts");

const sql1 = try builder1.where("active", "=", true).toSql();
const sql2 = try builder2.where("published", "=", true).toSql();

// 不需要单独 deinit，arena.deinit() 会一次性释放所有
```

**适用场景**：
- 一次性执行多个查询
- 临时的批量操作
- 测试代码

### 方案 4：辅助函数（即将实现）

```zig
// 提供一个便捷方法
const users = try db.queryAuto(User, struct {
    fn build(q: *QueryBuilder) void {
        _ = q.where("age", ">", 18).limit(10);
    }
});
// 内部自动管理 builder 的生命周期
```

## 🎯 新增功能：debug() 方法

现在可以在查询链中随时调试：

```zig
var builder = sql.core.QueryBuilder(struct {}).init(allocator, "users");
defer builder.deinit();

_ = builder
    .where("age", ">", 18)
    .debug()  // 打印当前 SQL
    .orderBy("name", .asc)
    .debugWith("添加排序后")  // 带自定义消息
    .limit(10);

const sql = try builder.toSql();
defer allocator.free(sql);
```

**输出**：
```
[QueryBuilder Debug] SQL: SELECT * FROM users WHERE age > 18
[QueryBuilder Debug] 添加排序后
[QueryBuilder Debug] SQL: SELECT * FROM users WHERE age > 18 ORDER BY name ASC LIMIT 10
```

## 📊 方案对比

| 方案 | 代码简洁度 | 内存效率 | 适用场景 |
|------|-----------|---------|----------|
| defer（推荐） | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 所有场景 |
| errdefer | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 错误处理 |
| Arena | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 批量操作 |
| 辅助函数 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 简单查询 |

## 💡 实际使用建议

### 简单查询 - 使用 defer

```zig
pub fn getActiveUsers(db: *Database, allocator: Allocator) ![]User {
    var builder = sql.core.QueryBuilder(User).init(allocator, "users");
    defer builder.deinit();
    
    const sql = try builder
        .where("active", "=", true)
        .orderBy("created_at", .desc)
        .toSql();
    defer allocator.free(sql);
    
    var result = try db.rawQuery(sql);
    defer result.deinit();
    
    // 处理结果...
}
```

### 复杂查询 - 使用 Arena

```zig
pub fn generateReport(db: *Database, allocator: Allocator) !Report {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    
    const a = arena.allocator();
    
    // 多个查询，不需要单独释放
    var q1 = sql.core.QueryBuilder(User).init(a, "users");
    var q2 = sql.core.QueryBuilder(Post).init(a, "posts");
    var q3 = sql.core.QueryBuilder(Comment).init(a, "comments");
    
    // 执行查询...
    
    // arena.deinit() 自动释放所有
}
```

### 调试查询 - 使用 debug()

```zig
var builder = sql.core.QueryBuilder(User).init(allocator, "users");
defer builder.deinit();

_ = builder
    .where("age", ">", 18)
    .debugWith("初始条件")
    .where("city", "=", "北京")
    .debug()
    .orderBy("created_at", .desc)
    .debug();

// 可以看到每一步的 SQL 变化
```

## ⚠️ 不推荐的做法

### ❌ 不调用 deinit

```zig
// ❌ 内存泄漏！
var builder = sql.core.QueryBuilder(User).init(allocator, "users");
const sql = try builder.toSql();
// 忘记 builder.deinit() - 内存泄漏！
```

### ❌ 过早释放

```zig
var builder = sql.core.QueryBuilder(User).init(allocator, "users");
const sql = try builder.toSql();
builder.deinit();  // ❌ 过早释放
// sql 可能包含指向已释放内存的指针！
```

### ❌ 多次释放

```zig
var builder = sql.core.QueryBuilder(User).init(allocator, "users");
defer builder.deinit();
builder.deinit();  // ❌ 双重释放！
```

## 📝 总结

### Zig 的内存管理哲学

> "如果你分配了内存，你就负责释放它。"

这看起来"繁琐"，但带来了：
- ✅ **性能** - 零 GC 开销
- ✅ **可预测性** - 明确的内存行为
- ✅ **安全性** - 编译器检查
- ✅ **控制力** - 完全控制内存

### 实践建议

1. **使用 `defer`** - 这是 Zig 的惯用法，简洁且安全
2. **使用 Arena** - 批量操作时简化内存管理
3. **使用 `debug()`** - 随时查看 SQL，方便调试
4. **遵循 RAII 模式** - init/deinit 成对出现

### 这不是 bug，这是特性！

在其他语言中（Go、Python、JavaScript），你看不到内存管理，因为：
- Go：有 GC，定期停顿
- Python：引用计数 + GC，性能开销
- JavaScript：GC，不可控

在 Zig 中，你看得到内存管理，因为：
- ✅ 零隐藏开销
- ✅ 可预测的性能
- ✅ 适合系统编程

**这种"繁琐"是 Zig 的核心价值所在！**

## 🚀 已实现的改进

### 1. debug() 方法 ✅

```zig
_ = builder
    .where("age", ">", 18)
    .debug()  // 新增
    .limit(10);
```

### 2. debugWith() 方法 ✅

```zig
_ = builder
    .where("age", ">", 18)
    .debugWith("年龄过滤后")  // 新增
    .limit(10);
```

### 3. 文档改进 ✅

- 详细说明内存管理原理
- 提供多种使用模式
- 最佳实践建议

## 🔜 未来可能的改进

### 可选的辅助 API（如果需要）

```zig
// 选项 A：回调模式
const users = try db.queryWith(User, struct {
    fn build(q: *QueryBuilder) !void {
        _ = q.where("age", ">", 18);
    }
}, struct {
    fn execute(sql: []const u8, db_ref: *Database) ![]User {
        // 执行并返回
    }
});

// 选项 B：builder 工厂
const users = try db.queryBuilder(User)
    .where("age", ">", 18)
    .executeAndFree();  // 自动管理生命周期
```

**但这会增加复杂度，当前的 defer 模式已经足够好。**

---

**结论**：当前的 `defer builder.deinit()` 模式是 Zig 的最佳实践，简洁、安全、高效。新增的 `debug()` 方法让调试更方便。这就是最优解！
