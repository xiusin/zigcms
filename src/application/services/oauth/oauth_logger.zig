//! OAuth 审计日志记录服务
//!
//! 记录所有 OAuth 操作（登录、绑定、解绑、刷新）

const std = @import("std");
const models = @import("../../../domain/entities/mod.zig");

/// OAuth 操作类型
pub const OAuthAction = enum {
    login,
    bind,
    unbind,
    refresh,

    pub fn toString(self: OAuthAction) []const u8 {
        return switch (self) {
            .login => "login",
            .bind => "bind",
            .unbind => "unbind",
            .refresh => "refresh",
        };
    }
};

/// 审计日志记录参数
pub const LogParams = struct {
    user_id: ?i32 = null,
    provider: []const u8,
    action: OAuthAction,
    provider_user_id: []const u8 = "",
    ip_address: []const u8 = "",
    user_agent: []const u8 = "",
    status: i32 = 1,
    error_msg: []const u8 = "",
    extra_data: []const u8 = "",
};

/// 记录 OAuth 操作日志
pub fn logOAuthAction(params: LogParams) !void {
    const now = std.time.timestamp();

    const log = models.SysOAuthLog{
        .user_id = params.user_id,
        .provider = params.provider,
        .action = params.action.toString(),
        .provider_user_id = params.provider_user_id,
        .ip_address = params.ip_address,
        .user_agent = params.user_agent,
        .status = params.status,
        .error_msg = params.error_msg,
        .extra_data = params.extra_data,
        .created_at = now,
    };

    // TODO: 实现 ORM 创建逻辑
    // _ = try OrmOAuthLog.Create(log);

    // 临时日志输出
    std.log.info("OAuth 审计日志: user_id={?}, provider={s}, action={s}, status={d}", .{
        log.user_id,
        log.provider,
        log.action,
        log.status,
    });
}

/// 记录成功的 OAuth 登录
pub fn logLoginSuccess(user_id: i32, provider: []const u8, provider_user_id: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .user_id = user_id,
        .provider = provider,
        .action = .login,
        .provider_user_id = provider_user_id,
        .ip_address = ip,
        .user_agent = ua,
        .status = 1,
    });
}

/// 记录失败的 OAuth 登录
pub fn logLoginFailure(provider: []const u8, error_msg: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .provider = provider,
        .action = .login,
        .ip_address = ip,
        .user_agent = ua,
        .status = 0,
        .error_msg = error_msg,
    });
}

/// 记录成功的账户绑定
pub fn logBindSuccess(user_id: i32, provider: []const u8, provider_user_id: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .user_id = user_id,
        .provider = provider,
        .action = .bind,
        .provider_user_id = provider_user_id,
        .ip_address = ip,
        .user_agent = ua,
        .status = 1,
    });
}

/// 记录失败的账户绑定
pub fn logBindFailure(user_id: ?i32, provider: []const u8, error_msg: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .user_id = user_id,
        .provider = provider,
        .action = .bind,
        .ip_address = ip,
        .user_agent = ua,
        .status = 0,
        .error_msg = error_msg,
    });
}

/// 记录账户解绑
pub fn logUnbind(user_id: i32, provider: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .user_id = user_id,
        .provider = provider,
        .action = .unbind,
        .ip_address = ip,
        .user_agent = ua,
        .status = 1,
    });
}

/// 记录 Token 刷新
pub fn logRefresh(user_id: ?i32, provider: []const u8, ip: []const u8, ua: []const u8) !void {
    try logOAuthAction(.{
        .user_id = user_id,
        .provider = provider,
        .action = .refresh,
        .ip_address = ip,
        .user_agent = ua,
        .status = 1,
    });
}
