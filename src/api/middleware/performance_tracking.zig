const std = @import("std");
const zap = @import("zap");
const PerformanceMonitor = @import("../../infrastructure/monitoring/performance_monitor.zig").PerformanceMonitor;
const MetricNames = @import("../../infrastructure/monitoring/performance_monitor.zig").MetricNames;

/// 性能追踪中间件
pub const PerformanceTrackingMiddleware = struct {
    allocator: std.mem.Allocator,
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, monitor: *PerformanceMonitor) Self {
        return .{
            .allocator = allocator,
            .monitor = monitor,
        };
    }

    /// 处理请求
    pub fn handle(self: *Self, req: *zap.Request, next: anytype) !void {
        const start_time = std.time.milliTimestamp();
        
        // 增加并发请求数
        try self.monitor.incrementCounter(MetricNames.CONCURRENT_REQUESTS, 1);
        defer {
            self.monitor.incrementCounter(MetricNames.CONCURRENT_REQUESTS, -1) catch {};
        }

        // 记录请求大小
        if (req.body) |body| {
            try self.monitor.recordMetric(MetricNames.HTTP_REQUEST_SIZE, @floatFromInt(body.len), null);
        }

        // 调用下一个中间件
        try next(req);

        // 计算请求耗时
        const end_time = std.time.milliTimestamp();
        const duration = @as(f64, @floatFromInt(end_time - start_time));

        // 记录指标
        try self.monitor.incrementCounter(MetricNames.HTTP_REQUEST_COUNT, 1);
        try self.monitor.recordMetric(MetricNames.HTTP_REQUEST_DURATION, duration, null);

        // 记录响应大小
        if (req.response_body) |body| {
            try self.monitor.recordMetric(MetricNames.HTTP_RESPONSE_SIZE, @floatFromInt(body.len), null);
        }

        // 记录错误
        if (req.status_code >= 400) {
            try self.monitor.incrementCounter(MetricNames.HTTP_ERROR_COUNT, 1);
        }
    }
};

/// 数据库性能追踪
pub const DatabasePerformanceTracker = struct {
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(monitor: *PerformanceMonitor) Self {
        return .{ .monitor = monitor };
    }

    /// 记录查询开始
    pub fn recordQueryStart(self: *Self) i64 {
        _ = self;
        return std.time.milliTimestamp();
    }

    /// 记录查询结束
    pub fn recordQueryEnd(self: *Self, start_time: i64) !void {
        const end_time = std.time.milliTimestamp();
        const duration = @as(f64, @floatFromInt(end_time - start_time));

        try self.monitor.incrementCounter(MetricNames.DB_QUERY_COUNT, 1);
        try self.monitor.recordMetric(MetricNames.DB_QUERY_DURATION, duration, null);
    }

    /// 记录查询错误
    pub fn recordQueryError(self: *Self) !void {
        try self.monitor.incrementCounter(MetricNames.DB_ERROR_COUNT, 1);
    }

    /// 更新连接数
    pub fn updateConnectionCount(self: *Self, count: u32) !void {
        try self.monitor.setGauge(MetricNames.DB_CONNECTION_COUNT, @floatFromInt(count));
    }
};

/// 缓存性能追踪
pub const CachePerformanceTracker = struct {
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(monitor: *PerformanceMonitor) Self {
        return .{ .monitor = monitor };
    }

    /// 记录缓存命中
    pub fn recordCacheHit(self: *Self) !void {
        try self.monitor.incrementCounter(MetricNames.CACHE_HIT_COUNT, 1);
        try self.updateHitRate();
    }

    /// 记录缓存未命中
    pub fn recordCacheMiss(self: *Self) !void {
        try self.monitor.incrementCounter(MetricNames.CACHE_MISS_COUNT, 1);
        try self.updateHitRate();
    }

    /// 更新命中率
    fn updateHitRate(self: *Self) !void {
        const hit_metric = try self.monitor.getMetric(MetricNames.CACHE_HIT_COUNT) orelse return;
        const miss_metric = try self.monitor.getMetric(MetricNames.CACHE_MISS_COUNT) orelse return;

        const hits = hit_metric.getLatestValue() orelse 0;
        const misses = miss_metric.getLatestValue() orelse 0;
        const total = hits + misses;

        if (total > 0) {
            const hit_rate = (hits / total) * 100.0;
            try self.monitor.setGauge(MetricNames.CACHE_HIT_RATE, hit_rate);
        }
    }

    /// 更新缓存大小
    pub fn updateCacheSize(self: *Self, size: u64) !void {
        try self.monitor.setGauge(MetricNames.CACHE_SIZE, @floatFromInt(size));
    }
};

/// 系统性能追踪
pub const SystemPerformanceTracker = struct {
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(monitor: *PerformanceMonitor) Self {
        return .{ .monitor = monitor };
    }

    /// 更新内存使用量
    pub fn updateMemoryUsage(self: *Self) !void {
        // 获取当前进程内存使用量
        // 这里需要根据操作系统实现
        const memory_usage: u64 = 0; // TODO: 实现内存使用量获取
        try self.monitor.setGauge(MetricNames.MEMORY_USAGE, @floatFromInt(memory_usage));
    }

    /// 更新CPU使用率
    pub fn updateCPUUsage(self: *Self) !void {
        // 获取当前进程CPU使用率
        // 这里需要根据操作系统实现
        const cpu_usage: f64 = 0; // TODO: 实现CPU使用率获取
        try self.monitor.setGauge(MetricNames.CPU_USAGE, cpu_usage);
    }

    /// 更新堆内存分配
    pub fn updateHeapAlloc(self: *Self, alloc: u64) !void {
        try self.monitor.setGauge(MetricNames.HEAP_ALLOC, @floatFromInt(alloc));
    }
};

/// 业务性能追踪
pub const BusinessPerformanceTracker = struct {
    monitor: *PerformanceMonitor,

    const Self = @This();

    pub fn init(monitor: *PerformanceMonitor) Self {
        return .{ .monitor = monitor };
    }

    /// 更新活跃用户数
    pub fn updateActiveUsers(self: *Self, count: u32) !void {
        try self.monitor.setGauge(MetricNames.ACTIVE_USERS, @floatFromInt(count));
    }

    /// 更新队列大小
    pub fn updateQueueSize(self: *Self, size: u32) !void {
        try self.monitor.setGauge(MetricNames.QUEUE_SIZE, @floatFromInt(size));
    }
};
