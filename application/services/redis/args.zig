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
//! Zig 版本（优雅链式）：
//! ```zig
//! var args = Args.init(allocator);
//! defer args.deinit();
//!
//! // 优雅链式调用，无需 try
//! args.add("SET").add(key).add(value);
//! args.when(opts.ex > 0).add("EX").add(opts.ex).endWhen();
//! args.when(opts.nx).add("NX").endWhen();
//!
//! // 最后检查错误
//! try args.checkError();
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
//! 5. 错误被延迟检查，支持优雅的链式调用

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
/// ## 设计理念：优雅的链式调用
///
/// 为了提供类似 Go 的流畅体验，Args 采用延迟错误检查模式：
/// - 所有构建方法返回 `*Self`，支持无限链式调用
/// - 错误被捕获并存储在内部，不会中断链式调用
/// - 在最后通过 `checkError()` 检查是否有错误发生
///
/// ## 使用示例
///
/// ### 基础用法（优雅链式）
/// ```zig
/// var args = Args.init(allocator);
/// defer args.deinit();
///
/// // 无需 try，优雅链式调用
/// args.add("SET").add("key").add("value");
///
/// // 在最后检查错误
/// try args.checkError();
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
///     // 优雅链式，无需 try
///     args.add("SET").add(key).add(value);
///
///     // 条件添加 EX
///     if (opts.ex) |ex| {
///         args.add("EX").add(ex);
///     }
///
///     // 条件添加 PX
///     if (opts.px) |px| {
///         args.add("PX").add(px);
///     }
///
///     // 条件添加标志
///     args.flag(opts.nx, "NX");
///     args.flag(opts.xx, "XX");
///     args.flag(opts.keepttl, "KEEPTTL");
///     args.flag(opts.get, "GET");
///
///     // 最后检查错误
///     try args.checkError();
/// }
/// ```
///
/// ### 批量添加
/// ```zig
/// // MSET key1 value1 key2 value2 ...
/// var args = Args.init(allocator);
/// defer args.deinit();
///
/// args.add("MSET");
///
/// const pairs = [_][2][]const u8{
///     .{"key1", "value1"},
///     .{"key2", "value2"},
///     .{"key3", "value3"},
/// };
///
/// for (pairs) |pair| {
///     args.add(pair[0]).add(pair[1]);
/// }
///
/// try args.checkError();
/// ```
///
/// ## 错误处理说明
///
/// - 构建过程中的错误会被捕获并存储
/// - 第一个错误会被保留，后续错误会被忽略
/// - 调用 `checkError()` 会返回存储的错误（如果有）
/// - 如果没有错误，`checkError()` 返回 void
pub const Args = struct {
    /// 内部使用 CommandBuilder 存储参数
    builder: CommandBuilder,
    /// 是否启用添加（用于条件链式调用）
    enabled: bool = true,
    /// 存储构建过程中发生的错误
    build_error: ?anyerror = null,

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
        self.build_error = null;
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
    /// args.add("SET").add(3600).add(3.14);
    /// ```
    pub fn add(self: *Self, value: anytype) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.add(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加字符串参数
    pub fn addStr(self: *Self, value: []const u8) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addStr(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加整数参数
    pub fn addInt(self: *Self, value: i64) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addInt(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加无符号整数参数
    pub fn addUint(self: *Self, value: u64) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addUint(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加浮点数参数
    pub fn addFloat(self: *Self, value: f64) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addFloat(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
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
    /// args.flag(opts.nx, "NX").flag(opts.xx, "XX");
    /// ```
    pub fn flag(self: *Self, condition: bool, name: []const u8) *Self {
        if (self.enabled and condition and self.build_error == null) {
            _ = self.builder.addStr(name) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
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
    /// args.addIf(ttl > 0, "EX").addIf(ttl > 0, ttl);
    /// ```
    pub fn addIf(self: *Self, condition: bool, value: anytype) *Self {
        if (condition and self.build_error == null) {
            _ = self.builder.add(value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
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
    /// args.optional("EX", ex);
    ///
    /// // 不添加任何内容（px 为 null）
    /// args.optional("PX", px);
    /// ```
    pub fn optional(self: *Self, prefix: ?[]const u8, value: anytype) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addOptional(prefix, value) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加多个参数
    ///
    /// ## 示例
    /// ```zig
    /// args.many(.{"SET", key, value}).many(.{"EX", 3600, "NX"});
    /// ```
    pub fn many(self: *Self, values: anytype) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addMany(values) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 条件添加多个参数
    pub fn manyIf(self: *Self, condition: bool, values: anytype) *Self {
        if (self.enabled and condition and self.build_error == null) {
            _ = self.builder.addMany(values) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 添加字符串切片
    pub fn slice(self: *Self, values: []const []const u8) *Self {
        if (self.enabled and self.build_error == null) {
            _ = self.builder.addSlice(values) catch |err| {
                if (self.build_error == null) {
                    self.build_error = err;
                }
            };
        }
        return self;
    }

    /// 检查构建过程中是否发生错误
    ///
    /// ## 使用方式
    ///
    /// 在完成所有参数构建后，调用此方法检查是否有错误：
    /// ```zig
    /// args.add("SET").add("key").add("value");
    /// try args.checkError();  // 如果有错误会返回
    ///
    /// const reply = try conn.doArgs(args);
    /// ```
    ///
    /// ## 返回值
    ///
    /// - 如果没有错误，返回 void
    /// - 如果有错误，返回第一个发生的错误
    pub fn checkError(self: *const Self) !void {
        if (self.build_error) |err| {
            return err;
        }
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

    // 优雅链式调用，无需 try
    _ = a.add("SET").add("key").add("value");

    // 检查错误
    try a.checkError();

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
    _ = a.add("SET").add("key").add("value");
    _ = a.addIf(ttl > 0, "EX").addIf(ttl > 0, ttl);
    _ = a.flag(nx, "NX").flag(xx, "XX");

    try a.checkError();

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

    _ = a.add("SET").add("key").add("value");

    // ex > 0，所以添加 EX 和 ex
    _ = a.when(ex > 0).add("EX").add(ex).endWhen();

    // px <= 0，所以不添加任何内容
    _ = a.when(px > 0).add("PX").add(px).endWhen();

    try a.checkError();

    try std.testing.expectEqual(@as(usize, 5), a.len());
}

test "Args optional parameters" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    const pattern: ?[]const u8 = "user:*";
    const count: ?u64 = 100;
    const filter: ?[]const u8 = null;

    _ = a.add("SCAN").add("0");
    _ = a.optional("MATCH", pattern);
    _ = a.optional("COUNT", count);
    _ = a.optional("TYPE", filter);

    try a.checkError();

    try std.testing.expectEqual(@as(usize, 6), a.len());
}

test "Args many" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    _ = a.many(.{ "ZADD", "scores", @as(i64, 100), "player1" });
    _ = a.many(.{ @as(i64, 200), "player2" });

    try a.checkError();

    try std.testing.expectEqual(@as(usize, 6), a.len());
}

test "Args reset and reuse" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    _ = a.add("GET").add("key1");
    try a.checkError();
    try std.testing.expectEqual(@as(usize, 2), a.len());

    a.reset();
    try std.testing.expectEqual(@as(usize, 0), a.len());

    _ = a.add("SET").add("key2").add("value2");
    try a.checkError();
    try std.testing.expectEqual(@as(usize, 3), a.len());
}

test "Args checkError" {
    const allocator = std.testing.allocator;

    var a = Args.init(allocator);
    defer a.deinit();

    // 正常情况：checkError 不应返回错误
    _ = a.add("SET").add("key").add("value");
    try a.checkError();

    // 重置后再次测试
    a.reset();
    _ = a.add("GET").add("test");
    try a.checkError();
}
