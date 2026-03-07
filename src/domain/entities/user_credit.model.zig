//! 用户信用实体模型

const std = @import("std");

/// 用户信用状态
pub const UserCreditStatus = enum {
    normal,
    warning,
    restricted,
    banned,
    
    pub fn toString(self: UserCreditStatus) []const u8 {
        return switch (self) {
            .normal => "normal",
            .warning => "warning",
            .restricted => "restricted",
            .banned => "banned",
        };
    }
    
    pub fn fromString(str: []const u8) ?UserCreditStatus {
        if (std.mem.eql(u8, str, "normal")) return .normal;
        if (std.mem.eql(u8, str, "warning")) return .warning;
        if (std.mem.eql(u8, str, "restricted")) return .restricted;
        if (std.mem.eql(u8, str, "banned")) return .banned;
        return null;
    }
};

/// 用户信用实体
pub const UserCredit = struct {
    user_id: i32 = 0,
    credit_score: i32 = 100,
    violation_count: i32 = 0,
    last_violation_at: ?i64 = null,
    status: []const u8 = "normal",
    updated_at: ?i64 = null,
    
    const Self = @This();
    
    /// 是否正常
    pub fn isNormal(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "normal");
    }
    
    /// 是否警告
    pub fn isWarning(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "warning");
    }
    
    /// 是否受限
    pub fn isRestricted(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "restricted");
    }
    
    /// 是否封禁
    pub fn isBanned(self: *const Self) bool {
        return std.mem.eql(u8, self.status, "banned");
    }
    
    /// 信用分是否良好
    pub fn hasGoodCredit(self: *const Self) bool {
        return self.credit_score >= 80;
    }
    
    /// 信用分是否较低
    pub fn hasLowCredit(self: *const Self) bool {
        return self.credit_score < 60;
    }
    
    /// 增加信用分
    pub fn addCredit(self: *Self, points: i32) void {
        self.credit_score = @min(100, self.credit_score + points);
    }
    
    /// 减少信用分
    pub fn deductCredit(self: *Self, points: i32) void {
        self.credit_score = @max(0, self.credit_score - points);
    }
    
    /// 增加违规次数
    pub fn addViolation(self: *Self) void {
        self.violation_count += 1;
        self.last_violation_at = std.time.timestamp();
    }
};
