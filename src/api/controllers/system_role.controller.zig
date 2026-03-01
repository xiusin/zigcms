const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");
const log_mod = @import("../../application/services/logger/logger.zig");

const Self = @This();

allocator: Allocator,
logger: *log_mod.Logger,

const OrmRoleMenu = sql.defineWithConfig(models.SysRoleMenu, .{
    .table_name = "sys_role_menu",
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
pub fn init(allocator: Allocator, logger: *log_mod.Logger) Self {
    if (!OrmRoleMenu.hasDb()) {
        OrmRoleMenu.use(global.get_db());
    }
    if (!OrmAdminRole.hasDb()) {
        OrmAdminRole.use(global.get_db());
    }
    if (!OrmSysRole.hasDb()) {
        OrmSysRole.use(global.get_db());
    }
    return .{ 
        .allocator = allocator,
        .logger = logger,
    };
}

/// 角色信息与权限统一保存接口。
pub const save = saveImpl;

/// 角色权限查询接口。
pub const role_permissions_get = rolePermissionsGetImpl;

/// 角色权限查询接口 (别名)。
pub const role_permissions_info = rolePermissionsGetImpl;

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

/// 保存角色信息及其权限关联。
fn saveImpl(self: *Self, req: zap.Request) !void {
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("【角色保存】开始处理请求\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
    
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    // 打印原始请求体
    std.debug.print("请求体: {s}\n", .{body});

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");

    const data = parsed.value.object;
    
    // 打印所有字段
    std.debug.print("JSON 字段列表:\n", .{});
    var it = data.iterator();
    while (it.next()) |entry| {
        std.debug.print("  - {s}: {s}\n", .{entry.key_ptr.*, @tagName(entry.value_ptr.*)});
    }
    
    // 1. 提取角色基础信息
    const id_val = data.get("id");
    const role_name = if (data.get("role_name")) |v| v.string else "";
    const role_key = if (data.get("role_key")) |v| v.string else "";
    const sort = if (data.get("sort")) |v| @as(i32, @intCast(v.integer)) else 0;
    const remark = if (data.get("remark")) |v| v.string else "";
    const status = if (data.get("status")) |v| @as(i32, @intCast(v.integer)) else 1;

    if (role_name.len == 0) return base.send_failed(req, "角色名称不能为空");

    var role_id: i32 = 0;

    // 2. 创建或更新 sys_role 表
    if (id_val != null and id_val.? != .null) {
        role_id = @intCast(id_val.?.integer);
        std.debug.print("更新角色 ID: {d}\n", .{role_id});
        _ = OrmSysRole.Update(role_id, .{
            .role_name = role_name,
            .role_key = role_key,
            .sort = sort,
            .remark = remark,
            .status = status,
        }) catch |err| {
            std.debug.print("更新失败: {}\n", .{err});
            return base.send_error(req, err);
        };
        std.debug.print("更新成功\n", .{});
    } else {
        std.debug.print("创建新角色\n", .{});
        var created = OrmSysRole.Create(.{
            .role_name = role_name,
            .role_key = role_key,
            .sort = sort,
            .remark = remark,
            .status = status,
        }) catch |err| return base.send_error(req, err);
        defer OrmSysRole.freeModel(&created);
        role_id = created.id orelse 0;
    }

    if (role_id <= 0) {
        std.debug.print("角色ID无效: {d}\n", .{role_id});
        return base.send_failed(req, "保存角色失败");
    }

    std.debug.print("角色ID: {d}\n", .{role_id});

    // 3. 更新权限关联 (如果有 menu_ids 参数)
    if (data.get("menu_ids")) |menu_ids_val| {
        std.debug.print("检测到 menu_ids 字段，类型: {s}\n", .{@tagName(menu_ids_val)});
        if (menu_ids_val == .array) {
            std.debug.print("menu_ids 是数组，长度: {d}\n", .{menu_ids_val.array.items.len});
            
            // 清理旧关联
            var delete_menu_q = OrmRoleMenu.WhereEq("role_id", role_id);
            defer delete_menu_q.deinit();
            const deleted = delete_menu_q.delete() catch |err| {
                std.debug.print("删除旧关联失败: {}\n", .{err});
                return base.send_error(req, err);
            };
            std.debug.print("删除了 {d} 条旧关联\n", .{deleted});

            // 写入新关联
            var created_count: usize = 0;
            for (menu_ids_val.array.items) |m_id_val| {
                if (m_id_val != .integer) {
                    std.debug.print("跳过非整数类型的 menu_id: {s}\n", .{@tagName(m_id_val)});
                    continue;
                }
                const menu_id = @as(i32, @intCast(m_id_val.integer));
                std.debug.print("创建关联: role_id={d}, menu_id={d}\n", .{role_id, menu_id});
                
                var created_menu = OrmRoleMenu.Create(.{
                    .role_id = role_id,
                    .menu_id = menu_id,
                }) catch |err| {
                    std.debug.print("创建关联失败: role_id={d}, menu_id={d}, err={}\n", .{role_id, menu_id, err});
                    return base.send_error(req, err);
                };
                OrmRoleMenu.freeModel(&created_menu);
                created_count += 1;
            }
            std.debug.print("成功创建 {d} 条新关联\n", .{created_count});
        } else {
            std.debug.print("menu_ids 不是数组类型: {s}\n", .{@tagName(menu_ids_val)});
        }
    } else {
        std.debug.print("请求中没有 menu_ids 字段\n", .{});
    }

    std.debug.print("=== 角色保存完成 ===\n\n", .{});

    bumpRoleCacheVersion(self.allocator);
    
    // 重新查询角色信息返回
    const saved_role = (OrmSysRole.Find(role_id) catch null) orelse {
        return base.send_ok(req, .{ .id = role_id });
    };
    base.send_ok(req, saved_role);
}

/// 查询角色已分配的菜单 ID 列表。
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

    // 只返回 menu_ids，前端树会根据此 ID 自动勾选对应的菜单或按钮
    base.send_ok(req, .{
        .menu_ids = menu_ids.items,
    });
}

/// 删除角色，包含限制检查。
fn deleteImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = std.fmt.parseInt(i32, id_str, 10) catch return base.send_failed(req, "id 格式错误");

    const role_opt = OrmSysRole.Find(id) catch |err| return base.send_error(req, err);
    if (role_opt) |role| {
        var role_mut = role;
        defer OrmSysRole.freeModel(&role_mut);
        if (std.mem.eql(u8, role_mut.role_key, "super_admin") or id == 1) {
            return base.send_failed(req, "系统内置角色，不可删除");
        }
    } else {
        return base.send_failed(req, "该角色记录不存在");
    }

    var user_role_q = OrmAdminRole.WhereEq("role_id", id);
    defer user_role_q.deinit();
    if ((user_role_q.count() catch 0) > 0) {
        return base.send_failed(req, "该角色下仍有关联用户，请先解除关联后再尝试删除");
    }

    _ = OrmSysRole.Destroy(@as(usize, @intCast(id))) catch |err| return base.send_error(req, err);

    var rm_q = OrmRoleMenu.WhereEq("role_id", id);
    defer rm_q.deinit();
    _ = rm_q.delete() catch {};

    bumpRoleCacheVersion(global.get_allocator());
    base.send_ok(req, "角色已成功删除");
}
