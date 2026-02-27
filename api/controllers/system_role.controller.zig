const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");

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
    .table_name = "zigcms.sys_permission",
    .primary_key = "id",
});

/// 初始化角色扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmPermission.hasDb()) {
        OrmPermission.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 获取按钮权限选项接口。
pub const button_perms = buttonPermsImpl;

/// 返回按钮权限候选列表。
fn buttonPermsImpl(self: *Self, req: zap.Request) !void {
    var q = OrmPermission.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmPermission.freeModels(self.allocator, rows);

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
