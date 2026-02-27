const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmDept = sql.defineWithConfig(models.SysDept, .{
    .table_name = "sys_dept",
    .primary_key = "id",
});

const OrmAdmin = sql.defineWithConfig(models.SysAdmin, .{
    .table_name = "sys_admin",
    .primary_key = "id",
});

const DeptNode = struct {
    id: i32,
    parent_id: i32,
    title: []const u8,
    dept_name: []const u8,
    dept_code: []const u8,
    value: i32,
    key: i32,
};

/// 初始化部门扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmDept.hasDb()) {
        OrmDept.use(global.get_db());
    }
    if (!OrmAdmin.hasDb()) {
        OrmAdmin.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 部门树接口。
pub const dept_tree = deptTreeImpl;

/// 部门列表接口。
pub const dept_all = deptAllImpl;

/// 部门删除校验接口。
pub const dept_delete = deptDeleteImpl;

/// 返回部门树。
fn deptTreeImpl(self: *Self, req: zap.Request) !void {
    var q = OrmDept.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const items = q.get() catch |err| return base.send_error(req, err);
    defer OrmDept.freeModels(self.allocator, items);

    var tree = std.ArrayListUnmanaged(DeptNode){};
    defer tree.deinit(self.allocator);

    for (items) |item| {
        const id = item.id orelse 0;
        tree.append(self.allocator, .{
            .id = id,
            .parent_id = item.parent_id,
            .title = item.dept_name,
            .dept_name = item.dept_name,
            .dept_code = item.dept_code,
            .value = id,
            .key = id,
        }) catch {};
    }

    base.send_ok(req, tree.items);
}

/// 返回部门扁平列表。
fn deptAllImpl(self: *Self, req: zap.Request) !void {
    var q = OrmDept.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const items = q.get() catch |err| return base.send_error(req, err);
    defer OrmDept.freeModels(self.allocator, items);

    var list = std.ArrayListUnmanaged(models.SysDept){};
    defer list.deinit(self.allocator);
    for (items) |item| {
        list.append(self.allocator, item) catch {};
    }

    base.send_ok(req, list.items);
}

/// 删除部门前校验子部门与管理员占用。
fn deptDeleteImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    const dept_id = parseIdFromReq(req) orelse return base.send_failed(req, "缺少 id 参数");
    const hard_delete = parseDeleteMode(req);

    var child_q = OrmDept.WhereEq("parent_id", dept_id);
    defer child_q.deinit();
    if (child_q.exists() catch false) {
        return base.send_failed(req, "该部门存在子部门，无法删除");
    }

    var admin_q = OrmAdmin.WhereEq("dept_id", dept_id);
    defer admin_q.deinit();
    if (admin_q.exists() catch false) {
        return base.send_failed(req, "该部门下存在管理员，无法删除");
    }

    if (hard_delete) {
        _ = OrmDept.Destroy(@as(i32, @intCast(dept_id))) catch |err| return base.send_error(req, err);
        return base.send_ok(req, "删除成功");
    }

    _ = OrmDept.Update(@as(i32, @intCast(dept_id)), .{
        .status = @as(i32, 0),
    }) catch |err| return base.send_error(req, err);
    base.send_ok(req, "已软删除");
}

/// 兼容 query/body 的 id 读取。
fn parseIdFromReq(req: zap.Request) ?i32 {
    req.parseQuery();
    if (req.getParamSlice("id")) |id_str| {
        return std.fmt.parseInt(i32, id_str, 10) catch null;
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

/// 读取删除模式，默认软删除。
fn parseDeleteMode(req: zap.Request) bool {
    req.parseQuery();
    if (req.getParamSlice("delete_mode")) |mode| {
        return isHardDeleteMode(mode);
    }

    req.parseBody() catch return false;
    const body = req.body orelse return false;
    var parsed = std.json.parseFromSlice(std.json.Value, global.get_allocator(), body, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const mode_val = parsed.value.object.get("delete_mode") orelse return false;
    if (mode_val != .string) return false;
    return isHardDeleteMode(mode_val.string);
}

/// 判断是否为硬删除模式。
fn isHardDeleteMode(mode: []const u8) bool {
    return std.mem.eql(u8, mode, "hard");
}

test "isHardDeleteMode 模式识别" {
    try std.testing.expect(isHardDeleteMode("hard"));
    try std.testing.expect(!isHardDeleteMode("soft"));
    try std.testing.expect(!isHardDeleteMode(""));
}
