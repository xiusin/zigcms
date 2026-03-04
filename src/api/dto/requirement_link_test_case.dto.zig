//! 需求关联测试用例数据传输对象
//!
//! 用于关联或取消关联测试用例的数据结构

const std = @import("std");

/// 需求关联测试用例 DTO
pub const RequirementLinkTestCaseDto = struct {
    /// 测试用例 ID（必填）
    test_case_id: i32,

    /// 验证关联数据有效性
    pub fn validate(self: @This()) !void {
        if (self.test_case_id == 0) return error.TestCaseIdRequired;
    }
};
