// 反馈实体
// 用于质量中心的用户反馈管理

const std = @import("std");

/// 反馈实体
pub const Feedback = struct {
    id: ?i32 = null,
    title: []const u8 = "", // 反馈标题（必填）
    content: []const u8 = "", // 反馈内容（必填）
    type: FeedbackType = .bug, // 反馈类型
    severity: Severity = .medium, // 严重程度
    status: FeedbackStatus = .pending, // 状态
    assignee: ?[]const u8 = null, // 负责人
    submitter: []const u8 = "", // 提交人
    follow_ups: []const u8 = "", // 跟进记录（JSON 数组）
    follow_count: i32 = 0, // 跟进次数
    last_follow_at: ?i64 = null, // 最后跟进时间
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    /// 反馈类型枚举
    pub const FeedbackType = enum {
        bug, // Bug
        feature, // 功能建议
        improvement, // 改进建议
        question, // 问题咨询

        pub fn toString(self: FeedbackType) []const u8 {
            return switch (self) {
                .bug => "bug",
                .feature => "feature",
                .improvement => "improvement",
                .question => "question",
            };
        }

        pub fn fromString(str: []const u8) ?FeedbackType {
            if (std.mem.eql(u8, str, "bug")) return .bug;
            if (std.mem.eql(u8, str, "feature")) return .feature;
            if (std.mem.eql(u8, str, "improvement")) return .improvement;
            if (std.mem.eql(u8, str, "question")) return .question;
            return null;
        }
    };

    /// 严重程度枚举
    pub const Severity = enum {
        low, // 低
        medium, // 中
        high, // 高
        critical, // 紧急

        pub fn toString(self: Severity) []const u8 {
            return switch (self) {
                .low => "low",
                .medium => "medium",
                .high => "high",
                .critical => "critical",
            };
        }

        pub fn fromString(str: []const u8) ?Severity {
            if (std.mem.eql(u8, str, "low")) return .low;
            if (std.mem.eql(u8, str, "medium")) return .medium;
            if (std.mem.eql(u8, str, "high")) return .high;
            if (std.mem.eql(u8, str, "critical")) return .critical;
            return null;
        }
    };

    /// 反馈状态枚举
    pub const FeedbackStatus = enum {
        pending, // 待处理
        in_progress, // 处理中
        resolved, // 已解决
        closed, // 已关闭
        rejected, // 已拒绝

        pub fn toString(self: FeedbackStatus) []const u8 {
            return switch (self) {
                .pending => "pending",
                .in_progress => "in_progress",
                .resolved => "resolved",
                .closed => "closed",
                .rejected => "rejected",
            };
        }

        pub fn fromString(str: []const u8) ?FeedbackStatus {
            if (std.mem.eql(u8, str, "pending")) return .pending;
            if (std.mem.eql(u8, str, "in_progress")) return .in_progress;
            if (std.mem.eql(u8, str, "resolved")) return .resolved;
            if (std.mem.eql(u8, str, "closed")) return .closed;
            if (std.mem.eql(u8, str, "rejected")) return .rejected;
            return null;
        }
    };

    /// 验证反馈数据是否有效
    pub fn validate(self: *const Feedback) !void {
        if (self.title.len == 0) {
            return error.TitleRequired;
        }
        if (self.title.len > 200) {
            return error.TitleTooLong;
        }
        if (self.content.len == 0) {
            return error.ContentRequired;
        }
        if (self.submitter.len == 0) {
            return error.SubmitterRequired;
        }
    }

    /// 判断反馈是否待处理
    pub fn isPending(self: *const Feedback) bool {
        return self.status == .pending;
    }

    /// 判断反馈是否处理中
    pub fn isInProgress(self: *const Feedback) bool {
        return self.status == .in_progress;
    }

    /// 判断反馈是否已解决
    pub fn isResolved(self: *const Feedback) bool {
        return self.status == .resolved or self.status == .closed;
    }

    /// 判断反馈是否已拒绝
    pub fn isRejected(self: *const Feedback) bool {
        return self.status == .rejected;
    }

    /// 判断是否为 Bug 类型
    pub fn isBug(self: *const Feedback) bool {
        return self.type == .bug;
    }

    /// 判断是否为高优先级（高或紧急）
    pub fn isHighPriority(self: *const Feedback) bool {
        return self.severity == .high or self.severity == .critical;
    }

    /// 判断是否需要跟进（待处理或处理中且超过 24 小时未跟进）
    pub fn needsFollowUp(self: *const Feedback) bool {
        if (self.status != .pending and self.status != .in_progress) {
            return false;
        }

        if (self.last_follow_at) |last_follow| {
            const now = std.time.timestamp();
            const hours_since_follow = @divFloor(now - last_follow, 3600);
            return hours_since_follow >= 24;
        }

        return true;
    }
};
