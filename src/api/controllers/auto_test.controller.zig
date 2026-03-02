/// 自动化测试控制器
/// 提供测试报告上报、Bug 管理、统计等 API 端点
const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const datetime = @import("../../application/services/datetime/datetime.zig");

const Self = @This();

const OrmTestReport = sql.defineWithConfig(TestReportRow, .{
    .table_name = "test_reports",
    .primary_key = "id",
});

const OrmBugAnalysis = sql.defineWithConfig(BugAnalysisRow, .{
    .table_name = "bug_analyses",
    .primary_key = "id",
});

/// 测试报告行结构
const TestReportRow = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    test_type: []const u8 = "unit",
    status: []const u8 = "pending",
    total_cases: i32 = 0,
    passed_cases: i32 = 0,
    failed_cases: i32 = 0,
    skipped_cases: i32 = 0,
    pass_rate: i32 = 0,
    duration_ms: i32 = 0,
    error_message: []const u8 = "",
    stack_trace: []const u8 = "",
    test_target: []const u8 = "",
    triggered_by: []const u8 = "manual",
    environment: []const u8 = "{}",
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

/// Bug 分析行结构
const BugAnalysisRow = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    description: []const u8 = "",
    bug_type: []const u8 = "unknown",
    severity: []const u8 = "medium",
    priority: []const u8 = "medium",
    status: []const u8 = "pending",
    issue_location: []const u8 = "unknown",
    file_path: []const u8 = "",
    line_number: i32 = 0,
    root_cause: []const u8 = "",
    suggested_fix: []const u8 = "",
    confidence_score: i32 = 0,
    auto_fix_attempted: i32 = 0,
    auto_fix_result: []const u8 = "{}",
    test_report_id: ?i32 = null,
    feedback_id: ?i32 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

allocator: Allocator,

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmTestReport.hasDb()) {
        OrmTestReport.use(global.get_db());
    }
    if (!OrmBugAnalysis.hasDb()) {
        OrmBugAnalysis.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

// ==================== 公开路由处理器 ====================

/// 创建测试报告
pub const report_create = reportCreateImpl;

/// 获取测试报告列表
pub const report_list = reportListImpl;

/// 获取测试报告详情
pub const report_detail = reportDetailImpl;

/// 创建 Bug 分析
pub const bug_create = bugCreateImpl;

/// 获取 Bug 列表
pub const bug_list = bugListImpl;

/// 更新 Bug 状态
pub const bug_update_status = bugUpdateStatusImpl;

/// 获取统计概览
pub const statistics = statisticsImpl;

// ==================== 实现 ====================

/// 创建测试报告
fn reportCreateImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");
    const data = parsed.value.object;

    const now = datetime.nowGoDatetime();

    var created = OrmTestReport.Create(.{
        .name = if (data.get("name")) |v| v.string else "未命名报告",
        .test_type = if (data.get("test_type")) |v| v.string else "unit",
        .status = if (data.get("status")) |v| v.string else "completed",
        .total_cases = if (data.get("total_cases")) |v| @as(i32, @intCast(v.integer)) else 0,
        .passed_cases = if (data.get("passed_cases")) |v| @as(i32, @intCast(v.integer)) else 0,
        .failed_cases = if (data.get("failed_cases")) |v| @as(i32, @intCast(v.integer)) else 0,
        .skipped_cases = if (data.get("skipped_cases")) |v| @as(i32, @intCast(v.integer)) else 0,
        .pass_rate = if (data.get("pass_rate")) |v| @as(i32, @intCast(v.integer)) else 0,
        .duration_ms = if (data.get("duration_ms")) |v| @as(i32, @intCast(v.integer)) else 0,
        .error_message = if (data.get("error_message")) |v| v.string else "",
        .stack_trace = if (data.get("stack_trace")) |v| v.string else "",
        .test_target = if (data.get("test_target")) |v| v.string else "",
        .triggered_by = if (data.get("triggered_by")) |v| v.string else "manual",
        .environment = if (data.get("environment")) |v| v.string else "{}",
        .created_at = now.str,
        .updated_at = now.str,
    }) catch |err| return base.send_error(req, err);
    defer OrmTestReport.freeModel(&created);

    base.send_ok(req, created);
}

/// 获取测试报告列表
fn reportListImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var filter_type: ?[]const u8 = null;
    var filter_status: ?[]const u8 = null;

    var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
        return base.send_error(req, err);
    };
    defer params.deinit();

    for (params.items) |param| {
        if (std.mem.eql(u8, param.key, "page")) {
            page = @intCast(std.fmt.parseInt(i32, param.value, 10) catch 1);
        } else if (std.mem.eql(u8, param.key, "pageSize") or std.mem.eql(u8, param.key, "limit")) {
            limit = @intCast(std.fmt.parseInt(i32, param.value, 10) catch 10);
        } else if (std.mem.eql(u8, param.key, "type") and param.value.len > 0) {
            filter_type = param.value;
        } else if (std.mem.eql(u8, param.key, "status") and param.value.len > 0) {
            filter_status = param.value;
        }
    }

    var q = OrmTestReport.Query();
    defer q.deinit();

    if (filter_type) |t| {
        _ = q.whereEq("test_type", t);
    }
    if (filter_status) |s| {
        _ = q.whereEq("status", s);
    }

    const total = q.count() catch |err| return base.send_error(req, err);
    _ = q.orderBy("id", sql.OrderDir.desc);
    _ = q.page(@intCast(page), @intCast(limit));

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmTestReport.freeModels(rows);

    var items = std.ArrayListUnmanaged(TestReportRow){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

/// 获取测试报告详情
fn reportDetailImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id = std.fmt.parseInt(i32, id_str, 10) catch return base.send_failed(req, "id 参数格式错误");

    _ = self;
    const report = (OrmTestReport.Find(id) catch null) orelse {
        return base.send_failed(req, "报告不存在");
    };

    base.send_ok(req, report);
}

/// 创建 Bug 分析
fn bugCreateImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");
    const data = parsed.value.object;

    const title = if (data.get("title")) |v| v.string else "";
    if (title.len == 0) return base.send_failed(req, "Bug 标题不能为空");

    const now = datetime.nowGoDatetime();

    var created = OrmBugAnalysis.Create(.{
        .title = title,
        .description = if (data.get("description")) |v| v.string else "",
        .bug_type = if (data.get("bug_type")) |v| v.string else "unknown",
        .severity = if (data.get("severity")) |v| v.string else "medium",
        .priority = if (data.get("priority")) |v| v.string else "medium",
        .status = if (data.get("status")) |v| v.string else "pending",
        .issue_location = if (data.get("issue_location")) |v| v.string else "unknown",
        .file_path = if (data.get("file_path")) |v| v.string else "",
        .line_number = if (data.get("line_number")) |v| @as(i32, @intCast(v.integer)) else 0,
        .root_cause = if (data.get("root_cause")) |v| v.string else "",
        .suggested_fix = if (data.get("suggested_fix")) |v| v.string else "",
        .confidence_score = if (data.get("confidence_score")) |v| @as(i32, @intCast(v.integer)) else 0,
        .test_report_id = if (data.get("test_report_id")) |v| @as(?i32, @intCast(v.integer)) else null,
        .created_at = now.str,
        .updated_at = now.str,
    }) catch |err| return base.send_error(req, err);
    defer OrmBugAnalysis.freeModel(&created);

    base.send_ok(req, created);
}

/// 获取 Bug 列表
fn bugListImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var filter_status: ?[]const u8 = null;
    var filter_type: ?[]const u8 = null;
    var filter_severity: ?[]const u8 = null;

    var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
        return base.send_error(req, err);
    };
    defer params.deinit();

    for (params.items) |param| {
        if (std.mem.eql(u8, param.key, "page")) {
            page = @intCast(std.fmt.parseInt(i32, param.value, 10) catch 1);
        } else if (std.mem.eql(u8, param.key, "pageSize") or std.mem.eql(u8, param.key, "limit")) {
            limit = @intCast(std.fmt.parseInt(i32, param.value, 10) catch 10);
        } else if (std.mem.eql(u8, param.key, "status") and param.value.len > 0) {
            filter_status = param.value;
        } else if (std.mem.eql(u8, param.key, "type") and param.value.len > 0) {
            filter_type = param.value;
        } else if (std.mem.eql(u8, param.key, "severity") and param.value.len > 0) {
            filter_severity = param.value;
        }
    }

    var q = OrmBugAnalysis.Query();
    defer q.deinit();

    if (filter_status) |s| {
        _ = q.whereEq("status", s);
    }
    if (filter_type) |t| {
        _ = q.whereEq("bug_type", t);
    }
    if (filter_severity) |sv| {
        _ = q.whereEq("severity", sv);
    }

    const total = q.count() catch |err| return base.send_error(req, err);
    _ = q.orderBy("id", sql.OrderDir.desc);
    _ = q.page(@intCast(page), @intCast(limit));

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmBugAnalysis.freeModels(rows);

    var items = std.ArrayListUnmanaged(BugAnalysisRow){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

/// 更新 Bug 状态
fn bugUpdateStatusImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");
    const data = parsed.value.object;

    const id_val = data.get("id") orelse return base.send_failed(req, "缺少 id");
    if (id_val != .integer) return base.send_failed(req, "id 格式错误");
    const id: i32 = @intCast(id_val.integer);

    const status = if (data.get("status")) |v| v.string else return base.send_failed(req, "缺少 status");
    const now = datetime.nowGoDatetime();

    _ = OrmBugAnalysis.Update(id, .{
        .status = status,
        .updated_at = now.str,
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, .{ .id = id, .status = status });
}

/// 获取统计概览
fn statisticsImpl(self: *Self, req: zap.Request) !void {
    // 统计测试报告
    var rq = OrmTestReport.Query();
    defer rq.deinit();
    const total_reports = rq.count() catch 0;

    var rq_passed = OrmTestReport.WhereEq("status", "passed");
    defer rq_passed.deinit();
    const passed_reports = rq_passed.count() catch 0;

    var rq_failed = OrmTestReport.WhereEq("status", "failed");
    defer rq_failed.deinit();
    const failed_reports = rq_failed.count() catch 0;

    // 统计 Bug
    var bq = OrmBugAnalysis.Query();
    defer bq.deinit();
    const total_bugs = bq.count() catch 0;

    var bq_pending = OrmBugAnalysis.WhereEq("status", "pending");
    defer bq_pending.deinit();
    const pending_bugs = bq_pending.count() catch 0;

    var bq_resolved = OrmBugAnalysis.WhereEq("status", "resolved");
    defer bq_resolved.deinit();
    const resolved_bugs = bq_resolved.count() catch 0;

    // 使用 self 保持方法签名一致
    const alloc = self.allocator;
    _ = alloc;

    base.send_ok(req, .{
        .reports = .{
            .total = total_reports,
            .passed = passed_reports,
            .failed = failed_reports,
        },
        .bugs = .{
            .total = total_bugs,
            .pending = pending_bugs,
            .resolved = resolved_bugs,
        },
    });
}
