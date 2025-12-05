//! Zig Redis 客户端库
//!
//! 一个完整的 Redis 客户端实现，支持：
//! - 所有基本数据类型操作（String, Hash, List, Set, Sorted Set）
//! - 连接池管理
//! - 发布/订阅
//! - 线程安全
//!
//! ## 快速开始
//!
//! ```zig
//! const redis = @import("redis");
//!
//! // 方式 1: 单连接使用
//! var conn = try redis.connect(.{
//!     .host = "localhost",
//!     .port = 6379,
//! }, allocator);
//! defer conn.close();
//!
//! // 基本操作
//! var reply = try conn.set("key", "value");
//! reply.deinit();
//!
//! reply = try conn.get("key");
//! defer reply.deinit();
//! std.debug.print("value: {s}\n", .{reply.string().?});
//!
//! // 方式 2: 使用连接池（推荐生产环境）
//! var pool = try redis.createPool(.{
//!     .max_connections = 10,
//!     .conn_options = .{
//!         .host = "localhost",
//!         .password = "secret",
//!     },
//! }, allocator);
//! defer pool.deinit();
//!
//! // 从池中获取连接
//! var pooled = try pool.acquire();
//! defer pooled.release();
//!
//! reply = try pooled.get("key");
//! defer reply.deinit();
//! ```
//!
//! ## 使用命令模块
//!
//! ```zig
//! const conn = try redis.connect(.{}, allocator);
//! defer conn.close();
//!
//! // String 命令
//! const strings = redis.strings(conn);
//! try strings.setEx("session", 3600, "data");
//!
//! // Hash 命令
//! const hash = redis.hash(conn);
//! try hash.hset("user:1", "name", "John");
//!
//! // List 命令
//! const list = redis.list(conn);
//! try list.lpush("queue", &.{"item1", "item2"});
//!
//! // Set 命令
//! const set = redis.set(conn);
//! try set.sadd("tags", &.{"zig", "redis"});
//!
//! // Sorted Set 命令
//! const zset = redis.zset(conn);
//! try zset.zaddOne("leaderboard", 100, "player1");
//! ```
//!
//! ## Go 程序员学习指南
//!
//! ### 内存管理
//!
//! Go 有 GC，Zig 没有。关键点：
//!
//! 1. **使用 defer 释放资源**
//!    ```zig
//!    var reply = try conn.get("key");
//!    defer reply.deinit();  // 类似 Go 的 defer，但作用域结束时执行
//!    ```
//!
//! 2. **errdefer 处理错误路径**
//!    ```zig
//!    var resource = try allocate();
//!    errdefer resource.deinit();  // 仅在函数返回错误时执行
//!    // ...更多操作，如果出错会自动清理 resource
//!    return resource;  // 成功时不会执行 errdefer
//!    ```
//!
//! ### 错误处理
//!
//! Go: `value, err := f()`
//! Zig: 使用 `try` 或 `catch`
//!
//! ```zig
//! // 类似 Go 的 if err != nil { return err }
//! const value = try f();
//!
//! // 类似 Go 的 if err != nil { handle(err) }
//! const value = f() catch |err| {
//!     // 处理错误
//!     return defaultValue;
//! };
//!
//! // 类似 Go 的 if v, err := f(); err == nil { use(v) }
//! if (f()) |value| {
//!     use(value);
//! } else |err| {
//!     handleError(err);
//! }
//! ```
//!
//! ### Optional 类型
//!
//! Go: `value, ok := map[key]`
//! Zig: `?T` 类型
//!
//! ```zig
//! if (reply.string()) |s| {
//!     // s 是 []const u8
//! } else {
//!     // 值为 null
//! }
//!
//! // 提供默认值
//! const s = reply.string() orelse "default";
//! ```

const std = @import("std");

// ========================================
// 导出核心模块
// ========================================

/// 类型定义
pub const types = @import("types.zig");

/// RESP 协议
pub const protocol = @import("protocol.zig");

/// 命令构建器
pub const command = @import("command.zig");

/// 响应处理
pub const reply = @import("reply.zig");

/// 类型化结果（参考 go-redis 的 StringCmd, IntCmd 等）
pub const result = @import("result.zig");

/// 动态参数构建器
pub const args = @import("args.zig");

/// 连接管理
pub const connection = @import("connection.zig");

/// 连接池
pub const pool = @import("pool.zig");

/// 命令模块
pub const commands = @import("commands.zig");

// ========================================
// 导出常用类型
// ========================================

/// Redis 连接
pub const Connection = connection.Connection;

/// 连接池
pub const Pool = pool.Pool;

/// 池化连接
pub const PooledConnection = pool.PooledConnection;

/// 响应对象
pub const Reply = reply.Reply;

/// 连接选项
pub const ConnectOptions = types.ConnectOptions;

/// 连接池选项
pub const PoolOptions = types.PoolOptions;

/// SET 命令选项
pub const SetOptions = types.SetOptions;

/// SCAN 选项
pub const ScanOptions = types.ScanOptions;

/// ZRANGE 选项
pub const ZRangeOptions = types.ZRangeOptions;

/// Redis 错误类型
pub const RedisError = types.RedisError;

// ========================================
// 类型化结果类型（类似 go-redis 的 Cmd 类型）
// ========================================

/// 字符串结果 - 对应 go-redis 的 StringCmd
pub const StringResult = result.StringResult;

/// 整数结果 - 对应 go-redis 的 IntCmd
pub const IntResult = result.IntResult;

/// 布尔结果 - 对应 go-redis 的 BoolCmd
pub const BoolResult = result.BoolResult;

/// 浮点数结果 - 对应 go-redis 的 FloatCmd
pub const FloatResult = result.FloatResult;

/// 状态结果 - 对应 go-redis 的 StatusCmd
pub const StatusResult = result.StatusResult;

/// 切片结果 - 对应 go-redis 的 SliceCmd
pub const SliceResult = result.SliceResult;

/// Map 结果 - 对应 go-redis 的 MapStringStringCmd
pub const MapResult = result.MapResult;

/// SCAN 结果 - 对应 go-redis 的 ScanCmd
pub const ScanResult = result.ScanResult;

// ========================================
// 动态参数构建
// ========================================

/// 动态参数构建器（类似 Go 的 []any 动态追加）
///
/// ## 使用示例
///
/// ```zig
/// var a = Args.init(allocator);
/// defer a.deinit();
///
/// // 动态构造 SET 命令参数
/// _ = try a.add("SET");
/// _ = try a.add(key);
/// _ = try a.add(value);
/// _ = try a.addIf(ttl > 0, "EX");
/// _ = try a.addIf(ttl > 0, ttl);
/// _ = try a.flag(opts.nx, "NX");
///
/// var reply = try conn.doArgs(&a);
/// defer reply.deinit();
/// ```
pub const Args = args.Args;

/// 命令构建器
pub const CommandBuilder = command.CommandBuilder;

// ========================================
// 便捷函数
// ========================================

/// 创建单个连接
///
/// ## 参数
/// - options: 连接选项
/// - allocator: 内存分配器
///
/// ## 返回
/// 连接对象指针，使用完毕后需调用 close()
///
/// ## 示例
/// ```zig
/// var conn = try redis.connect(.{
///     .host = "localhost",
///     .port = 6379,
///     .password = "secret",
/// }, allocator);
/// defer conn.close();
/// ```
pub fn connect(options: ConnectOptions, allocator: std.mem.Allocator) !*Connection {
    return connection.connect(options, allocator);
}

/// 使用默认选项创建连接
pub fn connectDefault(allocator: std.mem.Allocator) !*Connection {
    return connection.connectDefault(allocator);
}

/// 创建连接池
///
/// ## 参数
/// - options: 连接池选项
/// - allocator: 内存分配器
///
/// ## 返回
/// 连接池对象指针，使用完毕后需调用 deinit()
///
/// ## 示例
/// ```zig
/// var pool = try redis.createPool(.{
///     .max_connections = 20,
///     .conn_options = .{
///         .host = "localhost",
///     },
/// }, allocator);
/// defer pool.deinit();
///
/// var conn = try pool.acquire();
/// defer conn.release();
/// ```
pub fn createPool(options: PoolOptions, allocator: std.mem.Allocator) !*Pool {
    return pool.createPool(options, allocator);
}

/// 使用默认选项创建连接池
pub fn createDefaultPool(allocator: std.mem.Allocator) !*Pool {
    return pool.createDefaultPool(allocator);
}

// ========================================
// 命令模块便捷函数
// ========================================

/// 获取 String 命令接口
pub fn strings(conn: *Connection) commands.StringCommands {
    return commands.StringCommands.init(conn);
}

/// 获取 Hash 命令接口
pub fn hash(conn: *Connection) commands.HashCommands {
    return commands.HashCommands.init(conn);
}

/// 获取 List 命令接口
pub fn list(conn: *Connection) commands.ListCommands {
    return commands.ListCommands.init(conn);
}

/// 获取 Set 命令接口
pub fn set(conn: *Connection) commands.SetCommands {
    return commands.SetCommands.init(conn);
}

/// 获取 Sorted Set 命令接口
pub fn zset(conn: *Connection) commands.ZSetCommands {
    return commands.ZSetCommands.init(conn);
}

/// 获取 Pub/Sub 命令接口
pub fn pubsub(conn: *Connection) commands.PubSubCommands {
    return commands.PubSubCommands.init(conn);
}

// ========================================
// 测试
// ========================================

test "redis module imports" {
    // 确保所有模块可以正确导入
    _ = types;
    _ = protocol;
    _ = command;
    _ = reply;
    _ = connection;
    _ = pool;
    _ = commands;
}

test "types" {
    _ = @import("types.zig");
}

test "protocol" {
    _ = @import("protocol.zig");
}

test "command" {
    _ = @import("command.zig");
}

test "reply" {
    _ = @import("reply.zig");
}
