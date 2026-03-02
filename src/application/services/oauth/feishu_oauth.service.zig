//! 飞书 OAuth 服务
//!
//! 处理飞书开放平台的 OAuth 2.0 认证流程
//!
//! ## 功能
//! - 获取飞书用户信息
//! - 刷新访问令牌
//! - 验证令牌有效性
//!
//! ## 飞书 OAuth 流程
//! 1. 前端跳转到飞书授权页面
//! 2. 用户授权后，飞书回调到前端
//! 3. 前端将 code 发送到后端
//! 4. 后端使用 code 换取 access_token
//! 5. 后端使用 access_token 获取用户信息
//! 6. 后端创建或绑定用户账户

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const json = std.json;

/// 飞书 OAuth 配置
pub const FeishuConfig = struct {
    /// 应用 ID
    app_id: []const u8,
    /// 应用密钥
    app_secret: []const u8,
    /// 回调地址
    redirect_uri: []const u8,
};

/// 飞书用户信息
pub const FeishuUserInfo = struct {
    /// 用户 open_id（应用内唯一）
    open_id: []const u8,
    /// 用户 union_id（企业内唯一）
    union_id: []const u8,
    /// 用户名
    name: []const u8,
    /// 英文名
    en_name: []const u8 = "",
    /// 邮箱
    email: []const u8 = "",
    /// 手机号
    mobile: []const u8 = "",
    /// 头像URL
    avatar_url: []const u8 = "",
};

/// 飞书访问令牌响应
pub const FeishuTokenResponse = struct {
    /// 访问令牌
    access_token: []const u8,
    /// 刷新令牌
    refresh_token: []const u8,
    /// 过期时间（秒）
    expires_in: i64,
    /// 令牌类型
    token_type: []const u8,
};

/// 飞书 OAuth 服务
pub const FeishuOAuthService = struct {
    allocator: Allocator,
    config: FeishuConfig,
    
    const Self = @This();
    
    /// 飞书 API 基础URL
    const FEISHU_API_BASE = "https://open.feishu.cn/open-apis";
    
    /// 初始化服务
    pub fn init(allocator: Allocator, config: FeishuConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }
    
    /// 获取应用访问令牌（app_access_token）
    /// 用于调用飞书 API
    pub fn getAppAccessToken(self: *Self) ![]const u8 {
        const url = FEISHU_API_BASE ++ "/auth/v3/app_access_token/internal";
        
        // 构建请求体
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"app_id":"{s}","app_secret":"{s}"}}
        , .{ self.config.app_id, self.config.app_secret });
        defer self.allocator.free(body);
        
        // 发送 HTTP 请求
        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        var req = try client.open(.POST, try std.Uri.parse(url), .{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        });
        defer req.deinit();
        
        req.headers.content_type = .{ .override = "application/json" };
        req.transfer_encoding = .{ .content_length = body.len };
        
        try req.send();
        try req.writeAll(body);
        try req.finish();
        try req.wait();
        
        // 读取响应
        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(response_body);
        
        // 解析 JSON
        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const code = root.get("code").?.integer;
        
        if (code != 0) {
            const msg = root.get("msg").?.string;
            std.log.err("飞书 API 错误: {s}", .{msg});
            return error.FeishuApiError;
        }
        
        const app_access_token = root.get("app_access_token").?.string;
        return try self.allocator.dupe(u8, app_access_token);
    }
    
    /// 使用授权码换取用户访问令牌
    pub fn getUserAccessToken(self: *Self, code: []const u8) !FeishuTokenResponse {
        const app_access_token = try self.getAppAccessToken();
        defer self.allocator.free(app_access_token);
        
        const url = FEISHU_API_BASE ++ "/authen/v1/oidc/access_token";
        
        // 构建请求体
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"grant_type":"authorization_code","code":"{s}"}}
        , .{code});
        defer self.allocator.free(body);
        
        // 发送 HTTP 请求
        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        var req = try client.open(.POST, try std.Uri.parse(url), .{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        });
        defer req.deinit();
        
        req.headers.content_type = .{ .override = "application/json" };
        req.transfer_encoding = .{ .content_length = body.len };
        
        // 添加 Authorization 头
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{app_access_token});
        defer self.allocator.free(auth_header);
        try req.headers.append("Authorization", auth_header);
        
        try req.send();
        try req.writeAll(body);
        try req.finish();
        try req.wait();
        
        // 读取响应
        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(response_body);
        
        // 解析 JSON
        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const code_val = root.get("code").?.integer;
        
        if (code_val != 0) {
            const msg = root.get("msg").?.string;
            std.log.err("飞书 API 错误: {s}", .{msg});
            return error.FeishuApiError;
        }
        
        const data = root.get("data").?.object;
        
        return FeishuTokenResponse{
            .access_token = try self.allocator.dupe(u8, data.get("access_token").?.string),
            .refresh_token = try self.allocator.dupe(u8, data.get("refresh_token").?.string),
            .expires_in = data.get("expires_in").?.integer,
            .token_type = try self.allocator.dupe(u8, data.get("token_type").?.string),
        };
    }
    
    /// 获取用户信息
    pub fn getUserInfo(self: *Self, user_access_token: []const u8) !FeishuUserInfo {
        const url = FEISHU_API_BASE ++ "/authen/v1/user_info";
        
        // 发送 HTTP 请求
        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        var req = try client.open(.GET, try std.Uri.parse(url), .{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        });
        defer req.deinit();
        
        // 添加 Authorization 头
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{user_access_token});
        defer self.allocator.free(auth_header);
        try req.headers.append("Authorization", auth_header);
        
        try req.send();
        try req.finish();
        try req.wait();
        
        // 读取响应
        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(response_body);
        
        // 解析 JSON
        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const code = root.get("code").?.integer;
        
        if (code != 0) {
            const msg = root.get("msg").?.string;
            std.log.err("飞书 API 错误: {s}", .{msg});
            return error.FeishuApiError;
        }
        
        const data = root.get("data").?.object;
        
        return FeishuUserInfo{
            .open_id = try self.allocator.dupe(u8, data.get("open_id").?.string),
            .union_id = try self.allocator.dupe(u8, data.get("union_id").?.string),
            .name = try self.allocator.dupe(u8, data.get("name").?.string),
            .en_name = if (data.get("en_name")) |v| try self.allocator.dupe(u8, v.string) else "",
            .email = if (data.get("email")) |v| try self.allocator.dupe(u8, v.string) else "",
            .mobile = if (data.get("mobile")) |v| try self.allocator.dupe(u8, v.string) else "",
            .avatar_url = if (data.get("avatar_url")) |v| try self.allocator.dupe(u8, v.string) else "",
        };
    }
    
    /// 刷新访问令牌
    pub fn refreshAccessToken(self: *Self, refresh_token: []const u8) !FeishuTokenResponse {
        const app_access_token = try self.getAppAccessToken();
        defer self.allocator.free(app_access_token);
        
        const url = FEISHU_API_BASE ++ "/authen/v1/oidc/refresh_access_token";
        
        // 构建请求体
        const body = try std.fmt.allocPrint(self.allocator,
            \\{{"grant_type":"refresh_token","refresh_token":"{s}"}}
        , .{refresh_token});
        defer self.allocator.free(body);
        
        // 发送 HTTP 请求
        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        var req = try client.open(.POST, try std.Uri.parse(url), .{
            .server_header_buffer = try self.allocator.alloc(u8, 8192),
        });
        defer req.deinit();
        
        req.headers.content_type = .{ .override = "application/json" };
        req.transfer_encoding = .{ .content_length = body.len };
        
        // 添加 Authorization 头
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{app_access_token});
        defer self.allocator.free(auth_header);
        try req.headers.append("Authorization", auth_header);
        
        try req.send();
        try req.writeAll(body);
        try req.finish();
        try req.wait();
        
        // 读取响应
        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(response_body);
        
        // 解析 JSON
        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const code = root.get("code").?.integer;
        
        if (code != 0) {
            const msg = root.get("msg").?.string;
            std.log.err("飞书 API 错误: {s}", .{msg});
            return error.FeishuApiError;
        }
        
        const data = root.get("data").?.object;
        
        return FeishuTokenResponse{
            .access_token = try self.allocator.dupe(u8, data.get("access_token").?.string),
            .refresh_token = try self.allocator.dupe(u8, data.get("refresh_token").?.string),
            .expires_in = data.get("expires_in").?.integer,
            .token_type = try self.allocator.dupe(u8, data.get("token_type").?.string),
        };
    }
    
    /// 释放资源
    pub fn deinit(self: *Self, token_response: *FeishuTokenResponse) void {
        self.allocator.free(token_response.access_token);
        self.allocator.free(token_response.refresh_token);
        self.allocator.free(token_response.token_type);
    }
    
    /// 释放用户信息资源
    pub fn deinitUserInfo(self: *Self, user_info: *FeishuUserInfo) void {
        self.allocator.free(user_info.open_id);
        self.allocator.free(user_info.union_id);
        self.allocator.free(user_info.name);
        if (user_info.en_name.len > 0) self.allocator.free(user_info.en_name);
        if (user_info.email.len > 0) self.allocator.free(user_info.email);
        if (user_info.mobile.len > 0) self.allocator.free(user_info.mobile);
        if (user_info.avatar_url.len > 0) self.allocator.free(user_info.avatar_url);
    }
};
