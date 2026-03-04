// Bug 实体
// 用于质量中心的 Bug 管理

const std = @import("std");

/// Bug 实体
pub const Bug = struct {
    id: ?i32 = null,
    title: []const u8 = "", // Bug 标题（必填）
    description: []const u8 = "", // Bug 描述（必填）
    project_id: i32 = 0, // 所属项目（必填）
    module_id: ?i32 = null, // 所属模块
    status: BugStatus = .open, // Bug 状态
    severity: BugSeverity = .medium, // 严重程度
    assignee: ?[]const u8 = null, // 负责人
    reporter: []const u8 = "", // 报告人
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    /// Bug 状态枚举
    pub const BugStatus = enum {
        open, // 打开
        in_progress, // 处理中
        resolved, // 已解决
        closed, // 已关闭
        reopened, // 重新打开

        pub fn toString(self: BugStatus) []const u8 {
            return switch (self) {
                .open => "open",
                .in_progress => "in_progress",
                .resolved => "resolved",
                .closed => "closed",
                .reopened => "reopened",
            };
        }

        pub fn fromString(str: []const u8) ?BugStatus {
            if (std.mem.eql(u8, str, "open")) return .open;
            if (std.mem.eql(u8, str, "in_progress")) return .in_progress;
            if (std.mem.eql(u8, str, "resolved")) return .resolved;
            if (std.mem.eql(u8, str, "closed")) return .closed;
            if (std.mem.eql(u8, str, "reopened")) return .reopened;
            return null;
        }
    };

    /// Bug 严重程度枚举
    pub const BugSeverity = enum {
        low, // 低
        medium, // 中
        high, // 高
        critical, // 紧急

        pub fn toString(self: BugSeverity) []const u8 {
            return switch (self) {
                .low => "low",
                .medium => "medium",
                .high => "high",
                .critical => "critical",
            };
        }

        pub fn fromString(str: []const u8) ?BugSeverity {
            if (std.mem.eql(u8, str, "low")) return .low;
            if (std.mem.eql(u8, str, "medium")) return .medium;
            if (std.mem.eql(u8, str, "high")) return .high;
            if (std.mem.eql(u8, str, "critical")) return .critical;
            return null;
        }
    };

    /// 验证 Bug 数据是否有效
    pub fn validate(self: *const Bug) !void {
        if (self.title.len == 0) {
            return error.TitleRequired;
        }
        if (self.title.len > 200) {
            return error.TitleTooLong;
        }
        if (self.description.len == 0) {
            return error.DescriptionRequired;
        }
        if (self.project_id == 0) {
            return error.ProjectIdRequired;
        }
        if (self.reporter.len == 0) {
            return error.ReporterRequired;
        }
    }

    /// 判断 Bug 是否打开
    pub fn isOpen(self: *const Bug) bool {
        return self.status == .open or self.status == .reopened;
    }

    /// 判断 Bug 是否处理中
    pub fn isInProgress(self: *const Bug) bool {
        return self.status == .in_progress;
    }

    /// 判断 Bug 是否已解决
    pub fn isResolved(self: *const Bug) bool {
        return self.status == .resolved or self.status == .closed;
    }

    /// 判断 Bug 是否已关闭
    pub fn isClosed(self: *const Bug) bool {
        return self.status == .closed;
    }

    /// 判断是否为高优先级 Bug（高或紧急）
    pub fn isHighPriority(self: *const Bug) bool {
        return self.severity == .high or self.severity == .critical;
    }

    /// 判断是否为紧急 Bug
    pub fn isCritical(self: *const Bug) bool {
        return self.severity == .critical;
    }
};
