//! 模块更新数据传输对象
//!
//! 用于更新模块实体的数据结构

const std = @import("std");
const Module = @import("../../domain/entities/module.model.zig").Module;

/// 模块更新 DTO
pub const ModuleUpdateDto = struct {
    /// 模块名称（可选）
    name: ?[]const u8 = null,
    /// 模块描述（可选）
    description: ?[]const u8 = null,
    /// 排序（可选）
    sort_order: ?i32 = null,

    /// 验证模块更新数据有效性
    pub fn validate(self: @This()) !void {
        if (self.name) |name| {
            if (name.len == 0) return error.NameRequired;
            if (name.len > 200) return error.NameTooLong;
        }
    }

    /// 应用更新到现有实体
    pub fn applyTo(self: @This(), entity: *Module) void {
        if (self.name) |v| entity.name = v;
        if (self.description) |v| entity.description = v;
        if (self.sort_order) |v| entity.sort_order = v;
    }
};
