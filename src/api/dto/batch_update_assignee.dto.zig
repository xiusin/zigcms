//! 批量更新负责人数据传输对象
//!
//! 用于批量更新测试用例负责人的数据结构

const std = @import("std");

/// 批量更新负责人 DTO
pub const BatchUpdateAssigneeDto = struct {
    /// ID 列表（必填）
    ids: []const i32,
    /// 负责人（必填）
    assignee: []const u8,

    /// 验证批量更新负责人数据有效性
    pub fn validate(self: @This()) !void {
        if (self.ids.len == 0) return error.IdsRequired;
        if (self.ids.len > 1000) return error.BatchSizeTooLarge;
        if (self.assignee.len == 0) return error.AssigneeRequired;
    }
};
