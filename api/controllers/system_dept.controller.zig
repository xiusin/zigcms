const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/models.zig");
const global = @import("../../shared/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmDept = sql.defineWithConfig(models.SysDept, .{
    .table_name = "zigcms.sys_dept",
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
    return .{ .allocator = allocator };
}

/// 部门树接口。
pub const dept_tree = deptTreeImpl;

/// 部门列表接口。
pub const dept_all = deptAllImpl;

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
