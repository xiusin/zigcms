//! 反馈创建数据传输对象
//!
//! 用于创建反馈实体的数据结构

const std = @import("std");
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;

/// 反馈创建 DTO
pub const FeedbackCreateDto = struct {
    /// 反馈标题（必填）
    title: []const u8,
    /// 反馈内容（必填）
    content: []const u8,
    /// 反馈类型（bug/feature/improvement/question）
    type: Feedback.FeedbackType = .bug,
    /// 严重程度（low/medium/high/critical）
    severity: Feedback.Severity = .medium,
    /// 负责人（可选）
    assignee: ?[]const u8 = null,
    /// 提交人
    submitter: []const u8 = "",

    /// 验证反馈创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.title.len == 0) return error.TitleRequired;
        if (self.title.len > 200) return error.TitleTooLong;
        if (self.content.len == 0) return error.ContentRequired;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) Feedback {
        return Feedback{
            .title = self.title,
            .content = self.content,
            .type = self.type,
            .severity = self.severity,
            .assignee = self.assignee,
            .submitter = self.submitter,
        };
    }
};
