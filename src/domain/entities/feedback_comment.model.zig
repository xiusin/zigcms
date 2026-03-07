// 反馈评论实体
//
// 功能：
// - 评论数据结构
// - 业务规则验证

const std = @import("std");

/// 反馈评论
pub const FeedbackComment = struct {
    /// 评论 ID
    id: ?i32 = null,
    
    /// 反馈 ID
    feedback_id: i32,
    
    /// 父评论 ID（回复时使用）
    parent_id: ?i32 = null,
    
    /// 评论者
    author: []const u8,
    
    /// 评论内容
    content: []const u8,
    
    /// 附件列表（JSON 字符串）
    attachments: []const u8 = "[]",
    
    /// 创建时间
    created_at: ?i64 = null,
    
    /// 更新时间
    updated_at: ?i64 = null,
    
    /// 验证评论内容
    pub fn validate(self: *const FeedbackComment) !void {
        // 验证评论者
        if (self.author.len == 0) {
            return error.InvalidAuthor;
        }
        
        if (self.author.len > 100) {
            return error.AuthorTooLong;
        }
        
        // 验证评论内容
        if (self.content.len == 0) {
            return error.EmptyContent;
        }
        
        if (self.content.len > 10000) {
            return error.ContentTooLong;
        }
        
        // 验证反馈 ID
        if (self.feedback_id <= 0) {
            return error.InvalidFeedbackId;
        }
    }
    
    /// 是否为回复
    pub fn isReply(self: *const FeedbackComment) bool {
        return self.parent_id != null;
    }
    
    /// 是否有附件
    pub fn hasAttachments(self: *const FeedbackComment) bool {
        return !std.mem.eql(u8, self.attachments, "[]");
    }
};
