//! 敏感词实体模型

const std = @import("std");

/// 敏感词实体
pub const SensitiveWord = struct {
    id: ?i32 = null,
    word: []const u8 = "",
    category: []const u8 = "general",
    level: i32 = 1,
    action: []const u8 = "replace",
    replacement: []const u8 = "***",
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
    
    const Self = @This();
    
    /// 是否启用
    pub fn isEnabled(self: *const Self) bool {
        return self.status == 1;
    }
    
    /// 是否高危
    pub fn isHighRisk(self: *const Self) bool {
        return self.level >= 3;
    }
    
    /// 是否中危
    pub fn isMediumRisk(self: *const Self) bool {
        return self.level == 2;
    }
    
    /// 是否低危
    pub fn isLowRisk(self: *const Self) bool {
        return self.level == 1;
    }
    
    /// 是否需要替换
    pub fn shouldReplace(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "replace");
    }
    
    /// 是否需要拦截
    pub fn shouldBlock(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "block");
    }
    
    /// 是否需要人工审核
    pub fn shouldReview(self: *const Self) bool {
        return std.mem.eql(u8, self.action, "review");
    }
};
