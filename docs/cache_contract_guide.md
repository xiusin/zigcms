# ZigCMS 缓存统一契约使用指南

## 概述

ZigCMS 采用统一的缓存契约接口（`CacheInterface`），支持多种缓存后端无缝切换：
- **MemoryCacheDriver**：内存缓存（开发/测试）
- **RedisCacheDriver**：Redis 缓存（生产环境）

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│              CacheInterface (契约接口)                   │
│  - set(key, value, ttl)                                 │
│  - get(key) → ?[]const u8                               │
│  - del(key)                                             │
│  - exists(key) → bool                                   │
│  - flush()                                              │
│  - stats() → CacheStats                                 │
│  - cleanupExpired()                                     │
│  - delByPrefix(prefix)                                  │
│  - deinit()                                             │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼────────┐    ┌────────▼────────┐
│ MemoryCacheDriver│    │ RedisCacheDriver│
│  - 内存存储      │    │  - Redis 存储   │
│  - 线程安全      │    │  - 连接池       │
│  - TTL 支持      │    │  - TTL 支持     │
└─────────────────┘    └─────────────────┘
```

## 契约接口

### CacheInterface

```zig
pub const CacheInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        set: *const fn (*anyopaque, []const u8, []const u8, ?u64) anyerror!void,
        get: *const fn (*anyopaque, []const u8, std.mem.Allocator) anyerror!?[]const u8,
        del: *const fn (*anyopaque, []const u8) anyerror!void,
        exists: *const fn (*anyopaque, []const u8) bool,
        flush: *const fn (*anyopaque) anyerror!void,
        stats: *const fn (*anyopaque) CacheStats,
        cleanupExpired: *const fn (*anyopaque) anyerror!void,
        delByPrefix: *const fn (*anyopaque, []const u8) anyerror!void,
        deinit: *const fn (*anyopaque) void,
    };

    // 方法实现...
};
```

### CacheStats

```zig
pub const CacheStats = struct {
    count: usize,      // 缓存项总数
    expired: usize,    // 过期项数量
};
```

## 使用方式

### 1. 内存缓存（开发/测试）

```zig
const cache_drivers = @import("application/services/cache_drivers.zig");

// 创建内存缓存驱动
var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
defer memory_cache.deinit();

// 获取接口
const cache = memory_cache.asInterface();

// 使用缓存
try cache.set("user:1", "张三", 300);  // TTL 300秒
if (cache.get("user:1", allocator)) |value| {
    defer allocator.free(value);
    std.debug.print("用户: {s}\n", .{value});
}
```

### 2. Redis 缓存（生产环境）

```zig
const cache_drivers = @import("application/services/cache_drivers.zig");

// 创建 Redis 缓存驱动
const redis_config = cache_drivers.RedisCacheConfig{
    .host = "localhost",
    .port = 6379,
    .password = null,
    .database = 0,
    .max_connections = 10,
};

var redis_cache = try cache_drivers.RedisCacheDriver.init(redis_config, allocator);
defer redis_cache.deinit();

// 获取接口
const cache = redis_cache.asInterface();

// 使用缓存（API 完全相同）
try cache.set("user:1", "张三", 300);
if (cache.get("user:1", allocator)) |value| {
    defer allocator.free(value);
    std.debug.print("用户: {s}\n", .{value});
}
```

### 3. 通过 DI 容器使用

```zig
// 注册缓存驱动到 DI 容器
const container = zigcms.core.di.getGlobalContainer();

// 开发环境：注册内存缓存
var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
const cache_interface = memory_cache.asInterface();
try container.registerInstance(cache_contract.CacheInterface, &cache_interface, null);

// 生产环境：注册 Redis 缓存
var redis_cache = try cache_drivers.RedisCacheDriver.init(redis_config, allocator);
const cache_interface = redis_cache.asInterface();
try container.registerInstance(cache_contract.CacheInterface, &cache_interface, null);

// 在服务中使用
const cache = try container.resolve(cache_contract.CacheInterface);
try cache.set("key", "value", 300);
```

## API 详解

### set() - 设置缓存

```zig
pub fn set(self: CacheInterface, key: []const u8, value: []const u8, ttl: ?u64) !void
```

**参数**：
- `key`：缓存键
- `value`：缓存值
- `ttl`：过期时间（秒），`null` 表示永不过期

**示例**：
```zig
// 设置 300 秒过期
try cache.set("user:1:name", "张三", 300);

// 永不过期
try cache.set("config:version", "1.0.0", null);
```

### get() - 获取缓存

```zig
pub fn get(self: CacheInterface, key: []const u8, allocator: std.mem.Allocator) !?[]const u8
```

**参数**：
- `key`：缓存键
- `allocator`：用于分配返回值的分配器

**返回**：
- `?[]const u8`：缓存值（需要调用者释放），`null` 表示不存在或已过期

**示例**：
```zig
if (cache.get("user:1:name", allocator)) |value| {
    defer allocator.free(value);  // ✅ 必须释放
    std.debug.print("用户名: {s}\n", .{value});
} else {
    std.debug.print("缓存不存在或已过期\n", .{});
}
```

### del() - 删除缓存

```zig
pub fn del(self: CacheInterface, key: []const u8) !void
```

**示例**：
```zig
try cache.del("user:1:name");
```

### exists() - 检查存在

```zig
pub fn exists(self: CacheInterface, key: []const u8) bool
```

**示例**：
```zig
if (cache.exists("user:1:name")) {
    std.debug.print("缓存存在且未过期\n", .{});
}
```

### flush() - 清空所有缓存

```zig
pub fn flush(self: CacheInterface) !void
```

**示例**：
```zig
try cache.flush();  // 清空所有缓存
```

### stats() - 获取统计信息

```zig
pub fn stats(self: CacheInterface) CacheStats
```

**示例**：
```zig
const stats = cache.stats();
std.debug.print("缓存项: {d}, 过期项: {d}\n", .{ stats.count, stats.expired });
```

### cleanupExpired() - 清理过期项

```zig
pub fn cleanupExpired(self: CacheInterface) !void
```

**示例**：
```zig
try cache.cleanupExpired();  // 清理所有过期项
```

### delByPrefix() - 按前缀删除

```zig
pub fn delByPrefix(self: CacheInterface, prefix: []const u8) !void
```

**示例**：
```zig
// 删除所有 user:1: 开头的缓存
try cache.delByPrefix("user:1:");
```

## 最佳实践

### 1. 缓存键命名规范

```zig
// ✅ 推荐：使用冒号分隔的层次结构
"user:1:profile"
"user:1:permissions"
"product:123:details"
"session:abc123:data"

// ❌ 避免：无结构的键名
"user1profile"
"userprofile1"
```

### 2. TTL 设置策略

```zig
// 短期缓存（1-5 分钟）：频繁变化的数据
try cache.set("user:1:online_status", "online", 60);

// 中期缓存（5-30 分钟）：相对稳定的数据
try cache.set("user:1:profile", profile_json, 300);

// 长期缓存（1-24 小时）：很少变化的数据
try cache.set("config:system", config_json, 3600);

// 永久缓存：不变的数据
try cache.set("constant:pi", "3.14159", null);
```

### 3. 缓存穿透防护

```zig
// ✅ 推荐：缓存空值，防止缓存穿透
pub fn getUserById(cache: CacheInterface, db: *Database, id: i32) !?User {
    const key = try std.fmt.allocPrint(allocator, "user:{d}", .{id});
    defer allocator.free(key);

    // 1. 尝试从缓存获取
    if (cache.get(key, allocator)) |cached| {
        defer allocator.free(cached);
        if (std.mem.eql(u8, cached, "null")) {
            return null;  // 缓存的空值
        }
        return try deserializeUser(cached);
    }

    // 2. 从数据库查询
    const user = try db.findUserById(id);

    // 3. 缓存结果（包括空值）
    if (user) |u| {
        const json = try serializeUser(u);
        defer allocator.free(json);
        try cache.set(key, json, 300);
        return u;
    } else {
        try cache.set(key, "null", 60);  // 缓存空值，TTL 较短
        return null;
    }
}
```

### 4. 缓存更新策略

```zig
// ✅ 推荐：写入时更新缓存
pub fn updateUser(cache: CacheInterface, db: *Database, id: i32, data: User) !void {
    // 1. 更新数据库
    try db.updateUser(id, data);

    // 2. 更新缓存
    const key = try std.fmt.allocPrint(allocator, "user:{d}", .{id});
    defer allocator.free(key);

    const json = try serializeUser(data);
    defer allocator.free(json);
    try cache.set(key, json, 300);
}

// ✅ 推荐：删除时清除缓存
pub fn deleteUser(cache: CacheInterface, db: *Database, id: i32) !void {
    // 1. 删除数据库记录
    try db.deleteUser(id);

    // 2. 删除缓存
    const key = try std.fmt.allocPrint(allocator, "user:{d}", .{id});
    defer allocator.free(key);
    try cache.del(key);

    // 3. 删除相关缓存
    try cache.delByPrefix(try std.fmt.allocPrint(allocator, "user:{d}:", .{id}));
}
```

### 5. 批量操作优化

```zig
// ✅ 推荐：批量获取缓存
pub fn getUsersByIds(cache: CacheInterface, db: *Database, ids: []const i32) ![]User {
    var users = std.ArrayList(User).init(allocator);
    defer users.deinit();

    var missing_ids = std.ArrayList(i32).init(allocator);
    defer missing_ids.deinit();

    // 1. 批量从缓存获取
    for (ids) |id| {
        const key = try std.fmt.allocPrint(allocator, "user:{d}", .{id});
        defer allocator.free(key);

        if (cache.get(key, allocator)) |cached| {
            defer allocator.free(cached);
            const user = try deserializeUser(cached);
            try users.append(user);
        } else {
            try missing_ids.append(id);
        }
    }

    // 2. 批量从数据库获取缺失的
    if (missing_ids.items.len > 0) {
        const db_users = try db.findUsersByIds(missing_ids.items);
        defer db.freeUsers(db_users);

        // 3. 批量写入缓存
        for (db_users) |user| {
            const key = try std.fmt.allocPrint(allocator, "user:{d}", .{user.id});
            defer allocator.free(key);

            const json = try serializeUser(user);
            defer allocator.free(json);
            try cache.set(key, json, 300);

            try users.append(user);
        }
    }

    return users.toOwnedSlice();
}
```

### 6. 内存管理

```zig
// ✅ 推荐：使用 defer 确保释放
if (cache.get("key", allocator)) |value| {
    defer allocator.free(value);  // ✅ 必须释放
    // 使用 value...
}

// ✅ 推荐：使用 Arena 简化批量操作
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_allocator = arena.allocator();

for (keys) |key| {
    if (cache.get(key, arena_allocator)) |value| {
        // 无需单独释放，arena.deinit() 会清理所有
        processValue(value);
    }
}
```

## 环境切换

### 开发环境

```zig
// config/development.zig
pub const cache_config = .{
    .driver = "memory",
};

// 初始化
var cache_driver = cache_drivers.MemoryCacheDriver.init(allocator);
defer cache_driver.deinit();
const cache = cache_driver.asInterface();
```

### 生产环境

```zig
// config/production.zig
pub const cache_config = .{
    .driver = "redis",
    .redis = .{
        .host = "redis.example.com",
        .port = 6379,
        .password = "secret",
        .database = 0,
        .max_connections = 20,
    },
};

// 初始化
var cache_driver = try cache_drivers.RedisCacheDriver.init(cache_config.redis, allocator);
defer cache_driver.deinit();
const cache = cache_driver.asInterface();
```

## 性能优化

### 1. 连接池（Redis）

```zig
// ✅ Redis 驱动自动使用连接池
const redis_config = cache_drivers.RedisCacheConfig{
    .max_connections = 20,  // 连接池大小
};
```

### 2. 批量操作

```zig
// ✅ 使用 delByPrefix 批量删除
try cache.delByPrefix("user:1:");  // 删除所有 user:1: 开头的键
```

### 3. 定期清理

```zig
// ✅ 定期清理过期项（内存缓存）
const cleanup_interval = 60;  // 60 秒
while (true) {
    std.time.sleep(cleanup_interval * std.time.ns_per_s);
    try cache.cleanupExpired();
}
```

## 测试

### 单元测试

```zig
test "缓存基本操作" {
    var cache_driver = cache_drivers.MemoryCacheDriver.init(std.testing.allocator);
    defer cache_driver.deinit();
    const cache = cache_driver.asInterface();

    // 设置缓存
    try cache.set("test_key", "test_value", 300);

    // 获取缓存
    const value = cache.get("test_key", std.testing.allocator) orelse return error.CacheNotFound;
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings("test_value", value);

    // 删除缓存
    try cache.del("test_key");
    try std.testing.expect(cache.get("test_key", std.testing.allocator) == null);
}
```

### 集成测试

```zig
test "缓存驱动切换" {
    // 测试内存缓存
    {
        var memory_cache = cache_drivers.MemoryCacheDriver.init(std.testing.allocator);
        defer memory_cache.deinit();
        try testCacheOperations(memory_cache.asInterface());
    }

    // 测试 Redis 缓存（需要 Redis 服务）
    {
        const redis_config = cache_drivers.RedisCacheConfig{};
        var redis_cache = try cache_drivers.RedisCacheDriver.init(redis_config, std.testing.allocator);
        defer redis_cache.deinit();
        try testCacheOperations(redis_cache.asInterface());
    }
}

fn testCacheOperations(cache: cache_contract.CacheInterface) !void {
    try cache.set("key", "value", 300);
    const value = cache.get("key", std.testing.allocator) orelse return error.CacheNotFound;
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings("value", value);
}
```

## 总结

### 优点

1. **统一接口**：所有缓存驱动实现相同的契约
2. **无缝切换**：开发/生产环境切换无需修改代码
3. **类型安全**：编译时检查接口实现
4. **内存安全**：明确的内存所有权和生命周期
5. **易于测试**：可以轻松 Mock 缓存接口

### 注意事项

1. **内存管理**：`get()` 返回的值必须由调用者释放
2. **TTL 设置**：根据数据特性合理设置过期时间
3. **键命名**：使用结构化的键名，便于管理和批量操作
4. **缓存穿透**：缓存空值，防止频繁查询数据库
5. **缓存更新**：写入/删除数据时同步更新缓存

**ZigCMS 缓存系统采用统一契约，规范、安全、易用！**
