//! 测试用例更新数据传输对象
//!
//! 用于更新测试用例实体的数据结构

const std = @import("std");
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;

/// 测试用例更新 DTO
pub const TestCaseUpdateDto = struct {
    /// 标题（可选）
    title: ?[]const u8 = null,
    /// 所属项目 ID（可选）
    project_id: ?i32 = null,
    /// 所属模块 ID（可选）
    module_id: ?i32 = null,
    /// 关联需求 ID（可选）
    requirement_id: ?i32 = null,
    /// 优先级（可选）
    priority: ?TestCase.Priority = null,
    /// 状态（可选）
    status: ?TestCase.TestCaseStatus = null,
    /// 前置条件（可选）
    precondition: ?[]const u8 = null,
    /// 测试步骤（可选）
    steps: ?[]const u8 = null,
    /// 预期结果（可选）
    expected_result: ?[]const u8 = null,
    /// 实际结果（可选）
    actual_result: ?[]const u8 = null,
    /// 负责人（可选）
    assignee: ?[]const u8 = null,
    /// 标签（可选）
    tags: ?[]const u8 = null,

    /// 验证测试用例更新数据有效性
    pub fn validate(self: @This()) !void {
        if (self.title) |title| {
            if (title.len == 0) return error.TitleRequired;
            if (title.len > 200) return error.TitleTooLong;
        }
        if (self.project_id) |pid| {
            if (pid == 0) return error.ProjectIdRequired;
        }
        if (self.module_id) |mid| {
            if (mid == 0) return error.ModuleIdRequired;
        }
    }

    /// 应用更新到现有实体
    pub fn applyTo(self: @This(), entity: *TestCase) void {
        if (self.title) |v| entity.title = v;
        if (self.project_id) |v| entity.project_id = v;
        if (self.module_id) |v| entity.module_id = v;
        if (self.requirement_id) |v| entity.requirement_id = v;
        if (self.priority) |v| entity.priority = v;
        if (self.status) |v| entity.status = v;
        if (self.precondition) |v| entity.precondition = v;
        if (self.steps) |v| entity.steps = v;
        if (self.expected_result) |v| entity.expected_result = v;
        if (self.actual_result) |v| entity.actual_result = v;
        if (self.assignee) |v| entity.assignee = v;
        if (self.tags) |v| entity.tags = v;
    }
};
