//! GitHub OAuth 服务
//!
//! 实现 GitHub OAuth 2.0 授权登录
//! 文档：https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;
const json = std.json;

const GITHUB_API_BASE = "https://api.github.com";
const GITHUB_OAUTH_BASE = "https://github.com";

/// GitHub OAuth 配置
pub const GitHubConfig = struct {
    /// 客户端 ID (Client ID)
    client_id: []const u8,
    /// 客户端密钥 (Client Secret)
    client_secret: []const u8,
    /// 回调地址
    redirect_uri: []const u8,
};

/// GitHub 用户信息
pub const GitHubUserInfo = struct {
    id: i64,
    login: []const u8,
    name: []const u8 = "",
    email: []const u8 = "",
    avatar_url: []const u8 = "",
    bio: []const u8 = "",
    location: []const u8 = "",
    company: []const u8 = "",
};

/// GitHub Token 响应
pub const GitHubTokenResponse = struct {
    access_token: []const u8,
    token_type: []const u8,
    scope: []const u8,
};

/// GitHub OAuth 服务
pub const GitHubOAuthService = struct {
    allocator: Allocator,
    config: GitHubConfig,

    const Self = @This();

    pub fn init(allocator: Allocator, config: GitHubConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// 获取用户访问令牌
    /// 文档：https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#2-users-are-redirected-back-to-your-site-by-github
    pub fn getUserAccessToken(self: *Self, code: []const u8) !GitHubTokenResponse {
        const url = GITHUB_OAUTH_BASE ++ "/login/oauth/access_token";

        // 构建请求体
        const body = try std.fmt.allocPrint(
            self.allocator,
            "client_id={s}&client_secret={s}&code={s}&redirect_uri={s}",
            .{ self.config.client_id, self.config.client_secret, code, self.config.redirect_uri },
        );
        defer self.allocator.free(body);

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .POST,
            .payload = body,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
                .{ .name = "Accept", .value = "application/json" },
            },
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        // 检查错误
        if (root.get("error")) |err_obj| {
            const error_msg = err_obj.string;
            std.log.err("GitHub API 错误: {s}", .{error_msg});
            return error.GitHubApiError;
        }

        return GitHubTokenResponse{
            .access_token = try self.allocator.dupe(u8, root.get("access_token").?.string),
            .token_type = try self.allocator.dupe(u8, root.get("token_type").?.string),
            .scope = try self.allocator.dupe(u8, root.get("scope").?.string),
        };
    }

    /// 获取用户信息
    /// 文档：https://docs.github.com/en/rest/users/users#get-the-authenticated-user
    pub fn getUserInfo(self: *Self, access_token: []const u8) !GitHubUserInfo {
        const url = GITHUB_API_BASE ++ "/user";

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{access_token});
        defer self.allocator.free(auth_header);

        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .GET,
            .extra_headers = &.{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Accept", .value = "application/vnd.github+json" },
                .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            },
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const root = parsed.value.object;

        return GitHubUserInfo{
            .id = root.get("id").?.integer,
            .login = try self.allocator.dupe(u8, root.get("login").?.string),
            .name = if (root.get("name")) |v| if (v != .null) try self.allocator.dupe(u8, v.string) else "" else "",
            .email = if (root.get("email")) |v| if (v != .null) try self.allocator.dupe(u8, v.string) else "" else "",
            .avatar_url = if (root.get("avatar_url")) |v| try self.allocator.dupe(u8, v.string) else "",
            .bio = if (root.get("bio")) |v| if (v != .null) try self.allocator.dupe(u8, v.string) else "" else "",
            .location = if (root.get("location")) |v| if (v != .null) try self.allocator.dupe(u8, v.string) else "" else "",
            .company = if (root.get("company")) |v| if (v != .null) try self.allocator.dupe(u8, v.string) else "" else "",
        };
    }

    /// 获取用户邮箱（如果主接口未返回）
    /// 文档：https://docs.github.com/en/rest/users/emails#list-email-addresses-for-the-authenticated-user
    pub fn getUserEmails(self: *Self, access_token: []const u8) ![]const u8 {
        const url = GITHUB_API_BASE ++ "/user/emails";

        var client = http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{access_token});
        defer self.allocator.free(auth_header);

        var response_writer = try std.io.Writer.Allocating.initCapacity(self.allocator, 4096);
        defer response_writer.deinit();

        _ = try client.fetch(.{
            .location = .{ .uri = uri },
            .method = .GET,
            .extra_headers = &.{
                .{ .name = "Authorization", .value = auth_header },
                .{ .name = "Accept", .value = "application/vnd.github+json" },
                .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            },
            .response_writer = &response_writer.writer,
        });

        const response_body = response_writer.writer.buffer[0..response_writer.writer.end];

        const parsed = try json.parseFromSlice(json.Value, self.allocator, response_body, .{});
        defer parsed.deinit();

        const emails = parsed.value.array;

        // 查找主邮箱
        for (emails.items) |email_obj| {
            const obj = email_obj.object;
            const is_primary = obj.get("primary").?.bool;
            if (is_primary) {
                return try self.allocator.dupe(u8, obj.get("email").?.string);
            }
        }

        // 如果没有主邮箱，返回第一个
        if (emails.items.len > 0) {
            const first = emails.items[0].object;
            return try self.allocator.dupe(u8, first.get("email").?.string);
        }

        return "";
    }
};
