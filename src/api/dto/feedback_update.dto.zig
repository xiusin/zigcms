//! 反馈更新数据传输对象
//!
//! 用于更新反馈实体的数据结构

const std = @import("std");
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;

/// 反馈更新 DTO
pub const FeedbackUpdateDto = struct {
    /// 反馈标题（可选）
    title: ?[]const u8 = null,
    /// 反馈内容（可选）
    content: ?[]const u8 = null,
    /// 反馈类型（可选）
    type: ?Feedback.FeedbackType = null,
    /// 严重程度（可选）
    severity: ?Feedback.Severity = null,
    /// 状态（可选）
    status: ?Feedback.FeedbackStatus = null,
    /// 负责人（可选）
    assignee: ?[]const u8 = null,

    /// 验证反馈更新数据有效性
    pub fn validate(self: @This()) !void {
        if (self.title) |title| {
            if (title.len == 0) return error.TitleRequired;
            if (title.len > 200) return error.TitleTooLong;
        }
        if (self.content) |content| {
            if (content.len == 0) return error.ContentRequired;
        }
    }

    /// 应用更新到现有实体
    pub fn applyTo(self: @This(), entity: *Feedback) void {
        if (self.title) |v| entity.title = v;
        if (self.content) |v| entity.content = v;
        if (self.type) |v| entity.type = v;
        if (self.severity) |v| entity.severity = v;
        if (self.status) |v| entity.status = v;
        if (self.assignee) |v| entity.assignee = v;
    }
};
