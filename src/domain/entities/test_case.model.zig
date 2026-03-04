// 测试用例实体
// 用于质量中心的测试用例管理

const std = @import("std");

/// 测试用例实体
pub const TestCase = struct {
    id: ?i32 = null,
    title: []const u8 = "", // 标题（必填）
    project_id: i32 = 0, // 所属项目（必填）
    module_id: i32 = 0, // 所属模块（必填）
    requirement_id: ?i32 = null, // 关联需求
    priority: Priority = .medium, // 优先级
    status: TestCaseStatus = .pending, // 状态
    precondition: []const u8 = "", // 前置条件
    steps: []const u8 = "", // 测试步骤
    expected_result: []const u8 = "", // 预期结果
    actual_result: []const u8 = "", // 实际结果
    assignee: ?[]const u8 = null, // 负责人
    tags: []const u8 = "", // 标签（JSON 数组）
    created_by: []const u8 = "", // 创建人
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    // 关联数据（预加载）
    executions: ?[]TestExecution = null, // 执行历史
    requirement: ?Requirement = null, // 关联需求
    bugs: ?[]Bug = null, // 关联 Bug

    /// 优先级枚举
    pub const Priority = enum {
        low, // 低
        medium, // 中
        high, // 高
        critical, // 紧急

        pub fn toString(self: Priority) []const u8 {
            return switch (self) {
                .low => "low",
                .medium => "medium",
                .high => "high",
                .critical => "critical",
            };
        }

        pub fn fromString(str: []const u8) ?Priority {
            if (std.mem.eql(u8, str, "low")) return .low;
            if (std.mem.eql(u8, str, "medium")) return .medium;
            if (std.mem.eql(u8, str, "high")) return .high;
            if (std.mem.eql(u8, str, "critical")) return .critical;
            return null;
        }
    };

    /// 测试用例状态枚举
    pub const TestCaseStatus = enum {
        pending, // 待执行
        in_progress, // 执行中
        passed, // 已通过
        failed, // 未通过
        blocked, // 已阻塞

        pub fn toString(self: TestCaseStatus) []const u8 {
            return switch (self) {
                .pending => "pending",
                .in_progress => "in_progress",
                .passed => "passed",
                .failed => "failed",
                .blocked => "blocked",
            };
        }

        pub fn fromString(str: []const u8) ?TestCaseStatus {
            if (std.mem.eql(u8, str, "pending")) return .pending;
            if (std.mem.eql(u8, str, "in_progress")) return .in_progress;
            if (std.mem.eql(u8, str, "passed")) return .passed;
            if (std.mem.eql(u8, str, "failed")) return .failed;
            if (std.mem.eql(u8, str, "blocked")) return .blocked;
            return null;
        }
    };

    /// 关系定义（用于 ORM 关系预加载）
    pub const relations = .{
        .executions = .{
            .type = .has_many,
            .model = @import("test_execution.model.zig").TestExecution,
            .foreign_key = "test_case_id",
        },
        .requirement = .{
            .type = .belongs_to,
            .model = @import("requirement.model.zig").Requirement,
            .foreign_key = "requirement_id",
        },
        .bugs = .{
            .type = .many_to_many,
            .model = @import("bug.model.zig").Bug,
            .through = "quality_link_records",
            .foreign_key = "source_id",
            .related_key = "target_id",
        },
    };

    /// 验证测试用例数据是否有效
    pub fn validate(self: *const TestCase) !void {
        if (self.title.len == 0) {
            return error.TitleRequired;
        }
        if (self.title.len > 200) {
            return error.TitleTooLong;
        }
        if (self.project_id == 0) {
            return error.ProjectIdRequired;
        }
        if (self.module_id == 0) {
            return error.ModuleIdRequired;
        }
    }

    /// 判断测试用例是否已通过
    pub fn isPassed(self: *const TestCase) bool {
        return self.status == .passed;
    }

    /// 判断测试用例是否已失败
    pub fn isFailed(self: *const TestCase) bool {
        return self.status == .failed;
    }

    /// 判断测试用例是否已阻塞
    pub fn isBlocked(self: *const TestCase) bool {
        return self.status == .blocked;
    }
};

// 导入关联实体类型（避免循环依赖）
const TestExecution = @import("test_execution.model.zig").TestExecution;
const Requirement = @import("requirement.model.zig").Requirement;
const Bug = @import("bug.model.zig").Bug;
