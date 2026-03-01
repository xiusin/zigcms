const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmMenu = sql.defineWithConfig(models.SysMenu, .{
    .table_name = "sys_menu",
    .primary_key = "id",
});

const MenuNode = struct {
    id: i32,
    pid: i32,
    title: []const u8,
    menu_name: []const u8,
    menu_type: i32,
    perms: []const u8,
    value: i32,
    key: i32,
};

/// 初始化菜单扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmMenu.hasDb()) {
        OrmMenu.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 菜单树接口。
pub const tree = treeImpl;

/// 菜单导出接口。
pub const menu_export = exportImpl;

/// 返回包含按钮在内的完整资源树。
fn treeImpl(self: *Self, req: zap.Request) !void {
    var q = OrmMenu.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmMenu.freeModels(rows);

    var tree_data = std.ArrayListUnmanaged(MenuNode){};
    defer tree_data.deinit(self.allocator);

    for (rows) |row| {
        const id = row.id orelse 0;
        tree_data.append(self.allocator, .{
            .id = id,
            .pid = row.pid,
            .title = row.menu_name,
            .menu_name = row.menu_name,
            .menu_type = row.menu_type,
            .perms = row.perms,
            .value = id,
            .key = id,
        }) catch {};
    }

    base.send_ok(req, tree_data.items);
}

/// 返回菜单导出地址。
fn exportImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    base.send_ok(req, .{ .url = "/api/system/menu/tree" });
}
