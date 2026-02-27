//! 日志系统模块 (Logging Module)
//!
//! 合并了原 shared/primitives/logger 和 application/services/logger 的功能。
//! 提供高性能结构化日志，支持多级别、多输出格式。
//!
//! ## 使用示例
//! ```zig
//! const logging = @import("core/logging/mod.zig");
//!
//! // 基础日志
//! logging.info("用户登录成功", .{});
//!
//! // 带属性的日志
//! logging.attr("user_id", 123).attr("ip", "192.168.1.1").info("用户登录成功", .{});
//! ```

const std = @import("std");

/// 日志级别
pub const LogLevel = enum {
    Debug,
    Info,
    Warn,
    Error,
    Fatal,

    /// 获取级别标签
    pub fn label(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warn => "WARN",
            .Error => "ERROR",
            .Fatal => "FATAL",
        };
    }

    /// 获取级别颜色代码
    pub fn color(self: LogLevel) []const u8 {
        return switch (self) {
            .Debug => "\x1b[36m", // 青色
            .Info => "\x1b[32m", // 绿色
            .Warn => "\x1b[33m", // 黄色
            .Error => "\x1b[31m", // 红色
            .Fatal => "\x1b[35m", // 紫色
        };
    }
};

/// 日志输出格式
pub const LogFormat = enum {
    Text,
    Json,
    Colored,
};

/// 日志配置
pub const LogConfig = struct {
    level: LogLevel = .Info,
    format: LogFormat = .Colored,
    sync_on_error: bool = true,
};

// Thread-local request ID storage
threadlocal var current_request_id: ?[]const u8 = null;

/// 设置当前请求 ID
pub fn setRequestId(id: ?[]const u8) void {
    current_request_id = id;
}

/// 获取当前请求 ID
pub fn getRequestId() ?[]const u8 {
    return current_request_id;
}

/// 日志记录器
pub const Logger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: LogConfig,
    mutex: std.Thread.Mutex = .{},

    /// 初始化日志记录器
    pub fn init(allocator: std.mem.Allocator, config: LogConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// 销毁日志记录器
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 记录日志
    pub fn log(self: *Self, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.config.level)) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        const timestamp = std.time.timestamp();
        const writer = std.io.getStdErr().writer();

        switch (self.config.format) {
            .Colored => {
                writer.print("{s}[{s}]\x1b[0m {}: " ++ fmt ++ "\n", .{ level.color(), level.label(), timestamp } ++ args) catch {};
            },
            .Text => {
                writer.print("[{s}] {}: " ++ fmt ++ "\n", .{ level.label(), timestamp } ++ args) catch {};
            },
            .Json => {
                writer.print("{{\"level\":\"{s}\",\"time\":{},\"msg\":\"" ++ fmt ++ "\"}}\n", .{ level.label(), timestamp } ++ args) catch {};
            },
        }
    }

    /// Debug 级别日志
    pub fn debug(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.Debug, fmt, args);
    }

    /// Info 级别日志
    pub fn logInfo(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.Info, fmt, args);
    }

    /// Warn 级别日志
    pub fn warn(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.Warn, fmt, args);
    }

    /// Error 级别日志
    pub fn logError(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.Error, fmt, args);
    }

    /// Fatal 级别日志
    pub fn fatal(self: *Self, comptime fmt: []const u8, args: anytype) void {
        self.log(.Fatal, fmt, args);
    }
};

// ============================================================================
// 全局便捷函数（兼容原 shared/primitives/logger 接口）
// ============================================================================

/// Debug 日志
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    writer.print("\x1b[36m[DEBUG]\x1b[0m " ++ fmt ++ "\n", args) catch {};
}

/// Info 日志
pub fn info(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    writer.print("\x1b[32m[INFO]\x1b[0m " ++ fmt ++ "\n", args) catch {};
}

/// Warn 日志
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    writer.print("\x1b[33m[WARN]\x1b[0m " ++ fmt ++ "\n", args) catch {};
}

/// Error 日志
pub fn err(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    writer.print("\x1b[31m[ERROR]\x1b[0m " ++ fmt ++ "\n", args) catch {};
}

/// Fatal 日志
pub fn fatal(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdErr().writer();
    writer.print("\x1b[35m[FATAL]\x1b[0m " ++ fmt ++ "\n", args) catch {};
}
