//! 安全监控系统
//!
//! 提供异常访问检测、敏感操作告警、安全事件日志等功能

const std = @import("std");
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;
const sql_orm = @import("../../application/services/sql/orm.zig");

/// 安全事件类型
pub const SecurityEventType = enum {
    /// 登录失败
    login_failed,
    /// 登录成功
    login_success,
    /// 权限拒绝
    permission_denied,
    /// 速率限制触发
    rate_limit_exceeded,
    /// SQL 注入尝试
    sql_injection_attempt,
    /// XSS 攻击尝试
    xss_attack_attempt,
    /// CSRF 攻击尝试
    csrf_attack_attempt,
    /// 敏感操作
    sensitive_operation,
    /// 异常访问
    abnormal_access,
    /// 数据泄露风险
    data_leak_risk,
    
    pub fn toString(self: SecurityEventType) []const u8 {
        return switch (self) {
            .login_failed => "登录失败",
            .login_success => "登录成功",
            .permission_denied => "权限拒绝",
            .rate_limit_exceeded => "速率限制",
            .sql_injection_attempt => "SQL注入尝试",
            .xss_attack_attempt => "XSS攻击尝试",
            .csrf_attack_attempt => "CSRF攻击尝试",
            .sensitive_operation => "敏感操作",
            .abnormal_access => "异常访问",
            .data_leak_risk => "数据泄露风险",
        };
    }
};

/// 安全事件严重程度
pub const SecuritySeverity = enum {
    low,
    medium,
    high,
    critical,
    
    pub fn toString(self: SecuritySeverity) []const u8 {
        return switch (self) {
            .low => "低",
            .medium => "中",
            .high => "高",
            .critical => "严重",
        };
    }
};

/// 安全事件
pub const SecurityEvent = struct {
    /// 事件 ID
    id: ?i32 = null,
    /// 事件类型
    event_type: []const u8,
    /// 严重程度
    severity: []const u8,
    /// 用户 ID
    user_id: ?i32 = null,
    /// 客户端 IP
    client_ip: []const u8,
    /// 请求路径
    path: []const u8,
    /// 请求方法
    method: []const u8,
    /// 事件描述
    description: []const u8,
    /// 事件详情（JSON）
    details: []const u8 = "{}",
    /// 时间戳
    timestamp: ?i64 = null,
};

/// IP 封禁记录
pub const IPBan = struct {
    /// 记录 ID
    id: ?i32 = null,
    /// IP 地址
    ip: []const u8,
    /// 封禁原因
    reason: []const u8,
    /// 封禁时间
    banned_at: ?i64 = null,
    /// 过期时间
    expires_at: ?i64 = null,
    /// 创建时间
    created_at: ?i64 = null,
};

/// 安全监控配置
pub const SecurityMonitorConfig = struct {
    /// 是否启用监控
    enabled: bool = true,
    /// 是否记录日志
    log_enabled: bool = true,
    /// 是否发送告警
    alert_enabled: bool = true,
    /// 告警阈值（分钟内事件数）
    alert_threshold: u32 = 10,
    /// 告警时间窗口（秒）
    alert_window: u32 = 60,
    /// 是否自动封禁
    auto_ban_enabled: bool = true,
    /// 自动封禁阈值
    auto_ban_threshold: u32 = 20,
    /// 封禁时长（秒）
    ban_duration: u32 = 3600, // 1 小时
};

/// 安全监控器
pub const SecurityMonitor = struct {
    allocator: std.mem.Allocator,
    config: SecurityMonitorConfig,
    cache: *CacheInterface,
    db: ?*sql_orm.Database = null,
    notifier: ?*@import("../notification/dingtalk_notifier.zig").DingTalkNotifier = null,
    
    const Self = @This();
    
    /// 初始化安全监控器
    pub fn init(allocator: std.mem.Allocator, config: SecurityMonitorConfig, cache: *CacheInterface) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .cache = cache,
            .db = null,
        };
    }
    
    /// 设置数据库连接
    pub fn setDatabase(self: *Self, db: *sql_orm.Database) void {
        self.db = db;
    }
    
    /// 设置通知器
    pub fn setNotifier(self: *Self, notifier: *@import("../notification/dingtalk_notifier.zig").DingTalkNotifier) void {
        self.notifier = notifier;
    }
    
    /// 记录安全事件
    pub fn logEvent(self: *Self, event: SecurityEvent) !void {
        if (!self.config.enabled) return;
        
        // 1. 记录日志
        if (self.config.log_enabled) {
            try self.writeLog(event);
        }
        
        // 2. 更新统计
        try self.updateStats(event);
        
        // 3. 检查告警
        if (self.config.alert_enabled) {
            try self.checkAlert(event);
        }
        
        // 4. 检查自动封禁
        if (self.config.auto_ban_enabled) {
            try self.checkAutoBan(event);
        }
    }
    
    /// 写入日志
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
    
    /// 更新统计
    fn updateStats(self: *Self, event: SecurityEvent) !void {
        // 更新 IP 事件计数
        const ip_key = try std.fmt.allocPrint(
            self.allocator,
            "security:stats:ip:{s}:{s}",
            .{ event.client_ip, @tagName(event.event_type) },
        );
        defer self.allocator.free(ip_key);
        
        const count_str = self.cache.get(ip_key, self.allocator) catch null;
        defer if (count_str) |s| self.allocator.free(s);
        
        const count = if (count_str) |s|
            std.fmt.parseInt(u32, s, 10) catch 0
        else
            0;
        
        const new_count = count + 1;
        const new_count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{new_count});
        defer self.allocator.free(new_count_str);
        
        try self.cache.set(ip_key, new_count_str, self.config.alert_window);
    }
    
    /// 检查告警
    fn checkAlert(self: *Self, event: SecurityEvent) !void {
        // 获取 IP 事件计数
        const ip_key = try std.fmt.allocPrint(
            self.allocator,
            "security:stats:ip:{s}:{s}",
            .{ event.client_ip, @tagName(event.event_type) },
        );
        defer self.allocator.free(ip_key);
        
        const count_str = self.cache.get(ip_key, self.allocator) catch return;
        defer self.allocator.free(count_str);
        
        const count = std.fmt.parseInt(u32, count_str, 10) catch return;
        
        // 超过阈值发送告警
        if (count >= self.config.alert_threshold) {
            try self.sendAlert(event, count);
        }
    }
    
    /// 发送告警
    fn sendAlert(self: *Self, event: SecurityEvent, count: u32) !void {
        const alert_message = try std.fmt.allocPrint(
            self.allocator,
            "安全告警: IP {s} 在 {d} 秒内触发 {d} 次 {s} 事件",
            .{
                event.client_ip,
                self.config.alert_window,
                count,
                event.event_type,
            },
        );
        defer self.allocator.free(alert_message);
        
        // 1. 打印日志
        std.debug.print("🚨 {s}\n", .{alert_message});
        
        // 2. 发送钉钉通知
        if (self.notifier) |notifier| {
            _ = notifier.sendSecurityAlert(
                event.event_type,
                event.severity,
                alert_message,
                event.client_ip,
            ) catch |err| {
                std.debug.print("发送告警通知失败: {any}\n", .{err});
            };
        }
    }
    
    /// 检查自动封禁
    fn checkAutoBan(self: *Self, event: SecurityEvent) !void {
        // 只对高危事件自动封禁
        if (event.severity != .high and event.severity != .critical) return;
        
        // 获取 IP 总事件计数
        const ip_total_key = try std.fmt.allocPrint(
            self.allocator,
            "security:stats:ip:{s}:total",
            .{event.client_ip},
        );
        defer self.allocator.free(ip_total_key);
        
        const count_str = self.cache.get(ip_total_key, self.allocator) catch null;
        defer if (count_str) |s| self.allocator.free(s);
        
        const count = if (count_str) |s|
            std.fmt.parseInt(u32, s, 10) catch 0
        else
            0;
        
        const new_count = count + 1;
        const new_count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{new_count});
        defer self.allocator.free(new_count_str);
        
        try self.cache.set(ip_total_key, new_count_str, self.config.alert_window);
        
        // 超过阈值自动封禁
        if (new_count >= self.config.auto_ban_threshold) {
            try self.banIP(event.client_ip);
        }
    }
    
    /// 封禁 IP
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
            const ban_record = IPBan{
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
    
    /// 手动封禁IP（带原因和时长）
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
            const ban_record = IPBan{
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
    
    /// 解封IP
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
    
    /// 检查 IP 是否被封禁
    pub fn isIPBanned(self: *Self, ip: []const u8) !bool {
        const ban_key = try std.fmt.allocPrint(
            self.allocator,
            "security:ban:ip:{s}",
            .{ip},
        );
        defer self.allocator.free(ban_key);
        
        const banned = self.cache.get(ban_key, self.allocator) catch return false;
        defer self.allocator.free(banned);
        
        return true;
    }
    
    /// 获取安全统计
    pub fn getStats(self: *Self, ip: []const u8) !SecurityStats {
        var stats = SecurityStats{
            .ip = ip,
            .total_events = 0,
            .login_failed_count = 0,
            .permission_denied_count = 0,
            .rate_limit_count = 0,
            .is_banned = false,
        };
        
        // 获取总事件数
        const total_key = try std.fmt.allocPrint(
            self.allocator,
            "security:stats:ip:{s}:total",
            .{ip},
        );
        defer self.allocator.free(total_key);
        
        if (self.cache.get(total_key, self.allocator)) |count_str| {
            defer self.allocator.free(count_str);
            stats.total_events = std.fmt.parseInt(u32, count_str, 10) catch 0;
        } else |_| {}
        
        // 检查是否被封禁
        stats.is_banned = try self.isIPBanned(ip);
        
        return stats;
    }
    
    pub const SecurityStats = struct {
        ip: []const u8,
        total_events: u32,
        login_failed_count: u32,
        permission_denied_count: u32,
        rate_limit_count: u32,
        is_banned: bool,
    };
};

/// 敏感操作定义
pub const SensitiveOperations = struct {
    pub const DELETE_PROJECT = "删除项目";
    pub const DELETE_TEST_CASE = "删除测试用例";
    pub const BATCH_DELETE = "批量删除";
    pub const EXPORT_DATA = "导出数据";
    pub const MODIFY_PERMISSION = "修改权限";
    pub const MODIFY_ROLE = "修改角色";
};
