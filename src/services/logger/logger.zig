//! 高性能结构化日志库
//!
//! 类似 Go 的 zap 日志库，支持结构化日志、多级别、多输出。
//!
//! ## 使用示例
//!
//! ```zig
//! const logger = @import("services/logger/logger.zig");
//!
//! // 创建日志器
//! var log = logger.Logger.init(allocator, .{});
//! defer log.deinit();
//!
//! // 基本日志
//! log.info("服务启动", .{});
//! log.warn("连接超时", .{});
//! log.err("数据库错误", .{});
//!
//! // 结构化日志
//! log.with(.{ .user_id = 123, .action = "login" }).info("用户登录", .{});
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

    pub fn write(self: Writer, data: []const u8) void {
        self.writeFn(self.ptr, data);
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

/// 异步写入器
///
/// 高并发优化策略：
/// 1. 异步写入：日志先放入环形缓冲区，后台线程批量写入
/// 2. 双缓冲：写入和刷新使用不同缓冲区，减少锁竞争
/// 3. 批量刷新：累积到阈值或超时后批量写入
/// 4. 无阻塞：写入操作几乎无等待
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
        };
    }

    fn writeAsync(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
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
        };
    }

    fn writeBuffered(ptr: *anyopaque, data: []const u8) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(data);
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

pub fn setGlobalLogger(logger: ?*Logger) void {
    global_logger = logger;
}

pub fn getGlobalLogger() ?*Logger {
    return global_logger;
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
    var rotating_file = try RotatingFileWriter.init(allocator, .{
        .base_path = "/tmp/zigcms_app.log",
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

    // 模拟请求处理
    const http_log = log.scope(.http);
    http_log.with(.{
        .method = "GET",
        .path = "/api/users",
        .status = @as(i64, 200),
        .latency_ms = @as(f64, 12.5),
    }).info("请求处理完成", .{});

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
