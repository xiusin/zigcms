# ORM 部分更新优化：PartialUpdateFromJson API

## 问题背景

在更新数据库记录时，传统方式需要手动构造包含所有字段的结构体，即使只想更新其中几个字段：

```zig
// ❌ 繁琐的传统方式
var update_fields = .{
    .username = current.username,
    .nickname = current.nickname,
    .password_hash = current.password_hash,
    .mobile = current.mobile,
    .email = current.email,
    .avatar = current.avatar,
    .gender = current.gender,
    .dept_id = current.dept_id,
    .position_id = current.position_id,
    .status = current.status,
    .remark = current.remark,
};

// 然后逐个字段检查 JSON 并更新
if (obj.get("username")) |v| {
    if (v == .string) update_fields.username = v.string;
}
if (obj.get("nickname")) |v| {
    if (v == .string) update_fields.nickname = v.string;
}
// ... 重复 N 次

_ = try OrmAdmin.Update(id, update_fields);
```

这种方式的问题：
1. 代码冗长，每个字段都要写一遍
2. 容易遗漏字段
3. 维护成本高，新增字段需要修改多处
4. 不够优雅

## 解决方案：PartialUpdateFromJson

新增的 `PartialUpdateFromJson` API 直接接受 JSON 对象，自动提取需要更新的字段：

```zig
// ✅ 优雅的新方式
_ = try OrmAdmin.PartialUpdateFromJson(id, json_obj);
```

### 核心特性

1. **只更新 JSON 中存在的字段**
   - 如果 JSON 中没有某个字段，该字段不会被更新
   - 保留数据库中的原值

2. **自动跳过 null 值**
   - JSON 中值为 `null` 的字段会被跳过
   - 不会将数据库字段更新为 `NULL`

3. **自动处理特殊字段**
   - `id`（主键）：自动跳过，不会被更新
   - `created_at`：自动跳过，创建时间不应被修改
   - `updated_at`：自动设置为当前时间（使用 `FROM_UNIXTIME()`）

4. **字符串自动 trim**
   - 所有字符串字段自动去除首尾空白
   - 自动转义单引号，防止 SQL 注入

5. **类型安全**
   - 编译时检查字段类型
   - 只处理匹配的 JSON 类型（integer → int, string → []const u8）

## 使用示例

### 基本用法

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

        // 直接使用 PartialUpdateFromJson
        _ = OrmAdmin.PartialUpdateFromJson(id, obj) catch |err| return base.send_error(req, err);
        
        return base.send_success(req, "更新成功");
    }
}
```

### 处理特殊字段（如密码加密）

如果需要对某些字段做特殊处理（如密码加密），可以先复制 JSON 对象并添加处理后的字段：

```zig
// 创建临时 JSON 对象
var temp_obj = std.json.ObjectMap.init(self.allocator);
defer temp_obj.deinit();

// 复制原始 JSON
var it = obj.iterator();
while (it.next()) |entry| {
    try temp_obj.put(entry.key_ptr.*, entry.value_ptr.*);
}

// 处理密码字段
if (obj.get("password")) |pwd_val| {
    if (pwd_val == .string and pwd_val.string.len > 0) {
        const pwd_hash = try strings.md5(self.allocator, pwd_val.string);
        defer self.allocator.free(pwd_hash);
        
        // 添加加密后的密码
        try temp_obj.put("password_hash", .{ .string = pwd_hash });
    }
}

// 使用处理后的对象更新
_ = try OrmAdmin.PartialUpdateFromJson(id, temp_obj);
```

## 生成的 SQL 示例

### 示例 1：更新部分字段

**输入 JSON:**
```json
{
  "id": 3,
  "nickname": "客服管理员",
  "status": 1
}
```

**生成的 SQL:**
```sql
UPDATE sys_admin 
SET nickname = '客服管理员', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

### 示例 2：跳过 null 值

**输入 JSON:**
```json
{
  "id": 3,
  "nickname": "新昵称",
  "dept_id": null,
  "status": 1
}
```

**生成的 SQL:**
```sql
UPDATE sys_admin 
SET nickname = '新昵称', 
    status = 1, 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

注意：`dept_id` 为 `null`，所以被跳过，不会更新为 `NULL`。

### 示例 3：字符串转义

**输入 JSON:**
```json
{
  "id": 3,
  "remark": "这是一个'测试'备注"
}
```

**生成的 SQL:**
```sql
UPDATE sys_admin 
SET remark = '这是一个''测试''备注', 
    updated_at = FROM_UNIXTIME(1772269534) 
WHERE id = 3
```

注意：单引号被自动转义为两个单引号。

## 支持的字段类型

| Zig 类型 | JSON 类型 | 说明 |
|---------|----------|------|
| `i32`, `i64`, `u32`, `u64` | `integer` | 整数类型 |
| `[]const u8` | `string` | 字符串（自动 trim 和转义） |
| `?i32`, `?i64` | `integer` 或 `null` | 可选整数 |
| `?[]const u8` | `string` 或 `null` | 可选字符串 |

## 错误处理

### NoFieldsToUpdate

如果 JSON 中没有任何可更新的字段（所有字段都是 null 或不存在），会返回错误：

```zig
_ = try OrmAdmin.PartialUpdateFromJson(id, obj);
// 如果 obj 为空或所有字段都是 null，会抛出 error.NoFieldsToUpdate
```

### 数据库错误

如果 SQL 执行失败（如约束冲突、字段不存在等），会返回数据库错误：

```zig
_ = OrmAdmin.PartialUpdateFromJson(id, obj) catch |err| {
    // err 可能是：
    // - error.ColumnNotNull (字段不能为 NULL)
    // - error.DuplicateEntry (唯一键冲突)
    // - error.DatabaseError (其他数据库错误)
    return base.send_error(req, err);
};
```

## 与传统 Update 方法的对比

| 特性 | Update(id, data) | PartialUpdateFromJson(id, json_obj) |
|------|------------------|-------------------------------------|
| 参数类型 | 结构体或匿名结构体 | std.json.ObjectMap |
| 字段选择 | 必须手动构造 | 自动从 JSON 提取 |
| null 处理 | 会更新为 NULL | 自动跳过 |
| 字符串 trim | 需要手动处理 | 自动处理 |
| SQL 转义 | 自动处理 | 自动处理 |
| updated_at | 自动设置 | 自动设置 |
| 代码量 | 多（需要逐字段赋值） | 少（一行调用） |
| 适用场景 | 程序内部更新 | API 接口更新 |

## 最佳实践

### 1. 业务验证在调用前完成

```zig
// ✅ 正确：先验证，再更新
if (obj.get("username")) |v| {
    if (v == .string) {
        const username = std.mem.trim(u8, v.string, " \t\r\n");
        if (username.len == 0) return base.send_failed(req, "用户名不能为空");
        const unique = try ensureUsernameUnique(self, username, id);
        if (!unique) return base.send_failed(req, "用户名已存在");
    }
}

_ = try OrmAdmin.PartialUpdateFromJson(id, obj);
```

### 2. 使用临时对象处理特殊字段

```zig
// ✅ 正确：复制 JSON 对象并添加处理后的字段
var temp_obj = std.json.ObjectMap.init(self.allocator);
defer temp_obj.deinit();

var it = obj.iterator();
while (it.next()) |entry| {
    try temp_obj.put(entry.key_ptr.*, entry.value_ptr.*);
}

// 添加特殊处理的字段
try temp_obj.put("processed_field", .{ .string = processed_value });

_ = try OrmAdmin.PartialUpdateFromJson(id, temp_obj);
```

### 3. 错误处理要明确

```zig
// ✅ 正确：明确处理不同错误
_ = OrmAdmin.PartialUpdateFromJson(id, obj) catch |err| {
    switch (err) {
        error.NoFieldsToUpdate => return base.send_failed(req, "没有需要更新的字段"),
        error.ColumnNotNull => return base.send_failed(req, "必填字段不能为空"),
        error.DuplicateEntry => return base.send_failed(req, "数据重复"),
        else => return base.send_error(req, err),
    }
};
```

## 注意事项

1. **JSON 对象生命周期**
   - `PartialUpdateFromJson` 不会持有 JSON 对象的引用
   - 方法返回后可以安全释放 JSON 对象

2. **字符串内存管理**
   - 方法内部会复制字符串到 SQL 语句中
   - 不需要担心字符串生命周期问题

3. **类型不匹配**
   - 如果 JSON 类型与字段类型不匹配，该字段会被跳过
   - 例如：字段是 `i32`，但 JSON 是 `string`，该字段不会被更新

4. **性能考虑**
   - 方法使用编译时反射（`inline for`），没有运行时开销
   - SQL 语句动态构建，只包含需要更新的字段
   - 适合 API 接口场景，不适合高频批量更新

## 相关文档

- [ORM 内存生命周期管理](./orm_memory_lifecycle.md)
- [错误处理与资源安全](./error_resource_safety.md)
- [内存泄漏防范基础](./memory_leak_basics.md)
