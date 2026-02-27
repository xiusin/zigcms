const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/models.zig");
const global = @import("../../shared/primitives/global.zig");
const strings = @import("../../shared/utils/strings.zig");

const Self = @This();

allocator: Allocator,

const OrmAdmin = sql.defineWithConfig(models.SysAdmin, .{
    .table_name = "sys_admin",
    .primary_key = "id",
});

const SysAdminRole = struct {
    id: ?i32 = null,
    admin_id: i32,
    role_id: i32,
    created_at: ?i64 = null,
};

const OrmAdminRole = sql.defineWithConfig(SysAdminRole, .{
    .table_name = "sys_admin_role",
    .primary_key = "id",
});

/// 初始化管理员扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmAdmin.hasDb()) {
        OrmAdmin.use(global.get_db());
    }
    if (!OrmAdminRole.hasDb()) {
        OrmAdminRole.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 重置管理员密码接口。
pub const reset_password = resetPasswordImpl;

/// 分配管理员角色接口。
pub const assign_roles = assignRolesImpl;

/// 用户信息接口。
pub const user_info = userInfoImpl;

/// 重置管理员密码为默认值。
fn resetPasswordImpl(self: *Self, req: zap.Request) !void {
    var target_admin_id = parseIdFromReq(req) orelse return base.send_failed(req, "缺少 id 参数");
    var target_hash: []const u8 = "e10adc3949ba59abbe56e057f20f883e";
    var dynamic_hash: ?[]const u8 = null;
    defer if (dynamic_hash) |h| self.allocator.free(h);

    req.parseBody() catch {};
    if (req.body) |body| {
        var parsed_opt = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        if (parsed_opt) |*parsed| {
            defer parsed.deinit();
            if (parsed.value == .object) {
                if (parsed.value.object.get("id")) |id_val| {
                    if (id_val == .integer) {
                        target_admin_id = @intCast(id_val.integer);
                    }
                }
                if (parsed.value.object.get("password")) |pwd_val| {
                    if (pwd_val == .string and pwd_val.string.len > 0) {
                        const pwd_hash = strings.md5(self.allocator, pwd_val.string) catch return base.send_failed(req, "密码加密失败");
                        dynamic_hash = pwd_hash;
                        target_hash = pwd_hash;
                    }
                }
            }
        } else {
            var fallback = std.json.parseFromSlice(std.json.Value, global.get_allocator(), body, .{}) catch null;
            if (fallback) |*v| {
                defer v.deinit();
                if (v.value == .object) {
                    if (v.value.object.get("id")) |id_val| {
                        if (id_val == .integer) {
                            target_admin_id = @intCast(id_val.integer);
                        }
                    }
                    if (v.value.object.get("password")) |pwd_val| {
                        if (pwd_val == .string and pwd_val.string.len > 0) {
                            const pwd_hash = strings.md5(self.allocator, pwd_val.string) catch return base.send_failed(req, "密码加密失败");
                            dynamic_hash = pwd_hash;
                            target_hash = pwd_hash;
                        }
                    }
                }
            }
        }
    }

    _ = OrmAdmin.Update(target_admin_id, .{
        .password_hash = target_hash,
        .updated_at = std.time.microTimestamp(),
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, "密码重置成功");
}

/// 覆盖管理员角色关系。
fn assignRolesImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        return base.send_failed(req, "请求体格式错误");
    }

    const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id 参数");
    const role_ids_val = parsed.value.object.get("role_ids") orelse return base.send_failed(req, "缺少 role_ids 参数");

    if (id_val != .integer or role_ids_val != .array) {
        return base.send_failed(req, "参数格式错误");
    }

    const admin_id: i32 = @intCast(id_val.integer);

    var delete_q = OrmAdminRole.WhereEq("admin_id", admin_id);
    defer delete_q.deinit();
    _ = delete_q.delete() catch |err| return base.send_error(req, err);

    for (role_ids_val.array.items) |role_id_val| {
        if (role_id_val != .integer) continue;
        _ = OrmAdminRole.Create(.{
            .admin_id = admin_id,
            .role_id = @as(i32, @intCast(role_id_val.integer)),
        }) catch |err| return base.send_error(req, err);
    }

    base.send_ok(req, "角色分配成功");
}

/// 返回当前用户基础信息（联调兼容）。
fn userInfoImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id: i32 = if (req.getParamSlice("id")) |id_str|
        @intCast(strings.to_int(id_str) catch 1)
    else
        1;

    const user_opt = OrmAdmin.Find(id) catch |err| return base.send_error(req, err);
    if (user_opt) |user| {
        var user_mut = user;
        defer OrmAdmin.freeModel(self.allocator, &user_mut);
        return base.send_ok(req, .{
            .id = user_mut.id orelse id,
            .username = user_mut.username,
            .nickname = user_mut.nickname,
            .email = user_mut.email,
            .mobile = user_mut.mobile,
            .avatar = user_mut.avatar,
            .status = user_mut.status,
        });
    }

    base.send_ok(req, .{
        .id = id,
        .username = "admin",
        .nickname = "系统管理员",
        .email = "admin@zigcms.local",
        .mobile = "",
        .avatar = "",
        .status = 1,
    });
}

/// 兼容 query/body 的 id 读取。
fn parseIdFromReq(req: zap.Request) ?i32 {
    req.parseQuery();
    if (req.getParamSlice("id")) |id_str| {
        if (std.fmt.parseInt(i32, id_str, 10)) |id| {
            return id;
        } else |_| {}
    }

    req.parseBody() catch return null;
    const body = req.body orelse return null;
    var parsed = std.json.parseFromSlice(std.json.Value, global.get_allocator(), body, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value != .object) return null;
    const id_val = parsed.value.object.get("id") orelse return null;
    if (id_val != .integer) return null;
    return @intCast(id_val.integer);
}
