//! 批量更新状态数据传输对象
//!
//! 用于批量更新测试用例状态的数据结构

const std = @import("std");
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;

/// 批量更新状态 DTO
pub const BatchUpdateStatusDto = struct {
    /// ID 列表（必填）
    ids: []const i32,
    /// 目标状态（必填）
    status: TestCase.TestCaseStatus,

    /// 验证批量更新状态数据有效性
    pub fn validate(self: @This()) !void {
        if (self.ids.len == 0) return error.IdsRequired;
        if (self.ids.len > 1000) return error.BatchSizeTooLarge;
    }
};
