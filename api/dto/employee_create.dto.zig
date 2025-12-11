//! 员工创建数据传输对象
//!
//! 用于创建员工实体的数据结构

const std = @import("std");

/// 员工创建 DTO
pub const EmployeeCreateDto = struct {
    /// 工号
    employee_no: []const u8,
    /// 姓名
    name: []const u8,
    /// 性别（0未知 1男 2女）
    gender: i32 = 0,
    /// 手机号
    phone: []const u8 = "",
    /// 邮箱
    email: []const u8 = "",
    /// 身份证号
    id_card: []const u8 = "",
    /// 部门ID
    department_id: ?i32 = null,
    /// 职位ID
    position_id: ?i32 = null,
    /// 角色ID
    role_id: ?i32 = null,
    /// 直属上级ID
    leader_id: ?i32 = null,
    /// 入职日期
    hire_date: ?i64 = null,
    /// 头像URL
    avatar: []const u8 = "",
    /// 状态（0离职 1在职 2试用期）
    status: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 备注
    remark: []const u8 = "",
};
