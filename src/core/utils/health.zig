//! 健康检查模块
//!
//! 提供系统健康检查和就绪检查功能。

const std = @import("std");

/// 健康检查状态
pub const HealthStatus = enum {
    Healthy,
    Degraded,
    Unhealthy,
};

/// 健康检查结果
pub const HealthCheckResult = struct {
    name: []const u8,
    status: HealthStatus,
    message: []const u8,
    duration_ns: i64,
};

/// 健康检查函数类型
pub const HealthCheckFn = fn () HealthCheckResult;

/// 健康检查注册表
pub const HealthRegistry = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    checks: std.StringHashMap(HealthCheckFn),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .checks = std.StringHashMap(HealthCheckFn).init(allocator),
        };
    }

    pub fn register(self: *Self, name: []const u8, check_fn: HealthCheckFn) !void {
        try self.put(name, check_fn);
    }

    pub fn put(self: *Self, name: []const u8, check_fn: HealthCheckFn) !void {
        try self.checks.put(name, check_fn);
    }

    pub fn runAll(self: *Self) []HealthCheckResult {
        const results = self.allocator.alloc(HealthCheckResult, self.checks.count()) catch {
            return &.{};
        };

        var idx: usize = 0;
        var it = self.checks.iterator();
        while (it.next()) |entry| {
            const start = std.time.nanoTimestamp();
            results[idx] = entry.value_ptr.*();
            results[idx].duration_ns = std.time.nanoTimestamp() - start;
            results[idx].name = entry.key_ptr.*;
            idx += 1;
        }

        return results;
    }

    pub fn deinit(self: *Self) void {
        self.checks.deinit();
    }
};

/// 内置健康检查函数
pub const BuiltinChecks = struct {
    /// 检查内存使用
    pub fn memoryCheck() HealthCheckResult {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const status = gpa.deinit();

        return .{
            .name = "memory",
            .status = if (status == .leak) .Degraded else .Healthy,
            .message = if (status == .leak) "Memory leak detected" else "Memory OK",
            .duration_ns = 0,
        };
    }

    /// 检查 goroutine 数量（模拟）
    pub fn goroutineCheck() HealthCheckResult {
        return .{
            .name = "goroutines",
            .status = .Healthy,
            .message = "Goroutines OK",
            .duration_ns = 0,
        };
    }

    /// 检查文件系统
    pub fn filesystemCheck() HealthCheckResult {
        const tmp_dir = std.fs.cwd().openDir("/tmp", .{}) catch {
            return .{
                .name = "filesystem",
                .status = .Degraded,
                .message = "Cannot access /tmp",
                .duration_ns = 0,
            };
        };
        defer tmp_dir.close();

        return .{
            .name = "filesystem",
            .status = .Healthy,
            .message = "Filesystem OK",
            .duration_ns = 0,
        };
    }
};

/// 健康检查响应格式化
pub fn formatHealthResponse(allocator: std.mem.Allocator, results: []const HealthCheckResult) ![]u8 {
    var response = std.ArrayList(u8).init(allocator);

    var overall_status: HealthStatus = .Healthy;
    var unhealthy_count: usize = 0;
    var degraded_count: usize = 0;

    for (results) |result| {
        switch (result.status) {
            .Unhealthy => {
                overall_status = .Unhealthy;
                unhealthy_count += 1;
            },
            .Degraded => {
                if (overall_status == .Healthy) overall_status = .Degraded;
                degraded_count += 1;
            },
            .Healthy => {},
        }
    }

    // 状态行
    try response.appendSlice("status: ");
    switch (overall_status) {
        .Healthy => try response.appendSlice("healthy\n"),
        .Degraded => try response.appendSlice("degraded\n"),
        .Unhealthy => try response.appendSlice("unhealthy\n"),
    }

    // 详细信息
    try response.appendSlice("checks:\n");
    for (results) |result| {
        try response.appendSlice("  - name: \"");
        try response.appendSlice(result.name);
        try response.appendSlice("\"\n    status: \"");
        switch (result.status) {
            .Healthy => try response.appendSlice("healthy"),
            .Degraded => try response.appendSlice("degraded"),
            .Unhealthy => try response.appendSlice("unhealthy"),
        }
        try response.appendSlice("\"\n    message: \"");
        try response.appendSlice(result.message);
        try response.appendSlice("\"\n    duration_ms: ");
        try response.appendFormat(&response.writer(), "{d:.3}", .{@as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0});
        try response.appendSlice("\n");
    }

    // 汇总
    try response.appendSlice("summary:\n");
    try response.appendFormat(&response.writer(), "  healthy: {d}\n", .{results.len - unhealthy_count - degraded_count});
    try response.appendFormat(&response.writer(), "  degraded: {d}\n", .{degraded_count});
    try response.appendFormat(&response.writer(), "  unhealthy: {d}\n", .{unhealthy_count});

    return response.toOwnedSlice();
}

/// JSON 格式的健康检查响应
pub fn formatHealthResponseJson(allocator: std.mem.Allocator, results: []const HealthCheckResult) ![]u8 {
    var response = std.ArrayList(u8).init(allocator);
    const writer = response.writer();

    var overall_status: HealthStatus = .Healthy;
    var unhealthy_count: usize = 0;
    var degraded_count: usize = 0;

    for (results) |result| {
        switch (result.status) {
            .Unhealthy => {
                overall_status = .Unhealthy;
                unhealthy_count += 1;
            },
            .Degraded => {
                if (overall_status == .Healthy) overall_status = .Degraded;
                degraded_count += 1;
            },
            .Healthy => {},
        }
    }

    try writer.print("{{\"status\":\"{}\",\"checks\":[", .{
        switch (overall_status) {
            .Healthy => "healthy",
            .Degraded => "degraded",
            .Unhealthy => "unhealthy",
        },
    });

    for (results, 0..) |result, i| {
        if (i > 0) try writer.print(",", .{});
        try writer.print("{{\"name\":\"{}\",\"status\":\"{}\",\"message\":\"{}\",\"duration_ms\":{d:.3}}}", .{
            result.name,
            switch (result.status) {
                .Healthy => "healthy",
                .Degraded => "degraded",
                .Unhealthy => "unhealthy",
            },
            result.message,
            @as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0,
        });
    }

    try writer.print("],\"summary\":{{\"healthy\":{},\"degraded\":{},\"unhealthy\":{}}}}}", .{
        results.len - unhealthy_count - degraded_count,
        degraded_count,
        unhealthy_count,
    });

    return response.toOwnedSlice();
}
