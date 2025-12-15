//! Request ID 中间件
//!
//! 为每个请求生成唯一的 request_id，用于链路追踪和日志关联。
//! 支持 Server-Timing 响应头，跟踪请求处理耗时。

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

/// 请求上下文，包含 request_id 和 timing 信息
pub const RequestContext = struct {
    request_id: [36]u8,
    start_time: i128,
    timings: std.ArrayList(Timing),
    allocator: Allocator,

    pub const Timing = struct {
        name: []const u8,
        duration_ns: i64,
        description: ?[]const u8 = null,
    };

    /// 初始化请求上下文
    pub fn init(allocator: Allocator) !RequestContext {
        var ctx = RequestContext{
            .request_id = undefined,
            .start_time = std.time.nanoTimestamp(),
            .timings = undefined,
            .allocator = allocator,
        };
        ctx.timings = try std.ArrayList(Timing).initCapacity(allocator, 0);
        generateUUID(&ctx.request_id);
        return ctx;
    }

    /// 释放资源
    pub fn deinit(self: *RequestContext) void {
        self.timings.deinit(self.allocator);
    }

    /// 获取 request_id 字符串
    pub fn getRequestId(self: *const RequestContext) []const u8 {
        return &self.request_id;
    }

    /// 记录一个计时点
    pub fn addTiming(self: *RequestContext, name: []const u8, duration_ns: i64, description: ?[]const u8) void {
        self.timings.append(self.allocator, .{
            .name = name,
            .duration_ns = duration_ns,
            .description = description,
        }) catch {};
    }

    /// 获取总耗时（毫秒）
    pub fn getTotalDurationMs(self: *const RequestContext) f64 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        return @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;
    }

    /// 生成 Server-Timing 响应头值
    pub fn getServerTimingHeader(self: *RequestContext) ![]u8 {
        var buf = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        errdefer buf.deinit(self.allocator);

        // 添加总耗时
        const total_ms = self.getTotalDurationMs();
        try buf.writer(self.allocator).print("total;dur={d:.2}", .{total_ms});

        // 添加各个计时点
        for (self.timings.items) |timing| {
            const dur_ms = @as(f64, @floatFromInt(timing.duration_ns)) / 1_000_000.0;
            if (timing.description) |desc| {
                try buf.writer(self.allocator).print(", {s};dur={d:.2};desc=\"{s}\"", .{ timing.name, dur_ms, desc });
            } else {
                try buf.writer(self.allocator).print(", {s};dur={d:.2}", .{ timing.name, dur_ms });
            }
        }

        return buf.toOwnedSlice(self.allocator);
    }
};

/// 计时器，用于测量代码块执行时间
pub const Timer = struct {
    name: []const u8,
    description: ?[]const u8,
    start_time: i64,
    ctx: *RequestContext,

    /// 开始计时
    pub fn start(ctx: *RequestContext, name: []const u8, description: ?[]const u8) Timer {
        return .{
            .name = name,
            .description = description,
            .start_time = std.time.nanoTimestamp(),
            .ctx = ctx,
        };
    }

    /// 结束计时并记录
    pub fn stop(self: *Timer) void {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        self.ctx.addTiming(self.name, elapsed, self.description);
    }
};

/// 生成 UUID v4
fn generateUUID(buf: *[36]u8) void {
    var random_bytes: [16]u8 = undefined;

    // 使用时间戳和计数器生成伪随机数
    const timestamp = std.time.nanoTimestamp();
    const seed = @as(u64, @intCast(timestamp & 0xFFFFFFFFFFFFFFFF));
    var prng = std.Random.DefaultPrng.init(seed);
    prng.fill(&random_bytes);

    // 设置 UUID 版本 (v4) 和变体
    random_bytes[6] = (random_bytes[6] & 0x0f) | 0x40; // 版本 4
    random_bytes[8] = (random_bytes[8] & 0x3f) | 0x80; // 变体 1

    // 格式化为标准 UUID 字符串
    const hex = "0123456789abcdef";
    var pos: usize = 0;

    inline for ([_]usize{ 0, 1, 2, 3 }) |i| {
        buf[pos] = hex[random_bytes[i] >> 4];
        buf[pos + 1] = hex[random_bytes[i] & 0x0f];
        pos += 2;
    }
    buf[pos] = '-';
    pos += 1;

    inline for ([_]usize{ 4, 5 }) |i| {
        buf[pos] = hex[random_bytes[i] >> 4];
        buf[pos + 1] = hex[random_bytes[i] & 0x0f];
        pos += 2;
    }
    buf[pos] = '-';
    pos += 1;

    inline for ([_]usize{ 6, 7 }) |i| {
        buf[pos] = hex[random_bytes[i] >> 4];
        buf[pos + 1] = hex[random_bytes[i] & 0x0f];
        pos += 2;
    }
    buf[pos] = '-';
    pos += 1;

    inline for ([_]usize{ 8, 9 }) |i| {
        buf[pos] = hex[random_bytes[i] >> 4];
        buf[pos + 1] = hex[random_bytes[i] & 0x0f];
        pos += 2;
    }
    buf[pos] = '-';
    pos += 1;

    inline for ([_]usize{ 10, 11, 12, 13, 14, 15 }) |i| {
        buf[pos] = hex[random_bytes[i] >> 4];
        buf[pos + 1] = hex[random_bytes[i] & 0x0f];
        pos += 2;
    }
}

/// 线程局部存储，用于在请求处理过程中访问当前请求上下文
threadlocal var current_context: ?*RequestContext = null;

/// 获取当前请求上下文
pub fn getCurrentContext() ?*RequestContext {
    return current_context;
}

/// 设置当前请求上下文
pub fn setCurrentContext(ctx: ?*RequestContext) void {
    current_context = ctx;
}

/// 获取当前 request_id（便捷方法）
pub fn getRequestId() ?[]const u8 {
    if (current_context) |ctx| {
        return ctx.getRequestId();
    }
    return null;
}

/// 在当前上下文中添加计时（便捷方法）
pub fn addTiming(name: []const u8, duration_ns: i64, description: ?[]const u8) void {
    if (current_context) |ctx| {
        ctx.addTiming(name, duration_ns, description);
    }
}

/// 开始计时（便捷方法）
pub fn startTimer(name: []const u8, description: ?[]const u8) ?Timer {
    if (current_context) |ctx| {
        return Timer.start(ctx, name, description);
    }
    return null;
}

test "RequestContext: 基本操作" {
    const allocator = std.testing.allocator;
    var ctx = try RequestContext.init(allocator);
    defer ctx.deinit();

    // 验证 request_id 格式
    const id = ctx.getRequestId();
    try std.testing.expectEqual(@as(usize, 36), id.len);
    try std.testing.expectEqual(@as(u8, '-'), id[8]);
    try std.testing.expectEqual(@as(u8, '-'), id[13]);
    try std.testing.expectEqual(@as(u8, '-'), id[18]);
    try std.testing.expectEqual(@as(u8, '-'), id[23]);
}

test "RequestContext: 计时" {
    const allocator = std.testing.allocator;
    var ctx = try RequestContext.init(allocator);
    defer ctx.deinit();

    ctx.addTiming("db", 1_000_000, "数据库查询");
    ctx.addTiming("render", 500_000, null);

    try std.testing.expectEqual(@as(usize, 2), ctx.timings.items.len);

    const header = try ctx.getServerTimingHeader();
    defer allocator.free(header);
    try std.testing.expect(std.mem.indexOf(u8, header, "total;dur=") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "db;dur=") != null);
}
