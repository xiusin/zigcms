//! 部门响应数据传输对象
//!
//! 用于返回部门实体的数据结构

const std = @import("std");

/// 部门响应 DTO
pub const DepartmentResponseDto = struct {
    /// 部门ID
    id: ?i32 = null,
    /// 部门名称
    name: []const u8 = "",
    /// 部门编码
    code: []const u8 = "",
    /// 父部门ID
    parent_id: i32 = 0,
    /// 部门负责人ID
    leader_id: ?i32 = null,
    /// 联系电话
    phone: []const u8 = "",
    /// 联系邮箱
    email: []const u8 = "",
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
