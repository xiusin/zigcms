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
    return .{ .allocator = allocator };
}

/// 获取按钮权限选项接口。
pub const button_perms = buttonPermsImpl;

/// 角色权限保存接口。
pub const role_permissions_save = rolePermissionsSaveImpl;

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
