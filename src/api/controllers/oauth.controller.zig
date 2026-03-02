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

/// 处理 OAuth 回调
/// POST /api/oauth/callback
/// Body: { "provider": "feishu", "code": "xxx", "state": "xxx" }
pub fn callback(req: zap.Request) void {
    handleCallback(req) catch |err| {
        std.log.err("OAuth 回调处理失败: {any}", .{err});
        base.send_failed(req, "OAuth 回调处理失败");
    };
}

fn handleCallback(req: zap.Request) !void {
    // 解析请求体
    const body = req.body orelse return error.MissingBody;
    
    const parsed = try std.json.parseFromSlice(std.json.Value, req.allocator.?, body, .{});
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
    var feishu_service = FeishuOAuthService.init(req.allocator.?, .{
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
    var q = OrmOAuthBind.Query();
    defer q.deinit();
    
    _ = q.where("provider", "=", provider)
         .where("provider_user_id", "=", user_info.union_id);
    
    const binds = try q.get();
    defer OrmOAuthBind.freeModels(binds);
    
    if (binds.len > 0) {
        // 已绑定，直接登录
        const bind = binds[0];
        
        // 更新最后登录时间
        const now = std.time.timestamp();
        _ = try OrmOAuthBind.UpdateWith(bind.id.?, .{
            .last_login_time = now,
            .access_token = token_response.access_token,
            .refresh_token = token_response.refresh_token,
            .token_expires_at = now + token_response.expires_in,
        });
        
        // 查询用户信息
        var user_q = OrmSysAdmin.Query();
        defer user_q.deinit();
        
        _ = user_q.where("id", "=", bind.user_id);
        const users = try user_q.get();
        defer OrmSysAdmin.freeModels(users);
        
        if (users.len == 0) {
            return base.send_failed(req, "用户不存在");
        }
        
        const user = users[0];
        
        // 生成 JWT token
        const access_token = try jwt.generateToken(req.allocator.?, user.id.?, user.username);
        defer req.allocator.?.free(access_token);
        
        // 返回登录成功
        try base.send_ok(req, .{
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
            .username = user_info.email,
            .nickname = user_info.name,
            .email = user_info.email,
            .password = "", // OAuth 用户无密码
            .status = 1,
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
        
        // 生成 JWT token
        const access_token = try jwt.generateToken(req.allocator.?, created_user.id.?, created_user.username);
        defer req.allocator.?.free(access_token);
        
        // 返回登录成功
        try base.send_ok(req, .{
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

/// 获取绑定列表
/// GET /api/oauth/bind/list
pub fn bindList(req: zap.Request) void {
    handleBindList(req) catch |err| {
        std.log.err("获取绑定列表失败: {any}", .{err});
        base.send_failed(req, "获取绑定列表失败");
    };
}

fn handleBindList(req: zap.Request) !void {
    // 从请求头获取用户ID
    const user_id_str = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse {
        return base.send_failed(req, "未登录");
    };
    
    const user_id = try std.fmt.parseInt(i32, user_id_str, 10);
    
    // 查询绑定列表
    var q = OrmOAuthBind.Query();
    defer q.deinit();
    
    _ = q.where("user_id", "=", user_id)
         .where("status", "=", 1);
    
    const binds = try q.get();
    defer OrmOAuthBind.freeModels(binds);
    
    // 构建返回数据
    var list = std.ArrayList(std.json.Value).init(req.allocator.?);
    defer list.deinit();
    
    for (binds) |bind| {
        try list.append(.{
            .object = std.json.ObjectMap.init(req.allocator.?),
        });
        var obj = &list.items[list.items.len - 1].object;
        try obj.put("provider", .{ .string = bind.provider });
        try obj.put("provider_user_id", .{ .string = bind.provider_user_id });
        try obj.put("nickname", .{ .string = bind.nickname });
        try obj.put("avatar_url", .{ .string = bind.avatar_url });
        try obj.put("bind_time", .{ .integer = bind.bind_time.? });
    }
    
    try base.send_ok(req, .{ .list = list.items });
}

/// 解绑 OAuth 账户
/// DELETE /api/oauth/unbind?provider=feishu
pub fn unbind(req: zap.Request) void {
    handleUnbind(req) catch |err| {
        std.log.err("解绑失败: {any}", .{err});
        base.send_failed(req, "解绑失败");
    };
}

fn handleUnbind(req: zap.Request) !void {
    // 从请求头获取用户ID
    const user_id_str = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse {
        return base.send_failed(req, "未登录");
    };
    
    const user_id = try std.fmt.parseInt(i32, user_id_str, 10);
    
    // 获取 provider 参数
    const provider = req.getParamStr("provider") orelse {
        return base.send_failed(req, "缺少 provider 参数");
    };
    
    // 查询绑定记录
    var q = OrmOAuthBind.Query();
    defer q.deinit();
    
    _ = q.where("user_id", "=", user_id)
         .where("provider", "=", provider);
    
    const binds = try q.get();
    defer OrmOAuthBind.freeModels(binds);
    
    if (binds.len == 0) {
        return base.send_failed(req, "未找到绑定记录");
    }
    
    // 删除绑定记录
    try OrmOAuthBind.Delete(binds[0].id.?);
    
    try base.send_ok(req, .{ .message = "解绑成功" });
}
