//! 员工更新数据传输对象
//!
//! 用于更新员工实体的数据结构

const std = @import("std");

/// 员工更新 DTO
pub const EmployeeUpdateDto = struct {
    /// 员工ID（必填）
    id: i32,
    /// 工号
    employee_no: ?[]const u8 = null,
    /// 姓名
    name: ?[]const u8 = null,
    /// 性别（0未知 1男 2女）
    gender: ?i32 = null,
    /// 手机号
    phone: ?[]const u8 = null,
    /// 邮箱
    email: ?[]const u8 = null,
    /// 身份证号
    id_card: ?[]const u8 = null,
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
    avatar: ?[]const u8 = null,
    /// 状态（0离职 1在职 2试用期）
    status: ?i32 = null,
    /// 排序
    sort: ?i32 = null,
    /// 备注
    remark: ?[]const u8 = null,
};
