//! 职位响应数据传输对象
//!
//! 用于返回职位实体的数据结构

const std = @import("std");

/// 职位响应 DTO
pub const PositionResponseDto = struct {
    /// 职位ID
    id: ?i32 = null,
    /// 职位名称
    name: []const u8 = "",
    /// 职位编码
    code: []const u8 = "",
    /// 所属部门ID
    department_id: ?i32 = null,
    /// 职级
    level: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 状态
    status: i32 = 1,
    /// 职位描述
    description: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
};
