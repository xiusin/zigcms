//! 需求创建数据传输对象
//!
//! 用于创建需求实体的数据结构

const std = @import("std");
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;

/// 需求创建 DTO
pub const RequirementCreateDto = struct {
    /// 所属项目 ID（必填）
    project_id: i32,
    /// 需求标题（必填）
    title: []const u8,
    /// 需求描述（必填）
    description: []const u8,
    /// 优先级（low/medium/high/critical）
    priority: Requirement.Priority = .medium,
    /// 负责人（可选）
    assignee: ?[]const u8 = null,
    /// 建议测试用例数
    estimated_cases: i32 = 0,
    /// 创建人
    created_by: []const u8 = "",

    /// 验证需求创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.project_id == 0) return error.ProjectIdRequired;
        if (self.title.len == 0) return error.TitleRequired;
        if (self.title.len > 200) return error.TitleTooLong;
        if (self.description.len == 0) return error.DescriptionRequired;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) Requirement {
        return Requirement{
            .project_id = self.project_id,
            .title = self.title,
            .description = self.description,
            .priority = self.priority,
            .assignee = self.assignee,
            .estimated_cases = self.estimated_cases,
            .created_by = self.created_by,
        };
    }
};
