//! SecurityMonitor 数据库持久化补丁
//! 
//! 将此代码合并到 security_monitor.zig 中

// 在 writeLog 方法中添加数据库持久化
fn writeLog(self: *Self, event: SecurityEvent) !void {
    // 1. 写入控制台日志
    const log_entry = try std.fmt.allocPrint(
        self.allocator,
        "[{?d}] [{s}] [{s}] IP={s} User={?d} Path={s} Method={s} Desc={s}",
        .{
            event.timestamp,
            event.severity,
            event.event_type,
            event.client_ip,
            event.user_id,
            event.path,
            event.method,
            event.description,
        },
    );
    defer self.allocator.free(log_entry);
    
    std.debug.print("{s}\n", .{log_entry});
    
    // 2. 保存到数据库
    if (self.db) |db| {
        _ = db;
        const OrmSecurityEvent = sql_orm.defineWithConfig(SecurityEvent, .{ .table_name = "security_events" });
        var event_copy = event;
        if (event_copy.timestamp == null) {
            event_copy.timestamp = std.time.timestamp();
        }
        _ = OrmSecurityEvent.Create(event_copy) catch |err| {
            std.debug.print("保存安全事件到数据库失败: {any}\n", .{err});
        };
    }
}

// 在 banIP 方法中添加数据库持久化
fn banIP(self: *Self, ip: []const u8) !void {
    // 1. 写入缓存
    const ban_key = try std.fmt.allocPrint(
        self.allocator,
        "security:ban:ip:{s}",
        .{ip},
    );
    defer self.allocator.free(ban_key);
    
    try self.cache.set(ban_key, "1", self.config.ban_duration);
    
    std.debug.print("🚫 IP {s} 已被自动封禁 {d} 秒\n", .{ ip, self.config.ban_duration });
    
    // 2. 保存到数据库
    if (self.db) |db| {
        _ = db;
        const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
        const now = std.time.timestamp();
        var ban_record = IPBan{
            .ip = ip,
            .reason = "自动封禁",
            .banned_at = now,
            .expires_at = now + @as(i64, @intCast(self.config.ban_duration)),
            .created_at = now,
        };
        _ = OrmIPBan.Create(ban_record) catch |err| {
            std.debug.print("保存IP封禁记录到数据库失败: {any}\n", .{err});
        };
    }
}

// 添加新方法：手动封禁IP（带原因和时长）
pub fn banIPWithReason(self: *Self, ip: []const u8, duration: u32, reason: []const u8) !void {
    // 1. 写入缓存
    const ban_key = try std.fmt.allocPrint(
        self.allocator,
        "security:ban:ip:{s}",
        .{ip},
    );
    defer self.allocator.free(ban_key);
    
    try self.cache.set(ban_key, "1", duration);
    
    std.debug.print("🚫 IP {s} 已被手动封禁 {d} 秒，原因: {s}\n", .{ ip, duration, reason });
    
    // 2. 保存到数据库
    if (self.db) |db| {
        _ = db;
        const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
        const now = std.time.timestamp();
        var ban_record = IPBan{
            .ip = ip,
            .reason = reason,
            .banned_at = now,
            .expires_at = now + @as(i64, @intCast(duration)),
            .created_at = now,
        };
        _ = OrmIPBan.Create(ban_record) catch |err| {
            std.debug.print("保存IP封禁记录到数据库失败: {any}\n", .{err});
        };
    }
}

// 添加新方法：解封IP
pub fn unbanIP(self: *Self, ip: []const u8) !void {
    // 1. 从缓存删除
    const ban_key = try std.fmt.allocPrint(
        self.allocator,
        "security:ban:ip:{s}",
        .{ip},
    );
    defer self.allocator.free(ban_key);
    
    try self.cache.del(ban_key);
    
    std.debug.print("✅ IP {s} 已解封\n", .{ip});
    
    // 2. 更新数据库记录（设置过期时间为当前时间）
    if (self.db) |db| {
        _ = db;
        const OrmIPBan = sql_orm.defineWithConfig(IPBan, .{ .table_name = "ip_bans" });
        var q = OrmIPBan.Query();
        defer q.deinit();
        
        _ = q.where("ip", "=", ip)
             .where("expires_at", ">", std.time.timestamp());
        
        const bans = q.get() catch return;
        defer OrmIPBan.freeModels(bans);
        
        for (bans) |ban| {
            if (ban.id) |ban_id| {
                _ = OrmIPBan.UpdateWith(ban_id, .{
                    .expires_at = std.time.timestamp(),
                }) catch {};
            }
        }
    }
}
