//! 职位更新数据传输对象
//!
//! 用于更新职位实体的数据结构

const std = @import("std");

/// 职位更新 DTO
pub const PositionUpdateDto = struct {
    /// 职位ID（必填）
    id: i32,
    /// 职位名称
    name: ?[]const u8 = null,
    /// 职位编码
    code: ?[]const u8 = null,
    /// 所属部门ID
    department_id: ?i32 = null,
    /// 职级（1-10）
    level: ?i32 = null,
    /// 排序
    sort: ?i32 = null,
    /// 状态（0禁用 1启用）
    status: ?i32 = null,
    /// 职位描述
    description: ?[]const u8 = null,
    /// 备注
    remark: ?[]const u8 = null,
};
