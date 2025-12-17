//! 日志系统
//!
//! 提供类似 glog 的日志功能，支持：
//! - 结构化日志属性（attr）
//! - 链式追加属性
//! - 自动关联 request_id
//! - 多级别日志（debug/info/warn/error）
//!
//! ## 使用示例
//!
//! ```zig
//! const log = @import("shared/primitives/logger.zig");
//!
//! // 基础日志
//! log.info("用户登录成功");
//!
//! // 带属性的日志
//! log.attr("user_id", 123).attr("ip", "192.168.1.1").info("用户登录成功");
//!
//! // 错误日志
//! log.attr("host", "localhost").attr("port", 3306).err("数据库连接失败");
//! ```

const std = @import("std");
const request_id_mw = @import("../../api/middleware/request_id.middleware.zig");

/// 日志级别
pub const Level = enum {
    debug,
    info,
    warn,
    err,

    /// 获取级别标签
    pub fn label(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }

    /// 获取级别颜色代码
    pub fn color(self: Level) []const u8 {
        return switch (self) {
            .debug => "\x1b[36m", // 青色
            .info => "\x1b[32m", // 绿色
            .warn => "\x1b[33m", // 黄色
            .err => "\x1b[31m", // 红色
        };
    }
};

/// 日志属性值
pub const AttrValue = union(enum) {
    int: i64,
    uint: u64,
    float: f64,
    str: []const u8,
    boolean: bool,
};

/// 日志属性
pub const Attr = struct {
    key: []const u8,
    value: AttrValue,
};

/// 日志构建器，支持链式调用
pub const LogBuilder = struct {
    allocator: std.mem.Allocator,
    attrs: std.ArrayList(Attr),
    arena: std.heap.ArenaAllocator,

    /// 初始化日志构建器
    pub fn init(allocator: std.mem.Allocator) LogBuilder {
        const arena = std.heap.ArenaAllocator.init(allocator);
        return .{
            .allocator = allocator,
            .attrs = std.ArrayList(Attr).init(allocator),
            .arena = arena,
        };
    }

    /// 释放资源
    pub fn deinit(self: *LogBuilder) void {
        self.arena.deinit();
    }

    /// 添加属性
    pub fn attr(self: *LogBuilder, key: []const u8, value: anytype) *LogBuilder {
        const T = @TypeOf(value);
        const attr_value: AttrValue = blk: {
            if (T == []const u8) {
                // 复制字符串到arena
                const duped = self.arena.allocator().dupe(u8, value) catch break :blk .{ .str = "<oom>" };
                break :blk .{ .str = duped };
            } else if (T == bool) {
                break :blk .{ .boolean = value };
            } else if (T == f32 or T == f64) {
                break :blk .{ .float = @floatCast(value) };
            } else if (@typeInfo(T) == .int) {
                if (@typeInfo(T).int.signedness == .signed) {
                    break :blk .{ .int = @intCast(value) };
                } else {
                    break :blk .{ .uint = @intCast(value) };
                }
            } else if (@typeInfo(T) == .comptime_int) {
                break :blk .{ .int = value };
            } else if (@typeInfo(T) == .comptime_float) {
                break :blk .{ .float = value };
            } else if (@typeInfo(T) == .pointer) {
                const ptr_info = @typeInfo(T).pointer;
                if (ptr_info.child == u8) {
                    // 复制字符串指针指向的内容
                    const duped = self.arena.allocator().dupe(u8, value) catch break :blk .{ .str = "<oom>" };
                    break :blk .{ .str = duped };
                } else if (@typeInfo(ptr_info.child) == .array) {
                    const arr_info = @typeInfo(ptr_info.child).array;
                    if (arr_info.child == u8) {
                        const duped = self.arena.allocator().dupe(u8, value) catch break :blk .{ .str = "<oom>" };
                        break :blk .{ .str = duped };
                    }
                }
                break :blk .{ .str = "<unsupported>" };
            } else {
                break :blk .{ .str = "<unsupported>" };
            }
        };

        // 复制key到arena
        const duped_key = self.arena.allocator().dupe(u8, key) catch return self;

        self.attrs.append(.{
            .key = duped_key,
            .value = attr_value,
        }) catch {};

        return self;
    }

    /// 输出DEBUG级别日志
    pub fn debug(self: *LogBuilder, message: []const u8) void {
        self.log(.debug, message);
    }

    /// 输出INFO级别日志
    pub fn info(self: *LogBuilder, message: []const u8) void {
        self.log(.info, message);
    }

    /// 输出WARN级别日志
    pub fn warn(self: *LogBuilder, message: []const u8) void {
        self.log(.warn, message);
    }

    /// 输出ERROR级别日志
    pub fn err(self: *LogBuilder, message: []const u8) void {
        self.log(.err, message);
    }

    /// 内部日志输出方法
    fn log(self: *LogBuilder, level: Level, message: []const u8) void {
        defer self.deinit();

        var buf: [4096]u8 = undefined;
        var pos: usize = 0;

        // 时间戳
        const timestamp = std.time.timestamp();
        const time_str = std.fmt.bufPrint(buf[pos..], "{d}", .{timestamp}) catch "";
        pos += time_str.len;

        // 级别
        const level_str = std.fmt.bufPrint(buf[pos..], " [{s}]", .{level.label()}) catch "";
        pos += level_str.len;

        // request_id（如果有）
        if (request_id_mw.getRequestId()) |req_id| {
            const req_id_str = std.fmt.bufPrint(buf[pos..], " [req_id={s}]", .{req_id}) catch "";
            pos += req_id_str.len;
        }

        // 消息
        const msg_str = std.fmt.bufPrint(buf[pos..], " {s}", .{message}) catch "";
        pos += msg_str.len;

        // 属性
        for (self.attrs.items) |a| {
            var attr_buf: [256]u8 = undefined;
            const attr_str = formatAttr(&attr_buf, a);
            if (attr_str.len > 0) {
                const sep = std.fmt.bufPrint(buf[pos..], " {s}", .{attr_str}) catch "";
                pos += sep.len;
            }
        }

        // 输出到标准错误流
        const stderr = std.io.getStdErr();
        const writer = stderr.writer();
        writer.print("{s}\n", .{buf[0..pos]}) catch {};
    }
};

/// 格式化属性值为字符串
fn formatAttr(buf: []u8, a: Attr) []const u8 {
    return switch (a.value) {
        .int => |v| std.fmt.bufPrint(buf, "{s}={d}", .{ a.key, v }) catch "",
        .uint => |v| std.fmt.bufPrint(buf, "{s}={d}", .{ a.key, v }) catch "",
        .float => |v| std.fmt.bufPrint(buf, "{s}={d:.3}", .{ a.key, v }) catch "",
        .str => |v| std.fmt.bufPrint(buf, "{s}=\"{s}\"", .{ a.key, v }) catch "",
        .boolean => |v| std.fmt.bufPrint(buf, "{s}={}", .{ a.key, v }) catch "",
    };
}

/// 创建日志构建器
pub fn attr(key: []const u8, value: anytype) *LogBuilder {
    var builder = LogBuilder.init(std.heap.page_allocator);
    return builder.attr(key, value);
}

/// 便捷函数：DEBUG 日志
pub fn debug(message: []const u8) void {
    var builder = LogBuilder.init(std.heap.page_allocator);
    builder.debug(message);
}

/// 便捷函数：INFO 日志
pub fn info(message: []const u8) void {
    var builder = LogBuilder.init(std.heap.page_allocator);
    builder.info(message);
}

/// 便捷函数：WARN 日志
pub fn warn(message: []const u8) void {
    var builder = LogBuilder.init(std.heap.page_allocator);
    builder.warn(message);
}

/// 便捷函数：ERROR 日志
pub fn err(message: []const u8) void {
    var builder = LogBuilder.init(std.heap.page_allocator);
    builder.err(message);
}

/// 便捷函数：格式化DEBUG日志
pub fn debugf(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch return;
    debug(message);
}

/// 便捷函数：格式化INFO日志
pub fn infof(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch return;
    info(message);
}

/// 便捷函数：格式化WARN日志
pub fn warnf(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch return;
    warn(message);
}

/// 便捷函数：格式化ERROR日志
pub fn errf(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch return;
    err(message);
}

test "LogBuilder: 基本日志" {
    info("测试消息");
}

test "LogBuilder: 带属性日志" {
    attr("user_id", @as(i32, 123))
        .attr("username", "test")
        .attr("success", true)
        .info("用户登录");
}

test "LogBuilder: 多级别日志" {
    attr("test", "value").debug("调试信息");
    attr("test", "value").info("普通信息");
    attr("test", "value").warn("警告信息");
    attr("test", "value").err("错误信息");
}
