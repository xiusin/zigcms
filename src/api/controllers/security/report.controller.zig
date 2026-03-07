const std = @import("std");
const zap = @import("zap");
const base = @import("../base.zig");
const SecurityReportGenerator = @import("../../infrastructure/report/security_report_generator.zig").SecurityReportGenerator;
const ReportParams = @import("../../infrastructure/report/security_report_generator.zig").ReportParams;
const ReportType = @import("../../infrastructure/report/security_report_generator.zig").ReportType;
const ReportFormat = @import("../../infrastructure/report/security_report_generator.zig").ReportFormat;

/// 报告控制器
pub const ReportController = struct {
    allocator: std.mem.Allocator,
    generator: *SecurityReportGenerator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, generator: *SecurityReportGenerator) Self {
        return .{
            .allocator = allocator,
            .generator = generator,
        };
    }

    /// 生成日报
    pub fn generateDaily(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取日期参数
        const date = req.getParam("date") orelse {
            try base.send_error(req, 400, "缺少日期参数");
            return;
        };
        
        // 获取生成器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const generator = try container.resolve(SecurityReportGenerator);
        
        // 生成报告
        const report = try generator.generateDailyReport(date);
        defer {
            allocator.free(report.title);
            allocator.free(report.period);
            for (report.alert_trend) |point| {
                allocator.free(point.date);
            }
            allocator.free(report.alert_trend);
            for (report.event_distribution) |item| {
                allocator.free(item.name);
            }
            allocator.free(report.event_distribution);
            for (report.top_attack_types) |item| {
                allocator.free(item.type);
            }
            allocator.free(report.top_attack_types);
            for (report.top_attack_ips) |item| {
                allocator.free(item.ip);
                allocator.free(item.last_seen);
            }
            allocator.free(report.top_attack_ips);
            for (report.recent_alerts) |alert| {
                allocator.free(alert.level);
                allocator.free(alert.type);
                allocator.free(alert.message);
                allocator.free(alert.created_at);
            }
            allocator.free(report.recent_alerts);
            for (report.recent_events) |event| {
                allocator.free(event.type);
                allocator.free(event.severity);
                allocator.free(event.description);
                allocator.free(event.created_at);
            }
            allocator.free(report.recent_events);
        }
        
        // 返回报告数据
        try base.send_success(req, report);
    }

    /// 生成周报
    pub fn generateWeekly(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取日期参数
        const start_date = req.getParam("start_date") orelse {
            try base.send_error(req, 400, "缺少开始日期参数");
            return;
        };
        
        const end_date = req.getParam("end_date") orelse {
            try base.send_error(req, 400, "缺少结束日期参数");
            return;
        };
        
        // 获取生成器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const generator = try container.resolve(SecurityReportGenerator);
        
        // 生成报告
        const report = try generator.generateWeeklyReport(start_date, end_date);
        defer {
            allocator.free(report.title);
            allocator.free(report.period);
            for (report.alert_trend) |point| {
                allocator.free(point.date);
            }
            allocator.free(report.alert_trend);
            for (report.event_distribution) |item| {
                allocator.free(item.name);
            }
            allocator.free(report.event_distribution);
            for (report.top_attack_types) |item| {
                allocator.free(item.type);
            }
            allocator.free(report.top_attack_types);
            for (report.top_attack_ips) |item| {
                allocator.free(item.ip);
                allocator.free(item.last_seen);
            }
            allocator.free(report.top_attack_ips);
            for (report.recent_alerts) |alert| {
                allocator.free(alert.level);
                allocator.free(alert.type);
                allocator.free(alert.message);
                allocator.free(alert.created_at);
            }
            allocator.free(report.recent_alerts);
            for (report.recent_events) |event| {
                allocator.free(event.type);
                allocator.free(event.severity);
                allocator.free(event.description);
                allocator.free(event.created_at);
            }
            allocator.free(report.recent_events);
        }
        
        // 返回报告数据
        try base.send_success(req, report);
    }

    /// 生成月报
    pub fn generateMonthly(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取月份参数
        const month = req.getParam("month") orelse {
            try base.send_error(req, 400, "缺少月份参数");
            return;
        };
        
        // 获取生成器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const generator = try container.resolve(SecurityReportGenerator);
        
        // 生成报告
        const report = try generator.generateMonthlyReport(month);
        defer {
            allocator.free(report.title);
            allocator.free(report.period);
            for (report.alert_trend) |point| {
                allocator.free(point.date);
            }
            allocator.free(report.alert_trend);
            for (report.event_distribution) |item| {
                allocator.free(item.name);
            }
            allocator.free(report.event_distribution);
            for (report.top_attack_types) |item| {
                allocator.free(item.type);
            }
            allocator.free(report.top_attack_types);
            for (report.top_attack_ips) |item| {
                allocator.free(item.ip);
                allocator.free(item.last_seen);
            }
            allocator.free(report.top_attack_ips);
            for (report.recent_alerts) |alert| {
                allocator.free(alert.level);
                allocator.free(alert.type);
                allocator.free(alert.message);
                allocator.free(alert.created_at);
            }
            allocator.free(report.recent_alerts);
            for (report.recent_events) |event| {
                allocator.free(event.type);
                allocator.free(event.severity);
                allocator.free(event.description);
                allocator.free(event.created_at);
            }
            allocator.free(report.recent_events);
        }
        
        // 返回报告数据
        try base.send_success(req, report);
    }

    /// 生成自定义报告
    pub fn generateCustom(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 解析请求体
        const body = try req.parseBody();
        const obj = body.object;
        
        // 获取参数
        const report_type_str = if (obj.get("report_type")) |v| if (v == .string) v.string else "custom" else "custom";
        const start_date = if (obj.get("start_date")) |v| if (v == .string) v.string else "" else "";
        const end_date = if (obj.get("end_date")) |v| if (v == .string) v.string else "" else "";
        const format_str = if (obj.get("format")) |v| if (v == .string) v.string else "html" else "html";
        const include_charts = if (obj.get("include_charts")) |v| if (v == .bool) v.bool else true else true;
        const include_details = if (obj.get("include_details")) |v| if (v == .bool) v.bool else true else true;
        
        // 解析报告类型
        const report_type = if (std.mem.eql(u8, report_type_str, "daily"))
            ReportType.daily
        else if (std.mem.eql(u8, report_type_str, "weekly"))
            ReportType.weekly
        else if (std.mem.eql(u8, report_type_str, "monthly"))
            ReportType.monthly
        else
            ReportType.custom;
        
        // 解析报告格式
        const format = if (std.mem.eql(u8, format_str, "pdf"))
            ReportFormat.pdf
        else if (std.mem.eql(u8, format_str, "excel"))
            ReportFormat.excel
        else if (std.mem.eql(u8, format_str, "json"))
            ReportFormat.json
        else
            ReportFormat.html;
        
        // 构建参数
        const params = ReportParams{
            .report_type = report_type,
            .start_date = start_date,
            .end_date = end_date,
            .format = format,
            .include_charts = include_charts,
            .include_details = include_details,
        };
        
        // 获取生成器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const generator = try container.resolve(SecurityReportGenerator);
        
        // 生成报告
        const report = try generator.generateCustomReport(params);
        defer {
            allocator.free(report.title);
            allocator.free(report.period);
            for (report.alert_trend) |point| {
                allocator.free(point.date);
            }
            allocator.free(report.alert_trend);
            for (report.event_distribution) |item| {
                allocator.free(item.name);
            }
            allocator.free(report.event_distribution);
            for (report.top_attack_types) |item| {
                allocator.free(item.type);
            }
            allocator.free(report.top_attack_types);
            for (report.top_attack_ips) |item| {
                allocator.free(item.ip);
                allocator.free(item.last_seen);
            }
            allocator.free(report.top_attack_ips);
            for (report.recent_alerts) |alert| {
                allocator.free(alert.level);
                allocator.free(alert.type);
                allocator.free(alert.message);
                allocator.free(alert.created_at);
            }
            allocator.free(report.recent_alerts);
            for (report.recent_events) |event| {
                allocator.free(event.type);
                allocator.free(event.severity);
                allocator.free(event.description);
                allocator.free(event.created_at);
            }
            allocator.free(report.recent_events);
        }
        
        // 返回报告数据
        try base.send_success(req, report);
    }

    /// 导出HTML报告
    pub fn exportHTML(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 解析请求体
        const body = try req.parseBody();
        const obj = body.object;
        
        // 获取参数
        const start_date = if (obj.get("start_date")) |v| if (v == .string) v.string else "" else "";
        const end_date = if (obj.get("end_date")) |v| if (v == .string) v.string else "" else "";
        
        // 构建参数
        const params = ReportParams{
            .report_type = .custom,
            .start_date = start_date,
            .end_date = end_date,
            .format = .html,
        };
        
        // 获取生成器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const generator = try container.resolve(SecurityReportGenerator);
        
        // 生成报告
        const report = try generator.generateCustomReport(params);
        defer {
            allocator.free(report.title);
            allocator.free(report.period);
            for (report.alert_trend) |point| {
                allocator.free(point.date);
            }
            allocator.free(report.alert_trend);
            for (report.event_distribution) |item| {
                allocator.free(item.name);
            }
            allocator.free(report.event_distribution);
            for (report.top_attack_types) |item| {
                allocator.free(item.type);
            }
            allocator.free(report.top_attack_types);
            for (report.top_attack_ips) |item| {
                allocator.free(item.ip);
                allocator.free(item.last_seen);
            }
            allocator.free(report.top_attack_ips);
            for (report.recent_alerts) |alert| {
                allocator.free(alert.level);
                allocator.free(alert.type);
                allocator.free(alert.message);
                allocator.free(alert.created_at);
            }
            allocator.free(report.recent_alerts);
            for (report.recent_events) |event| {
                allocator.free(event.type);
                allocator.free(event.severity);
                allocator.free(event.description);
                allocator.free(event.created_at);
            }
            allocator.free(report.recent_events);
        }
        
        // 渲染HTML
        const html = try generator.renderHTML(report);
        defer allocator.free(html);
        
        // 设置响应头
        try req.setHeader("Content-Type", "text/html; charset=utf-8");
        try req.setHeader("Content-Disposition", "attachment; filename=\"security_report.html\"");
        
        // 返回HTML
        try req.sendBody(html);
    }

    /// 注册路由
    pub fn registerRoutes(app: *zap.App, controller: *Self) !void {
        try app.route("GET", "/api/security/reports/daily", generateDaily);
        try app.route("GET", "/api/security/reports/weekly", generateWeekly);
        try app.route("GET", "/api/security/reports/monthly", generateMonthly);
        try app.route("POST", "/api/security/reports/custom", generateCustom);
        try app.route("POST", "/api/security/reports/export/html", exportHTML);
        
        _ = controller;
    }
};
