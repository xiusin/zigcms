//! 角色响应数据传输对象
//!
//! 用于返回角色实体的数据结构

const std = @import("std");

/// 角色响应 DTO
pub const RoleResponseDto = struct {
    /// 角色ID
    id: ?i32 = null,
    /// 角色名称
    name: []const u8 = "",
    /// 角色编码
    code: []const u8 = "",
    /// 角色描述
    description: []const u8 = "",
    /// 权限列表
    permissions: []const u8 = "[]",
    /// 数据权限范围
    data_scope: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 状态
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
};
