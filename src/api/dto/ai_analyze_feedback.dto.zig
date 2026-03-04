//! AI 分析反馈数据传输对象
//!
//! 用于 AI 分析反馈内容的数据结构

const std = @import("std");

/// AI 分析反馈 DTO
pub const AIAnalyzeFeedbackDto = struct {
    /// 反馈内容（必填）
    content: []const u8,
    /// 语言（zh-CN/en-US）
    language: []const u8 = "zh-CN",

    /// 验证分析参数有效性
    pub fn validate(self: @This()) !void {
        if (self.content.len == 0) return error.ContentRequired;
        if (self.content.len > 5000) return error.ContentTooLong;
    }
};
