//! 告警管理控制器
//! 处理告警规则和告警历史的管理

const std = @import("std");
const zap = @import("zap");
const base = @import("../base.fn.zig");
const sql_orm = @import("../../../application/services/sql/orm.zig");
const zigcms = @import("../../../../root.zig");

const Self = @This();

/// 告警规则实体
pub const AlertRule = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    event_type: []const u8 = "",
    threshold: i32 = 0,
    time_window: i32 = 60,
    enabled: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 告警历史实体
pub const AlertHistory = struct {
    id: ?i32 = null,
    rule_id: i32 = 0,
    rule_name: []const u8 = "",
    event_type: []const u8 = "",
    trigger_count: i32 = 0,
    status: []const u8 = "pending",
    created_at: ?i64 = null,
    resolved_at: ?i64 = null,
};

/// 获取告警规则列表
pub fn listRules(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;

    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    var q = OrmAlertRule.Query();
    defer q.deinit();

    _ = q.orderBy("created_at", .desc)
        .limit(@as(u64, @intCast(page_size)))
        .offset(@as(u64, @intCast((page - 1) * page_size)));

    const items = q.get() catch |e| return base.send_error(req, e);
    defer OrmAlertRule.freeModels(items);

    const total = q.count() catch |e| return base.send_error(req, e);

    const response = .{
        .items = items,
        .total = @as(i32, @intCast(total)),
        .page = page,
        .page_size = page_size,
    };

    base.send_ok(req, response);
}

/// 获取告警规则详情
pub fn getRule(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    var q = OrmAlertRule.Query();
    defer q.deinit();

    _ = q.where("id", "=", id);

    const items = q.get() catch |e| return base.send_error(req, e);
    defer OrmAlertRule.freeModels(items);

    if (items.len > 0) {
        base.send_ok(req, items[0]);
    } else {
        base.send_failed(req, "告警规则不存在");
    }
}

/// 创建告警规则
pub fn createRule(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const name = try req.getParamStr(allocator, "name");
    if (name == null) return base.send_failed(req, "缺少参数 name");

    const event_type = try req.getParamStr(allocator, "event_type");
    if (event_type == null) return base.send_failed(req, "缺少参数 event_type");

    const threshold_str = try req.getParamStr(allocator, "threshold");
    if (threshold_str == null) return base.send_failed(req, "缺少参数 threshold");
    const threshold = std.fmt.parseInt(i32, threshold_str.?, 10) catch return base.send_failed(req, "无效的 threshold");

    const time_window_str = try req.getParamStr(allocator, "time_window");
    if (time_window_str == null) return base.send_failed(req, "缺少参数 time_window");
    const time_window = std.fmt.parseInt(i32, time_window_str.?, 10) catch return base.send_failed(req, "无效的 time_window");

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    const now = std.time.timestamp();

    const rule = AlertRule{
        .name = name.?,
        .event_type = event_type.?,
        .threshold = threshold,
        .time_window = time_window,
        .enabled = 1,
        .created_at = now,
        .updated_at = now,
    };

    const created = OrmAlertRule.Create(rule) catch |e| return base.send_error(req, e);

    base.send_ok(req, created);
}

/// 更新告警规则
pub fn updateRule(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });

    const enabled_str = try req.getParamStr(allocator, "enabled");
    const enabled = if (enabled_str) |es| std.fmt.parseInt(i32, es, 10) catch 1 else 1;

    _ = OrmAlertRule.UpdateWith(id, .{
        .enabled = enabled,
        .updated_at = std.time.timestamp(),
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .message = "更新成功" });
}

/// 删除告警规则
pub fn deleteRule(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const container = zigcms.core.di.getGlobalContainer() orelse return base.send_failed(req, "DI容器未初始化");
    const db = container.resolve(sql_orm.Database) catch |e| return base.send_error(req, e);

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    var q = OrmAlertRule.query(db);
    defer q.deinit();

    _ = q.where("id", "=", id);
    _ = q.delete() catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .message = "删除成功" });
}

/// 启用/禁用告警规则
pub fn toggleRule(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const enabled_str = try req.getParamStr(allocator, "enabled");
    if (enabled_str == null) return base.send_failed(req, "缺少参数 enabled");
    const enabled = std.fmt.parseInt(i32, enabled_str.?, 10) catch return base.send_failed(req, "无效的 enabled");

    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    _ = OrmAlertRule.UpdateWith(id, .{
        .enabled = enabled,
        .updated_at = std.time.timestamp(),
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .message = "操作成功" });
}

/// 获取告警历史列表
pub fn listHistory(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const status = try req.getParamStr(allocator, "status");

    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;

    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;

    const OrmAlertHistory = sql_orm.defineWithConfig(AlertHistory, .{ .table_name = "alert_history" });
    var q = OrmAlertHistory.Query();
    defer q.deinit();

    if (status) |st| {
        _ = q.where("status", "=", st);
    }

    _ = q.orderBy("created_at", .desc)
        .limit(@as(u64, @intCast(page_size)))
        .offset(@as(u64, @intCast((page - 1) * page_size)));

    const items = q.get() catch |e| return base.send_error(req, e);
    defer OrmAlertHistory.freeModels(items);

    const total = q.count() catch |e| return base.send_error(req, e);

    const response = .{
        .items = items,
        .total = @as(i32, @intCast(total)),
        .page = page,
        .page_size = page_size,
    };

    base.send_ok(req, response);
}

/// 获取告警历史详情
pub fn getHistory(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const OrmAlertHistory = sql_orm.defineWithConfig(AlertHistory, .{ .table_name = "alert_history" });
    var q = OrmAlertHistory.Query();
    defer q.deinit();

    _ = q.where("id", "=", id);

    const items = q.get() catch |e| return base.send_error(req, e);
    defer OrmAlertHistory.freeModels(items);

    if (items.len > 0) {
        base.send_ok(req, items[0]);
    } else {
        base.send_failed(req, "告警历史不存在");
    }
}

/// 标记告警已处理
pub fn resolveAlert(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const OrmAlertHistory = sql_orm.defineWithConfig(AlertHistory, .{ .table_name = "alert_history" });
    _ = OrmAlertHistory.UpdateWith(id, .{
        .status = "resolved",
        .resolved_at = std.time.timestamp(),
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .message = "已标记为已处理" });
}

/// 忽略告警
pub fn ignoreAlert(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");

    const OrmAlertHistory = sql_orm.defineWithConfig(AlertHistory, .{ .table_name = "alert_history" });
    _ = OrmAlertHistory.UpdateWith(id, .{
        .status = "ignored",
        .resolved_at = std.time.timestamp(),
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, .{ .message = "已忽略" });
}

/// 获取告警统计
pub fn getStats(_: *Self, req: zap.Request) !void {
    const OrmAlertHistory = sql_orm.defineWithConfig(AlertHistory, .{ .table_name = "alert_history" });

    // 今日告警数
    var today_q = OrmAlertHistory.Query();
    defer today_q.deinit();

    const now = std.time.timestamp();
    const today_start = now - @rem(now, 86400);
    _ = today_q.where("created_at", ">=", today_start);
    const today_alerts = today_q.count() catch |e| return base.send_error(req, e);

    // 活跃规则数
    const OrmAlertRule = sql_orm.defineWithConfig(AlertRule, .{ .table_name = "alert_rules" });
    var rule_q = OrmAlertRule.Query();
    defer rule_q.deinit();
    _ = rule_q.where("enabled", "=", 1);
    const active_rules = rule_q.count() catch |e| return base.send_error(req, e);

    // 待处理告警数
    var pending_q = OrmAlertHistory.Query();
    defer pending_q.deinit();
    _ = pending_q.where("status", "=", "pending");
    const pending_alerts = pending_q.count() catch |e| return base.send_error(req, e);

    // 已处理告警数
    var resolved_q = OrmAlertHistory.Query();
    defer resolved_q.deinit();
    _ = resolved_q.where("status", "=", "resolved")
        .where("created_at", ">=", today_start);
    const resolved_alerts = resolved_q.count() catch |e| return base.send_error(req, e);

    const stats = .{
        .todayAlerts = @as(i32, @intCast(today_alerts)),
        .activeRules = @as(i32, @intCast(active_rules)),
        .pendingAlerts = @as(i32, @intCast(pending_alerts)),
        .resolvedAlerts = @as(i32, @intCast(resolved_alerts)),
    };

    base.send_ok(req, stats);
}

pub fn getRealtimeAlerts(_: *Self, req: zap.Request) !void {
    _ = req.getParamSlice("last_id");
    base.send_ok(req, &[_]AlertHistory{});
}
