//! 审核统计 API 控制器

const std = @import("std");
const zap = @import("zap");
const base = @import("../base.zig");

/// 获取审核统计数据
pub fn getStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询统计数据
    // 当前返回模拟数据
    const stats = .{
        .total = 245,
        .pending = 20,
        .approved = 150,
        .rejected = 45,
        .auto_approved = 180,
        .auto_rejected = 30,
    };
    
    try base.send_success(req, stats);
}

/// 获取审核趋势数据
pub fn getTrend(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const days = req.getParamInt("days") orelse 7;
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询趋势数据
    // 当前返回模拟数据
    var trend_data = std.ArrayList(struct {
        date: []const u8,
        approved: i32,
        rejected: i32,
        pending: i32,
    }).init(allocator);
    defer trend_data.deinit();
    
    var i: i32 = @intCast(days - 1);
    while (i >= 0) : (i -= 1) {
        const date = try std.fmt.allocPrint(allocator, "2026-03-{d:0>2}", .{7 - i});
        try trend_data.append(.{
            .date = date,
            .approved = 20 + @rem(i * 7, 30),
            .rejected = 5 + @rem(i * 3, 15),
            .pending = 5 + @rem(i * 2, 10),
        });
    }
    
    try base.send_success(req, trend_data.items);
}

/// 获取敏感词命中统计
pub fn getSensitiveWordStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const limit = req.getParamInt("limit") orelse 10;
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询敏感词命中统计
    // 当前返回模拟数据
    var word_stats = std.ArrayList(struct {
        word: []const u8,
        category: []const u8,
        hit_count: i32,
        level: i32,
    }).init(allocator);
    defer word_stats.deinit();
    
    const words = [_]struct { word: []const u8, category: []const u8, level: i32 }{
        .{ .word = "傻逼", .category = "abuse", .level = 2 },
        .{ .word = "垃圾", .category = "abuse", .level = 1 },
        .{ .word = "加微信", .category = "ad", .level = 1 },
        .{ .word = "白痴", .category = "abuse", .level = 2 },
        .{ .word = "敏感词1", .category = "political", .level = 3 },
        .{ .word = "色情词1", .category = "porn", .level = 3 },
        .{ .word = "暴力词1", .category = "violence", .level = 3 },
        .{ .word = "广告词", .category = "ad", .level = 1 },
        .{ .word = "辱骂词", .category = "abuse", .level = 2 },
        .{ .word = "其他", .category = "general", .level = 1 },
    };
    
    var count: i32 = 0;
    for (words) |word| {
        if (count >= limit) break;
        try word_stats.append(.{
            .word = word.word,
            .category = word.category,
            .hit_count = 45 - count * 3,
            .level = word.level,
        });
        count += 1;
    }
    
    try base.send_success(req, word_stats.items);
}

/// 获取敏感词分类统计
pub fn getCategoryStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询分类统计
    // 当前返回模拟数据
    var category_stats = std.ArrayList(struct {
        category: []const u8,
        count: i32,
    }).init(allocator);
    defer category_stats.deinit();
    
    try category_stats.append(.{ .category = "abuse", .count = 120 });
    try category_stats.append(.{ .category = "ad", .count = 85 });
    try category_stats.append(.{ .category = "political", .count = 45 });
    try category_stats.append(.{ .category = "porn", .count = 38 });
    try category_stats.append(.{ .category = "violence", .count = 32 });
    try category_stats.append(.{ .category = "general", .count = 25 });
    
    try base.send_success(req, category_stats.items);
}

/// 获取用户违规统计
pub fn getUserViolationStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const limit = req.getParamInt("limit") orelse 10;
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询用户违规统计
    // 当前返回模拟数据
    var user_stats = std.ArrayList(struct {
        user_id: i32,
        violation_count: i32,
        credit_score: i32,
        status: []const u8,
        last_violation_at: []const u8,
    }).init(allocator);
    defer user_stats.deinit();
    
    const statuses = [_][]const u8{ "restricted", "warning", "warning", "normal", "normal", "normal", "normal", "normal", "normal", "normal" };
    
    var i: i32 = 0;
    while (i < limit) : (i += 1) {
        const user_id = 1001 + i;
        const violation_count = 15 - i;
        const credit_score = 45 + i * 5;
        const status = statuses[@intCast(i)];
        const last_violation_at = try std.fmt.allocPrint(allocator, "2026-03-{d:0>2} {d:0>2}:{d:0>2}:00", .{ 7 - @divFloor(i, 2), 10 + i, 30 - i * 2 });
        
        try user_stats.append(.{
            .user_id = user_id,
            .violation_count = violation_count,
            .credit_score = credit_score,
            .status = status,
            .last_violation_at = last_violation_at,
        });
    }
    
    try base.send_success(req, user_stats.items);
}

/// 获取审核效率统计
pub fn getEfficiencyStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    
    _ = start_date;
    _ = end_date;
    _ = allocator;
    
    // TODO: 从数据库查询效率统计
    // 当前返回模拟数据
    const efficiency = .{
        .avg_review_time = 18, // 分钟
        .auto_process_rate = 85.7, // 百分比
        .manual_review_rate = 14.3, // 百分比
        .reject_rate = 30.6, // 百分比
        .total_processed = 245,
        .auto_approved = 180,
        .auto_rejected = 30,
        .manual_approved = 20,
        .manual_rejected = 15,
    };
    
    try base.send_success(req, efficiency);
}

/// 获取审核方式分布
pub fn getActionDistribution(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析查询参数
    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    
    _ = start_date;
    _ = end_date;
    
    // TODO: 从数据库查询审核方式分布
    // 当前返回模拟数据
    var action_stats = std.ArrayList(struct {
        action: []const u8,
        count: i32,
    }).init(allocator);
    defer action_stats.deinit();
    
    try action_stats.append(.{ .action = "auto_approved", .count = 180 });
    try action_stats.append(.{ .action = "auto_rejected", .count = 30 });
    try action_stats.append(.{ .action = "manual_approved", .count = 20 });
    try action_stats.append(.{ .action = "manual_rejected", .count = 15 });
    try action_stats.append(.{ .action = "pending", .count = 20 });
    
    try base.send_success(req, action_stats.items);
}
