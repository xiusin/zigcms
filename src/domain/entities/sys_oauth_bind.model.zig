//! OAuth 绑定模型
//!
//! 存储用户与第三方 OAuth 账户的绑定关系

/// OAuth 绑定实体
pub const SysOAuthBind = struct {
    /// 主键ID
    id: ?i32 = null,
    
    /// 用户ID（关联 sys_admin.id）
    user_id: i32 = 0,
    
    /// OAuth 提供商（feishu, github, wechat 等）
    provider: []const u8 = "",
    
    /// 第三方用户唯一标识（如飞书的 open_id 或 union_id）
    provider_user_id: []const u8 = "",
    
    /// 第三方用户昵称
    nickname: []const u8 = "",
    
    /// 第三方用户头像URL
    avatar_url: []const u8 = "",
    
    /// 第三方用户邮箱
    email: []const u8 = "",
    
    /// 访问令牌（加密存储）
    access_token: []const u8 = "",
    
    /// 刷新令牌（加密存储）
    refresh_token: []const u8 = "",
    
    /// 令牌过期时间（Unix 时间戳）
    token_expires_at: ?i64 = null,
    
    /// 绑定时间
    bind_time: ?i64 = null,
    
    /// 最后登录时间
    last_login_time: ?i64 = null,
    
    /// 状态（1=正常 0=禁用）
    status: i32 = 1,
    
    /// 创建时间
    created_at: ?i64 = null,
    
    /// 更新时间
    updated_at: ?i64 = null,
};
