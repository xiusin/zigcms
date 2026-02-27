//! 友链创建数据传输对象
//!
//! 用于创建友情链接实体的数据结构

const std = @import("std");

/// 友链创建 DTO
pub const FriendLinkCreateDto = struct {
    /// 网站名称
    name: []const u8,
    /// 网站URL
    url: []const u8,
    /// 网站Logo
    logo: []const u8 = "",
    /// 网站描述
    description: []const u8 = "",
    /// 联系邮箱
    email: []const u8 = "",
    /// QQ号码
    qq: []const u8 = "",
    /// 是否显示（0隐藏 1显示）
    is_show: i32 = 1,
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 申请人
    applicant: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
};
