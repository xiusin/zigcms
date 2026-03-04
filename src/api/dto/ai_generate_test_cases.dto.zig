//! AI 生成测试用例数据传输对象
//!
//! 用于 AI 生成测试用例的数据结构

const std = @import("std");

/// AI 生成测试用例 DTO
pub const AIGenerateTestCasesDto = struct {
    /// 需求 ID（必填）
    requirement_id: i32,
    /// 最大生成数量
    max_cases: i32 = 10,
    /// 是否包含边界条件
    include_edge_cases: bool = true,
    /// 是否包含性能测试
    include_performance: bool = false,
    /// 语言（zh-CN/en-US）
    language: []const u8 = "zh-CN",

    /// 验证生成参数有效性
    pub fn validate(self: @This()) !void {
        if (self.requirement_id == 0) return error.RequirementIdRequired;
        if (self.max_cases <= 0) return error.InvalidMaxCases;
        if (self.max_cases > 100) return error.MaxCasesTooLarge;
    }
};
