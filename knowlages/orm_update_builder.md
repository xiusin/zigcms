# ORM UpdateBuilder：动态构建更新字段的优雅方案

## 设计理念

UpdateBuilder 提供了一种类似"动态构建匿名结构体"的体验，通过链式调用动态添加需要更新的字段，避免手动构造结构体的繁琐。

## 核心特性

1. **链式调用**：流畅的 API 设计，支持连续调用
2. **类型安全**：编译时类型检查
3. **自动管理**：自动处理字符串 trim、SQL 转义、内存管理
4. **灵活性**：支持从 JSON 自动提取字段
5. **零开销**：使用 HashMap 存储字段，只在 execute 时构建 SQL

## 基本用法

### 示例 1：手动设置字段

```zig
var builder = try User.updateBuilder(allocator, user_id);
defer builder.deinit();

_ = try builder.setString("username", "new_name");
_ = try builder.setInt("status", 1);
_ = try builder.setOptionalInt("dept_id", null);  // null 会被跳过

_ = try builder.execute();
```

### 示例 2：从 JSON 自动提取（推荐）

```zig
fn saveAdminImpl(self: *Self, req: zap.Request) !void {
    // ... 解析 JSON ...
    const obj = parsed.value.object;
    var id: i32 = 0;
    if (obj.get("id")) |id_val| {
        if (id_val == .integer) id = @intCast(id_val.integer);
    }

    if (id > 0) {
        // 创建 builder
        var builder = try OrmAdmin.updateBuilder(self.allocator, id);
        defer builder.deinit();

        // 从 JSON 动态添加字段
        var it = obj.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            
            // 跳过特殊字段
            if (std.mem.eql(u8, key, "id") or 
                std.mem.eql(u8, key, "password")) {
                continue;
            }
            
            // 自动添加字段（根据 JSON 类型自动判断）
            _ = try builder.setFromJson(key, value);
        }
        
        // 执行更新
        _ = try builder.execute();
    }
}
```

### 示例 3：处理特殊字段（如密码加密）

```zig
var builder = try OrmAdmin.updateBuilder(self.allocator, id);
defer builder.deinit();

// 从 JSON 添加普通字段
var it = obj.iterator();
while (it.next()) |entry| {
    const key = entry.key_ptr.*;
    const value = entry.value_ptr.*;
    
    if (std.mem.eql(u8, key, "id") or 
        std.mem.eql(u8, key, "password") or 
        std.mem.eql(u8, key, "confirm_password")) {
        continue;
    }
    
    _ = try builder.setFromJson(key, value);
}

// 处理密码字段
if (obj.get("password")) |pwd_val| {
    if (pwd_val == .string and pwd_val.string.len > 0) {
        const pwd_hash = try strings.md5(allocator, pwd_val.string);
        defer allocator.free(pwd_hash);
        
        _ = try builder.setString("password_hash", pwd_hash);
    }
}

_ = try builder.execute();
```

## API 参考

### 创建 Builder

```zig
pub fn updateBuilder(allocator: Allocator, id: anytype) !UpdateBuilder(T, @TypeOf(id))
```

创建一个更新构建器实例。

**参数**：
- `allocator`: 内存分配器
- `id`: 记录 ID（任意整数类型）

**返回**：UpdateBuilder 实例

**注意**：必须调用 `defer builder.deinit()` 释放资源

### 设置字段方法

#### setInt

```zig
pub fn setInt(self: *Builder, field_name: []const u8, value: anytype) !*Builder
```

设置整数字段。

**参数**：
- `field_name`: 字段名
- `value`: 整数值（任意整数类型，会自动转换为 i64）

**返回**：Builder 指针（支持链式调用）

**示例**：
```zig
_ = try builder.setInt("status", 1);
_ = try builder.setInt("age", 25);
```

#### setString

```zig
pub fn setString(self: *Builder, field_name: []const u8, value: []const u8) !*Builder
```

设置字符串字段。

**参数**：
- `field_name`: 字段名
- `value`: 字符串值

**特性**：
- 自动 trim 首尾空白
- 自动转义单引号
- 自动复制字符串（不依赖原字符串生命周期）

**示例**：
```zig
_ = try builder.setString("username", "  admin  ");  // 自动 trim 为 "admin"
_ = try builder.setString("remark", "It's a test");  // 自动转义为 "It''s a test"
```

#### setOptionalInt

```zig
pub fn setOptionalInt(self: *Builder, field_name: []const u8, value: ?i64) !*Builder
```

设置可选整数字段。

**参数**：
- `field_name`: 字段名
- `value`: 可选整数值

**特性**：
- 如果值为 `null`，该字段会被跳过（不添加到 SQL）
- 如果值不为 `null`，等同于 `setInt`

**示例**：
```zig
_ = try builder.setOptionalInt("dept_id", null);  // 跳过
_ = try builder.setOptionalInt("dept_id", 10);    // 添加
```

#### setOptionalString

```zig
pub fn setOptionalString(self: *Builder, field_name: []const u8, value: ?[]const u8) !*Builder
```

设置可选字符串字段。

**参数**：
- `field_name`: 字段名
- `value`: 可选字符串值

**特性**：
- 如果值为 `null`，该字段会被跳过
- 如果值不为 `null`，等同于 `setString`

**示例**：
```zig
_ = try builder.setOptionalString("email", null);  // 跳过
_ = try builder.setOptionalString("email", "admin@example.com");  // 添加
```

#### setFromJson

```zig
pub fn setFromJson(self: *Builder, field_name: []const u8, json_value: std.json.Value) !*Builder
```

从 JSON 值自动设置字段。

**参数**：
- `field_name`: 字段名
- `json_value`: JSON 值

**特性**：
- 自动判断 JSON 类型
- `integer` → 调用 `setInt`
- `string` → 调用 `setString`
- `null` → 跳过
- 其他类型 → 跳过

**示例**：
```zig
_ = try builder.setFromJson("status", .{ .integer = 1 });
_ = try builder.setFromJson("username", .{ .string = "admin" });
_ = try builder.setFromJson("dept_id", .null);  // 跳过
```

### 执行更新

#### execute

```zig
pub fn execute(self: *Builder) !u64
```

执行更新操作。

**返回**：受影响的行数

**特性**：
- 自动添加 `updated_at = FROM_UNIXTIME(当前时间戳)`
- 如果没有任何字段，返回 `error.NoFieldsToUpdate`
- 自动构建 SQL 并执行

**示例**：
```zig
const affected_rows = try builder.execute();
std.debug.print("Updated {d} rows\n", .{affected_rows});
```

## 生成的 SQL 示例

### 示例 1：基本更新

```zig
var builder = try User.updateBuilder(allocator, 3);
defer builder.deinit();

_ = try builder.setString("nickname", "新昵称");
_ = try builder.setInt("status", 1);
_ = try builder.execute();
```

**生成的 SQL**：
```sql
UPDATE sys_admin 
SET nickname = '新昵称', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

### 示例 2：跳过 null 值

```zig
var builder = try User.updateBuilder(allocator, 3);
defer builder.deinit();

_ = try builder.setString("nickname", "新昵称");
_ = try builder.setOptionalInt("dept_id", null);  // 跳过
_ = try builder.setInt("status", 1);
_ = try builder.execute();
```

**生成的 SQL**：
```sql
UPDATE sys_admin 
SET nickname = '新昵称', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

注意：`dept_id` 为 `null`，所以被跳过。

### 示例 3：字符串转义

```zig
var builder = try User.updateBuilder(allocator, 3);
defer builder.deinit();

_ = try builder.setString("remark", "这是一个'测试'备注");
_ = try builder.execute();
```

**生成的 SQL**：
```sql
UPDATE sys_admin 
SET remark = '这是一个''测试''备注', 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

## 与其他方案的对比

| 特性 | 传统 Update | UpdateWith | UpdateBuilder |
|------|------------|-----------|---------------|
| 参数类型 | 结构体 | 匿名结构体 `.{}` | Builder |
| 字段选择 | 手动构造 | 编译时指定 | 链式调用 |
| 灵活性 | 低 | 中 | 高 |
| 特殊处理 | 困难 | 中等 | 直接调用方法 |
| 代码可读性 | 低 | 高 | 高 |
| 类型安全 | 高 | 高 | 高 |
| 性能 | 高 | 高 | 中 |
| 适用场景 | 程序内部 | API 接口 | API 接口 + 复杂逻辑 |

## 最佳实践

### 1. 始终使用 defer 释放资源

```zig
// ✅ 正确
var builder = try User.updateBuilder(allocator, id);
defer builder.deinit();

// ❌ 错误：忘记 deinit 会导致内存泄漏
var builder = try User.updateBuilder(allocator, id);
_ = try builder.execute();
```

### 2. 使用 setFromJson 简化 JSON 处理

```zig
// ✅ 推荐：自动判断类型
var it = obj.iterator();
while (it.next()) |entry| {
    _ = try builder.setFromJson(entry.key_ptr.*, entry.value_ptr.*);
}

// ❌ 不推荐：手动判断类型
var it = obj.iterator();
while (it.next()) |entry| {
    const value = entry.value_ptr.*;
    if (value == .integer) {
        _ = try builder.setInt(entry.key_ptr.*, value.integer);
    } else if (value == .string) {
        _ = try builder.setString(entry.key_ptr.*, value.string);
    }
}
```

### 3. 业务验证在构建前完成

```zig
// ✅ 正确：先验证，再构建
if (obj.get("username")) |v| {
    if (v == .string) {
        const username = std.mem.trim(u8, v.string, " \t\r\n");
        if (username.len == 0) return error.UsernameEmpty;
        const unique = try ensureUsernameUnique(username, id);
        if (!unique) return error.UsernameDuplicate;
    }
}

var builder = try User.updateBuilder(allocator, id);
defer builder.deinit();
// ... 添加字段 ...
```

### 4. 特殊字段单独处理

```zig
// ✅ 正确：先添加普通字段，再添加特殊字段
var builder = try User.updateBuilder(allocator, id);
defer builder.deinit();

// 添加普通字段
var it = obj.iterator();
while (it.next()) |entry| {
    const key = entry.key_ptr.*;
    if (std.mem.eql(u8, key, "password")) continue;  // 跳过密码
    _ = try builder.setFromJson(key, entry.value_ptr.*);
}

// 单独处理密码
if (obj.get("password")) |pwd| {
    const hash = try encryptPassword(pwd.string);
    defer allocator.free(hash);
    _ = try builder.setString("password_hash", hash);
}

_ = try builder.execute();
```

## 错误处理

### NoFieldsToUpdate

如果没有添加任何字段就调用 `execute()`，会返回错误：

```zig
var builder = try User.updateBuilder(allocator, id);
defer builder.deinit();

// 没有添加任何字段
_ = builder.execute() catch |err| {
    if (err == error.NoFieldsToUpdate) {
        std.debug.print("没有需要更新的字段\n", .{});
    }
};
```

### 数据库错误

SQL 执行失败会返回数据库错误：

```zig
_ = builder.execute() catch |err| {
    switch (err) {
        error.ColumnNotNull => std.debug.print("字段不能为空\n", .{}),
        error.DuplicateEntry => std.debug.print("数据重复\n", .{}),
        else => std.debug.print("数据库错误: {}\n", .{err}),
    }
};
```

## 内存管理

UpdateBuilder 自动管理内存：

1. **字段名复制**：所有字段名都会被复制，不依赖原字符串
2. **字符串值复制**：所有字符串值都会被复制并 trim
3. **自动释放**：`deinit()` 会释放所有分配的内存
4. **错误安全**：使用 `errdefer` 确保错误时正确释放

```zig
// 内部实现示例
pub fn setString(self: *Builder, field_name: []const u8, value: []const u8) !*Builder {
    const name_copy = try self.allocator.dupe(u8, field_name);
    errdefer self.allocator.free(name_copy);  // 错误时释放
    
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    const value_copy = try self.allocator.dupe(u8, trimmed);
    errdefer self.allocator.free(value_copy);  // 错误时释放
    
    try self.fields.put(self.allocator, name_copy, .{ .string = value_copy });
    return self;
}
```

## 性能考虑

1. **HashMap 存储**：使用 `StringHashMapUnmanaged` 存储字段，查找和插入都是 O(1)
2. **延迟构建**：SQL 只在 `execute()` 时构建，避免不必要的字符串操作
3. **零拷贝优化**：整数类型直接存储，不需要额外分配
4. **适用场景**：适合 API 接口场景，不适合高频批量更新

## 完整示例

```zig
fn updateUser(allocator: Allocator, user_id: i32, json_obj: std.json.ObjectMap) !void {
    // 创建 builder
    var builder = try User.updateBuilder(allocator, user_id);
    defer builder.deinit();
    
    // 从 JSON 动态添加字段
    var it = json_obj.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        
        // 跳过特殊字段
        if (std.mem.eql(u8, key, "id") or 
            std.mem.eql(u8, key, "password") or 
            std.mem.eql(u8, key, "created_at")) {
            continue;
        }
        
        // 自动添加字段
        _ = try builder.setFromJson(key, value);
    }
    
    // 处理密码（如果有）
    if (json_obj.get("password")) |pwd_val| {
        if (pwd_val == .string and pwd_val.string.len > 0) {
            const pwd_hash = try encryptPassword(allocator, pwd_val.string);
            defer allocator.free(pwd_hash);
            _ = try builder.setString("password_hash", pwd_hash);
        }
    }
    
    // 执行更新
    const affected = try builder.execute();
    std.debug.print("Updated {d} rows\n", .{affected});
}
```

## 相关文档

- [ORM 内存生命周期管理](./orm_memory_lifecycle.md)
- [ORM UpdateWith](./orm_update_with_anonymous_struct.md)（推荐使用）
- [错误处理与资源安全](./error_resource_safety.md)
