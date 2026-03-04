//! 模块创建数据传输对象
//!
//! 用于创建模块实体的数据结构

const std = @import("std");
const Module = @import("../../domain/entities/module.model.zig").Module;

/// 模块创建 DTO
pub const ModuleCreateDto = struct {
    /// 所属项目 ID（必填）
    project_id: i32,
    /// 父模块 ID（可选，null 表示根节点）
    parent_id: ?i32 = null,
    /// 模块名称（必填）
    name: []const u8,
    /// 模块描述
    description: []const u8 = "",
    /// 排序
    sort_order: i32 = 0,
    /// 创建人
    created_by: []const u8 = "",

    /// 验证模块创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.project_id == 0) return error.ProjectIdRequired;
        if (self.name.len == 0) return error.NameRequired;
        if (self.name.len > 200) return error.NameTooLong;
    }

    /// 转换为领域实体
    pub fn toEntity(self: @This()) Module {
        return Module{
            .project_id = self.project_id,
            .parent_id = self.parent_id,
            .name = self.name,
            .description = self.description,
            .sort_order = self.sort_order,
            .created_by = self.created_by,
        };
    }
};
