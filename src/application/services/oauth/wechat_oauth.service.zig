//! 微信 OAuth 服务
//!
//! 实现微信开放平台 OAuth 2.0 授权登录
//! 文档：https://developers.weixin.qq.com/doc/oplatform/Website_App/WeChat_Login/Wechat_Login.html

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const json = std.json;

const WECHAT_API_BASE = "https://api.weixin.qq.com";

/// 微信 OAuth 配置
pub const WechatConfig = struct {
    /// 应用 ID (AppID)
    app_id: []const u8,
    /// 应用密钥 (AppSecret)
    app_secret: []const u8,
    /// 回调地址
    redirect_uri: []const u8,
};

/// 微信用户信息
pub const WechatUserInfo = struct {
    openid: []const u8,
    unionid: []const u8,
    nickname: []const u8,
    headimgurl: []const u8,
    sex: i32 = 0,
    province: []const u8 = "",
    city: []const u8 = "",
    country: []const u8 = "",
};

/// 微信 Token 响应
pub const WechatTokenResponse = struct {
    access_token: []const u8,
    refresh_token: []const u8,
    expires_in: i64,
    openid: []const u8,
    scope: []const u8,
    unionid: []const u8 = "",
};

/// 微信 OAuth 服务
pub const WechatOAuthService = struct {
    allocator: Allocator,
    config: WechatConfig,

    const Self = @This();

    pub fn init(allocator: Allocator, config: WechatConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// 获取用户访问令牌
    /// 文档：https://developers.weixin.qq.com/doc/oplatform/Website_App/WeChat_Login/Wechat_Login.html
    pub fn getUserAccessToken(self: *Self, code: []const u8) !WechatTokenResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sns/oauth2/access_token?appid={s}&secret={s}&code={s}&grant_type=authorization_code",
            .{ WECHAT_API_BASE, self.config.app_id, self.config.app_secret, code },
        );
        defer self.allocator.free(url);

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .GET,
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        if (root.get("errcode")) |errcode| {
            const err_code = errcode.integer;
            if (err_code != 0) {
                const errmsg = root.get("errmsg").?.string;
                std.log.err("微信 API 错误: {s}", .{errmsg});
                return error.WechatApiError;
            }
        }

        return WechatTokenResponse{
            .access_token = try self.allocator.dupe(u8, root.get("access_token").?.string),
            .refresh_token = try self.allocator.dupe(u8, root.get("refresh_token").?.string),
            .expires_in = root.get("expires_in").?.integer,
            .openid = try self.allocator.dupe(u8, root.get("openid").?.string),
            .scope = try self.allocator.dupe(u8, root.get("scope").?.string),
            .unionid = if (root.get("unionid")) |v| try self.allocator.dupe(u8, v.string) else "",
        };
    }

    /// 获取用户信息
    pub fn getUserInfo(self: *Self, access_token: []const u8, openid: []const u8) !WechatUserInfo {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sns/userinfo?access_token={s}&openid={s}",
            .{ WECHAT_API_BASE, access_token, openid },
        );
        defer self.allocator.free(url);

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .GET,
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        if (root.get("errcode")) |errcode| {
            const err_code = errcode.integer;
            if (err_code != 0) {
                const errmsg = root.get("errmsg").?.string;
                std.log.err("微信 API 错误: {s}", .{errmsg});
                return error.WechatApiError;
            }
        }

        return WechatUserInfo{
            .openid = try self.allocator.dupe(u8, root.get("openid").?.string),
            .unionid = if (root.get("unionid")) |v| try self.allocator.dupe(u8, v.string) else "",
            .nickname = try self.allocator.dupe(u8, root.get("nickname").?.string),
            .headimgurl = if (root.get("headimgurl")) |v| try self.allocator.dupe(u8, v.string) else "",
            .sex = if (root.get("sex")) |v| @intCast(v.integer) else 0,
            .province = if (root.get("province")) |v| try self.allocator.dupe(u8, v.string) else "",
            .city = if (root.get("city")) |v| try self.allocator.dupe(u8, v.string) else "",
            .country = if (root.get("country")) |v| try self.allocator.dupe(u8, v.string) else "",
        };
    }

    /// 刷新访问令牌
    pub fn refreshAccessToken(self: *Self, refresh_token: []const u8) !WechatTokenResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/sns/oauth2/refresh_token?appid={s}&grant_type=refresh_token&refresh_token={s}",
            .{ WECHAT_API_BASE, self.config.app_id, refresh_token },
        );
        defer self.allocator.free(url);

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .GET,
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        if (root.get("errcode")) |errcode| {
            const err_code = errcode.integer;
            if (err_code != 0) {
                const errmsg = root.get("errmsg").?.string;
                std.log.err("微信 API 错误: {s}", .{errmsg});
                return error.WechatApiError;
            }
        }

        return WechatTokenResponse{
            .access_token = try self.allocator.dupe(u8, root.get("access_token").?.string),
            .refresh_token = try self.allocator.dupe(u8, root.get("refresh_token").?.string),
            .expires_in = root.get("expires_in").?.integer,
            .openid = try self.allocator.dupe(u8, root.get("openid").?.string),
            .scope = try self.allocator.dupe(u8, root.get("scope").?.string),
            .unionid = if (root.get("unionid")) |v| try self.allocator.dupe(u8, v.string) else "",
        };
    }
};
