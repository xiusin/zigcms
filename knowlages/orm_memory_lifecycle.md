# ORM 查询结果的内存生命周期管理

## 问题场景

在 ZigCMS 管理员列表接口中，角色名称（`role_name`、`role_names`、`role_text`）返回给前端时显示为乱码（`\udcaa\udcaa...`），但数据库中的数据是正常的中文。

## 问题根源

### 错误代码模式

```zig
var roles = std.ArrayListUnmanaged(models.SysRole){};
defer roles.deinit(self.allocator);

if (role_ids.items.len > 0) {
    var role_q = OrmRole.Query();
    defer role_q.deinit();
    
    const role_rows = role_q.get() catch |err| return base.send_error(req, err);
    defer OrmRole.freeModels(role_rows);  // ⚠️ 这里会释放 role_rows 的内存
    
    // ❌ 错误：直接复制对象，字符串字段指向已释放的内存
    for (role_rows) |role| {
        roles.append(self.allocator, role) catch {};
    }
}

// 后续使用 roles.items 时，role.role_name 指向的内存已被释放
for (roles.items) |role| {
    const name = role.role_name;  // ❌ 悬垂指针，读取到垃圾数据
}
```

### 问题分析

1. **ORM 查询返回的对象生命周期**：
   - `role_q.get()` 返回的 `role_rows` 由 ORM 内部分配器管理
   - `defer OrmRole.freeModels(role_rows)` 会释放所有字符串字段的内存

2. **浅拷贝导致悬垂指针**：
   - `roles.append(self.allocator, role)` 只复制结构体本身
   - 字符串字段（`[]const u8`）是切片，只复制指针和长度
   - 原始内存被 ORM 释放后，这些指针变成悬垂指针

3. **乱码产生机制**：
   - 访问悬垂指针时读取到已释放内存中的随机数据
   - UTF-8 解码失败，显示为 `\udcaa` 等替代字符

## 正确解决方案

### 深拷贝字符串字段

```zig
var roles = std.ArrayListUnmanaged(models.SysRole){};
defer {
    // 释放深拷贝的字符串
    for (roles.items) |role| {
        self.allocator.free(role.role_name);
        self.allocator.free(role.role_key);
        self.allocator.free(role.remark);
    }
    roles.deinit(self.allocator);
}

if (role_ids.items.len > 0) {
    var role_q = OrmRole.Query();
    defer role_q.deinit();
    
    const role_rows = role_q.get() catch |err| return base.send_error(req, err);
    defer OrmRole.freeModels(role_rows);
    
    // ✅ 正确：深拷贝所有字符串字段
    for (role_rows) |role| {
        const role_copy = models.SysRole{
            .id = role.id,
            .role_name = self.allocator.dupe(u8, role.role_name) catch role.role_name,
            .role_key = self.allocator.dupe(u8, role.role_key) catch role.role_key,
            .sort = role.sort,
            .status = role.status,
            .remark = self.allocator.dupe(u8, role.remark) catch role.remark,
            .data_scope = role.data_scope,
            .created_at = role.created_at,
            .updated_at = role.updated_at,
        };
        roles.append(self.allocator, role_copy) catch {};
    }
}

// 现在可以安全使用 roles.items
for (roles.items) |role| {
    const name = role.role_name;  // ✅ 指向独立内存，安全访问
}
```

## 核心原则

### 1. ORM 查询结果的所有权规则

```zig
// ORM 拥有查询结果的内存
const rows = query.get() catch |err| return err;
defer OrmModel.freeModels(rows);  // ORM 负责释放

// 如果需要在 defer 之后使用数据，必须深拷贝
```

### 2. 字符串字段的深拷贝

```zig
// ❌ 错误：浅拷贝
const copy = original;  // 只复制指针

// ✅ 正确：深拷贝
const copy = try allocator.dupe(u8, original);  // 分配新内存并复制数据
defer allocator.free(copy);  // 记得释放
```

### 3. 结构体复制的陷阱

```zig
const User = struct {
    id: i32,
    name: []const u8,  // 切片类型
};

const user1 = User{ .id = 1, .name = "Alice" };
const user2 = user1;  // ❌ 浅拷贝，user2.name 和 user1.name 指向同一内存

// 如果 user1.name 的内存被释放，user2.name 变成悬垂指针
```

## 排查方法

### 1. 检查数据库原始数据

```bash
mysql -h host -P port -u user -ppassword database \
  -e "SELECT id, role_name FROM sys_role WHERE id = 3;"
```

如果数据库数据正常，问题在应用层。

### 2. 检查 ORM 查询和释放时机

```zig
const rows = query.get() catch |err| return err;
defer OrmModel.freeModels(rows);  // ⚠️ 注意这个 defer 的作用域

// 在这个作用域内使用 rows 是安全的
for (rows) |row| {
    std.debug.print("{s}\n", .{row.name});  // ✅ 安全
}

// 如果将 rows 的数据传递到作用域外，必须深拷贝
```

### 3. 使用内存检测工具

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{
    .safety = true,  // 启用安全检查
}){};
defer {
    const status = gpa.deinit();
    if (status == .leak) {
        std.debug.print("内存泄漏检测\n", .{});
    }
}
```

## 最佳实践

### 1. 明确数据所有权

```zig
// 方案 A：ORM 拥有所有权，立即使用
const rows = query.get() catch |err| return err;
defer OrmModel.freeModels(rows);
processImmediately(rows);  // 在 defer 之前使用

// 方案 B：应用层拥有所有权，深拷贝
const rows = query.get() catch |err| return err;
defer OrmModel.freeModels(rows);
const owned_rows = try deepCopyRows(allocator, rows);
defer freeOwnedRows(allocator, owned_rows);
```

### 2. 封装深拷贝逻辑

```zig
fn deepCopyRole(allocator: std.mem.Allocator, role: models.SysRole) !models.SysRole {
    return models.SysRole{
        .id = role.id,
        .role_name = try allocator.dupe(u8, role.role_name),
        .role_key = try allocator.dupe(u8, role.role_key),
        .sort = role.sort,
        .status = role.status,
        .remark = try allocator.dupe(u8, role.remark),
        .data_scope = role.data_scope,
        .created_at = role.created_at,
        .updated_at = role.updated_at,
    };
}

fn freeRole(allocator: std.mem.Allocator, role: models.SysRole) void {
    allocator.free(role.role_name);
    allocator.free(role.role_key);
    allocator.free(role.remark);
}
```

### 3. 使用 Arena 分配器简化管理

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();  // 一次性释放所有内存
const arena_allocator = arena.allocator();

// 所有深拷贝使用 arena_allocator
const role_copy = models.SysRole{
    .role_name = try arena_allocator.dupe(u8, role.role_name),
    // ...
};
// 不需要单独释放每个字符串
```

## 相关知识点

- [字符串切片基础](./string_slices_basics.md)
- [内存分配器深入](./allocator_deep_dive.md)
- [错误处理与资源安全](./error_resource_safety.md)

## 总结

ORM 查询结果的内存由 ORM 管理，使用 `defer freeModels()` 释放。如果需要在释放后继续使用数据，必须深拷贝所有字符串字段，确保数据拥有独立的内存生命周期。这是 Zig 显式内存管理的核心原则：谁分配谁释放，跨作用域传递必须明确所有权转移。
