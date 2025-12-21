//! 通用类型定义模块 (Types Module)
//!
//! 定义项目中共享的类型，包括类型别名、枚举、结构体等。
//! 这些类型在各层之间传递数据时使用。
//!
//! ## 包含的类型
//! - 标准库类型别名（Allocator, ArrayList 等）
//! - HTTP 相关类型（HttpMethod, StatusCode）
//! - 分页参数（Pagination）
//! - 结果类型（Result, Option）

const std = @import("std");

// ============================================================================
// 标准库类型别名
// ============================================================================

/// 内存分配器类型别名
pub const Allocator = std.mem.Allocator;

/// 动态数组类型别名
pub const ArrayList = std.ArrayList;

/// 字符串哈希表类型别名
pub const StringHashMap = std.StringHashMap;

/// 自动哈希表类型别名
pub const AutoHashMap = std.AutoHashMap;

// ============================================================================
// HTTP 相关类型
// ============================================================================

/// HTTP 请求方法
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

/// HTTP 响应状态码
pub const StatusCode = enum(u16) {
    OK = 200,
    Created = 201,
    NoContent = 204,
    BadRequest = 400,
    Unauthorized = 401,
    Forbidden = 403,
    NotFound = 404,
    UnprocessableEntity = 422,
    InternalServerError = 500,
};

// ============================================================================
// 分页类型
// ============================================================================

/// 分页参数
///
/// 用于分页查询的参数结构体。
pub const Pagination = struct {
    /// 当前页码（从 1 开始）
    page: i32 = 1,
    /// 每页记录数
    page_size: i32 = 10,
    /// 总记录数
    total: i32 = 0,

    /// 计算偏移量
    pub fn offset(self: Pagination) i32 {
        return (self.page - 1) * self.page_size;
    }

    /// 计算总页数
    pub fn totalPages(self: Pagination) i32 {
        if (self.page_size == 0) return 0;
        return @divTrunc(self.total + self.page_size - 1, self.page_size);
    }
};

// ============================================================================
// 结果类型
// ============================================================================

/// 结果类型
///
/// 表示操作结果，可能是成功值或错误。
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        /// 检查是否成功
        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }

        /// 检查是否失败
        pub fn isErr(self: @This()) bool {
            return self == .err;
        }
    };
}

/// 可选类型别名
///
/// 表示可能存在或不存在的值。
pub fn Option(comptime T: type) type {
    return ?T;
}
