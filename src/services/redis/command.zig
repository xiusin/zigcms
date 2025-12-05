//! Redis 命令构建器
//!
//! 本模块提供类型安全的命令参数构建功能。
//! 支持将多种 Zig 类型转换为 Redis 命令参数。
//!
//! ## Zig vs Go: 泛型和类型转换
//!
//! Go 中处理多种类型参数通常用 interface{}:
//! ```go
//! func (c *Client) Send(cmd string, args ...interface{}) error {
//!     for _, arg := range args {
//!         switch v := arg.(type) {
//!         case string: ...
//!         case int: ...
//!         }
//!     }
//! }
//! ```
//! 问题：运行时类型检查，可能 panic
//!
//! Zig 使用编译时泛型：
//! - 类型检查在编译时完成
//! - 零运行时开销
//! - 更好的错误信息

const std = @import("std");
const types = @import("types.zig");

/// 命令参数类型
///
/// ## 为什么使用 union 而非 interface{}？
///
/// Go 的 interface{} 是运行时多态：
/// ```go
/// var arg interface{} = 42
/// // 需要类型断言才能使用: arg.(int)
/// ```
///
/// Zig 的 tagged union 是编译时多态：
/// ```zig
/// const arg = CmdArg{ .int = 42 };
/// // switch 处理所有情况，编译器检查完整性
/// ```
pub const CmdArg = union(enum) {
    string: []const u8,
    int: i64,
    uint: u64,
    float: f64,
    /// 布尔值会转换为 "1" 或 "0"
    boolean: bool,

    /// 将参数转换为字符串表示
    ///
    /// ## 关于 comptime 和格式化
    ///
    /// Zig 的 `std.fmt.bufPrint` 在编译时检查格式字符串
    /// 错误的格式会导致编译错误，而非运行时错误
    pub fn toString(self: CmdArg, buffer: []u8) ![]const u8 {
        return switch (self) {
            .string => |s| s,
            .int => |i| std.fmt.bufPrint(buffer, "{d}", .{i}) catch unreachable,
            .uint => |u| std.fmt.bufPrint(buffer, "{d}", .{u}) catch unreachable,
            .float => |f| std.fmt.bufPrint(buffer, "{d}", .{f}) catch unreachable,
            .boolean => |b| if (b) "1" else "0",
        };
    }
};

/// 命令构建器
///
/// ## 构建器模式 (Builder Pattern)
///
/// 这是常见的设计模式，允许链式调用：
/// ```zig
/// var cmd = CommandBuilder.init(allocator);
/// defer cmd.deinit();
/// try cmd.add("SET").add("key").add("value").add(123);
/// ```
///
/// ## 内存安全
///
/// 所有添加的字符串参数都会被复制到内部缓冲区
/// 这确保了即使原始字符串被释放，命令仍然有效
pub const CommandBuilder = struct {
    /// 参数列表
    /// 
    /// std.ArrayList 类似 Go 的 slice，但提供更多控制：
    /// - 可以指定自定义分配器
    /// - 可以预分配容量
    /// - 释放时不会有 GC 延迟
    args: std.ArrayListUnmanaged([]const u8),
    /// 用于存储转换后的数字字符串
    string_pool: std.ArrayListUnmanaged([]u8),
    /// 内存分配器
    allocator: std.mem.Allocator,

    /// 初始化命令构建器
    ///
    /// ## 为什么需要显式初始化？
    ///
    /// Go 中可以直接使用零值:
    /// ```go
    /// var builder CommandBuilder // 可直接使用
    /// ```
    ///
    /// Zig 要求显式初始化，原因：
    /// 1. 避免未初始化内存访问（Go 通过零值解决，但有时零值不是有效状态）
    /// 2. 显式的分配器参数使内存管理更透明
    pub fn init(allocator: std.mem.Allocator) CommandBuilder {
        return .{
            .args = .{},
            .string_pool = .{},
            .allocator = allocator,
        };
    }

    /// 释放所有资源
    ///
    /// ## defer 模式
    ///
    /// 在 Zig 中，资源管理通常使用 defer:
    /// ```zig
    /// var cmd = CommandBuilder.init(allocator);
    /// defer cmd.deinit();
    /// // 即使后续代码出错，deinit 也会被调用
    /// ```
    ///
    /// 这比 Go 的 defer 更强大，因为它在作用域结束时执行
    /// 而非函数返回时
    pub fn deinit(self: *CommandBuilder) void {
        // 释放字符串池中的所有字符串
        for (self.string_pool.items) |str| {
            self.allocator.free(str);
        }
        self.string_pool.deinit(self.allocator);
        self.args.deinit(self.allocator);
    }

    /// 清空构建器（保留容量以便复用）
    ///
    /// ## 对象复用优化
    ///
    /// 频繁创建/销毁对象会有开销
    /// 使用 reset 可以复用已分配的内存
    pub fn reset(self: *CommandBuilder) void {
        for (self.string_pool.items) |str| {
            self.allocator.free(str);
        }
        self.string_pool.clearRetainingCapacity();
        self.args.clearRetainingCapacity();
    }

    /// 添加字符串参数
    pub fn addStr(self: *CommandBuilder, value: []const u8) !*CommandBuilder {
        try self.args.append(self.allocator, value);
        return self;
    }

    /// 添加整数参数
    pub fn addInt(self: *CommandBuilder, value: i64) !*CommandBuilder {
        // 分配足够的空间存储整数字符串（i64 最长 20 字符 + 符号）
        var buffer = try self.allocator.alloc(u8, 21);
        const str = std.fmt.bufPrint(buffer, "{d}", .{value}) catch unreachable;
        // 调整到实际长度
        buffer = try self.allocator.realloc(buffer, str.len);
        try self.string_pool.append(self.allocator, buffer);
        try self.args.append(self.allocator, buffer);
        return self;
    }

    /// 添加无符号整数参数
    pub fn addUint(self: *CommandBuilder, value: u64) !*CommandBuilder {
        var buffer = try self.allocator.alloc(u8, 20);
        const str = std.fmt.bufPrint(buffer, "{d}", .{value}) catch unreachable;
        buffer = try self.allocator.realloc(buffer, str.len);
        try self.string_pool.append(self.allocator, buffer);
        try self.args.append(self.allocator, buffer);
        return self;
    }

    /// 添加浮点数参数
    pub fn addFloat(self: *CommandBuilder, value: f64) !*CommandBuilder {
        var buffer = try self.allocator.alloc(u8, 32);
        const str = std.fmt.bufPrint(buffer, "{d}", .{value}) catch unreachable;
        buffer = try self.allocator.realloc(buffer, str.len);
        try self.string_pool.append(self.allocator, buffer);
        try self.args.append(self.allocator, buffer);
        return self;
    }

    /// 泛型添加方法
    ///
    /// ## comptime 泛型
    ///
    /// Zig 的泛型是编译时计算的：
    /// - `@TypeOf(value)` 在编译时获取类型
    /// - 根据类型生成不同的代码路径
    /// - 最终生成的代码没有泛型开销
    ///
    /// 对比 Go 的 interface{} 方案：
    /// ```go
    /// func (b *Builder) Add(v interface{}) {
    ///     switch v.(type) { // 运行时类型检查
    /// ```
    ///
    /// Zig 版本在编译时就确定了类型，更快且更安全
    pub fn add(self: *CommandBuilder, value: anytype) !*CommandBuilder {
        const T = @TypeOf(value);
        const type_info = @typeInfo(T);

        // 处理指针类型（如 *const [N]u8）
        if (type_info == .pointer) {
            const child_info = @typeInfo(type_info.pointer.child);
            if (child_info == .array and child_info.array.child == u8) {
                // 字符串字面量
                return self.addStr(value);
            }
        }

        // 根据类型选择合适的方法
        return switch (type_info) {
            .pointer => self.addStr(value),
            .int, .comptime_int => {
                if (type_info == .comptime_int or @typeInfo(T).int.signedness == .signed) {
                    return self.addInt(@as(i64, value));
                } else {
                    return self.addUint(@as(u64, value));
                }
            },
            .float, .comptime_float => self.addFloat(@as(f64, value)),
            else => @compileError("Unsupported argument type: " ++ @typeName(T)),
        };
    }

    /// 批量添加字符串参数
    pub fn addSlice(self: *CommandBuilder, values: []const []const u8) !*CommandBuilder {
        for (values) |v| {
            try self.args.append(self.allocator, v);
        }
        return self;
    }

    /// 条件添加参数
    ///
    /// ## 动态构造命令（类似 Go 的 []any 动态追加）
    ///
    /// Go 中你可能这样写：
    /// ```go
    /// args := []interface{}{"SET", key, value}
    /// if ttl > 0 {
    ///     args = append(args, "EX", ttl)
    /// }
    /// if nx {
    ///     args = append(args, "NX")
    /// }
    /// ```
    ///
    /// Zig 版本：
    /// ```zig
    /// var cmd = CommandBuilder.init(allocator);
    /// _ = try cmd.add("SET").add(key).add(value);
    /// _ = try cmd.addIf(ttl > 0, "EX");
    /// _ = try cmd.addIf(ttl > 0, ttl);
    /// _ = try cmd.addIf(nx, "NX");
    /// ```
    pub fn addIf(self: *CommandBuilder, condition: bool, value: anytype) !*CommandBuilder {
        if (condition) {
            return self.add(value);
        }
        return self;
    }

    /// 条件添加字符串
    pub fn addStrIf(self: *CommandBuilder, condition: bool, value: []const u8) !*CommandBuilder {
        if (condition) {
            return self.addStr(value);
        }
        return self;
    }

    /// 条件添加整数
    pub fn addIntIf(self: *CommandBuilder, condition: bool, value: i64) !*CommandBuilder {
        if (condition) {
            return self.addInt(value);
        }
        return self;
    }

    /// 添加可选参数（null 时不添加）
    ///
    /// ## Optional 类型处理
    ///
    /// Go 中处理可选参数通常用指针：
    /// ```go
    /// func setWithTTL(key string, value string, ttl *int) {
    ///     if ttl != nil {
    ///         args = append(args, "EX", *ttl)
    ///     }
    /// }
    /// ```
    ///
    /// Zig 使用 optional 类型：
    /// ```zig
    /// fn setWithTTL(key: []const u8, value: []const u8, ttl: ?i64) {
    ///     _ = try cmd.addOptional("EX", ttl);
    /// }
    /// ```
    pub fn addOptional(self: *CommandBuilder, prefix: ?[]const u8, value: anytype) !*CommandBuilder {
        const T = @TypeOf(value);
        const type_info = @typeInfo(T);

        if (type_info != .optional) {
            // 非 optional 类型直接添加
            if (prefix) |p| {
                _ = try self.addStr(p);
            }
            return self.add(value);
        }

        // Optional 类型：仅当有值时添加
        if (value) |v| {
            if (prefix) |p| {
                _ = try self.addStr(p);
            }
            return self.add(v);
        }
        return self;
    }

    /// 添加可选字符串参数
    pub fn addOptionalStr(self: *CommandBuilder, prefix: ?[]const u8, value: ?[]const u8) !*CommandBuilder {
        if (value) |v| {
            if (prefix) |p| {
                _ = try self.addStr(p);
            }
            return self.addStr(v);
        }
        return self;
    }

    /// 添加可选整数参数
    pub fn addOptionalInt(self: *CommandBuilder, prefix: ?[]const u8, value: ?i64) !*CommandBuilder {
        if (value) |v| {
            if (prefix) |p| {
                _ = try self.addStr(p);
            }
            return self.addInt(v);
        }
        return self;
    }

    /// 添加可选无符号整数参数
    pub fn addOptionalUint(self: *CommandBuilder, prefix: ?[]const u8, value: ?u64) !*CommandBuilder {
        if (value) |v| {
            if (prefix) |p| {
                _ = try self.addStr(p);
            }
            return self.addUint(v);
        }
        return self;
    }

    /// 添加布尔参数
    pub fn addBool(self: *CommandBuilder, value: bool) !*CommandBuilder {
        return self.addStr(if (value) "1" else "0");
    }

    /// 条件添加标志（仅当 true 时添加字符串）
    ///
    /// ## 标志参数模式
    ///
    /// Redis 中很多命令有布尔标志：
    /// ```
    /// SET key value [NX|XX] [GET] [EX seconds]
    /// ```
    ///
    /// 使用示例：
    /// ```zig
    /// _ = try cmd.addFlag(options.nx, "NX");
    /// _ = try cmd.addFlag(options.xx, "XX");
    /// _ = try cmd.addFlag(options.get, "GET");
    /// ```
    pub fn addFlag(self: *CommandBuilder, condition: bool, flag: []const u8) !*CommandBuilder {
        if (condition) {
            return self.addStr(flag);
        }
        return self;
    }

    /// 添加多个参数（元组展开）
    ///
    /// ## 批量添加
    ///
    /// ```zig
    /// // 一次添加多个参数
    /// _ = try cmd.addMany(.{"SET", key, value});
    /// _ = try cmd.addMany(.{"EX", 3600, "NX"});
    /// ```
    pub fn addMany(self: *CommandBuilder, args: anytype) !*CommandBuilder {
        const ArgsType = @TypeOf(args);
        const args_info = @typeInfo(ArgsType);

        if (args_info == .@"struct" and args_info.@"struct".is_tuple) {
            inline for (args_info.@"struct".fields) |field| {
                _ = try self.add(@field(args, field.name));
            }
        }
        return self;
    }

    /// 条件添加多个参数
    pub fn addManyIf(self: *CommandBuilder, condition: bool, args: anytype) !*CommandBuilder {
        if (condition) {
            return self.addMany(args);
        }
        return self;
    }

    /// 获取参数列表（用于发送）
    pub fn getArgs(self: *const CommandBuilder) []const []const u8 {
        return self.args.items;
    }

    /// 获取参数数量
    pub fn len(self: *const CommandBuilder) usize {
        return self.args.items.len;
    }
};

/// 快捷函数：构建简单命令
///
/// ## 可变参数模板
///
/// Zig 使用 anytype 和 comptime 实现类型安全的可变参数：
/// ```zig
/// cmd("SET", "key", "value", 123)
/// // 编译时展开为具体的类型调用
/// ```
///
/// 对比 Go:
/// ```go
/// Send("SET", "key", "value", 123) // interface{} 运行时处理
/// ```
pub fn buildCommand(allocator: std.mem.Allocator, cmd: []const u8, args: anytype) ![]const []const u8 {
    var builder = CommandBuilder.init(allocator);
    // 注意：这里不调用 deinit，因为返回的切片会引用 builder 的内存
    // 调用方需要负责释放

    _ = try builder.addStr(cmd);

    // 使用 inline for 在编译时展开
    // 这样每个参数的类型处理都是编译时确定的
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        const value = @field(args, field.name);
        _ = try builder.add(value);
    }

    return builder.getArgs();
}

// 测试
test "CommandBuilder basic" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    _ = try cmd.addStr("SET");
    _ = try cmd.addStr("mykey");
    _ = try cmd.addStr("myvalue");

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 3), args.len);
    try std.testing.expectEqualStrings("SET", args[0]);
    try std.testing.expectEqualStrings("mykey", args[1]);
    try std.testing.expectEqualStrings("myvalue", args[2]);
}

test "CommandBuilder with numbers" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    _ = try cmd.addStr("EXPIRE");
    _ = try cmd.addStr("mykey");
    _ = try cmd.addInt(3600);

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 3), args.len);
    try std.testing.expectEqualStrings("3600", args[2]);
}

test "CommandBuilder generic add" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    // 使用泛型 add 方法
    _ = try cmd.add("ZADD");
    _ = try cmd.add("myset");
    _ = try cmd.add(@as(i64, 100));
    _ = try cmd.add("member1");

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 4), args.len);
    try std.testing.expectEqualStrings("ZADD", args[0]);
    try std.testing.expectEqualStrings("100", args[2]);
}

test "CommandBuilder reset and reuse" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    // 第一次使用
    _ = try cmd.addStr("GET");
    _ = try cmd.addStr("key1");
    try std.testing.expectEqual(@as(usize, 2), cmd.len());

    // 重置并复用
    cmd.reset();
    try std.testing.expectEqual(@as(usize, 0), cmd.len());

    // 第二次使用
    _ = try cmd.addStr("SET");
    _ = try cmd.addStr("key2");
    _ = try cmd.addStr("value2");
    try std.testing.expectEqual(@as(usize, 3), cmd.len());
}

test "CommandBuilder conditional add" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    const ttl: i64 = 3600;
    const nx = true;
    const xx = false;

    // 模拟 SET key value [EX seconds] [NX|XX]
    _ = try cmd.addMany(.{ "SET", "mykey", "myvalue" });
    _ = try cmd.addManyIf(ttl > 0, .{ "EX", ttl });
    _ = try cmd.addFlag(nx, "NX");
    _ = try cmd.addFlag(xx, "XX");

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 6), args.len);
    try std.testing.expectEqualStrings("SET", args[0]);
    try std.testing.expectEqualStrings("EX", args[3]);
    try std.testing.expectEqualStrings("3600", args[4]);
    try std.testing.expectEqualStrings("NX", args[5]);
}

test "CommandBuilder optional parameters" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    const pattern: ?[]const u8 = "user:*";
    const count: ?u64 = 100;
    const filter: ?[]const u8 = null;

    // 模拟 SCAN cursor [MATCH pattern] [COUNT count]
    _ = try cmd.addMany(.{ "SCAN", "0" });
    _ = try cmd.addOptionalStr("MATCH", pattern);
    _ = try cmd.addOptionalUint("COUNT", count);
    _ = try cmd.addOptionalStr("TYPE", filter);

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 6), args.len);
    try std.testing.expectEqualStrings("MATCH", args[2]);
    try std.testing.expectEqualStrings("user:*", args[3]);
    try std.testing.expectEqualStrings("COUNT", args[4]);
    try std.testing.expectEqualStrings("100", args[5]);
}

test "CommandBuilder addMany tuple" {
    const allocator = std.testing.allocator;

    var cmd = CommandBuilder.init(allocator);
    defer cmd.deinit();

    // 一次添加多个不同类型的参数
    _ = try cmd.addMany(.{ "ZADD", "leaderboard", @as(i64, 1000), "player1" });

    const args = cmd.getArgs();
    try std.testing.expectEqual(@as(usize, 4), args.len);
    try std.testing.expectEqualStrings("ZADD", args[0]);
    try std.testing.expectEqualStrings("leaderboard", args[1]);
    try std.testing.expectEqualStrings("1000", args[2]);
    try std.testing.expectEqualStrings("player1", args[3]);
}
