//! 统一错误处理模块 (Unified Error Handling Module)
//!
//! 合并了原 shared/errors 和 application/services/errors 的功能。
//! 提供统一的错误类型定义、HTTP 状态码映射和错误响应构建。
//!
//! ## 使用示例
//! ```zig
//! const errors = @import("core/errors/mod.zig");
//!
//! // 获取错误的 HTTP 状态码
//! const status = errors.errorToHttpStatus(error.NotFound); // 404
//!
//! // 获取错误消息
//! const message = errors.errorToMessage(error.NotFound); // "资源不存在"
//!
//! // 构建错误响应
//! const response = errors.ErrorResponse.fromError(error.NotFound);
//! ```

const std = @import("std");

/// 应用错误类型
pub const AppError = error{
    // 通用错误 (1000-1099)
    InternalError,
    NotImplemented,
    InvalidParameter,
    InvalidOperation,

    // 认证和授权错误 (1100-1199)
    Unauthorized,
    Forbidden,
    InvalidCredentials,
    TokenExpired,
    TokenInvalid,
    PermissionDenied,

    // 资源错误 (1200-1299)
    NotFound,
    AlreadyExists,
    Conflict,
    ResourceLocked,

    // 验证错误 (1300-1399)
    ValidationError,
    InvalidFormat,
    InvalidLength,
    RequiredFieldMissing,

    // 业务逻辑错误 (1400-1499)
    BusinessRuleViolation,
    InvalidState,
    OperationNotAllowed,

    // 数据库错误 (1500-1599)
    DatabaseError,
    QueryError,
    ConnectionError,
    TransactionError,

    // 外部服务错误 (1600-1699)
    ExternalServiceError,
    NetworkError,
    TimeoutError,

    // 文件和上传错误 (1700-1799)
    FileNotFound,
    FileTooBig,
    InvalidFileType,
    UploadError,
};

/// 错误详情
pub const ErrorDetail = struct {
    code: u32,
    message: []const u8,
    field: ?[]const u8 = null,
    details: ?[]const u8 = null,
};

/// 错误响应
pub const ErrorResponse = struct {
    success: bool = false,
    error_code: u32,
    message: []const u8,
    details: ?[]const u8 = null,

    /// 从错误创建响应
    pub fn fromError(err: anyerror) ErrorResponse {
        return .{
            .error_code = errorToCode(err),
            .message = errorToMessage(err),
        };
    }
};

/// 错误到 HTTP 状态码映射
pub fn errorToHttpStatus(err: anyerror) u16 {
    return switch (err) {
        error.NotFound, error.FileNotFound => 404,
        error.Unauthorized, error.InvalidCredentials, error.TokenExpired, error.TokenInvalid => 401,
        error.Forbidden, error.PermissionDenied => 403,
        error.AlreadyExists, error.Conflict => 409,
        error.ValidationError, error.InvalidFormat, error.InvalidLength, error.RequiredFieldMissing, error.InvalidParameter => 400,
        error.TimeoutError => 408,
        error.FileTooBig => 413,
        error.InvalidFileType => 415,
        else => 500,
    };
}

/// 错误到错误码映射
pub fn errorToCode(err: anyerror) u32 {
    return switch (err) {
        error.InternalError => 1000,
        error.NotImplemented => 1001,
        error.InvalidParameter => 1002,
        error.InvalidOperation => 1003,
        error.Unauthorized => 1100,
        error.Forbidden => 1101,
        error.InvalidCredentials => 1102,
        error.TokenExpired => 1103,
        error.TokenInvalid => 1104,
        error.PermissionDenied => 1105,
        error.NotFound => 1200,
        error.AlreadyExists => 1201,
        error.Conflict => 1202,
        error.ResourceLocked => 1203,
        error.ValidationError => 1300,
        error.InvalidFormat => 1301,
        error.InvalidLength => 1302,
        error.RequiredFieldMissing => 1303,
        error.BusinessRuleViolation => 1400,
        error.InvalidState => 1401,
        error.OperationNotAllowed => 1402,
        error.DatabaseError => 1500,
        error.QueryError => 1501,
        error.ConnectionError => 1502,
        error.TransactionError => 1503,
        error.ExternalServiceError => 1600,
        error.NetworkError => 1601,
        error.TimeoutError => 1602,
        error.FileNotFound => 1700,
        error.FileTooBig => 1701,
        error.InvalidFileType => 1702,
        error.UploadError => 1703,
        else => 9999,
    };
}

/// 错误到消息映射
pub fn errorToMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.InternalError => "内部错误",
        error.NotImplemented => "功能未实现",
        error.InvalidParameter => "参数无效",
        error.InvalidOperation => "操作无效",
        error.Unauthorized => "未授权",
        error.Forbidden => "禁止访问",
        error.InvalidCredentials => "凭证无效",
        error.TokenExpired => "令牌已过期",
        error.TokenInvalid => "令牌无效",
        error.PermissionDenied => "权限不足",
        error.NotFound => "资源不存在",
        error.AlreadyExists => "资源已存在",
        error.Conflict => "资源冲突",
        error.ResourceLocked => "资源已锁定",
        error.ValidationError => "验证失败",
        error.InvalidFormat => "格式无效",
        error.InvalidLength => "长度无效",
        error.RequiredFieldMissing => "必填字段缺失",
        error.BusinessRuleViolation => "违反业务规则",
        error.InvalidState => "状态无效",
        error.OperationNotAllowed => "操作不允许",
        error.DatabaseError => "数据库错误",
        error.QueryError => "查询错误",
        error.ConnectionError => "连接错误",
        error.TransactionError => "事务错误",
        error.ExternalServiceError => "外部服务错误",
        error.NetworkError => "网络错误",
        error.TimeoutError => "请求超时",
        error.FileNotFound => "文件不存在",
        error.FileTooBig => "文件过大",
        error.InvalidFileType => "文件类型无效",
        error.UploadError => "上传失败",
        else => "未知错误",
    };
}

/// 错误上下文（用于错误链）
pub const Error = struct {
    msg: []const u8,
    code: ?i32 = null,
    cause: ?*const Error = null,
    source_file: ?[]const u8 = null,
    source_line: ?u32 = null,
    allocator: ?std.mem.Allocator = null,
    owns_message: bool = false,

    /// 获取错误消息
    pub fn message(self: *const Error) []const u8 {
        return self.msg;
    }

    /// 获取错误码
    pub fn getCode(self: *const Error) ?i32 {
        return self.code;
    }

    /// 解包错误链
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

    /// 释放错误
    pub fn deinit(self: *Error) void {
        if (self.owns_message) {
            if (self.allocator) |alloc| {
                alloc.free(self.msg);
            }
        }
    }
};

/// 创建简单错误
pub fn new(msg: []const u8) Error {
    return .{ .msg = msg };
}

/// 创建带错误码的错误
pub fn newWithCode(code: i32, msg: []const u8) Error {
    return .{ .msg = msg, .code = code };
}

/// 包装已有错误
pub fn wrap(cause: *const Error, msg: []const u8) Error {
    return .{ .msg = msg, .cause = cause };
}
