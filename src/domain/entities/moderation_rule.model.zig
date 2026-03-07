//! 审核规则实体模型

const std = @import("std");

/// 规则类型
pub const RuleType = enum {
    sensitive_word,
    length,
    frequency,
    user_level,
    
    pub fn toString(self: RuleType) []const u8 {
        return switch (self) {
            .sensitive_word => "sensitive_word",
            .length => "length",
            .frequency => "frequency",
            .user_level => "user_level",
        };
    }
    
    pub fn fromString(str: []const u8) ?RuleType {
        if (std.mem.eql(u8, str, "sensitive_word")) return .sensitive_word;
        if (std.mem.eql(u8, str, "length")) return .length;
        if (std.mem.eql(u8, str, "frequency")) return .frequency;
        if (std.mem.eql(u8, str, "user_level")) return .user_level;
        return null;
    }
};

/// 审核规则实体
pub const ModerationRule = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    description: []const u8 = "",
    rule_type: []const u8 = "sensitive_word",
    conditions: []const u8 = "{}",
    action: []const u8 = "review",
    priority: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
    
    const Self = @This();
    
    /// 是否启用
    pub fn isEnabled(self: *const Self) bool {
        return self.status == 1;
    }
    
    /// 是否自动通过
    pub fn isAutoApprove(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "auto_approve");
    }
    
    /// 是否自动拒绝
    pub fn isAutoReject(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "auto_reject");
    }
    
    /// 是否人工审核
    pub fn isReview(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "review");
    }
};
