//! 认证应用服务 (Auth Application Service)
//!
//! 处理用户登录、注册等核心业务逻辑。

const std = @import("std");
const Allocator = std.mem.Allocator;
const orm_models = @import("../../domain/entities/orm_models.zig");
const Admin = orm_models.Admin;
const jwt = @import("../../shared/utils/jwt.zig");
const global = @import("../../shared/primitives/global.zig");

pub const AuthService = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) AuthService {
        return .{ .allocator = allocator };
    }

    /// 注册新管理员
    pub fn register(self: *AuthService, username: []const u8, password: []const u8) !orm_models.Admin.Model {
        _ = self;
        // 检查用户是否存在
        var q = Admin.WhereEq("username", username);
        defer q.deinit();

        if (try q.exists()) {
            return error.UserAlreadyExists;
        }

        // 创建用户
        return try Admin.Create(.{
            .username = username,
            .password = password,
            .create_time = std.time.microTimestamp(),
            .update_time = std.time.microTimestamp(),
        });
    }

    /// 管理员登录
    pub fn login(self: *AuthService, username: []const u8, password: []const u8) !struct { token: []const u8, user: orm_models.Admin.Model } {
        var q = Admin.WhereEq("username", username);
        defer q.deinit();

        const user_opt = try q.first();
        if (user_opt == null) return error.UserNotFound;

        var user = user_opt.?;
        if (!std.mem.eql(u8, user.password, password)) {
            Admin.freeModel(self.allocator, &user);
            return error.InvalidPassword;
        }

        // 生成 JWT token
        const payload = .{
            .sub = user.id.?,
            .name = user.username,
            .iat = std.time.timestamp(),
            .exp = std.time.timestamp() + 3600 * 24,
        };

        const token = try jwt.encode(self.allocator, .{ .alg = .HS256 }, payload, .{
            .secret = global.JwtTokenSecret,
        });

        return .{ .token = token, .user = user };
    }
};
