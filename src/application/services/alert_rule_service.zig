const std = @import("std");
const AlertRule = @import("../../domain/entities/alert_rule.zig").AlertRule;
const AlertRuleRepository = @import("../../domain/repositories/alert_rule_repository.zig").AlertRuleRepository;

/// 告警规则服务
pub const AlertRuleService = struct {
    allocator: std.mem.Allocator,
    repository: *AlertRuleRepository,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, repository: *AlertRuleRepository) Self {
        return .{
            .allocator = allocator,
            .repository = repository,
        };
    }

    /// 获取规则列表
    pub fn list(self: *Self) ![]AlertRule {
        return try self.repository.findAll();
    }

    /// 获取启用的规则
    pub fn listEnabled(self: *Self) ![]AlertRule {
        return try self.repository.findEnabled();
    }

    /// 根据类型获取规则
    pub fn listByType(self: *Self, rule_type: []const u8) ![]AlertRule {
        return try self.repository.findByType(rule_type);
    }

    /// 获取规则详情
    pub fn get(self: *Self, id: i32) !?AlertRule {
        return try self.repository.findById(id);
    }

    /// 创建规则
    pub fn create(self: *Self, rule: *AlertRule) !void {
        // 验证规则
        try rule.validate();

        // 设置默认值
        if (rule.priority == 0) {
            rule.priority = 100;
        }

        // 保存规则
        try self.repository.save(rule);

        std.log.info("Alert rule created: {s} (ID: {?d})", .{ rule.name, rule.id });
    }

    /// 更新规则
    pub fn update(self: *Self, id: i32, rule: *AlertRule) !void {
        // 检查规则是否存在
        const existing = try self.repository.findById(id);
        if (existing == null) {
            return error.RuleNotFound;
        }

        // 验证规则
        try rule.validate();

        // 设置 ID
        rule.id = id;

        // 保存规则
        try self.repository.save(rule);

        std.log.info("Alert rule updated: {s} (ID: {d})", .{ rule.name, id });
    }

    /// 删除规则
    pub fn delete(self: *Self, id: i32) !void {
        // 检查规则是否存在
        const existing = try self.repository.findById(id);
        if (existing == null) {
            return error.RuleNotFound;
        }

        // 删除规则
        try self.repository.delete(id);

        std.log.info("Alert rule deleted: ID {d}", .{id});
    }

    /// 启用规则
    pub fn enable(self: *Self, id: i32) !void {
        // 检查规则是否存在
        const existing = try self.repository.findById(id);
        if (existing == null) {
            return error.RuleNotFound;
        }

        // 启用规则
        try self.repository.enable(id);

        std.log.info("Alert rule enabled: ID {d}", .{id});
    }

    /// 禁用规则
    pub fn disable(self: *Self, id: i32) !void {
        // 检查规则是否存在
        const existing = try self.repository.findById(id);
        if (existing == null) {
            return error.RuleNotFound;
        }

        // 禁用规则
        try self.repository.disable(id);

        std.log.info("Alert rule disabled: ID {d}", .{id});
    }

    /// 更新规则优先级
    pub fn updatePriority(self: *Self, id: i32, priority: i32) !void {
        // 检查规则是否存在
        const existing = try self.repository.findById(id);
        if (existing == null) {
            return error.RuleNotFound;
        }

        // 更新优先级
        try self.repository.updatePriority(id, priority);

        std.log.info("Alert rule priority updated: ID {d}, Priority {d}", .{ id, priority });
    }

    /// 测试规则
    pub fn test(self: *Self, rule: *const AlertRule, test_data: std.json.Value) !bool {
        _ = self;
        
        // 验证规则
        try rule.validate();

        // 解析条件
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, rule.conditions, .{});
        defer parsed.deinit();

        const conditions = parsed.value;
        if (conditions != .array) {
            return error.InvalidConditions;
        }

        // 评估条件
        for (conditions.array.items) |condition| {
            if (condition != .object) continue;

            const cond_obj = condition.object;
            const field = cond_obj.get("field") orelse continue;
            const operator = cond_obj.get("operator") orelse continue;
            const value = cond_obj.get("value") orelse continue;

            if (field != .string or operator != .string) continue;

            // 从测试数据中获取字段值
            const test_value = test_data.object.get(field.string) orelse continue;

            // 评估条件
            const result = try evaluateCondition(test_value, operator.string, value);
            if (!result) {
                return false;
            }
        }

        return true;
    }

    /// 评估单个条件
    fn evaluateCondition(test_value: std.json.Value, operator: []const u8, expected_value: std.json.Value) !bool {
        if (std.mem.eql(u8, operator, "eq")) {
            return std.meta.eql(test_value, expected_value);
        } else if (std.mem.eql(u8, operator, "ne")) {
            return !std.meta.eql(test_value, expected_value);
        } else if (std.mem.eql(u8, operator, "gt")) {
            if (test_value == .integer and expected_value == .integer) {
                return test_value.integer > expected_value.integer;
            }
            if (test_value == .float and expected_value == .float) {
                return test_value.float > expected_value.float;
            }
        } else if (std.mem.eql(u8, operator, "lt")) {
            if (test_value == .integer and expected_value == .integer) {
                return test_value.integer < expected_value.integer;
            }
            if (test_value == .float and expected_value == .float) {
                return test_value.float < expected_value.float;
            }
        } else if (std.mem.eql(u8, operator, "gte")) {
            if (test_value == .integer and expected_value == .integer) {
                return test_value.integer >= expected_value.integer;
            }
            if (test_value == .float and expected_value == .float) {
                return test_value.float >= expected_value.float;
            }
        } else if (std.mem.eql(u8, operator, "lte")) {
            if (test_value == .integer and expected_value == .integer) {
                return test_value.integer <= expected_value.integer;
            }
            if (test_value == .float and expected_value == .float) {
                return test_value.float <= expected_value.float;
            }
        } else if (std.mem.eql(u8, operator, "contains")) {
            if (test_value == .string and expected_value == .string) {
                return std.mem.indexOf(u8, test_value.string, expected_value.string) != null;
            }
        }

        return false;
    }
};
