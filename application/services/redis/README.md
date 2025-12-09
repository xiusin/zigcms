# Zig Redis 客户端

一个用 Zig 语言实现的 Redis 客户端库，参考 [vredis](https://github.com/xiusin/vredis) 和 [go-redis](https://github.com/redis/go-redis) 设计。

## 特性

- ✅ 完整的 RESP 协议支持
- ✅ 连接池管理
- ✅ 线程安全
- ✅ 支持所有主要数据类型（String, Hash, List, Set, Sorted Set）
- ✅ Pub/Sub 发布订阅
- ✅ **类型化结果系统**（类似 go-redis 的 StringCmd, IntCmd 等）
- ✅ 类型安全的 API
- ✅ 详细的中文注释（帮助 Go 程序员学习 Zig）

## 快速开始

### 单连接使用

```zig
const std = @import("std");
const redis = @import("services/redis/redis.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建连接
    var conn = try redis.connect(.{
        .host = "127.0.0.1",
        .port = 6379,
        .password = null,  // 如果有密码
    }, allocator);
    defer conn.close();

    // SET 命令 - 返回 StatusResult
    var set_result = try conn.set("mykey", "hello world");
    defer set_result.deinit();
    
    if (set_result.isOk()) {
        std.debug.print("SET 成功\n", .{});
    }

    // GET 命令 - 返回 StringResult（类似 go-redis 的 StringCmd）
    var get_result = try conn.get("mykey");
    defer get_result.deinit();
    
    // 方式 1: 使用 val()，类似 go-redis 的 Val()
    if (get_result.val()) |value| {
        std.debug.print("GET 结果: {s}\n", .{value});
    }
    
    // 方式 2: 使用 valOr() 提供默认值
    const value = get_result.valOr("默认值");
    std.debug.print("值: {s}\n", .{value});
    
    // 方式 3: 检查 nil（类似 go-redis 的 redis.Nil）
    if (get_result.isNil()) {
        std.debug.print("Key 不存在\n", .{});
    }
}
```

### 使用连接池（推荐）

```zig
const redis = @import("services/redis/redis.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // 创建连接池
    var pool = try redis.createPool(.{
        .max_connections = 10,
        .conn_options = .{
            .host = "127.0.0.1",
            .port = 6379,
        },
    }, allocator);
    defer pool.deinit();

    // 从池中获取连接
    var conn = try pool.acquire();
    defer conn.release();  // 必须释放！

    // 使用连接
    var reply = try conn.get("mykey");
    defer reply.deinit();
}
```

### 使用命令模块

```zig
const redis = @import("services/redis/redis.zig");

pub fn main() !void {
    // ... 创建连接 ...

    // String 命令
    const strings = redis.strings(conn);
    _ = try strings.setEx("session:123", 3600, "user_data");
    const val = try strings.incr("counter");

    // Hash 命令
    const hash = redis.hash(conn);
    _ = try hash.hset("user:1", "name", "张三");
    _ = try hash.hincrBy("user:1", "score", 10);

    // List 命令
    const list = redis.list(conn);
    _ = try list.lpush("queue", &.{"task1", "task2"});
    var item = try list.rpop("queue");
    defer item.deinit();

    // Set 命令
    const set = redis.set(conn);
    _ = try set.sadd("tags", &.{"zig", "redis", "database"});

    // Sorted Set 命令
    const zset = redis.zset(conn);
    _ = try zset.zaddOne("leaderboard", 1000, "player1");
}
```

## 目录结构

```
redis/
├── redis.zig       # 主入口文件
├── types.zig       # 类型定义
├── protocol.zig    # RESP 协议解析
├── command.zig     # 命令构建器
├── reply.zig       # 响应处理（旧版）
├── result.zig      # 类型化结果系统（推荐，类似 go-redis）
├── connection.zig  # 连接管理
├── pool.zig        # 连接池
├── commands.zig    # 命令模块汇总
├── commands/       # 各类型命令实现
│   ├── strings.zig
│   ├── hash.zig
│   ├── list.zig
│   ├── set.zig
│   ├── zset.zig
│   └── pubsub.zig
├── tests.zig       # 集成测试
└── README.md       # 本文档
```

## 动态参数构建（类似 Go 的 []any）

zig-redis 提供 `Args` 构建器，支持根据条件动态构造命令参数：

### Go 风格对比

```go
// Go: 使用 []interface{} 动态构造
args := []interface{}{"SET", key, value}
if opts.EX > 0 {
    args = append(args, "EX", opts.EX)
}
if opts.NX {
    args = append(args, "NX")
}
client.Do(ctx, args...)
```

```zig
// Zig: 使用 Args 构建器
var a = redis.Args.init(allocator);
defer a.deinit();

_ = try a.add("SET");
_ = try a.add(key);
_ = try a.add(value);
_ = try a.addIf(opts.ex > 0, "EX");
_ = try a.addIf(opts.ex > 0, opts.ex);
_ = try a.flag(opts.nx, "NX");

var reply = try conn.doArgs(&a);
defer reply.deinit();
```

### Args 主要方法

| 方法 | 说明 |
|------|------|
| `add(value)` | 添加任意类型参数 |
| `addIf(cond, value)` | 条件添加参数 |
| `flag(cond, name)` | 条件添加标志字符串 |
| `optional(prefix, ?value)` | 添加可选参数（null 时不添加） |
| `many(tuple)` | 添加多个参数 |
| `when(cond)/endWhen()` | 条件链式调用 |

### 实际示例：SET 命令选项

```zig
const SetOptions = struct {
    ex: ?i64 = null,       // 过期秒数
    px: ?i64 = null,       // 过期毫秒数
    nx: bool = false,      // 仅当不存在时设置
    xx: bool = false,      // 仅当存在时设置
    keepttl: bool = false, // 保留原有 TTL
    get: bool = false,     // 返回旧值
};

fn setWithOptions(conn: *Connection, key: []const u8, value: []const u8, opts: SetOptions) !Reply {
    var a = redis.Args.init(conn.allocator);
    defer a.deinit();

    _ = try a.add("SET");
    _ = try a.add(key);
    _ = try a.add(value);
    _ = try a.optional("EX", opts.ex);
    _ = try a.optional("PX", opts.px);
    _ = try a.flag(opts.nx, "NX");
    _ = try a.flag(opts.xx, "XX");
    _ = try a.flag(opts.keepttl, "KEEPTTL");
    _ = try a.flag(opts.get, "GET");

    return conn.doArgs(&a);
}
```

## 类型化结果系统（参考 go-redis）

zig-redis 的返回值设计参考了 go-redis 的 Cmd 类型系统：

| go-redis            | zig-redis        | 说明 |
|---------------------|------------------|------|
| StringCmd           | StringResult     | GET, HGET 等返回字符串 |
| IntCmd              | IntResult        | INCR, DEL 等返回整数 |
| BoolCmd             | BoolResult       | EXISTS, EXPIRE 等返回布尔 |
| FloatCmd            | FloatResult      | INCRBYFLOAT 等返回浮点数 |
| StatusCmd           | StatusResult     | SET, PING 等返回状态 |
| SliceCmd            | SliceResult      | KEYS, SMEMBERS 等返回数组 |
| MapStringStringCmd  | MapResult        | HGETALL 等返回映射 |
| ScanCmd             | ScanResult       | SCAN 迭代结果 |

### 使用示例

```zig
// go-redis 风格
// val, err := client.Get(ctx, "key").Result()
// if err == redis.Nil { ... }

// zig-redis 对应写法
var result = try conn.get("key");
defer result.deinit();

// 获取值（类似 Val()）
const value = result.val();

// 带默认值（类似 Val() 的便捷写法）
const value = result.valOr("default");

// 检查是否为空（类似检查 redis.Nil）
if (result.isNil()) {
    // key 不存在
}

// 获取结果或错误（类似 Result()）
if (result.result()) |v| {
    // 使用 v
} else |err| {
    // 处理错误
}
```

## Go vs Zig 对照

### 错误处理

**Go:**
```go
value, err := client.Get("key").Result()
if err != nil {
    return err
}
```

**Zig:**
```zig
// 方式 1: try（错误向上传播）
const value = try conn.get("key");

// 方式 2: catch（处理错误）
const value = conn.get("key") catch |err| {
    std.debug.print("Error: {}\n", .{err});
    return err;
};
```

### 内存管理

**Go:**
```go
// GC 自动管理，无需手动释放
result := client.Get("key").Val()
```

**Zig:**
```zig
// 必须手动释放
var reply = try conn.get("key");
defer reply.deinit();  // 确保释放

const value = reply.string();
```

### Optional 类型

**Go:**
```go
val, ok := someMap["key"]
if ok {
    // 使用 val
}
```

**Zig:**
```zig
if (reply.string()) |val| {
    // val 是 []const u8
} else {
    // 值为 null
}

// 或使用 orelse 提供默认值
const val = reply.string() orelse "default";
```

### 结构体初始化

**Go:**
```go
opts := &ConnOpts{
    Host: "localhost",
    Port: 6379,
}
```

**Zig:**
```zig
const opts = redis.ConnectOptions{
    .host = "localhost",
    .port = 6379,
};

// 或使用默认值
const opts = redis.ConnectOptions{};  // 使用所有默认值
```

## 运行测试

```bash
# 确保 Redis 运行中
redis-server

# 运行所有测试
zig test src/services/redis/tests.zig

# 运行特定模块测试
zig test src/services/redis/protocol.zig
zig test src/services/redis/command.zig
```

## 注意事项

1. **内存安全**: 所有返回 `Reply` 的方法都需要调用 `deinit()` 释放内存
2. **线程安全**: 单个 `Connection` 是线程安全的，但建议使用连接池
3. **连接池**: 必须调用 `release()` 归还连接，否则会耗尽池
4. **Pub/Sub**: 订阅会阻塞连接，需要单独的连接处理

## License

MIT
