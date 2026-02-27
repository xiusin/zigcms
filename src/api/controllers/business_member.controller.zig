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

const OrmMember = sql.defineWithConfig(models.BizMember, .{ .table_name = "biz_member", .primary_key = "id" });
const OrmMemberTagRel = sql.defineWithConfig(models.BizMemberTagRel, .{ .table_name = "biz_member_tag_rel", .primary_key = "id" });
const OrmMemberBalanceLog = sql.defineWithConfig(models.BizMemberBalanceLog, .{ .table_name = "biz_member_balance_log", .primary_key = "id" });
const OrmMemberPointLog = sql.defineWithConfig(models.BizMemberPointLog, .{ .table_name = "biz_member_point_log", .primary_key = "id" });

/// 初始化会员扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmMember.hasDb()) OrmMember.use(global.get_db());
    if (!OrmMemberTagRel.hasDb()) OrmMemberTagRel.use(global.get_db());
    if (!OrmMemberBalanceLog.hasDb()) OrmMemberBalanceLog.use(global.get_db());
    if (!OrmMemberPointLog.hasDb()) OrmMemberPointLog.use(global.get_db());
    return .{ .allocator = allocator };
}

/// 会员批量启用接口。
pub const batch_enable = batchEnableImpl;

/// 会员批量禁用接口。
pub const batch_disable = batchDisableImpl;

/// 会员批量删除接口。
pub const batch_delete = batchDeleteImpl;

/// 会员打标签接口。
pub const tag_add = tagAddImpl;

/// 会员积分充值接口。
pub const point_recharge = pointRechargeImpl;

/// 会员余额充值接口。
pub const balance_recharge = balanceRechargeImpl;

/// 会员导出接口。
pub const member_export = exportImpl;

/// 批量启用会员。
fn batchEnableImpl(self: *Self, req: zap.Request) !void {
    try batchSetStatus(self, req, 1);
}

/// 批量禁用会员。
fn batchDisableImpl(self: *Self, req: zap.Request) !void {
    try batchSetStatus(self, req, 0);
}

/// 批量删除会员。
fn batchDeleteImpl(self: *Self, req: zap.Request) !void {
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
fn tagAddImpl(self: *Self, req: zap.Request) !void {
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
fn pointRechargeImpl(self: *Self, req: zap.Request) !void {
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
fn balanceRechargeImpl(self: *Self, req: zap.Request) !void {
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
fn exportImpl(self: *Self, req: zap.Request) !void {
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

/// 批量更新会员状态。
fn batchSetStatus(self: *Self, req: zap.Request, status: i32) !void {
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
        try ids.append(allocator, @as(i32, @intCast(id_val.integer)));
    }
    return ids;
}
