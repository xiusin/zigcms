# MCP CRUD 生成器 - 验证规则指南

## 概述

CRUD 生成器现在支持**自动验证规则生成**，确保数据完整性和安全性。

## 支持的验证规则

### 1. 必填验证

**字段定义**：
```json
{
  "name": "title",
  "type": "string",
  "required": true
}
```

**生成的验证代码**：
```zig
if (item.title.len == 0) {
    try base.send_error(&mutable_req, "title is required", 400);
    return;
}
```

### 2. 字符串长度验证

**字段定义**：
```json
{
  "name": "title",
  "type": "string",
  "required": true,
  "min_length": 5,
  "max_length": 200
}
```

**生成的验证代码**：
```zig
// 必填验证
if (item.title.len == 0) {
    try base.send_error(&mutable_req, "title is required", 400);
    return;
}

// 最小长度验证
if (item.title.len < 5) {
    try base.send_error(&mutable_req, "title too short (min 5)", 400);
    return;
}

// 最大长度验证
if (item.title.len > 200) {
    try base.send_error(&mutable_req, "title too long (max 200)", 400);
    return;
}
```

### 3. 数值范围验证

**字段定义**：
```json
{
  "name": "age",
  "type": "int",
  "required": true,
  "min_value": 18,
  "max_value": 120
}
```

**生成的验证代码**：
```zig
// 最小值验证
if (item.age < 18) {
    try base.send_error(&mutable_req, "age too small (min 18)", 400);
    return;
}

// 最大值验证
if (item.age > 120) {
    try base.send_error(&mutable_req, "age too large (max 120)", 400);
    return;
}
```

## 完整示例

### AI 对话

```
你：请生成 User CRUD 模块，包含以下字段：
- username (string, 必填, 3-50 字符)
- email (string, 必填, 5-100 字符)
- age (int, 必填, 18-120)
- bio (string, 可选, 最多 500 字符)
- score (int, 可选, 0-100)
```

### 字段定义（JSON）

```json
{
  "name": "User",
  "fields": [
    {
      "name": "username",
      "type": "string",
      "required": true,
      "min_length": 3,
      "max_length": 50
    },
    {
      "name": "email",
      "type": "string",
      "required": true,
      "min_length": 5,
      "max_length": 100
    },
    {
      "name": "age",
      "type": "int",
      "required": true,
      "min_value": 18,
      "max_value": 120
    },
    {
      "name": "bio",
      "type": "string",
      "required": false,
      "max_length": 500
    },
    {
      "name": "score",
      "type": "int",
      "required": false,
      "min_value": 0,
      "max_value": 100
    }
  ]
}
```

### 生成的 create 方法

```zig
/// 创建
///
/// ## 请求体
/// JSON 格式，包含所有必填字段
///
/// ## 验证规则
/// - 必填字段不能为空
/// - 字符串长度验证
/// - 数值范围验证
///
/// ## 返回
/// - 成功: 返回创建的记录（包含 ID）
/// - 失败: 400 (验证失败)
pub fn create(self: *@This(), req: zap.Request) !void {
    _ = self;
    var mutable_req = req;

    // 解析请求体
    const body = mutable_req.body orelse {
        try base.send_error(&mutable_req, "Missing body", 400);
        return;
    };

    const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        try base.send_error(&mutable_req, "Invalid JSON", 400);
        return;
    };
    defer parsed.deinit();

    const obj = parsed.value.object;

    const item = User{
        .username = obj.get("username").?.string,
        .email = obj.get("email").?.string,
        .age = @intCast(obj.get("age").?.integer),
        .bio = if (obj.get("bio")) |v| if (v == .string) v.string else null else null,
        .score = if (obj.get("score")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
    };

    // 字段验证
    
    // username 验证
    if (item.username.len == 0) {
        try base.send_error(&mutable_req, "username is required", 400);
        return;
    }
    if (item.username.len < 3) {
        try base.send_error(&mutable_req, "username too short (min 3)", 400);
        return;
    }
    if (item.username.len > 50) {
        try base.send_error(&mutable_req, "username too long (max 50)", 400);
        return;
    }
    
    // email 验证
    if (item.email.len == 0) {
        try base.send_error(&mutable_req, "email is required", 400);
        return;
    }
    if (item.email.len < 5) {
        try base.send_error(&mutable_req, "email too short (min 5)", 400);
        return;
    }
    if (item.email.len > 100) {
        try base.send_error(&mutable_req, "email too long (max 100)", 400);
        return;
    }
    
    // age 验证
    if (item.age < 18) {
        try base.send_error(&mutable_req, "age too small (min 18)", 400);
        return;
    }
    if (item.age > 120) {
        try base.send_error(&mutable_req, "age too large (max 120)", 400);
        return;
    }
    
    // bio 验证（可选字段，只验证长度）
    if (item.bio) |bio| {
        if (bio.len > 500) {
            try base.send_error(&mutable_req, "bio too long (max 500)", 400);
            return;
        }
    }
    
    // score 验证（可选字段，只验证范围）
    if (item.score) |score| {
        if (score < 0) {
            try base.send_error(&mutable_req, "score too small (min 0)", 400);
            return;
        }
        if (score > 100) {
            try base.send_error(&mutable_req, "score too large (max 100)", 400);
            return;
        }
    }

    const created = try OrmUser.Create(item);
    defer OrmUser.freeModel(created);

    try base.send_success(&mutable_req, created);
}
```

## 验证规则矩阵

| 字段类型 | 验证规则 | 参数 | 生成的验证 |
|----------|----------|------|------------|
| string | required | true | 长度 > 0 |
| string | min_length | 5 | 长度 >= 5 |
| string | max_length | 200 | 长度 <= 200 |
| int | min_value | 18 | 值 >= 18 |
| int | max_value | 120 | 值 <= 120 |
| float | min_value | 0.0 | 值 >= 0.0 |
| float | max_value | 100.0 | 值 <= 100.0 |

## API 测试示例

### 成功创建

**请求**：
```bash
POST /api/user/create
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "age": 25,
  "bio": "Software developer",
  "score": 85
}
```

**响应**：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "age": 25,
    "bio": "Software developer",
    "score": 85
  }
}
```

### 验证失败 - 用户名太短

**请求**：
```bash
POST /api/user/create
Content-Type: application/json

{
  "username": "ab",
  "email": "john@example.com",
  "age": 25
}
```

**响应**：
```json
{
  "code": 400,
  "message": "username too short (min 3)",
  "data": null
}
```

### 验证失败 - 年龄超出范围

**请求**：
```bash
POST /api/user/create
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "age": 15
}
```

**响应**：
```json
{
  "code": 400,
  "message": "age too small (min 18)",
  "data": null
}
```

### 验证失败 - 可选字段超出范围

**请求**：
```bash
POST /api/user/create
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "age": 25,
  "score": 150
}
```

**响应**：
```json
{
  "code": 400,
  "message": "score too large (max 100)",
  "data": null
}
```

## 验证顺序

生成的验证代码按以下顺序执行：

1. **必填验证**：检查字段是否为空
2. **最小值/长度验证**：检查是否小于最小值
3. **最大值/长度验证**：检查是否大于最大值

**优势**：
- 提前返回，避免不必要的验证
- 错误消息清晰明确
- 性能优化

## 可选字段验证

可选字段只在值存在时进行验证：

```zig
// bio 是可选字段
if (item.bio) |bio| {
    // 只验证长度，不验证是否为空
    if (bio.len > 500) {
        try base.send_error(&mutable_req, "bio too long (max 500)", 400);
        return;
    }
}
```

**特性**：
- 不验证是否为空（因为是可选的）
- 只验证长度/范围规则
- null 值会被跳过

## 自定义验证

生成的代码提供了基础验证，你可以在此基础上添加自定义验证：

```zig
// 生成的验证代码
if (item.email.len == 0) {
    try base.send_error(&mutable_req, "email is required", 400);
    return;
}

// 添加自定义验证
if (!std.mem.containsAtLeast(u8, item.email, 1, "@")) {
    try base.send_error(&mutable_req, "Invalid email format", 400);
    return;
}

if (!std.mem.endsWith(u8, item.email, ".com") and 
    !std.mem.endsWith(u8, item.email, ".net")) {
    try base.send_error(&mutable_req, "Email must end with .com or .net", 400);
    return;
}
```

## 最佳实践

### 1. 合理设置验证规则

```json
// ✅ 推荐：合理的范围
{
  "name": "username",
  "type": "string",
  "min_length": 3,
  "max_length": 50
}

// ❌ 避免：过于严格
{
  "name": "username",
  "type": "string",
  "min_length": 10,
  "max_length": 15
}
```

### 2. 可选字段不设置 required

```json
// ✅ 推荐
{
  "name": "bio",
  "type": "string",
  "required": false,
  "max_length": 500
}

// ❌ 避免
{
  "name": "bio",
  "type": "string",
  "required": true,  // 矛盾
  "max_length": 500
}
```

### 3. 数值范围要合理

```json
// ✅ 推荐
{
  "name": "age",
  "type": "int",
  "min_value": 0,
  "max_value": 150
}

// ❌ 避免
{
  "name": "age",
  "type": "int",
  "min_value": 100,  // 不合理
  "max_value": 50    // min > max
}
```

### 4. 友好的错误消息

生成的错误消息格式：
```
{field_name} is required
{field_name} too short (min {min})
{field_name} too long (max {max})
{field_name} too small (min {min})
{field_name} too large (max {max})
```

**特性**：
- 包含字段名
- 包含限制值
- 清晰明确
- 易于理解

## 性能考虑

### 验证顺序优化

```zig
// ✅ 优化：先验证必填，再验证范围
if (item.username.len == 0) {
    return error.Required;  // 提前返回
}
if (item.username.len < 3) {
    return error.TooShort;
}
```

### 避免重复验证

```zig
// ✅ 推荐：一次验证
const len = item.username.len;
if (len == 0) return error.Required;
if (len < 3) return error.TooShort;
if (len > 50) return error.TooLong;

// ❌ 避免：多次计算长度
if (item.username.len == 0) return error.Required;
if (item.username.len < 3) return error.TooShort;
if (item.username.len > 50) return error.TooLong;
```

## 总结

### 现在的能力

- ✅ **自动验证生成**：根据字段定义自动生成验证代码
- ✅ **多种验证规则**：必填、长度、范围
- ✅ **友好的错误消息**：清晰明确的错误提示
- ✅ **可选字段支持**：只在值存在时验证
- ✅ **性能优化**：提前返回，避免不必要的验证

### 效率提升

| 功能 | 传统方式 | MCP 生成 | 提升 |
|------|----------|----------|------|
| 验证代码 | 30 分钟 | 0 分钟 | ∞ |
| 错误消息 | 10 分钟 | 0 分钟 | ∞ |
| 测试验证 | 20 分钟 | 5 分钟 | 4 倍 |

### 适用场景

- ✅ 用户注册/登录
- ✅ 表单提交
- ✅ 数据导入
- ✅ API 接口
- ✅ 数据完整性保证

老铁，现在验证规则生成也完全自动化了！
