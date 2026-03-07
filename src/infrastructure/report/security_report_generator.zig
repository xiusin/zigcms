const std = @import("std");
const Allocator = std.mem.Allocator;

/// 报告类型
pub const ReportType = enum {
    daily,
    weekly,
    monthly,
    custom,

    pub fn toString(self: ReportType) []const u8 {
        return switch (self) {
            .daily => "daily",
            .weekly => "weekly",
            .monthly => "monthly",
            .custom => "custom",
        };
    }
};

/// 报告格式
pub const ReportFormat = enum {
    html,
    pdf,
    excel,
    json,

    pub fn toString(self: ReportFormat) []const u8 {
        return switch (self) {
            .html => "html",
            .pdf => "pdf",
            .excel => "excel",
            .json => "json",
        };
    }
};

/// 报告参数
pub const ReportParams = struct {
    report_type: ReportType,
    start_date: []const u8,
    end_date: []const u8,
    format: ReportFormat = .html,
    include_charts: bool = true,
    include_details: bool = true,
};

/// 报告数据
pub const ReportData = struct {
    title: []const u8,
    period: []const u8,
    generated_at: i64,
    
    // 统计数据
    total_alerts: u32,
    critical_alerts: u32,
    high_alerts: u32,
    medium_alerts: u32,
    low_alerts: u32,
    
    total_events: u32,
    blocked_ips: u32,
    affected_users: u32,
    
    // 趋势数据
    alert_trend: []TrendPoint,
    event_distribution: []DistributionItem,
    top_attack_types: []AttackTypeItem,
    top_attack_ips: []IPItem,
    
    // 详细数据
    recent_alerts: []AlertSummary,
    recent_events: []EventSummary,
};

pub const TrendPoint = struct {
    date: []const u8,
    count: u32,
};

pub const DistributionItem = struct {
    name: []const u8,
    value: u32,
};

pub const AttackTypeItem = struct {
    type: []const u8,
    count: u32,
    percentage: f32,
};

pub const IPItem = struct {
    ip: []const u8,
    count: u32,
    last_seen: []const u8,
};

pub const AlertSummary = struct {
    id: i32,
    level: []const u8,
    type: []const u8,
    message: []const u8,
    created_at: []const u8,
};

pub const EventSummary = struct {
    id: i32,
    type: []const u8,
    severity: []const u8,
    description: []const u8,
    created_at: []const u8,
};

/// 安全报告生成器
pub const SecurityReportGenerator = struct {
    allocator: Allocator,
    // db: *Database, // 实际项目中需要数据库连接

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    /// 生成日报
    pub fn generateDailyReport(self: *Self, date: []const u8) !ReportData {
        const params = ReportParams{
            .report_type = .daily,
            .start_date = date,
            .end_date = date,
            .format = .html,
        };
        return try self.generateReport(params);
    }

    /// 生成周报
    pub fn generateWeeklyReport(self: *Self, start_date: []const u8, end_date: []const u8) !ReportData {
        const params = ReportParams{
            .report_type = .weekly,
            .start_date = start_date,
            .end_date = end_date,
            .format = .html,
        };
        return try self.generateReport(params);
    }

    /// 生成月报
    pub fn generateMonthlyReport(self: *Self, month: []const u8) !ReportData {
        const params = ReportParams{
            .report_type = .monthly,
            .start_date = month,
            .end_date = month,
            .format = .html,
        };
        return try self.generateReport(params);
    }

    /// 生成自定义报告
    pub fn generateCustomReport(self: *Self, params: ReportParams) !ReportData {
        return try self.generateReport(params);
    }

    /// 生成报告
    fn generateReport(self: *Self, params: ReportParams) !ReportData {
        // 1. 收集统计数据
        const stats = try self.collectStatistics(params);

        // 2. 收集趋势数据
        const trend = try self.collectTrendData(params);

        // 3. 收集分布数据
        const distribution = try self.collectDistributionData(params);

        // 4. 收集Top数据
        const top_types = try self.collectTopAttackTypes(params);
        const top_ips = try self.collectTopAttackIPs(params);

        // 5. 收集详细数据
        const recent_alerts = try self.collectRecentAlerts(params);
        const recent_events = try self.collectRecentEvents(params);

        // 6. 构建报告
        const title = try self.generateTitle(params);
        const period = try self.generatePeriod(params);

        return ReportData{
            .title = title,
            .period = period,
            .generated_at = std.time.timestamp(),
            .total_alerts = stats.total_alerts,
            .critical_alerts = stats.critical_alerts,
            .high_alerts = stats.high_alerts,
            .medium_alerts = stats.medium_alerts,
            .low_alerts = stats.low_alerts,
            .total_events = stats.total_events,
            .blocked_ips = stats.blocked_ips,
            .affected_users = stats.affected_users,
            .alert_trend = trend,
            .event_distribution = distribution,
            .top_attack_types = top_types,
            .top_attack_ips = top_ips,
            .recent_alerts = recent_alerts,
            .recent_events = recent_events,
        };
    }

    /// 收集统计数据
    fn collectStatistics(self: *Self, params: ReportParams) !struct {
        total_alerts: u32,
        critical_alerts: u32,
        high_alerts: u32,
        medium_alerts: u32,
        low_alerts: u32,
        total_events: u32,
        blocked_ips: u32,
        affected_users: u32,
    } {
        _ = self;
        
        // 使用 ORM 查询统计数据
        const OrmAlert = @import("../../domain/entities/alert.model.zig").OrmAlert;
        const OrmSecurityEvent = @import("../../domain/entities/security_event.model.zig").OrmSecurityEvent;
        
        // 查询告警统计
        var alert_q = OrmAlert.Query();
        defer alert_q.deinit();
        
        _ = alert_q.whereBetween("created_at", params.start_date, params.end_date);
        const alerts = try alert_q.get();
        defer OrmAlert.freeModels(alerts);
        
        var critical: u32 = 0;
        var high: u32 = 0;
        var medium: u32 = 0;
        var low: u32 = 0;
        
        for (alerts) |alert| {
            if (std.mem.eql(u8, alert.level, "critical")) {
                critical += 1;
            } else if (std.mem.eql(u8, alert.level, "high")) {
                high += 1;
            } else if (std.mem.eql(u8, alert.level, "medium")) {
                medium += 1;
            } else if (std.mem.eql(u8, alert.level, "low")) {
                low += 1;
            }
        }
        
        // 查询事件统计
        var event_q = OrmSecurityEvent.Query();
        defer event_q.deinit();
        
        _ = event_q.whereBetween("created_at", params.start_date, params.end_date);
        const events = try event_q.get();
        defer OrmSecurityEvent.freeModels(events);
        
        // 统计被阻断的IP（去重）
        var blocked_ip_set = std.StringHashMap(void).init(self.allocator);
        defer blocked_ip_set.deinit();
        
        for (events) |event| {
            if (std.mem.eql(u8, event.action, "blocked")) {
                try blocked_ip_set.put(event.ip_address, {});
            }
        }
        
        // 统计受影响的用户（去重）
        var affected_user_set = std.AutoHashMap(u32, void).init(self.allocator);
        defer affected_user_set.deinit();
        
        for (events) |event| {
            if (event.user_id) |uid| {
                try affected_user_set.put(uid, {});
            }
        }
        
        return .{
            .total_alerts = @intCast(alerts.len),
            .critical_alerts = critical,
            .high_alerts = high,
            .medium_alerts = medium,
            .low_alerts = low,
            .total_events = @intCast(events.len),
            .blocked_ips = @intCast(blocked_ip_set.count()),
            .affected_users = @intCast(affected_user_set.count()),
        };
    }

    /// 收集趋势数据
    fn collectTrendData(self: *Self, params: ReportParams) ![]TrendPoint {
        const OrmAlert = @import("../../domain/entities/alert.model.zig").OrmAlert;
        
        // 查询告警数据
        var q = OrmAlert.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date)
             .orderBy("created_at", "asc");
        
        const alerts = try q.get();
        defer OrmAlert.freeModels(alerts);
        
        // 按日期分组统计
        var date_map = std.StringHashMap(u32).init(self.allocator);
        defer date_map.deinit();
        
        for (alerts) |alert| {
            // 提取日期部分（YYYY-MM-DD）
            const date = alert.created_at[0..10];
            const count = date_map.get(date) orelse 0;
            try date_map.put(date, count + 1);
        }
        
        // 转换为数组
        var trend = std.ArrayList(TrendPoint).init(self.allocator);
        defer trend.deinit();
        
        var it = date_map.iterator();
        while (it.next()) |entry| {
            const date_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            try trend.append(.{
                .date = date_copy,
                .count = entry.value_ptr.*,
            });
        }
        
        return try trend.toOwnedSlice();
    }

    /// 收集分布数据
    fn collectDistributionData(self: *Self, params: ReportParams) ![]DistributionItem {
        const OrmSecurityEvent = @import("../../domain/entities/security_event.model.zig").OrmSecurityEvent;
        
        // 查询事件数据
        var q = OrmSecurityEvent.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date);
        const events = try q.get();
        defer OrmSecurityEvent.freeModels(events);
        
        // 按事件类型分组统计
        var type_map = std.StringHashMap(u32).init(self.allocator);
        defer type_map.deinit();
        
        for (events) |event| {
            const count = type_map.get(event.event_type) orelse 0;
            try type_map.put(event.event_type, count + 1);
        }
        
        // 转换为数组
        var distribution = std.ArrayList(DistributionItem).init(self.allocator);
        defer distribution.deinit();
        
        var it = type_map.iterator();
        while (it.next()) |entry| {
            const name_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            try distribution.append(.{
                .name = name_copy,
                .value = entry.value_ptr.*,
            });
        }
        
        return try distribution.toOwnedSlice();
    }

    /// 收集Top攻击类型
    fn collectTopAttackTypes(self: *Self, params: ReportParams) ![]AttackTypeItem {
        const OrmSecurityEvent = @import("../../domain/entities/security_event.model.zig").OrmSecurityEvent;
        
        // 查询事件数据
        var q = OrmSecurityEvent.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date);
        const events = try q.get();
        defer OrmSecurityEvent.freeModels(events);
        
        const total = events.len;
        
        // 按攻击类型分组统计
        var type_map = std.StringHashMap(u32).init(self.allocator);
        defer type_map.deinit();
        
        for (events) |event| {
            const count = type_map.get(event.event_type) orelse 0;
            try type_map.put(event.event_type, count + 1);
        }
        
        // 转换为数组并排序
        var items = std.ArrayList(AttackTypeItem).init(self.allocator);
        defer items.deinit();
        
        var it = type_map.iterator();
        while (it.next()) |entry| {
            const type_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            const count = entry.value_ptr.*;
            const percentage = if (total > 0) @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(total)) * 100.0 else 0.0;
            
            try items.append(.{
                .type = type_copy,
                .count = count,
                .percentage = percentage,
            });
        }
        
        // 按数量降序排序
        const items_slice = try items.toOwnedSlice();
        std.sort.pdq(AttackTypeItem, items_slice, {}, struct {
            fn lessThan(_: void, a: AttackTypeItem, b: AttackTypeItem) bool {
                return a.count > b.count;
            }
        }.lessThan);
        
        // 只返回前10个
        const top_count = @min(10, items_slice.len);
        return items_slice[0..top_count];
    }

    /// 收集Top攻击IP
    fn collectTopAttackIPs(self: *Self, params: ReportParams) ![]IPItem {
        const OrmSecurityEvent = @import("../../domain/entities/security_event.model.zig").OrmSecurityEvent;
        
        // 查询事件数据
        var q = OrmSecurityEvent.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date);
        const events = try q.get();
        defer OrmSecurityEvent.freeModels(events);
        
        // 按IP分组统计
        var ip_map = std.StringHashMap(struct { count: u32, last_seen: []const u8 }).init(self.allocator);
        defer {
            var it = ip_map.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.value_ptr.last_seen);
            }
            ip_map.deinit();
        }
        
        for (events) |event| {
            if (ip_map.get(event.ip_address)) |info| {
                // 更新计数和最后出现时间
                const last_seen = if (std.mem.order(u8, event.created_at, info.last_seen) == .gt)
                    try self.allocator.dupe(u8, event.created_at)
                else
                    info.last_seen;
                
                if (std.mem.order(u8, event.created_at, info.last_seen) == .gt) {
                    self.allocator.free(info.last_seen);
                }
                
                try ip_map.put(event.ip_address, .{
                    .count = info.count + 1,
                    .last_seen = last_seen,
                });
            } else {
                try ip_map.put(event.ip_address, .{
                    .count = 1,
                    .last_seen = try self.allocator.dupe(u8, event.created_at),
                });
            }
        }
        
        // 转换为数组并排序
        var items = std.ArrayList(IPItem).init(self.allocator);
        defer items.deinit();
        
        var it = ip_map.iterator();
        while (it.next()) |entry| {
            const ip_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            const last_seen_copy = try self.allocator.dupe(u8, entry.value_ptr.last_seen);
            
            try items.append(.{
                .ip = ip_copy,
                .count = entry.value_ptr.count,
                .last_seen = last_seen_copy,
            });
        }
        
        // 按数量降序排序
        const items_slice = try items.toOwnedSlice();
        std.sort.pdq(IPItem, items_slice, {}, struct {
            fn lessThan(_: void, a: IPItem, b: IPItem) bool {
                return a.count > b.count;
            }
        }.lessThan);
        
        // 只返回前10个
        const top_count = @min(10, items_slice.len);
        return items_slice[0..top_count];
    }

    /// 收集最近告警
    fn collectRecentAlerts(self: *Self, params: ReportParams) ![]AlertSummary {
        const OrmAlert = @import("../../domain/entities/alert.model.zig").OrmAlert;
        
        // 查询最近的告警
        var q = OrmAlert.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date)
             .orderBy("created_at", "desc")
             .limit(20);
        
        const alerts = try q.get();
        defer OrmAlert.freeModels(alerts);
        
        // 转换为摘要
        var summaries = std.ArrayList(AlertSummary).init(self.allocator);
        defer summaries.deinit();
        
        for (alerts) |alert| {
            try summaries.append(.{
                .id = alert.id.?,
                .level = try self.allocator.dupe(u8, alert.level),
                .type = try self.allocator.dupe(u8, alert.alert_type),
                .message = try self.allocator.dupe(u8, alert.message),
                .created_at = try self.allocator.dupe(u8, alert.created_at),
            });
        }
        
        return try summaries.toOwnedSlice();
    }

    /// 收集最近事件
    fn collectRecentEvents(self: *Self, params: ReportParams) ![]EventSummary {
        const OrmSecurityEvent = @import("../../domain/entities/security_event.model.zig").OrmSecurityEvent;
        
        // 查询最近的事件
        var q = OrmSecurityEvent.Query();
        defer q.deinit();
        
        _ = q.whereBetween("created_at", params.start_date, params.end_date)
             .orderBy("created_at", "desc")
             .limit(20);
        
        const events = try q.get();
        defer OrmSecurityEvent.freeModels(events);
        
        // 转换为摘要
        var summaries = std.ArrayList(EventSummary).init(self.allocator);
        defer summaries.deinit();
        
        for (events) |event| {
            try summaries.append(.{
                .id = event.id.?,
                .type = try self.allocator.dupe(u8, event.event_type),
                .severity = try self.allocator.dupe(u8, event.severity),
                .description = try self.allocator.dupe(u8, event.description),
                .created_at = try self.allocator.dupe(u8, event.created_at),
            });
        }
        
        return try summaries.toOwnedSlice();
    }

    /// 生成标题
    fn generateTitle(self: *Self, params: ReportParams) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            "安全{s}报告",
            .{switch (params.report_type) {
                .daily => "日",
                .weekly => "周",
                .monthly => "月",
                .custom => "自定义",
            }},
        );
    }

    /// 生成周期
    fn generatePeriod(self: *Self, params: ReportParams) ![]const u8 {
        if (std.mem.eql(u8, params.start_date, params.end_date)) {
            return try std.fmt.allocPrint(
                self.allocator,
                "{s}",
                .{params.start_date},
            );
        } else {
            return try std.fmt.allocPrint(
                self.allocator,
                "{s} 至 {s}",
                .{ params.start_date, params.end_date },
            );
        }
    }

    /// 渲染HTML报告
    pub fn renderHTML(self: *Self, data: ReportData) ![]const u8 {
        var html = std.ArrayList(u8).init(self.allocator);
        defer html.deinit();

        try html.appendSlice("<!DOCTYPE html>\n");
        try html.appendSlice("<html>\n");
        try html.appendSlice("<head>\n");
        try html.appendSlice("  <meta charset=\"UTF-8\">\n");
        try html.appendSlice("  <title>");
        try html.appendSlice(data.title);
        try html.appendSlice("</title>\n");
        try html.appendSlice("  <style>\n");
        try html.appendSlice(try self.getCSS());
        try html.appendSlice("  </style>\n");
        try html.appendSlice("</head>\n");
        try html.appendSlice("<body>\n");
        
        // 报告头部
        try html.appendSlice("  <div class=\"header\">\n");
        try html.appendSlice("    <h1>");
        try html.appendSlice(data.title);
        try html.appendSlice("</h1>\n");
        try html.appendSlice("    <p>报告周期: ");
        try html.appendSlice(data.period);
        try html.appendSlice("</p>\n");
        try html.appendSlice("  </div>\n");
        
        // 统计概览
        try html.appendSlice("  <div class=\"summary\">\n");
        try html.appendSlice("    <h2>统计概览</h2>\n");
        try html.appendSlice("    <div class=\"stats\">\n");
        
        const total_str = try std.fmt.allocPrint(self.allocator, "{d}", .{data.total_alerts});
        defer self.allocator.free(total_str);
        try html.appendSlice("      <div class=\"stat-item\">\n");
        try html.appendSlice("        <div class=\"stat-value\">");
        try html.appendSlice(total_str);
        try html.appendSlice("</div>\n");
        try html.appendSlice("        <div class=\"stat-label\">总告警数</div>\n");
        try html.appendSlice("      </div>\n");
        
        // ... 更多统计项
        
        try html.appendSlice("    </div>\n");
        try html.appendSlice("  </div>\n");
        
        try html.appendSlice("</body>\n");
        try html.appendSlice("</html>\n");

        return try html.toOwnedSlice();
    }

    /// 获取CSS样式
    fn getCSS(self: *Self) ![]const u8 {
        _ = self;
        return 
            \\body { font-family: Arial, sans-serif; margin: 20px; }
            \\.header { text-align: center; margin-bottom: 30px; }
            \\.summary { margin-bottom: 30px; }
            \\.stats { display: flex; gap: 20px; }
            \\.stat-item { flex: 1; padding: 20px; background: #f5f5f5; border-radius: 8px; }
            \\.stat-value { font-size: 32px; font-weight: bold; color: #1890ff; }
            \\.stat-label { font-size: 14px; color: #666; margin-top: 8px; }
        ;
    }
};
