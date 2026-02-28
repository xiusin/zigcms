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

const jwt = @import("../../core/utils/jwt.zig");

const global = @import("../../core/primitives/global.zig");

const base = @import("base.fn.zig");

const dtos = @import("../dto/mod.zig");

const orm_models = @import("../../domain/entities/orm_models.zig");
const json_mod = @import("../../application/services/json/json.zig");
const AuthService = @import("../services/auth_service.zig").AuthService;
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");

const Self = @This();
const replacement_marker = "\xEF\xBF\xBD";

// ORM 模型别名
const Admin = orm_models.Admin;

const OrmSysAdmin = sql.defineWithConfig(models.SysAdmin, .{
    .table_name = "sys_admin",
    .primary_key = "id",
});

const AdminRole = struct {
    id: ?i32 = null,
    admin_id: i32,
    role_id: i32,
    created_at: ?i64 = null,
};

const OrmAdminRole = sql.defineWithConfig(AdminRole, .{
    .table_name = "sys_admin_role",
    .primary_key = "id",
});

const OrmSysDept = sql.defineWithConfig(models.SysDept, .{
    .table_name = "sys_dept",
    .primary_key = "id",
});

const OrmSysRole = sql.defineWithConfig(models.SysRole, .{
    .table_name = "sys_role",
    .primary_key = "id",
});

allocator: Allocator,
logger: *log_mod.Logger,
auth_service: *AuthService,

pub fn init(allocator: Allocator, logger: *log_mod.Logger, auth_service: *AuthService) Self {
    if (!OrmSysAdmin.hasDb()) {
        OrmSysAdmin.use(global.get_db());
    }
    if (!OrmAdminRole.hasDb()) {
        OrmAdminRole.use(global.get_db());
    }
    if (!OrmSysDept.hasDb()) {
        OrmSysDept.use(global.get_db());
    }
    if (!OrmSysRole.hasDb()) {
        OrmSysRole.use(global.get_db());
    }
    return .{
        .allocator = allocator,
        .logger = logger,
        .auth_service = auth_service,
    };
}

/// 会员登录接口（ecom-admin 联调）。
pub fn memberLogin(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(dtos.user.Login, self.allocator, body) catch {
        return base.send_failed(req, "请求参数格式错误");
    };
    defer {
        self.allocator.free(dto.username);
        self.allocator.free(dto.password);
    }

    if (dto.username.len == 0 or dto.password.len == 0) {
        return base.send_failed(req, "用户名或密码不能为空");
    }

    const client_ip = req.getHeader("x-forwarded-for") orelse "";
    const client_ua = req.getHeader("user-agent") orelse "";

    const auth_result = self.auth_service.login(dto.username, dto.password) catch |err| switch (err) {
        error.UserNotFound => {
            self.logger.warn("[auth][member_login] 用户不存在 username={s} ip={s} ua={s}", .{ dto.username, client_ip, client_ua });
            return base.send_failed(req, "用户不存在");
        },
        error.InvalidPassword => {
            self.logger.warn("[auth][member_login] 密码错误 username={s} ip={s} ua={s}", .{ dto.username, client_ip, client_ua });
            return base.send_failed(req, "密码错误, 请重试");
        },
        else => return base.send_error(req, err),
    };

    var user = auth_result.user;
    const token = auth_result.token;
    defer {
        Admin.freeModel(&user);
        self.allocator.free(token);
    }

    const admin_id = user.id orelse 0;
    const role_info = try self.resolveRoleInfo(admin_id);
    defer if (role_info.role_ids_owner) |owner| self.allocator.free(owner);
    defer if (role_info.role_text_owner) |owner| self.allocator.free(owner);

    const dept_info = try self.resolveDeptInfo(user.dept_id);
    defer if (dept_info.department_name_owner) |owner| self.allocator.free(owner);

    self.warnReplacementIfNeeded(&.{
        .{ .field = "username", .value = user.username },
        .{ .field = "nickname", .value = user.nickname },
        .{ .field = "department_name", .value = dept_info.department_name },
        .{ .field = "role_text", .value = role_info.role_text },
    });

    base.send_ok(req, .{
        .token = token,
        .userId = admin_id,
        .username = user.username,
        .nickname = user.nickname,
        .avatar = user.avatar,
        .email = user.email,
        .mobile = user.mobile,
        .department_id = dept_info.department_id,
        .department_name = dept_info.department_name,
        .role_id = role_info.primary_role_id,
        .role_ids = role_info.role_ids,
        .role_text = role_info.role_text,
        .status = user.status,
        .pages = defaultPages(),
        .buttons = defaultButtons(),
        .created_at = "",
        .expire = std.time.timestamp() + 3600 * 24,
        .expires_in = @as(i64, 3600 * 24),
    });
}

/// 会员信息刷新接口（ecom-admin 联调）。
pub fn memberRefreshInfo(self: *Self, req: zap.Request) !void {
    const auth_ctx = self.resolveAuthContext(req) catch |err| switch (err) {
        error.Unauthorized => return sendUnauthorized(req, "登录已失效，请重新登录"),
        else => return base.send_error(req, err),
    };
    var user = auth_ctx.user;
    defer OrmSysAdmin.freeModel(&user);

    const admin_id = user.id orelse 0;
    const role_info = try self.resolveRoleInfo(admin_id);
    defer if (role_info.role_ids_owner) |owner| self.allocator.free(owner);
    const dept_info = try self.resolveDeptInfo(user.dept_id);

    base.send_ok(req, .{
        .token = auth_ctx.token,
        .userId = admin_id,
        .username = user.username,
        .nickname = user.nickname,
        .avatar = user.avatar,
        .email = user.email,
        .mobile = user.mobile,
        .department_id = dept_info.department_id,
        .department_name = dept_info.department_name,
        .role_ids = role_info.role_ids,
        .role_text = role_info.role_text,
        .status = user.status,
        .pages = defaultPages(),
        .buttons = defaultButtons(),
        .expires_in = auth_ctx.expires_in,
        .expire_soon = auth_ctx.expires_in <= 60,
        .server_time = std.time.timestamp(),
    });
}

/// 会员权限刷新接口（ecom-admin 联调）。
pub fn memberRefreshPermissions(self: *Self, req: zap.Request) !void {
    const auth_ctx = self.resolveAuthContext(req) catch |err| switch (err) {
        error.Unauthorized => return sendUnauthorized(req, "登录已失效，请重新登录"),
        else => return base.send_error(req, err),
    };
    var user = auth_ctx.user;
    defer OrmSysAdmin.freeModel(&user);

    const admin_id: i32 = user.id orelse 0;
    const role_info = try self.resolveRoleInfo(admin_id);
    defer if (role_info.role_ids_owner) |owner| self.allocator.free(owner);

    base.send_ok(req, .{
        .pages = defaultPages(),
        .buttons = defaultButtons(),
        .role_ids = role_info.role_ids,
    });
}

/// 兼容前端登录路径。
pub const member_login = memberLogin;

/// 兼容前端用户信息刷新路径。
pub const member_refresh_info = memberRefreshInfo;

/// 兼容前端权限刷新路径。
pub const member_refresh_permissions = memberRefreshPermissions;

/// 解析当前请求的登录上下文。
fn resolveAuthContext(self: *Self, req: zap.Request) !struct {
    token: []const u8,
    user: models.SysAdmin,
    expires_in: i64,
} {
    const authorization = req.getHeader("authorization") orelse return error.Unauthorized;
    var token = authorization;
    if (std.mem.startsWith(u8, authorization, "Bearer ")) {
        token = authorization[7..];
    }

    if (token.len == 0) return error.Unauthorized;

    // 去除前后空白，避免粘贴/换行导致 JWT 解析失败
    token = std.mem.trim(u8, token, " \t\r\n");

    // 使用注入的日志服务打印授权头，便于排查令牌问题
    self.logger.info("[auth] resolveAuthContext token={s} token len = {d}", .{ token, token.len });

    // 记录调用方信息，方便排查来源
    const method = req.method orelse "";
    const path = req.path orelse "";
    const client_ip = req.getHeader("x-forwarded-for") orelse req.getHeader("x-real-ip") orelse "";
    const ua = req.getHeader("user-agent") orelse "";
    self.logger.info("[auth] resolveAuthContext caller method={s} path={s} ip={s} ua={s}", .{ method, path, client_ip, ua });

    const payload = jwt.decode(self.allocator, token, .{
        .secret = global.JwtTokenSecret,
        .verify_signature = true,
    }) catch |err| {
        self.logger.err("[auth] resolveAuthContext decode failed err={any} token_len={d}", .{ err, token.len });

        return error.Unauthorized;
    };

    defer {
        if (payload.username.len > 0) self.allocator.free(payload.username);
        if (payload.email.len > 0) self.allocator.free(payload.email);
    }

    // 使用注入的日志服务打印JWT载荷，便于排查令牌问题
    self.logger.info("[auth] resolveAuthContext payload.user_id={d} payload.exp={d}", .{ payload.user_id, payload.exp });

    if (payload.user_id <= 0) return error.Unauthorized;

    const now = std.time.timestamp();
    const expires_in: i64 = if (payload.exp > now) payload.exp - now else 0;

    const user_opt = OrmSysAdmin.Find(@as(i32, @intCast(payload.user_id))) catch |err| return err;

    // 使用注入的日志服务打印用户信息，便于排查用户问题
    if (user_opt != null) {
        self.logger.info("[auth] resolveAuthContext user_opt.user_id={any} user_opt.username={s}", .{ user_opt.?.id, user_opt.?.username });
    } else {
        self.logger.warn("[auth] resolveAuthContext user_opt is null for payload.user_id={any}", .{payload.user_id});
    }

    if (user_opt == null) return error.Unauthorized;

    return .{
        .token = token,
        .user = user_opt.?,
        .expires_in = expires_in,
    };
}

/// 返回未授权响应。
fn sendUnauthorized(req: zap.Request, message: []const u8) void {
    const ser = json_mod.JSON.encode(global.get_allocator(), .{
        .code = 401,
        .msg = message,
    }) catch return;
    defer global.get_allocator().free(ser);
    req.sendJson(ser) catch return;
}

/// 解析管理员的角色信息。
fn resolveRoleInfo(self: *Self, admin_id: i32) !struct {
    role_ids: []const i32,
    role_ids_owner: ?[]i32,
    primary_role_id: i32,
    role_text: []const u8,
    role_text_owner: ?[]u8,
} {
    var q = OrmAdminRole.WhereEq("admin_id", admin_id);
    defer q.deinit();
    const rels = q.get() catch null;
    if (rels == null or rels.?.len == 0) {
        if (rels) |rows| OrmAdminRole.freeModels(rows);
        return .{
            .role_ids = &.{1},
            .role_ids_owner = null,
            .primary_role_id = 1,
            .role_text = "超级管理员",
            .role_text_owner = null,
        };
    }

    const rows = rels.?;
    defer OrmAdminRole.freeModels(rows);

    const owned_ids = try self.allocator.alloc(i32, rows.len);
    for (rows, 0..) |rel, idx| {
        owned_ids[idx] = rel.role_id;
    }

    const primary = owned_ids[0];
    var role_text: []const u8 = "超级管理员";
    var role_text_owner: ?[]u8 = null;

    const role_opt = OrmSysRole.Find(primary) catch null;
    if (role_opt) |role| {
        var role_mut = role;
        defer OrmSysRole.freeModel(&role_mut);
        if (role_mut.role_name.len > 0) {
            const copied = try self.allocator.dupe(u8, role_mut.role_name);
            role_text = copied;
            role_text_owner = copied;
        }
    }

    return .{
        .role_ids = owned_ids,
        .role_ids_owner = owned_ids,
        .primary_role_id = primary,
        .role_text = role_text,
        .role_text_owner = role_text_owner,
    };
}

/// 解析管理员所属部门信息。
fn resolveDeptInfo(self: *Self, dept_id_opt: ?i32) !struct {
    department_id: i32,
    department_name: []const u8,
    department_name_owner: ?[]u8,
} {
    if (dept_id_opt) |dept_id| {
        const dept_opt = OrmSysDept.Find(dept_id) catch null;
        if (dept_opt) |dept| {
            var dept_mut = dept;
            defer OrmSysDept.freeModel(&dept_mut);
            if (dept_mut.dept_name.len > 0) {
                const copied = try self.allocator.dupe(u8, dept_mut.dept_name);
                return .{
                    .department_id = dept_id,
                    .department_name = copied,
                    .department_name_owner = copied,
                };
            }
            return .{
                .department_id = dept_id,
                .department_name = dept_mut.dept_name,
                .department_name_owner = null,
            };
        }
    }

    return .{
        .department_id = 0,
        .department_name = "",
        .department_name_owner = null,
    };
}

/// 返回默认页面权限。
fn defaultPages() []const []const u8 {
    return &.{ "system", "user", "role", "department", "order", "product" };
}

/// 返回默认按钮权限。
fn defaultButtons() []const []const u8 {
    return &.{ "btn:add", "btn:edit", "btn:delete", "btn:export", "btn:import", "btn:query" };
}

fn warnReplacementIfNeeded(self: *Self, list: []const struct { field: []const u8, value: []const u8 }) void {
    for (list) |item| {
        if (item.value.len == 0) continue;
        if (std.mem.indexOf(u8, item.value, replacement_marker) != null) {
            self.logger.warn(
                "[auth][utf8_guard] field={s} contains replacement char, raw={s}",
                .{ item.field, item.value },
            );
        }
    }
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
    defer Admin.freeModel(&new_user);

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
        Admin.freeModel(&user);
        self.allocator.free(token);
    }

    base.send_ok(req, .{
        .token = token,
        .user = .{
            .id = user.id,
            .username = user.username,
        },
    });
}
