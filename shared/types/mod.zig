//! Shared Types Module
//!
//! 通用类型定义模块入口
//! 提供项目中共享的类型定义

const std = @import("std");

// 通用类型别名
pub const Allocator = std.mem.Allocator;
pub const ArrayList = std.ArrayList;
pub const StringHashMap = std.StringHashMap;
pub const AutoHashMap = std.AutoHashMap;

// HTTP 相关类型
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

// 响应状态码
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

// 分页参数
pub const Pagination = struct {
    page: i32 = 1,
    page_size: i32 = 10,
    total: i32 = 0,
    
    pub fn offset(self: Pagination) i32 {
        return (self.page - 1) * self.page_size;
    }
    
    pub fn totalPages(self: Pagination) i32 {
        if (self.page_size == 0) return 0;
        return @divTrunc(self.total + self.page_size - 1, self.page_size);
    }
};

// 结果类型
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,
        
        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }
        
        pub fn isErr(self: @This()) bool {
            return self == .err;
        }
    };
}

// 可选结果类型
pub fn Option(comptime T: type) type {
    return ?T;
}

// 导出类型
pub const Types = struct {
    pub const HttpMethod = HttpMethod;
    pub const StatusCode = StatusCode;
    pub const Pagination = Pagination;
    pub const Result = Result;
    pub const Option = Option;
};
