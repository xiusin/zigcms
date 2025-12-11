//! 部门更新数据传输对象
//!
//! 用于更新部门实体的数据结构

const std = @import("std");

/// 部门更新 DTO
pub const DepartmentUpdateDto = struct {
    /// 部门ID（必填）
    id: i32,
    /// 部门名称
    name: ?[]const u8 = null,
    /// 部门编码
    code: ?[]const u8 = null,
    /// 父部门ID
    parent_id: ?i32 = null,
    /// 部门负责人ID
    leader_id: ?i32 = null,
    /// 联系电话
    phone: ?[]const u8 = null,
    /// 联系邮箱
    email: ?[]const u8 = null,
    /// 排序
    sort: ?i32 = null,
    /// 状态（0禁用 1启用）
    status: ?i32 = null,
    /// 备注
    remark: ?[]const u8 = null,
};
