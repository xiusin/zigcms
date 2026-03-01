const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const SysPermission = struct {
    id: ?i32 = null,
    perm_name: []const u8 = "",
    perm_code: []const u8 = "",
    menu_id: i32 = 0,
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

const OrmPermission = sql.defineWithConfig(SysPermission, .{
    .table_name = "sys_permission",
    .primary_key = "id",
});

const OrmRoleMenu = sql.defineWithConfig(models.SysRoleMenu, .{
    .table_name = "sys_role_menu",
    .primary_key = "id",
});

const OrmRolePermission = sql.defineWithConfig(models.SysRolePermission, .{
    .table_name = "sys_role_permission",
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

const OrmSysRole = sql.defineWithConfig(models.SysRole, .{
    .table_name = "sys_role",
    .primary_key = "id",
});

const ROLE_CACHE_VERSION_KEY = "sys:role:list:version";

/// 初始化角色扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmPermission.hasDb()) {
        OrmPermission.use(global.get_db());
    }
    if (!OrmRoleMenu.hasDb()) {
        OrmRoleMenu.use(global.get_db());
    }
    if (!OrmRolePermission.hasDb()) {
        OrmRolePermission.use(global.get_db());
    }
    if (!OrmAdminRole.hasDb()) {
        OrmAdminRole.use(global.get_db());
    }
    if (!OrmSysRole.hasDb()) {
        OrmSysRole.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 获取按钮权限选项接口。
pub const button_perms = buttonPermsImpl;

/// 角色权限保存接口。
pub const role_permissions_save = rolePermissionsSaveImpl;

/// 角色权限查询接口。
pub const role_permissions_get = rolePermissionsGetImpl;

/// 角色删除接口。
pub const delete = deleteImpl;

/// 读取角色列表缓存版本。
pub fn getRoleCacheVersion(allocator: Allocator) []const u8 {
    const db = global.get_db();
    if (db.kv_get(allocator, ROLE_CACHE_VERSION_KEY)) |version| {
        return version;
    } else |_| {}
    return "0";
}

/// 刷新角色列表缓存版本。
pub fn bumpRoleCacheVersion(allocator: Allocator) void {
    const db = global.get_db();
    const now = std.time.timestamp();
    const version = std.fmt.allocPrint(allocator, "{d}", .{now}) catch return;
    defer allocator.free(version);
    db.kv_set(ROLE_CACHE_VERSION_KEY, version) catch {};
}

/// 返回按钮权限候选列表。
fn buttonPermsImpl(self: *Self, req: zap.Request) !void {
    var q = OrmPermission.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmPermission.freeModels(rows);

    if (rows.len == 0) {
        return base.send_ok(req, defaultPerms());
    }

    var options = std.ArrayListUnmanaged(struct { label: []const u8, value: []const u8 }){};
    defer options.deinit(self.allocator);

    for (rows) |row| {
        options.append(self.allocator, .{
            .label = row.perm_name,
            .value = row.perm_code,
        }) catch {};
    }

    base.send_ok(req, options.items);
}

/// 保存角色菜单和按钮权限。
fn rolePermissionsSaveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");

    const role_id_val = parsed.value.object.get("role_id") orelse return base.send_failed(req, "缺少 role_id 参数");
    const menu_ids_val = parsed.value.object.get("menu_ids") orelse return base.send_failed(req, "缺少 menu_ids 参数");
    const button_perms_val = parsed.value.object.get("button_perms") orelse return base.send_failed(req, "缺少 button_perms 参数");

    if (role_id_val != .integer or menu_ids_val != .array or button_perms_val != .array) {
        return base.send_failed(req, "参数格式错误");
    }

    const role_id: i32 = @intCast(role_id_val.integer);

    var delete_menu_q = OrmRoleMenu.WhereEq("role_id", role_id);
    defer delete_menu_q.deinit();
    _ = delete_menu_q.delete() catch |err| return base.send_error(req, err);

    var delete_perm_q = OrmRolePermission.WhereEq("role_id", role_id);
    defer delete_perm_q.deinit();
    _ = delete_perm_q.delete() catch |err| return base.send_error(req, err);

    for (menu_ids_val.array.items) |menu_id_val| {
        if (menu_id_val != .integer) continue;
        _ = OrmRoleMenu.Create(.{
            .role_id = role_id,
            .menu_id = @as(i32, @intCast(menu_id_val.integer)),
        }) catch |err| return base.send_error(req, err);
    }

    for (button_perms_val.array.items, 0..) |perm_val, idx| {
        if (perm_val != .string) continue;

        var perm_q = OrmPermission.WhereEq("perm_code", perm_val.string);
        defer perm_q.deinit();
        const existed = perm_q.first() catch null;

        const permission_id: i32 = if (existed) |perm| blk: {
            break :blk perm.id orelse 0;
        } else blk: {
            var created = OrmPermission.Create(.{
                .perm_name = perm_val.string,
                .perm_code = perm_val.string,
                .menu_id = 0,
                .sort = @as(i32, @intCast(idx + 1)),
                .status = 1,
            }) catch |err| return base.send_error(req, err);
            defer OrmPermission.freeModel(&created);
            break :blk created.id orelse 0;
        };

        _ = OrmRolePermission.Create(.{
            .role_id = role_id,
            .permission_id = permission_id,
        }) catch |err| return base.send_error(req, err);
    }

    bumpRoleCacheVersion(self.allocator);

    base.send_ok(req, "权限保存成功");
}

/// 查询角色菜单与按钮权限。
fn rolePermissionsGetImpl(self: *Self, req: zap.Request) !void {
    var role_id: i32 = 0;

    req.parseQuery();
    if (req.getParamSlice("role_id")) |role_id_str| {
        role_id = std.fmt.parseInt(i32, role_id_str, 10) catch 0;
    }

    if (role_id <= 0) {
        req.parseBody() catch {};
        if (req.body) |body| {
            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
            defer if (parsed) |*p| p.deinit();
            if (parsed) |p| {
                if (p.value == .object) {
                    if (p.value.object.get("role_id")) |role_id_val| {
                        switch (role_id_val) {
                            .integer => role_id = @intCast(role_id_val.integer),
                            .string => role_id = std.fmt.parseInt(i32, role_id_val.string, 10) catch 0,
                            else => {},
                        }
                    }
                }
            }
        }
    }

    if (role_id <= 0) return base.send_failed(req, "缺少 role_id 参数");

    var role_menu_q = OrmRoleMenu.WhereEq("role_id", role_id);
    defer role_menu_q.deinit();
    const role_menus = role_menu_q.get() catch |err| return base.send_error(req, err);
    defer OrmRoleMenu.freeModels(role_menus);

    var menu_ids = std.ArrayListUnmanaged(i32){};
    defer menu_ids.deinit(self.allocator);
    for (role_menus) |row| {
        menu_ids.append(self.allocator, row.menu_id) catch {};
    }

    var role_perm_q = OrmRolePermission.WhereEq("role_id", role_id);
    defer role_perm_q.deinit();
    const role_perms = role_perm_q.get() catch |err| return base.send_error(req, err);
    defer OrmRolePermission.freeModels(role_perms);

    var button_perm_codes = std.ArrayListUnmanaged([]const u8){};
    defer button_perm_codes.deinit(self.allocator);
    var button_perm_owners = std.ArrayListUnmanaged([]u8){};
    defer {
        for (button_perm_owners.items) |owned| self.allocator.free(owned);
        button_perm_owners.deinit(self.allocator);
    }

    for (role_perms) |row| {
        const perm_opt = OrmPermission.Find(row.permission_id) catch null;
        if (perm_opt) |perm| {
            var perm_mut = perm;
            defer OrmPermission.freeModel(&perm_mut);
            if (perm_mut.perm_code.len == 0) continue;

            const owned = self.allocator.dupe(u8, perm_mut.perm_code) catch continue;
            button_perm_owners.append(self.allocator, owned) catch {};
            button_perm_codes.append(self.allocator, owned) catch {};
        }
    }

    base.send_ok(req, .{
        .menu_ids = menu_ids.items,
        .button_perms = button_perm_codes.items,
    });
}

/// 删除角色，包含限制检查。
fn deleteImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = std.fmt.parseInt(i32, id_str, 10) catch return base.send_failed(req, "id 格式错误");

    // 1. 获取角色详情检查是否为系统角色
    const role_opt = OrmSysRole.Find(id) catch |err| return base.send_error(req, err);
    if (role_opt) |role| {
        var role_mut = role;
        defer OrmSysRole.freeModel(&role_mut);
        // 系统管理员角色通常 key 为 'super_admin' 且 ID 为 1
        if (std.mem.eql(u8, role_mut.role_key, "super_admin") or id == 1) {
            return base.send_failed(req, "系统内置角色，不可删除");
        }
    } else {
        return base.send_failed(req, "该角色记录不存在");
    }

    // 2. 检查是否有用户关联此角色
    var user_role_q = OrmAdminRole.WhereEq("role_id", id);
    defer user_role_q.deinit();
    const count = user_role_q.count() catch 0;
    if (count > 0) {
        return base.send_failed(req, "该角色下仍有关联用户，请先解除关联后再尝试删除");
    }

    // 3. 执行删除操作
    _ = OrmSysRole.Destroy(@as(usize, @intCast(id))) catch |err| return base.send_error(req, err);

    // 4. 清理关联表
    var rm_q = OrmRoleMenu.WhereEq("role_id", id);
    defer rm_q.deinit();
    _ = rm_q.delete() catch {};

    var rp_q = OrmRolePermission.WhereEq("role_id", id);
    defer rp_q.deinit();
    _ = rp_q.delete() catch {};

    // 5. 刷新缓存版本
    bumpRoleCacheVersion(global.get_allocator());

    base.send_ok(req, "角色已成功删除");
}

/// 默认按钮权限列表。
fn defaultPerms() []const struct { label: []const u8, value: []const u8 } {
    return &.{
        .{ .label = "新增", .value = "btn:add" },
        .{ .label = "编辑", .value = "btn:edit" },
        .{ .label = "删除", .value = "btn:delete" },
        .{ .label = "导出", .value = "btn:export" },
        .{ .label = "导入", .value = "btn:import" },
        .{ .label = "查询", .value = "btn:query" },
        .{ .label = "详情", .value = "btn:detail" },
        .{ .label = "审核", .value = "btn:audit" },
        .{ .label = "启用", .value = "btn:enable" },
        .{ .label = "禁用", .value = "btn:disable" },
        .{ .label = "分配权限", .value = "btn:permission" },
        .{ .label = "重置密码", .value = "btn:resetPwd" },
    };
}
