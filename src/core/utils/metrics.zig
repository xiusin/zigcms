//! 指标收集工具模块
//!
//! 提供应用指标收集和导出功能。

const std = @import("std");

/// 指标类型
pub const MetricType = enum {
    Counter,
    Gauge,
    Histogram,
    Summary,
};

/// 指标值
pub const MetricValue = union(enum) {
    counter: u64,
    gauge: f64,
    histogram: HistogramValue,
};

/// 直方图值
pub const HistogramValue = struct {
    count: u64,
    sum: f64,
    buckets: []const Bucket,

    pub const Bucket = struct {
        le: f64,
        count: u64,
    };
};

/// 指标
pub const Metric = struct {
    name: []const u8,
    help: []const u8,
    metric_type: MetricType,
    value: MetricValue,
    labels: ?std.StringHashMap([]const u8) = null,
};

/// 指标注册表
pub const Registry = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    metrics: std.StringHashMap(Metric),
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .metrics = std.StringHashMap(Metric).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.metrics.deinit();
    }

    /// 注册计数器
    pub fn registerCounter(self: *Self, name: []const u8, help: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.metrics.put(name, .{
            .name = name,
            .help = help,
            .metric_type = .Counter,
            .value = .{ .counter = 0 },
        });
    }

    /// 增加计数器
    pub fn incCounter(self: *Self, name: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.metrics.getPtr(name)) |metric| {
            if (metric.value == .counter) {
                metric.value.counter += 1;
            }
        }
    }

    /// 注册仪表
    pub fn registerGauge(self: *Self, name: []const u8, help: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.metrics.put(name, .{
            .name = name,
            .help = help,
            .metric_type = .Gauge,
            .value = .{ .gauge = 0.0 },
        });
    }

    /// 设置仪表值
    pub fn setGauge(self: *Self, name: []const u8, value: f64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.metrics.getPtr(name)) |metric| {
            if (metric.value == .gauge) {
                metric.value.gauge = value;
            }
        }
    }
};
