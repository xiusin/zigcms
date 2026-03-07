//! 审核控制器
//!
//! 功能：
//! - 检查内容
//! - 获取待审核列表
//! - 通过审核
//! - 拒绝审核
//! - 审核统计

const std = @import("std");
const zap = @import("zap");
const zigcms = @import("zigcms");
const base = @import("../base.zig");
const ModerationEngine = @import("../../infrastructure/moderation/moderation_engine.zig").ModerationEngine;
const ModerationContext = @import("../../infrastructure/moderation/moderation_engine.zig").ModerationContext;

/// 检查内容
pub fn check(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const content_text = if (obj.get("content_text")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    const user_id = if (obj.get("user_id")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 0 
        else 0;
    
    const user_register_days = if (obj.get("user_register_days")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 0 
        else 0;
    
    const user_credit_score = if (obj.get("user_credit_score")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 100 
        else 100;
    
    const recent_comment_count = if (obj.get("recent_comment_count")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 0 
        else 0;
    
    // 创建审核引擎
    var engine = try ModerationEngine.init(allocator);
    defer engine.deinit();
    
    // 加载敏感词
    try engine.loadSensitiveWords();
    
    // 审核内容
    const ctx = ModerationContext{
        .content_text = content_text,
        .user_id = user_id,
        .user_register_days = user_register_days,
        .user_credit_score = user_credit_score,
        .recent_comment_count = recent_comment_count,
    };
    
    var result = try engine.moderate(ctx);
    defer engine.freeResult(&result);
    
    // 构建响应
    var matched_words = std.ArrayList(std.json.Value).init(allocator);
    defer matched_words.deinit();
    
    for (result.matched_words) |match| {
        var word_obj = std.json.ObjectMap.init(allocator);
        try word_obj.put("word", .{ .string = match.word });
        try word_obj.put("start_pos", .{ .integer = @intCast(match.start_pos) });
        try word_obj.put("end_pos", .{ .integer = @intCast(match.end_pos) });
        try word_obj.put("category", .{ .string = match.category });
        try word_obj.put("level", .{ .integer = @intCast(match.level) });
        try word_obj.put("action", .{ .string = match.action });
        
        try matched_words.append(.{ .object = word_obj });
    }
    
    var matched_rules = std.ArrayList(std.json.Value).init(allocator);
    defer matched_rules.deinit();
    
    for (result.matched_rules) |rule| {
        try matched_rules.append(.{ .string = rule });
    }
    
    // 返回响应
    try base.send_success(req, .{
        .action = .{ .string = result.action.toString() },
        .reason = .{ .string = result.reason },
        .matched_words = .{ .array = try matched_words.toOwnedSlice() },
        .matched_rules = .{ .array = try matched_rules.toOwnedSlice() },
        .cleaned_text = if (result.cleaned_text) |text| .{ .string = text } else .null,
    });
}

/// 获取待审核列表
pub fn getPending(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析分页参数
    const page_str = req.getParamStr("page") orelse "1";
    const page_size_str = req.getParamStr("page_size") orelse "20";
    
    const page = std.fmt.parseInt(i32, page_str, 10) catch 1;
    const page_size = std.fmt.parseInt(i32, page_size_str, 10) catch 20;
    
    // TODO: 从数据库查询待审核列表
    _ = page;
    _ = page_size;
    
    // 模拟数据
    var items = std.ArrayList(std.json.Value).init(allocator);
    defer items.deinit();
    
    // 返回响应
    try base.send_success(req, .{
        .items = .{ .array = try items.toOwnedSlice() },
        .total = .{ .integer = 0 },
        .page = .{ .integer = page },
        .page_size = .{ .integer = page_size },
    });
}

/// 通过审核
pub fn approve(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析请求参数
    const id_str = req.getParamStr("id") orelse {
        try base.send_error(req, 400, "缺少 id 参数");
        return;
    };
    
    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(req, 400, "id 参数无效");
        return;
    };
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const reviewer_id = if (obj.get("reviewer_id")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 0 
        else 0;
    
    const review_reason = if (obj.get("review_reason")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    // TODO: 更新数据库
    std.debug.print("通过审核: id={d}, reviewer_id={d}, reason={s}\n", .{ id, reviewer_id, review_reason });
    
    // 返回响应
    try base.send_success(req, .{
        .message = .{ .string = "审核已通过" },
        .reviewed_at = .{ .integer = std.time.timestamp() },
    });
}

/// 拒绝审核
pub fn reject(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析请求参数
    const id_str = req.getParamStr("id") orelse {
        try base.send_error(req, 400, "缺少 id 参数");
        return;
    };
    
    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(req, 400, "id 参数无效");
        return;
    };
    
    // 解析请求体
    const body = req.body orelse {
        try base.send_error(req, 400, "缺少请求体");
        return;
    };
    
    var parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        body,
        .{},
    ) catch {
        try base.send_error(req, 400, "JSON 解析失败");
        return;
    };
    defer parsed.deinit();
    
    const obj = parsed.value.object;
    
    // 提取字段
    const reviewer_id = if (obj.get("reviewer_id")) |v| 
        if (v == .integer) @as(i32, @intCast(v.integer)) else 0 
        else 0;
    
    const review_reason = if (obj.get("review_reason")) |v| 
        if (v == .string) v.string else "" 
        else "";
    
    // TODO: 更新数据库
    std.debug.print("拒绝审核: id={d}, reviewer_id={d}, reason={s}\n", .{ id, reviewer_id, review_reason });
    
    // 返回响应
    try base.send_success(req, .{
        .message = .{ .string = "审核已拒绝" },
        .reviewed_at = .{ .integer = std.time.timestamp() },
    });
}

/// 审核统计
pub fn getStats(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 解析日期参数
    const start_date = req.getParamStr("start_date");
    const end_date = req.getParamStr("end_date");
    
    // TODO: 从数据库查询统计数据
    _ = start_date;
    _ = end_date;
    
    // 模拟数据
    try base.send_success(req, .{
        .total = .{ .integer = 100 },
        .pending = .{ .integer = 20 },
        .approved = .{ .integer = 60 },
        .rejected = .{ .integer = 15 },
        .auto_approved = .{ .integer = 5 },
        .auto_rejected = .{ .integer = 0 },
    });
}
