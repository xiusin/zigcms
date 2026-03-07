const std = @import("std");
const zap = @import("zap");
const base = @import("../base.zig");
const PerformanceMonitor = @import("../../infrastructure/monitoring/performance_monitor.zig").PerformanceMonitor;
const MetricStats = @import("../../infrastructure/monitoring/performance_monitor.zig").MetricStats;

/// 性能监控控制器
pub const PerformanceController = struct {
    allocator: std.mem.Allocator,
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, monitor: *PerformanceMonitor) Self {
        return .{
            .allocator = allocator,
            .monitor = monitor,
        };
    }

    /// 获取所有指标
    pub fn getAllMetrics(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取监控器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const monitor = try container.resolve(PerformanceMonitor);
        
        // 获取所有指标
        const metrics = try monitor.getAllMetrics();
        defer metrics.deinit();
        
        // 构建响应
        var response = std.ArrayList(u8).init(allocator);
        defer response.deinit();
        
        try response.appendSlice("[");
        
        for (metrics.items, 0..) |metric, i| {
            if (i > 0) try response.appendSlice(",");
            
            try response.appendSlice("{");
            try response.appendSlice("\"name\":\"");
            try response.appendSlice(metric.name);
            try response.appendSlice("\",\"type\":\"");
            try response.appendSlice(metric.type.toString());
            try response.appendSlice("\",\"description\":\"");
            try response.appendSlice(metric.description);
            try response.appendSlice("\",\"unit\":\"");
            try response.appendSlice(metric.unit);
            try response.appendSlice("\",\"current\":");
            
            if (metric.getLatestValue()) |value| {
                const value_str = try std.fmt.allocPrint(allocator, "{d}", .{value});
                defer allocator.free(value_str);
                try response.appendSlice(value_str);
            } else {
                try response.appendSlice("null");
            }
            
            try response.appendSlice(",\"points\":");
            const points_str = try std.fmt.allocPrint(allocator, "{d}", .{metric.points.items.len});
            defer allocator.free(points_str);
            try response.appendSlice(points_str);
            
            try response.appendSlice("}");
        }
        
        try response.appendSlice("]");
        
        // 返回响应
        try base.send_success(req, response.items);
    }

    /// 获取指定指标
    pub fn getMetric(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取指标名称
        const name = req.getParam("name") orelse {
            try base.send_error(req, 400, "缺少指标名称");
            return;
        };
        
        // 获取监控器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const monitor = try container.resolve(PerformanceMonitor);
        
        // 获取指标
        const metric = try monitor.getMetric(name) orelse {
            try base.send_error(req, 404, "指标不存在");
            return;
        };
        
        // 返回指标数据
        try base.send_success(req, metric);
    }

    /// 获取指标统计
    pub fn getMetricStats(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取指标名称
        const name = req.getParam("name") orelse {
            try base.send_error(req, 400, "缺少指标名称");
            return;
        };
        
        // 获取时间范围（默认1小时）
        const duration_str = req.getParam("duration") orelse "3600";
        const duration = try std.fmt.parseInt(i64, duration_str, 10);
        
        // 获取监控器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const monitor = try container.resolve(PerformanceMonitor);
        
        // 获取统计数据
        const stats = try monitor.getMetricStats(name, duration);
        
        // 返回统计数据
        try base.send_success(req, stats);
    }

    /// 健康检查
    pub fn healthCheck(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取监控器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const monitor = try container.resolve(PerformanceMonitor);
        
        // 检查关键指标
        const http_errors = try monitor.getMetric("http_error_count");
        const db_errors = try monitor.getMetric("db_error_count");
        const memory_usage = try monitor.getMetric("memory_usage_bytes");
        
        var status = "healthy";
        var issues = std.ArrayList([]const u8).init(allocator);
        defer issues.deinit();
        
        // 检查HTTP错误率
        if (http_errors) |metric| {
            if (metric.getLatestValue()) |value| {
                if (value > 100) {
                    status = "unhealthy";
                    try issues.append("HTTP错误率过高");
                }
            }
        }
        
        // 检查数据库错误率
        if (db_errors) |metric| {
            if (metric.getLatestValue()) |value| {
                if (value > 10) {
                    status = "unhealthy";
                    try issues.append("数据库错误率过高");
                }
            }
        }
        
        // 检查内存使用
        if (memory_usage) |metric| {
            if (metric.getLatestValue()) |value| {
                if (value > 1024 * 1024 * 1024) { // 1GB
                    status = "warning";
                    try issues.append("内存使用过高");
                }
            }
        }
        
        // 构建响应
        const response = .{
            .status = status,
            .timestamp = std.time.timestamp(),
            .issues = issues.items,
        };
        
        try base.send_success(req, response);
    }

    /// 获取系统概览
    pub fn getSystemOverview(req: zap.Request) !void {
        const allocator = req.allocator orelse return error.NoAllocator;
        
        // 获取监控器
        const container = @import("../../../core/di/mod.zig").getGlobalContainer();
        const monitor = try container.resolve(PerformanceMonitor);
        
        // 获取关键指标
        const http_requests = try monitor.getMetric("http_request_count");
        const http_duration = try monitor.getMetric("http_request_duration_ms");
        const db_queries = try monitor.getMetric("db_query_count");
        const db_duration = try monitor.getMetric("db_query_duration_ms");
        const cache_hit_rate = try monitor.getMetric("cache_hit_rate");
        const memory_usage = try monitor.getMetric("memory_usage_bytes");
        const cpu_usage = try monitor.getMetric("cpu_usage_percent");
        const active_users = try monitor.getMetric("active_users");
        
        // 构建响应
        const response = .{
            .http = .{
                .total_requests = if (http_requests) |m| m.getLatestValue() else null,
                .avg_duration = if (http_duration) |m| try m.getAverageValue(3600) else null,
            },
            .database = .{
                .total_queries = if (db_queries) |m| m.getLatestValue() else null,
                .avg_duration = if (db_duration) |m| try m.getAverageValue(3600) else null,
            },
            .cache = .{
                .hit_rate = if (cache_hit_rate) |m| m.getLatestValue() else null,
            },
            .system = .{
                .memory_usage = if (memory_usage) |m| m.getLatestValue() else null,
                .cpu_usage = if (cpu_usage) |m| m.getLatestValue() else null,
            },
            .business = .{
                .active_users = if (active_users) |m| m.getLatestValue() else null,
            },
        };
        
        try base.send_success(req, response);
    }

    /// 注册路由
    pub fn registerRoutes(app: *zap.App, controller: *Self) !void {
        try app.route("GET", "/api/monitoring/metrics", getAllMetrics);
        try app.route("GET", "/api/monitoring/metrics/:name", getMetric);
        try app.route("GET", "/api/monitoring/metrics/:name/stats", getMetricStats);
        try app.route("GET", "/api/monitoring/health", healthCheck);
        try app.route("GET", "/api/monitoring/overview", getSystemOverview);
        
        _ = controller;
    }
};
