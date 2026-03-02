//! QQ OAuth 服务
//!
//! 实现 QQ 互联 OAuth 2.0 授权登录
//! 文档：https://wiki.connect.qq.com/

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const json = std.json;

const QQ_API_BASE = "https://graph.qq.com";

/// QQ OAuth 配置
pub const QQConfig = struct {
    /// 应用 ID (App ID)
    app_id: []const u8,
    /// 应用密钥 (App Key)
    app_key: []const u8,
    /// 回调地址
    redirect_uri: []const u8,
};

/// QQ 用户信息
pub const QQUserInfo = struct {
    openid: []const u8,
    unionid: []const u8 = "",
    nickname: []const u8,
    figureurl_qq: []const u8 = "",
    gender: []const u8 = "",
    province: []const u8 = "",
    city: []const u8 = "",
};

/// QQ Token 响应
pub const QQTokenResponse = struct {
    access_token: []const u8,
    refresh_token: []const u8,
    expires_in: i64,
};

/// QQ OAuth 服务
pub const QQOAuthService = struct {
    allocator: Allocator,
    config: QQConfig,

    const Self = @This();

    pub fn init(allocator: Allocator, config: QQConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// 获取用户访问令牌
    /// 文档：https://wiki.connect.qq.com/%E4%BD%BF%E7%94%A8authorization_code%E8%8E%B7%E5%8F%96access_token
    pub fn getUserAccessToken(self: *Self, code: []const u8) !QQTokenResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/oauth2.0/token?grant_type=authorization_code&client_id={s}&client_secret={s}&code={s}&redirect_uri={s}",
            .{ QQ_API_BASE, self.config.app_id, self.config.app_key, code, self.config.redirect_uri },
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

        // QQ 返回的是 URL 编码格式：access_token=xxx&expires_in=xxx&refresh_token=xxx
        var access_token: []const u8 = "";
        var refresh_token: []const u8 = "";
        var expires_in: i64 = 7200;

        var params = std.mem.splitScalar(u8, response_body, '&');
        while (params.next()) |param| {
            var kv = std.mem.splitScalar(u8, param, '=');
            const key = kv.next() orelse continue;
            const value = kv.next() orelse continue;

            if (std.mem.eql(u8, key, "access_token")) {
                access_token = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "refresh_token")) {
                refresh_token = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "expires_in")) {
                expires_in = try std.fmt.parseInt(i64, value, 10);
            }
        }

        if (access_token.len == 0) {
            return error.QQApiError;
        }

        return QQTokenResponse{
            .access_token = access_token,
            .refresh_token = refresh_token,
            .expires_in = expires_in,
        };
    }

    /// 获取用户 OpenID
    pub fn getOpenID(self: *Self, access_token: []const u8) ![]const u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/oauth2.0/me?access_token={s}",
            .{ QQ_API_BASE, access_token },
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

        // QQ 返回格式：callback( {"client_id":"YOUR_APPID","openid":"YOUR_OPENID"} );
        // 需要提取 JSON 部分
        const start = std.mem.indexOf(u8, response_body, "{") orelse return error.QQApiError;
        const end = std.mem.lastIndexOf(u8, response_body, "}") orelse return error.QQApiError;
        const json_str = response_body[start .. end + 1];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, json_str, .{});
        defer parsed.deinit();

        const root = parsed.value.object;
        const openid = root.get("openid").?.string;

        return try self.allocator.dupe(u8, openid);
    }

    /// 获取用户信息
    pub fn getUserInfo(self: *Self, access_token: []const u8, openid: []const u8) !QQUserInfo {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/user/get_user_info?access_token={s}&oauth_consumer_key={s}&openid={s}",
            .{ QQ_API_BASE, access_token, self.config.app_id, openid },
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

        if (root.get("ret")) |ret| {
            const ret_code = ret.integer;
            if (ret_code != 0) {
                const msg = root.get("msg").?.string;
                std.log.err("QQ API 错误: {s}", .{msg});
                return error.QQApiError;
            }
        }

        return QQUserInfo{
            .openid = try self.allocator.dupe(u8, openid),
            .nickname = try self.allocator.dupe(u8, root.get("nickname").?.string),
            .figureurl_qq = if (root.get("figureurl_qq_2")) |v| try self.allocator.dupe(u8, v.string) else "",
            .gender = if (root.get("gender")) |v| try self.allocator.dupe(u8, v.string) else "",
            .province = if (root.get("province")) |v| try self.allocator.dupe(u8, v.string) else "",
            .city = if (root.get("city")) |v| try self.allocator.dupe(u8, v.string) else "",
        };
    }

    /// 刷新访问令牌
    pub fn refreshAccessToken(self: *Self, refresh_token: []const u8) !QQTokenResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/oauth2.0/token?grant_type=refresh_token&client_id={s}&client_secret={s}&refresh_token={s}",
            .{ QQ_API_BASE, self.config.app_id, self.config.app_key, refresh_token },
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

        var access_token: []const u8 = "";
        var new_refresh_token: []const u8 = "";
        var expires_in: i64 = 7200;

        var params = std.mem.splitScalar(u8, response_body, '&');
        while (params.next()) |param| {
            var kv = std.mem.splitScalar(u8, param, '=');
            const key = kv.next() orelse continue;
            const value = kv.next() orelse continue;

            if (std.mem.eql(u8, key, "access_token")) {
                access_token = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "refresh_token")) {
                new_refresh_token = try self.allocator.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "expires_in")) {
                expires_in = try std.fmt.parseInt(i64, value, 10);
            }
        }

        if (access_token.len == 0) {
            return error.QQApiError;
        }

        return QQTokenResponse{
            .access_token = access_token,
            .refresh_token = new_refresh_token,
            .expires_in = expires_in,
        };
    }
};
