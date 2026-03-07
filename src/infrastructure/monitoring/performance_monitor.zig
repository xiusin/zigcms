const std = @import("std");
const Allocator = std.mem.Allocator;

/// 指标类型
pub const MetricType = enum {
    counter,    // 计数器
    gauge,      // 仪表
    histogram,  // 直方图
    summary,    // 摘要

    pub fn toString(self: MetricType) []const u8 {
        return switch (self) {
            .counter => "counter",
            .gauge => "gauge",
            .histogram => "histogram",
            .summary => "summary",
        };
    }
};

/// 指标数据点
pub const MetricPoint = struct {
    timestamp: i64,
    value: f64,
    labels: ?std.StringHashMap([]const u8) = null,
};

/// 指标
pub const Metric = struct {
    name: []const u8,
    type: MetricType,
    description: []const u8,
    unit: []const u8,
    points: std.ArrayList(MetricPoint),
    allocator: Allocator,

    pub fn init(allocator: Allocator, name: []const u8, metric_type: MetricType, description: []const u8, unit: []const u8) !*Metric {
        const metric = try allocator.create(Metric);
        metric.* = .{
            .name = try allocator.dupe(u8, name),
            .type = metric_type,
            .description = try allocator.dupe(u8, description),
            .unit = try allocator.dupe(u8, unit),
            .points = std.ArrayList(MetricPoint).init(allocator),
            .allocator = allocator,
        };
        return metric;
    }

    pub fn deinit(self: *Metric) void {
        self.allocator.free(self.name);
        self.allocator.free(self.description);
        self.allocator.free(self.unit);
        
        for (self.points.items) |point| {
            if (point.labels) |labels| {
                var it = labels.iterator();
                while (it.next()) |entry| {
                    self.allocator.free(entry.key_ptr.*);
                    self.allocator.free(entry.value_ptr.*);
                }
                labels.deinit();
            }
        }
        
        self.points.deinit();
        self.allocator.destroy(self);
    }

    pub fn addPoint(self: *Metric, value: f64, labels: ?std.StringHashMap([]const u8)) !void {
        const point = MetricPoint{
            .timestamp = std.time.timestamp(),
            .value = value,
            .labels = labels,
        };
        try self.points.append(point);
    }

    pub fn getLatestValue(self: *const Metric) ?f64 {
        if (self.points.items.len == 0) return null;
        return self.points.items[self.points.items.len - 1].value;
    }

    pub fn getAverageValue(self: *const Metric, duration: i64) !f64 {
        const now = std.time.timestamp();
        const start_time = now - duration;
        
        var sum: f64 = 0;
        var count: u32 = 0;
        
        for (self.points.items) |point| {
            if (point.timestamp >= start_time) {
                sum += point.value;
                count += 1;
            }
        }
        
        if (count == 0) return 0;
        return sum / @as(f64, @floatFromInt(count));
    }

    pub fn getMaxValue(self: *const Metric, duration: i64) !f64 {
        const now = std.time.timestamp();
        const start_time = now - duration;
        
        var max: f64 = 0;
        var found = false;
        
        for (self.points.items) |point| {
            if (point.timestamp >= start_time) {
                if (!found or point.value > max) {
                    max = point.value;
                    found = true;
                }
            }
        }
        
        return max;
    }

    pub fn getMinValue(self: *const Metric, duration: i64) !f64 {
        const now = std.time.timestamp();
        const start_time = now - duration;
        
        var min: f64 = 0;
        var found = false;
        
        for (self.points.items) |point| {
            if (point.timestamp >= start_time) {
                if (!found or point.value < min) {
                    min = point.value;
                    found = true;
                }
            }
        }
        
        return min;
    }
};

/// 性能监控器
pub const PerformanceMonitor = struct {
    allocator: Allocator,
    metrics: std.StringHashMap(*Metric),
    mutex: std.Thread.Mutex,
    retention_duration: i64, // 数据保留时长（秒）
    cleanup_timer: ?std.time.Timer,

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        const monitor = try allocator.create(Self);
        monitor.* = .{
            .allocator = allocator,
            .metrics = std.StringHashMap(*Metric).init(allocator),
            .mutex = std.Thread.Mutex{},
            .retention_duration = 3600, // 默认保留1小时
            .cleanup_timer = null,
        };
        return monitor;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.metrics.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.metrics.deinit();
        self.allocator.destroy(self);
    }

    /// 注册指标
    pub fn registerMetric(self: *Self, name: []const u8, metric_type: MetricType, description: []const u8, unit: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.metrics.contains(name)) {
            return error.MetricAlreadyExists;
        }

        const metric = try Metric.init(self.allocator, name, metric_type, description, unit);
        const name_copy = try self.allocator.dupe(u8, name);
        try self.metrics.put(name_copy, metric);
    }

    /// 记录指标
    pub fn recordMetric(self: *Self, name: []const u8, value: f64, labels: ?std.StringHashMap([]const u8)) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const metric = self.metrics.get(name) orelse return error.MetricNotFound;
        try metric.addPoint(value, labels);
    }

    /// 增加计数器
    pub fn incrementCounter(self: *Self, name: []const u8, delta: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const metric = self.metrics.get(name) orelse return error.MetricNotFound;
        if (metric.type != .counter) return error.InvalidMetricType;

        const current = metric.getLatestValue() orelse 0;
        try metric.addPoint(current + delta, null);
    }

    /// 设置仪表值
    pub fn setGauge(self: *Self, name: []const u8, value: f64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const metric = self.metrics.get(name) orelse return error.MetricNotFound;
        if (metric.type != .gauge) return error.InvalidMetricType;

        try metric.addPoint(value, null);
    }

    /// 获取指标
    pub fn getMetric(self: *Self, name: []const u8) !?*Metric {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.metrics.get(name);
    }

    /// 获取所有指标
    pub fn getAllMetrics(self: *Self) !std.ArrayList(*Metric) {
        self.mutex.lock();
        defer self.mutex.unlock();

        var metrics = std.ArrayList(*Metric).init(self.allocator);
        
        var it = self.metrics.iterator();
        while (it.next()) |entry| {
            try metrics.append(entry.value_ptr.*);
        }
        
        return metrics;
    }

    /// 获取指标统计
    pub fn getMetricStats(self: *Self, name: []const u8, duration: i64) !MetricStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        const metric = self.metrics.get(name) orelse return error.MetricNotFound;

        return MetricStats{
            .name = metric.name,
            .type = metric.type,
            .current = metric.getLatestValue() orelse 0,
            .average = try metric.getAverageValue(duration),
            .max = try metric.getMaxValue(duration),
            .min = try metric.getMinValue(duration),
            .count = @intCast(metric.points.items.len),
        };
    }

    /// 清理过期数据
    pub fn cleanupOldData(self: *Self) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.timestamp();
        const cutoff_time = now - self.retention_duration;

        var it = self.metrics.iterator();
        while (it.next()) |entry| {
            const metric = entry.value_ptr.*;
            
            // 移除过期数据点
            var i: usize = 0;
            while (i < metric.points.items.len) {
                if (metric.points.items[i].timestamp < cutoff_time) {
                    const point = metric.points.orderedRemove(i);
                    if (point.labels) |labels| {
                        var label_it = labels.iterator();
                        while (label_it.next()) |label_entry| {
                            self.allocator.free(label_entry.key_ptr.*);
                            self.allocator.free(label_entry.value_ptr.*);
                        }
                        labels.deinit();
                    }
                } else {
                    i += 1;
                }
            }
        }
    }

    /// 启动自动清理
    pub fn startAutoCleanup(self: *Self) !void {
        self.cleanup_timer = try std.time.Timer.start();
        
        // 在实际项目中，这里应该启动一个后台线程定期清理
        // 这里只是示例
    }

    /// 停止自动清理
    pub fn stopAutoCleanup(self: *Self) void {
        self.cleanup_timer = null;
    }
};

/// 指标统计
pub const MetricStats = struct {
    name: []const u8,
    type: MetricType,
    current: f64,
    average: f64,
    max: f64,
    min: f64,
    count: u32,
};

/// 预定义指标名称
pub const MetricNames = struct {
    // HTTP 指标
    pub const HTTP_REQUEST_COUNT = "http_request_count";
    pub const HTTP_REQUEST_DURATION = "http_request_duration_ms";
    pub const HTTP_REQUEST_SIZE = "http_request_size_bytes";
    pub const HTTP_RESPONSE_SIZE = "http_response_size_bytes";
    pub const HTTP_ERROR_COUNT = "http_error_count";

    // 数据库指标
    pub const DB_QUERY_COUNT = "db_query_count";
    pub const DB_QUERY_DURATION = "db_query_duration_ms";
    pub const DB_CONNECTION_COUNT = "db_connection_count";
    pub const DB_ERROR_COUNT = "db_error_count";

    // 缓存指标
    pub const CACHE_HIT_COUNT = "cache_hit_count";
    pub const CACHE_MISS_COUNT = "cache_miss_count";
    pub const CACHE_HIT_RATE = "cache_hit_rate";
    pub const CACHE_SIZE = "cache_size_bytes";

    // 系统指标
    pub const MEMORY_USAGE = "memory_usage_bytes";
    pub const CPU_USAGE = "cpu_usage_percent";
    pub const GOROUTINE_COUNT = "goroutine_count";
    pub const HEAP_ALLOC = "heap_alloc_bytes";

    // 业务指标
    pub const ACTIVE_USERS = "active_users";
    pub const CONCURRENT_REQUESTS = "concurrent_requests";
    pub const QUEUE_SIZE = "queue_size";
};

/// 初始化默认指标
pub fn initDefaultMetrics(monitor: *PerformanceMonitor) !void {
    // HTTP 指标
    try monitor.registerMetric(MetricNames.HTTP_REQUEST_COUNT, .counter, "HTTP请求总数", "count");
    try monitor.registerMetric(MetricNames.HTTP_REQUEST_DURATION, .histogram, "HTTP请求耗时", "ms");
    try monitor.registerMetric(MetricNames.HTTP_REQUEST_SIZE, .histogram, "HTTP请求大小", "bytes");
    try monitor.registerMetric(MetricNames.HTTP_RESPONSE_SIZE, .histogram, "HTTP响应大小", "bytes");
    try monitor.registerMetric(MetricNames.HTTP_ERROR_COUNT, .counter, "HTTP错误总数", "count");

    // 数据库指标
    try monitor.registerMetric(MetricNames.DB_QUERY_COUNT, .counter, "数据库查询总数", "count");
    try monitor.registerMetric(MetricNames.DB_QUERY_DURATION, .histogram, "数据库查询耗时", "ms");
    try monitor.registerMetric(MetricNames.DB_CONNECTION_COUNT, .gauge, "数据库连接数", "count");
    try monitor.registerMetric(MetricNames.DB_ERROR_COUNT, .counter, "数据库错误总数", "count");

    // 缓存指标
    try monitor.registerMetric(MetricNames.CACHE_HIT_COUNT, .counter, "缓存命中总数", "count");
    try monitor.registerMetric(MetricNames.CACHE_MISS_COUNT, .counter, "缓存未命中总数", "count");
    try monitor.registerMetric(MetricNames.CACHE_HIT_RATE, .gauge, "缓存命中率", "percent");
    try monitor.registerMetric(MetricNames.CACHE_SIZE, .gauge, "缓存大小", "bytes");

    // 系统指标
    try monitor.registerMetric(MetricNames.MEMORY_USAGE, .gauge, "内存使用量", "bytes");
    try monitor.registerMetric(MetricNames.CPU_USAGE, .gauge, "CPU使用率", "percent");
    try monitor.registerMetric(MetricNames.HEAP_ALLOC, .gauge, "堆内存分配", "bytes");

    // 业务指标
    try monitor.registerMetric(MetricNames.ACTIVE_USERS, .gauge, "活跃用户数", "count");
    try monitor.registerMetric(MetricNames.CONCURRENT_REQUESTS, .gauge, "并发请求数", "count");
    try monitor.registerMetric(MetricNames.QUEUE_SIZE, .gauge, "队列大小", "count");
}
