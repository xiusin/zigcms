//! 会员创建数据传输对象
//!
//! 用于创建会员实体的数据结构

const std = @import("std");

/// 会员创建 DTO
pub const MemberCreateDto = struct {
    /// 用户名
    username: []const u8,
    /// 邮箱
    email: []const u8 = "",
    /// 手机号
    mobile: []const u8 = "",
    /// 昵称
    nickname: []const u8 = "",
    /// 头像
    avatar: []const u8 = "",
    /// 性别（0未知 1男 2女）
    gender: i32 = 0,
    /// 生日时间戳
    birthday: ?i64 = null,
    /// 所在地
    location: []const u8 = "",
    /// 个人签名
    signature: []const u8 = "",
    /// 会员分组ID
    group_id: i32 = 0,
    /// 积分
    points: i32 = 0,
    /// 经验值
    experience: i32 = 0,
    /// 等级
    level: i32 = 1,
    /// 总消费金额
    total_consume: f64 = 0.0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否邮箱验证
    email_verified: i32 = 0,
    /// 是否手机验证
    mobile_verified: i32 = 0,
    /// 备注
    remark: []const u8 = "",
};
