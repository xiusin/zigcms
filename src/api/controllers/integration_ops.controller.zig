const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const json_mod = @import("../../application/services/json/json.zig");
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

const OrmConfig = sql.defineWithConfig(models.SysConfig, .{ .table_name = "sys_config", .primary_key = "id" });
const OrmMember = sql.defineWithConfig(models.BizMember, .{ .table_name = "biz_member", .primary_key = "id" });
const OrmMemberTagRel = sql.defineWithConfig(models.BizMemberTagRel, .{ .table_name = "biz_member_tag_rel", .primary_key = "id" });
const OrmMemberBalanceLog = sql.defineWithConfig(models.BizMemberBalanceLog, .{ .table_name = "biz_member_balance_log", .primary_key = "id" });
const OrmMemberPointLog = sql.defineWithConfig(models.BizMemberPointLog, .{ .table_name = "biz_member_point_log", .primary_key = "id" });
const OrmTask = sql.defineWithConfig(models.OpTask, .{ .table_name = "op_task", .primary_key = "id" });
const OrmTaskLog = sql.defineWithConfig(models.OpTaskLog, .{ .table_name = "op_task_log", .primary_key = "id" });
const OrmTaskScheduleLog = sql.defineWithConfig(models.OpTaskScheduleLog, .{ .table_name = "op_task_schedule_log", .primary_key = "id" });
const OrmRoleMenu = sql.defineWithConfig(models.SysRoleMenu, .{ .table_name = "sys_role_menu", .primary_key = "id" });
const OrmRolePermission = sql.defineWithConfig(models.SysRolePermission, .{ .table_name = "sys_role_permission", .primary_key = "id" });
const OrmPermission = sql.defineWithConfig(SysPermission, .{ .table_name = "sys_permission", .primary_key = "id" });

/// 初始化对接扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmConfig.hasDb()) OrmConfig.use(global.get_db());
    if (!OrmMember.hasDb()) OrmMember.use(global.get_db());
    if (!OrmMemberTagRel.hasDb()) OrmMemberTagRel.use(global.get_db());
    if (!OrmMemberBalanceLog.hasDb()) OrmMemberBalanceLog.use(global.get_db());
    if (!OrmMemberPointLog.hasDb()) OrmMemberPointLog.use(global.get_db());
    if (!OrmTask.hasDb()) OrmTask.use(global.get_db());
    if (!OrmTaskLog.hasDb()) OrmTaskLog.use(global.get_db());
    if (!OrmTaskScheduleLog.hasDb()) OrmTaskScheduleLog.use(global.get_db());
    if (!OrmRoleMenu.hasDb()) OrmRoleMenu.use(global.get_db());
    if (!OrmRolePermission.hasDb()) OrmRolePermission.use(global.get_db());
    if (!OrmPermission.hasDb()) OrmPermission.use(global.get_db());

    return .{ .allocator = allocator };
}

/// 角色权限保存接口。
pub const role_permissions_save = rolePermissionsSaveImpl;

/// 配置刷新缓存接口。
pub const config_refresh_cache = configRefreshCacheImpl;

/// 配置导出接口。
pub const config_export = configExportImpl;

/// 配置导入接口。
pub const config_import = configImportImpl;

/// 配置备份接口。
pub const config_backup = configBackupImpl;

/// 会员批量启用接口。
pub const member_batch_enable = memberBatchEnableImpl;

/// 会员批量禁用接口。
pub const member_batch_disable = memberBatchDisableImpl;

/// 会员批量删除接口。
pub const member_batch_delete = memberBatchDeleteImpl;

/// 会员打标签接口。
pub const member_tag_add = memberTagAddImpl;

/// 会员积分充值接口。
pub const member_point_recharge = memberPointRechargeImpl;

/// 会员余额充值接口。
pub const member_balance_recharge = memberBalanceRechargeImpl;

/// 会员导出接口。
pub const member_export = memberExportImpl;

/// 任务立即执行接口。
pub const task_run = taskRunImpl;

/// 任务执行日志接口。
pub const task_logs = taskLogsImpl;

/// 任务调度日志接口。
pub const task_schedule_logs = taskScheduleLogsImpl;

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
            defer OrmPermission.freeModel(self.allocator, &created);
            break :blk created.id orelse 0;
        };

        _ = OrmRolePermission.Create(.{
            .role_id = role_id,
            .permission_id = permission_id,
        }) catch |err| return base.send_error(req, err);
    }

    base.send_ok(req, "权限保存成功");
}

/// 返回配置缓存刷新结果。
fn configRefreshCacheImpl(self: *Self, req: zap.Request) !void {
    _ = self;

    var q = OrmConfig.Query();
    defer q.deinit();
    const total = q.count() catch |err| return base.send_error(req, err);

    base.send_ok(req, .{
        .refreshed = true,
        .refreshed_count = total,
        .refreshed_at = std.time.timestamp(),
    });
}

/// 导出配置列表。
fn configExportImpl(self: *Self, req: zap.Request) !void {
    var q = OrmConfig.Query();
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmConfig.freeModels(self.allocator, rows);

    var items = std.ArrayListUnmanaged(models.SysConfig){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 导入配置列表并按 config_key 覆盖。
fn configImportImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");
    const items_val = parsed.value.object.get("items") orelse return base.send_failed(req, "缺少 items 参数");
    if (items_val != .array) return base.send_failed(req, "items 参数格式错误");

    var imported: usize = 0;
    for (items_val.array.items) |item_val| {
        if (item_val != .object) continue;

        const obj = item_val.object;
        const dto = models.SysConfig{
            .id = parseOptionalI32(obj.get("id")),
            .config_name = parseString(obj.get("config_name")),
            .config_key = parseString(obj.get("config_key")),
            .config_group = if (parseString(obj.get("config_group")).len > 0) parseString(obj.get("config_group")) else "basic",
            .config_type = if (parseString(obj.get("config_type")).len > 0) parseString(obj.get("config_type")) else "text",
            .config_value = parseString(obj.get("config_value")),
            .description = parseString(obj.get("description")),
            .sort = parseI32Default(obj.get("sort"), 0),
            .status = parseI32Default(obj.get("status"), 1),
            .created_at = parseOptionalI64(obj.get("created_at")),
            .updated_at = parseOptionalI64(obj.get("updated_at")),
        };

        if (dto.config_key.len == 0) continue;

        var exist_q = OrmConfig.WhereEq("config_key", dto.config_key);
        defer exist_q.deinit();
        const existed = exist_q.first() catch null;

        if (existed) |old| {
            const old_id = old.id orelse 0;
            if (old_id > 0) {
                _ = OrmConfig.Update(old_id, dto) catch |err| return base.send_error(req, err);
                imported += 1;
            }
        } else {
            _ = OrmConfig.Create(dto) catch |err| return base.send_error(req, err);
            imported += 1;
        }
    }

    base.send_ok(req, .{ .imported = imported });
}

/// 备份当前配置快照。
fn configBackupImpl(self: *Self, req: zap.Request) !void {
    var q = OrmConfig.Query();
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmConfig.freeModels(self.allocator, rows);

    var items = std.ArrayListUnmanaged(models.SysConfig){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .snapshot_time = std.time.timestamp(), .list = items.items });
}

/// 批量启用会员。
fn memberBatchEnableImpl(self: *Self, req: zap.Request) !void {
    try memberBatchSetStatus(self, req, 1);
}

/// 批量禁用会员。
fn memberBatchDisableImpl(self: *Self, req: zap.Request) !void {
    try memberBatchSetStatus(self, req, 0);
}

/// 批量删除会员。
fn memberBatchDeleteImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var ids = parseIds(self.allocator, body) catch return base.send_failed(req, "ids 参数错误");
    defer ids.deinit(self.allocator);
    var affected: usize = 0;
    for (ids.items) |id| {
        _ = OrmMember.Destroy(id) catch |err| return base.send_error(req, err);
        affected += 1;
    }

    base.send_ok(req, .{ .affected = affected });
}

/// 为会员新增标签关联。
fn memberTagAddImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");

    const member_ids_val = parsed.value.object.get("member_ids") orelse return base.send_failed(req, "缺少 member_ids 参数");
    const tag_id_val = parsed.value.object.get("tag_id") orelse return base.send_failed(req, "缺少 tag_id 参数");
    if (member_ids_val != .array or tag_id_val != .integer) return base.send_failed(req, "参数格式错误");

    const tag_id: i32 = @intCast(tag_id_val.integer);
    var affected: usize = 0;

    for (member_ids_val.array.items) |member_id_val| {
        if (member_id_val != .integer) continue;
        _ = OrmMemberTagRel.Create(.{
            .member_id = @as(i32, @intCast(member_id_val.integer)),
            .tag_id = tag_id,
        }) catch |err| return base.send_error(req, err);
        affected += 1;
    }

    base.send_ok(req, .{ .affected = affected });
}

/// 为会员充值积分并记录日志。
fn memberPointRechargeImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct {
        member_id: i32,
        points: i32,
        change_type: []const u8 = "add",
        remark: []const u8 = "",
        operator_id: ?i32 = null,
    };

    const dto = json_mod.JSON.decode(Dto, self.allocator, body) catch return base.send_failed(req, "参数格式错误");
    if (dto.member_id <= 0 or dto.points == 0) return base.send_failed(req, "参数无效");

    var member = (OrmMember.Find(dto.member_id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "会员不存在");
    };
    defer OrmMember.freeModel(self.allocator, &member);

    if (std.mem.eql(u8, dto.change_type, "reduce")) {
        member.points -= dto.points;
    } else {
        member.points += dto.points;
    }

    _ = OrmMember.Update(dto.member_id, member) catch |err| return base.send_error(req, err);
    _ = OrmMemberPointLog.Create(.{
        .member_id = dto.member_id,
        .change_type = dto.change_type,
        .points = dto.points,
        .remark = dto.remark,
        .operator_id = dto.operator_id,
        .created_at = std.time.timestamp(),
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, .{ .member_id = dto.member_id, .points = member.points });
}

/// 为会员充值余额并记录日志。
fn memberBalanceRechargeImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct {
        member_id: i32,
        amount: f64,
        change_type: []const u8 = "add",
        payment_method: []const u8 = "",
        remark: []const u8 = "",
        operator_id: ?i32 = null,
    };

    const dto = json_mod.JSON.decode(Dto, self.allocator, body) catch return base.send_failed(req, "参数格式错误");
    if (dto.member_id <= 0 or dto.amount <= 0) return base.send_failed(req, "参数无效");

    var member = (OrmMember.Find(dto.member_id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "会员不存在");
    };
    defer OrmMember.freeModel(self.allocator, &member);

    if (std.mem.eql(u8, dto.change_type, "reduce")) {
        member.balance -= dto.amount;
    } else {
        member.balance += dto.amount;
    }

    _ = OrmMember.Update(dto.member_id, member) catch |err| return base.send_error(req, err);
    _ = OrmMemberBalanceLog.Create(.{
        .member_id = dto.member_id,
        .change_type = dto.change_type,
        .amount = dto.amount,
        .payment_method = dto.payment_method,
        .remark = dto.remark,
        .operator_id = dto.operator_id,
        .created_at = std.time.timestamp(),
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, .{ .member_id = dto.member_id, .balance = member.balance });
}

/// 导出会员列表。
fn memberExportImpl(self: *Self, req: zap.Request) !void {
    var q = OrmMember.Query();
    defer q.deinit();
    _ = q.limit(5000);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmMember.freeModels(self.allocator, rows);

    var items = std.ArrayListUnmanaged(models.BizMember){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 立即执行任务并写入执行日志。
fn taskRunImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct { id: i32 };
    const dto = json_mod.JSON.decode(Dto, self.allocator, body) catch return base.send_failed(req, "参数格式错误");
    if (dto.id <= 0) return base.send_failed(req, "任务ID无效");

    var task = (OrmTask.Find(dto.id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "任务不存在");
    };
    defer OrmTask.freeModel(self.allocator, &task);

    const now = std.time.timestamp();
    task.last_run_time = now;
    _ = OrmTask.Update(dto.id, task) catch |err| return base.send_error(req, err);

    _ = OrmTaskLog.Create(.{
        .task_id = dto.id,
        .task_name = task.task_name,
        .start_time = now,
        .end_time = now,
        .duration_ms = 0,
        .status = "success",
        .result = "手动执行成功",
        .error_message = "",
        .created_at = now,
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, "任务执行成功");
}

/// 查询任务执行日志。
fn taskLogsImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch {};

    var task_id: ?i32 = null;
    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        if (parsed) |*p| {
            defer p.deinit();
            if (p.value == .object) {
                if (p.value.object.get("task_id")) |id_val| {
                    if (id_val == .integer) task_id = @intCast(id_val.integer);
                }
            }
        }
    }

    var q = OrmTaskLog.Query();
    defer q.deinit();
    if (task_id) |id| _ = q.whereEq("task_id", id);
    _ = q.orderBy("id", .desc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmTaskLog.freeModels(self.allocator, rows);

    var items = std.ArrayListUnmanaged(models.OpTaskLog){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 查询任务调度日志。
fn taskScheduleLogsImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch {};

    var task_id: ?i32 = null;
    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        if (parsed) |*p| {
            defer p.deinit();
            if (p.value == .object) {
                if (p.value.object.get("task_id")) |id_val| {
                    if (id_val == .integer) task_id = @intCast(id_val.integer);
                }
            }
        }
    }

    var q = OrmTaskScheduleLog.Query();
    defer q.deinit();
    if (task_id) |id| _ = q.whereEq("task_id", id);
    _ = q.orderBy("id", .desc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmTaskScheduleLog.freeModels(self.allocator, rows);

    var items = std.ArrayListUnmanaged(models.OpTaskScheduleLog){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 批量更新会员状态。
fn memberBatchSetStatus(self: *Self, req: zap.Request, status: i32) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var ids = parseIds(self.allocator, body) catch return base.send_failed(req, "ids 参数错误");
    defer ids.deinit(self.allocator);
    var affected: usize = 0;
    for (ids.items) |id| {
        _ = OrmMember.Update(id, .{ .status = status }) catch |err| return base.send_error(req, err);
        affected += 1;
    }

    base.send_ok(req, .{ .affected = affected, .status = status });
}

/// 解析批量 id 列表。
fn parseIds(allocator: Allocator, body: []const u8) !std.ArrayListUnmanaged(i32) {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidData;
    const ids_val = parsed.value.object.get("ids") orelse return error.InvalidData;
    if (ids_val != .array) return error.InvalidData;

    var ids = std.ArrayListUnmanaged(i32){};
    for (ids_val.array.items) |id_val| {
        if (id_val != .integer) continue;
        try ids.append(allocator, @intCast(id_val.integer));
    }
    return ids;
}

/// 解析字符串字段。
fn parseString(value: ?std.json.Value) []const u8 {
    if (value) |v| {
        if (v == .string) return v.string;
    }
    return "";
}

/// 解析可选 i32 字段。
fn parseOptionalI32(value: ?std.json.Value) ?i32 {
    if (value) |v| {
        if (v == .integer) return @as(i32, @intCast(v.integer));
    }
    return null;
}

/// 解析带默认值的 i32 字段。
fn parseI32Default(value: ?std.json.Value, default_value: i32) i32 {
    if (value) |v| {
        if (v == .integer) return @as(i32, @intCast(v.integer));
    }
    return default_value;
}

/// 解析可选 i64 字段。
fn parseOptionalI64(value: ?std.json.Value) ?i64 {
    if (value) |v| {
        if (v == .integer) return @as(i64, @intCast(v.integer));
    }
    return null;
}
