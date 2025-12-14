//! 友链管理模型
//!
//! 系统友情链接实体

/// 友情链接实体
pub const FriendLink = struct {
    /// 链接ID
    id: ?i32 = null,
    /// 网站名称
    name: []const u8 = "",
    /// 网站URL
    url: []const u8 = "",
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
    /// 点击次数
    clicks: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 申请人
    applicant: []const u8 = "",
    /// 申请时间
    apply_time: ?i64 = null,
    /// 通过时间
    pass_time: ?i64 = null,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};
