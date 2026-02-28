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

const OrmTask = sql.defineWithConfig(models.OpTask, .{ .table_name = "op_task", .primary_key = "id" });
const OrmTaskLog = sql.defineWithConfig(models.OpTaskLog, .{ .table_name = "op_task_log", .primary_key = "id" });
const OrmTaskScheduleLog = sql.defineWithConfig(models.OpTaskScheduleLog, .{ .table_name = "op_task_schedule_log", .primary_key = "id" });

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
fn logsImpl(self: *Self, req: zap.Request) !void {
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
    defer OrmTaskLog.freeModels(rows);

    var items = std.ArrayListUnmanaged(models.OpTaskLog){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 查询任务调度日志。
fn scheduleLogsImpl(self: *Self, req: zap.Request) !void {
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
    defer OrmTaskScheduleLog.freeModels(rows);

    var items = std.ArrayListUnmanaged(models.OpTaskScheduleLog){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}
