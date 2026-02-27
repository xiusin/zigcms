//! 系统扩展控制器
//!
//! 提供非标准 CRUD 的系统接口，覆盖组织、管理员、菜单、字典、权限等页面复杂行为。

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const strings = @import("../../shared/utils/strings.zig");
const orm_sql = @import("../../application/services/sql/orm.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

const SysDeptRow = struct {
    id: i64,
    parent_id: i64,
    dept_name: []const u8,
    dept_code: []const u8,
    leader: []const u8,
    phone: []const u8,
    email: []const u8,
    sort: i64,
    status: i64,
    remark: []const u8,
};

const DeptTreeItem = struct {
    key: i64,
    title: []const u8,
    value: i64,
    parent_id: i64,
    raw: SysDeptRow,
};

const MenuTreeItem = struct {
    id: i64,
    title: []const u8,
    menu_name: []const u8,
    pid: i64,
};

const OrmSysDict = orm_sql.define(struct {
    pub const table_name = "sys_dict";
    pub const primary_key = "id";

    id: ?i64 = null,
    dict_code: []const u8 = "",
});

const OrmSysDictItem = orm_sql.define(struct {
    pub const table_name = "sys_dict_item";
    pub const primary_key = "id";

    id: ?i64 = null,
    dict_id: i64 = 0,
    item_name: []const u8 = "",
    item_value: []const u8 = "",
    sort: i64 = 0,
    status: i64 = 1,
});

const OrmSysAdmin = orm_sql.define(struct {
    pub const table_name = "sys_admin";
    pub const primary_key = "id";

    id: ?i64 = null,
    password_hash: []const u8 = "",
    updated_at: ?i64 = null,
});

const OrmSysAdminRole = orm_sql.define(struct {
    pub const table_name = "sys_admin_role";
    pub const primary_key = "id";

    id: ?i64 = null,
    admin_id: i64 = 0,
    role_id: i64 = 0,
});

const OrmSysPermission = orm_sql.define(struct {
    pub const table_name = "sys_permission";
    pub const primary_key = "id";

    id: ?i64 = null,
    perm_name: []const u8 = "",
    perm_code: []const u8 = "",
    menu_id: i64 = 0,
    perm_type: i64 = 2,
    status: i64 = 1,
    updated_at: ?i64 = null,
});

/// 初始化扩展控制器
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

/// 部门树接口
pub const dept_tree = MW.requireAuth(deptTreeImpl);
/// 部门全量接口
pub const dept_all = MW.requireAuth(deptAllImpl);
/// 管理员重置密码
pub const admin_reset_password = MW.requireAuth(adminResetPasswordImpl);
/// 管理员分配角色
pub const admin_assign_roles = MW.requireAuth(adminAssignRolesImpl);
/// 菜单树接口
pub const menu_tree = MW.requireAuth(menuTreeImpl);
/// 菜单权限读取
pub const menu_permissions = MW.requireAuth(menuPermissionsImpl);
/// 菜单权限保存
pub const menu_save_permissions = MW.requireAuth(menuSavePermissionsImpl);
/// 菜单导出
pub const menu_export = MW.requireAuth(menuExportImpl);
/// 字典项列表
pub const dict_items = MW.requireAuth(dictItemsImpl);
/// 字典项保存
pub const dict_item_save = MW.requireAuth(dictItemSaveImpl);
/// 字典项删除
pub const dict_item_delete = MW.requireAuth(dictItemDeleteImpl);
/// 字典项单字段更新
pub const dict_item_set = MW.requireAuth(dictItemSetImpl);
/// 按钮权限选项
pub const role_button_perms = MW.requireAuth(roleButtonPermsImpl);

/// 查询部门树
fn deptTreeImpl(_: *Self, req: zap.Request) !void {
    var result = global.get_db().rawQuery(
        "SELECT id, parent_id, dept_name, dept_code, leader, phone, email, sort, status, remark FROM sys_dept WHERE deleted_at IS NULL ORDER BY sort ASC, id ASC",
        .{},
    ) catch |e| return base.send_error(req, e);
    defer result.deinit();

    var rows = std.ArrayListUnmanaged(SysDeptRow){};
    defer rows.deinit(global.get_allocator());

    while (result.next()) {
        try rows.append(global.get_allocator(), .{
            .id = @intCast(try result.get(i64, 0)),
            .parent_id = @intCast(try result.get(i64, 1)),
            .dept_name = try global.get_allocator().dupe(u8, try result.get([]const u8, 2)),
            .dept_code = try global.get_allocator().dupe(u8, try result.get([]const u8, 3)),
            .leader = try global.get_allocator().dupe(u8, try result.get([]const u8, 4)),
            .phone = try global.get_allocator().dupe(u8, try result.get([]const u8, 5)),
            .email = try global.get_allocator().dupe(u8, try result.get([]const u8, 6)),
            .sort = @intCast(try result.get(i64, 7)),
            .status = @intCast(try result.get(i64, 8)),
            .remark = try global.get_allocator().dupe(u8, try result.get([]const u8, 9)),
        });
    }

    var list = std.ArrayListUnmanaged(DeptTreeItem){};
    defer list.deinit(global.get_allocator());

    for (rows.items) |row| {
        try list.append(global.get_allocator(), .{
            .key = row.id,
            .title = row.dept_name,
            .value = row.id,
            .parent_id = row.parent_id,
            .raw = row,
        });
    }

    base.send_ok(req, list.items);
}

/// 查询部门全量列表
fn deptAllImpl(_: *Self, req: zap.Request) !void {
    var result = global.get_db().rawQuery(
        "SELECT id, dept_name FROM sys_dept WHERE deleted_at IS NULL AND status = 1 ORDER BY sort ASC, id ASC",
        .{},
    ) catch |e| return base.send_error(req, e);
    defer result.deinit();

    const Option = struct { id: i64, dept_name: []const u8 };
    var list = std.ArrayListUnmanaged(Option){};
    defer list.deinit(global.get_allocator());

    while (result.next()) {
        try list.append(global.get_allocator(), .{
            .id = @intCast(try result.get(i64, 0)),
            .dept_name = try global.get_allocator().dupe(u8, try result.get([]const u8, 1)),
        });
    }

    base.send_ok(req, list.items);
}

/// 重置管理员密码
fn adminResetPasswordImpl(_: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct { id: i64 };
    var parsed = std.json.parseFromSlice(Dto, global.get_allocator(), body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return base.send_failed(req, "参数错误");
    defer parsed.deinit();

    const default_hash = "e10adc3949ba59abbe56e057f20f883e"; // 123456 的 md5
    var query = OrmSysAdmin.query(global.get_db());
    defer query.deinit();
    _ = query.whereEq("id", parsed.value.id);
    _ = query.whereNull("deleted_at");
    _ = query.update(.{
        .password_hash = default_hash,
        .updated_at = std.time.microTimestamp(),
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .id = parsed.value.id, .reset = true });
}

/// 分配管理员角色
fn adminAssignRolesImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return base.send_failed(req, "参数错误");
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "参数错误");
    const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少管理员ID");
    if (id_val != .integer) return base.send_failed(req, "管理员ID错误");
    const admin_id: i64 = @intCast(id_val.integer);

    var del_query = OrmSysAdminRole.query(global.get_db());
    defer del_query.deinit();
    _ = del_query.whereEq("admin_id", admin_id);
    _ = del_query.delete() catch |e| return base.send_error(req, e);

    const role_ids_val = parsed.value.object.get("role_ids") orelse std.json.Value{ .array = std.json.Array.init(self.allocator) };
    if (role_ids_val == .array) {
        for (role_ids_val.array.items) |rid| {
            if (rid == .integer and rid.integer > 0) {
                _ = OrmSysAdminRole.create(global.get_db(), .{
                    .admin_id = admin_id,
                    .role_id = rid.integer,
                }) catch {};
            }
        }
    }

    base.send_ok(req, .{ .id = admin_id, .assigned = true });
}

/// 查询菜单树
fn menuTreeImpl(_: *Self, req: zap.Request) !void {
    var result = global.get_db().rawQuery(
        "SELECT id, pid, menu_name FROM sys_menu WHERE deleted_at IS NULL ORDER BY sort ASC, id ASC",
        .{},
    ) catch |e| return base.send_error(req, e);
    defer result.deinit();

    const Row = struct { id: i64, pid: i64, menu_name: []const u8 };
    var rows = std.ArrayListUnmanaged(Row){};
    defer rows.deinit(global.get_allocator());

    while (result.next()) {
        try rows.append(global.get_allocator(), .{
            .id = @intCast(try result.get(i64, 0)),
            .pid = @intCast(try result.get(i64, 1)),
            .menu_name = try global.get_allocator().dupe(u8, try result.get([]const u8, 2)),
        });
    }

    var list = std.ArrayListUnmanaged(MenuTreeItem){};
    defer list.deinit(global.get_allocator());

    for (rows.items) |row| {
        try list.append(global.get_allocator(), .{
            .id = row.id,
            .title = row.menu_name,
            .menu_name = row.menu_name,
            .pid = row.pid,
        });
    }

    base.send_ok(req, list.items);
}

/// 查询菜单按钮权限
fn menuPermissionsImpl(_: *Self, req: zap.Request) !void {
    req.parseQuery();
    const menu_id_str = req.getParamSlice("menu_id") orelse return base.send_failed(req, "缺少menu_id");
    const menu_id = strings.to_int(menu_id_str) catch return base.send_failed(req, "menu_id错误");

    var result = global.get_db().rawQuery(
        "SELECT perm_code FROM sys_permission WHERE menu_id = ? AND perm_type = 2 AND status = 1 ORDER BY id ASC",
        .{menu_id},
    ) catch |e| return base.send_error(req, e);
    defer result.deinit();

    var perms = std.ArrayListUnmanaged([]const u8){};
    defer perms.deinit(global.get_allocator());

    while (result.next()) {
        try perms.append(global.get_allocator(), try global.get_allocator().dupe(u8, try result.get([]const u8, 0)));
    }

    base.send_ok(req, .{ .permissions = perms.items });
}

/// 保存菜单按钮权限
fn menuSavePermissionsImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return base.send_failed(req, "参数错误");
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "参数错误");
    const menu_id_val = parsed.value.object.get("menu_id") orelse return base.send_failed(req, "缺少menu_id");
    if (menu_id_val != .integer) return base.send_failed(req, "menu_id错误");
    const menu_id = menu_id_val.integer;

    var del_query = OrmSysPermission.query(global.get_db());
    defer del_query.deinit();
    _ = del_query.whereEq("menu_id", menu_id);
    _ = del_query.whereEq("perm_type", @as(i64, 2));
    _ = del_query.delete() catch |e| return base.send_error(req, e);

    const perms_val = parsed.value.object.get("permissions") orelse std.json.Value{ .array = std.json.Array.init(self.allocator) };
    if (perms_val == .array) {
        for (perms_val.array.items) |perm| {
            if (perm == .string and perm.string.len > 0) {
                _ = OrmSysPermission.create(global.get_db(), .{
                    .perm_name = perm.string,
                    .perm_code = perm.string,
                    .menu_id = menu_id,
                    .perm_type = 2,
                    .status = 1,
                }) catch {};
            }
        }
    }

    base.send_ok(req, .{ .menu_id = menu_id, .saved = true });
}

/// 导出菜单数据
fn menuExportImpl(_: *Self, req: zap.Request) !void {
    base.send_ok(req, .{ .url = "/api/system/menu/list" });
}

/// 获取字典项
fn dictItemsImpl(_: *Self, req: zap.Request) !void {
    req.parseQuery();

    var query = OrmSysDictItem.query(global.get_db());
    defer query.deinit();

    if (req.getParamSlice("dict_id")) |dict_id_str| {
        const dict_id = strings.to_int(dict_id_str) catch return base.send_failed(req, "dict_id错误");
        _ = query.whereEq("dict_id", dict_id);
    } else if (req.getParamSlice("dict_code")) |dict_code| {
        var dict_query = OrmSysDict.query(global.get_db());
        defer dict_query.deinit();
        _ = dict_query.whereEq("dict_code", dict_code);
        const dict = dict_query.first() catch |e| return base.send_error(req, e);
        if (dict == null or dict.?.id == null) {
            return base.send_ok(req, .{ .list = &[_]u8{}, .items = &[_]u8{}, .total = 0 });
        }
        _ = query.whereEq("dict_id", dict.?.id.?);
    } else {
        return base.send_failed(req, "缺少dict_id或dict_code");
    }

    _ = query.orderBy("sort", .asc);
    _ = query.orderBy("id", .asc);

    const models = query.get() catch |e| return base.send_error(req, e);
    defer OrmSysDictItem.freeModels(global.get_db().allocator, models);

    const Item = struct {
        id: i64,
        dict_id: i64,
        item_name: []const u8,
        item_value: []const u8,
        sort: i64,
        status: i64,
    };

    var list = std.ArrayListUnmanaged(Item){};
    defer list.deinit(global.get_allocator());

    for (models) |model| {
        try list.append(global.get_allocator(), .{
            .id = model.id orelse 0,
            .dict_id = model.dict_id,
            .item_name = try global.get_allocator().dupe(u8, model.item_name),
            .item_value = try global.get_allocator().dupe(u8, model.item_value),
            .sort = model.sort,
            .status = model.status,
        });
    }

    base.send_ok(req, .{ .list = list.items, .items = list.items, .total = list.items.len });
}

/// 保存字典项
fn dictItemSaveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct {
        id: ?i64 = null,
        dict_id: i64,
        item_name: []const u8,
        item_value: []const u8,
        sort: i64 = 0,
        status: i64 = 1,
    };

    var parsed = std.json.parseFromSlice(Dto, self.allocator, body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return base.send_failed(req, "参数错误");
    defer parsed.deinit();

    const dto = parsed.value;
    if (dto.item_name.len == 0 or dto.item_value.len == 0) return base.send_failed(req, "字典项名称和值不能为空");

    if (dto.id != null and dto.id.? > 0) {
        _ = OrmSysDictItem.update(global.get_db(), dto.id.?, .{
            .item_name = dto.item_name,
            .item_value = dto.item_value,
            .sort = dto.sort,
            .status = dto.status,
            .updated_at = std.time.microTimestamp(),
        }) catch |e| return base.send_error(req, e);
        return base.send_ok(req, .{ .id = dto.id.?, .updated = true });
    }

    const created = OrmSysDictItem.create(global.get_db(), .{
        .dict_id = dto.dict_id,
        .item_name = dto.item_name,
        .item_value = dto.item_value,
        .sort = dto.sort,
        .status = dto.status,
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .id = created.id orelse 0, .created = true });
}

/// 删除字典项
fn dictItemDeleteImpl(_: *Self, req: zap.Request) !void {
    req.parseBody() catch {};
    req.parseQuery();

    const id_str = req.getParamSlice("id") orelse {
        const body = req.body orelse return base.send_failed(req, "缺少id");
        const Dto = struct { id: i64 };
        var parsed = std.json.parseFromSlice(Dto, global.get_allocator(), body, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        }) catch return base.send_failed(req, "参数错误");
        defer parsed.deinit();
        _ = OrmSysDictItem.destroy(global.get_db(), parsed.value.id) catch |e| return base.send_error(req, e);
        return base.send_ok(req, .{ .id = parsed.value.id, .deleted = true });
    };

    const id = strings.to_int(id_str) catch return base.send_failed(req, "id错误");
    _ = OrmSysDictItem.destroy(global.get_db(), id) catch |e| return base.send_error(req, e);
    base.send_ok(req, .{ .id = id, .deleted = true });
}

/// 单字段更新字典项
fn dictItemSetImpl(_: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct {
        id: i64,
        field: []const u8,
        value: i64,
    };

    var parsed = std.json.parseFromSlice(Dto, global.get_allocator(), body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return base.send_failed(req, "参数错误");
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.field, "status") and !std.mem.eql(u8, parsed.value.field, "sort")) {
        return base.send_failed(req, "仅支持status/sort字段更新");
    }

    if (std.mem.eql(u8, parsed.value.field, "status")) {
        _ = OrmSysDictItem.update(global.get_db(), parsed.value.id, .{
            .status = parsed.value.value,
            .updated_at = std.time.microTimestamp(),
        }) catch |e| return base.send_error(req, e);
    } else {
        _ = OrmSysDictItem.update(global.get_db(), parsed.value.id, .{
            .sort = parsed.value.value,
            .updated_at = std.time.microTimestamp(),
        }) catch |e| return base.send_error(req, e);
    }
    base.send_ok(req, .{ .id = parsed.value.id, .updated = true });
}

/// 查询角色按钮权限选项
fn roleButtonPermsImpl(_: *Self, req: zap.Request) !void {
    var result = global.get_db().rawQuery(
        "SELECT DISTINCT perm_code FROM sys_permission WHERE perm_type = 2 AND status = 1 ORDER BY perm_code ASC",
        .{},
    ) catch |e| return base.send_error(req, e);
    defer result.deinit();

    const Opt = struct { label: []const u8, value: []const u8 };
    var options = std.ArrayListUnmanaged(Opt){};
    defer options.deinit(global.get_allocator());

    while (result.next()) {
        const code = try global.get_allocator().dupe(u8, try result.get([]const u8, 0));
        try options.append(global.get_allocator(), .{ .label = code, .value = code });
    }

    if (options.items.len == 0) {
        try options.append(global.get_allocator(), .{ .label = "新增", .value = "btn:add" });
        try options.append(global.get_allocator(), .{ .label = "编辑", .value = "btn:edit" });
        try options.append(global.get_allocator(), .{ .label = "删除", .value = "btn:delete" });
        try options.append(global.get_allocator(), .{ .label = "导出", .value = "btn:export" });
        try options.append(global.get_allocator(), .{ .label = "分配权限", .value = "btn:permission" });
        try options.append(global.get_allocator(), .{ .label = "重置密码", .value = "btn:resetPwd" });
    }

    base.send_ok(req, options.items);
}
