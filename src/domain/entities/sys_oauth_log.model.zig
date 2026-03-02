//! OAuth 审计日志实体
//!
//! 记录所有 OAuth 登录、绑定、解绑、刷新操作

/// OAuth 审计日志实体
pub const SysOAuthLog = struct {
    /// 主键ID
    id: ?i64 = null,
    /// 用户ID（未登录时为NULL）
    user_id: ?i32 = null,
    /// OAuth提供商（feishu/github/wechat/qq）
    provider: []const u8 = "",
    /// 操作类型（login/bind/unbind/refresh）
    action: []const u8 = "",
    /// 第三方用户ID
    provider_user_id: []const u8 = "",
    /// 客户端IP地址
    ip_address: []const u8 = "",
    /// 客户端User-Agent
    user_agent: []const u8 = "",
    /// 操作状态（1成功/0失败）
    status: i32 = 1,
    /// 错误信息（失败时记录）
    error_msg: []const u8 = "",
    /// 额外数据（JSON格式）
    extra_data: []const u8 = "",
    /// 操作时间戳
    created_at: ?i64 = null,
};
