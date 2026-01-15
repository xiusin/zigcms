//! 指标收集模块
//!
//! 提供系统指标收集和暴露功能，支持 Prometheus 格式输出。
//!
//! ## 使用示例
//! ```zig
//! const metrics = @import("shared/utils/metrics.zig");
//!
//! var counter = try metrics.Counter.init("http_requests_total", "Total HTTP requests");
//! counter.inc();
//!
//! // 暴露 Prometheus 格式
//! const output = try metrics.collect(std.testing.allocator);
//! ```

const std = @import("std");

/// 指标类型
pub const MetricType = enum {
    Counter,
    Gauge,
    Histogram,
    Summary,
};

/// 指标标签
pub const Labels = struct {
    labels: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) Labels {
        return .{
            .labels = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn put(self: *Labels, key: []const u8, value: []const u8) !void {
        try self.labels.put(key, value);
    }

    pub fn deinit(self: *Labels) void {
        var it = self.labels.valueIterator();
        while (it.next()) |value| {
            self.labels.allocator.free(value.*);
        }
        self.labels.deinit();
    }
};

/// 指标值
pub const MetricValue = struct {
    value: f64,
    labels: Labels,
    timestamp: i64,
};

/// 计数器指标
pub const Counter = struct {
    const Self = @This();

    name: []const u8,
    help: []const u8,
    value: f64,
    labels: std.StringHashMap(f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, help: []const u8) !Self {
        return .{
            .name = try allocator.dupe(u8, name),
            .help = try allocator.dupe(u8, help),
            .value = 0,
            .labels = std.StringHashMap(f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn inc(self: *Self) void {
        self.value += 1;
    }

    pub fn incBy(self: *Self, amount: f64) void {
        self.value += amount;
    }

    pub fn get(self: *Self) f64 {
        return self.value;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.help);
        self.labels.deinit();
    }
};

/// 仪表盘指标
pub const Gauge = struct {
    const Self = @This();

    name: []const u8,
    help: []const u8,
    value: f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, help: []const u8) !Self {
        return .{
            .name = try allocator.dupe(u8, name),
            .help = try allocator.dupe(u8, help),
            .value = 0,
            .allocator = allocator,
        };
    }

    pub fn set(self: *Self, value: f64) void {
        self.value = value;
    }

    pub fn inc(self: *Self) void {
        self.value += 1;
    }

    pub fn dec(self: *Self) void {
        self.value -= 1;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.help);
    }
};

/// 直方图指标
pub const Histogram = struct {
    const Self = @This();

    name: []const u8,
    help: []const u8,
    buckets: []const f64,
    counts: []usize,
    sum: f64,
    count: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, help: []const u8, buckets: []const f64) !Self {
        const counts = try allocator.alloc(usize, buckets.len + 1);
        @memset(counts, 0);

        return .{
            .name = try allocator.dupe(u8, name),
            .help = try allocator.dupe(u8, help),
            .buckets = try allocator.dupe(f64, buckets),
            .counts = counts,
            .sum = 0,
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn observe(self: *Self, value: f64) void {
        self.sum += value;
        self.count += 1;

        for (self.buckets, 0..) |bucket, i| {
            if (value <= bucket) {
                self.counts[i] += 1;
            }
        }
        self.counts[self.buckets.len] += 1;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.help);
        self.allocator.free(self.buckets);
        self.allocator.free(self.counts);
    }
};

/// 指标注册表
pub const Registry = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    counters: std.StringHashMap(*Counter),
    gauges: std.StringHashMap(*Gauge),
    histograms: std.StringHashMap(*Histogram),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .counters = std.StringHashMap(*Counter).init(allocator),
            .gauges = std.StringHashMap(*Gauge).init(allocator),
            .histograms = std.StringHashMap(*Histogram).init(allocator),
        };
    }

    pub fn registerCounter(self: *Self, name: []const u8, help: []const u8) !*Counter {
        if (self.counters.get(name)) |existing| {
            return existing;
        }

        const counter = try self.allocator.create(Counter);
        counter.* = try Counter.init(self.allocator, name, help);
        try self.counters.put(name, counter);

        return counter;
    }

    pub fn registerGauge(self: *Self, name: []const u8, help: []const u8) !*Gauge {
        if (self.gauges.get(name)) |existing| {
            return existing;
        }

        const gauge = try self.allocator.create(Gauge);
        gauge.* = try Gauge.init(self.allocator, name, help);
        try self.gauges.put(name, gauge);

        return gauge;
    }

    pub fn registerHistogram(self: *Self, name: []const u8, help: []const u8, buckets: []const f64) !*Histogram {
        if (self.histograms.get(name)) |existing| {
            return existing;
        }

        const histogram = try self.allocator.create(Histogram);
        histogram.* = try Histogram.init(self.allocator, name, help, buckets);
        try self.histograms.put(name, histogram);

        return histogram;
    }

    pub fn collect(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        var output = std.ArrayList(u8).init(allocator);

        // 收集 Counters
        var counter_it = self.counters.iterator();
        while (counter_it.next()) |entry| {
            try output.appendSlice("# TYPE ");
            try output.appendSlice(entry.key_ptr.*);
            try output.appendSlice(" counter\n");

            if (entry.value_ptr.*.help.len > 0) {
                try output.appendSlice("# HELP ");
                try output.appendSlice(entry.key_ptr.*);
                try output.appendSlice(" ");
                try output.appendSlice(entry.value_ptr.*.help);
                try output.appendSlice("\n");
            }

            try output.appendSlice(entry.key_ptr.*);
            try output.appendSlice(" ");
            try output.appendFormat(&output.writer(), "{d}", .{entry.value_ptr.*.value});
            try output.appendSlice("\n");
        }

        // 收集 Gauges
        var gauge_it = self.gauges.iterator();
        while (gauge_it.next()) |entry| {
            try output.appendSlice("# TYPE ");
            try output.appendSlice(entry.key_ptr.*);
            try output.appendSlice(" gauge\n");

            try output.appendSlice(entry.key_ptr.*);
            try output.appendSlice(" ");
            try output.appendFormat(&output.writer(), "{d}", .{entry.value_ptr.*.value});
            try output.appendSlice("\n");
        }

        return output.toOwnedSlice();
    }

    pub fn deinit(self: *Self) void {
        var counter_it = self.counters.valueIterator();
        while (counter_it.next()) |counter| {
            counter.*.deinit();
            self.allocator.destroy(counter.*);
        }

        var gauge_it = self.gauges.valueIterator();
        while (gauge_it.next()) |gauge| {
            gauge.*.deinit();
            self.allocator.destroy(gauge.*);
        }

        var histogram_it = self.histograms.valueIterator();
        while (histogram_it.next()) |histogram| {
            histogram.*.deinit();
            self.allocator.destroy(histogram.*);
        }

        self.counters.deinit();
        self.gauges.deinit();
        self.histograms.deinit();
    }
};

/// 全局指标注册表
var global_registry: ?*Registry = null;

/// 初始化全局指标注册表
pub fn initGlobalRegistry(allocator: std.mem.Allocator) !void {
    global_registry = try allocator.create(Registry);
    global_registry.?.* = Registry.init(allocator);
}

/// 获取全局指标注册表
pub fn getGlobalRegistry() ?*Registry {
    return global_registry;
}

/// 清理全局指标注册表
pub fn deinitGlobalRegistry(allocator: std.mem.Allocator) void {
    if (global_registry) |reg| {
        reg.*.deinit();
        allocator.destroy(reg);
        global_registry = null;
    }
}
