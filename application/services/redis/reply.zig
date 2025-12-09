//! Redis 响应处理模块
//!
//! 提供便捷的响应值访问和转换方法。
//! 设计目标是让 API 调用尽可能简洁，类似 Go 的体验。
//!
//! ## 使用示例
//! ```zig
//! const reply = try client.get("mykey");
//! defer reply.deinit();
//!
//! if (reply.isOk()) {
//!     const value = reply.string() orelse "default";
//!     std.debug.print("value: {s}\n", .{value});
//! }
//! ```

const std = @import("std");
const types = @import("types.zig");
const protocol = @import("protocol.zig");

const RedisValue = types.RedisValue;
const RedisError = types.RedisError;

/// Redis 响应封装
///
/// ## 设计理念
///
/// 这个结构体封装了原始的 RedisValue，提供：
/// 1. 更友好的 API（类似 vredis 的 Reply）
/// 2. 自动内存管理
/// 3. 类型转换辅助方法
///
/// ## Go 程序员注意
///
/// Go 中你可能习惯这样：
/// ```go
/// result, err := client.Get("key").Result()
/// if err == redis.Nil {
///     // key 不存在
/// }
/// ```
///
/// Zig 中我们返回 optional 类型而非特殊错误：
/// ```zig
/// if (reply.string()) |value| {
///     // 有值
/// } else {
///     // key 不存在或类型不匹配
/// }
/// ```
pub const Reply = struct {
    /// 原始响应值
    value: RedisValue,
    /// 用于释放内存的分配器
    allocator: std.mem.Allocator,
    /// 标记是否已释放（防止重复释放）
    freed: bool = false,

    /// 创建响应对象
    pub fn init(value: RedisValue, allocator: std.mem.Allocator) Reply {
        return .{
            .value = value,
            .allocator = allocator,
        };
    }

    /// 释放响应占用的内存
    ///
    /// ## 重要：内存安全
    ///
    /// 在 Zig 中，你必须手动管理内存。
    /// 推荐使用 defer 模式：
    /// ```zig
    /// const reply = try client.get("key");
    /// defer reply.deinit();
    /// // 使用 reply...
    /// ```
    ///
    /// 如果忘记调用 deinit，会导致内存泄漏。
    /// 使用 std.testing.allocator 可以在测试中检测泄漏。
    pub fn deinit(self: *Reply) void {
        if (!self.freed) {
            protocol.freeRedisValue(self.allocator, self.value);
            self.freed = true;
        }
    }

    /// 检查响应是否为 "OK"
    ///
    /// 许多 Redis 命令成功时返回 "OK"
    pub fn isOk(self: Reply) bool {
        return switch (self.value) {
            .string => |s| std.mem.eql(u8, s, types.OK_RESPONSE),
            else => false,
        };
    }

    /// 检查响应是否为 nil
    ///
    /// nil 表示 key 不存在或操作没有结果
    pub fn isNil(self: Reply) bool {
        return self.value.isNil();
    }

    /// 检查是否为错误响应
    pub fn isError(self: Reply) bool {
        return self.value.isError();
    }

    /// 获取错误信息
    pub fn getError(self: Reply) ?[]const u8 {
        return switch (self.value) {
            .err => |e| e,
            else => null,
        };
    }

    /// 获取字符串值
    ///
    /// ## Optional 类型 vs Go 的 (value, ok) 模式
    ///
    /// Go:
    /// ```go
    /// if s, ok := reply.String(); ok {
    ///     fmt.Println(s)
    /// }
    /// ```
    ///
    /// Zig 使用 optional 类型（?T）：
    /// ```zig
    /// if (reply.string()) |s| {
    ///     std.debug.print("{s}\n", .{s});
    /// }
    /// ```
    ///
    /// optional 的优势：
    /// 1. 不可能忽略检查（编译器强制）
    /// 2. 使用 orelse 提供默认值更简洁
    pub fn string(self: Reply) ?[]const u8 {
        return self.value.asString();
    }

    /// 获取整数值
    pub fn int(self: Reply) ?i64 {
        return self.value.asInt();
    }

    /// 获取 usize 值（用于长度等）
    pub fn usize_(self: Reply) ?usize {
        if (self.value.asInt()) |i| {
            if (i >= 0) {
                return @intCast(i);
            }
        }
        return null;
    }

    /// 获取布尔值
    ///
    /// Redis 通常用 1/0 表示 true/false
    pub fn boolean(self: Reply) ?bool {
        return switch (self.value) {
            .integer => |i| i != 0,
            .string => |s| {
                if (std.mem.eql(u8, s, "1") or std.mem.eql(u8, s, "OK")) {
                    return true;
                }
                if (std.mem.eql(u8, s, "0")) {
                    return false;
                }
                return null;
            },
            else => null,
        };
    }

    /// 获取浮点数值
    pub fn float(self: Reply) ?f64 {
        return switch (self.value) {
            .string => |s| std.fmt.parseFloat(f64, s) catch null,
            .integer => |i| @floatFromInt(i),
            else => null,
        };
    }

    /// 获取字符串数组
    ///
    /// ## 内存所有权说明
    ///
    /// 返回的切片引用内部数据，不要在 Reply 释放后使用！
    ///
    /// 安全用法：
    /// ```zig
    /// const reply = try client.keys("*");
    /// defer reply.deinit();
    /// if (reply.strings()) |keys| {
    ///     for (keys) |key| {
    ///         std.debug.print("key: {s}\n", .{key});
    ///     }
    /// } // reply.deinit() 在这里被调用，keys 不再有效
    /// ```
    ///
    /// 错误用法：
    /// ```zig
    /// var saved_keys: [][]const u8 = undefined;
    /// {
    ///     const reply = try client.keys("*");
    ///     defer reply.deinit();
    ///     saved_keys = reply.strings().?; // 危险！
    /// } // reply 被释放，saved_keys 指向无效内存
    /// ```
    pub fn strings(self: Reply, allocator: std.mem.Allocator) !?[][]const u8 {
        const arr = self.value.asArray() orelse return null;

        var result = try allocator.alloc([]const u8, arr.len);
        errdefer allocator.free(result);

        for (arr, 0..) |item, i| {
            result[i] = item.asString() orelse "";
        }

        return result;
    }

    /// 获取字符串数组（不分配新内存，直接引用）
    /// 注意：返回的切片在 Reply.deinit() 后无效
    pub fn stringsRef(self: Reply) ?[]RedisValue {
        return self.value.asArray();
    }

    /// 获取原始数组
    pub fn array(self: Reply) ?[]RedisValue {
        return self.value.asArray();
    }

    /// 将数组响应转换为 key-value map
    ///
    /// 用于 HGETALL 等返回交替 key/value 的命令
    ///
    /// ## 内存管理
    ///
    /// 返回的 StringHashMap 需要调用方释放：
    /// ```zig
    /// const map = try reply.toMap();
    /// defer {
    ///     map.deinit();
    /// }
    /// ```
    pub fn toMap(self: Reply, allocator: std.mem.Allocator) !?std.StringHashMap([]const u8) {
        const arr = self.value.asArray() orelse return null;

        if (arr.len % 2 != 0) {
            return RedisError.InvalidResponse;
        }

        var map = std.StringHashMap([]const u8).init(allocator);
        errdefer map.deinit();

        var i: usize = 0;
        while (i < arr.len) : (i += 2) {
            const key = arr[i].asString() orelse continue;
            const value = arr[i + 1].asString() orelse "";
            try map.put(key, value);
        }

        return map;
    }

    /// 比较整数值
    ///
    /// ## 泛型比较
    ///
    /// 这个方法使用 comptime 在编译时确定比较类型
    /// 避免了运行时类型转换的开销
    pub fn equals(self: Reply, comptime T: type, expected: T) bool {
        return switch (@typeInfo(T)) {
            .int, .comptime_int => {
                if (self.int()) |i| {
                    return i == @as(i64, expected);
                }
                return false;
            },
            .pointer => |ptr_info| {
                if (ptr_info.child == u8 or (ptr_info.size == .slice and ptr_info.child == u8)) {
                    if (self.string()) |s| {
                        return std.mem.eql(u8, s, expected);
                    }
                }
                return false;
            },
            else => false,
        };
    }

    /// 获取原始 bytes
    pub fn bytes(self: Reply) ?[]const u8 {
        return self.value.asString();
    }
};

/// 快捷函数：创建 OK 响应（用于测试）
pub fn okReply(allocator: std.mem.Allocator) !Reply {
    const str = try allocator.dupe(u8, "OK");
    return Reply.init(RedisValue{ .string = str }, allocator);
}

/// 快捷函数：创建整数响应（用于测试）
pub fn intReply(value: i64, allocator: std.mem.Allocator) Reply {
    return Reply.init(RedisValue{ .integer = value }, allocator);
}

/// 快捷函数：创建 nil 响应（用于测试）
pub fn nilReply(allocator: std.mem.Allocator) Reply {
    return Reply.init(RedisValue{ .nil = {} }, allocator);
}

// 测试
test "Reply.isOk" {
    const allocator = std.testing.allocator;
    var reply = try okReply(allocator);
    defer reply.deinit();

    try std.testing.expect(reply.isOk());
    try std.testing.expect(!reply.isNil());
}

test "Reply.int" {
    const allocator = std.testing.allocator;
    var reply = intReply(42, allocator);
    defer reply.deinit();

    try std.testing.expectEqual(@as(i64, 42), reply.int().?);
    try std.testing.expect(!reply.isOk());
}

test "Reply.isNil" {
    const allocator = std.testing.allocator;
    var reply = nilReply(allocator);
    defer reply.deinit();

    try std.testing.expect(reply.isNil());
    try std.testing.expect(reply.string() == null);
}

test "Reply.boolean" {
    const allocator = std.testing.allocator;

    // 测试整数 1
    var reply1 = intReply(1, allocator);
    defer reply1.deinit();
    try std.testing.expectEqual(true, reply1.boolean().?);

    // 测试整数 0
    var reply2 = intReply(0, allocator);
    defer reply2.deinit();
    try std.testing.expectEqual(false, reply2.boolean().?);
}

test "Reply.equals" {
    const allocator = std.testing.allocator;

    var reply = intReply(100, allocator);
    defer reply.deinit();

    try std.testing.expect(reply.equals(i64, 100));
    try std.testing.expect(!reply.equals(i64, 99));
}

test "Reply double free protection" {
    const allocator = std.testing.allocator;
    var reply = try okReply(allocator);

    // 第一次释放
    reply.deinit();
    // 第二次释放不会崩溃
    reply.deinit();
}
