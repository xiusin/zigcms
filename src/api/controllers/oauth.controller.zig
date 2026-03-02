//! OAuth 控制器
//!
//! 处理第三方 OAuth 登录和账户绑定
//!
//! ## 功能
//! - 处理 OAuth 回调
//! - 绑定/解绑 OAuth 账户
//! - 获取绑定列表

const std = @import("std");
const Allocator = std.mem.Allocator;
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const jwt = @import("../../core/utils/jwt.zig");
const FeishuOAuthService = @import("../../application/services/oauth/feishu_oauth.service.zig").FeishuOAuthService;
const FeishuConfig = @import("../../application/services/oauth/feishu_oauth.service.zig").FeishuConfig;
const oauth_logger = @import("../../application/services/oauth/oauth_logger.zig");

const Self = @This();

// ORM 定义
const OrmOAuthBind = sql.defineWithConfig(models.SysOAuthBind, .{
    .table_name = "sys_oauth_bind",
    .primary_key = "id",
});

const OrmSysAdmin = sql.defineWithConfig(models.SysAdmin, .{
    .table_name = "sys_admin",
    .primary_key = "id",
});

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    if (!OrmOAuthBind.hasDb()) {
        OrmOAuthBind.use(global.get_db());
    }
    if (!OrmSysAdmin.hasDb()) {
        OrmSysAdmin.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 获取 OAuth 授权 URL
/// GET /api/oauth/authorize?provider=feishu
pub fn authorize(self: *Self, req: zap.Request) !void {
    const provider = (try req.getParamStr(self.allocator, "provider")) orelse {
        return base.send_failed(req, "缺少 provider 参数");
    };
    defer self.allocator.free(provider);

    if (!std.mem.eql(u8, provider, "feishu")) {
        return base.send_failed(req, "不支持的 OAuth 提供商");
    }

    const app_id = std.posix.getenv("FEISHU_APP_ID") orelse {
        return base.send_failed(req, "飞书 APP_ID 未配置");
    };

    const redirect_uri = std.posix.getenv("FEISHU_REDIRECT_URI") orelse {
        return base.send_failed(req, "飞书回调地址未配置");
    };

    const url = try std.fmt.allocPrint(self.allocator, "https://open.feishu.cn/open-apis/authen/v1/authorize?app_id={s}&redirect_uri={s}&state=feishu_oauth", .{ app_id, redirect_uri });
    defer self.allocator.free(url);

    base.send_ok(req, .{ .url = url });
}

/// 处理 OAuth 回调
/// POST /api/oauth/callback
/// Body: { "provider": "feishu", "code": "xxx", "state": "xxx" }
pub fn callback(self: *Self, req: zap.Request) !void {
    self.handleCallback(req) catch |err| {
        std.log.err("OAuth 回调处理失败: {any}", .{err});
        base.send_failed(req, "OAuth 回调处理失败");
    };
}

fn handleCallback(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    const provider = obj.get("provider").?.string;
    const code = obj.get("code").?.string;

    // 目前只支持飞书
    if (!std.mem.eql(u8, provider, "feishu")) {
        return base.send_failed(req, "不支持的 OAuth 提供商");
    }

    // 从环境变量获取飞书配置
    const feishu_app_id = std.posix.getenv("FEISHU_APP_ID") orelse return error.MissingConfig;
    const feishu_app_secret = std.posix.getenv("FEISHU_APP_SECRET") orelse return error.MissingConfig;
    const feishu_redirect_uri = std.posix.getenv("FEISHU_REDIRECT_URI") orelse return error.MissingConfig;

    // 初始化飞书服务
    var feishu_service = FeishuOAuthService.init(self.allocator, .{
        .app_id = feishu_app_id,
        .app_secret = feishu_app_secret,
        .redirect_uri = feishu_redirect_uri,
    });

    // 获取用户访问令牌
    var token_response = try feishu_service.getUserAccessToken(code);
    defer feishu_service.deinit(&token_response);

    // 获取用户信息
    var user_info = try feishu_service.getUserInfo(token_response.access_token);
    defer feishu_service.deinitUserInfo(&user_info);

    // 查询是否已绑定
    var q = OrmOAuthBind.WhereEq("provider", provider);
    defer q.deinit();
    _ = q.whereEq("provider_user_id", user_info.union_id);

    const binds = try q.get();
    defer OrmOAuthBind.freeModels(binds);

    if (binds.len > 0) {
        // 已绑定，直接登录
        const oauth_bind = binds[0];

        // 更新最后登录时间
        const now = std.time.timestamp();
        _ = try OrmOAuthBind.UpdateWith(oauth_bind.id.?, .{
            .last_login_time = now,
            .access_token = token_response.access_token,
            .refresh_token = token_response.refresh_token,
            .token_expires_at = now + token_response.expires_in,
        });

        // 查询用户信息
        var user_q = OrmSysAdmin.Query();
        defer user_q.deinit();

        _ = user_q.where("id", "=", oauth_bind.user_id);
        const users = try user_q.get();
        defer OrmSysAdmin.freeModels(users);

        if (users.len == 0) {
            return base.send_failed(req, "用户不存在");
        }

        const user = users[0];

        // 记录审计日志
        const ip = req.getHeader("x-real-ip") orelse req.getHeader("x-forwarded-for") orelse "unknown";
        const ua = req.getHeader("user-agent") orelse "";
        oauth_logger.logLoginSuccess(user.id.?, provider, user_info.union_id, ip, ua) catch |err| {
            std.log.warn("记录审计日志失败: {any}", .{err});
        };

        // 生成 JWT token
        const now_jwt = std.time.timestamp();
        const access_token = try jwt.encode(self.allocator, .{}, .{
            .user_id = user.id.?,
            .username = user.username,
            .email = user.email,
            .exp = now_jwt + 7200,
            .iat = now_jwt,
        }, .{ .secret = "zigcms-jwt-secret-key-2024" });
        defer self.allocator.free(access_token);

        // 返回登录成功
        base.send_ok(req, .{
            .access_token = access_token,
            .expires_in = 7200,
            .user = .{
                .id = user.id.?,
                .username = user.username,
                .nickname = user.nickname,
                .email = user.email,
                .avatar_url = user_info.avatar_url,
            },
        });
    } else {
        // 未绑定，需要注册或绑定现有账户
        // 这里简化处理：自动创建新用户
        const now = std.time.timestamp();

        // 创建新用户
        const new_user = models.SysAdmin{
            .username = try std.fmt.allocPrint(self.allocator, "feishu_{s}", .{user_info.open_id}),
            .nickname = user_info.name,
            .password_hash = "", // OAuth 用户无密码
            .email = user_info.email,
            .created_at = now,
            .updated_at = now,
        };

        const created_user = try OrmSysAdmin.Create(new_user);

        // 创建绑定记录
        const new_bind = models.SysOAuthBind{
            .user_id = created_user.id.?,
            .provider = provider,
            .provider_user_id = user_info.union_id,
            .nickname = user_info.name,
            .avatar_url = user_info.avatar_url,
            .email = user_info.email,
            .access_token = token_response.access_token,
            .refresh_token = token_response.refresh_token,
            .token_expires_at = now + token_response.expires_in,
            .bind_time = now,
            .last_login_time = now,
            .status = 1,
            .created_at = now,
            .updated_at = now,
        };

        _ = try OrmOAuthBind.Create(new_bind);

        // 记录审计日志（首次注册登录）
        const ip = req.getHeader("x-real-ip") orelse req.getHeader("x-forwarded-for") orelse "unknown";
        const ua = req.getHeader("user-agent") orelse "";
        oauth_logger.logLoginSuccess(created_user.id.?, provider, user_info.union_id, ip, ua) catch |err| {
            std.log.warn("记录审计日志失败: {any}", .{err});
        };

        // 生成 JWT token
        const now_ts = std.time.timestamp();
        const access_token = try jwt.encode(self.allocator, .{}, .{
            .user_id = created_user.id.?,
            .username = created_user.username,
            .email = created_user.email,
            .exp = now_ts + 7200,
            .iat = now_ts,
        }, .{ .secret = "zigcms-jwt-secret-key-2024" });
        defer self.allocator.free(access_token);

        // 返回登录成功
        base.send_ok(req, .{
            .access_token = access_token,
            .expires_in = 7200,
            .user = .{
                .id = created_user.id.?,
                .username = created_user.username,
                .nickname = created_user.nickname,
                .email = created_user.email,
                .avatar_url = user_info.avatar_url,
            },
        });
    }
}

/// 绑定第三方账户
/// POST /api/oauth/bind
/// Body: { "provider": "feishu", "code": "xxx" }
pub fn bind(self: *Self, req: zap.Request) !void {
    self.handleBind(req) catch |err| {
        std.log.err("绑定账户失败: {any}", .{err});
        base.send_failed(req, "绑定账户失败");
    };
}

fn handleBind(self: *Self, req: zap.Request) !void {
    const user_id_str = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse {
        return base.send_failed(req, "未登录");
    };
    const user_id = try std.fmt.parseInt(i32, user_id_str, 10);

    const body = req.body orelse return base.send_failed(req, "缺少请求体");

    const parsed = try std.json.parseFromSlice(struct {
        provider: []const u8,
        code: []const u8,
    }, self.allocator, body, .{});
    defer parsed.deinit();

    const provider = parsed.value.provider;
    const code = parsed.value.code;

    if (!std.mem.eql(u8, provider, "feishu")) {
        return base.send_failed(req, "不支持的 OAuth 提供商");
    }

    const feishu_config = FeishuConfig{
        .app_id = std.posix.getenv("FEISHU_APP_ID") orelse return base.send_failed(req, "飞书配置错误"),
        .app_secret = std.posix.getenv("FEISHU_APP_SECRET") orelse return base.send_failed(req, "飞书配置错误"),
        .redirect_uri = std.posix.getenv("FEISHU_REDIRECT_URI") orelse "",
    };

    var feishu_service = FeishuOAuthService.init(self.allocator, feishu_config);

    const token = try feishu_service.getUserAccessToken(code);
    defer self.allocator.free(token.access_token);
    defer self.allocator.free(token.refresh_token);

    const user_info = try feishu_service.getUserInfo(token.access_token);
    defer self.allocator.free(user_info.open_id);
    defer self.allocator.free(user_info.union_id);
    defer self.allocator.free(user_info.name);
    defer self.allocator.free(user_info.en_name);
    defer self.allocator.free(user_info.email);
    defer self.allocator.free(user_info.mobile);
    defer self.allocator.free(user_info.avatar_url);

    var q = OrmOAuthBind.WhereEq("provider", provider);
    defer q.deinit();
    _ = q.whereEq("provider_user_id", user_info.open_id);

    const existing = try q.get();
    defer OrmOAuthBind.freeModels(existing);

    if (existing.len > 0) {
        return base.send_failed(req, "该第三方账户已被绑定");
    }

    const now = std.time.timestamp();
    const new_bind = models.SysOAuthBind{
        .user_id = user_id,
        .provider = provider,
        .provider_user_id = user_info.open_id,
        .nickname = user_info.name,
        .avatar_url = user_info.avatar_url,
        .email = user_info.email,
        .access_token = token.access_token,
        .refresh_token = token.refresh_token,
        .token_expires_at = now + token.expires_in,
        .bind_time = now,
        .last_login_time = now,
        .status = 1,
        .created_at = now,
        .updated_at = now,
    };

    _ = try OrmOAuthBind.Create(new_bind);

    // 记录审计日志
    const ip = req.getHeader("x-real-ip") orelse req.getHeader("x-forwarded-for") orelse "unknown";
    const ua = req.getHeader("user-agent") orelse "";
    oauth_logger.logBindSuccess(user_id, provider, user_info.open_id, ip, ua) catch |err| {
        std.log.warn("记录审计日志失败: {any}", .{err});
    };

    base.send_ok(req, .{ .msg = "绑定成功" });
}

/// 获取绑定列表
/// GET /api/oauth/bind/list
pub fn bindList(self: *Self, req: zap.Request) !void {
    self.handleBindList(req) catch |err| {
        std.log.err("获取绑定列表失败: {any}", .{err});
        base.send_failed(req, "获取绑定列表失败");
    };
}

fn handleBindList(self: *Self, req: zap.Request) !void {
    // 从请求头获取用户ID
    const user_id_str = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse {
        return base.send_failed(req, "未登录");
    };

    const user_id = try std.fmt.parseInt(i32, user_id_str, 10);

    // 查询绑定列表
    var q = OrmOAuthBind.WhereEq("user_id", user_id);
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));

    const binds = q.get() catch |err| return base.send_error(req, err);
    defer OrmOAuthBind.freeModels(binds);

    // 构建返回数据
    var list = std.ArrayListUnmanaged(models.SysOAuthBind){};
    defer list.deinit(self.allocator);
    for (binds) |item| {
        list.append(self.allocator, item) catch {};
    }

    base.send_ok(req, .{ .list = list.items });
}

/// 刷新 OAuth Token
/// POST /api/oauth/refresh
/// Body: { "provider": "feishu", "refresh_token": "xxx" }
pub fn refresh(self: *Self, req: zap.Request) !void {
    self.handleRefresh(req) catch |err| {
        std.log.err("Token 刷新失败: {any}", .{err});
        base.send_failed(req, "Token 刷新失败");
    };
}

fn handleRefresh(self: *Self, req: zap.Request) !void {
    const body = req.body orelse return base.send_failed(req, "缺少请求体");

    const parsed = try std.json.parseFromSlice(struct {
        provider: []const u8,
        refresh_token: []const u8,
    }, self.allocator, body, .{});
    defer parsed.deinit();

    const provider = parsed.value.provider;
    const refresh_token = parsed.value.refresh_token;

    if (!std.mem.eql(u8, provider, "feishu")) {
        return base.send_failed(req, "不支持的 OAuth 提供商");
    }

    const feishu_config = FeishuConfig{
        .app_id = std.posix.getenv("FEISHU_APP_ID") orelse return base.send_failed(req, "飞书配置错误"),
        .app_secret = std.posix.getenv("FEISHU_APP_SECRET") orelse return base.send_failed(req, "飞书配置错误"),
        .redirect_uri = std.posix.getenv("FEISHU_REDIRECT_URI") orelse "",
    };

    var feishu_service = FeishuOAuthService.init(self.allocator, feishu_config);

    const new_token = try feishu_service.refreshAccessToken(refresh_token);
    defer self.allocator.free(new_token.access_token);
    defer self.allocator.free(new_token.refresh_token);

    // 记录审计日志
    const ip = req.getHeader("x-real-ip") orelse req.getHeader("x-forwarded-for") orelse "unknown";
    const ua = req.getHeader("user-agent") orelse "";
    oauth_logger.logRefresh(null, provider, ip, ua) catch |err| {
        std.log.warn("记录审计日志失败: {any}", .{err});
    };

    base.send_ok(req, .{
        .access_token = new_token.access_token,
        .refresh_token = new_token.refresh_token,
        .expires_in = new_token.expires_in,
    });
}

/// 解绑 OAuth 账户
/// DELETE /api/oauth/unbind?provider=feishu
pub fn unbind(self: *Self, req: zap.Request) !void {
    self.handleUnbind(req) catch |err| {
        std.log.err("解绑失败: {any}", .{err});
        base.send_failed(req, "解绑失败");
    };
}

fn handleUnbind(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();

    // 从请求头获取用户ID
    const user_id_str = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse {
        return base.send_failed(req, "未登录");
    };

    const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch {
        return base.send_failed(req, "用户ID格式错误");
    };

    // 获取 provider 参数
    const provider = req.getParamSlice("provider") orelse {
        return base.send_failed(req, "缺少 provider 参数");
    };

    // 查询绑定记录
    var q = OrmOAuthBind.WhereEq("user_id", user_id);
    defer q.deinit();
    _ = q.whereEq("provider", provider);

    const binds = q.get() catch |err| return base.send_error(req, err);
    defer OrmOAuthBind.freeModels(binds);

    if (binds.len == 0) {
        return base.send_failed(req, "未找到绑定记录");
    }

    // 删除绑定记录
    _ = OrmOAuthBind.Destroy(binds[0].id.?) catch |err| return base.send_error(req, err);

    // 记录审计日志
    const ip = req.getHeader("x-real-ip") orelse req.getHeader("x-forwarded-for") orelse "unknown";
    const ua = req.getHeader("user-agent") orelse "";
    oauth_logger.logUnbind(user_id, provider, ip, ua) catch |err| {
        std.log.warn("记录审计日志失败: {any}", .{err});
    };

    base.send_ok(req, .{ .message = "解绑成功" });
}
