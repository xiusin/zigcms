//! 审核记录实体模型

const std = @import("std");

/// 审核状态
pub const ModerationStatus = enum {
    pending,
    approved,
    rejected,
    auto_approved,
    auto_rejected,
    
    pub fn toString(self: ModerationStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .approved => "approved",
            .rejected => "rejected",
            .auto_approved => "auto_approved",
            .auto_rejected => "auto_rejected",
        };
    }
    
    pub fn fromString(str: []const u8) ?ModerationStatus {
        if (std.mem.eql(u8, str, "pending")) return .pending;
        if (std.mem.eql(u8, str, "approved")) return .approved;
        if (std.mem.eql(u8, str, "rejected")) return .rejected;
        if (std.mem.eql(u8, str, "auto_approved")) return .auto_approved;
        if (std.mem.eql(u8, str, "auto_rejected")) return .auto_rejected;
        return null;
    }
};

/// 内容类型
pub const ContentType = enum {
    comment,
    feedback,
    requirement,
    
    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .comment => "comment",
            .feedback => "feedback",
            .requirement => "requirement",
        };
    }
    
    pub fn fromString(str: []const u8) ?ContentType {
        if (std.mem.eql(u8, str, "comment")) return .comment;
        if (std.mem.eql(u8, str, "feedback")) return .feedback;
        if (std.mem.eql(u8, str, "requirement")) return .requirement;
        return null;
    }
};

/// 审核记录实体
pub const ModerationLog = struct {
    id: ?i32 = null,
    content_type: []const u8 = "comment",
    content_id: i32 = 0,
    content_text: []const u8 = "",
    user_id: i32 = 0,
    status: []const u8 = "pending",
    matched_words: []const u8 = "[]",
    matched_rules: []const u8 = "[]",
    auto_action: ?[]const u8 = null,
    reviewer_id: ?i32 = null,
    review_reason: ?[]const u8 = null,
    reviewed_at: ?i64 = null,
    created_at: ?i64 = null,
    
    const Self = @This();
    
    /// 是否待审核
    pub fn isPending(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "pending");
    }
    
    /// 是否已通过
    pub fn isApproved(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "approved") or 
               std.mem.eql(u8, self.status, "auto_approved");
    }
    
    /// 是否已拒绝
    pub fn isRejected(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "rejected") or 
               std.mem.eql(u8, self.status, "auto_rejected");
    }
    
    /// 是否自动处理
    pub fn isAutoProcessed(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "auto_approved") or 
               std.mem.eql(u8, self.status, "auto_rejected");
    }
    
    /// 是否已审核
    pub fn isReviewed(self: *const Self) bool {
        return self.reviewed_at != null;
    }
};
