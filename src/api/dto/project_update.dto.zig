//! 项目更新数据传输对象
//!
//! 用于更新项目实体的数据结构

const std = @import("std");
const Project = @import("../../domain/entities/project.model.zig").Project;

/// 项目更新 DTO
pub const ProjectUpdateDto = struct {
    /// 项目名称（可选）
    name: ?[]const u8 = null,
    /// 项目描述（可选）
    description: ?[]const u8 = null,
    /// 项目状态（可选）
    status: ?Project.ProjectStatus = null,
    /// 项目负责人（可选）
    owner: ?[]const u8 = null,
    /// 成员列表（可选）
    members: ?[]const u8 = null,
    /// 项目设置（可选）
    settings: ?[]const u8 = null,

    /// 验证项目更新数据有效性
    pub fn validate(self: @This()) !void {
        if (self.name) |name| {
            if (name.len == 0) return error.NameRequired;
            if (name.len > 200) return error.NameTooLong;
        }
        if (self.description) |desc| {
            if (desc.len == 0) return error.DescriptionRequired;
            if (desc.len > 500) return error.DescriptionTooLong;
        }
    }

    /// 应用更新到现有实体
    pub fn applyTo(self: @This(), entity: *Project) void {
        if (self.name) |v| entity.name = v;
        if (self.description) |v| entity.description = v;
        if (self.status) |v| entity.status = v;
        if (self.owner) |v| entity.owner = v;
        if (self.members) |v| entity.members = v;
        if (self.settings) |v| entity.settings = v;
    }
};
