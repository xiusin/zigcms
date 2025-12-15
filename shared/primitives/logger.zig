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
//! log.info("用户登录成功").attr("user_id", 123).attr("ip", "192.168.1.1").log();
//!
//! // 错误日志
//! log.err("数据库连接失败").attr("host", "localhost").attr("port", 3306).log();
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

/// 日志属性
pub const Attr = struct {
    key: []const u8,
    value: Value,

    pub const Value = union(enum) {
        int: i64,
        uint: u64,
        float: f64,
        str: []const u8,
        boolean: bool,
    };

    /// 格式化属性值为字符串
    pub fn format(self: Attr, buf: []u8) []const u8 {
        const written = switch (self.value) {
            .int => |v| std.fmt.bufPrint(buf, "{s}={d}", .{ self.key, v }) catch return "",
            .uint => |v| std.fmt.bufPrint(buf, "{s}={d}", .{ self.key, v }) catch return "",
            .float => |v| std.fmt.bufPrint(buf, "{s}={d:.3}", .{ self.key, v }) catch return "",
            .str => |v| std.fmt.bufPrint(buf, "{s}=\"{s}\"", .{ self.key, v }) catch return "",
            .boolean => |v| std.fmt.bufPrint(buf, "{s}={}", .{ self.key, v }) catch return "",
        };
        return written;
    }
};

/// 日志构建器，支持链式调用
pub const LogBuilder = struct {
    level: Level,
    message: []const u8,
    attrs: [16]Attr,
    attr_count: usize,

    /// 添加字符串属性
    pub fn attr(self: *LogBuilder, key: []const u8, value: anytype) *LogBuilder {
        if (self.attr_count >= 16) return self;

        const T = @TypeOf(value);
        const attr_value: Attr.Value = blk: {
            if (T == []const u8) {
                break :blk .{ .str = value };
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
                    break :blk .{ .str = value };
                } else if (@typeInfo(ptr_info.child) == .array) {
                    const arr_info = @typeInfo(ptr_info.child).array;
                    if (arr_info.child == u8) {
                        break :blk .{ .str = value };
                    }
                }
                break :blk .{ .str = "<unsupported>" };
            } else {
                break :blk .{ .str = "<unsupported>" };
            }
        };

        self.attrs[self.attr_count] = .{
            .key = key,
            .value = attr_value,
        };
        self.attr_count += 1;
        return self;
    }

    /// 输出日志
    pub fn log(self: *LogBuilder) void {
        var buf: [4096]u8 = undefined;
        var pos: usize = 0;

        // 时间戳
        const timestamp = std.time.timestamp();
        const time_str = std.fmt.bufPrint(buf[pos..], "{d}", .{timestamp}) catch "";
        pos += time_str.len;

        // 级别
        const level_str = std.fmt.bufPrint(buf[pos..], " [{s}]", .{self.level.label()}) catch "";
        pos += level_str.len;

        // request_id（如果有）
        if (request_id_mw.getRequestId()) |req_id| {
            const req_id_str = std.fmt.bufPrint(buf[pos..], " [req_id={s}]", .{req_id}) catch "";
            pos += req_id_str.len;
        }

        // 消息
        const msg_str = std.fmt.bufPrint(buf[pos..], " {s}", .{self.message}) catch "";
        pos += msg_str.len;

        // 属性
        for (self.attrs[0..self.attr_count]) |a| {
            var attr_buf: [256]u8 = undefined;
            const attr_str = a.format(&attr_buf);
            if (attr_str.len > 0) {
                const sep = std.fmt.bufPrint(buf[pos..], " {s}", .{attr_str}) catch "";
                pos += sep.len;
            }
        }

        // 输出到标准错误
        const writer = std.io.getStdErr().writer();
        writer.print("{s}\n", .{buf[0..pos]}) catch {};
    }
};

/// 创建 DEBUG 级别日志
pub fn debug(message: []const u8) *LogBuilder {
    return createBuilder(.debug, message);
}

/// 创建 INFO 级别日志
pub fn info(message: []const u8) *LogBuilder {
    return createBuilder(.info, message);
}

/// 创建 WARN 级别日志
pub fn warn(message: []const u8) *LogBuilder {
    return createBuilder(.warn, message);
}

/// 创建 ERROR 级别日志
pub fn err(message: []const u8) *LogBuilder {
    return createBuilder(.err, message);
}

/// 线程局部日志构建器（避免分配）
threadlocal var builder: LogBuilder = undefined;

fn createBuilder(level: Level, message: []const u8) *LogBuilder {
    builder = .{
        .level = level,
        .message = message,
        .attrs = undefined,
        .attr_count = 0,
    };
    return &builder;
}

/// 简单日志输出（不带属性）
pub fn logSimple(level: Level, comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, fmt, args) catch return;

    var b = LogBuilder{
        .level = level,
        .message = message,
        .attrs = undefined,
        .attr_count = 0,
    };
    b.log();
}

/// 便捷函数：DEBUG 日志
pub fn debugf(comptime fmt: []const u8, args: anytype) void {
    logSimple(.debug, fmt, args);
}

/// 便捷函数：INFO 日志
pub fn infof(comptime fmt: []const u8, args: anytype) void {
    logSimple(.info, fmt, args);
}

/// 便捷函数：WARN 日志
pub fn warnf(comptime fmt: []const u8, args: anytype) void {
    logSimple(.warn, fmt, args);
}

/// 便捷函数：ERROR 日志
pub fn errf(comptime fmt: []const u8, args: anytype) void {
    logSimple(.err, fmt, args);
}

test "LogBuilder: 基本日志" {
    info("测试消息").log();
}

test "LogBuilder: 带属性日志" {
    info("用户登录")
        .attr("user_id", @as(i32, 123))
        .attr("username", "test")
        .attr("success", true)
        .log();
}

test "LogBuilder: 多级别日志" {
    debug("调试信息").log();
    info("普通信息").log();
    warn("警告信息").log();
    err("错误信息").log();
}
