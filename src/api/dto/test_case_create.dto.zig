//! 测试用例创建数据传输对象
//!
//! 用于创建测试用例实体的数据结构

const std = @import("std");
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;

/// 测试用例创建 DTO
pub const TestCaseCreateDto = struct {
    /// 标题（必填）
    title: []const u8,
    /// 所属项目 ID（必填）
    project_id: i32,
    /// 所属模块 ID（必填）
    module_id: i32,
    /// 关联需求 ID（可选）
    requirement_id: ?i32 = null,
    /// 优先级（low/medium/high/critical）
    priority: TestCase.Priority = .medium,
    /// 前置条件
    precondition: []const u8 = "",
    /// 测试步骤
    steps: []const u8 = "",
    /// 预期结果
    expected_result: []const u8 = "",
    /// 负责人（可选）
    assignee: ?[]const u8 = null,
    /// 标签（JSON 数组）
    tags: []const u8 = "[]",
    /// 创建人
    created_by: []const u8 = "",

    /// 验证测试用例创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.title.len == 0) return error.TitleRequired;
        if (self.title.len > 200) return error.TitleTooLong;
        if (self.project_id == 0) return error.ProjectIdRequired;
        if (self.module_id == 0) return error.ModuleIdRequired;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) TestCase {
        return TestCase{
            .title = self.title,
            .project_id = self.project_id,
            .module_id = self.module_id,
            .requirement_id = self.requirement_id,
            .priority = self.priority,
            .precondition = self.precondition,
            .steps = self.steps,
            .expected_result = self.expected_result,
            .assignee = self.assignee,
            .tags = self.tags,
            .created_by = self.created_by,
        };
    }
};
