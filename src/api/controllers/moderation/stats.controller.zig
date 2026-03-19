//! 审核统计 API 控制器

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("../base.zig");
const sql = @import("../../../application/services/sql/orm.zig");
const global = @import("../../../core/primitives/global.zig");
const ModerationLogModel = @import("../../../domain/entities/moderation_log.model.zig").ModerationLog;

const OrmModerationLog = sql.defineWithConfig(ModerationLogModel, .{
    .table_name = "moderation_logs",
    .primary_key = "id",
});

fn ensureOrmDb() void {
    if (!OrmModerationLog.hasDb()) {
        OrmModerationLog.use(global.get_db());
    }
}

fn parseDateToTimestamp(date_str: []const u8) !i64 {
    if (date_str.len == 0) return 0;
    var year: i32 = 0;
    var month: i32 = 0;
    var day: i32 = 0;
    var hour: i32 = 0;
    var minute: i32 = 0;
    var second: i32 = 0;

    const parts = std.mem.split(u8, date_str, " ");
    const date_part = parts.first();
    if (parts.next()) |time_part| {
        const time_parts = std.mem.split(u8, time_part, ":");
        hour = std.fmt.parseInt(i32, time_parts.first(), 10) catch 0;
        if (time_parts.next()) |m| {
            minute = std.fmt.parseInt(i32, m, 10) catch 0;
            if (time_parts.next()) |s| {
                second = std.fmt.parseInt(i32, s, 10) catch 0;
            }
        }
    }

    const date_nums = std.mem.split(u8, date_part, "-");
    year = std.fmt.parseInt(i32, date_nums.first(), 10) catch 0;
    if (date_nums.next()) |m| {
        month = std.fmt.parseInt(i32, m, 10) catch 0;
        if (date_nums.next()) |d| {
            day = std.fmt.parseInt(i32, d, 10) catch 0;
        }
    }

    const tm = std.time.Tm{
        .year = year - 1900,
        .month = @intCast(month - 1),
        .day = @intCast(day),
        .hour = @intCast(hour),
        .min = @intCast(minute),
        .sec = @intCast(second),
        .west = 0,
        .ymd = undefined,
    };

    return @intCast(@divFloor(tm.toTimestamp(), 1_000_000_000));
}

/// 获取审核统计数据
pub fn getStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    _ = allocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询审核记录失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var stats = struct {
        total: i32 = 0,
        pending: i32 = 0,
        approved: i32 = 0,
        rejected: i32 = 0,
        auto_approved: i32 = 0,
        auto_rejected: i32 = 0,
    }{};

    for (logs) |log| {
        stats.total += 1;
        if (std.mem.eql(u8, log.status, "pending")) {
            stats.pending += 1;
        } else if (std.mem.eql(u8, log.status, "approved")) {
            stats.approved += 1;
        } else if (std.mem.eql(u8, log.status, "rejected")) {
            stats.rejected += 1;
        } else if (std.mem.eql(u8, log.status, "auto_approved")) {
            stats.auto_approved += 1;
        } else if (std.mem.eql(u8, log.status, "auto_rejected")) {
            stats.auto_rejected += 1;
        }
    }

    try base.send_success(req, stats);
}

/// 获取审核趋势数据
pub fn getTrend(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const days = req.getParamInt("days") orelse 7;

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询审核趋势失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var trend_map = std.StringHashMap(struct {
        approved: i32 = 0,
        rejected: i32 = 0,
        pending: i32 = 0,
    }).init(allocator);
    defer {
        var it = trend_map.iterator();
        while (it.next()) |_| {}
        trend_map.deinit();
    }

    for (logs) |log| {
        const ts = log.created_at orelse continue;
        const tm = std.time.Timestamp{ .nanoseconds = ts * 1_000_000_000 };
        const local = tm.toLocal();
        const date_buf = std.fmt.allocPrint(allocator, "{d}-{d:0>2}-{d:0>2}", .{
            local.year + 1900,
            local.month + 1,
            local.day,
        }) catch continue;
        defer allocator.free(date_buf);

        const entry = trend_map.getOrPut(date_buf) catch continue;
        if (!entry.found_existing) {
            entry.value_ptr.* = .{};
        }

        if (std.mem.eql(u8, log.status, "approved") or std.mem.eql(u8, log.status, "auto_approved")) {
            entry.value_ptr.approved += 1;
        } else if (std.mem.eql(u8, log.status, "rejected") or std.mem.eql(u8, log.status, "auto_rejected")) {
            entry.value_ptr.rejected += 1;
        } else if (std.mem.eql(u8, log.status, "pending")) {
            entry.value_ptr.pending += 1;
        }
    }

    var trend_data = std.ArrayList(struct {
        date: []const u8,
        approved: i32,
        rejected: i32,
        pending: i32,
    }).init(allocator);
    defer trend_data.deinit();

    var sorted_keys = std.ArrayList([]const u8).init(allocator);
    defer sorted_keys.deinit();

    var it = trend_map.iterator();
    while (it.next()) |entry| {
        sorted_keys.append(entry.key_ptr.*) catch {};
    }
    std.mem.sort([]const u8, sorted_keys.items, {}, struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);

    for (sorted_keys.items) |key| {
        const counts = trend_map.get(key).?;
        trend_data.append(.{
            .date = key,
            .approved = counts.approved,
            .rejected = counts.rejected,
            .pending = counts.pending,
        }) catch {};
    }

    if (trend_data.items.len == 0) {
        var i: i32 = @intCast(days - 1);
        while (i >= 0) : (i -= 1) {
            const date = std.fmt.allocPrint(allocator, "2026-03-{d:0>2}", .{@intCast(7 - i)}) catch continue;
            trend_data.append(.{
                .date = date,
                .approved = 0,
                .rejected = 0,
                .pending = 0,
            }) catch {};
        }
    }

    try base.send_success(req, trend_data.items);
}

/// 获取敏感词命中统计
pub fn getSensitiveWordStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const limit = req.getParamInt("limit") orelse 10;

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询敏感词统计失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var word_map = std.StringHashMap(struct {
        count: i32 = 0,
        category: []const u8 = "unknown",
        level: i32 = 1,
    }).init(allocator);
    defer {
        var it = word_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        word_map.deinit();
    }

    for (logs) |log| {
        if (log.matched_words.len == 0 or std.mem.eql(u8, log.matched_words, "[]")) continue;

        var json_parsed = std.json.parseFromSlice(std.json.Value, allocator, log.matched_words, .{}) catch continue;
        defer json_parsed.deinit();

        if (json_parsed.value != .array) continue;

        for (json_parsed.value.array.items) |item| {
            if (item != .object) continue;
            const word_obj = item.object;

            const word = word_obj.get("word") orelse continue;
            if (word != .string) continue;
            const word_str = word.string;

            const category = word_obj.get("category") orelse null;
            const category_str = if (category) |c| if (c == .string) c.string else "unknown" else "unknown";

            const level = word_obj.get("level") orelse null;
            const level_val: i32 = if (level) |l| if (l == .integer) @intCast(l.integer) else 1 else 1;

            const word_copy = allocator.dupe(u8, word_str) catch continue;
            const entry = word_map.getOrPut(word_copy) catch {
                allocator.free(word_copy);
                continue;
            };

            if (!entry.found_existing) {
                entry.value_ptr.* = .{
                    .count = 0,
                    .category = allocator.dupe(u8, category_str) catch "unknown",
                    .level = level_val,
                };
            }
            entry.value_ptr.count += 1;
        }
    }

    var sorted_words = std.ArrayList(struct {
        word: []const u8,
        category: []const u8,
        hit_count: i32,
        level: i32,
    }).init(allocator);
    defer sorted_words.deinit();

    var it = word_map.iterator();
    while (it.next()) |entry| {
        sorted_words.append(.{
            .word = entry.key_ptr.*,
            .category = entry.value_ptr.category,
            .hit_count = entry.value_ptr.count,
            .level = entry.value_ptr.level,
        }) catch {};
    }

    std.mem.sort(struct { word: []const u8, category: []const u8, hit_count: i32, level: i32 }, sorted_words.items, {}, struct {
        fn less(_: void, a: struct { word: []const u8, category: []const u8, hit_count: i32, level: i32 }, b: struct { word: []const u8, category: []const u8, hit_count: i32, level: i32 }) bool {
            return a.hit_count > b.hit_count;
        }
    }.less);

    const result_len: usize = @min(@as(usize, @intCast(limit)), sorted_words.items.len);
    try base.send_success(req, sorted_words.items[0..result_len]);
}

/// 获取敏感词分类统计
pub fn getCategoryStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询分类统计失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var category_map = std.StringHashMap(i32).init(allocator);
    defer {
        var it = category_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
        }
        category_map.deinit();
    }

    for (logs) |log| {
        if (log.matched_words.len == 0 or std.mem.eql(u8, log.matched_words, "[]")) continue;

        var json_parsed = std.json.parseFromSlice(std.json.Value, allocator, log.matched_words, .{}) catch continue;
        defer json_parsed.deinit();

        if (json_parsed.value != .array) continue;

        for (json_parsed.value.array.items) |item| {
            if (item != .object) continue;
            const word_obj = item.object;

            const category = word_obj.get("category") orelse continue;
            if (category != .string) continue;

            const category_copy = allocator.dupe(u8, category.string) catch continue;
            const entry = category_map.getOrPut(category_copy) catch {
                allocator.free(category_copy);
                continue;
            };

            if (!entry.found_existing) {
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
        }
    }

    var category_stats = std.ArrayList(struct {
        category: []const u8,
        count: i32,
    }).init(allocator);
    defer category_stats.deinit();

    var it = category_map.iterator();
    while (it.next()) |entry| {
        category_stats.append(.{
            .category = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        }) catch {};
    }

    std.mem.sort(struct { category: []const u8, count: i32 }, category_stats.items, {}, struct {
        fn less(_: void, a: struct { category: []const u8, count: i32 }, b: struct { category: []const u8, count: i32 }) bool {
            return a.count > b.count;
        }
    }.less);

    if (category_stats.items.len == 0) {
        try category_stats.append(.{ .category = "abuse", .count = 0 });
        try category_stats.append(.{ .category = "ad", .count = 0 });
        try category_stats.append(.{ .category = "political", .count = 0 });
        try category_stats.append(.{ .category = "porn", .count = 0 });
        try category_stats.append(.{ .category = "violence", .count = 0 });
        try category_stats.append(.{ .category = "general", .count = 0 });
    }

    try base.send_success(req, category_stats.items);
}

/// 获取用户违规统计
pub fn getUserViolationStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";
    const limit = req.getParamInt("limit") orelse 10;

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询用户违规统计失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var user_map = std.StringHashMap(struct {
        violation_count: i32 = 0,
        last_violation_at: i64 = 0,
    }).init(allocator);
    defer user_map.deinit();

    for (logs) |log| {
        if (std.mem.eql(u8, log.status, "rejected") or std.mem.eql(u8, log.status, "auto_rejected")) {
            const user_key = std.fmt.allocPrint(allocator, "{d}", .{log.user_id}) catch continue;
            const entry = user_map.getOrPut(user_key) catch {
                allocator.free(user_key);
                continue;
            };

            if (!entry.found_existing) {
                entry.value_ptr.* = .{};
            }
            entry.value_ptr.violation_count += 1;

            const log_ts = log.created_at orelse 0;
            if (log_ts > entry.value_ptr.last_violation_at) {
                entry.value_ptr.last_violation_at = log_ts;
            }
        }
    }

    var user_stats = std.ArrayList(struct {
        user_id: i32,
        violation_count: i32,
        credit_score: i32,
        status: []const u8,
        last_violation_at: []const u8,
    }).init(allocator);
    defer user_stats.deinit();

    var it = user_map.iterator();
    while (it.next()) |entry| {
        const user_id = std.fmt.parseInt(i32, entry.key_ptr.*, 10) catch continue;
        const violation_count = entry.value_ptr.violation_count;
        const credit_score: i32 = @max(0, 100 - violation_count * 10);
        const status = if (violation_count >= 10) "restricted" else if (violation_count >= 5) "warning" else "normal";

        var last_violation_at_str: []const u8 = "";
        if (entry.value_ptr.last_violation_at > 0) {
            const ts = entry.value_ptr.last_violation_at;
            const tm = std.time.Timestamp{ .nanoseconds = ts * 1_000_000_000 };
            const local = tm.toLocal();
            last_violation_at_str = std.fmt.allocPrint(allocator, "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:00", .{
                local.year + 1900,
                local.month + 1,
                local.day,
                local.hour,
                local.min,
            }) catch "";
        }

        user_stats.append(.{
            .user_id = user_id,
            .violation_count = violation_count,
            .credit_score = credit_score,
            .status = status,
            .last_violation_at = last_violation_at_str,
        }) catch {};
    }

    std.mem.sort(struct { user_id: i32, violation_count: i32, credit_score: i32, status: []const u8, last_violation_at: []const u8 }, user_stats.items, {}, struct {
        fn less(_: void, a: struct { user_id: i32, violation_count: i32, credit_score: i32, status: []const u8, last_violation_at: []const u8 }, b: struct { user_id: i32, violation_count: i32, credit_score: i32, status: []const u8, last_violation_at: []const u8 }) bool {
            return a.violation_count > b.violation_count;
        }
    }.less);

    const result_len: usize = @min(@as(usize, @intCast(limit)), user_stats.items.len);
    try base.send_success(req, user_stats.items[0..result_len]);
}

/// 获取审核效率统计
pub fn getEfficiencyStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    _ = allocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询效率统计失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var stats = struct {
        total_processed: i32 = 0,
        auto_approved: i32 = 0,
        auto_rejected: i32 = 0,
        manual_approved: i32 = 0,
        manual_rejected: i32 = 0,
        total_review_time: i64 = 0,
        reviewed_count: i32 = 0,
    }{};

    for (logs) |log| {
        stats.total_processed += 1;

        if (std.mem.eql(u8, log.status, "auto_approved")) {
            stats.auto_approved += 1;
        } else if (std.mem.eql(u8, log.status, "auto_rejected")) {
            stats.auto_rejected += 1;
        } else if (std.mem.eql(u8, log.status, "approved") or std.mem.eql(u8, log.status, "rejected")) {
            if (std.mem.eql(u8, log.status, "approved")) {
                stats.manual_approved += 1;
            } else {
                stats.manual_rejected += 1;
            }

            if (log.reviewed_at != null and log.created_at != null) {
                const review_time = log.reviewed_at.? - log.created_at.?;
                stats.total_review_time += review_time;
                stats.reviewed_count += 1;
            }
        }
    }

    const avg_review_time: i32 = if (stats.reviewed_count > 0) @intCast(@divFloor(stats.total_review_time, @as(i64, stats.reviewed_count)) / 60) else 0;
    const total = stats.total_processed;
    const auto_process_rate: f64 = if (total > 0) @as(f64, @floatFromInt(stats.auto_approved + stats.auto_rejected)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;
    const manual_review_rate: f64 = if (total > 0) @as(f64, @floatFromInt(stats.manual_approved + stats.manual_rejected)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;
    const reject_rate: f64 = if (total > 0) @as(f64, @floatFromInt(stats.auto_rejected + stats.manual_rejected)) / @as(f64, @floatFromInt(total)) * 100.0 else 0.0;

    const efficiency = .{
        .avg_review_time = avg_review_time,
        .auto_process_rate = @round(auto_process_rate * 10.0) / 10.0,
        .manual_review_rate = @round(manual_review_rate * 10.0) / 10.0,
        .reject_rate = @round(reject_rate * 10.0) / 10.0,
        .total_processed = stats.total_processed,
        .auto_approved = stats.auto_approved,
        .auto_rejected = stats.auto_rejected,
        .manual_approved = stats.manual_approved,
        .manual_rejected = stats.manual_rejected,
    };

    try base.send_success(req, efficiency);
}

/// 获取审核方式分布
pub fn getActionDistribution(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;

    ensureOrmDb();

    const start_date = req.getParamStr("start_date") orelse "";
    const end_date = req.getParamStr("end_date") orelse "";

    var q = OrmModerationLog.Query();
    defer q.deinit();

    const start_ts = parseDateToTimestamp(start_date) catch 0;
    const end_ts = parseDateToTimestamp(end_date) catch 0;

    if (start_ts > 0) {
        _ = q.whereGte("created_at", start_ts);
    }
    if (end_ts > 0) {
        _ = q.whereLte("created_at", end_ts);
    }

    const logs = q.get() catch |err| {
        std.log.err("[stats] 查询审核方式分布失败: err={}", .{err});
        return base.send_error(req, err);
    };
    defer OrmModerationLog.freeModels(logs);

    var action_map = std.StringHashMap(i32).init(allocator);
    defer action_map.deinit();

    for (logs) |log| {
        const entry = action_map.getOrPut(log.status) catch continue;
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    var action_stats = std.ArrayList(struct {
        action: []const u8,
        count: i32,
    }).init(allocator);
    defer action_stats.deinit();

    const status_order = [_][]const u8{ "pending", "auto_approved", "auto_rejected", "approved", "rejected" };
    for (status_order) |status| {
        if (action_map.get(status)) |count| {
            action_stats.append(.{
                .action = status,
                .count = count,
            }) catch {};
        }
    }

    if (action_stats.items.len == 0) {
        try action_stats.append(.{ .action = "auto_approved", .count = 0 });
        try action_stats.append(.{ .action = "auto_rejected", .count = 0 });
        try action_stats.append(.{ .action = "manual_approved", .count = 0 });
        try action_stats.append(.{ .action = "manual_rejected", .count = 0 });
        try action_stats.append(.{ .action = "pending", .count = 0 });
    }

    try base.send_success(req, action_stats.items);
}
