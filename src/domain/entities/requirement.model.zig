// 需求实体
// 用于质量中心的需求管理

const std = @import("std");

/// 需求实体
pub const Requirement = struct {
    id: ?i32 = null,
    project_id: i32 = 0, // 所属项目（必填）
    title: []const u8 = "", // 需求标题（必填）
    description: []const u8 = "", // 需求描述（必填）
    priority: Priority = .medium, // 优先级
    status: RequirementStatus = .pending, // 状态
    assignee: ?[]const u8 = null, // 负责人
    estimated_cases: i32 = 0, // 建议测试用例数
    actual_cases: i32 = 0, // 实际测试用例数
    coverage_rate: f32 = 0.0, // 覆盖率
    created_by: []const u8 = "", // 创建人
    created_at: ?i64 = null, // 创建时间
    updated_at: ?i64 = null, // 更新时间

    // 关联数据（预加载）
    test_cases: ?[]TestCase = null, // 关联测试用例

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

    /// 需求状态枚举
    pub const RequirementStatus = enum {
        pending, // 待评审
        reviewed, // 已评审
        developing, // 开发中
        testing, // 待测试
        in_test, // 测试中
        completed, // 已完成
        closed, // 已关闭

        pub fn toString(self: RequirementStatus) []const u8 {
            return switch (self) {
                .pending => "pending",
                .reviewed => "reviewed",
                .developing => "developing",
                .testing => "testing",
                .in_test => "in_test",
                .completed => "completed",
                .closed => "closed",
            };
        }

        pub fn fromString(str: []const u8) ?RequirementStatus {
            if (std.mem.eql(u8, str, "pending")) return .pending;
            if (std.mem.eql(u8, str, "reviewed")) return .reviewed;
            if (std.mem.eql(u8, str, "developing")) return .developing;
            if (std.mem.eql(u8, str, "testing")) return .testing;
            if (std.mem.eql(u8, str, "in_test")) return .in_test;
            if (std.mem.eql(u8, str, "completed")) return .completed;
            if (std.mem.eql(u8, str, "closed")) return .closed;
            return null;
        }
    };

    /// 关系定义（用于 ORM 关系预加载）
    pub const relations = .{
        .test_cases = .{
            .type = .has_many,
            .model = @import("test_case.model.zig").TestCase,
            .foreign_key = "requirement_id",
        },
    };

    /// 验证需求数据是否有效
    pub fn validate(self: *const Requirement) !void {
        if (self.project_id == 0) {
            return error.ProjectIdRequired;
        }
        if (self.title.len == 0) {
            return error.TitleRequired;
        }
        if (self.title.len > 200) {
            return error.TitleTooLong;
        }
        if (self.description.len == 0) {
            return error.DescriptionRequired;
        }
    }

    /// 计算覆盖率
    pub fn calculateCoverageRate(self: *Requirement) void {
        if (self.estimated_cases > 0) {
            self.coverage_rate = @as(f32, @floatFromInt(self.actual_cases)) / @as(f32, @floatFromInt(self.estimated_cases)) * 100.0;
        } else {
            self.coverage_rate = 0.0;
        }
    }

    /// 判断需求是否已完成
    pub fn isCompleted(self: *const Requirement) bool {
        return self.status == .completed or self.status == .closed;
    }

    /// 判断需求是否在测试中
    pub fn isInTest(self: *const Requirement) bool {
        return self.status == .testing or self.status == .in_test;
    }

    /// 判断覆盖率是否达标（>= 80%）
    pub fn isCoverageAdequate(self: *const Requirement) bool {
        return self.coverage_rate >= 80.0;
    }

    /// 验证状态流转是否合法
    pub fn canTransitionTo(self: *const Requirement, new_status: RequirementStatus) bool {
        return switch (self.status) {
            .pending => new_status == .reviewed or new_status == .closed,
            .reviewed => new_status == .developing or new_status == .closed,
            .developing => new_status == .testing or new_status == .closed,
            .testing => new_status == .in_test or new_status == .closed,
            .in_test => new_status == .completed or new_status == .testing or new_status == .closed,
            .completed => new_status == .closed,
            .closed => false, // 已关闭的需求不能再流转
        };
    }
};

// 导入关联实体类型（避免循环依赖）
const TestCase = @import("test_case.model.zig").TestCase;
