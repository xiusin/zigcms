const std = @import("std");

/// 告警规则实体
pub const AlertRule = struct {
    /// 规则 ID
    id: ?i32 = null,
    /// 规则名称
    name: []const u8 = "",
    /// 规则描述
    description: []const u8 = "",
    /// 规则类型（brute_force, sql_injection, xss, csrf, rate_limit, etc.）
    rule_type: []const u8 = "",
    /// 告警级别（critical, high, medium, low）
    level: []const u8 = "",
    /// 规则条件（JSON 格式）
    conditions: []const u8 = "{}",
    /// 触发动作（JSON 格式）
    actions: []const u8 = "{}",
    /// 是否启用
    enabled: bool = true,
    /// 优先级（数字越大优先级越高）
    priority: i32 = 0,
    /// 创建者 ID
    created_by: ?i32 = null,
    /// 创建时间
    created_at: ?i64 = null,
    /// 更新时间
    updated_at: ?i64 = null,

    /// 规则条件结构
    pub const Condition = struct {
        /// 字段名
        field: []const u8,
        /// 操作符（eq, ne, gt, lt, gte, lte, contains, regex）
        operator: []const u8,
        /// 值
        value: std.json.Value,
        /// 逻辑运算符（and, or）
        logic: ?[]const u8 = null,
    };

    /// 规则动作结构
    pub const Action = struct {
        /// 动作类型（alert, block, notify, log）
        action_type: []const u8,
        /// 动作参数
        params: std.json.Value,
    };

    /// 验证规则
    pub fn validate(self: *const AlertRule) !void {
        if (self.name.len == 0) {
            return error.InvalidName;
        }
        if (self.rule_type.len == 0) {
            return error.InvalidRuleType;
        }
        if (self.level.len == 0) {
            return error.InvalidLevel;
        }
        // 验证 conditions 是否为有效 JSON
        var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, self.conditions, .{}) catch {
            return error.InvalidConditions;
        };
        defer parsed.deinit();
        // 验证 actions 是否为有效 JSON
        var parsed_actions = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, self.actions, .{}) catch {
            return error.InvalidActions;
        };
        defer parsed_actions.deinit();
    }
};

/// 规则类型枚举
pub const RuleType = enum {
    brute_force,
    sql_injection,
    xss,
    csrf,
    rate_limit,
    abnormal_access,
    data_leak,
    permission_denied,
    custom,

    pub fn toString(self: RuleType) []const u8 {
        return switch (self) {
            .brute_force => "brute_force",
            .sql_injection => "sql_injection",
            .xss => "xss",
            .csrf => "csrf",
            .rate_limit => "rate_limit",
            .abnormal_access => "abnormal_access",
            .data_leak => "data_leak",
            .permission_denied => "permission_denied",
            .custom => "custom",
        };
    }

    pub fn fromString(str: []const u8) !RuleType {
        if (std.mem.eql(u8, str, "brute_force")) return .brute_force;
        if (std.mem.eql(u8, str, "sql_injection")) return .sql_injection;
        if (std.mem.eql(u8, str, "xss")) return .xss;
        if (std.mem.eql(u8, str, "csrf")) return .csrf;
        if (std.mem.eql(u8, str, "rate_limit")) return .rate_limit;
        if (std.mem.eql(u8, str, "abnormal_access")) return .abnormal_access;
        if (std.mem.eql(u8, str, "data_leak")) return .data_leak;
        if (std.mem.eql(u8, str, "permission_denied")) return .permission_denied;
        if (std.mem.eql(u8, str, "custom")) return .custom;
        return error.InvalidRuleType;
    }
};

/// 告警级别枚举
pub const AlertLevel = enum {
    critical,
    high,
    medium,
    low,

    pub fn toString(self: AlertLevel) []const u8 {
        return switch (self) {
            .critical => "critical",
            .high => "high",
            .medium => "medium",
            .low => "low",
        };
    }

    pub fn fromString(str: []const u8) !AlertLevel {
        if (std.mem.eql(u8, str, "critical")) return .critical;
        if (std.mem.eql(u8, str, "high")) return .high;
        if (std.mem.eql(u8, str, "medium")) return .medium;
        if (std.mem.eql(u8, str, "low")) return .low;
        return error.InvalidAlertLevel;
    }
};
