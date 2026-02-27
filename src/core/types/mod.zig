//! 通用类型定义模块 (Types Module)
//!
//! 定义项目中共享的类型，包括分页参数、HTTP 方法、状态码、结果类型等。

const std = @import("std");

/// 分页参数
pub const Pagination = struct {
    page: u32 = 1,
    page_size: u32 = 10,
    total: ?u64 = null,

    /// 计算偏移量
    pub fn offset(self: Pagination) u64 {
        return @as(u64, self.page - 1) * @as(u64, self.page_size);
    }

    /// 计算总页数
    pub fn totalPages(self: Pagination) u32 {
        if (self.total) |t| {
            return @intCast((t + @as(u64, self.page_size) - 1) / @as(u64, self.page_size));
        }
        return 0;
    }
};

/// 分页结果
pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        pagination: Pagination,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.items);
        }
    };
}

/// HTTP 方法
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
};

/// HTTP 状态码
pub const HttpStatus = struct {
    pub const OK = 200;
    pub const Created = 201;
    pub const NoContent = 204;
    pub const BadRequest = 400;
    pub const Unauthorized = 401;
    pub const Forbidden = 403;
    pub const NotFound = 404;
    pub const Conflict = 409;
    pub const InternalServerError = 500;
};

/// 操作结果
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

        pub fn unwrap(self: @This()) T {
            return switch (self) {
                .ok => |v| v,
                .err => unreachable,
            };
        }

        pub fn unwrapErr(self: @This()) E {
            return switch (self) {
                .ok => unreachable,
                .err => |e| e,
            };
        }
    };
}

/// 可选结果
pub fn Optional(comptime T: type) type {
    return ?T;
}

/// 排序方向
pub const SortDirection = enum {
    Asc,
    Desc,
};

/// 排序参数
pub const SortParam = struct {
    field: []const u8,
    direction: SortDirection = .Asc,
};

/// 时间戳类型
pub const Timestamp = i64;

/// 获取当前时间戳
pub fn now() Timestamp {
    return std.time.timestamp();
}
