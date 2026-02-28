# ORM UpdateWith：利用 Zig 编译时特性动态构建匿名结构体

## 设计理念

`UpdateWith` 是真正利用 Zig `comptime` 特性的方案，允许你直接使用匿名结构体 `.{}` 来指定需要更新的字段，编译器会在编译时自动推导类型并生成高效的 SQL。

## 核心优势

1. **真正的 Zig 风格**：使用原生的匿名结构体语法 `.{}`
2. **编译时类型推导**：零运行时开销，所有类型检查在编译时完成
3. **自动跳过 null**：optional 字段值为 `null` 时自动跳过
4. **简洁优雅**：一行代码完成更新，无需额外的 builder 或 JSON 处理

## 基本用法

### 示例 1：更新部分字段

```zig
_ = try User.UpdateWith(user_id, .{
    .username = "new_name",
    .status = 1,
});
```

**生成的 SQL**：
```sql
UPDATE sys_admin 
SET username = 'new_name', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

### 示例 2：使用 optional 字段（null 会被跳过）

```zig
_ = try User.UpdateWith(user_id, .{
    .username = "new_name",
    .dept_id = null,  // 会被跳过
    .status = 1,
});
```

**生成的 SQL**：
```sql
UPDATE sys_admin 
SET username = 'new_name', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

注意：`dept_id` 为 `null`，所以被跳过，不会更新数据库。

### 示例 3：从 JSON 提取值

```zig
_ = try User.UpdateWith(user_id, .{
    .username = if (json_obj.get("username")) |v| 
        if (v == .string) v.string else null 
        else null,
    .status = if (json_obj.get("status")) |v| 
        if (v == .integer) @as(?i32, @intCast(v.integer)) else null 
        else null,
    .dept_id = if (json_obj.get("dept_id")) |v| 
        if (v == .null) null 
        else if (v == .integer) @as(?i32, @intCast(v.integer)) else null 
        else null,
});
```

## 完整示例：API 接口更新

```zig
fn saveAdminImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    var id: i32 = 0;
    if (obj.get("id")) |id_val| {
        if (id_val == .integer) id = @intCast(id_val.integer);
    }

    if (id > 0) {
        // 验证记录是否存在
        const current_opt = OrmAdmin.Find(id) catch |err| return base.send_error(req, err);
        if (current_opt == null) return base.send_failed(req, "记录不存在");
        var current = current_opt.?;
        defer OrmAdmin.freeModel(&current);

        // 业务验证
        if (obj.get("username")) |v| {
            if (v == .string) {
                const username = std.mem.trim(u8, v.string, " \t\r\n");
                if (username.len == 0) return base.send_failed(req, "用户名不能为空");
                const unique = try ensureUsernameUnique(self, username, id);
                if (!unique) return base.send_failed(req, "用户名已存在");
            }
        }

        // 处理密码加密
        var pwd_hash: ?[]const u8 = null;
        defer if (pwd_hash) |h| self.allocator.free(h);
        
        if (obj.get("password")) |pwd_val| {
            if (pwd_val == .string and pwd_val.string.len > 0) {
                pwd_hash = try strings.md5(self.allocator, pwd_val.string);
            }
        }

        // 使用匿名结构体更新（真正的 Zig 风格）
        _ = try OrmAdmin.UpdateWith(id, .{
            .username = if (obj.get("username")) |v| if (v == .string) v.string else null else null,
            .nickname = if (obj.get("nickname")) |v| if (v == .string) v.string else null else null,
            .password_hash = pwd_hash,
            .mobile = if (obj.get("mobile")) |v| if (v == .string) v.string else null else null,
            .email = if (obj.get("email")) |v| if (v == .string) v.string else null else null,
            .status = if (obj.get("status")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
            .dept_id = if (obj.get("dept_id")) |v| 
                if (v == .null) null 
                else if (v == .integer) @as(?i32, @intCast(v.integer)) else null 
                else null,
        });

        return base.send_success(req, "更新成功");
    }
}
```

## 工作原理

### 编译时类型推导

```zig
// 你写的代码
_ = try User.UpdateWith(id, .{
    .username = "admin",
    .status = 1,
    .dept_id = null,
});

// 编译器推导出的匿名结构体类型
struct {
    username: []const u8,
    status: comptime_int,  // 会被转换为 i32
    dept_id: @TypeOf(null),  // 会被识别为 optional
}
```

### 编译时字段遍历

```zig
fn updateWith(db: *Database, id: anytype, data: anytype) !u64 {
    const DataType = @TypeOf(data);
    const fields = std.meta.fields(DataType);
    
    // inline for 在编译时展开
    inline for (fields) |field| {
        const value = @field(data, field.name);
        const type_info = @typeInfo(field.type);
        
        // 编译时判断是否为 optional
        const should_include = if (comptime type_info == .optional) 
            value != null  // 运行时检查
        else 
            true;  // 非 optional 总是包含
        
        if (should_include) {
            // 添加到 SQL
        }
    }
}
```

## 类型支持

| Zig 类型 | 示例 | SQL 生成 |
|---------|------|---------|
| `[]const u8` | `"admin"` | `'admin'` |
| `i32`, `i64` | `1`, `100` | `1`, `100` |
| `?i32`, `?i64` | `10`, `null` | `10`, 跳过 |
| `?[]const u8` | `"text"`, `null` | `'text'`, 跳过 |
| `comptime_int` | `1` | 自动转换为 `i32` |

## 特殊字段处理

### 自动跳过的字段

- `id`（主键）：永远不会被更新
- `created_at`：创建时间不应被修改
- `updated_at`：自动设置为当前时间

### 自动设置的字段

- `updated_at`：自动设置为 `FROM_UNIXTIME(当前时间戳)`

## 与其他方案的对比

| 特性 | 传统 Update | UpdateBuilder | UpdateWith |
|------|------------|---------------|------------|
| 语法 | 结构体 | 链式调用 | 匿名结构体 `.{}` |
| 类型检查 | 编译时 | 运行时 | 编译时 |
| 性能 | 高 | 中（HashMap） | 高（零开销） |
| 灵活性 | 低 | 高 | 中 |
| 代码量 | 多 | 中 | 少 |
| Zig 风格 | 中 | 低 | 高 |
| 适用场景 | 程序内部 | 复杂逻辑 | API 接口 |

## 最佳实践

### 1. 使用 optional 类型处理可能不存在的字段

```zig
// ✅ 推荐：使用 optional
_ = try User.UpdateWith(id, .{
    .username = if (json_obj.get("username")) |v| 
        if (v == .string) v.string else null 
        else null,
});

// ❌ 不推荐：使用非 optional 类型
_ = try User.UpdateWith(id, .{
    .username = json_obj.get("username").?.string,  // 可能 panic
});
```

### 2. 特殊字段单独处理

```zig
// ✅ 推荐：先处理特殊字段
var pwd_hash: ?[]const u8 = null;
defer if (pwd_hash) |h| allocator.free(h);

if (json_obj.get("password")) |pwd| {
    pwd_hash = try encryptPassword(allocator, pwd.string);
}

_ = try User.UpdateWith(id, .{
    .username = ...,
    .password_hash = pwd_hash,  // 使用处理后的值
});
```

### 3. 业务验证在更新前完成

```zig
// ✅ 推荐：先验证，再更新
if (json_obj.get("username")) |v| {
    if (v == .string) {
        const username = std.mem.trim(u8, v.string, " \t\r\n");
        if (username.len == 0) return error.UsernameEmpty;
        const unique = try ensureUsernameUnique(username, id);
        if (!unique) return error.UsernameDuplicate;
    }
}

_ = try User.UpdateWith(id, .{ .username = ... });
```

### 4. 使用辅助函数简化 JSON 提取

```zig
// 辅助函数
fn getStringOrNull(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    if (obj.get(key)) |v| {
        if (v == .string) return v.string;
    }
    return null;
}

fn getIntOrNull(obj: std.json.ObjectMap, key: []const u8) ?i32 {
    if (obj.get(key)) |v| {
        if (v == .integer) return @intCast(v.integer);
    }
    return null;
}

// 使用
_ = try User.UpdateWith(id, .{
    .username = getStringOrNull(obj, "username"),
    .status = getIntOrNull(obj, "status"),
    .dept_id = getIntOrNull(obj, "dept_id"),
});
```

## 错误处理

### NoFieldsToUpdate

如果所有字段都是 `null`，会返回错误：

```zig
_ = User.UpdateWith(id, .{
    .username = null,
    .status = null,
}) catch |err| {
    if (err == error.NoFieldsToUpdate) {
        std.debug.print("没有需要更新的字段\n", .{});
    }
};
```

### 数据库错误

```zig
_ = User.UpdateWith(id, .{
    .username = "admin",
}) catch |err| {
    switch (err) {
        error.ColumnNotNull => std.debug.print("字段不能为空\n", .{}),
        error.DuplicateEntry => std.debug.print("数据重复\n", .{}),
        else => std.debug.print("数据库错误: {}\n", .{err}),
    }
};
```

## 性能考虑

1. **零运行时开销**：所有类型检查和字段遍历在编译时完成
2. **内联展开**：`inline for` 在编译时展开为直接的字段访问
3. **无额外分配**：不需要 HashMap 或其他运行时数据结构
4. **SQL 延迟构建**：只在需要时构建 SQL 字符串

## 编译时保证

```zig
// ✅ 编译通过：字段存在且类型匹配
_ = try User.UpdateWith(id, .{
    .username = "admin",  // []const u8
    .status = 1,          // i32
});

// ❌ 编译错误：字段不存在
_ = try User.UpdateWith(id, .{
    .non_existent_field = "value",
});

// ❌ 编译错误：类型不匹配
_ = try User.UpdateWith(id, .{
    .status = "not_a_number",  // 期望 i32，得到 []const u8
});
```

## 限制与注意事项

1. **必须是结构体**：`data` 参数必须是结构体类型（包括匿名结构体）
2. **字段必须存在**：结构体中的字段必须在模型中存在
3. **类型必须匹配**：字段类型必须与模型中的类型兼容
4. **JSON 是运行时的**：从 JSON 提取值需要运行时判断，不能完全在编译时完成

## 为什么这是最优雅的方案

1. **符合 Zig 哲学**
   - 使用原生语法 `.{}`
   - 编译时类型安全
   - 零成本抽象

2. **代码简洁**
   - 一行代码完成更新
   - 不需要额外的 builder 或辅助对象
   - 直观易懂

3. **性能最优**
   - 编译时展开
   - 无运行时开销
   - 无额外内存分配

4. **类型安全**
   - 编译时检查字段存在性
   - 编译时检查类型匹配
   - 运行时零错误

## 相关文档

- [ORM 内存生命周期管理](./orm_memory_lifecycle.md)
- [ORM UpdateBuilder](./orm_update_builder.md)（适合需要运行时动态构建的场景）
- [错误处理与资源安全](./error_resource_safety.md)
