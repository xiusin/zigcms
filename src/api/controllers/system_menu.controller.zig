const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/models.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmMenu = sql.defineWithConfig(models.SysMenu, .{
    .table_name = "sys_menu",
    .primary_key = "id",
});

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

const MenuNode = struct {
    id: i32,
    pid: i32,
    title: []const u8,
    menu_name: []const u8,
    value: i32,
    key: i32,
};

/// 初始化菜单扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmMenu.hasDb()) {
        OrmMenu.use(global.get_db());
    }
    if (!OrmPermission.hasDb()) {
        OrmPermission.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 菜单树接口。
pub const tree = treeImpl;

/// 菜单权限查询接口。
pub const permissions = permissionsImpl;

/// 菜单权限保存接口。
pub const save_permissions = savePermissionsImpl;

/// 菜单导出接口。
pub const menu_export = exportImpl;

/// 返回菜单树。
fn treeImpl(self: *Self, req: zap.Request) !void {
    var q = OrmMenu.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmMenu.freeModels(self.allocator, rows);

    var tree_data = std.ArrayListUnmanaged(MenuNode){};
    defer tree_data.deinit(self.allocator);

    for (rows) |row| {
        const id = row.id orelse 0;
        tree_data.append(self.allocator, .{
            .id = id,
            .pid = row.pid,
            .title = row.menu_name,
            .menu_name = row.menu_name,
            .value = id,
            .key = id,
        }) catch {};
    }

    base.send_ok(req, tree_data.items);
}

/// 获取菜单按钮权限代码。
fn permissionsImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const menu_id_str = req.getParamSlice("menu_id") orelse return base.send_failed(req, "缺少 menu_id 参数");
    const menu_id = std.fmt.parseInt(i32, menu_id_str, 10) catch return base.send_failed(req, "menu_id 格式错误");

    var q = OrmPermission.WhereEq("menu_id", menu_id);
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmPermission.freeModels(global.get_allocator(), rows);

    var perms = std.ArrayListUnmanaged([]const u8){};
    defer perms.deinit(global.get_allocator());
    for (rows) |row| {
        perms.append(global.get_allocator(), row.perm_code) catch {};
    }

    base.send_ok(req, .{ .permissions = perms.items });
}

/// 保存菜单按钮权限代码。
fn savePermissionsImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        return base.send_failed(req, "请求体格式错误");
    }

    const menu_id_val = parsed.value.object.get("menu_id") orelse return base.send_failed(req, "缺少 menu_id 参数");
    const permissions_val = parsed.value.object.get("permissions") orelse return base.send_failed(req, "缺少 permissions 参数");
    if (menu_id_val != .integer or permissions_val != .array) {
        return base.send_failed(req, "参数格式错误");
    }

    const menu_id: i32 = @intCast(menu_id_val.integer);

    var delete_q = OrmPermission.WhereEq("menu_id", menu_id);
    defer delete_q.deinit();
    _ = delete_q.delete() catch |err| return base.send_error(req, err);

    for (permissions_val.array.items, 0..) |perm, idx| {
        if (perm != .string) continue;
        _ = OrmPermission.Create(.{
            .perm_name = perm.string,
            .perm_code = perm.string,
            .menu_id = menu_id,
            .sort = @as(i32, @intCast(idx + 1)),
            .status = 1,
        }) catch |err| return base.send_error(req, err);
    }

    base.send_ok(req, "权限保存成功");
}

/// 返回菜单导出地址。
fn exportImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    base.send_ok(req, .{ .url = "/api/system/menu/tree" });
}
