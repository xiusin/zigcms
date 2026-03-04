//! AI 生成需求数据传输对象
//!
//! 用于 AI 生成需求的数据结构

const std = @import("std");

/// AI 生成需求 DTO
pub const AIGenerateRequirementDto = struct {
    /// 项目描述或用户故事（必填）
    description: []const u8,
    /// 语言（zh-CN/en-US）
    language: []const u8 = "zh-CN",

    /// 验证生成参数有效性
    pub fn validate(self: @This()) !void {
        if (self.description.len == 0) return error.DescriptionRequired;
        if (self.description.len > 5000) return error.DescriptionTooLong;
    }
};
