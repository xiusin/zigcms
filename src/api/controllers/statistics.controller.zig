//! 统计控制器
//!
//! 提供数据统计和可视化的 HTTP 接口
//! 需求: 6.1, 6.3, 6.4, 6.5, 6.6, 6.7

const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

const StatisticsService = @import("../../application/services/statistics_service.zig").StatisticsService;

pub fn getModuleDistribution(req: zap.Request) void {
    const allocator = global.get_allocator();
    const project_id_str = req.getParamStr("project_id") orelse {
        base.send_failed(req, "缺少参数 project_id");
        return;
    };

    const project_id = std.fmt.parseInt(i32, project_id_str.str, 10) catch {
        base.send_failed(req, "参数 project_id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(StatisticsService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const distribution = service.getModuleDistribution(project_id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeDistribution(distribution);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = distribution }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn getBugDistribution(req: zap.Request) void {
    const allocator = global.get_allocator();
    const project_id_str = req.getParamStr("project_id") orelse {
        base.send_failed(req, "缺少参数 project_id");
        return;
    };

    const project_id = std.fmt.parseInt(i32, project_id_str.str, 10) catch {
        base.send_failed(req, "参数 project_id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(StatisticsService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const distribution = service.getBugDistribution(project_id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeDistribution(distribution);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = distribution }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn getFeedbackDistribution(req: zap.Request) void {
    const allocator = global.get_allocator();
    const project_id_str = req.getParamStr("project_id") orelse {
        base.send_failed(req, "缺少参数 project_id");
        return;
    };

    const project_id = std.fmt.parseInt(i32, project_id_str.str, 10) catch {
        base.send_failed(req, "参数 project_id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(StatisticsService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const distribution = service.getFeedbackDistribution(project_id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeDistribution(distribution);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = distribution }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn getQualityTrend(req: zap.Request) void {
    const allocator = global.get_allocator();
    const project_id_str = req.getParamStr("project_id") orelse {
        base.send_failed(req, "缺少参数 project_id");
        return;
    };

    const project_id = std.fmt.parseInt(i32, project_id_str.str, 10) catch {
        base.send_failed(req, "参数 project_id 格式错误");
        return;
    };

    // 解析时间范围参数
    const start_time = if (req.getParamStr("start_time")) |s|
        std.fmt.parseInt(i64, s.str, 10) catch null
    else
        null;

    const end_time = if (req.getParamStr("end_time")) |s|
        std.fmt.parseInt(i64, s.str, 10) catch null
    else
        null;

    const container = di.getGlobalContainer();
    const service = container.resolve(StatisticsService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const trend = service.getQualityTrend(project_id, start_time, end_time) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeTrend(trend);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = trend }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn exportChart(req: zap.Request) void {
    _ = req;
    // TODO: 实现图表导出
}
