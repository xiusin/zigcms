//! 角色更新数据传输对象
//!
//! 用于更新角色实体的数据结构

const std = @import("std");

/// 角色更新 DTO
pub const RoleUpdateDto = struct {
    /// 角色ID（必填）
    id: i32,
    /// 角色名称
    name: ?[]const u8 = null,
    /// 角色编码
    code: ?[]const u8 = null,
    /// 角色描述
    description: ?[]const u8 = null,
    /// 权限列表（JSON格式）
    permissions: ?[]const u8 = null,
    /// 数据权限范围（1全部 2自定义 3本部门 4本部门及以下 5仅本人）
    data_scope: ?i32 = null,
    /// 排序
    sort: ?i32 = null,
    /// 状态（0禁用 1启用）
    status: ?i32 = null,
    /// 备注
    remark: ?[]const u8 = null,
};
