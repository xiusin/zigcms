//! 会员分组创建数据传输对象
//!
//! 用于创建会员分组实体的数据结构

const std = @import("std");

/// 会员分组创建 DTO
pub const MemberGroupCreateDto = struct {
    /// 分组名称
    name: []const u8,
    /// 分组编码（唯一标识）
    code: []const u8 = "",
    /// 分组描述
    description: []const u8 = "",
    /// 分组图标
    icon: []const u8 = "",
    /// 权限列表（JSON格式）
    permissions: []const u8 = "[]",
    /// 积分要求
    points_required: i32 = 0,
    /// 折扣率（0-100，100为不打折）
    discount_rate: i32 = 100,
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否默认分组
    is_default: i32 = 0,
    /// 备注
    remark: []const u8 = "",
};
