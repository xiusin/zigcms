//! Unified Error Handling Module
//!
//! 统一错误处理模块
//!
//! 职责：
//! - 定义统一的错误类型
//! - 提供错误转换和包装
//! - 错误日志记录
//! - HTTP 错误响应

const std = @import("std");

/// 应用错误类型
pub const AppError = error{
    // ============================================================================
    // 通用错误 (1000-1099)
    // ============================================================================
    InternalError,
    NotImplemented,
    InvalidParameter,
    InvalidOperation,

    // ============================================================================
    // 认证和授权错误 (1100-1199)
    // ============================================================================
    Unauthorized,
    Forbidden,
    InvalidCredentials,
    TokenExpired,
    TokenInvalid,
    PermissionDenied,

    // ============================================================================
    // 资源错误 (1200-1299)
    // ============================================================================
    NotFound,
    AlreadyExists,
    Conflict,
    ResourceLocked,

    // ============================================================================
    // 验证错误 (1300-1399)
    // ============================================================================
    ValidationError,
    InvalidFormat,
    InvalidLength,
    RequiredFieldMissing,

    // ============================================================================
    // 业务逻辑错误 (1400-1499)
    // ============================================================================
    BusinessRuleViolation,
    InvalidState,
    OperationNotAllowed,

    // ============================================================================
    // 数据库错误 (1500-1599)
    // ============================================================================
    DatabaseError,
    QueryError,
    ConnectionError,
    TransactionError,

    // ============================================================================
    // 外部服务错误 (1600-1699)
    // ============================================================================
    ExternalServiceError,
    NetworkError,
    TimeoutError,

    // ============================================================================
    // 文件和上传错误 (1700-1799)
    // ============================================================================
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

    pub fn init(code: u32, message: []const u8) ErrorDetail {
        return .{
            .code = code,
            .message = message,
        };
    }

    pub fn withField(self: ErrorDetail, field: []const u8) ErrorDetail {
        var result = self;
        result.field = field;
        return result;
    }

    pub fn withDetails(self: ErrorDetail, details: []const u8) ErrorDetail {
        var result = self;
        result.details = details;
        return result;
    }
};

/// HTTP 状态码映射
pub fn errorToHttpStatus(err: anyerror) u16 {
    return switch (err) {
        // 400 Bad Request
        error.InvalidParameter,
        error.InvalidFormat,
        error.InvalidLength,
        error.ValidationError,
        => 400,

        // 401 Unauthorized
        error.Unauthorized,
        error.InvalidCredentials,
        error.TokenExpired,
        error.TokenInvalid,
        => 401,

        // 403 Forbidden
        error.Forbidden,
        error.PermissionDenied,
        => 403,

        // 404 Not Found
        error.NotFound,
        error.FileNotFound,
        => 404,

        // 409 Conflict
        error.AlreadyExists,
        error.Conflict,
        => 409,

        // 422 Unprocessable Entity
        error.RequiredFieldMissing,
        error.BusinessRuleViolation,
        error.InvalidState,
        => 422,

        // 500 Internal Server Error
        else => 500,
    };
}

/// 错误消息映射
pub fn errorToMessage(err: anyerror) []const u8 {
    return switch (err) {
        // 通用错误
        error.InternalError => "内部服务器错误",
        error.NotImplemented => "功能未实现",
        error.InvalidParameter => "参数无效",
        error.InvalidOperation => "操作无效",

        // 认证和授权
        error.Unauthorized => "未授权访问",
        error.Forbidden => "禁止访问",
        error.InvalidCredentials => "用户名或密码错误",
        error.TokenExpired => "令牌已过期",
        error.TokenInvalid => "令牌无效",
        error.PermissionDenied => "权限不足",

        // 资源错误
        error.NotFound => "资源不存在",
        error.AlreadyExists => "资源已存在",
        error.Conflict => "资源冲突",
        error.ResourceLocked => "资源已锁定",

        // 验证错误
        error.ValidationError => "数据验证失败",
        error.InvalidFormat => "格式不正确",
        error.InvalidLength => "长度不符合要求",
        error.RequiredFieldMissing => "必填字段缺失",

        // 业务逻辑
        error.BusinessRuleViolation => "违反业务规则",
        error.InvalidState => "状态无效",
        error.OperationNotAllowed => "不允许的操作",

        // 数据库
        error.DatabaseError => "数据库错误",
        error.QueryError => "查询错误",
        error.ConnectionError => "连接错误",
        error.TransactionError => "事务错误",

        // 外部服务
        error.ExternalServiceError => "外部服务错误",
        error.NetworkError => "网络错误",
        error.TimeoutError => "请求超时",

        // 文件上传
        error.FileNotFound => "文件不存在",
        error.FileTooBig => "文件过大",
        error.InvalidFileType => "文件类型不支持",
        error.UploadError => "上传失败",

        else => "未知错误",
    };
}

/// 错误响应构建器
pub const ErrorResponse = struct {
    code: u32,
    message: []const u8,
    errors: ?[]ErrorDetail = null,

    pub fn fromError(err: anyerror) ErrorResponse {
        return .{
            .code = errorToHttpStatus(err),
            .message = errorToMessage(err),
        };
    }

    pub fn withErrors(self: ErrorResponse, errors: []ErrorDetail) ErrorResponse {
        var result = self;
        result.errors = errors;
        return result;
    }
};

/// 结果类型 - 用于返回成功或错误
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: ErrorResponse,

        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }

        pub fn isErr(self: @This()) bool {
            return self == .err;
        }

        pub fn unwrap(self: @This()) !T {
            return switch (self) {
                .ok => |value| value,
                .err => error.ResultContainsError,
            };
        }
    };
}
