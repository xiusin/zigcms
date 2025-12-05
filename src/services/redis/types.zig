//! Redis 客户端基础类型定义
//!
//! 本文件定义了 Redis 客户端使用的所有基础类型和错误码。
//! 对于 Go 程序员来说，这相当于 Go 中的 types.go 或 errors.go
//!
//! ## Zig vs Go 类型系统对比
//! - Go: `type MyError string` 或 `var ErrXxx = errors.New("xxx")`
//! - Zig: 使用 `error` 枚举，编译器会自动追踪错误传播
//!
//! ## 为什么 Zig 的错误处理更安全？
//! 1. 错误必须被显式处理，不能被忽略（除非用 `catch unreachable`）
//! 2. 编译器会检查所有可能的错误路径
//! 3. 错误类型在编译时已知，不像 Go 的 `error` 接口需要运行时类型断言

const std = @import("std");

/// Redis 错误类型枚举
/// 
/// 在 Go 中你可能这样定义:
/// ```go
/// var (
///     ErrConnectionClosed = errors.New("connection closed")
///     ErrPoolExhausted    = errors.New("pool exhausted")
/// )
/// ```
/// 
/// Zig 的 error 枚举是编译时类型安全的，且零运行时开销
pub const RedisError = error{
    /// 连接已关闭
    ConnectionClosed,
    /// 连接池已耗尽
    PoolExhausted,
    /// 连接获取失败
    PoolGetFailed,
    /// 连接不活跃
    ConnectionNotActive,
    /// 读取消息错误
    ReadMessageError,
    /// 协议解析错误
    ProtocolError,
    /// 认证失败
    AuthenticationFailed,
    /// 选择数据库失败
    SelectDatabaseFailed,
    /// 无效的响应格式
    InvalidResponse,
    /// 服务器返回错误
    ServerError,
    /// 连接超时
    ConnectionTimeout,
    /// 写入失败
    WriteFailed,
    /// 读取失败
    ReadFailed,
    /// 无效参数
    InvalidArgument,
    /// 内存分配失败
    OutOfMemory,
    /// 空响应
    NilResponse,
    /// Key 不存在（类似 go-redis 的 redis.Nil）
    KeyNotFound,
    /// 类型错误（期望的类型与实际类型不匹配）
    TypeError,
};

/// RESP 协议响应类型
/// 
/// Redis 使用 RESP (Redis Serialization Protocol) 协议
/// 每种响应以不同的前缀字符开头：
/// - '+' 简单字符串
/// - '-' 错误
/// - ':' 整数
/// - '$' 批量字符串
/// - '*' 数组
pub const RespType = enum(u8) {
    simple_string = '+',
    err = '-',
    integer = ':',
    bulk_string = '$',
    array = '*',

    /// 从字节解析响应类型
    /// 
    /// 这是 Zig 中给枚举添加方法的方式
    /// Go 中需要定义一个独立的函数: `func ParseRespType(b byte) RespType`
    pub fn fromByte(byte: u8) ?RespType {
        return switch (byte) {
            '+' => .simple_string,
            '-' => .err,
            ':' => .integer,
            '$' => .bulk_string,
            '*' => .array,
            else => null,
        };
    }
};

/// Redis 值的联合类型
/// 
/// ## Zig Tagged Union vs Go interface{}
/// 
/// Go 中处理多种类型通常用 interface{}:
/// ```go
/// func (r *Reply) Value() interface{} { ... }
/// ```
/// 问题：需要运行时类型断言，可能 panic
/// 
/// Zig 使用 tagged union，编译时类型安全：
/// ```zig
/// switch (value) {
///     .string => |s| ...,  // s 的类型已知是 []const u8
///     .integer => |i| ..., // i 的类型已知是 i64
/// }
/// ```
pub const RedisValue = union(enum) {
    /// 字符串值
    string: []const u8,
    /// 整数值
    integer: i64,
    /// 数组值（存储索引到父数组的引用）
    array: []RedisValue,
    /// 空值
    nil: void,
    /// 错误信息
    err: []const u8,

    /// 尝试获取字符串值
    /// 
    /// 返回 optional 类型 `?[]const u8`
    /// Go 中你需要: `if s, ok := v.(string); ok { ... }`
    /// Zig 中: `if (v.asString()) |s| { ... }`
    pub fn asString(self: RedisValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    /// 尝试获取整数值
    pub fn asInt(self: RedisValue) ?i64 {
        return switch (self) {
            .integer => |i| i,
            .string => |s| std.fmt.parseInt(i64, s, 10) catch null,
            else => null,
        };
    }

    /// 尝试获取数组值
    pub fn asArray(self: RedisValue) ?[]RedisValue {
        return switch (self) {
            .array => |a| a,
            else => null,
        };
    }

    /// 检查是否为 nil
    pub fn isNil(self: RedisValue) bool {
        return self == .nil;
    }

    /// 检查是否为错误
    pub fn isError(self: RedisValue) bool {
        return switch (self) {
            .err => true,
            else => false,
        };
    }
};

/// 连接配置选项
/// 
/// ## Zig struct 默认值 vs Go struct
/// 
/// Go 中需要构造函数或零值：
/// ```go
/// type ConnOpts struct {
///     Host string // 默认是 ""，需要在代码中检查
///     Port int    // 默认是 0
/// }
/// func NewConnOpts() *ConnOpts {
///     return &ConnOpts{Host: "127.0.0.1", Port: 6379}
/// }
/// ```
/// 
/// Zig 可以直接在 struct 定义中指定默认值：
pub const ConnectOptions = struct {
    /// 主机地址
    host: []const u8 = "127.0.0.1",
    /// 端口号
    port: u16 = 6379,
    /// 数据库索引
    database: u32 = 0,
    /// 用户名（Redis 6.0+ ACL）
    username: ?[]const u8 = null,
    /// 密码
    password: ?[]const u8 = null,
    /// 客户端名称
    client_name: ?[]const u8 = null,
    /// 读取超时（纳秒）
    /// 使用 u64 是因为 Zig 标准库的时间单位是纳秒
    read_timeout_ns: u64 = 10 * std.time.ns_per_s,
    /// 写入超时（纳秒）
    write_timeout_ns: u64 = 10 * std.time.ns_per_s,
    /// 连接超时（纳秒）
    connect_timeout_ns: u64 = 5 * std.time.ns_per_s,
};

/// 连接池配置选项
pub const PoolOptions = struct {
    /// 最大活跃连接数
    max_connections: u32 = 10,
    /// 最小空闲连接数
    min_idle_connections: u32 = 1,
    /// 空闲超时（纳秒）- 超过此时间的空闲连接会被关闭
    idle_timeout_ns: u64 = 600 * std.time.ns_per_s,
    /// 连接最大存活时间（纳秒）
    max_lifetime_ns: u64 = 600 * std.time.ns_per_s,
    /// 获取连接的等待超时（纳秒）
    wait_timeout_ns: u64 = 3 * std.time.ns_per_s,
    /// 连接选项
    conn_options: ConnectOptions = .{},
};

/// SET 命令选项
/// 
/// 对应 Redis SET 命令的可选参数：
/// SET key value [EX seconds] [PX milliseconds] [NX|XX] [KEEPTTL]
pub const SetOptions = struct {
    /// 过期时间（秒）
    ex_seconds: ?i64 = null,
    /// 过期时间（毫秒）
    px_milliseconds: ?i64 = null,
    /// 仅当 key 不存在时设置
    nx: bool = false,
    /// 仅当 key 存在时设置
    xx: bool = false,
    /// 保留原有的 TTL
    keep_ttl: bool = false,
};

/// SCAN 命令选项
pub const ScanOptions = struct {
    /// 游标位置
    cursor: u64 = 0,
    /// 匹配模式
    pattern: ?[]const u8 = null,
    /// 返回数量提示
    count: ?u64 = null,
    /// 类型过滤（SCAN 命令支持）
    scan_type: ?[]const u8 = null,
};

/// SCAN 命令返回结果
pub const ScanResult = struct {
    /// 下一个游标位置，为 0 表示遍历结束
    cursor: u64,
    /// 本次返回的 key 列表
    keys: [][]const u8,
    /// 用于释放内存的分配器
    allocator: std.mem.Allocator,

    /// 释放结果占用的内存
    /// 
    /// ## 重要：Zig 内存管理
    /// 
    /// Go 有 GC，你不需要关心内存释放
    /// Zig 需要手动管理内存，但这带来了：
    /// 1. 零 GC 停顿
    /// 2. 可预测的内存使用
    /// 3. 更小的二进制文件
    /// 
    /// 使用 `defer result.deinit()` 确保内存被释放
    pub fn deinit(self: *ScanResult) void {
        for (self.keys) |key| {
            self.allocator.free(key);
        }
        self.allocator.free(self.keys);
    }
};

/// ZRANGE 命令选项
pub const ZRangeOptions = struct {
    /// 是否返回分数
    with_scores: bool = false,
    /// LIMIT offset
    offset: ?i64 = null,
    /// LIMIT count
    count: ?i64 = null,
    /// 是否逆序
    reverse: bool = false,
};

/// 阻塞弹出结果
pub const BPopResult = struct {
    /// 弹出元素的 key
    key: []const u8,
    /// 弹出的值
    value: []const u8,
};

/// 常量定义
pub const CRLF = "\r\n";
pub const NIL_BULK = "$-1\r\n";
pub const NIL_ARRAY = "*-1\r\n";
pub const OK_RESPONSE = "OK";

// 测试模块
//
// Zig 的测试是内置的，不需要单独的测试框架
// 运行: `zig test types.zig`
test "RespType.fromByte" {
    // 测试有效的类型字符
    try std.testing.expectEqual(RespType.simple_string, RespType.fromByte('+').?);
    try std.testing.expectEqual(RespType.err, RespType.fromByte('-').?);
    try std.testing.expectEqual(RespType.integer, RespType.fromByte(':').?);
    try std.testing.expectEqual(RespType.bulk_string, RespType.fromByte('$').?);
    try std.testing.expectEqual(RespType.array, RespType.fromByte('*').?);

    // 测试无效字符返回 null
    try std.testing.expect(RespType.fromByte('x') == null);
}

test "RedisValue.asString" {
    const str_val = RedisValue{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", str_val.asString().?);

    const int_val = RedisValue{ .integer = 42 };
    try std.testing.expect(int_val.asString() == null);
}

test "RedisValue.asInt" {
    const int_val = RedisValue{ .integer = 42 };
    try std.testing.expectEqual(@as(i64, 42), int_val.asInt().?);

    // 字符串也可以解析为整数
    const str_val = RedisValue{ .string = "123" };
    try std.testing.expectEqual(@as(i64, 123), str_val.asInt().?);

    // 无效字符串返回 null
    const invalid = RedisValue{ .string = "abc" };
    try std.testing.expect(invalid.asInt() == null);
}
