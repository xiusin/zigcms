//! 性能基准测试模块
//!
//! 提供简单而强大的性能测试功能，用于测量和比较代码执行时间。

const std = @import("std");

/// 基准测试计时器
pub const BenchmarkTimer = struct {
    const Self = @This();

    start_time: i128,
    allocator: std.mem.Allocator,
    lap_count: usize = 0,
    total_ns: i128 = 0,

    pub fn start(allocator: std.mem.Allocator) Self {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .allocator = allocator,
        };
    }

    pub fn lap(self: *Self) void {
        const now = std.time.nanoTimestamp();
        self.total_ns += now - self.start_time;
        self.start_time = now;
        self.lap_count += 1;
    }

    pub fn avgNs(self: *Self) i128 {
        if (self.lap_count == 0) return 0;
        return @divFloor(self.total_ns, @as(i128, @intCast(self.lap_count)));
    }

    pub fn totalNs(self: *Self) i128 {
        return self.total_ns;
    }

    pub fn laps(self: *Self) usize {
        return self.lap_count;
    }

    pub fn report(self: *Self, comptime src: std.builtin.SourceLocation) void {
        const avg = self.avgNs();
        std.debug.print("[BENCH] {s}:{} - avg {d} ns/op ({d} laps)\n", .{
            src.file,
            src.line,
            avg,
            self.lap_count,
        });
    }
};

/// 性能测试结果
pub const BenchmarkResult = struct {
    name: []const u8,
    avg_ns: i128,
    total_ns: i128,
    iterations: usize,
};

/// 简单基准测试运行器
pub const BenchmarkRunner = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
        };
    }

    pub fn run(self: *Self, name: []const u8, iterations: usize, func: fn () anyerror!void) !BenchmarkResult {
        var timer = BenchmarkTimer.start(self.allocator);

        for (0..iterations) |_| {
            try func();
        }

        return BenchmarkResult{
            .name = name,
            .avg_ns = timer.avgNs(),
            .total_ns = timer.totalNs(),
            .iterations = timer.laps(),
        };
    }

    pub fn compare(
        self: *Self,
        name_a: []const u8,
        func_a: fn () anyerror!void,
        name_b: []const u8,
        func_b: fn () anyerror!void,
        iterations: usize,
    ) !void {
        const result_a = try self.run(name_a, iterations, func_a);
        const result_b = try self.run(name_b, iterations, func_b);

        const faster = if (result_a.avg_ns < result_b.avg_ns) result_a else result_b;
        const slower = if (result_a.avg_ns < result_b.avg_ns) result_b else result_a;

        const ratio = @as(f64, @floatFromInt(slower.avg_ns)) / @as(f64, @floatFromInt(faster.avg_ns));

        std.debug.print("\n=== Benchmark Comparison ===\n", .{});
        std.debug.print("{s}: {d} ns/op\n", .{ name_a, result_a.avg_ns });
        std.debug.print("{s}: {d} ns/op\n", .{ name_b, result_b.avg_ns });
        std.debug.print("Winner: {s} ({d:.2}x faster)\n", .{ faster.name, ratio });
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }
};
