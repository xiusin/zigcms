//! 批量删除数据传输对象
//!
//! 用于批量删除操作的数据结构

const std = @import("std");

/// 批量删除 DTO
pub const BatchDeleteDto = struct {
    /// ID 列表（必填）
    ids: []const i32,

    /// 验证批量删除数据有效性
    pub fn validate(self: @This()) !void {
        if (self.ids.len == 0) return error.IdsRequired;
        if (self.ids.len > 1000) return error.BatchSizeTooLarge;
    }
};
