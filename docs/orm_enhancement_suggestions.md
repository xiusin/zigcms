# ORM/Relations/QueryBuilder 功能增强建议

## 🎯 高优先级建议（强烈推荐）

### 1. 条件预加载（Conditional Eager Loading）

**问题**：当前预加载会加载所有关联数据，即使某些数据不需要

**建议**：支持带条件的预加载

```zig
// 只预加载状态为 active 的菜单
var q = OrmRole.Query();
_ = q.withWhere("menus", .{
    .where = &.{ .{ "status", "=", 1 } },
    .orderBy = "sort",
});
const roles = try q.get();

// 或者使用闭包风格
_ = q.withConstraint("menus", struct {
    pub fn apply(query: *MenuQuery) void {
        _ = query.where("status", "=", 1)
                 .orderBy("sort", .asc)
                 .limit(10);
    }
}.apply);
```

**收益**：
- 减少不必要的数据加载
- 提升性能 20-50%
- 更灵活的数据控制

---

### 2. 软删除（Soft Deletes）

**问题**：当前删除是物理删除，无法恢复

**建议**：支持软删除

```zig
// 模型定义
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    deleted_at: ?i64 = null,  // 软删除标记
    
    pub const soft_deletes = true;  // 启用软删除
};

// 使用
try OrmUser.Delete(1);  // 软删除（设置 deleted_at）
try OrmUser.ForceDelete(1);  // 物理删除

// 查询时自动过滤已删除
var q = OrmUser.Query();
const users = try q.get();  // 自动添加 WHERE deleted_at IS NULL

// 包含已删除
var q = OrmUser.Query();
_ = q.withTrashed();
const users = try q.get();

// 只查询已删除
var q = OrmUser.Query();
_ = q.onlyTrashed();
const users = try q.get();

// 恢复
try OrmUser.Restore(1);
```

**收益**：
- 数据安全（可恢复）
- 审计追踪
- 符合业务需求

---

### 3. 查询作用域（Query Scopes）

**问题**：常用查询条件需要重复编写

**建议**：支持可复用的查询作用域

```zig
// 模型定义
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    status: i32 = 1,
    
    // 定义作用域
    pub const scopes = .{
        .active = struct {
            pub fn apply(query: *UserQuery) void {
                _ = query.where("status", "=", 1);
            }
        },
        .recent = struct {
            pub fn apply(query: *UserQuery) void {
                _ = query.orderBy("created_at", .desc).limit(10);
            }
        },
        .byRole = struct {
            pub fn apply(query: *UserQuery, role_id: i32) void {
                _ = query.whereHas("roles", .{
                    .where = &.{ .{ "id", "=", role_id } },
                });
            }
        },
    };
};

// 使用
var q = OrmUser.Query();
_ = q.active().recent();  // 链式调用作用域
const users = try q.get();

// 带参数的作用域
var q = OrmUser.Query();
_ = q.byRole(1);
const users = try q.get();
```

**收益**：
- 代码复用
- 可读性提升
- 易于维护

---

### 4. 批量插入优化（Bulk Insert）

**问题**：当前批量插入需要循环调用 Create

**建议**：支持真正的批量插入

```zig
// 批量插入
const users = [_]User{
    .{ .name = "张三", .email = "zhangsan@example.com" },
    .{ .name = "李四", .email = "lisi@example.com" },
    .{ .name = "王五", .email = "wangwu@example.com" },
};

// 一次性插入（单条 SQL）
try OrmUser.BulkInsert(&users);
// SQL: INSERT INTO users (name, email) VALUES ('张三', '...'), ('李四', '...'), ('王五', '...')

// 批量插入并返回 ID
const ids = try OrmUser.BulkInsertGetIds(&users);

// 批量更新
try OrmUser.BulkUpdate(&[_]struct { id: i32, name: []const u8 }{
    .{ .id = 1, .name = "新名字1" },
    .{ .id = 2, .name = "新名字2" },
});
```

**收益**：
- 性能提升 10-100 倍
- 减少数据库连接开销
- 适合数据导入场景

---

### 5. 关系计数（Relation Counting）

**问题**：统计关联数据需要额外查询

**建议**：支持关系计数

```zig
// 统计关联数量
var q = OrmRole.Query();
_ = q.withCount(&.{"menus", "users"});
const roles = try q.get();

for (roles) |role| {
    std.debug.print("角色: {s}, 菜单数: {d}, 用户数: {d}\n", 
        .{role.name, role.menus_count, role.users_count});
}

// 带条件的计数
_ = q.withCount(&.{
    .{ "menus", .{ .where = &.{ .{ "status", "=", 1 } } } },
});

// 只查询计数（不加载关联数据）
var q = OrmRole.Query();
_ = q.withCount(&.{"menus"});  // 不加载 menus，只统计数量
const roles = try q.get();
```

**收益**：
- 避免加载不需要的数据
- 性能提升
- 常见需求

---

## 🔧 中优先级建议（推荐）

### 6. 子查询支持（Subquery）

```zig
// WHERE 子查询
var q = OrmUser.Query();
_ = q.whereIn("id", OrmOrder.Query()
    .select("user_id")
    .where("status", "=", "completed")
);

// SELECT 子查询
var q = OrmUser.Query();
_ = q.selectRaw("*, (SELECT COUNT(*) FROM orders WHERE user_id = users.id) as order_count");

// FROM 子查询
var subquery = OrmUser.Query().where("status", "=", 1);
var q = OrmUser.QueryFrom(subquery, "active_users");
```

**收益**：
- 复杂查询支持
- 性能优化
- SQL 灵活性

---

### 7. 事务支持增强

```zig
// 自动事务（失败自动回滚）
try db.transaction(struct {
    pub fn run(tx: *Transaction) !void {
        try OrmUser.Create(.{ .name = "张三" });
        try OrmOrder.Create(.{ .user_id = 1 });
        // 自动提交，失败自动回滚
    }
}.run);

// 嵌套事务（Savepoint）
try db.transaction(struct {
    pub fn run(tx: *Transaction) !void {
        try OrmUser.Create(.{ .name = "张三" });
        
        try tx.savepoint("sp1");
        try OrmOrder.Create(.{ .user_id = 1 });
        try tx.rollbackTo("sp1");  // 只回滚订单
    }
}.run);
```

**收益**：
- 代码简洁
- 错误处理自动化
- 支持复杂事务

---

### 8. 模型事件（Model Events）

```zig
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    
    // 定义事件钩子
    pub const events = .{
        .creating = struct {
            pub fn handle(model: *User) !void {
                // 创建前执行
                std.debug.print("Creating user: {s}\n", .{model.name});
            }
        },
        .created = struct {
            pub fn handle(model: *User) !void {
                // 创建后执行
                std.debug.print("Created user: {d}\n", .{model.id.?});
            }
        },
        .updating = struct {
            pub fn handle(model: *User) !void {
                // 更新前执行
            }
        },
        .deleting = struct {
            pub fn handle(model: *User) !void {
                // 删除前执行（可用于级联删除）
            }
        },
    };
};
```

**收益**：
- 业务逻辑解耦
- 自动化操作
- 审计日志

---

### 9. 分页优化（Cursor Pagination）

```zig
// 传统分页（有性能问题）
var q = OrmUser.Query();
_ = q.limit(20).offset(1000);  // OFFSET 1000 很慢

// 游标分页（推荐）
var q = OrmUser.Query();
_ = q.cursorPaginate(.{
    .cursor = last_id,  // 上次最后一条的 ID
    .limit = 20,
    .direction = .forward,
});
const result = try q.get();
// SQL: WHERE id > last_id ORDER BY id ASC LIMIT 20
```

**收益**：
- 大数据集性能提升
- 避免 OFFSET 性能问题
- 适合无限滚动

---

### 10. JSON 字段支持

```zig
pub const User = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    metadata: std.json.Value = .null,  // JSON 字段
    
    pub const json_fields = .{"metadata"};
};

// 查询 JSON 字段
var q = OrmUser.Query();
_ = q.whereJson("metadata->age", ">", 18);
_ = q.whereJsonContains("metadata->tags", "vip");

// 更新 JSON 字段
try OrmUser.UpdateWith(1, .{
    .metadata = .{ .object = std.StringHashMap(std.json.Value).init(...) },
});
```

**收益**：
- 灵活的数据结构
- 减少表字段
- 适合动态属性

---

## 💡 低优先级建议（可选）

### 11. 观察者模式（Observers）

```zig
// 注册观察者
const UserObserver = struct {
    pub fn created(user: *User) !void {
        // 发送欢迎邮件
    }
    
    pub fn deleted(user: *User) !void {
        // 清理相关数据
    }
};

try OrmUser.observe(UserObserver);
```

---

### 12. 全局作用域（Global Scopes）

```zig
pub const User = struct {
    pub const global_scopes = .{
        .tenant = struct {
            pub fn apply(query: *UserQuery) void {
                _ = query.where("tenant_id", "=", current_tenant_id);
            }
        },
    };
};

// 自动应用到所有查询
var q = OrmUser.Query();  // 自动添加 WHERE tenant_id = ?
```

---

### 13. 模型序列化

```zig
// 自动序列化为 JSON
const user = try OrmUser.Find(1);
const json = try user.toJson(allocator);

// 隐藏敏感字段
pub const User = struct {
    password: []const u8 = "",
    
    pub const hidden = .{"password"};
};
```

---

## 📊 优先级总结

| 功能 | 优先级 | 实现难度 | 收益 | 推荐指数 |
|------|--------|----------|------|----------|
| 条件预加载 | ⭐⭐⭐⭐⭐ | 中 | 高 | ⭐⭐⭐⭐⭐ |
| 软删除 | ⭐⭐⭐⭐⭐ | 低 | 高 | ⭐⭐⭐⭐⭐ |
| 查询作用域 | ⭐⭐⭐⭐⭐ | 中 | 高 | ⭐⭐⭐⭐⭐ |
| 批量插入 | ⭐⭐⭐⭐⭐ | 中 | 极高 | ⭐⭐⭐⭐⭐ |
| 关系计数 | ⭐⭐⭐⭐ | 中 | 中 | ⭐⭐⭐⭐ |
| 子查询 | ⭐⭐⭐⭐ | 高 | 高 | ⭐⭐⭐⭐ |
| 事务增强 | ⭐⭐⭐⭐ | 中 | 高 | ⭐⭐⭐⭐ |
| 模型事件 | ⭐⭐⭐ | 中 | 中 | ⭐⭐⭐ |
| 游标分页 | ⭐⭐⭐ | 低 | 中 | ⭐⭐⭐ |
| JSON 字段 | ⭐⭐⭐ | 中 | 中 | ⭐⭐⭐ |

---

## 🎯 建议实现顺序

### 第一批（立即实现）
1. **软删除** - 实现简单，收益高，业务常用
2. **批量插入** - 性能提升明显，实现中等
3. **查询作用域** - 代码复用，提升开发效率

### 第二批（短期实现）
4. **条件预加载** - 优化现有预加载功能
5. **关系计数** - 常见需求，实现中等
6. **游标分页** - 解决大数据集性能问题

### 第三批（中期实现）
7. **事务增强** - 提升事务易用性
8. **子查询** - 支持复杂查询
9. **模型事件** - 业务逻辑解耦

---

## 💡 实现建议

### 最小化实现原则
- 每个功能独立实现，不相互依赖
- 保持向后兼容
- 可选启用（不影响现有代码）
- 充分测试

### 代码风格
- 遵循 Zig 语言规范
- 保持 Laravel 风格 API
- 类型安全 + 编译时检查
- 内存安全 + 自动管理

---

**老铁，这些建议都是基于实际项目经验总结的，优先实现前 3 个功能就能大幅提升开发效率！🚀**
