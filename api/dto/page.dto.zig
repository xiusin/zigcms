//! 分页数据传输对象

const std = @import("std");

/// 分页 DTO
pub const PageDto = struct {
    page: u64 = 1,
    limit: u64 = 10,
    field: []const u8 = "id",
    sort: []const u8 = "desc",
};
