//! 认证应用服务 (Auth Application Service)
//!
//! 处理用户登录、注册等核心业务逻辑。

const std = @import("std");
const Allocator = std.mem.Allocator;
const orm_models = @import("../../domain/entities/orm_models.zig");
const Admin = orm_models.Admin;
const jwt = @import("../../core/utils/jwt.zig");
const global = @import("../../core/primitives/global.zig");
const strings = @import("../../core/utils/strings.zig");
const datetime = @import("../../application/services/datetime/datetime.zig");

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
        const pwd_hash = try strings.md5(global.get_allocator(), password);
        defer global.get_allocator().free(pwd_hash);

        return try Admin.Create(.{
            .username = username,
            .password_hash = pwd_hash,
        });
    }

    /// 管理员登录
    pub fn login(self: *AuthService, username: []const u8, password: []const u8) !struct { token: []const u8, user: orm_models.Admin.Model } {
        var q = Admin.WhereEq("username", username);
        defer q.deinit();

        const user_opt = try q.first();
        if (user_opt == null) return error.UserNotFound;

        var user = user_opt.?;
        const pwd_hash = try strings.md5(self.allocator, password);
        defer self.allocator.free(pwd_hash);

        if (!std.mem.eql(u8, user.password_hash, pwd_hash)) {
            Admin.freeModel(self.allocator, &user);
            return error.InvalidPassword;
        }

        // 登录成功后回写最近登录时间（不影响登录主流程）
        if (user.id) |user_id| {
            var ts_buf: [32]u8 = undefined;
            const now_dt = datetime.DateTime.now();
            const now_str = now_dt.formatGo("2006-01-02 15:04:05", &ts_buf);
            _ = Admin.Update(user_id, .{
                .last_login = now_str,
                .updated_at = now_str,
            }) catch |err| blk: {
                std.log.warn("[auth] update last_login failed, user_id={d}, err={s}", .{ user_id, @errorName(err) });
                break :blk 0;
            };
        }

        // 生成 JWT token
        const payload = .{
            .user_id = user.id.?,
            .username = user.username,
            .email = user.email,
            .iat = std.time.timestamp(),
            .exp = std.time.timestamp() + 3600 * 24,
        };

        const token = try jwt.encode(self.allocator, .{ .alg = .HS256 }, payload, .{
            .secret = global.JwtTokenSecret,
        });

        return .{ .token = token, .user = user };
    }
};
