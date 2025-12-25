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
const AuthService = @import("../../application/services/auth_service.zig").AuthService;

const Self = @This();

// ORM 模型别名
const Admin = orm_models.Admin;

allocator: Allocator,
logger: *log_mod.Logger,
auth_service: *AuthService,

pub fn init(allocator: Allocator, logger: *log_mod.Logger, auth_service: *AuthService) Self {
    return .{ 
        .allocator = allocator, 
        .logger = logger,
        .auth_service = auth_service,
    };
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

    // 调用 AuthService 处理注册逻辑
    var new_user = self.auth_service.register(dto.username, dto.password) catch |err| switch (err) {
        error.UserAlreadyExists => return base.send_failed(req, "用户已存在"),
        else => return base.send_error(req, err),
    };
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

    // 调用 AuthService 处理登录逻辑
    const auth_result = self.auth_service.login(dto.username, dto.password) catch |err| switch (err) {
        error.UserNotFound => return base.send_failed(req, "用户不存在"),
        error.InvalidPassword => return base.send_failed(req, "密码错误, 请重试"),
        else => return base.send_error(req, err),
    };
    var user = auth_result.user;
    const token = auth_result.token;

    defer {
        Admin.freeModel(self.allocator, &user);
        self.allocator.free(token);
    }

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
