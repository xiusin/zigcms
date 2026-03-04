//! 反馈跟进数据传输对象
//!
//! 用于添加反馈跟进记录的数据结构

const std = @import("std");

/// 反馈跟进 DTO
pub const FeedbackFollowUpDto = struct {
    /// 跟进人（必填）
    follower: []const u8,
    /// 跟进内容（必填）
    content: []const u8,

    /// 验证跟进数据有效性
    pub fn validate(self: @This()) !void {
        if (self.follower.len == 0) return error.FollowerRequired;
        if (self.content.len == 0) return error.ContentRequired;
    }
};
