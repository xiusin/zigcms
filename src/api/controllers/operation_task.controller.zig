const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const json_mod = @import("../../application/services/json/json.zig");
const sql = @import("../../application/services/sql/orm.zig");
const datetime = @import("../../application/services/datetime/datetime.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmTask = sql.defineWithConfig(models.OpTask, .{ .table_name = "op_task", .primary_key = "id" });
const OrmTaskLog = sql.defineWithConfig(models.OpTaskLog, .{ .table_name = "op_task_log", .primary_key = "id" });
const OrmTaskScheduleLog = sql.defineWithConfig(models.OpTaskScheduleLog, .{ .table_name = "op_task_schedule_log", .primary_key = "id" });

fn parsePage(value: ?[]const u8, default_value: i32) i32 {
    return std.fmt.parseInt(i32, value orelse "", 10) catch default_value;
}

/// 初始化任务扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmTask.hasDb()) OrmTask.use(global.get_db());
    if (!OrmTaskLog.hasDb()) OrmTaskLog.use(global.get_db());
    if (!OrmTaskScheduleLog.hasDb()) OrmTaskScheduleLog.use(global.get_db());
    return .{ .allocator = allocator };
}

/// 任务立即执行接口。
pub const run = runImpl;

/// 任务执行日志接口。
pub const logs = logsImpl;

/// 任务调度日志接口。
pub const schedule_logs = scheduleLogsImpl;

/// 立即执行任务并写入执行日志。
fn runImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const Dto = struct { id: i32 };
    const dto = json_mod.JSON.decode(Dto, self.allocator, body) catch return base.send_failed(req, "参数格式错误");
    if (dto.id <= 0) return base.send_failed(req, "任务ID无效");

    var task = (OrmTask.Find(dto.id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "任务不存在");
    };
    defer OrmTask.freeModel(&task);

    const now_fmt = datetime.nowGoDatetimeOwned(self.allocator) catch |err| return base.send_error(req, err);
    defer self.allocator.free(now_fmt);
    const now_fmt_const: []const u8 = now_fmt;
    _ = OrmTask.UpdateWith(dto.id, .{ .last_run_time = now_fmt_const }) catch |err| return base.send_error(req, err);

    var task_log = OrmTaskLog.Create(.{
        .task_id = dto.id,
        .task_name = task.task_name,
        .start_time = now_fmt_const,
        .end_time = now_fmt_const,
        .duration_ms = 0,
        .status = "success",
        .result = "手动执行成功",
        .error_message = "",
        .created_at = now_fmt_const,
    }) catch |err| return base.send_error(req, err);
    OrmTaskLog.freeModel(&task_log);

    base.send_ok(req, "任务执行成功");
}

/// 查询任务执行日志。
fn logsImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    req.parseBody() catch {};

    var task_id: ?i32 = null;
    var status: ?[]const u8 = req.getParamSlice("status");
    const page = parsePage(req.getParamSlice("page"), 1);
    const page_size = parsePage(req.getParamSlice("pageSize") orelse req.getParamSlice("page_size") orelse req.getParamSlice("limit"), 20);

    if (req.getParamSlice("task_id")) |id_str| {
        task_id = std.fmt.parseInt(i32, id_str, 10) catch null;
    }

    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch null;
        defer if (parsed) |*p| p.deinit();
        if (parsed) |p| {
            if (p.value == .object) {
                if (p.value.object.get("task_id")) |id_val| switch (id_val) {
                    .integer => task_id = @intCast(id_val.integer),
                    .string => task_id = std.fmt.parseInt(i32, id_val.string, 10) catch task_id,
                    else => {},
                };
                if (p.value.object.get("status")) |status_val| {
                    if (status_val == .string) status = status_val.string;
                }
            }
        }
    }

    var q = OrmTaskLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    var items = std.ArrayListUnmanaged(models.OpTaskLog){};
    defer items.deinit(allocator);

    const start_index: usize = @intCast(@max(page - 1, 0) * @max(page_size, 1));
    const page_len: usize = @intCast(@max(page_size, 1));
    var matched_total: usize = 0;

    for (rows) |row| {
        if (task_id) |id| {
            if (row.task_id != id) continue;
        }
        if (status) |st| {
            if (!std.mem.eql(u8, row.status, st)) continue;
        }
        if (matched_total >= start_index and items.items.len < page_len) {
            try items.append(allocator, row);
        }
        matched_total += 1;
    }

    base.send_ok(req, .{ .list = items.items, .total = matched_total, .page = page, .page_size = page_size });
}

/// 查询任务调度日志。
fn scheduleLogsImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    req.parseBody() catch {};

    var task_id: ?i32 = null;
    var status: ?[]const u8 = req.getParamSlice("status");
    const page = parsePage(req.getParamSlice("page"), 1);
    const page_size = parsePage(req.getParamSlice("pageSize") orelse req.getParamSlice("page_size") orelse req.getParamSlice("limit"), 20);

    if (req.getParamSlice("task_id")) |id_str| {
        task_id = std.fmt.parseInt(i32, id_str, 10) catch null;
    }

    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch null;
        defer if (parsed) |*p| p.deinit();
        if (parsed) |p| {
            if (p.value == .object) {
                if (p.value.object.get("task_id")) |id_val| switch (id_val) {
                    .integer => task_id = @intCast(id_val.integer),
                    .string => task_id = std.fmt.parseInt(i32, id_val.string, 10) catch task_id,
                    else => {},
                };
                if (p.value.object.get("status")) |status_val| {
                    if (status_val == .string) status = status_val.string;
                }
            }
        }
    }

    var q = OrmTaskScheduleLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    var items = std.ArrayListUnmanaged(models.OpTaskScheduleLog){};
    defer items.deinit(allocator);

    const start_index: usize = @intCast(@max(page - 1, 0) * @max(page_size, 1));
    const page_len: usize = @intCast(@max(page_size, 1));
    var matched_total: usize = 0;

    for (rows) |row| {
        if (task_id) |id| {
            if (row.task_id != id) continue;
        }
        if (status) |st| {
            if (!std.mem.eql(u8, row.status, st)) continue;
        }
        if (matched_total >= start_index and items.items.len < page_len) {
            try items.append(allocator, row);
        }
        matched_total += 1;
    }

    base.send_ok(req, .{ .list = items.items, .total = matched_total, .page = page, .page_size = page_size });
}
