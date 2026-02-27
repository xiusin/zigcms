//! 部门创建数据传输对象
//!
//! 用于创建部门实体的数据结构

const std = @import("std");

/// 部门创建 DTO
pub const DepartmentCreateDto = struct {
    /// 部门名称
    name: []const u8,
    /// 部门编码
    code: []const u8 = "",
    /// 父部门ID（0表示顶级部门）
    parent_id: i32 = 0,
    /// 部门负责人ID
    leader_id: ?i32 = null,
    /// 联系电话
    phone: []const u8 = "",
    /// 联系邮箱
    email: []const u8 = "",
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
    
    /// 验证部门创建数据有效性
    pub fn validate(self: @This()) !void {
        if (self.name.len == 0) return error.NameRequired;
        if (self.name.len > 100) return error.NameTooLong;
        if (self.parent_id < 0) return error.InvalidParentId;
        if (self.status < 0 or self.status > 1) return error.InvalidStatus;
    }
};
