//! SQL 错误处理模块
//!
//! 提供详细的 SQL 错误信息，支持：
//! - 捕获数据库原生错误消息（SQLite/MySQL/PostgreSQL）
//! - 错误链和上下文信息
//! - 可重试错误识别
//! - 与应用错误系统集成
//!
//! ## 使用示例
//!
//! ```zig
//! const sql_errors = @import("sql_errors.zig");
//!
//! // 执行查询时捕获详细错误
//! const result = db.rawQuery(sql, .{}) catch |err| {
//!     if (sql_errors.getLastError()) |detail| {
//!         std.log.err("SQL错误: {s}", .{detail.message()});
//!         std.log.err("原生错误: {s}", .{detail.getNativeMessage() orelse "无"});
//!         std.log.err("SQL语句: {s}", .{detail.getSql() orelse "无"});
//!     }
//!     return err;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const errors = @import("../errors/errors.zig");

// ============================================================================
// SQL 错误码定义
// ============================================================================

/// SQL 错误码（扩展 errors.ErrorCode）
pub const SqlErrorCode = struct {
    // 连接错误 (2100-2199)
    pub const ConnectionFailed: i32 = 2100;
    pub const ConnectionLost: i32 = 2101;
    pub const ConnectionTimeout: i32 = 2102;
    pub const ConnectionPoolExhausted: i32 = 2103;
    pub const ConnectionPoolClosed: i32 = 2104;
    pub const ServerGone: i32 = 2105;
    pub const BrokenPipe: i32 = 2106;

    // 查询错误 (2200-2299)
    pub const QueryFailed: i32 = 2200;
    pub const QueryTimeout: i32 = 2201;
    pub const QueryCancelled: i32 = 2202;
    pub const SyntaxError: i32 = 2203;
    pub const TableNotFound: i32 = 2204;
    pub const ColumnNotFound: i32 = 2205;
    pub const InvalidParameter: i32 = 2206;

    // 事务错误 (2300-2399)
    pub const TransactionFailed: i32 = 2300;
    pub const TransactionTimeout: i32 = 2301;
    pub const TransactionRollback: i32 = 2302;
    pub const DeadlockDetected: i32 = 2303;
    pub const LockTimeout: i32 = 2304;

    // 数据错误 (2400-2499)
    pub const DuplicateKey: i32 = 2400;
    pub const ForeignKeyViolation: i32 = 2401;
    pub const CheckConstraintViolation: i32 = 2402;
    pub const NotNullViolation: i32 = 2403;
    pub const DataTruncation: i32 = 2404;
    pub const InvalidDataType: i32 = 2405;

    // 权限错误 (2500-2599)
    pub const AccessDenied: i32 = 2500;
    pub const InsufficientPrivilege: i32 = 2501;

    // 模型/ORM 错误 (2600-2699)
    pub const ModelNotFound: i32 = 2600;
    pub const ModelValidationFailed: i32 = 2601;
    pub const ModelCreateFailed: i32 = 2602;
    pub const ModelUpdateFailed: i32 = 2603;
    pub const ModelDeleteFailed: i32 = 2604;
    pub const PrimaryKeyNotFound: i32 = 2605;
};

/// 错误是否可重试
pub fn isRetryable(code: i32) bool {
    return switch (code) {
        SqlErrorCode.ConnectionLost,
        SqlErrorCode.ConnectionTimeout,
        SqlErrorCode.ServerGone,
        SqlErrorCode.BrokenPipe,
        SqlErrorCode.QueryTimeout,
        SqlErrorCode.DeadlockDetected,
        SqlErrorCode.LockTimeout,
        SqlErrorCode.ConnectionPoolExhausted,
        => true,
        else => false,
    };
}

/// 错误是否为连接错误（需要重建连接）
pub fn isConnectionError(code: i32) bool {
    return switch (code) {
        SqlErrorCode.ConnectionFailed,
        SqlErrorCode.ConnectionLost,
        SqlErrorCode.ServerGone,
        SqlErrorCode.BrokenPipe,
        => true,
        else => false,
    };
}

// ============================================================================
// SQL 错误详情
// ============================================================================

/// SQL 错误详情，包含完整上下文
pub const SqlError = struct {
    /// 基础错误信息
    base: errors.Error,
    /// 原生数据库错误码
    native_code: ?i32 = null,
    /// 原生数据库错误消息
    native_message: ?[]const u8 = null,
    /// 执行的 SQL 语句
    sql: ?[]const u8 = null,
    /// 表名
    table_name: ?[]const u8 = null,
    /// 操作类型
    operation: ?Operation = null,
    /// 执行耗时（毫秒）
    duration_ms: ?f64 = null,
    /// 重试次数
    retry_count: u32 = 0,
    /// 是否可重试
    retryable: bool = false,

    pub const Operation = enum {
        query,
        exec,
        insert,
        update,
        delete,
        transaction_begin,
        transaction_commit,
        transaction_rollback,
        connect,
        disconnect,
    };

    /// 获取错误消息
    pub fn message(self: *const SqlError) []const u8 {
        return self.base.msg;
    }

    /// 获取错误码
    pub fn getCode(self: *const SqlError) ?i32 {
        return self.base.code;
    }

    /// 获取原生错误消息
    pub fn getNativeMessage(self: *const SqlError) ?[]const u8 {
        return self.native_message;
    }

    /// 获取 SQL 语句
    pub fn getSql(self: *const SqlError) ?[]const u8 {
        return self.sql;
    }

    /// 格式化完整错误信息
    pub fn format(self: *const SqlError, allocator: Allocator) ![]u8 {
        var buf = try std.ArrayList(u8).initCapacity(allocator, 128);
        errdefer buf.deinit(allocator);

        try self.formatTo(&buf, allocator);
        return buf.toOwnedSlice(allocator);
    }

    /// 格式化错误到缓冲区
    fn formatTo(self: *const SqlError, buf: *std.ArrayList(u8), allocator: Allocator) !void {
        // 错误码和消息
        if (self.base.code) |code| {
            try buf.writer(allocator).print("[{d}] ", .{code});
        }
        try buf.writer(allocator).print("{s}", .{self.base.msg});

        // 操作类型
        if (self.operation) |op| {
            try buf.writer(allocator).print(" (操作: {s})", .{@tagName(op)});
        }

        // 表名
        if (self.table_name) |tbl| {
            try buf.writer(allocator).print(" [表: {s}]", .{tbl});
        }

        // 原生错误
        if (self.native_message) |native| {
            try buf.writer(allocator).print("\n  原生错误: ", .{});
            if (self.native_code) |nc| {
                try buf.writer(allocator).print("[{d}] ", .{nc});
            }
            try buf.writer(allocator).print("{s}", .{native});
        }

        // SQL 语句
        if (self.sql) |sql| {
            const max_sql_len: usize = 500;
            const display_sql = if (sql.len > max_sql_len) sql[0..max_sql_len] else sql;
            try buf.writer(allocator).print("\n  SQL: {s}", .{display_sql});
            if (sql.len > max_sql_len) {
                try buf.writer(allocator).print("... (截断)", .{});
            }
        }

        // 耗时
        if (self.duration_ms) |dur| {
            try buf.writer(allocator).print("\n  耗时: {d:.2}ms", .{dur});
        }

        // 重试信息
        if (self.retry_count > 0) {
            try buf.writer(allocator).print("\n  重试次数: {d}", .{self.retry_count});
        }
    }

    /// 转换为基础 Error
    pub fn toError(self: *const SqlError) errors.Error {
        return self.base;
    }
};

// ============================================================================
// 线程局部错误存储
// ============================================================================

/// 线程局部 SQL 错误存储
threadlocal var thread_sql_error: ?SqlError = null;
threadlocal var thread_sql_buf: [2048]u8 = undefined;
threadlocal var thread_native_msg_buf: [1024]u8 = undefined;

/// 设置线程局部 SQL 错误
pub fn setLastError(err: SqlError) void {
    thread_sql_error = err;
    // 同时设置到通用错误存储
    errors.setThreadError(err.base);
}

/// 获取线程局部 SQL 错误
pub fn getLastError() ?*SqlError {
    if (thread_sql_error) |*e| {
        return e;
    }
    return null;
}

/// 清除线程局部 SQL 错误
pub fn clearLastError() void {
    thread_sql_error = null;
    errors.clearThreadError();
}

// ============================================================================
// 错误构建器
// ============================================================================

/// SQL 错误构建器
pub const SqlErrorBuilder = struct {
    err: SqlError,

    pub fn init(code: i32, msg: []const u8) SqlErrorBuilder {
        return .{
            .err = .{
                .base = errors.newWithCode(code, msg),
                .retryable = isRetryable(code),
            },
        };
    }

    /// 设置原生错误信息
    pub fn withNativeError(self: *SqlErrorBuilder, native_code: i32, native_msg: []const u8) *SqlErrorBuilder {
        self.err.native_code = native_code;
        // 复制到线程局部缓冲区
        const len = @min(native_msg.len, thread_native_msg_buf.len - 1);
        @memcpy(thread_native_msg_buf[0..len], native_msg[0..len]);
        thread_native_msg_buf[len] = 0;
        self.err.native_message = thread_native_msg_buf[0..len];
        return self;
    }

    /// 设置 SQL 语句
    pub fn withSql(self: *SqlErrorBuilder, sql: []const u8) *SqlErrorBuilder {
        // 复制到线程局部缓冲区
        const len = @min(sql.len, thread_sql_buf.len - 1);
        @memcpy(thread_sql_buf[0..len], sql[0..len]);
        thread_sql_buf[len] = 0;
        self.err.sql = thread_sql_buf[0..len];
        return self;
    }

    /// 设置表名
    pub fn withTable(self: *SqlErrorBuilder, table: []const u8) *SqlErrorBuilder {
        self.err.table_name = table;
        return self;
    }

    /// 设置操作类型
    pub fn withOperation(self: *SqlErrorBuilder, op: SqlError.Operation) *SqlErrorBuilder {
        self.err.operation = op;
        return self;
    }

    /// 设置执行耗时
    pub fn withDuration(self: *SqlErrorBuilder, duration_ms: f64) *SqlErrorBuilder {
        self.err.duration_ms = duration_ms;
        return self;
    }

    /// 设置重试次数
    pub fn withRetryCount(self: *SqlErrorBuilder, count: u32) *SqlErrorBuilder {
        self.err.retry_count = count;
        return self;
    }

    /// 构建并设置为线程局部错误
    pub fn build(self: *SqlErrorBuilder) SqlError {
        setLastError(self.err);
        return self.err;
    }

    /// 构建并抛出 Zig 错误
    pub fn throw(self: *SqlErrorBuilder, comptime E: type, zig_err: E) E {
        _ = self.build();
        return zig_err;
    }

    /// 直接抛出任意Zig错误并附带错误码和消息
    pub fn raiseWithCode(comptime E: type, zig_err: E, code: i32, msg: []const u8) E {
        errors.setThreadError(errors.newWithCode(code, msg));
        return zig_err;
    }

    /// 抛出 SQL 错误（设置详细错误信息并返回 Zig 错误）
    pub fn raiseSqlError(
        comptime E: type,
        zig_err: E,
        code: i32,
        msg: []const u8,
        sql: ?[]const u8,
        native_code: ?i32,
        native_msg: ?[]const u8,
    ) E {
        var builder = SqlErrorBuilder.init(code, msg);
        if (sql) |s| _ = builder.withSql(s);
        if (native_code) |nc| {
            if (native_msg) |nm| {
                _ = builder.withNativeError(nc, nm);
            }
        }
        _ = builder.build();
        return zig_err;
    }

    /// 抛出查询失败错误
    pub fn raiseQueryFailed(
        comptime E: type,
        zig_err: E,
        sql: []const u8,
        native_code: i32,
        native_msg: []const u8,
    ) E {
        return raiseSqlError(E, zig_err, SqlErrorCode.QueryFailed, "SQL查询执行失败", sql, native_code, native_msg);
    }

    /// 抛出执行失败错误
    pub fn raiseExecFailed(
        comptime E: type,
        zig_err: E,
        sql: []const u8,
        native_code: i32,
        native_msg: []const u8,
    ) E {
        return raiseSqlError(E, zig_err, SqlErrorCode.QueryFailed, "SQL语句执行失败", sql, native_code, native_msg);
    }

    /// 抛出连接失败错误
    pub fn raiseConnectionFailed(
        comptime E: type,
        zig_err: E,
        native_code: i32,
        native_msg: []const u8,
    ) E {
        return raiseSqlError(E, zig_err, SqlErrorCode.ConnectionFailed, "数据库连接失败", null, native_code, native_msg);
    }
};

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建连接失败错误
pub fn connectionFailed(native_code: i32, native_msg: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.ConnectionFailed, "数据库连接失败");
    _ = builder.withNativeError(native_code, native_msg).withOperation(.connect);
    return builder;
}

/// 创建查询失败错误
pub fn queryFailed(sql: []const u8, native_code: i32, native_msg: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.QueryFailed, "SQL查询执行失败");
    _ = builder.withSql(sql).withNativeError(native_code, native_msg).withOperation(.query);
    return builder;
}

/// 创建执行失败错误
pub fn execFailed(sql: []const u8, native_code: i32, native_msg: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.QueryFailed, "SQL语句执行失败");
    _ = builder.withSql(sql).withNativeError(native_code, native_msg).withOperation(.exec);
    return builder;
}

/// 创建事务错误
pub fn transactionFailed(op: SqlError.Operation, native_code: i32, native_msg: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.TransactionFailed, "事务操作失败");
    _ = builder.withNativeError(native_code, native_msg).withOperation(op);
    return builder;
}

/// 创建模型未找到错误
pub fn modelNotFound(table: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.ModelNotFound, "记录不存在");
    _ = builder.withTable(table);
    return builder;
}

/// 创建重复键错误
pub fn duplicateKey(table: []const u8, native_msg: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.DuplicateKey, "记录已存在（主键或唯一键冲突）");
    _ = builder.withTable(table).withNativeError(0, native_msg);
    return builder;
}

/// 创建连接池耗尽错误
pub fn poolExhausted() SqlErrorBuilder {
    return SqlErrorBuilder.init(SqlErrorCode.ConnectionPoolExhausted, "连接池已耗尽，无法获取连接");
}

/// 创建死锁错误
pub fn deadlockDetected(sql: []const u8) SqlErrorBuilder {
    var builder = SqlErrorBuilder.init(SqlErrorCode.DeadlockDetected, "检测到死锁，事务已回滚");
    _ = builder.withSql(sql);
    return builder;
}

// ============================================================================
// 从原生错误转换
// ============================================================================

/// SQLite 错误码映射
pub fn mapSqliteError(rc: c_int) i32 {
    return switch (rc) {
        1 => SqlErrorCode.SyntaxError, // SQLITE_ERROR
        5 => SqlErrorCode.LockTimeout, // SQLITE_BUSY
        6 => SqlErrorCode.LockTimeout, // SQLITE_LOCKED
        14 => SqlErrorCode.ConnectionFailed, // SQLITE_CANTOPEN
        19 => SqlErrorCode.DuplicateKey, // SQLITE_CONSTRAINT
        else => SqlErrorCode.QueryFailed,
    };
}

/// MySQL 错误码映射
pub fn mapMysqlError(errno: c_uint) i32 {
    return switch (errno) {
        1045 => SqlErrorCode.AccessDenied, // Access denied
        1049 => SqlErrorCode.ConnectionFailed, // Unknown database
        1062 => SqlErrorCode.DuplicateKey, // Duplicate entry
        1064 => SqlErrorCode.SyntaxError, // Syntax error
        1146 => SqlErrorCode.TableNotFound, // Table doesn't exist
        1205 => SqlErrorCode.LockTimeout, // Lock wait timeout
        1213 => SqlErrorCode.DeadlockDetected, // Deadlock found
        1451, 1452 => SqlErrorCode.ForeignKeyViolation, // FK constraint
        2002, 2003, 2006 => SqlErrorCode.ConnectionFailed, // Can't connect
        2013 => SqlErrorCode.ConnectionLost, // Lost connection
        else => SqlErrorCode.QueryFailed,
    };
}

// ============================================================================
// 重试策略
// ============================================================================

/// 重试配置
pub const RetryConfig = struct {
    /// 最大重试次数
    max_retries: u32 = 3,
    /// 初始延迟（毫秒）
    initial_delay_ms: u64 = 100,
    /// 最大延迟（毫秒）
    max_delay_ms: u64 = 5000,
    /// 延迟倍数（指数退避）
    backoff_multiplier: f32 = 2.0,
    /// 是否只重试可重试错误
    retry_only_retryable: bool = true,
};

/// 带重试的执行器
pub fn withRetry(
    comptime T: type,
    config: RetryConfig,
    context: anytype,
    comptime func: fn (@TypeOf(context)) anyerror!T,
) anyerror!T {
    var attempt: u32 = 0;
    var delay_ms: u64 = config.initial_delay_ms;

    while (true) {
        const result = func(context) catch |err| {
            attempt += 1;

            // 检查是否应该重试
            var should_retry = false;
            if (getLastError()) |sql_err| {
                if (config.retry_only_retryable) {
                    should_retry = sql_err.retryable;
                } else {
                    should_retry = true;
                }
            }

            if (should_retry and attempt < config.max_retries) {
                // 等待后重试
                std.time.sleep(delay_ms * std.time.ns_per_ms);

                // 指数退避
                delay_ms = @min(
                    @as(u64, @intFromFloat(@as(f64, @floatFromInt(delay_ms)) * config.backoff_multiplier)),
                    config.max_delay_ms,
                );

                // 更新重试计数
                if (getLastError()) |sql_err| {
                    sql_err.retry_count = attempt;
                }

                continue;
            }

            return err;
        };

        return result;
    }
}

// ============================================================================
// 测试
// ============================================================================

test "SqlError: 基本创建" {
    var builder = SqlErrorBuilder.init(SqlErrorCode.QueryFailed, "查询失败");
    _ = builder.withSql("SELECT * FROM users").withOperation(.query);
    const err = builder.build();

    try std.testing.expectEqualStrings("查询失败", err.message());
    try std.testing.expectEqual(@as(?i32, SqlErrorCode.QueryFailed), err.getCode());
    try std.testing.expect(err.getSql() != null);
}

test "SqlError: 连接错误可重试" {
    try std.testing.expect(isRetryable(SqlErrorCode.ConnectionLost));
    try std.testing.expect(isRetryable(SqlErrorCode.DeadlockDetected));
    try std.testing.expect(!isRetryable(SqlErrorCode.SyntaxError));
    try std.testing.expect(!isRetryable(SqlErrorCode.DuplicateKey));
}

test "SqlError: 错误码映射" {
    try std.testing.expectEqual(SqlErrorCode.DuplicateKey, mapMysqlError(1062));
    try std.testing.expectEqual(SqlErrorCode.SyntaxError, mapMysqlError(1064));
    try std.testing.expectEqual(SqlErrorCode.DeadlockDetected, mapMysqlError(1213));
}
