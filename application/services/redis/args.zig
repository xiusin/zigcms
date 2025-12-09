//! 动态参数构建器
//!
//! 本模块提供类似 Go `[]any` 的动态参数构造能力，
//! 支持根据条件动态添加不同类型的参数。
//!
//! ## 设计目标
//!
//! 让 Go 程序员感到熟悉：
//! ```go
//! // Go 风格
//! args := []interface{}{"SET", key, value}
//! if opts.EX > 0 {
//!     args = append(args, "EX", opts.EX)
//! }
//! if opts.NX {
//!     args = append(args, "NX")
//! }
//! client.Do(ctx, args...)
//! ```
//!
//! Zig 版本：
//! ```zig
//! var args = Args.init(allocator);
//! defer args.deinit();
//!
//! try args.add("SET").add(key).add(value);
//! try args.when(opts.ex > 0).add("EX").add(opts.ex);
//! try args.when(opts.nx).add("NX");
//!
//! try conn.doArgs(args);
//! ```
//!
//! ## 安全保证
//!
//! 1. 所有数值类型会被转换为字符串并存储在内部缓冲区
//! 2. 调用 `deinit()` 时会释放所有分配的内存
//! 3. 使用 `defer args.deinit()` 确保资源释放
//! 4. 编译时类型检查，避免运行时错误

const std = @import("std");
const types = @import("types.zig");
const CommandBuilder = @import("command.zig").CommandBuilder;

/// 参数值联合类型
///
/// 类似 Go 的 `interface{}`，但是编译时类型安全
pub const Arg = union(enum) {
    string: []const u8,
    int: i64,
    uint: u64,
    float: f64,
    boolean: bool,
    bytes: []const u8,
};

/// 动态参数构建器
///
/// ## 使用示例
///
/// ### 基础用法
/// ```zig
/// var args = Args.init(allocator);
/// defer args.deinit();
///
/// // 链式添加参数
/// _ = try args.add("SET").add("key").add("value");
///
/// // 发送命令
/// const reply = try conn.doArgs(args);
/// ```
///
/// ### 条件构造（类似 Go 的动态 append）
/// ```zig
/// // SET key value [EX seconds] [PX ms] [NX|XX] [KEEPTTL] [GET]
/// const SetOptions = struct {
///     ex: ?i64 = null,        // 过期秒数
///     px: ?i64 = null,        // 过期毫秒数
///     nx: bool = false,       // 仅当不存在时设置
///     xx: bool = false,       // 仅当存在时设置
///     keepttl: bool = false,  // 保留原有 TTL
///     get: bool = false,      // 返回旧值
/// };
///
/// fn setEx(args: *Args, key: []const u8, value: []const u8, opts: SetOptions) !void {
///     _ = try args.add("SET").add(key).add(value);
///
///     // 条件添加 EX
///     if (opts.ex) |ex| {
///         _ = try args.add("EX").add(ex);
///     }
///
///     // 条件添加 PX
///     if (opts.px) |px| {
///         _ = try args.add("PX").add(px);
///     }
///
///     // 条件添加标志
///     _ = try args.flag(opts.nx, "NX");
///     _ = try args.flag(opts.xx, "XX");
///     _ = try args.flag(opts.keepttl, "KEEPTTL");
///     _ = try args.flag(opts.get, "GET");
/// }
/// ```
///
/// ### 批量添加
/// ```zig
/// // MSET key1 value1 key2 value2 ...
/// var args = Args.init(allocator);
/// _ = try args.add("MSET");
///
/// const pairs = [_][2][]const u8{
///     .{"key1", "value1"},
///     .{"key2", "value2"},
///     .{"key3", "value3"},
/// };
///
/// for (pairs) |pair| {
///     _ = try args.add(pair[0]).add(pair[1]);
/// }
/// ```
pub const Args = struct {
    /// 内部使用 CommandBuilder 存储参数
    builder: CommandBuilder,
    /// 是否启用添加（用于条件链式调用）
    enabled: bool = true,

    const Self = @This();

    /// 初始化参数构建器
    ///
    /// ## 使用模式
    /// ```zig
    /// var args = Args.init(allocator);
    /// defer args.deinit();  // 必须调用！
    /// ```
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .builder = CommandBuilder.init(allocator),
        };
    }

    /// 释放所有资源
    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }

    /// 重置参数列表（保留容量以便复用）
    pub fn reset(self: *Self) void {
        self.builder.reset();
        self.enabled = true;
    }

    /// 添加任意类型参数
    ///
    /// 支持的类型：
    /// - 字符串: `[]const u8`, 字符串字面量
    /// - 整数: `i8` ~ `i64`, `u8` ~ `u64`
    /// - 浮点: `f32`, `f64`
    /// - 布尔: `bool` (转换为 "1" 或 "0")
    ///
    /// ## 示例
    /// ```zig
    /// _ = try args.add("SET");      // 字符串
    /// _ = try args.add(3600);       // 整数
    /// _ = try args.add(3.14);       // 浮点数
    /// ```
    pub fn add(self: *Self, value: anytype) !*Self {
        if (self.enabled) {
            _ = try self.builder.add(value);
        }
        return self;
    }

    /// 添加字符串参数
    pub fn addStr(self: *Self, value: []const u8) !*Self {
        if (self.enabled) {
            _ = try self.builder.addStr(value);
        }
        return self;
    }

    /// 添加整数参数
    pub fn addInt(self: *Self, value: i64) !*Self {
        if (self.enabled) {
            _ = try self.builder.addInt(value);
        }
        return self;
    }

    /// 添加无符号整数参数
    pub fn addUint(self: *Self, value: u64) !*Self {
        if (self.enabled) {
            _ = try self.builder.addUint(value);
        }
        return self;
    }

    /// 添加浮点数参数
    pub fn addFloat(self: *Self, value: f64) !*Self {
        if (self.enabled) {
            _ = try self.builder.addFloat(value);
        }
        return self;
    }

    /// 添加布尔标志
    ///
    /// 如果 condition 为 true，添加 flag 字符串
    ///
    /// ## 示例
    /// ```zig
    /// // 如果 opts.nx 为 true，添加 "NX"
    /// _ = try args.flag(opts.nx, "NX");
    /// _ = try args.flag(opts.xx, "XX");
    /// ```
    pub fn flag(self: *Self, condition: bool, name: []const u8) !*Self {
        if (self.enabled and condition) {
            _ = try self.builder.addStr(name);
        }
        return self;
    }

    /// 条件启用/禁用后续添加
    ///
    /// ## 链式条件添加
    ///
    /// ```zig
    /// // 仅当 ttl > 0 时添加 "EX" 和 ttl
    /// _ = try args.when(ttl > 0).add("EX").add(ttl).endWhen();
    ///
    /// // 等价于 Go:
    /// // if ttl > 0 {
    /// //     args = append(args, "EX", ttl)
    /// // }
    /// ```
    pub fn when(self: *Self, condition: bool) *Self {
        self.enabled = condition;
        return self;
    }

    /// 结束条件添加，恢复正常模式
    pub fn endWhen(self: *Self) *Self {
        self.enabled = true;
        return self;
    }

    /// 条件添加单个参数
    ///
    /// ## 示例
    /// ```zig
    /// _ = try args.addIf(ttl > 0, "EX");
    /// _ = try args.addIf(ttl > 0, ttl);
    /// ```
    pub fn addIf(self: *Self, condition: bool, value: anytype) !*Self {
        if (condition) {
            _ = try self.builder.add(value);
        }
        return self;
    }

    /// 添加可选参数
    ///
    /// 如果 value 不为 null，添加 prefix（如果有）和 value
    ///
    /// ## 示例
    /// ```zig
    /// const ex: ?i64 = 3600;
    /// const px: ?i64 = null;
    ///
    /// // 添加 "EX" "3600"（ex 有值）
    /// _ = try args.optional("EX", ex);
    ///
    /// // 不添加任何内容（px 为 null）
    /// _ = try args.optional("PX", px);
    /// ```
    pub fn optional(self: *Self, prefix: ?[]const u8, value: anytype) !*Self {
        if (self.enabled) {
            _ = try self.builder.addOptional(prefix, value);
        }
        return self;
    }

    /// 添加多个参数
    ///
    /// ## 示例
    /// ```zig
    /// _ = try args.many(.{"SET", key, value});
    /// _ = try args.many(.{"EX", 3600, "NX"});
    /// ```
    pub fn many(self: *Self, values: anytype) !*Self {
        if (self.enabled) {
            _ = try self.builder.addMany(values);
        }
        return self;
    }

    /// 条件添加多个参数
    pub fn manyIf(self: *Self, condition: bool, values: anytype) !*Self {
        if (self.enabled and condition) {
            _ = try self.builder.addMany(values);
        }
        return self;
    }

    /// 添加字符串切片
    pub fn slice(self: *Self, values: []const []const u8) !*Self {
        if (self.enabled) {
            _ = try self.builder.addSlice(values);
        }
        return self;
    }

    /// 获取参数列表
    pub fn getArgs(self: *const Self) []const []const u8 {
        return self.builder.getArgs();
    }

    /// 获取参数数量
    pub fn len(self: *const Self) usize {
        return self.builder.len();
    }

    /// 检查是否为空
    pub fn isEmpty(self: *const Self) bool {
        return self.len() == 0;
    }
};

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建参数构建器
pub fn args(allocator: std.mem.Allocator) Args {
    return Args.init(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "Args basic usage" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    // 链式调用需要每步都 try
    _ = try a.add("SET");
    _ = try a.add("key");
    _ = try a.add("value");

    try std.testing.expectEqual(@as(usize, 3), a.len());
    try std.testing.expectEqualStrings("SET", a.getArgs()[0]);
    try std.testing.expectEqualStrings("key", a.getArgs()[1]);
    try std.testing.expectEqualStrings("value", a.getArgs()[2]);
}

test "Args conditional add" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    const ttl: i64 = 3600;
    const nx = true;
    const xx = false;

    // 模拟 SET key value [EX seconds] [NX|XX]
    _ = try a.add("SET");
    _ = try a.add("key");
    _ = try a.add("value");
    _ = try a.addIf(ttl > 0, "EX");
    _ = try a.addIf(ttl > 0, ttl);
    _ = try a.flag(nx, "NX");
    _ = try a.flag(xx, "XX");

    try std.testing.expectEqual(@as(usize, 6), a.len());
    try std.testing.expectEqualStrings("EX", a.getArgs()[3]);
    try std.testing.expectEqualStrings("3600", a.getArgs()[4]);
    try std.testing.expectEqualStrings("NX", a.getArgs()[5]);
}

test "Args when/endWhen chain" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    const ex: i64 = 3600;
    const px: i64 = 0;

    _ = try a.add("SET");
    _ = try a.add("key");
    _ = try a.add("value");

    // ex > 0，所以添加 EX 和 ex
    _ = a.when(ex > 0);
    _ = try a.add("EX");
    _ = try a.add(ex);
    _ = a.endWhen();

    // px <= 0，所以不添加任何内容
    _ = a.when(px > 0);
    _ = try a.add("PX");
    _ = try a.add(px);
    _ = a.endWhen();

    try std.testing.expectEqual(@as(usize, 5), a.len());
}

test "Args optional parameters" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    const pattern: ?[]const u8 = "user:*";
    const count: ?u64 = 100;
    const filter: ?[]const u8 = null;

    _ = try a.add("SCAN");
    _ = try a.add("0");
    _ = try a.optional("MATCH", pattern);
    _ = try a.optional("COUNT", count);
    _ = try a.optional("TYPE", filter);

    try std.testing.expectEqual(@as(usize, 6), a.len());
}

test "Args many" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    _ = try a.many(.{ "ZADD", "scores", @as(i64, 100), "player1" });
    _ = try a.many(.{ @as(i64, 200), "player2" });

    try std.testing.expectEqual(@as(usize, 6), a.len());
}

test "Args reset and reuse" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    _ = try a.add("GET");
    _ = try a.add("key1");
    try std.testing.expectEqual(@as(usize, 2), a.len());

    a.reset();
    try std.testing.expectEqual(@as(usize, 0), a.len());

    _ = try a.add("SET");
    _ = try a.add("key2");
    _ = try a.add("value2");
    try std.testing.expectEqual(@as(usize, 3), a.len());
}
