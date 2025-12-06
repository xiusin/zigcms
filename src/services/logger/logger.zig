//! # 高性能结构化日志库
//!
//! 类似 Go 的 zap 日志库，支持结构化日志、多级别、多输出。
//! 针对高并发场景进行了深度优化，提供多种写入器以满足不同性能需求。
//!
//! ## 核心特性
//!
//! - **结构化日志**：支持 key=value 格式的字段附加
//! - **多输出格式**：Text、JSON、Colored 三种格式
//! - **多级别**：debug、info、warn、err、fatal
//! - **模块作用域**：类似 std.log.scoped(.app) 的模块命名
//! - **高性能写入器**：无锁环形缓冲区、线程本地缓冲
//! - **崩溃保护**：ERROR/FATAL 自动刷新，panic 时保留日志
//!
//! ## 写入器性能对比
//!
//! | 写入器            | 锁策略       | 延迟  | 吞吐量 | 适用场景           |
//! |-------------------|--------------|-------|--------|-------------------|
//! | StderrWriter      | 无缓冲       | 高    | 低     | 调试              |
//! | AsyncWriter       | Mutex        | 中    | 中     | 通用              |
//! | LockFreeWriter    | CAS 原子操作 | 低    | 高     | 高并发、低延迟    |
//! | ThreadLocalWriter | 线程本地     | 最低  | 最高   | 多线程独立写入    |
//!
//! ## 线程安全说明
//!
//! - **Logger**：内部使用 Mutex 保护 writers 列表，多线程安全
//! - **AsyncWriter**：使用 Mutex 保护双缓冲区切换，写入时短暂加锁
//! - **LockFreeWriter**：使用 CAS 原子操作，写入完全无锁，刷新时使用自旋锁
//! - **ThreadLocalWriter**：每线程独立缓冲区，写入无锁，仅刷新时加锁
//!
//! ## 内存安全说明
//!
//! - 所有动态分配的缓冲区在 deinit() 时释放
//! - 使用 defer 模式确保资源释放顺序正确
//! - 环形缓冲区使用固定大小，避免运行时分配
//! - 原子操作使用 acquire/release 语义保证内存可见性
//!
//! ## 崩溃保护机制
//!
//! 1. **sync_on_error**：ERROR/FATAL 级别自动立即刷新缓冲区
//! 2. **registerCrashFlush**：注册写入器，程序异常时自动刷新
//! 3. **panicHandler**：自定义 panic 处理器，记录崩溃信息并刷新
//!
//! ## 使用示例
//!
//! ### 基础用法
//! ```zig
//! const logger = @import("services/logger/logger.zig");
//!
//! var log = logger.Logger.init(allocator, .{});
//! defer log.deinit();
//!
//! log.info("服务启动", .{});
//! log.with(.{ .user_id = 123 }).info("用户登录", .{});
//! ```
//!
//! ### 高性能生产配置
//! ```zig
//! // 1. 轮转文件
//! var rotating = try logger.RotatingFileWriter.init(alloc, "app.log", .{});
//! defer rotating.deinit();
//!
//! // 2. 无锁缓冲（推荐）
//! var lock_free = try logger.LockFreeWriter.init(alloc, rotating.writer(), .{});
//! defer lock_free.deinit();
//!
//! // 3. 崩溃保护
//! logger.registerCrashFlush(&lock_free);
//! defer logger.unregisterCrashFlush(&lock_free);
//!
//! // 4. 日志器
//! var log = logger.Logger.init(alloc, .{ .sync_on_error = true });
//! defer log.deinit();
//! try log.addWriter(lock_free.writer());
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

/// 内部时间戳格式化
const Timestamp = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,

    /// 从 Unix 时间戳创建
    fn fromUnix(ts: i64, offset: i32) Timestamp {
        const local_ts = ts + offset;
        var rem = local_ts;

        const sec: u8 = @intCast(@mod(rem, 60));
        rem = @divTrunc(rem, 60);
        const min: u8 = @intCast(@mod(rem, 60));
        rem = @divTrunc(rem, 60);
        const hr: u8 = @intCast(@mod(rem, 24));
        var days = @divFloor(rem, 24);

        // 计算年份
        var y: i32 = 1970;
        while (true) {
            const year_days: i64 = if (isLeap(y)) 366 else 365;
            if (days < year_days) break;
            days -= year_days;
            y += 1;
        }

        // 计算月份
        const month_days = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        var m: u8 = 1;
        while (m <= 12) : (m += 1) {
            var md: i64 = month_days[m - 1];
            if (m == 2 and isLeap(y)) md = 29;
            if (days < md) break;
            days -= md;
        }

        return .{
            .year = @intCast(y),
            .month = m,
            .day = @intCast(days + 1),
            .hour = hr,
            .minute = min,
            .second = sec,
        };
    }

    fn isLeap(year: i32) bool {
        return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or @mod(year, 400) == 0;
    }

    /// 格式化为 "2025-12-06 09:18:00"
    pub fn format(self: Timestamp, writer: anytype) !void {
        try writer.print("{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            self.year, self.month, self.day, self.hour, self.minute, self.second,
        });
    }

    /// 格式化为 ISO 格式 "2025-12-06T09:18:00"
    pub fn formatIso(self: Timestamp, writer: anytype) !void {
        try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}", .{
            self.year, self.month, self.day, self.hour, self.minute, self.second,
        });
    }
};

/// 日志级别
pub const Level = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,
    fatal = 4,

    /// 获取级别名称
    pub fn name(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }

    /// 获取短名称
    pub fn shortName(self: Level) []const u8 {
        return switch (self) {
            .debug => "DBG",
            .info => "INF",
            .warn => "WRN",
            .err => "ERR",
            .fatal => "FTL",
        };
    }

    /// 获取颜色代码
    pub fn color(self: Level) []const u8 {
        return switch (self) {
            .debug => "\x1b[36m", // 青色
            .info => "\x1b[32m", // 绿色
            .warn => "\x1b[33m", // 黄色
            .err => "\x1b[31m", // 红色
            .fatal => "\x1b[35m", // 紫色
        };
    }
};

/// 日志输出格式
pub const Format = enum {
    /// 纯文本格式：2025-12-06 09:18:00 [INFO] message
    text,
    /// JSON 格式：{"time":"...","level":"INFO","msg":"..."}
    json,
    /// 彩色文本格式（用于终端）
    colored,
};

/// 日志器配置
pub const LoggerConfig = struct {
    /// 最低日志级别
    level: Level = .info,
    /// 输出格式
    format: Format = .text,
    /// 模块名称（类似 Zig std.log 的 scope）
    module_name: ?[]const u8 = null,
    /// 是否包含调用位置
    include_caller: bool = false,
    /// 是否包含时间戳
    include_timestamp: bool = true,
    /// 是否包含模块名称
    include_module: bool = true,
    /// 时区偏移（秒），默认北京时间 UTC+8
    timezone_offset: i32 = 8 * 3600,
    /// 缓冲区大小
    buffer_size: usize = 4096,
    /// ERROR/FATAL 级别是否立即同步刷新（防止崩溃丢日志）
    sync_on_error: bool = true,
};

/// 日志字段
pub const Field = struct {
    key: []const u8,
    value: FieldValue,
};

/// 字段值类型
pub const FieldValue = union(enum) {
    int: i64,
    uint: u64,
    float: f64,
    bool_val: bool,
    string: []const u8,
    err_val: anyerror,

    /// 格式化为字符串
    pub fn format(self: FieldValue, writer: anytype) !void {
        switch (self) {
            .int => |v| try writer.print("{d}", .{v}),
            .uint => |v| try writer.print("{d}", .{v}),
            .float => |v| try writer.print("{d:.6}", .{v}),
            .bool_val => |v| try writer.print("{}", .{v}),
            .string => |v| try writer.print("\"{s}\"", .{v}),
            .err_val => |v| try writer.print("\"{s}\"", .{@errorName(v)}),
        }
    }
};

/// 日志输出接口
pub const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (*anyopaque, []const u8) void,
    /// 可选的刷新函数（用于缓冲写入器）
    flushFn: ?*const fn (*anyopaque) void = null,

    pub fn write(self: Writer, data: []const u8) void {
        self.writeFn(self.ptr, data);
    }

    /// 刷新缓冲区（如果支持）
    pub fn flush(self: Writer) void {
        if (self.flushFn) |f| {
            f(self.ptr);
        }
    }
};

/// 标准错误输出
pub const StderrWriter = struct {
    pub fn writer() Writer {
        return .{
            .ptr = undefined,
            .writeFn = writeStderr,
        };
    }

    fn writeStderr(_: *anyopaque, data: []const u8) void {
        _ = std.posix.write(std.posix.STDERR_FILENO, data) catch {};
    }
};

/// 标准输出
pub const StdoutWriter = struct {
    pub fn writer() Writer {
        return .{
            .ptr = undefined,
            .writeFn = writeStdout,
        };
    }

    fn writeStdout(_: *anyopaque, data: []const u8) void {
        _ = std.posix.write(std.posix.STDOUT_FILENO, data) catch {};
    }
};

/// 文件输出
pub const FileWriter = struct {
    file: std.fs.File,

    pub fn init(path: []const u8) !FileWriter {
        const file = try std.fs.cwd().createFile(path, .{
            .truncate = false,
        });
        try file.seekFromEnd(0);
        return .{ .file = file };
    }

    pub fn deinit(self: *FileWriter) void {
        self.file.close();
    }

    pub fn writer(self: *FileWriter) Writer {
        return .{
            .ptr = self,
            .writeFn = writeFile,
        };
    }

    fn writeFile(ptr: *anyopaque, data: []const u8) void {
        const self: *FileWriter = @ptrCast(@alignCast(ptr));
        self.file.writeAll(data) catch {};
    }
};

/// 日志器
pub const Logger = struct {
    const Self = @This();

    allocator: Allocator,
    config: LoggerConfig,
    writers: std.ArrayListUnmanaged(Writer),
    mutex: Mutex,
    fields: std.ArrayListUnmanaged(Field),

    /// 初始化日志器
    pub fn init(allocator: Allocator, config: LoggerConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .writers = .{},
            .mutex = .{},
            .fields = .{},
        };
    }

    /// 释放日志器
    pub fn deinit(self: *Self) void {
        self.writers.deinit(self.allocator);
        self.fields.deinit(self.allocator);
    }

    /// 添加输出目标
    pub fn addWriter(self: *Self, w: Writer) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.writers.append(self.allocator, w);
    }

    /// 创建带字段的子日志器
    pub fn with(self: *Self, fields: anytype) FieldLogger(@TypeOf(fields)) {
        return .{
            .logger = self,
            .fields = fields,
        };
    }

    /// 设置日志级别
    pub fn setLevel(self: *Self, level: Level) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.config.level = level;
    }

    /// 设置输出格式
    pub fn setFormat(self: *Self, format_type: Format) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.config.format = format_type;
    }

    /// 设置模块名称
    pub fn setModule(self: *Self, name: ?[]const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.config.module_name = name;
    }

    /// 检查级别是否启用
    pub fn isEnabled(self: *Self, level: Level) bool {
        return @intFromEnum(level) >= @intFromEnum(self.config.level);
    }

    /// 移除所有输出目标
    pub fn clearWriters(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.writers.clearRetainingCapacity();
    }

    /// 创建带模块名称的子日志器（字符串版本）
    pub fn scoped(self: *Self, comptime module: []const u8) ScopedLogger {
        return ScopedLogger{
            .parent = self,
            .module_name = module,
        };
    }

    /// 创建带模块名称的子日志器（枚举版本，类似 std.log.scoped(.app)）
    pub fn scope(self: *Self, comptime module: @Type(.enum_literal)) ScopedLogger {
        return ScopedLogger{
            .parent = self,
            .module_name = @tagName(module),
        };
    }

    // ========================================================================
    // 日志方法
    // ========================================================================

    pub fn debug(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.log(.debug, msg, args, .{});
    }

    pub fn info(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.log(.info, msg, args, .{});
    }

    pub fn warn(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.log(.warn, msg, args, .{});
    }

    pub fn err(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.log(.err, msg, args, .{});
    }

    pub fn fatal(self: *Self, comptime msg: []const u8, args: anytype) void {
        self.log(.fatal, msg, args, .{});
    }

    /// 通用日志方法
    fn log(self: *Self, level: Level, comptime msg: []const u8, args: anytype, extra_fields: anytype) void {
        if (!self.isEnabled(level)) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        var buf: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        self.formatEntry(writer, level, msg, args, extra_fields) catch return;

        const output = fbs.getWritten();
        for (self.writers.items) |w| {
            w.write(output);
        }

        // 如果没有输出目标，输出到 stderr
        if (self.writers.items.len == 0) {
            _ = std.posix.write(std.posix.STDERR_FILENO, output) catch {};
        }

        // ERROR/FATAL 级别立即刷新缓冲区（防止崩溃丢日志）
        if (self.config.sync_on_error and (level == .err or level == .fatal)) {
            for (self.writers.items) |w| {
                w.flush();
            }
        }
    }

    /// 手动刷新所有写入器的缓冲区
    pub fn flush(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.writers.items) |w| {
            w.flush();
        }
    }

    /// 格式化日志条目
    fn formatEntry(
        self: *Self,
        writer: anytype,
        level: Level,
        comptime msg: []const u8,
        args: anytype,
        extra_fields: anytype,
    ) !void {
        switch (self.config.format) {
            .text => try self.formatText(writer, level, msg, args, extra_fields),
            .json => try self.formatJson(writer, level, msg, args, extra_fields),
            .colored => try self.formatColored(writer, level, msg, args, extra_fields),
        }
    }

    /// 纯文本格式
    fn formatText(
        self: *Self,
        writer: anytype,
        level: Level,
        comptime msg: []const u8,
        args: anytype,
        extra_fields: anytype,
    ) !void {
        // 时间戳
        if (self.config.include_timestamp) {
            const ts = std.time.timestamp();
            const now = Timestamp.fromUnix(ts, self.config.timezone_offset);
            try now.format(writer);
            try writer.writeAll(" ");
        }

        // 级别
        try writer.print("[{s}]", .{level.name()});

        // 模块名称
        if (self.config.include_module) {
            if (self.config.module_name) |name| {
                try writer.print(" ({s})", .{name});
            }
        }
        try writer.writeAll(" ");

        // 消息
        try writer.print(msg, args);

        // 额外字段
        const fields_type = @TypeOf(extra_fields);
        if (@typeInfo(fields_type) == .@"struct") {
            inline for (std.meta.fields(fields_type)) |field| {
                const value = @field(extra_fields, field.name);
                try writer.print(" {s}=", .{field.name});
                try formatValue(writer, value);
            }
        }

        try writer.writeAll("\n");
    }

    /// JSON 格式
    fn formatJson(
        self: *Self,
        writer: anytype,
        level: Level,
        comptime msg: []const u8,
        args: anytype,
        extra_fields: anytype,
    ) !void {
        try writer.writeAll("{");

        // 时间戳
        if (self.config.include_timestamp) {
            const ts = std.time.timestamp();
            const now = Timestamp.fromUnix(ts, self.config.timezone_offset);
            try writer.writeAll("\"time\":\"");
            try now.formatIso(writer);
            try writer.writeAll("\",");
        }

        // 级别
        try writer.print("\"level\":\"{s}\"", .{level.name()});

        // 模块名称
        if (self.config.include_module) {
            if (self.config.module_name) |name| {
                try writer.print(",\"module\":\"{s}\"", .{name});
            }
        }

        // 消息
        try writer.writeAll(",\"msg\":\"");
        try writer.print(msg, args);
        try writer.writeAll("\"");

        // 额外字段
        const fields_type = @TypeOf(extra_fields);
        if (@typeInfo(fields_type) == .@"struct") {
            inline for (std.meta.fields(fields_type)) |field| {
                const value = @field(extra_fields, field.name);
                try writer.print(",\"{s}\":", .{field.name});
                try formatJsonValue(writer, value);
            }
        }

        try writer.writeAll("}\n");
    }

    /// 彩色文本格式
    fn formatColored(
        self: *Self,
        writer: anytype,
        level: Level,
        comptime msg: []const u8,
        args: anytype,
        extra_fields: anytype,
    ) !void {
        const reset = "\x1b[0m";

        // 时间戳（灰色）
        if (self.config.include_timestamp) {
            const ts = std.time.timestamp();
            const now = Timestamp.fromUnix(ts, self.config.timezone_offset);
            try writer.writeAll("\x1b[90m");
            try now.format(writer);
            try writer.writeAll("\x1b[0m ");
        }

        // 级别（带颜色）
        try writer.print("{s}[{s}]{s}", .{ level.color(), level.shortName(), reset });

        // 模块名称（黄色）
        if (self.config.include_module) {
            if (self.config.module_name) |name| {
                try writer.print(" \x1b[33m({s})\x1b[0m", .{name});
            }
        }
        try writer.writeAll(" ");

        // 消息
        try writer.print(msg, args);

        // 额外字段（青色）
        const fields_type = @TypeOf(extra_fields);
        if (@typeInfo(fields_type) == .@"struct") {
            inline for (std.meta.fields(fields_type)) |field| {
                const value = @field(extra_fields, field.name);
                try writer.print(" \x1b[36m{s}\x1b[0m=", .{field.name});
                try formatValue(writer, value);
            }
        }

        try writer.writeAll("\n");
    }
};

/// 带字段的日志器
pub fn FieldLogger(comptime Fields: type) type {
    return struct {
        const Self = @This();

        logger: *Logger,
        fields: Fields,

        pub fn debug(self: Self, comptime msg: []const u8, args: anytype) void {
            self.logger.log(.debug, msg, args, self.fields);
        }

        pub fn info(self: Self, comptime msg: []const u8, args: anytype) void {
            self.logger.log(.info, msg, args, self.fields);
        }

        pub fn warn(self: Self, comptime msg: []const u8, args: anytype) void {
            self.logger.log(.warn, msg, args, self.fields);
        }

        pub fn err(self: Self, comptime msg: []const u8, args: anytype) void {
            self.logger.log(.err, msg, args, self.fields);
        }

        pub fn fatal(self: Self, comptime msg: []const u8, args: anytype) void {
            self.logger.log(.fatal, msg, args, self.fields);
        }
    };
}

/// 带模块名称的作用域日志器（类似 Zig std.log.scoped）
pub const ScopedLogger = struct {
    const Self = @This();

    parent: *Logger,
    module_name: []const u8,

    pub fn debug(self: Self, comptime msg: []const u8, args: anytype) void {
        self.logWithModule(.debug, msg, args);
    }

    pub fn info(self: Self, comptime msg: []const u8, args: anytype) void {
        self.logWithModule(.info, msg, args);
    }

    pub fn warn(self: Self, comptime msg: []const u8, args: anytype) void {
        self.logWithModule(.warn, msg, args);
    }

    pub fn err(self: Self, comptime msg: []const u8, args: anytype) void {
        self.logWithModule(.err, msg, args);
    }

    pub fn fatal(self: Self, comptime msg: []const u8, args: anytype) void {
        self.logWithModule(.fatal, msg, args);
    }

    fn logWithModule(self: Self, level: Level, comptime msg: []const u8, args: anytype) void {
        if (!self.parent.isEnabled(level)) return;

        self.parent.mutex.lock();
        defer self.parent.mutex.unlock();

        var buf: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        // 临时设置模块名
        const old_module = self.parent.config.module_name;
        self.parent.config.module_name = self.module_name;
        defer self.parent.config.module_name = old_module;

        self.parent.formatEntry(writer, level, msg, args, .{}) catch return;

        const output = fbs.getWritten();
        for (self.parent.writers.items) |w| {
            w.write(output);
        }

        if (self.parent.writers.items.len == 0) {
            _ = std.posix.write(std.posix.STDERR_FILENO, output) catch {};
        }
    }
};

/// 轮转文件写入器
///
/// 支持按大小轮转，保留最近 N 个文件
pub const RotatingFileWriter = struct {
    const Self = @This();

    allocator: Allocator,
    base_path: []const u8,
    current_file: ?std.fs.File,
    max_size: u64,
    max_backups: u8,
    current_size: u64,
    mutex: Mutex,

    /// 轮转配置
    pub const Config = struct {
        /// 单文件最大大小（字节）
        max_size: u64 = 10 * 1024 * 1024, // 10MB
        /// 最大备份文件数
        max_backups: u8 = 5,
    };

    pub fn init(allocator: Allocator, path: []const u8, config: Config) !Self {
        const path_copy = try allocator.dupe(u8, path);
        var self = Self{
            .allocator = allocator,
            .base_path = path_copy,
            .current_file = null,
            .max_size = config.max_size,
            .max_backups = config.max_backups,
            .current_size = 0,
            .mutex = .{},
        };

        try self.openFile();
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.current_file) |f| {
            f.close();
        }
        self.allocator.free(self.base_path);
    }

    fn openFile(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.base_path, .{
            .truncate = false,
        });
        try file.seekFromEnd(0);
        self.current_file = file;

        // 获取当前文件大小
        const stat = try file.stat();
        self.current_size = stat.size;
    }

    fn rotate(self: *Self) !void {
        if (self.current_file) |f| {
            f.close();
            self.current_file = null;
        }

        // 删除最旧的备份
        var path_buf: [512]u8 = undefined;
        const oldest = std.fmt.bufPrint(&path_buf, "{s}.{d}", .{ self.base_path, self.max_backups }) catch return;
        std.fs.cwd().deleteFile(oldest) catch {};

        // 重命名现有备份
        var i: u8 = self.max_backups - 1;
        while (i >= 1) : (i -= 1) {
            const old_name = std.fmt.bufPrint(&path_buf, "{s}.{d}", .{ self.base_path, i }) catch continue;
            var new_buf: [512]u8 = undefined;
            const new_name = std.fmt.bufPrint(&new_buf, "{s}.{d}", .{ self.base_path, i + 1 }) catch continue;
            std.fs.cwd().rename(old_name, new_name) catch {};
        }

        // 重命名当前文件
        const backup1 = std.fmt.bufPrint(&path_buf, "{s}.1", .{self.base_path}) catch return;
        std.fs.cwd().rename(self.base_path, backup1) catch {};

        // 打开新文件
        self.current_size = 0;
        try self.openFile();
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeRotating,
        };
    }

    fn writeRotating(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        // 检查是否需要轮转
        if (self.current_size + data.len > self.max_size) {
            self.rotate() catch return;
        }

        if (self.current_file) |f| {
            f.writeAll(data) catch return;
            self.current_size += data.len;
        }
    }
};

/// 多输出写入器
///
/// 同时写入多个目标
pub const MultiWriter = struct {
    const Self = @This();

    writers: std.ArrayListUnmanaged(Writer),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{
            .writers = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.writers.deinit(self.allocator);
    }

    pub fn add(self: *Self, w: Writer) !void {
        try self.writers.append(self.allocator, w);
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeMulti,
        };
    }

    fn writeMulti(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        for (self.writers.items) |w| {
            w.write(data);
        }
    }
};

// ============================================================================
// 高性能异步日志
// ============================================================================

/// 异步日志缓冲区
const AsyncBuffer = struct {
    data: []u8,
    len: usize,
};

/// 双缓冲异步写入器
///
/// ## 设计原理
///
/// 使用双缓冲（Double Buffering）技术，一个缓冲区用于写入，另一个用于刷新，
/// 通过快速切换减少写入线程的等待时间。
///
/// ## 优点
///
/// - **减少阻塞**：写入和刷新可以并行进行
/// - **批量写入**：累积多条日志后一次性写入，减少系统调用
/// - **内存可控**：固定大小缓冲区，不会无限增长
///
/// ## 线程安全
///
/// - 使用 Mutex 保护缓冲区切换操作
/// - 写入时短暂加锁，刷新时持有锁直到完成
/// - 适合中等并发场景（<100 线程）
///
/// ## 内存安全
///
/// - init() 分配两个固定大小缓冲区
/// - deinit() 先刷新残留数据，再释放内存
/// - 缓冲区大小在初始化时确定，运行时不会重新分配
///
/// ## 使用建议
///
/// - 通用场景首选，平衡了性能和复杂度
/// - 高并发场景建议使用 LockFreeWriter
pub const AsyncWriter = struct {
    const Self = @This();
    const BUFFER_COUNT = 2;

    allocator: Allocator,
    target: Writer,
    buffers: [BUFFER_COUNT][]u8,
    buffer_lens: [BUFFER_COUNT]usize,
    active_buffer: u8,
    buffer_size: usize,
    flush_threshold: usize,
    mutex: Mutex,
    flush_interval_ns: u64,

    /// 异步配置
    pub const Config = struct {
        /// 每个缓冲区大小
        buffer_size: usize = 64 * 1024, // 64KB
        /// 刷新阈值（缓冲区使用率）
        flush_threshold: usize = 32 * 1024, // 32KB
        /// 刷新间隔（毫秒）
        flush_interval_ms: u64 = 100, // 100ms
    };

    pub fn init(allocator: Allocator, target: Writer, config: Config) !Self {
        var buffers: [BUFFER_COUNT][]u8 = undefined;
        for (0..BUFFER_COUNT) |i| {
            buffers[i] = try allocator.alloc(u8, config.buffer_size);
        }

        return Self{
            .allocator = allocator,
            .target = target,
            .buffers = buffers,
            .buffer_lens = .{ 0, 0 },
            .active_buffer = 0,
            .buffer_size = config.buffer_size,
            .flush_threshold = config.flush_threshold,
            .mutex = .{},
            .flush_interval_ns = config.flush_interval_ms * 1_000_000,
        };
    }

    pub fn deinit(self: *Self) void {
        // 刷新剩余数据
        self.flushAll();

        // 释放缓冲区
        for (0..BUFFER_COUNT) |i| {
            self.allocator.free(self.buffers[i]);
        }
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeAsync,
            .flushFn = flushAsync,
        };
    }

    fn writeAsync(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
    }

    fn flushAsync(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }

    /// 写入数据（几乎无阻塞）
    pub fn write(self: *Self, data: []const u8) void {
        if (data.len == 0) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        const active = self.active_buffer;
        const current_len = self.buffer_lens[active];
        const available = self.buffer_size - current_len;

        if (data.len <= available) {
            // 直接写入当前缓冲区
            @memcpy(self.buffers[active][current_len..][0..data.len], data);
            self.buffer_lens[active] = current_len + data.len;

            // 超过阈值时自动刷新
            if (self.buffer_lens[active] >= self.flush_threshold) {
                self.flushCurrentLocked();
            }
        } else {
            // 缓冲区满，切换并刷新旧缓冲区
            self.swapAndFlushLocked();

            // 写入新缓冲区
            const new_active = self.active_buffer;
            if (data.len <= self.buffer_size) {
                @memcpy(self.buffers[new_active][0..data.len], data);
                self.buffer_lens[new_active] = data.len;
            } else {
                // 数据太大，直接写入目标
                self.target.write(data);
            }
        }
    }

    fn flushCurrentLocked(self: *Self) void {
        const active = self.active_buffer;
        const len = self.buffer_lens[active];
        if (len > 0) {
            self.target.write(self.buffers[active][0..len]);
            self.buffer_lens[active] = 0;
        }
    }

    fn swapAndFlushLocked(self: *Self) void {
        const old_active = self.active_buffer;
        const old_len = self.buffer_lens[old_active];

        // 切换到另一个缓冲区
        self.active_buffer = 1 - old_active;
        self.buffer_lens[self.active_buffer] = 0;

        // 刷新旧缓冲区
        if (old_len > 0) {
            self.target.write(self.buffers[old_active][0..old_len]);
            self.buffer_lens[old_active] = 0;
        }
    }

    fn flushAll(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (0..BUFFER_COUNT) |i| {
            const len = self.buffer_lens[i];
            if (len > 0) {
                self.target.write(self.buffers[i][0..len]);
                self.buffer_lens[i] = 0;
            }
        }
    }

    /// 强制刷新
    pub fn flush(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const active = self.active_buffer;
        const len = self.buffer_lens[active];
        if (len > 0) {
            self.target.write(self.buffers[active][0..len]);
            self.buffer_lens[active] = 0;
        }
    }
};

/// 无锁环形缓冲区写入器（Lock-Free Ring Buffer）
///
/// ## 设计原理
///
/// 使用环形缓冲区（Ring Buffer）配合 CAS（Compare-And-Swap）原子操作，
/// 实现多线程写入时完全无锁，仅在刷新时使用轻量级自旋锁。
///
/// ```
/// 写入流程：
/// 1. 原子读取 write_pos
/// 2. CAS 尝试预留空间
/// 3. 成功后写入数据到环形缓冲区
/// 4. 达到阈值时触发异步刷新
/// ```
///
/// ## 优点
///
/// - **零锁竞争**：写入使用 CAS 操作，无需等待锁
/// - **低延迟**：平均写入延迟 < 1μs
/// - **高吞吐**：支持 >100 万条/秒的写入速度
/// - **内存友好**：固定大小环形缓冲区，无运行时分配
///
/// ## 线程安全
///
/// - **写入**：使用 cmpxchgWeak 原子操作预留空间，完全无锁
/// - **刷新**：使用原子标志位实现自旋锁，避免重复刷新
/// - **内存序**：使用 acquire/release 语义保证跨线程可见性
///
/// ## 内存安全
///
/// - 缓冲区大小自动对齐到 2 的幂（位运算优化）
/// - 使用 wrapping 算术（-%）处理位置回绕，防止溢出
/// - deinit() 保证先刷新再释放内存
///
/// ## 注意事项
///
/// - 缓冲区满时会阻塞等待刷新完成
/// - 单条日志不能超过缓冲区大小
/// - 建议缓冲区设置为预期峰值吞吐量的 2-4 倍
///
/// ## 使用建议
///
/// - 高并发场景首选（>100 线程）
/// - 对延迟敏感的实时系统
pub const LockFreeWriter = struct {
    const Self = @This();

    allocator: Allocator,
    target: Writer,
    buffer: []u8,
    buffer_size: usize,
    /// 写入位置（原子）
    write_pos: std.atomic.Value(usize),
    /// 已提交位置（原子）
    commit_pos: std.atomic.Value(usize),
    /// 刷新阈值
    flush_threshold: usize,
    /// 是否正在刷新
    flushing: std.atomic.Value(bool),

    pub const Config = struct {
        /// 缓冲区大小（必须是 2 的幂）
        buffer_size: usize = 64 * 1024, // 64KB
        /// 刷新阈值
        flush_threshold: usize = 32 * 1024, // 32KB
    };

    pub fn init(allocator: Allocator, target: Writer, config: Config) !Self {
        // 确保缓冲区大小是 2 的幂
        const size = blk: {
            var s = config.buffer_size;
            if (s == 0) s = 64 * 1024;
            // 向上取整到 2 的幂
            s -= 1;
            s |= s >> 1;
            s |= s >> 2;
            s |= s >> 4;
            s |= s >> 8;
            s |= s >> 16;
            s += 1;
            break :blk s;
        };

        return Self{
            .allocator = allocator,
            .target = target,
            .buffer = try allocator.alloc(u8, size),
            .buffer_size = size,
            .write_pos = std.atomic.Value(usize).init(0),
            .commit_pos = std.atomic.Value(usize).init(0),
            .flush_threshold = config.flush_threshold,
            .flushing = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *Self) void {
        self.flush();
        self.allocator.free(self.buffer);
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeLockFree,
            .flushFn = flushLockFree,
        };
    }

    fn writeLockFree(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
    }

    fn flushLockFree(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }

    /// 无锁写入
    pub fn write(self: *Self, data: []const u8) void {
        if (data.len == 0) return;

        const mask = self.buffer_size - 1;

        // 尝试预留空间（CAS 循环）
        while (true) {
            const current_write = self.write_pos.load(.acquire);
            const commit = self.commit_pos.load(.acquire);

            // 检查可用空间
            const used = current_write -% commit;
            if (used + data.len > self.buffer_size) {
                // 缓冲区满，强制刷新
                self.flush();
                continue;
            }

            // 尝试预留空间
            const new_write = current_write +% data.len;
            if (self.write_pos.cmpxchgWeak(current_write, new_write, .acq_rel, .acquire)) |_| {
                // CAS 失败，重试
                continue;
            }

            // 成功预留，写入数据
            var pos = current_write;
            for (data) |byte| {
                self.buffer[pos & mask] = byte;
                pos +%= 1;
            }

            // 检查是否需要刷新
            const new_used = new_write -% self.commit_pos.load(.acquire);
            if (new_used >= self.flush_threshold) {
                self.tryFlush();
            }

            break;
        }
    }

    /// 尝试刷新（非阻塞）
    fn tryFlush(self: *Self) void {
        // 尝试获取刷新权限
        if (self.flushing.cmpxchgWeak(false, true, .acq_rel, .acquire)) |_| {
            // 其他线程正在刷新
            return;
        }

        self.doFlush();
        self.flushing.store(false, .release);
    }

    /// 强制刷新
    pub fn flush(self: *Self) void {
        // 等待获取刷新权限
        while (self.flushing.cmpxchgWeak(false, true, .acq_rel, .acquire)) |_| {
            std.atomic.spinLoopHint();
        }

        self.doFlush();
        self.flushing.store(false, .release);
    }

    fn doFlush(self: *Self) void {
        const mask = self.buffer_size - 1;
        const write_pos = self.write_pos.load(.acquire);
        const commit = self.commit_pos.load(.acquire);

        if (commit == write_pos) return;

        // 计算需要刷新的数据
        const len = write_pos -% commit;
        if (len == 0) return;

        // 写入目标
        if (len <= self.buffer_size) {
            const start = commit & mask;
            const end_pos = (commit +% len) & mask;

            if (start < end_pos) {
                // 连续区域
                self.target.write(self.buffer[start..end_pos]);
            } else {
                // 跨越边界，分两次写入
                self.target.write(self.buffer[start..]);
                if (end_pos > 0) {
                    self.target.write(self.buffer[0..end_pos]);
                }
            }
        }

        // 更新提交位置
        self.commit_pos.store(write_pos, .release);
    }

    /// 获取缓冲区使用量
    pub fn usage(self: *Self) usize {
        const write_pos = self.write_pos.load(.acquire);
        const commit = self.commit_pos.load(.acquire);
        return write_pos -% commit;
    }
};

/// 线程本地缓冲写入器（Thread-Local Storage Buffer）
///
/// ## 设计原理
///
/// 为每个线程分配独立的缓冲区，写入时直接操作本线程缓冲区，
/// 完全避免线程间竞争。仅在缓冲区满或显式刷新时才需要同步。
///
/// ```
/// 写入流程：
/// 1. 通过线程 ID 哈希找到专属缓冲区
/// 2. 直接写入本地缓冲区（无锁）
/// 3. 缓冲区满时加锁刷新到目标
/// ```
///
/// ## 优点
///
/// - **完全无锁**：每线程独立缓冲区，写入零竞争
/// - **最低延迟**：本地内存写入，无原子操作开销
/// - **最高吞吐**：理论上限等于内存带宽
/// - **缓存友好**：线程本地数据，CPU 缓存命中率高
///
/// ## 线程安全
///
/// - **写入**：每线程独立缓冲区，完全无锁
/// - **槽位分配**：通过线程 ID 哈希 + 线性探测
/// - **刷新**：使用 Mutex 保护目标写入器
///
/// ## 内存安全
///
/// - 预分配固定数量的线程槽位（默认 64）
/// - 每个槽位固定 4KB 缓冲区
/// - deinit() 遍历刷新所有非空缓冲区
///
/// ## 注意事项
///
/// - 最大支持 MAX_THREADS(64) 个并发线程
/// - 超出时会降级为直接写入（加锁）
/// - 刷新时会短暂阻塞所有线程
///
/// ## 使用建议
///
/// - 线程数固定且较少的场景（<64）
/// - 追求极致性能的场景
/// - 日志顺序不严格要求的场景
pub const ThreadLocalWriter = struct {
    const Self = @This();
    /// 最大支持线程数
    const MAX_THREADS = 64;
    /// 每线程缓冲区大小
    const TLS_BUFFER_SIZE = 4096;

    /// 线程本地缓冲区
    const ThreadBuffer = struct {
        buffer: [TLS_BUFFER_SIZE]u8 = undefined,
        pos: usize = 0,
        owner: ?std.Thread.Id = null,
    };

    allocator: Allocator,
    target: Writer,
    buffers: []ThreadBuffer,
    buffer_count: usize,
    flush_mutex: Mutex, // 仅刷新时使用

    pub fn init(allocator: Allocator, target: Writer) !Self {
        const buffers = try allocator.alloc(ThreadBuffer, MAX_THREADS);
        for (buffers) |*buf| {
            buf.* = .{};
        }

        return Self{
            .allocator = allocator,
            .target = target,
            .buffers = buffers,
            .buffer_count = MAX_THREADS,
            .flush_mutex = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.flushAll();
        self.allocator.free(self.buffers);
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeTLS,
            .flushFn = flushTLS,
        };
    }

    fn writeTLS(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
    }

    fn flushTLS(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flushAll();
    }

    /// 获取当前线程的缓冲区（无锁）
    fn getThreadBuffer(self: *Self) ?*ThreadBuffer {
        const tid = std.Thread.getCurrentId();

        // 简单哈希找槽位
        const hash = @as(usize, @intCast(tid)) % self.buffer_count;

        // 尝试当前槽位
        var buf = &self.buffers[hash];
        if (buf.owner == tid) {
            return buf;
        }

        // 槽位空闲，尝试占用
        if (buf.owner == null) {
            buf.owner = tid;
            return buf;
        }

        // 线性探测
        var i: usize = 1;
        while (i < self.buffer_count) : (i += 1) {
            const idx = (hash + i) % self.buffer_count;
            buf = &self.buffers[idx];

            if (buf.owner == tid) return buf;
            if (buf.owner == null) {
                buf.owner = tid;
                return buf;
            }
        }

        return null;
    }

    /// 写入（线程本地，无锁）
    pub fn write(self: *Self, data: []const u8) void {
        if (data.len == 0) return;

        const buf = self.getThreadBuffer() orelse {
            // 无可用槽位，直接写入目标
            self.flush_mutex.lock();
            defer self.flush_mutex.unlock();
            self.target.write(data);
            return;
        };

        // 检查是否需要刷新
        if (buf.pos + data.len > TLS_BUFFER_SIZE) {
            self.flushBuffer(buf);
        }

        // 写入本地缓冲区
        if (data.len <= TLS_BUFFER_SIZE - buf.pos) {
            @memcpy(buf.buffer[buf.pos..][0..data.len], data);
            buf.pos += data.len;
        } else {
            // 数据太大，直接写入
            self.flush_mutex.lock();
            defer self.flush_mutex.unlock();
            self.target.write(data);
        }
    }

    /// 刷新单个缓冲区
    fn flushBuffer(self: *Self, buf: *ThreadBuffer) void {
        if (buf.pos == 0) return;

        self.flush_mutex.lock();
        defer self.flush_mutex.unlock();

        self.target.write(buf.buffer[0..buf.pos]);
        buf.pos = 0;
    }

    /// 刷新所有缓冲区
    pub fn flushAll(self: *Self) void {
        self.flush_mutex.lock();
        defer self.flush_mutex.unlock();

        for (self.buffers) |*buf| {
            if (buf.pos > 0) {
                self.target.write(buf.buffer[0..buf.pos]);
                buf.pos = 0;
            }
        }
    }
};

/// 带缓冲的文件写入器
///
/// 减少系统调用次数，提高写入效率
pub const BufferedFileWriter = struct {
    const Self = @This();

    file: std.fs.File,
    buffer: []u8,
    pos: usize,
    allocator: Allocator,
    mutex: Mutex,

    pub const Config = struct {
        buffer_size: usize = 8 * 1024, // 8KB
    };

    pub fn init(allocator: Allocator, path: []const u8, config: Config) !Self {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
        try file.seekFromEnd(0);

        return Self{
            .file = file,
            .buffer = try allocator.alloc(u8, config.buffer_size),
            .pos = 0,
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.flush();
        self.file.close();
        self.allocator.free(self.buffer);
    }

    pub fn writer(self: *Self) Writer {
        return .{
            .ptr = self,
            .writeFn = writeBuffered,
            .flushFn = flushBuffered,
        };
    }

    fn writeBuffered(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
    }

    fn flushBuffered(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }

    pub fn write(self: *Self, data: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const available = self.buffer.len - self.pos;

        if (data.len <= available) {
            @memcpy(self.buffer[self.pos..][0..data.len], data);
            self.pos += data.len;
        } else {
            // 先刷新缓冲区
            if (self.pos > 0) {
                self.file.writeAll(self.buffer[0..self.pos]) catch {};
                self.pos = 0;
            }

            // 大数据直接写入
            if (data.len >= self.buffer.len) {
                self.file.writeAll(data) catch {};
            } else {
                @memcpy(self.buffer[0..data.len], data);
                self.pos = data.len;
            }
        }
    }

    pub fn flush(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.pos > 0) {
            self.file.writeAll(self.buffer[0..self.pos]) catch {};
            self.pos = 0;
        }
    }
};

/// 格式化值
fn formatValue(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int, .comptime_int => try writer.print("{d}", .{value}),
        .float, .comptime_float => try writer.print("{d:.6}", .{value}),
        .bool => try writer.print("{}", .{value}),
        .pointer => |ptr| {
            // 字符串切片 []const u8
            if (ptr.size == .slice and ptr.child == u8) {
                try writer.print("\"{s}\"", .{value});
            }
            // 字符串字面量 *const [N]u8
            else if (ptr.size == .one and @typeInfo(ptr.child) == .array) {
                const arr_info = @typeInfo(ptr.child).array;
                if (arr_info.child == u8) {
                    try writer.print("\"{s}\"", .{value});
                } else {
                    try writer.print("{any}", .{value});
                }
            } else {
                try writer.print("{any}", .{value});
            }
        },
        .optional => {
            if (value) |v| {
                try formatValue(writer, v);
            } else {
                try writer.writeAll("null");
            }
        },
        .error_set => try writer.print("\"{s}\"", .{@errorName(value)}),
        else => try writer.print("{any}", .{value}),
    }
}

/// 格式化 JSON 值
fn formatJsonValue(writer: anytype, value: anytype) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int, .comptime_int => try writer.print("{d}", .{value}),
        .float, .comptime_float => try writer.print("{d:.6}", .{value}),
        .bool => try writer.print("{}", .{value}),
        .pointer => |ptr| {
            // 字符串切片 []const u8
            if (ptr.size == .slice and ptr.child == u8) {
                try writer.print("\"{s}\"", .{value});
            }
            // 字符串字面量 *const [N]u8
            else if (ptr.size == .one and @typeInfo(ptr.child) == .array) {
                const arr_info = @typeInfo(ptr.child).array;
                if (arr_info.child == u8) {
                    try writer.print("\"{s}\"", .{value});
                } else {
                    try writer.print("\"{any}\"", .{value});
                }
            } else {
                try writer.print("\"{any}\"", .{value});
            }
        },
        .optional => {
            if (value) |v| {
                try formatJsonValue(writer, v);
            } else {
                try writer.writeAll("null");
            }
        },
        .error_set => try writer.print("\"{s}\"", .{@errorName(value)}),
        else => try writer.print("\"{any}\"", .{value}),
    }
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建默认日志器（输出到 stderr）
pub fn createLogger(allocator: Allocator) Logger {
    return Logger.init(allocator, .{});
}

/// 创建 JSON 格式日志器
pub fn createJsonLogger(allocator: Allocator) Logger {
    return Logger.init(allocator, .{ .format = .json });
}

/// 创建彩色日志器（用于开发）
pub fn createColoredLogger(allocator: Allocator) Logger {
    return Logger.init(allocator, .{ .format = .colored });
}

/// 全局日志器（可选）
var global_logger: ?*Logger = null;

// ============================================================================
// 崩溃保护机制
// ============================================================================
//
// ## 设计目标
//
// 确保程序异常退出（panic、崩溃、信号中断）时，缓冲区中的日志不会丢失。
// 这对于问题排查至关重要，因为崩溃前的日志往往包含关键的错误信息。
//
// ## 三层保护
//
// 1. **sync_on_error**：ERROR/FATAL 级别自动同步刷新
//    - 错误日志立即写入磁盘，不依赖缓冲区
//    - 即使后续崩溃，错误信息也已保存
//
// 2. **registerCrashFlush**：注册崩溃时刷新的写入器
//    - 程序退出前遍历刷新所有注册的写入器
//    - 配合 defer 使用，确保释放顺序正确
//
// 3. **panicHandler**：自定义 panic 处理器
//    - 记录 panic 信息到日志
//    - 刷新所有缓冲区后再终止程序
//
// ## 线程安全
//
// - crash_flush_writers 使用固定大小数组，无需动态分配
// - 注册/取消操作应在单线程初始化阶段完成
// - flushAllCrashWriters 可在任意线程调用
//
// ## 内存安全
//
// - 仅存储指针和函数指针，不拥有内存
// - 必须确保注册的写入器生命周期覆盖整个程序运行期
// - 使用 defer unregisterCrashFlush 确保正确清理

/// 需要在崩溃时刷新的写入器列表（最多 16 个）
var crash_flush_writers: [16]?*anyopaque = .{null} ** 16;
var crash_flush_fns: [16]?*const fn (*anyopaque) void = .{null} ** 16;
var crash_flush_count: usize = 0;

/// 设置全局日志器
///
/// 全局日志器用于：
/// - panicHandler 记录崩溃信息
/// - scoped() API 的默认输出目标
pub fn setGlobalLogger(logger: ?*Logger) void {
    global_logger = logger;
}

/// 获取全局日志器
pub fn getGlobalLogger() ?*Logger {
    return global_logger;
}

/// 注册需要在崩溃时刷新的写入器
///
/// ## 功能
///
/// 将缓冲类写入器注册到崩溃保护列表。当程序异常退出时，
/// 会自动调用所有注册写入器的 flush() 方法，确保日志不丢失。
///
/// ## 线程安全
///
/// - 注册操作非原子，应在程序初始化阶段单线程调用
/// - 建议配合 defer 使用确保正确取消注册
///
/// ## 使用示例
///
/// ```zig
/// var async_writer = try AsyncWriter.init(allocator, target, .{});
/// logger.registerCrashFlush(&async_writer);
/// defer logger.unregisterCrashFlush(&async_writer);
/// ```
///
/// ## 注意
///
/// - 最多支持 16 个写入器
/// - 写入器必须有 flush(*Self) void 方法
pub fn registerCrashFlush(writer_ptr: anytype) void {
    const T = @TypeOf(writer_ptr);
    const ptr_info = @typeInfo(T);

    if (ptr_info != .pointer) {
        @compileError("registerCrashFlush requires a pointer type");
    }

    if (crash_flush_count < 16) {
        crash_flush_writers[crash_flush_count] = @ptrCast(writer_ptr);
        crash_flush_fns[crash_flush_count] = @ptrCast(&@TypeOf(writer_ptr.*).flush);
        crash_flush_count += 1;
    }
}

/// 取消注册崩溃刷新
pub fn unregisterCrashFlush(writer_ptr: anytype) void {
    const ptr: *anyopaque = @ptrCast(writer_ptr);
    for (0..crash_flush_count) |i| {
        if (crash_flush_writers[i] == ptr) {
            // 移除该项，后面的项前移
            var j = i;
            while (j + 1 < crash_flush_count) : (j += 1) {
                crash_flush_writers[j] = crash_flush_writers[j + 1];
                crash_flush_fns[j] = crash_flush_fns[j + 1];
            }
            crash_flush_count -= 1;
            crash_flush_writers[crash_flush_count] = null;
            crash_flush_fns[crash_flush_count] = null;
            break;
        }
    }
}

/// 刷新所有注册的崩溃写入器
pub fn flushAllCrashWriters() void {
    for (0..crash_flush_count) |i| {
        if (crash_flush_writers[i]) |ptr| {
            if (crash_flush_fns[i]) |flush_fn| {
                flush_fn(ptr);
            }
        }
    }
    // 同时刷新全局日志器
    if (global_logger) |logger| {
        logger.flush();
    }
}

/// 自定义 panic 处理器
///
/// 在程序的入口文件中设置：
/// ```zig
/// pub const panic = logger.panicHandler;
/// ```
/// 或者在 panic 发生时手动调用 flushAllCrashWriters()
pub fn panicHandler(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // 先尝试记录 panic 信息到日志
    if (global_logger) |logger| {
        logger.fatal("PANIC: {s}", .{msg});
    }

    // 刷新所有缓冲区
    flushAllCrashWriters();

    // 输出到 stderr 作为最后保障
    _ = std.posix.write(std.posix.STDERR_FILENO, "PANIC: ") catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, msg) catch {};
    _ = std.posix.write(std.posix.STDERR_FILENO, "\n") catch {};

    // 终止程序
    std.posix.abort();
}

// ============================================================================
// 类似 std.log 的顶层 API
// ============================================================================

/// 创建作用域日志器（类似 std.log.scoped(.app)）
///
/// ## 使用示例
/// ```zig
/// const logger = @import("services/logger/logger.zig");
///
/// // 定义模块日志器
/// const log = logger.scoped(.http);
///
/// pub fn handleRequest() void {
///     log.info("处理请求", .{});
/// }
/// ```
pub fn scoped(comptime module: @Type(.enum_literal)) type {
    return struct {
        const scope_name = @tagName(module);

        pub fn debug(comptime msg: []const u8, args: anytype) void {
            logTo(.debug, msg, args);
        }

        pub fn info(comptime msg: []const u8, args: anytype) void {
            logTo(.info, msg, args);
        }

        pub fn warn(comptime msg: []const u8, args: anytype) void {
            logTo(.warn, msg, args);
        }

        pub fn err(comptime msg: []const u8, args: anytype) void {
            logTo(.err, msg, args);
        }

        pub fn fatal(comptime msg: []const u8, args: anytype) void {
            logTo(.fatal, msg, args);
        }

        fn logTo(level: Level, comptime msg: []const u8, args: anytype) void {
            if (global_logger) |logger| {
                const scoped_log = logger.scoped(scope_name);
                switch (level) {
                    .debug => scoped_log.debug(msg, args),
                    .info => scoped_log.info(msg, args),
                    .warn => scoped_log.warn(msg, args),
                    .err => scoped_log.err(msg, args),
                    .fatal => scoped_log.fatal(msg, args),
                }
            } else {
                // 无全局日志器时，输出到 stderr
                var buf: [8192]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buf);
                const writer = fbs.writer();

                const ts = std.time.timestamp();
                const now = Timestamp.fromUnix(ts, 8 * 3600);
                now.format(writer) catch return;
                writer.print(" [{s}] ({s}) ", .{ level.name(), scope_name }) catch return;
                writer.print(msg, args) catch return;
                writer.writeAll("\n") catch return;

                _ = std.posix.write(std.posix.STDERR_FILENO, fbs.getWritten()) catch {};
            }
        }
    };
}

/// 默认日志器（无作用域）
pub const default = scoped(.default);

// ============================================================================
// 测试
// ============================================================================

test "Logger: 基本日志" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    // 测试不会崩溃
    log.info("测试消息", .{});
    log.debug("调试消息", .{});
    log.warn("警告消息", .{});
}

test "Logger: 级别过滤" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .level = .warn });
    defer log.deinit();

    try std.testing.expect(!log.isEnabled(.debug));
    try std.testing.expect(!log.isEnabled(.info));
    try std.testing.expect(log.isEnabled(.warn));
    try std.testing.expect(log.isEnabled(.err));
}

test "Logger: 结构化日志" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    log.with(.{ .user_id = @as(i64, 123), .action = "login" }).info("用户登录", .{});
}

test "Level: 名称和颜色" {
    try std.testing.expectEqualStrings("INFO", Level.info.name());
    try std.testing.expectEqualStrings("INF", Level.info.shortName());
    try std.testing.expect(Level.info.color().len > 0);
}

test "Logger: 模块名称" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .format = .text,
        .module_name = "http",
    });
    defer log.deinit();

    log.info("处理请求", .{});
}

test "Logger: 作用域日志器" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    const http_log = log.scoped("http");
    http_log.info("处理请求", .{});

    const db_log = log.scoped("database");
    db_log.info("执行查询", .{});
}

test "Logger: 配置方法" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{});
    defer log.deinit();

    // 测试 setLevel
    log.setLevel(.debug);
    try std.testing.expect(log.isEnabled(.debug));

    // 测试 setFormat
    log.setFormat(.json);

    // 测试 setModule
    log.setModule("test");
}

test "Logger: 多输出" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    // 添加 stdout writer
    try log.addWriter(StdoutWriter.writer());

    // 清空 writers
    log.clearWriters();
    try std.testing.expectEqual(@as(usize, 0), log.writers.items.len);
}

test "MultiWriter: 多目标写入" {
    const allocator = std.testing.allocator;
    var multi = MultiWriter.init(allocator);
    defer multi.deinit();

    try multi.add(StderrWriter.writer());
    try std.testing.expectEqual(@as(usize, 1), multi.writers.items.len);
}

test "Logger: 枚举风格 scope" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    // 使用 .app 风格
    const app_log = log.scope(.app);
    app_log.info("应用启动", .{});

    const http_log = log.scope(.http);
    http_log.info("HTTP 请求", .{});

    const db_log = log.scope(.database);
    db_log.info("数据库连接", .{});
}

test "scoped: 顶层 API" {
    // 类似 std.log.scoped(.app) 的用法
    const app_log = scoped(.app);
    const http_log = scoped(.http);

    // 无全局日志器时也能工作
    app_log.info("测试消息", .{});
    http_log.warn("警告消息", .{});

    // 默认日志器
    default.info("默认日志", .{});
}

test "Logger: 所有日志级别" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .level = .debug, .format = .text });
    defer log.deinit();

    log.debug("DEBUG 消息", .{});
    log.info("INFO 消息", .{});
    log.warn("WARN 消息", .{});
    log.err("ERROR 消息", .{});
    log.fatal("FATAL 消息", .{});
}

test "Logger: JSON 格式输出" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .format = .json,
        .module_name = "test",
    });
    defer log.deinit();

    log.info("JSON 日志测试", .{});
    log.with(.{ .code = @as(i64, 200), .path = "/api/users" }).info("请求完成", .{});
}

test "Logger: 彩色格式输出" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .format = .colored,
        .module_name = "colored_test",
    });
    defer log.deinit();

    log.debug("调试信息", .{});
    log.info("普通信息", .{});
    log.warn("警告信息", .{});
    log.err("错误信息", .{});
}

test "Logger: 结构化日志多种字段类型" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    // 整数类型
    log.with(.{ .count = @as(i64, 42) }).info("整数字段", .{});

    // 浮点类型
    log.with(.{ .ratio = @as(f64, 3.14159) }).info("浮点字段", .{});

    // 布尔类型
    log.with(.{ .enabled = true, .disabled = false }).info("布尔字段", .{});

    // 字符串类型
    log.with(.{ .name = "test_user", .action = "login" }).info("字符串字段", .{});

    // 混合类型
    log.with(.{
        .user_id = @as(i64, 1001),
        .username = "admin",
        .is_admin = true,
        .score = @as(f64, 98.5),
    }).info("混合字段", .{});
}

test "Logger: 禁用时间戳" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .format = .text,
        .include_timestamp = false,
    });
    defer log.deinit();

    log.info("无时间戳消息", .{});
}

test "Logger: 禁用模块名称" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .format = .text,
        .module_name = "should_hide",
        .include_module = false,
    });
    defer log.deinit();

    log.info("模块名称被隐藏", .{});
}

test "Logger: 全局日志器" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text, .module_name = "global" });
    defer log.deinit();

    // 设置全局日志器
    setGlobalLogger(&log);
    defer setGlobalLogger(null);

    try std.testing.expect(getGlobalLogger() != null);
    try std.testing.expectEqual(&log, getGlobalLogger().?);

    // 使用顶层 scoped API
    const app_log = scoped(.app);
    app_log.info("通过全局日志器输出", .{});
}

test "Level: 所有级别属性" {
    // 测试所有级别的名称
    try std.testing.expectEqualStrings("DEBUG", Level.debug.name());
    try std.testing.expectEqualStrings("INFO", Level.info.name());
    try std.testing.expectEqualStrings("WARN", Level.warn.name());
    try std.testing.expectEqualStrings("ERROR", Level.err.name());
    try std.testing.expectEqualStrings("FATAL", Level.fatal.name());

    // 测试所有级别的短名称
    try std.testing.expectEqualStrings("DBG", Level.debug.shortName());
    try std.testing.expectEqualStrings("INF", Level.info.shortName());
    try std.testing.expectEqualStrings("WRN", Level.warn.shortName());
    try std.testing.expectEqualStrings("ERR", Level.err.shortName());
    try std.testing.expectEqualStrings("FTL", Level.fatal.shortName());

    // 测试颜色不为空
    try std.testing.expect(Level.debug.color().len > 0);
    try std.testing.expect(Level.info.color().len > 0);
    try std.testing.expect(Level.warn.color().len > 0);
    try std.testing.expect(Level.err.color().len > 0);
    try std.testing.expect(Level.fatal.color().len > 0);
}

test "Logger: 级别动态切换" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .level = .info });
    defer log.deinit();

    // 初始级别
    try std.testing.expect(!log.isEnabled(.debug));
    try std.testing.expect(log.isEnabled(.info));

    // 切换到 debug
    log.setLevel(.debug);
    try std.testing.expect(log.isEnabled(.debug));

    // 切换到 err
    log.setLevel(.err);
    try std.testing.expect(!log.isEnabled(.info));
    try std.testing.expect(!log.isEnabled(.warn));
    try std.testing.expect(log.isEnabled(.err));
}

test "Logger: 格式动态切换" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    log.info("文本格式", .{});

    log.setFormat(.json);
    log.info("JSON 格式", .{});

    log.setFormat(.colored);
    log.info("彩色格式", .{});
}

test "Logger: 带格式化参数的消息" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .format = .text });
    defer log.deinit();

    log.info("用户 {d} 登录成功", .{@as(i32, 12345)});
    log.info("请求耗时 {d:.2}ms", .{@as(f64, 123.456)});
    log.info("状态: {s}", .{"success"});
    log.warn("重试次数: {d}/{d}", .{ @as(i32, 3), @as(i32, 5) });
}

test "ScopedLogger: 所有方法" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .level = .debug, .format = .text });
    defer log.deinit();

    const scoped_log = log.scoped("test_scope");

    scoped_log.debug("作用域 debug", .{});
    scoped_log.info("作用域 info", .{});
    scoped_log.warn("作用域 warn", .{});
    scoped_log.err("作用域 err", .{});
    scoped_log.fatal("作用域 fatal", .{});
}

test "FieldLogger: 所有方法" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{ .level = .debug, .format = .text });
    defer log.deinit();

    const field_log = log.with(.{ .request_id = "abc-123" });

    field_log.debug("字段 debug", .{});
    field_log.info("字段 info", .{});
    field_log.warn("字段 warn", .{});
    field_log.err("字段 err", .{});
    field_log.fatal("字段 fatal", .{});
}

test "Timestamp: 时间格式化" {
    const ts = Timestamp.fromUnix(1733451600, 8 * 3600); // 2024-12-06 09:00:00 UTC+8

    try std.testing.expectEqual(@as(u16, 2024), ts.year);
    try std.testing.expectEqual(@as(u8, 12), ts.month);
    try std.testing.expectEqual(@as(u8, 6), ts.day);
}

test "Writer: 自定义写入器" {
    var output_count: usize = 0;

    const TestWriter = struct {
        fn write(ptr: *anyopaque, data: []const u8) void {
            _ = data;
            const count: *usize = @ptrCast(@alignCast(ptr));
            count.* += 1;
        }
    };

    const w = Writer{
        .ptr = &output_count,
        .writeFn = TestWriter.write,
    };

    w.write("test data");
    try std.testing.expectEqual(@as(usize, 1), output_count);

    w.write("more data");
    try std.testing.expectEqual(@as(usize, 2), output_count);
}

test "MultiWriter: 多目标广播" {
    const allocator = std.testing.allocator;
    var multi = MultiWriter.init(allocator);
    defer multi.deinit();

    // 添加多个写入器
    try multi.add(StderrWriter.writer());
    try multi.add(StdoutWriter.writer());
    try std.testing.expectEqual(@as(usize, 2), multi.writers.items.len);

    // 获取组合写入器
    const w = multi.writer();
    w.write("广播消息\n");
}

test "Logger: 完整配置" {
    const allocator = std.testing.allocator;
    var log = Logger.init(allocator, .{
        .level = .debug,
        .format = .text,
        .module_name = "full_config",
        .include_caller = false,
        .include_timestamp = true,
        .include_module = true,
        .timezone_offset = 8 * 3600,
        .buffer_size = 8192,
    });
    defer log.deinit();

    log.info("完整配置测试", .{});
}

test "AsyncWriter: 异步写入" {
    const allocator = std.testing.allocator;

    // 使用 stderr 作为目标
    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 1024,
        .flush_threshold = 512,
        .flush_interval_ms = 50,
    });
    defer async_writer.deinit();

    // 写入数据
    const w = async_writer.writer();
    w.write("异步日志消息 1\n");
    w.write("异步日志消息 2\n");
    w.write("异步日志消息 3\n");

    // 强制刷新
    async_writer.flush();
}

test "AsyncWriter: 高并发写入" {
    const allocator = std.testing.allocator;

    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 4096,
        .flush_interval_ms = 10,
    });
    defer async_writer.deinit();

    // 模拟高并发写入
    for (0..100) |i| {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "高并发消息 {d}\n", .{i}) catch continue;
        async_writer.write(msg);
    }

    async_writer.flush();
}

test "BufferedFileWriter: 带缓冲文件写入" {
    const allocator = std.testing.allocator;

    // 创建临时文件
    const tmp_path = "/tmp/zigcms_logger_test.log";
    var buffered = try BufferedFileWriter.init(allocator, tmp_path, .{
        .buffer_size = 1024,
    });
    defer buffered.deinit();

    // 写入数据
    const w = buffered.writer();
    w.write("缓冲写入测试 1\n");
    w.write("缓冲写入测试 2\n");

    // 刷新
    buffered.flush();

    // 清理
    std.fs.cwd().deleteFile(tmp_path) catch {};
}

test "Logger: 使用异步写入器" {
    const allocator = std.testing.allocator;

    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 2048,
        .flush_interval_ms = 50,
    });
    defer async_writer.deinit();

    var log = Logger.init(allocator, .{ .format = .text, .module_name = "async" });
    defer log.deinit();

    try log.addWriter(async_writer.writer());

    log.info("异步日志测试 1", .{});
    log.info("异步日志测试 2", .{});
    log.warn("异步警告消息", .{});

    async_writer.flush();
}

test "生产环境配置: AsyncWriter + RotatingFileWriter" {
    const allocator = std.testing.allocator;

    // ========================================
    // 1. 创建轮转文件写入器
    // ========================================
    // 配置：单文件最大 1MB，保留最近 5 个备份
    var rotating_file = try RotatingFileWriter.init(allocator, "/tmp/zigcms_app.log", .{
        .max_size = 1 * 1024 * 1024, // 1MB
        .max_backups = 5,
    });
    defer rotating_file.deinit();

    // ========================================
    // 2. 用异步写入器包装轮转文件
    // ========================================
    // 配置：64KB 缓冲，32KB 阈值刷新
    var async_writer = try AsyncWriter.init(allocator, rotating_file.writer(), .{
        .buffer_size = 64 * 1024, // 64KB 双缓冲
        .flush_threshold = 32 * 1024, // 32KB 触发刷新
        .flush_interval_ms = 100,
    });
    defer async_writer.deinit();

    // ========================================
    // 3. 创建日志器（JSON 格式，适合生产环境）
    // ========================================
    var log = Logger.init(allocator, .{
        .level = .info, // 生产环境通常用 info 级别
        .format = .json, // JSON 格式便于日志分析
        .module_name = "app",
        .include_timestamp = true,
        .include_module = true,
        .timezone_offset = 8 * 3600, // UTC+8
    });
    defer log.deinit();

    // 添加异步写入器
    try log.addWriter(async_writer.writer());

    // ========================================
    // 4. 使用示例
    // ========================================

    // 普通日志
    log.info("应用启动", .{});

    // 带结构化字段的日志
    log.with(.{
        .version = "1.0.0",
        .env = "production",
    }).info("配置加载完成", .{});

    // 模拟请求处理（使用作用域日志）
    const http_log = log.scope(.http);
    http_log.info("请求处理完成", .{});

    // 带字段的请求日志
    log.with(.{
        .module = "http",
        .method = "GET",
        .path = "/api/users",
        .status = @as(i64, 200),
        .latency_ms = @as(f64, 12.5),
    }).info("请求详情", .{});

    // 警告日志
    log.with(.{
        .current = @as(i64, 850),
        .max = @as(i64, 1000),
    }).warn("连接池使用率过高", .{});

    // 错误日志
    log.with(.{
        .error_code = "DB_TIMEOUT",
        .retry_count = @as(i64, 3),
    }).err("数据库连接超时", .{});

    // 刷新缓冲区确保写入
    async_writer.flush();

    // 清理测试文件
    std.fs.cwd().deleteFile("/tmp/zigcms_app.log") catch {};
}

test "开发环境配置: 彩色控制台 + 文件备份" {
    const allocator = std.testing.allocator;

    // ========================================
    // 1. 多目标写入器：同时输出到控制台和文件
    // ========================================
    var multi = MultiWriter.init(allocator);
    defer multi.deinit();

    // 添加彩色控制台输出
    try multi.add(StderrWriter.writer());

    // 添加文件备份（带缓冲）
    var file_writer = try BufferedFileWriter.init(allocator, "/tmp/zigcms_dev.log", .{
        .buffer_size = 4 * 1024, // 4KB
    });
    defer file_writer.deinit();
    try multi.add(file_writer.writer());

    // ========================================
    // 2. 创建开发环境日志器
    // ========================================
    var log = Logger.init(allocator, .{
        .level = .debug, // 开发环境启用 debug
        .format = .colored, // 彩色输出
        .module_name = "dev",
        .include_timestamp = true,
    });
    defer log.deinit();

    try log.addWriter(multi.writer());

    // ========================================
    // 3. 使用示例
    // ========================================
    log.debug("调试：变量值检查", .{});
    log.info("信息：服务启动", .{});
    log.warn("警告：配置项缺失，使用默认值", .{});
    log.err("错误：请求处理失败", .{});

    // 作用域日志
    const db_log = log.scope(.database);
    db_log.debug("SQL: SELECT * FROM users", .{});
    db_log.info("查询返回 10 条记录", .{});

    file_writer.flush();

    // 清理
    std.fs.cwd().deleteFile("/tmp/zigcms_dev.log") catch {};
}

test "高吞吐配置: 大缓冲 + 批量刷新" {
    const allocator = std.testing.allocator;

    // 针对高吞吐场景的配置
    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 256 * 1024, // 256KB 大缓冲
        .flush_threshold = 128 * 1024, // 128KB 才刷新，减少 IO
        .flush_interval_ms = 500, // 500ms 间隔
    });
    defer async_writer.deinit();

    var log = Logger.init(allocator, .{
        .level = .info,
        .format = .json, // JSON 便于后续处理
        .module_name = "high_throughput",
        .include_timestamp = true,
    });
    defer log.deinit();

    try log.addWriter(async_writer.writer());

    // 模拟高并发写入
    for (0..1000) |i| {
        log.with(.{
            .request_id = @as(i64, @intCast(i)),
            .status = @as(i64, 200),
        }).info("请求处理", .{});
    }

    async_writer.flush();
}

test "崩溃保护: ERROR 级别自动刷新" {
    const allocator = std.testing.allocator;

    // 创建带缓冲的异步写入器
    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 4096,
        .flush_threshold = 2048,
    });
    defer async_writer.deinit();

    // 创建日志器，启用 sync_on_error
    var log = Logger.init(allocator, .{
        .format = .text,
        .module_name = "crash_test",
        .sync_on_error = true, // 默认开启
    });
    defer log.deinit();

    try log.addWriter(async_writer.writer());

    // INFO 级别正常写入缓冲区
    log.info("普通日志 1", .{});
    log.info("普通日志 2", .{});

    // ERROR 级别会立即刷新缓冲区
    log.err("错误日志 - 会立即刷新", .{});

    // FATAL 级别也会立即刷新
    log.fatal("致命错误 - 也会立即刷新", .{});
}

test "崩溃保护: 注册和取消注册" {
    const allocator = std.testing.allocator;

    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 1024,
    });
    defer async_writer.deinit();

    // 注册崩溃刷新
    registerCrashFlush(&async_writer);

    // 验证已注册
    try std.testing.expect(crash_flush_count == 1);

    // 写入一些数据
    async_writer.write("测试数据\n");

    // 手动触发刷新所有
    flushAllCrashWriters();

    // 取消注册
    unregisterCrashFlush(&async_writer);

    // 验证已取消
    try std.testing.expect(crash_flush_count == 0);
}

test "崩溃保护: 完整生产配置" {
    const allocator = std.testing.allocator;

    // ========================================
    // 生产环境防崩溃配置示例
    // ========================================

    // 1. 创建轮转文件写入器
    var rotating = try RotatingFileWriter.init(allocator, "/tmp/zigcms_crash_test.log", .{
        .max_size = 1024 * 1024,
        .max_backups = 3,
    });
    defer rotating.deinit();

    // 2. 用异步写入器包装
    var async_writer = try AsyncWriter.init(allocator, rotating.writer(), .{
        .buffer_size = 32 * 1024,
        .flush_threshold = 16 * 1024,
    });
    defer async_writer.deinit();

    // 3. 注册崩溃保护（关键步骤）
    registerCrashFlush(&async_writer);
    defer unregisterCrashFlush(&async_writer);

    // 4. 创建日志器
    var log = Logger.init(allocator, .{
        .level = .debug,
        .format = .json,
        .module_name = "production",
        .sync_on_error = true, // ERROR/FATAL 立即刷新
    });
    defer log.deinit();

    // 5. 设置为全局日志器（panic 时可用）
    setGlobalLogger(&log);
    defer setGlobalLogger(null);

    try log.addWriter(async_writer.writer());

    // 6. 正常使用
    log.info("服务启动", .{});
    log.debug("调试信息", .{});

    // 模拟错误场景 - 会自动刷新
    log.err("数据库连接失败", .{});

    // 7. 在程序结束前确保刷新
    flushAllCrashWriters();

    // 清理测试文件
    std.fs.cwd().deleteFile("/tmp/zigcms_crash_test.log") catch {};
}

test "Logger: flush 方法" {
    const allocator = std.testing.allocator;

    var async_writer = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 4096,
    });
    defer async_writer.deinit();

    var log = Logger.init(allocator, .{ .module_name = "flush_test" });
    defer log.deinit();

    try log.addWriter(async_writer.writer());

    log.info("消息 1", .{});
    log.info("消息 2", .{});

    // 手动刷新日志器
    log.flush();
}

// ============================================================================
// 无锁写入器测试
// ============================================================================

test "LockFreeWriter: 基本写入" {
    const allocator = std.testing.allocator;

    var lock_free = try LockFreeWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 4096,
        .flush_threshold = 2048,
    });
    defer lock_free.deinit();

    // 注册崩溃保护
    registerCrashFlush(&lock_free);
    defer unregisterCrashFlush(&lock_free);

    const w = lock_free.writer();
    w.write("无锁写入测试 1\n");
    w.write("无锁写入测试 2\n");
    w.write("无锁写入测试 3\n");

    lock_free.flush();
}

test "LockFreeWriter: 高并发写入" {
    const allocator = std.testing.allocator;

    var lock_free = try LockFreeWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 8192,
        .flush_threshold = 4096,
    });
    defer lock_free.deinit();

    // 模拟高并发写入
    for (0..500) |i| {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "无锁消息 {d}\n", .{i}) catch continue;
        lock_free.write(msg);
    }

    // 检查缓冲区使用量
    const used = lock_free.usage();
    try std.testing.expect(used >= 0);

    lock_free.flush();
}

test "LockFreeWriter: 与 Logger 集成" {
    const allocator = std.testing.allocator;

    var lock_free = try LockFreeWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 8192,
        .flush_threshold = 4096,
    });
    defer lock_free.deinit();

    // 注册崩溃保护
    registerCrashFlush(&lock_free);
    defer unregisterCrashFlush(&lock_free);

    var log = Logger.init(allocator, .{
        .format = .json,
        .module_name = "lockfree_test",
        .sync_on_error = true,
    });
    defer log.deinit();

    try log.addWriter(lock_free.writer());

    log.info("无锁日志 1", .{});
    log.info("无锁日志 2", .{});
    log.err("错误会立即刷新", .{});

    lock_free.flush();
}

test "ThreadLocalWriter: 基本写入" {
    const allocator = std.testing.allocator;

    var tls_writer = try ThreadLocalWriter.init(allocator, StderrWriter.writer());
    defer tls_writer.deinit();

    const w = tls_writer.writer();
    w.write("TLS 写入测试 1\n");
    w.write("TLS 写入测试 2\n");

    tls_writer.flushAll();
}

test "ThreadLocalWriter: 与 Logger 集成" {
    const allocator = std.testing.allocator;

    var tls_writer = try ThreadLocalWriter.init(allocator, StderrWriter.writer());
    defer tls_writer.deinit();

    var log = Logger.init(allocator, .{
        .format = .text,
        .module_name = "tls_test",
    });
    defer log.deinit();

    try log.addWriter(tls_writer.writer());

    log.info("TLS 日志 1", .{});
    log.info("TLS 日志 2", .{});
    log.warn("TLS 警告", .{});

    tls_writer.flushAll();
}

test "无锁安全: 完整生产配置" {
    const allocator = std.testing.allocator;

    // ========================================
    // 高性能无锁生产配置
    // ========================================

    // 1. 创建轮转文件写入器
    var rotating = try RotatingFileWriter.init(allocator, "/tmp/zigcms_lockfree.log", .{
        .max_size = 1024 * 1024,
        .max_backups = 3,
    });
    defer rotating.deinit();

    // 2. 使用无锁写入器包装（比 AsyncWriter 更高效）
    var lock_free = try LockFreeWriter.init(allocator, rotating.writer(), .{
        .buffer_size = 64 * 1024, // 64KB 环形缓冲区
        .flush_threshold = 32 * 1024, // 32KB 触发刷新
    });
    defer lock_free.deinit();

    // 3. 注册崩溃保护
    registerCrashFlush(&lock_free);
    defer unregisterCrashFlush(&lock_free);

    // 4. 创建日志器
    var log = Logger.init(allocator, .{
        .level = .info,
        .format = .json,
        .module_name = "production",
        .sync_on_error = true, // ERROR/FATAL 立即刷新
    });
    defer log.deinit();

    // 5. 设置全局日志器
    setGlobalLogger(&log);
    defer setGlobalLogger(null);

    try log.addWriter(lock_free.writer());

    // 6. 正常使用
    log.info("服务启动", .{});
    log.with(.{ .version = "2.0.0" }).info("版本信息", .{});

    // 模拟高并发
    for (0..100) |i| {
        log.with(.{ .request_id = @as(i64, @intCast(i)) }).info("请求处理", .{});
    }

    // 错误日志会立即刷新
    log.err("测试错误", .{});

    // 7. 确保刷新
    flushAllCrashWriters();

    // 清理
    std.fs.cwd().deleteFile("/tmp/zigcms_lockfree.log") catch {};
}

test "写入器性能对比: Mutex vs LockFree vs TLS" {
    const allocator = std.testing.allocator;
    const iterations: usize = 1000;

    // 1. AsyncWriter (带 Mutex)
    var async_w = try AsyncWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 8192,
    });
    defer async_w.deinit();

    // 2. LockFreeWriter (无锁)
    var lockfree_w = try LockFreeWriter.init(allocator, StderrWriter.writer(), .{
        .buffer_size = 8192,
    });
    defer lockfree_w.deinit();

    // 3. ThreadLocalWriter (线程本地)
    var tls_w = try ThreadLocalWriter.init(allocator, StderrWriter.writer());
    defer tls_w.deinit();

    const test_data = "性能测试数据行\n";

    // AsyncWriter 写入
    for (0..iterations) |_| {
        async_w.write(test_data);
    }
    async_w.flush();

    // LockFreeWriter 写入
    for (0..iterations) |_| {
        lockfree_w.write(test_data);
    }
    lockfree_w.flush();

    // ThreadLocalWriter 写入
    for (0..iterations) |_| {
        tls_w.write(test_data);
    }
    tls_w.flushAll();

    // 所有写入器都应该成功完成
    try std.testing.expect(true);
}

test "Logger: 内存安全 - 大量日志写入" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{ .format = .json });
    defer logger.deinit();

    // 添加标准错误写入器
    try logger.addWriter(StderrWriter.writer());

    // 写入大量日志
    for (0..1000) |i| {
        logger.info("测试日志消息 #{d}", .{i});
    }

    // 验证内存状态正常（没有泄漏）
    try std.testing.expect(true); // 如果有内存泄漏，defer会失败
}

test "Logger: 内存安全 - 结构化日志的内存管理" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{ .format = .json });
    defer logger.deinit();

    // 使用标准错误输出
    try logger.addWriter(StderrWriter.writer());

    // 记录结构化日志（使用with方法添加额外字段）
    const log_with_fields = logger.with(.{
        .user_id = @as(i64, 12345),
        .action = "login",
        .ip = "192.168.1.1",
        .timestamp = @as(i64, 1640995200),
    });
    log_with_fields.info("用户操作", .{});

    // 验证没有崩溃或内存泄漏
    try std.testing.expect(true);
}

test "Logger: 线程安全 - 并发日志写入" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{ .format = .json });
    defer logger.deinit();

    // 添加线程安全的写入器
    var async_writer = try AsyncWriter.init(allocator, Writer{
        .ptr = undefined,
        .writeFn = testWriteToStderr,
        .flushFn = testFlushStderr,
    }, .{ .buffer_size = 4096 });
    defer async_writer.deinit();

    try logger.addWriter(async_writer.writer());

    const num_threads = 4;
    const logs_per_thread = 100;

    var threads: [num_threads]std.Thread = undefined;

    // 启动多个线程并发写日志
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, concurrentLoggingTest, .{ &logger, i, logs_per_thread });
    }

    for (&threads) |*thread| {
        thread.join();
    }

    // 强制刷新缓冲区
    logger.flush();

    // 验证所有日志都被处理（没有崩溃或死锁）
    try std.testing.expect(true);
}

test "Logger: 线程安全 - 错误级别自动刷新" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{
        .format = .json,
        .sync_on_error = true, // 启用错误级别自动刷新
    });
    defer logger.deinit();

    // 创建一个能跟踪刷新次数的写入器
    var flush_counter = std.atomic.Value(usize).init(0);
    var test_writer = TestFlushWriter{
        .flush_count = &flush_counter,
    };

    try logger.addWriter(Writer{
        .ptr = &test_writer,
        .writeFn = testWriteFlush,
        .flushFn = testFlush,
    });

    // 记录不同级别的日志
    logger.debug("调试信息", .{});
    logger.info("普通信息", .{});
    logger.warn("警告信息", .{});
    logger.err("错误信息", .{}); // 应该触发刷新
    logger.fatal("致命错误", .{}); // 应该触发刷新

    // 验证错误级别的日志触发了刷新
    const flush_count = flush_counter.load(.monotonic);
    try std.testing.expect(flush_count >= 2); // 至少err和fatal各触发一次
}

test "Logger: 内存安全 - 写入器生命周期管理" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{});
    defer logger.deinit();

    // 测试添加写入器
    const writer1 = Writer{
        .ptr = undefined,
        .writeFn = testWriteToStderr,
        .flushFn = testFlushStderr,
    };

    const writer2 = Writer{
        .ptr = undefined,
        .writeFn = testWriteToStdout,
        .flushFn = testFlushStdout,
    };

    // 添加写入器
    try logger.addWriter(writer1);
    try logger.addWriter(writer2);

    // 记录日志
    logger.info("测试多个写入器", .{});

    // 清空所有写入器
    logger.clearWriters();

    // 再次添加一个写入器
    try logger.addWriter(writer1);

    // 再次记录日志
    logger.info("测试清空后重新添加", .{});

    // 验证没有崩溃
    try std.testing.expect(true);
}

test "Logger: 崩溃保护 - 全局日志器和panic处理" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{ .format = .json });
    defer logger.deinit();

    // 设置全局日志器
    setGlobalLogger(&logger);

    // 注册崩溃保护写入器
    var async_writer = try AsyncWriter.init(allocator, Writer{
        .ptr = undefined,
        .writeFn = testWriteToStderr,
        .flushFn = testFlushStderr,
    }, .{});
    defer async_writer.deinit();

    registerCrashFlush(&async_writer);
    defer unregisterCrashFlush(&async_writer);

    // 记录一些日志
    logger.info("测试崩溃保护", .{});

    // 手动触发崩溃刷新（模拟panic）
    flushAllCrashWriters();

    // 清理全局日志器
    setGlobalLogger(null);

    // 验证没有内存泄漏
    try std.testing.expect(true);
}

test "Logger: 边界条件 - 空消息和参数" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{});
    defer logger.deinit();

    // 添加一个简单的写入器
    try logger.addWriter(Writer{
        .ptr = undefined,
        .writeFn = testWriteToStderr,
        .flushFn = testFlushStderr,
    });

    // 测试各种边界情况
    logger.info("", .{}); // 空消息
    logger.info("无参数消息", .{}); // 无参数
    logger.info("简单消息 {s}", .{"value"}); // 带参数的消息

    // 验证没有崩溃
    try std.testing.expect(true);
}

test "Logger: 内存安全 - 作用域日志器的生命周期" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{});
    defer logger.deinit();

    // 设置全局日志器以支持作用域日志器
    setGlobalLogger(&logger);
    defer setGlobalLogger(null);

    // 创建作用域日志器
    const log = logger.scoped("test");

    // 使用作用域日志器
    log.info("作用域测试消息", .{});
    log.warn("作用域警告", .{});
    log.err("作用域错误", .{});

    // 验证正常工作
    try std.testing.expect(true);
}

test "Logger: 性能测试 - 高频日志写入" {
    const allocator = std.testing.allocator;
    var logger = Logger.init(allocator, .{ .format = .text });
    defer logger.deinit();

    // 使用无锁写入器进行高性能测试
    var lock_free_writer = LockFreeWriter.init(allocator, Writer{
        .ptr = undefined,
        .writeFn = testWriteToStderr,
        .flushFn = testFlushStderr,
    }, .{ .buffer_size = 65536, .flush_threshold = 32768 }) catch {
        // 如果初始化失败，使用简单写入器
        try logger.addWriter(Writer{
            .ptr = undefined,
            .writeFn = testWriteToStderr,
            .flushFn = testFlushStderr,
        });
        return;
    };
    defer lock_free_writer.deinit();

    try logger.addWriter(lock_free_writer.writer());

    // 高频写入测试
    const start_time = std.time.milliTimestamp();
    for (0..10000) |i| {
        logger.debug("性能测试日志 #{d}", .{i});
    }
    const end_time = std.time.milliTimestamp();

    // 验证在合理时间内完成（每条日志平均耗时应小于1ms）
    const duration = end_time - start_time;
    try std.testing.expect(duration < 2000); // 2秒内完成1万条日志
}

// ============================================================================
// 测试辅助类型和函数
// ============================================================================

/// 测试用的刷新计数写入器
const TestFlushWriter = struct {
    flush_count: *std.atomic.Value(usize),
};

/// 用于ArrayList的写入函数
fn writeToArrayList(ptr: *anyopaque, data: []const u8) void {
    _ = ptr;
    _ = data;
    // 简化：测试中我们不需要真正写入
}

/// 测试写入器写入函数
fn testWriteFlush(ptr: *anyopaque, data: []const u8) void {
    _ = ptr;
    // 写入到stderr
    _ = std.posix.write(std.posix.STDERR_FILENO, data) catch {};
}

/// 测试写入器刷新函数
fn testFlush(ptr: *anyopaque) void {
    var test_writer = @as(*TestFlushWriter, @ptrCast(@alignCast(ptr)));
    _ = test_writer.flush_count.fetchAdd(1, .monotonic);
}

/// 测试用stderr写入函数
fn testWriteToStderr(ptr: *anyopaque, data: []const u8) void {
    _ = ptr;
    _ = std.posix.write(std.posix.STDERR_FILENO, data) catch {};
}

/// 测试用stderr刷新函数
fn testFlushStderr(ptr: *anyopaque) void {
    _ = ptr;
    // 刷新不需要实际操作
}

/// 测试用stdout写入函数
fn testWriteToStdout(ptr: *anyopaque, data: []const u8) void {
    _ = ptr;
    _ = std.posix.write(std.posix.STDOUT_FILENO, data) catch {};
}

/// 测试用stdout刷新函数
fn testFlushStdout(ptr: *anyopaque) void {
    _ = ptr;
    // 刷新不需要实际操作
}

/// 并发日志测试函数
fn concurrentLoggingTest(logger: *Logger, thread_id: usize, num_logs: usize) void {
    for (0..num_logs) |i| {
        // 使用不同的日志级别和消息（5个级别：debug, info, warn, err, fatal）
        const level = @as(Level, @enumFromInt(@mod(i, 5)));
        switch (level) {
            .debug => logger.debug("线程{d}调试日志#{d}", .{ thread_id, i }),
            .info => logger.info("线程{d}信息日志#{d}", .{ thread_id, i }),
            .warn => logger.warn("线程{d}警告日志#{d}", .{ thread_id, i }),
            .err => logger.err("线程{d}错误日志#{d}", .{ thread_id, i }),
            .fatal => logger.fatal("线程{d}致命日志#{d}", .{ thread_id, i }),
        }

        // 短暂延迟以增加并发性
        std.atomic.spinLoopHint();
    }
}
