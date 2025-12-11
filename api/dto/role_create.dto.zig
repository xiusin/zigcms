//! 角色创建数据传输对象
//!
//! 用于创建角色实体的数据结构

const std = @import("std");

/// 角色创建 DTO
pub const RoleCreateDto = struct {
    /// 角色名称
    name: []const u8,
    /// 角色编码
    code: []const u8 = "",
    /// 角色描述
    description: []const u8 = "",
    /// 权限列表（JSON格式）
    permissions: []const u8 = "[]",
    /// 数据权限范围（1全部 2自定义 3本部门 4本部门及以下 5仅本人）
    data_scope: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
};
