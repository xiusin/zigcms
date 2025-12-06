# HTTP Client 模块

可复用的 HTTP 客户端，支持文件上传、Cookie 管理、自定义请求头、连接池等功能。

## 功能特性

- **请求方法**：GET、POST、PUT、DELETE、PATCH
- **文件上传**：支持本地文件路径和流数据
- **Cookie 管理**：自动解析和持久化 Cookie
- **表单提交**：支持 `application/x-www-form-urlencoded` 和 `multipart/form-data`
- **JSON 支持**：自动序列化/反序列化 JSON
- **请求配置**：超时、重定向、自定义头部
- **连接池**：线程安全的客户端池化，支持最大/最小连接数、空闲超时

## 快速开始

```zig
const http = @import("services/http/mod.zig");

// 创建客户端
var client = try http.HttpClient.init(allocator);
defer client.deinit();

// GET 请求
var resp = try client.get("https://api.example.com/data");
defer resp.deinit();

if (resp.isSuccess()) {
    std.debug.print("响应: {s}\n", .{resp.body});
}
```

## 使用示例

### POST JSON

```zig
const data = .{ .name = "张三", .age = 25 };
var resp = try client.postJson("https://api.example.com/users", data);
defer resp.deinit();
```

### 设置请求头

```zig
try client.setHeader("Authorization", "Bearer token123");
try client.setHeader("X-Custom-Header", "value");
```

### Cookie 管理

```zig
// 添加 Cookie
try client.addCookie(.{
    .name = "session",
    .value = "abc123",
    .domain = "example.com",
});

// 获取 Cookie
if (client.getCookie("session")) |cookie| {
    std.debug.print("session: {s}\n", .{cookie.value});
}

// 清除所有 Cookie
client.clearCookies();
```

### 文件上传

```zig
// 上传本地文件
var resp = try client.uploadFile(
    "https://api.example.com/upload",
    "file",
    "/path/to/image.png"
);
defer resp.deinit();

// 上传流数据
var resp2 = try client.uploadStream(
    "https://api.example.com/upload",
    "file",
    "data.json",
    json_bytes,
    "application/json"
);
defer resp2.deinit();
```

### Multipart 表单

```zig
const fields = [_]http.FormField{
    .{ .text = .{ .name = "title", .value = "示例标题" } },
    .{ .file = .{
        .name = "image",
        .filename = "photo.jpg",
        .path = "/path/to/photo.jpg",
    } },
    .{ .stream = .{
        .name = "data",
        .filename = "data.bin",
        .data = binary_data,
        .content_type = "application/octet-stream",
    } },
};

var resp = try client.uploadMultipart("https://api.example.com/upload", &fields);
defer resp.deinit();
```

### 表单 POST

```zig
var form = std.StringHashMap([]const u8).init(allocator);
defer form.deinit();
try form.put("username", "admin");
try form.put("password", "secret");

var resp = try client.postForm("https://api.example.com/login", form);
defer resp.deinit();
```

### 自定义请求配置

```zig
var resp = try client.getWithOptions("https://api.example.com/data", .{
    .timeout_ms = 10_000,
    .user_agent = "ZigCMS/1.0",
    .authorization = "Bearer token123",
    .accept = "application/json",
});
defer resp.deinit();
```

### 通用请求方法

```zig
var resp = try client.request(.POST, "https://api.example.com/data", .{
    .content_type = "application/json",
    .body = "{\"key\": \"value\"}",
    .timeout_ms = 5_000,
});
defer resp.deinit();
```

## API 参考

### HttpClient

| 方法 | 说明 |
|------|------|
| `init(allocator)` | 创建客户端实例 |
| `deinit()` | 释放资源 |
| `get(url)` | 发送 GET 请求 |
| `post(url, body)` | 发送 POST 请求 |
| `postJson(url, data)` | 发送 JSON POST 请求 |
| `put(url, body)` | 发送 PUT 请求 |
| `delete(url)` | 发送 DELETE 请求 |
| `patch(url, body)` | 发送 PATCH 请求 |
| `uploadFile(url, field, path)` | 上传本地文件 |
| `uploadStream(url, field, filename, data, content_type)` | 上传流数据 |
| `uploadMultipart(url, fields)` | Multipart 表单上传 |
| `postForm(url, form_data)` | 发送表单数据 |
| `setHeader(name, value)` | 设置默认请求头 |
| `removeHeader(name)` | 删除默认请求头 |
| `addCookie(cookie)` | 添加 Cookie |
| `getCookie(name)` | 获取 Cookie |
| `clearCookies()` | 清除所有 Cookie |

### RequestOptions

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `timeout_ms` | `u64` | 30000 | 请求超时（毫秒） |
| `connect_timeout_ms` | `u64` | 10000 | 连接超时（毫秒） |
| `max_redirects` | `u8` | 5 | 最大重定向次数 |
| `follow_redirects` | `bool` | true | 是否跟随重定向 |
| `user_agent` | `?[]const u8` | null | User-Agent |
| `content_type` | `?[]const u8` | null | Content-Type |
| `accept` | `?[]const u8` | null | Accept |
| `authorization` | `?[]const u8` | null | Authorization |
| `body` | `?[]const u8` | null | 请求体 |

### Response

| 字段/方法 | 说明 |
|-----------|------|
| `status` | HTTP 状态码 |
| `headers` | 响应头 |
| `body` | 响应体 |
| `cookies` | 响应 Cookie 列表 |
| `isSuccess()` | 状态码是否为 2xx |
| `getHeader(name)` | 获取响应头 |
| `json(T)` | 解析 JSON 响应体 |
| `deinit()` | 释放资源 |

## 连接池

连接池提供线程安全的客户端管理，支持资源复用和自动回收。

### 基本使用

```zig
const http = @import("services/http/mod.zig");

// 创建连接池
var pool = http.ClientPool.init(allocator, .{
    .max_size = 10,        // 最大连接数
    .min_size = 2,         // 最小连接数
    .idle_timeout_ms = 60_000,  // 空闲超时
});
defer pool.deinit();

// 预热连接池（可选）
try pool.warmup();
```

### 获取和归还连接（RAII 风格）

```zig
{
    var handle = try pool.acquire();
    defer handle.release();  // 自动归还

    var resp = try handle.client().get("https://api.example.com");
    defer resp.deinit();
}
```

### 使用 execute 便捷方法

```zig
const result = try pool.execute(struct {
    pub fn call(client: *http.HttpClient) ![]const u8 {
        var resp = try client.get("https://api.example.com");
        defer resp.deinit();
        return resp.body;
    }
}.call);
```

### 非阻塞获取

```zig
if (pool.tryAcquire()) |*handle| {
    defer handle.release();
    // 使用连接
} else {
    // 池已满，连接不可用
}
```

### 连接失效处理

```zig
var handle = try pool.acquire();
errdefer handle.invalidate();  // 出错时标记连接无效，不归还到池

var resp = try handle.client().get(url);
defer resp.deinit();

handle.release();  // 正常归还
```

### PoolConfig 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `max_size` | `u32` | 10 | 最大连接数 |
| `min_size` | `u32` | 0 | 最小连接数（预创建） |
| `idle_timeout_ms` | `u64` | 60000 | 空闲超时（毫秒） |
| `acquire_timeout_ms` | `u64` | 30000 | 获取连接超时（毫秒） |

### 统计信息

```zig
const stats = pool.getStats();
std.debug.print("池大小: {}, 活跃: {}, 空闲: {}\n", .{
    stats.pool_size,
    stats.active_count,
    stats.idle_count,
});
```

## 注意事项

1. **资源释放**：`Response` 必须调用 `deinit()` 释放资源
2. **线程安全**：单个 `HttpClient` 实例不是线程安全的，使用 `ClientPool` 解决多线程问题
3. **Cookie 持久化**：响应中的 `Set-Cookie` 会自动添加到客户端
4. **文件大小**：上传大文件时注意内存占用
5. **连接池**：使用 `defer handle.release()` 确保连接归还，错误时使用 `handle.invalidate()`
