//! 职位创建数据传输对象
//!
//! 用于创建职位实体的数据结构

const std = @import("std");

/// 职位创建 DTO
pub const PositionCreateDto = struct {
    /// 职位名称
    name: []const u8,
    /// 职位编码
    code: []const u8 = "",
    /// 所属部门ID
    department_id: ?i32 = null,
    /// 职级（1-10）
    level: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 职位描述
    description: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
};
