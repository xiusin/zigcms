//! 角色管理控制器
//!
//! 提供角色的 CRUD 操作及权限管理

const std = @import("std");
const log_mod = @import("../../application/services/logger/logger.zig");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,
logger: *log_mod.Logger,

/// ORM 模型定义
const OrmRole = sql.defineWithConfig(models.Role, .{
    .table_name = "zigcms.role",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator, logger: *log_mod.Logger) Self {
    if (!OrmRole.hasDb()) {
        OrmRole.use(global.get_db());
    }
    return .{ .allocator = allocator, .logger = logger };
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

/// 分页列表
pub const list = listImpl;

/// 获取单条记录
pub const get = getImpl;

/// 保存（新增/更新）
pub const save = saveImpl;

/// 删除
pub const delete = deleteImpl;

/// 下拉选择列表
pub const select = MW.requireAuth(selectImpl);

/// 获取角色权限
pub const permissions = MW.requireAuth(permissionsImpl);

/// 更新角色权限
pub const updatePermissions = MW.requireAuth(updatePermissionsImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var sort_field: []const u8 = "sort";
    var sort_dir: []const u8 = "asc";

    var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
        return base.send_error(req, err);
    };
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 10);
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "sort";
            sort_dir = value.value;
        }
    }

    // 构建查询
    var q = OrmRole.WhereEq("is_delete", @as(i32, 0));
    defer q.deinit();

    const total = q.count() catch |e| return base.send_error(req, e);

    const order_dir: sql.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    _ = q.orderBy(sort_field, order_dir);
    _ = q.page(@intCast(page), @intCast(limit));

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmRole.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Role){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

/// 获取单条记录实现
fn getImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const item_opt = OrmRole.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "角色不存在");
    }

    var item = item_opt.?;
    defer OrmRole.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

/// 保存实现（新增/更新）
fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(models.Role, self.allocator, body) catch |err| {
        self.logger.err("解析角色数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    if (dto.name.len == 0) {
        return base.send_failed(req, "角色名称不能为空");
    }

    // 检查编码唯一性
    if (dto.code.len > 0) {
        var check_q = OrmRole.WhereEq("code", dto.code);
        defer check_q.deinit();
        _ = check_q.where("is_delete", "=", @as(i32, 0));
        if (dto.id) |id| {
            if (id > 0) {
                _ = check_q.where("id", "!=", id);
            }
        }
        const exists = check_q.first() catch null;
        if (exists != null) {
            return base.send_failed(req, "角色编码已存在");
        }
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmRole.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmRole.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmRole.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

/// 删除实现（软删除）
fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 检查是否为系统角色（不可删除）
    if (id == 1) {
        return base.send_failed(req, "系统角色不可删除");
    }

    // 软删除
    const sql_str = strings.sprinf(
        "UPDATE zigcms.role SET is_delete = 1, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "删除成功");
}

/// 下拉选择列表实现
fn selectImpl(self: *Self, req: zap.Request) !void {
    var q = OrmRole.WhereEq("status", @as(i32, 1));
    defer q.deinit();
    _ = q.where("is_delete", .eq, @as(i32, 0));
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmRole.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Role){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}

/// 获取角色权限实现
fn permissionsImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少角色ID");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "角色ID格式错误"));

    const item_opt = OrmRole.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "角色不存在");
    }

    var item = item_opt.?;
    defer OrmRole.freeModel(self.allocator, &item);

    // 返回权限列表
    base.send_ok(req, .{
        .id = item.id,
        .name = item.name,
        .permissions = item.permissions,
        .data_scope = item.data_scope,
    });
}

/// 更新角色权限实现
fn updatePermissionsImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const PermDto = struct {
        id: i32,
        permissions: []const u8 = "[]",
        data_scope: i32 = 1,
    };

    const dto = json_mod.JSON.decode(PermDto, self.allocator, body) catch {
        return base.send_failed(req, "解析数据失败");
    };

    if (dto.id <= 0) {
        return base.send_failed(req, "角色ID无效");
    }

    // 更新权限
    const sql_str = strings.sprinf(
        "UPDATE zigcms.role SET permissions = '{s}', data_scope = {d}, update_time = {d} WHERE id = {d}",
        .{ dto.permissions, dto.data_scope, std.time.microTimestamp(), dto.id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "权限更新成功");
}
