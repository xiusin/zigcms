//! 错误处理抽象层
//!
//! 提供类似Go的error接口，支持：
//! - 携带详细错误信息
//! - 错误码
//! - 错误链（wrap/unwrap）
//! - 堆栈跟踪（可选）
//!
//! ## 使用示例
//!
//! ```zig
//! const errors = @import("application/services/errors/errors.zig");
//!
//! // 创建简单错误
//! const err = errors.new("数据库连接失败");
//!
//! // 创建带错误码的错误
//! const err2 = errors.newWithCode(1001, "用户不存在");
//!
//! // 包装已有错误
//! const wrapped = errors.wrap(underlying_err, "处理用户请求时出错");
//!
//! // 格式化错误
//! const err3 = errors.fmt(allocator, "用户 {d} 不存在", .{user_id});
//!
//! // 获取错误信息
//! const msg = err.message();
//!
//! // 解包错误链
//! if (err.unwrap()) |cause| {
//!     // 处理原始错误
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 错误上下文，存储详细错误信息
pub const Error = struct {
    /// 错误消息
    msg: []const u8,
    /// 错误码（可选）
    code: ?i32 = null,
    /// 原始错误（用于错误链）
    cause: ?*const Error = null,
    /// 源文件
    source_file: ?[]const u8 = null,
    /// 源代码行号
    source_line: ?u32 = null,
    /// 函数名
    source_fn: ?[]const u8 = null,
    /// 额外上下文信息
    context: ?std.StringHashMap([]const u8) = null,
    /// 内存分配器（用于释放）
    allocator: ?Allocator = null,
    /// 是否拥有消息内存
    owns_message: bool = false,

    /// 获取错误消息
    pub fn message(self: *const Error) []const u8 {
        return self.msg;
    }

    /// 获取错误码
    pub fn getCode(self: *const Error) ?i32 {
        return self.code;
    }

    /// 解包错误链，获取原始错误
    pub fn unwrap(self: *const Error) ?*const Error {
        return self.cause;
    }

    /// 获取根因错误
    pub fn rootCause(self: *const Error) *const Error {
        var current = self;
        while (current.cause) |c| {
            current = c;
        }
        return current;
    }

    /// 检查错误链中是否包含指定错误码
    pub fn hasCode(self: *const Error, code: i32) bool {
        var current: ?*const Error = self;
        while (current) |c| {
            if (c.code) |ec| {
                if (ec == code) return true;
            }
            current = c.cause;
        }
        return false;
    }

    /// 获取上下文值
    pub fn getContext(self: *const Error, key: []const u8) ?[]const u8 {
        if (self.context) |ctx| {
            return ctx.get(key);
        }
        return null;
    }

    /// 格式化完整错误信息（包括错误链）
    pub fn format(self: *const Error, allocator: Allocator) ![]u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 128);
        errdefer buf.deinit(allocator);

        try self.formatTo(&buf, allocator);
        return buf.toOwnedSlice(allocator);
    }

    /// 格式化错误到缓冲区
    fn formatTo(self: *const Error, buf: *std.ArrayList(u8), allocator: Allocator) !void {
        // 错误码
        if (self.code) |c| {
            try buf.writer(allocator).print("[{d}] ", .{c});
        }

        // 消息
        try buf.appendSlice(allocator, self.msg);

        // 源位置
        if (self.source_file) |file| {
            try buf.writer(allocator).print(" (at {s}", .{file});
            if (self.source_line) |line| {
                try buf.writer(allocator).print(":{d}", .{line});
            }
            if (self.source_fn) |func| {
                try buf.writer(allocator).print(" in {s}", .{func});
            }
            try buf.appendSlice(allocator, ")");
        }

        // 错误链
        if (self.cause) |c| {
            try buf.appendSlice(allocator, "\n  caused by: ");
            try c.formatTo(buf, allocator);
        }
    }

    /// 释放错误资源
    pub fn deinit(self: *Error) void {
        if (self.allocator) |alloc| {
            if (self.owns_message) {
                alloc.free(self.msg);
            }
            if (self.context) |*ctx| {
                ctx.deinit();
            }
        }
    }
};

/// 错误构建器，支持链式调用
pub const ErrorBuilder = struct {
    err: Error,
    allocator: Allocator,

    /// 设置错误码
    pub fn withCode(self: *ErrorBuilder, code: i32) *ErrorBuilder {
        self.err.code = code;
        return self;
    }

    /// 设置原始错误
    pub fn withCause(self: *ErrorBuilder, cause: *const Error) *ErrorBuilder {
        self.err.cause = cause;
        return self;
    }

    /// 添加上下文信息
    pub fn withContext(self: *ErrorBuilder, key: []const u8, value: []const u8) *ErrorBuilder {
        if (self.err.context == null) {
            self.err.context = std.StringHashMap([]const u8).init(self.allocator);
        }
        if (self.err.context) |*ctx| {
            ctx.put(key, value) catch {};
        }
        return self;
    }

    /// 设置源位置
    pub fn withSource(self: *ErrorBuilder, file: []const u8, line: u32, func: []const u8) *ErrorBuilder {
        self.err.source_file = file;
        self.err.source_line = line;
        self.err.source_fn = func;
        return self;
    }

    /// 构建错误
    pub fn build(self: *ErrorBuilder) Error {
        return self.err;
    }

    /// 构建并返回指针（分配在堆上）
    pub fn buildHeap(self: *ErrorBuilder) !*Error {
        const ptr = try self.allocator.create(Error);
        ptr.* = self.err;
        ptr.allocator = self.allocator;
        return ptr;
    }
};

/// 线程局部错误存储
threadlocal var thread_error: ?Error = null;
threadlocal var thread_error_buf: [1024]u8 = undefined;

/// 设置线程局部错误
pub fn setThreadError(e: Error) void {
    thread_error = e;
}

/// 获取线程局部错误
pub fn getThreadError() ?*Error {
    if (thread_error) |*e| {
        return e;
    }
    return null;
}

/// 清除线程局部错误
pub fn clearThreadError() void {
    thread_error = null;
}

// ========================================
// 与Zig原生错误系统集成
// ========================================

/// 通用错误类型，可与try一起使用
pub const ZigError = error{
    /// 通用错误
    GenericError,
    /// 参数无效
    InvalidArgument,
    /// 未找到
    NotFound,
    /// 已存在
    AlreadyExists,
    /// 权限拒绝
    PermissionDenied,
    /// 超时
    Timeout,
    /// 数据库错误
    DatabaseError,
    /// 网络错误
    NetworkError,
    /// Redis错误
    RedisError,
    /// API错误
    ApiError,
    /// 业务错误
    BusinessError,
    /// 内存不足
    OutOfMemory,
};

/// Result类型，类似Rust的Result<T, E>
pub fn Result(comptime T: type) type {
    return union(enum) {
        success: T,
        failure: Error,

        const Self = @This();

        /// 检查是否成功
        pub fn isOk(self: Self) bool {
            return self == .success;
        }

        /// 检查是否失败
        pub fn isErr(self: Self) bool {
            return self == .failure;
        }

        /// 获取成功值，失败时返回null
        pub fn getValue(self: Self) ?T {
            return switch (self) {
                .success => |v| v,
                .failure => null,
            };
        }

        /// 获取错误，成功时返回null
        pub fn getError(self: Self) ?Error {
            return switch (self) {
                .success => null,
                .failure => |e| e,
            };
        }

        /// 解包成功值，失败时panic
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .success => |v| v,
                .failure => |e| @panic(e.msg),
            };
        }

        /// 解包成功值，失败时返回默认值
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .success => |v| v,
                .failure => default,
            };
        }

        /// 转换为Zig error union，同时保存详细错误到线程局部存储
        pub fn tryUnwrap(self: Self) ZigError!T {
            return switch (self) {
                .success => |v| v,
                .failure => |e| {
                    setThreadError(e);
                    return mapToZigError(e.code);
                },
            };
        }
    };
}

/// 将错误码映射到Zig错误
pub fn mapToZigError(code: ?i32) ZigError {
    if (code) |c| {
        return switch (c) {
            ErrorCode.InvalidArgument => ZigError.InvalidArgument,
            ErrorCode.NotFound, ErrorCode.RecordNotFound, ErrorCode.UserNotFound => ZigError.NotFound,
            ErrorCode.AlreadyExists, ErrorCode.DuplicateKey => ZigError.AlreadyExists,
            ErrorCode.PermissionDenied => ZigError.PermissionDenied,
            ErrorCode.Timeout, ErrorCode.NetworkTimeout, ErrorCode.RedisTimeout => ZigError.Timeout,
            ErrorCode.DatabaseConnection, ErrorCode.DatabaseQuery, ErrorCode.DatabaseTransaction => ZigError.DatabaseError,
            ErrorCode.NetworkConnection, ErrorCode.NetworkDns => ZigError.NetworkError,
            ErrorCode.RedisConnection, ErrorCode.RedisCommand => ZigError.RedisError,
            ErrorCode.ApiRequest, ErrorCode.ApiResponse, ErrorCode.ApiAuth, ErrorCode.ApiRateLimit => ZigError.ApiError,
            ErrorCode.UserDisabled, ErrorCode.InvalidPassword, ErrorCode.TokenExpired => ZigError.BusinessError,
            else => ZigError.GenericError,
        };
    }
    return ZigError.GenericError;
}

/// 抛出错误（设置线程局部错误并返回Zig错误）
pub fn throw(e: Error) ZigError {
    setThreadError(e);
    return mapToZigError(e.code);
}

/// 抛出简单错误
pub fn throwMsg(msg: []const u8) ZigError {
    return throw(new(msg));
}

/// 抛出带错误码的错误
pub fn throwWithCode(code: i32, msg: []const u8) ZigError {
    return throw(newWithCode(code, msg));
}

/// 捕获错误后获取详细信息的辅助函数
pub fn catch_info() ?*Error {
    return getThreadError();
}

// ========================================
// 通用错误支持（不需要预定义错误码）
// ========================================

/// 通用错误返回类型，可与任意Zig错误一起使用
pub fn Err(comptime E: type) type {
    return struct {
        zig_err: E,
        detail: Error,

        const Self = @This();

        /// 设置线程局部错误并返回Zig错误
        pub fn throw(self: Self) E {
            setThreadError(self.detail);
            return self.zig_err;
        }
    };
}

/// 创建通用错误（可与任意Zig错误类型配合）
pub fn make(comptime E: type, zig_err: E, msg: []const u8) Err(E) {
    return Err(E){
        .zig_err = zig_err,
        .detail = new(msg),
    };
}

/// 创建通用错误（带错误码）
pub fn makeWithCode(comptime E: type, zig_err: E, code: i32, msg: []const u8) Err(E) {
    return Err(E){
        .zig_err = zig_err,
        .detail = newWithCode(code, msg),
    };
}

/// 创建通用错误（包装已有错误）
pub fn makeWrap(comptime E: type, zig_err: E, cause: *const Error, msg: []const u8) Err(E) {
    return Err(E){
        .zig_err = zig_err,
        .detail = wrap(cause, msg),
    };
}

/// 直接抛出任意Zig错误并附带消息
pub fn raise(comptime E: type, zig_err: E, msg: []const u8) E {
    setThreadError(new(msg));
    return zig_err;
}

/// 直接抛出任意Zig错误并附带错误码和消息
pub fn raiseWithCode(comptime E: type, zig_err: E, code: i32, msg: []const u8) E {
    setThreadError(newWithCode(code, msg));
    return zig_err;
}

/// 包装Zig标准库错误并抛出
pub fn wrapZigError(comptime E: type, zig_err: E, msg: []const u8) E {
    const cause = fromZigError(zig_err);
    var wrapped = wrap(&cause, msg);
    wrapped.code = @intFromError(zig_err);
    setThreadError(wrapped);
    return zig_err;
}

/// 创建成功Result
pub fn ok(comptime T: type, value: T) Result(T) {
    return Result(T){ .success = value };
}

/// 创建失败Result
pub fn fail(comptime T: type, e: Error) Result(T) {
    return Result(T){ .failure = e };
}

/// 创建失败Result（简单消息）
pub fn failMsg(comptime T: type, msg: []const u8) Result(T) {
    return Result(T){ .failure = new(msg) };
}

/// 创建失败Result（带错误码）
pub fn failWithCode(comptime T: type, code: i32, msg: []const u8) Result(T) {
    return Result(T){ .failure = newWithCode(code, msg) };
}

/// 创建简单错误（栈上）
pub fn new(msg: []const u8) Error {
    return Error{
        .msg = msg,
    };
}

/// 创建带错误码的错误（栈上）
pub fn newWithCode(code: i32, msg: []const u8) Error {
    return Error{
        .msg = msg,
        .code = code,
    };
}

/// 包装已有错误
pub fn wrap(cause: *const Error, msg: []const u8) Error {
    return Error{
        .msg = msg,
        .cause = cause,
    };
}

/// 包装已有错误并添加错误码
pub fn wrapWithCode(cause: *const Error, code: i32, msg: []const u8) Error {
    return Error{
        .msg = msg,
        .code = code,
        .cause = cause,
    };
}

/// 创建错误构建器
pub fn builder(allocator: Allocator, msg: []const u8) ErrorBuilder {
    return ErrorBuilder{
        .err = Error{
            .msg = msg,
            .allocator = allocator,
        },
        .allocator = allocator,
    };
}

/// 格式化创建错误（堆分配）
pub fn fmt(allocator: Allocator, comptime format: []const u8, args: anytype) !*Error {
    const msg = try std.fmt.allocPrint(allocator, format, args);
    const err = try allocator.create(Error);
    err.* = Error{
        .msg = msg,
        .allocator = allocator,
        .owns_message = true,
    };
    return err;
}

/// 格式化创建错误并设置错误码
pub fn fmtWithCode(allocator: Allocator, code: i32, comptime format: []const u8, args: anytype) !*Error {
    const msg = try std.fmt.allocPrint(allocator, format, args);
    const err = try allocator.create(Error);
    err.* = Error{
        .msg = msg,
        .code = code,
        .allocator = allocator,
        .owns_message = true,
    };
    return err;
}

/// 释放堆分配的错误
pub fn free(allocator: Allocator, err: *Error) void {
    err.deinit();
    allocator.destroy(err);
}

/// 从Zig标准错误创建Error
pub fn fromZigError(zig_err: anyerror) Error {
    return Error{
        .msg = @errorName(zig_err),
        .code = @intFromError(zig_err),
    };
}

/// 带源位置的错误创建宏辅助
pub fn newWithLocation(msg: []const u8, src: std.builtin.SourceLocation) Error {
    return Error{
        .msg = msg,
        .source_file = src.file,
        .source_line = src.line,
        .source_fn = src.fn_name,
    };
}

/// 常用错误码定义
pub const ErrorCode = struct {
    // 通用错误 (1000-1999)
    pub const Unknown: i32 = 1000;
    pub const InvalidArgument: i32 = 1001;
    pub const NotFound: i32 = 1002;
    pub const AlreadyExists: i32 = 1003;
    pub const PermissionDenied: i32 = 1004;
    pub const Timeout: i32 = 1005;
    pub const Cancelled: i32 = 1006;

    // 数据库错误 (2000-2999)
    pub const DatabaseConnection: i32 = 2000;
    pub const DatabaseQuery: i32 = 2001;
    pub const DatabaseTransaction: i32 = 2002;
    pub const RecordNotFound: i32 = 2003;
    pub const DuplicateKey: i32 = 2004;

    // 网络错误 (3000-3999)
    pub const NetworkConnection: i32 = 3000;
    pub const NetworkTimeout: i32 = 3001;
    pub const NetworkDns: i32 = 3002;

    // Redis错误 (4000-4999)
    pub const RedisConnection: i32 = 4000;
    pub const RedisCommand: i32 = 4001;
    pub const RedisTimeout: i32 = 4002;

    // API错误 (5000-5999)
    pub const ApiRequest: i32 = 5000;
    pub const ApiResponse: i32 = 5001;
    pub const ApiAuth: i32 = 5002;
    pub const ApiRateLimit: i32 = 5003;

    // 业务错误 (6000-6999)
    pub const UserNotFound: i32 = 6000;
    pub const UserDisabled: i32 = 6001;
    pub const InvalidPassword: i32 = 6002;
    pub const TokenExpired: i32 = 6003;
};

// ========================================
// 测试
// ========================================

test "Error: 基本创建" {
    const err = new("测试错误");
    try std.testing.expectEqualStrings("测试错误", err.message());
    try std.testing.expect(err.code == null);
}

test "Error: 带错误码" {
    const err = newWithCode(1001, "用户不存在");
    try std.testing.expectEqualStrings("用户不存在", err.message());
    try std.testing.expectEqual(@as(?i32, 1001), err.code);
}

test "Error: 错误链" {
    const cause = new("原始错误");
    const wrapped = wrap(&cause, "包装错误");

    try std.testing.expectEqualStrings("包装错误", wrapped.message());
    try std.testing.expect(wrapped.unwrap() != null);
    try std.testing.expectEqualStrings("原始错误", wrapped.unwrap().?.message());
}

test "Error: 根因查找" {
    const root = new("根因错误");
    const mid = wrap(&root, "中间错误");
    const top = wrap(&mid, "顶层错误");

    const found_root = top.rootCause();
    try std.testing.expectEqualStrings("根因错误", found_root.message());
}

test "Error: 错误码检查" {
    const cause = newWithCode(2000, "数据库错误");
    const wrapped = wrapWithCode(&cause, 5000, "API错误");

    try std.testing.expect(wrapped.hasCode(5000));
    try std.testing.expect(wrapped.hasCode(2000));
    try std.testing.expect(!wrapped.hasCode(1000));
}

test "Error: 格式化创建" {
    const allocator = std.testing.allocator;
    const err = try fmt(allocator, "用户 {d} 不存在", .{123});
    defer free(allocator, err);

    try std.testing.expectEqualStrings("用户 123 不存在", err.message());
}

test "Error: 构建器模式" {
    const allocator = std.testing.allocator;
    var b = builder(allocator, "测试错误");
    const err = b.withCode(1001).withContext("user_id", "123").build();

    try std.testing.expectEqual(@as(?i32, 1001), err.code);
    try std.testing.expectEqualStrings("123", err.getContext("user_id").?);

    // 清理context
    if (err.context) |*ctx| {
        var ctx_copy = ctx.*;
        ctx_copy.deinit();
    }
}

test "Error: 从Zig错误转换" {
    const zig_err = error.OutOfMemory;
    const err = fromZigError(zig_err);

    try std.testing.expectEqualStrings("OutOfMemory", err.message());
    try std.testing.expect(err.code != null);
}

test "Error: 格式化输出" {
    const allocator = std.testing.allocator;

    const cause = newWithCode(2000, "数据库连接失败");
    const wrapped = wrapWithCode(&cause, 5000, "处理请求失败");

    const formatted = try wrapped.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "[5000]") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "处理请求失败") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "caused by") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "[2000]") != null);
}

test "Error: 线程局部错误" {
    const err = newWithCode(1001, "线程错误");
    setThreadError(err);

    const retrieved = getThreadError();
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqualStrings("线程错误", retrieved.?.message());

    clearThreadError();
    try std.testing.expect(getThreadError() == null);
}

test "Error: throw与try集成" {
    // 模拟函数抛出错误
    const doSomething = struct {
        fn call() ZigError!i32 {
            return throwWithCode(ErrorCode.UserNotFound, "用户123不存在");
        }
    }.call;

    // 使用try捕获错误
    const result = doSomething() catch |zig_err| {
        // 获取详细错误信息
        const detail = catch_info();
        try std.testing.expect(detail != null);
        try std.testing.expectEqualStrings("用户123不存在", detail.?.message());
        try std.testing.expectEqual(@as(?i32, ErrorCode.UserNotFound), detail.?.code);
        try std.testing.expectEqual(ZigError.NotFound, zig_err);
        clearThreadError();
        return;
    };
    _ = result;
    try std.testing.expect(false); // 不应该到达这里
}

test "Error: Result类型" {
    // 成功情况
    const success_result = ok(i32, 42);
    try std.testing.expect(success_result.isOk());
    try std.testing.expect(!success_result.isErr());
    try std.testing.expectEqual(@as(?i32, 42), success_result.getValue());
    try std.testing.expectEqual(@as(i32, 42), success_result.unwrap());

    // 失败情况
    const fail_result = failWithCode(i32, 1001, "操作失败");
    try std.testing.expect(!fail_result.isOk());
    try std.testing.expect(fail_result.isErr());
    try std.testing.expect(fail_result.getValue() == null);
    try std.testing.expectEqual(@as(i32, 0), fail_result.unwrapOr(0));

    const err_detail = fail_result.getError();
    try std.testing.expect(err_detail != null);
    try std.testing.expectEqualStrings("操作失败", err_detail.?.msg);
}

test "Error: Result.tryUnwrap" {
    // 成功情况
    const success_result = ok(i32, 42);
    const value = try success_result.tryUnwrap();
    try std.testing.expectEqual(@as(i32, 42), value);

    // 失败情况
    const fail_result = failWithCode(i32, ErrorCode.DatabaseConnection, "数据库连接失败");
    _ = fail_result.tryUnwrap() catch |zig_err| {
        try std.testing.expectEqual(ZigError.DatabaseError, zig_err);
        const detail = catch_info();
        try std.testing.expect(detail != null);
        try std.testing.expectEqualStrings("数据库连接失败", detail.?.message());
        clearThreadError();
        return;
    };
    try std.testing.expect(false); // 不应该到达这里
}

test "Error: 通用错误raise（任意错误类型）" {
    // 自定义错误类型
    const MyError = error{ FileNotFound, InvalidFormat, NetworkDown };

    // 模拟函数
    const readFile = struct {
        fn call() MyError![]const u8 {
            return raise(MyError, MyError.FileNotFound, "文件 config.json 不存在");
        }
    }.call;

    // 捕获错误
    _ = readFile() catch |zig_err| {
        try std.testing.expectEqual(MyError.FileNotFound, zig_err);
        const detail = catch_info();
        try std.testing.expect(detail != null);
        try std.testing.expectEqualStrings("文件 config.json 不存在", detail.?.message());
        clearThreadError();
        return;
    };
    try std.testing.expect(false);
}

test "Error: 通用错误make+throw" {
    const MyError = error{ ParseError, ValidationError };

    const parseData = struct {
        fn call() MyError!i32 {
            return make(MyError, MyError.ParseError, "JSON解析失败：缺少必需字段").throw();
        }
    }.call;

    _ = parseData() catch |zig_err| {
        try std.testing.expectEqual(MyError.ParseError, zig_err);
        const detail = catch_info();
        try std.testing.expect(detail != null);
        try std.testing.expectEqualStrings("JSON解析失败：缺少必需字段", detail.?.message());
        clearThreadError();
        return;
    };
    try std.testing.expect(false);
}

test "Error: raiseWithCode通用错误带错误码" {
    const ApiErr = error{ BadRequest, Unauthorized, NotFound };

    const fetchUser = struct {
        fn call() ApiErr!void {
            return raiseWithCode(ApiErr, ApiErr.NotFound, 404, "用户ID 12345 不存在");
        }
    }.call;

    fetchUser() catch |zig_err| {
        try std.testing.expectEqual(ApiErr.NotFound, zig_err);
        const detail = catch_info();
        try std.testing.expect(detail != null);
        try std.testing.expectEqual(@as(?i32, 404), detail.?.code);
        try std.testing.expectEqualStrings("用户ID 12345 不存在", detail.?.message());
        clearThreadError();
        return;
    };
    try std.testing.expect(false);
}
