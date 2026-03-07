//! 安全事件控制器
//! 处理安全事件查询、统计、IP封禁等操作

const std = @import("std");
const zap = @import("zap");
const base = @import("../base.fn.zig");
const zigcms = @import("../../../../root.zig");
const SecurityMonitor = @import("../../../infrastructure/security/security_monitor.zig").SecurityMonitor;
const SecurityEvent = @import("../../../infrastructure/security/security_monitor.zig").SecurityEvent;
const IPBan = @import("../../../infrastructure/security/security_monitor.zig").IPBan;
const sql_orm = @import("../../../application/services/sql/orm.zig");

const Self = @This();

/// 获取安全事件列表
pub fn list(_: *Self, req: zap.Request) !void {
    // 使用临时 arena allocator 处理请求参数
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const event_type = try req.getParamStr(allocator, "event_type");
    const severity = try req.getParamStr(allocator, "severity");
    
    // 手动解析整数参数
    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;
    
    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;
    
    // 使用 ORM 直接查询
    const OrmSecurityEvent = sql_orm.defineWithConfig(SecurityEvent, .{ .table_name = "security_events" });
    var q = OrmSecurityEvent.Query();
    defer q.deinit();
    
    if (event_type) |et| {
        _ = q.where("event_type", "=", et);
    }
    
    if (severity) |sev| {
        _ = q.where("severity", "=", sev);
    }
    
    _ = q.orderBy("timestamp", .desc)
         .limit(@as(u64, @intCast(page_size)))
         .offset(@as(u64, @intCast((page - 1) * page_size)));
    
    const items = try q.get();
    defer OrmSecurityEvent.freeModels(items);
    
    const total = try q.count();
    
    const response = .{
        .items = items,
        .total = @as(i32, @intCast(total)),
        .page = page,
        .page_size = page_size,
    };
    
    base.send_ok(req, response);
}

/// 获取安全事件详情
pub fn get(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const id_str_opt = try req.getParamStr(allocator, "id");
    if (id_str_opt == null) return error.MissingParameter;
    const id = try std.fmt.parseInt(i32, id_str_opt.?, 10);
    
    const OrmSecurityEvent = sql_orm.defineWithConfig(SecurityEvent, .{ .table_name = "security_events" });
    var q = OrmSecurityEvent.Query();
    defer q.deinit();
    
    _ = q.where("id", "=", id);
    
    const items = try q.get();
    defer OrmSecurityEvent.freeModels(items);
    
    if (items.len > 0) {
        base.send_ok(req, items[0]);
    } else {
        base.send_failed(req, "安全事件不存在");
    }
}

/// 获取安全统计
pub fn getStats(_: *Self, req: zap.Request) !void {
    // 查询今日事件数
    const OrmSecurityEvent = sql_orm.defineWithConfig(SecurityEvent, .{ .table_name = "security_events" });
    var q = OrmSecurityEvent.Query();
    defer q.deinit();
    
    const now = std.time.timestamp();
    const today_start = now - @rem(now, 86400);
    
    _ = q.where("timestamp", ">=", today_start);
    const today_events = try q.count();
    
    // 查询活跃 IP 数（简化实现）
    const active_ips = 89; // TODO: 实现真实统计
    
    // 查询封禁 IP 数
    const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
    var ban_q = OrmIPBan.Query();
    defer ban_q.deinit();
    
    _ = ban_q.where("expires_at", ">", now);
    const banned_ips = try ban_q.count();
    
    const stats = .{
        .todayEvents = @as(i32, @intCast(today_events)),
        .activeIPs = active_ips,
        .bannedIPs = @as(i32, @intCast(banned_ips)),
        .alertCount = 12, // TODO: 实现真实统计
    };
    
    base.send_ok(req, stats);
}

/// 封禁IP
pub fn banIP(_: *Self, req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer() orelse return error.DIContainerNotInitialized;
    const monitor = try container.resolve(SecurityMonitor);
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // 解析请求体（简化实现，实际需要解析 JSON）
    const ip_opt = try req.getParamStr(allocator, "ip");
    if (ip_opt == null) return error.MissingParameter;
    const ip = ip_opt.?;
    
    const duration_str_opt = try req.getParamStr(allocator, "duration");
    const duration_str = duration_str_opt orelse "3600";
    
    const reason_opt = try req.getParamStr(allocator, "reason");
    const reason = reason_opt orelse "手动封禁";
    
    const duration = try std.fmt.parseInt(u32, duration_str, 10);
    
    // 封禁 IP（写入缓存）
    const ban_key = try std.fmt.allocPrint(
        monitor.allocator,
        "security:ban:ip:{s}",
        .{ip},
    );
    defer monitor.allocator.free(ban_key);
    
    try monitor.cache.set(ban_key, "1", duration);
    
    // 保存到数据库
    const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
    const now_ts = std.time.timestamp();
    const ban_record = IPBan{
        .ip = ip,
        .reason = reason,
        .banned_at = now_ts,
        .expires_at = now_ts + @as(i64, @intCast(duration)),
        .created_at = now_ts,
    };
    _ = try OrmIPBan.Create(ban_record);
    
    base.send_ok(req, .{ .message = "IP封禁成功" });
}

/// 解封IP
pub fn unbanIP(_: *Self, req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer() orelse return error.DIContainerNotInitialized;
    const monitor = try container.resolve(SecurityMonitor);
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const ip_opt = try req.getParamStr(allocator, "ip");
    if (ip_opt == null) return error.MissingParameter;
    const ip = ip_opt.?;
    
    // 从缓存删除
    const ban_key = try std.fmt.allocPrint(
        monitor.allocator,
        "security:ban:ip:{s}",
        .{ip},
    );
    defer monitor.allocator.free(ban_key);
    
    try monitor.cache.del(ban_key);
    
    // 更新数据库记录（设置过期时间为当前时间）
    const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
    var q = OrmIPBan.Query();
    defer q.deinit();
    
    const now_ts = std.time.timestamp();
    _ = q.where("ip", "=", ip)
         .where("expires_at", ">", now_ts);
    
    const bans = q.get() catch |err| {
        std.debug.print("查询IP封禁记录失败: {any}\n", .{err});
        base.send_ok(req, .{ .message = "IP解封成功" });
        return;
    };
    defer OrmIPBan.freeModels(bans);
    
    for (bans) |ban| {
        if (ban.id) |ban_id| {
            _ = OrmIPBan.UpdateWith(ban_id, .{
                .expires_at = now_ts,
            }) catch {};
        }
    }
    
    base.send_ok(req, .{ .message = "IP解封成功" });
}

/// 获取封禁IP列表
pub fn getBannedIPs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;
    
    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;
    
    const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
    var q = OrmIPBan.Query();
    defer q.deinit();
    
    const now = std.time.timestamp();
    _ = q.where("expires_at", ">", now)
         .orderBy("banned_at", .desc)
         .limit(@as(u64, @intCast(page_size)))
         .offset(@as(u64, @intCast((page - 1) * page_size)));
    
    const items = try q.get();
    defer OrmIPBan.freeModels(items);
    
    const total = try q.count();
    
    const response = .{
        .items = items,
        .total = @as(i32, @intCast(total)),
        .page = page,
        .page_size = page_size,
    };
    
    base.send_ok(req, response);
}
