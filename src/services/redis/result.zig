//! Redis 结果类型系统
//!
//! 参考 go-redis 的设计，为不同类型的返回值提供专门的结构体。
//!
//! ## 设计理念
//!
//! go-redis 使用类型化的 Cmd 结构体：
//! ```go
//! // StringCmd 用于返回字符串的命令
//! result, err := client.Get(ctx, "key").Result()
//! value := client.Get(ctx, "key").Val()  // 忽略错误，返回零值
//!
//! // IntCmd 用于返回整数的命令
//! count, err := client.Incr(ctx, "counter").Result()
//! ```
//!
//! Zig 版本的设计：
//! ```zig
//! // StringResult 用于返回字符串的命令
//! const result = try client.get("key");
//! defer result.deinit();
//!
//! // 方式 1: 使用 val()，类似 go-redis 的 Val()
//! const value = result.val() orelse "default";
//!
//! // 方式 2: 使用 result()，类似 go-redis 的 Result()
//! if (result.result()) |value| {
//!     std.debug.print("value: {s}\n", .{value});
//! } else |err| {
//!     std.debug.print("error: {}\n", .{err});
//! }
//! ```
//!
//! ## 与 go-redis 的对比
//!
//! | go-redis            | zig-redis                |
//! |---------------------|--------------------------|
//! | StringCmd           | StringResult             |
//! | IntCmd              | IntResult                |
//! | BoolCmd             | BoolResult               |
//! | FloatCmd            | FloatResult              |
//! | SliceCmd            | SliceResult              |
//! | MapStringStringCmd  | MapResult                |
//! | StatusCmd           | StatusResult             |
//!
//! ## 内存管理
//!
//! 所有 Result 类型都需要调用 deinit() 释放内存：
//! ```zig
//! const result = try client.get("key");
//! defer result.deinit();  // 必须！
//! ```

const std = @import("std");
const types = @import("types.zig");
const protocol = @import("protocol.zig");

const RedisValue = types.RedisValue;
const RedisError = types.RedisError;

// ============================================================================
// 基础结果类型
// ============================================================================

/// 字符串结果 - 对应 go-redis 的 StringCmd
///
/// 用于 GET, GETEX, GETSET, HGET 等返回字符串的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.get("user:name");
/// defer result.deinit();
///
/// // 方式 1: val() 返回 optional
/// if (result.val()) |name| {
///     std.debug.print("Hello, {s}!\n", .{name});
/// } else {
///     std.debug.print("User not found\n", .{});
/// }
///
/// // 方式 2: valOr() 提供默认值
/// const name = result.valOr("Guest");
///
/// // 方式 3: result() 返回错误联合
/// const name = try result.result();
/// ```
pub const StringResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取字符串值（可能为 null）
    ///
    /// 类似 go-redis 的 `Val()` 方法。
    /// 如果响应不是字符串或为 nil，返回 null。
    pub fn val(self: StringResult) ?[]const u8 {
        return self.value.asString();
    }

    /// 获取字符串值，如果为空则返回默认值
    ///
    /// 类似 go-redis 的 `Val()` 但带默认值。
    /// ```zig
    /// const name = result.valOr("anonymous");
    /// ```
    pub fn valOr(self: StringResult, default: []const u8) []const u8 {
        return self.val() orelse default;
    }

    /// 获取结果或错误
    ///
    /// 类似 go-redis 的 `Result()` 方法。
    /// ```zig
    /// const value = try result.result();
    /// // 或
    /// if (result.result()) |v| { ... } else |err| { ... }
    /// ```
    pub fn result(self: StringResult) RedisError![]const u8 {
        if (self.value.isError()) {
            return RedisError.ServerError;
        }
        if (self.value.isNil()) {
            return RedisError.KeyNotFound;
        }
        return self.val() orelse RedisError.TypeError;
    }

    /// 检查是否为 nil（key 不存在）
    pub fn isNil(self: StringResult) bool {
        return self.value.isNil();
    }

    /// 检查是否有错误
    pub fn isErr(self: StringResult) bool {
        return self.value.isError();
    }

    /// 获取错误信息（如果有）
    pub fn err(self: StringResult) ?[]const u8 {
        return if (self.value.isError()) self.value.err else null;
    }

    /// 释放内存
    pub fn deinit(self: *StringResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// 整数结果 - 对应 go-redis 的 IntCmd
///
/// 用于 INCR, DECR, LLEN, SCARD, DEL 等返回整数的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.incr("counter");
/// defer result.deinit();
///
/// const count = result.val();  // i64
/// std.debug.print("Counter: {d}\n", .{count});
/// ```
pub const IntResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取整数值
    ///
    /// 如果响应不是整数，返回 0。
    pub fn val(self: IntResult) i64 {
        return self.value.asInt() orelse 0;
    }

    /// 获取结果或错误
    pub fn result(self: IntResult) RedisError!i64 {
        if (self.value.isError()) {
            return RedisError.ServerError;
        }
        return self.value.asInt() orelse RedisError.TypeError;
    }

    /// 检查是否有错误
    pub fn isErr(self: IntResult) bool {
        return self.value.isError();
    }

    /// 释放内存
    pub fn deinit(self: *IntResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// 布尔结果 - 对应 go-redis 的 BoolCmd
///
/// 用于 EXISTS, SISMEMBER, EXPIRE 等返回布尔值的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.exists("user:1");
/// defer result.deinit();
///
/// if (result.val()) {
///     std.debug.print("User exists!\n", .{});
/// }
/// ```
pub const BoolResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取布尔值
    ///
    /// 整数 1 = true, 0 = false
    /// 字符串 "OK" = true
    pub fn val(self: BoolResult) bool {
        return switch (self.value) {
            .integer => |i| i != 0,
            .string => |s| std.mem.eql(u8, s, "OK") or std.mem.eql(u8, s, "1"),
            else => false,
        };
    }

    /// 获取结果或错误
    pub fn result(self: BoolResult) RedisError!bool {
        if (self.value.isError()) {
            return RedisError.ServerError;
        }
        return self.val();
    }

    /// 释放内存
    pub fn deinit(self: *BoolResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// 浮点数结果 - 对应 go-redis 的 FloatCmd
///
/// 用于 INCRBYFLOAT, HINCRBYFLOAT, ZSCORE 等返回浮点数的命令。
pub const FloatResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取浮点数值
    pub fn val(self: FloatResult) f64 {
        // Redis 返回的浮点数是字符串格式
        if (self.value.asString()) |s| {
            return std.fmt.parseFloat(f64, s) catch 0;
        }
        return 0;
    }

    /// 获取结果或错误
    pub fn result(self: FloatResult) RedisError!f64 {
        if (self.value.isError()) {
            return RedisError.ServerError;
        }
        if (self.value.asString()) |s| {
            return std.fmt.parseFloat(f64, s) catch RedisError.TypeError;
        }
        return RedisError.TypeError;
    }

    /// 释放内存
    pub fn deinit(self: *FloatResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// 状态结果 - 对应 go-redis 的 StatusCmd
///
/// 用于 SET, PING, SELECT 等返回状态的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.set("key", "value");
/// defer result.deinit();
///
/// if (result.isOk()) {
///     std.debug.print("SET succeeded\n", .{});
/// }
/// ```
pub const StatusResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 检查状态是否为 OK
    pub fn isOk(self: StatusResult) bool {
        if (self.value.asString()) |s| {
            return std.mem.eql(u8, s, "OK");
        }
        return false;
    }

    /// 获取状态字符串
    pub fn val(self: StatusResult) ?[]const u8 {
        return self.value.asString();
    }

    /// 检查是否有错误
    pub fn isErr(self: StatusResult) bool {
        return self.value.isError();
    }

    /// 获取错误信息
    pub fn err(self: StatusResult) ?[]const u8 {
        return if (self.value.isError()) self.value.err else null;
    }

    /// 释放内存
    pub fn deinit(self: *StatusResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

// ============================================================================
// 复合结果类型
// ============================================================================

/// 字符串切片结果 - 对应 go-redis 的 StringSliceCmd
///
/// 用于 KEYS, MGET, SMEMBERS, LRANGE 等返回字符串数组的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.keys("user:*");
/// defer result.deinit();
///
/// for (result.val()) |key| {
///     std.debug.print("Key: {s}\n", .{key});
/// }
/// ```
pub const SliceResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取数组
    pub fn val(self: SliceResult) []const RedisValue {
        return self.value.asArray() orelse &.{};
    }

    /// 获取字符串数组
    ///
    /// 将数组中的元素转换为字符串切片。
    /// 需要调用者释放返回的切片。
    pub fn strings(self: SliceResult) ![][]const u8 {
        const arr = self.val();
        var result = try self.allocator.alloc([]const u8, arr.len);
        for (arr, 0..) |item, i| {
            result[i] = item.asString() orelse "";
        }
        return result;
    }

    /// 获取数组长度
    pub fn len(self: SliceResult) usize {
        return self.val().len;
    }

    /// 检查是否为空
    pub fn isEmpty(self: SliceResult) bool {
        return self.len() == 0;
    }

    /// 检查是否有错误
    pub fn isErr(self: SliceResult) bool {
        return self.value.isError();
    }

    /// 释放内存
    pub fn deinit(self: *SliceResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// Map 结果 - 对应 go-redis 的 MapStringStringCmd
///
/// 用于 HGETALL 等返回键值对的命令。
///
/// ## 使用示例
/// ```zig
/// const result = try client.hgetall("user:1");
/// defer result.deinit();
///
/// var map = try result.toMap();
/// defer map.deinit();
///
/// if (map.get("name")) |name| {
///     std.debug.print("Name: {s}\n", .{name});
/// }
/// ```
pub const MapResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 将结果转换为 HashMap
    ///
    /// Redis 返回的是交替的 key-value 数组，
    /// 此方法将其转换为方便使用的 HashMap。
    pub fn toMap(self: MapResult) !std.StringHashMap([]const u8) {
        var map = std.StringHashMap([]const u8).init(self.allocator);
        errdefer map.deinit();

        const arr = self.value.asArray() orelse return map;

        var i: usize = 0;
        while (i + 1 < arr.len) : (i += 2) {
            const k = arr[i].asString() orelse continue;
            const v = arr[i + 1].asString() orelse "";
            try map.put(k, v);
        }

        return map;
    }

    /// 获取原始数组
    pub fn val(self: MapResult) []const RedisValue {
        return self.value.asArray() orelse &.{};
    }

    /// 检查是否有错误
    pub fn isErr(self: MapResult) bool {
        return self.value.isError();
    }

    /// 释放内存
    pub fn deinit(self: *MapResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

/// SCAN 结果 - 对应 go-redis 的 ScanCmd
///
/// 用于 SCAN, SSCAN, HSCAN, ZSCAN 等迭代命令。
///
/// ## 使用示例
/// ```zig
/// var cursor: u64 = 0;
/// while (true) {
///     const result = try client.scan(cursor, .{ .pattern = "user:*" });
///     defer result.deinit();
///
///     cursor = result.cursor();
///     for (result.keys()) |key| {
///         std.debug.print("Key: {s}\n", .{key});
///     }
///
///     if (cursor == 0) break;
/// }
/// ```
pub const ScanResult = struct {
    value: RedisValue,
    allocator: std.mem.Allocator,
    freed: bool = false,

    /// 获取下一次迭代的游标
    pub fn cursor(self: ScanResult) u64 {
        const arr = self.value.asArray() orelse return 0;
        if (arr.len < 1) return 0;

        if (arr[0].asString()) |s| {
            return std.fmt.parseInt(u64, s, 10) catch 0;
        }
        return 0;
    }

    /// 获取本次迭代的 keys
    pub fn keys(self: ScanResult) []const RedisValue {
        const arr = self.value.asArray() orelse return &.{};
        if (arr.len < 2) return &.{};
        return arr[1].asArray() orelse &.{};
    }

    /// 检查迭代是否结束
    pub fn isFinished(self: ScanResult) bool {
        return self.cursor() == 0;
    }

    /// 释放内存
    pub fn deinit(self: *ScanResult) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }
};

// ============================================================================
// 工厂函数
// ============================================================================

/// 从 RedisValue 创建 StringResult
pub fn newStringResult(value: RedisValue, allocator: std.mem.Allocator) StringResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 IntResult
pub fn newIntResult(value: RedisValue, allocator: std.mem.Allocator) IntResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 BoolResult
pub fn newBoolResult(value: RedisValue, allocator: std.mem.Allocator) BoolResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 FloatResult
pub fn newFloatResult(value: RedisValue, allocator: std.mem.Allocator) FloatResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 StatusResult
pub fn newStatusResult(value: RedisValue, allocator: std.mem.Allocator) StatusResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 SliceResult
pub fn newSliceResult(value: RedisValue, allocator: std.mem.Allocator) SliceResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 MapResult
pub fn newMapResult(value: RedisValue, allocator: std.mem.Allocator) MapResult {
    return .{ .value = value, .allocator = allocator };
}

/// 从 RedisValue 创建 ScanResult
pub fn newScanResult(value: RedisValue, allocator: std.mem.Allocator) ScanResult {
    return .{ .value = value, .allocator = allocator };
}

// ============================================================================
// 测试
// ============================================================================

test "StringResult.val" {
    const allocator = std.testing.allocator;

    // 分配一个字符串用于测试（模拟真实场景）
    const str = try allocator.dupe(u8, "hello");

    var res = StringResult{
        .value = RedisValue{ .string = str },
        .allocator = allocator,
    };
    defer res.deinit();

    try std.testing.expectEqualStrings("hello", res.val().?);
    try std.testing.expectEqualStrings("hello", res.valOr("default"));
}

test "StringResult.valOr with nil" {
    const allocator = std.testing.allocator;
    var res = StringResult{
        .value = RedisValue{ .nil = {} },
        .allocator = allocator,
    };
    defer res.deinit();

    try std.testing.expect(res.val() == null);
    try std.testing.expectEqualStrings("default", res.valOr("default"));
    try std.testing.expect(res.isNil());
}

test "IntResult.val" {
    const allocator = std.testing.allocator;
    var res = IntResult{
        .value = RedisValue{ .integer = 42 },
        .allocator = allocator,
    };
    defer res.deinit();

    try std.testing.expectEqual(@as(i64, 42), res.val());
}

test "BoolResult.val" {
    const allocator = std.testing.allocator;

    // 测试整数 1 -> true
    var result1 = BoolResult{
        .value = RedisValue{ .integer = 1 },
        .allocator = allocator,
    };
    defer result1.deinit();
    try std.testing.expect(result1.val());

    // 测试整数 0 -> false
    var result2 = BoolResult{
        .value = RedisValue{ .integer = 0 },
        .allocator = allocator,
    };
    defer result2.deinit();
    try std.testing.expect(!result2.val());
}

test "StatusResult.isOk" {
    const allocator = std.testing.allocator;

    // 分配 "OK" 字符串
    const ok_str = try allocator.dupe(u8, "OK");

    var res = StatusResult{
        .value = RedisValue{ .string = ok_str },
        .allocator = allocator,
    };
    defer res.deinit();

    try std.testing.expect(res.isOk());
}
