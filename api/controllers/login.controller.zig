const std = @import("std");
const Allocator = std.mem.Allocator;

const zap = @import("zap");
const pretty = @import("pretty");
const jwt = @import("../../shared/utils/jwt.zig");

const global = @import("../../shared/primitives/global.zig");
const base = @import("base.fn.zig");
const dtos = @import("../dto/mod.zig");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const json_mod = @import("../../application/services/json/json.zig");

const Self = @This();

// ORM 模型别名
const Admin = orm_models.Admin;

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

/// 用户注册
pub fn register(self: *Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);

    var dto: dtos.user.Register = undefined;
    if (req.body) |body| {
        dto = json_mod.JSON.decode(dtos.user.Register, self.allocator, body) catch |e| return base.send_error(req, e);
    }

    if (dto.password.len == 0 or dto.username.len == 0) {
        return base.send_error(req, error.ParamMiss);
    }

    // 使用 ORM 检查用户是否存在
    var q = Admin.WhereEq("username", dto.username);
    defer q.deinit();
    const exists = q.exists() catch |e| return base.send_error(req, e);

    if (exists) {
        return base.send_failed(req, "用户已存在");
    }

    // 使用 ORM 创建用户
    var new_user = Admin.Create(.{
        .username = dto.username,
        .password = dto.password,
        .create_time = std.time.microTimestamp(),
        .update_time = std.time.microTimestamp(),
    }) catch |e| return base.send_error(req, e);
    defer Admin.freeModel(self.allocator, &new_user);

    return base.send_ok(req, .{
        .id = new_user.id,
        .username = new_user.username,
    });
}

/// 用户登录
pub fn login(self: *Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    var dto: dtos.user.Login = undefined;
    if (req.body) |body| {
        dto = json_mod.JSON.decode(dtos.user.Login, self.allocator, body) catch |e| return base.send_error(req, e);
    }

    if (dto.password.len == 0 or dto.username.len == 0) {
        return base.send_failed(req, "缺少必要参数");
    }

    std.log.info("用户登录: {s}", .{dto.username});

    // 使用 ORM 查询用户
    var q = Admin.WhereEq("username", dto.username);
    defer q.deinit();

    const user_opt = q.first() catch |e| return base.send_error(req, e);
    if (user_opt == null) {
        return base.send_failed(req, "用户不存在");
    }

    var user = user_opt.?;
    defer Admin.freeModel(self.allocator, &user);

    if (user.id == null or user.id.? == 0) {
        return base.send_failed(req, "用户不存在");
    }

    if (!std.mem.eql(u8, user.password, dto.password)) {
        return base.send_failed(req, "密码错误, 请重试");
    }

    // 生成 JWT token
    const payload = .{
        .sub = user.id.?,
        .name = user.username,
        .iat = std.time.timestamp() + 3600 * 24,
    };
    const token = jwt.encode(self.allocator, .{ .alg = .HS256 }, payload, .{
        .secret = global.JwtTokenSecret,
    }) catch return base.send_failed(req, "生成 token 失败");
    defer self.allocator.free(token);

    base.send_ok(req, .{
        .token = token,
        .user = .{
            .id = user.id,
            .username = user.username,
            .email = user.email,
            .phone = user.phone,
        },
    });
}
