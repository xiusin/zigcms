//! 项目创建数据传输对象
//!
//! 用于创建项目实体的数据结构

const std = @import("std");
const Project = @import("../../domain/entities/project.model.zig").Project;

/// 项目创建 DTO
pub const ProjectCreateDto = struct {
    /// 项目名称（必填）
    name: []const u8,
    /// 项目描述（必填）
    description: []const u8,
    /// 项目负责人
    owner: []const u8 = "",
    /// 成员列表（JSON 数组）
    members: []const u8 = "[]",
    /// 项目设置（JSON 对象）
    settings: []const u8 = "{}",
    /// 创建人
    created_by: []const u8 = "",

    /// 验证项目创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.name.len == 0) return error.NameRequired;
        if (self.name.len > 200) return error.NameTooLong;
        if (self.description.len == 0) return error.DescriptionRequired;
        if (self.description.len > 500) return error.DescriptionTooLong;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) Project {
        return Project{
            .name = self.name,
            .description = self.description,
            .owner = self.owner,
            .members = self.members,
            .settings = self.settings,
            .created_by = self.created_by,
        };
    }
};
