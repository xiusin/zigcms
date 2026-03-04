//! 需求更新数据传输对象
//!
//! 用于更新需求实体的数据结构

const std = @import("std");
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;

/// 需求更新 DTO
pub const RequirementUpdateDto = struct {
    /// 需求标题（可选）
    title: ?[]const u8 = null,
    /// 需求描述（可选）
    description: ?[]const u8 = null,
    /// 优先级（可选）
    priority: ?Requirement.Priority = null,
    /// 状态（可选）
    status: ?Requirement.RequirementStatus = null,
    /// 负责人（可选）
    assignee: ?[]const u8 = null,
    /// 建议测试用例数（可选）
    estimated_cases: ?i32 = null,

    /// 验证需求更新数据有效性
    pub fn validate(self: @This()) !void {
        if (self.title) |title| {
            if (title.len == 0) return error.TitleRequired;
            if (title.len > 200) return error.TitleTooLong;
        }
        if (self.description) |desc| {
            if (desc.len == 0) return error.DescriptionRequired;
        }
    }

    /// 应用更新到现有实体
    pub fn applyTo(self: @This(), entity: *Requirement) void {
        if (self.title) |v| entity.title = v;
        if (self.description) |v| entity.description = v;
        if (self.priority) |v| entity.priority = v;
        if (self.status) |v| entity.status = v;
        if (self.assignee) |v| entity.assignee = v;
        if (self.estimated_cases) |v| entity.estimated_cases = v;
    }
};
