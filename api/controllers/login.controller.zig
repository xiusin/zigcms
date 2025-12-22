//! 用户认证控制器 (Login Controller)
//!
//! 处理用户登录、注册等认证相关的 HTTP 请求。
//!
//! ## 功能
//! - 用户注册：创建新用户账号
//! - 用户登录：验证凭据并生成 JWT token
//!
//! ## 使用示例
//! ```zig
//! const LoginController = @import("api/controllers/login.controller.zig");
//! var ctrl = LoginController.init(allocator, logger);
//!
//! // 注册路由
//! router.post("/api/register", &ctrl, ctrl.register);
//! router.post("/api/login", &ctrl, ctrl.login);
//! ```

// 标准库

const std = @import("std");

const Allocator = std.mem.Allocator;



// 第三方库

const zap = @import("zap");

const pretty = @import("pretty");



// 项目内部模块

const log_mod = @import("../../application/services/logger/logger.zig");

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
logger: *log_mod.Logger,

pub fn init(allocator: Allocator, logger: *log_mod.Logger) Self {
    return .{ .allocator = allocator, .logger = logger };
}

/// 用户注册

pub fn register(self: *Self, req: zap.Request) !void {

    req.parseBody() catch |e| return base.send_error(req, e);



    var dto: dtos.user.Register = undefined;

    var dto_needs_free = false;

    if (req.body) |body| {

        dto = json_mod.JSON.decode(dtos.user.Register, self.allocator, body) catch |e| return base.send_error(req, e);

        dto_needs_free = true;

    }

    defer {

        if (dto_needs_free) {

            self.allocator.free(dto.username);

            self.allocator.free(dto.password);

        }

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
    var dto_needs_free = false;
    if (req.body) |body| {
        dto = json_mod.JSON.decode(dtos.user.Login, self.allocator, body) catch |e| return base.send_error(req, e);
        dto_needs_free = true;
    }
    defer {
        if (dto_needs_free) {
            self.allocator.free(dto.username);
            self.allocator.free(dto.password);
        }
    }

    if (dto.password.len == 0 or dto.username.len == 0) {
        return base.send_failed(req, "缺少必要参数");
    }

    self.logger.info("用户登录: {s}", .{dto.username});

    // 使用 ORM 查询用户
    var q = Admin.WhereEq("username", dto.username);
    defer q.deinit();

    const user_opt = q.first() catch |e| return base.send_error(req, e);
    if (user_opt == null) {
        return base.send_failed(req, "用户不存在");
    }

    var user = user_opt.?;
    defer Admin.freeModel(self.allocator, &user);

    if (user.id) |user_id| {
        if (user_id == 0) {
            return base.send_failed(req, "用户不存在");
        }
    } else {
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
