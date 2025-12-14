//! 会员管理模型
//!
//! 系统会员实体，用于用户会员信息管理

/// 会员实体
pub const Member = struct {
    /// 会员ID
    id: ?i32 = null,
    /// 用户名
    username: []const u8 = "",
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
    /// 生日
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
    /// 最后登录时间
    last_login_time: ?i64 = null,
    /// 最后登录IP
    last_login_ip: []const u8 = "",
    /// 注册时间
    register_time: ?i64 = null,
    /// 注册IP
    register_ip: []const u8 = "",
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否邮箱验证
    email_verified: i32 = 0,
    /// 是否手机验证
    mobile_verified: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};
