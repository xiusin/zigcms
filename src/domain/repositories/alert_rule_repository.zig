const std = @import("std");
const AlertRule = @import("../entities/alert_rule.zig").AlertRule;

/// 告警规则仓储接口
pub const AlertRuleRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?AlertRule,
        findAll: *const fn (*anyopaque) anyerror![]AlertRule,
        findByType: *const fn (*anyopaque, []const u8) anyerror![]AlertRule,
        findEnabled: *const fn (*anyopaque) anyerror![]AlertRule,
        save: *const fn (*anyopaque, *AlertRule) anyerror!void,
        delete: *const fn (*anyopaque, i32) anyerror!void,
        enable: *const fn (*anyopaque, i32) anyerror!void,
        disable: *const fn (*anyopaque, i32) anyerror!void,
        updatePriority: *const fn (*anyopaque, i32, i32) anyerror!void,
    };

    pub fn findById(self: *AlertRuleRepository, id: i32) !?AlertRule {
        return self.vtable.findById(self.ptr, id);
    }

    pub fn findAll(self: *AlertRuleRepository) ![]AlertRule {
        return self.vtable.findAll(self.ptr);
    }

    pub fn findByType(self: *AlertRuleRepository, rule_type: []const u8) ![]AlertRule {
        return self.vtable.findByType(self.ptr, rule_type);
    }

    pub fn findEnabled(self: *AlertRuleRepository) ![]AlertRule {
        return self.vtable.findEnabled(self.ptr);
    }

    pub fn save(self: *AlertRuleRepository, rule: *AlertRule) !void {
        return self.vtable.save(self.ptr, rule);
    }

    pub fn delete(self: *AlertRuleRepository, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }

    pub fn enable(self: *AlertRuleRepository, id: i32) !void {
        return self.vtable.enable(self.ptr, id);
    }

    pub fn disable(self: *AlertRuleRepository, id: i32) !void {
        return self.vtable.disable(self.ptr, id);
    }

    pub fn updatePriority(self: *AlertRuleRepository, id: i32, priority: i32) !void {
        return self.vtable.updatePriority(self.ptr, id, priority);
    }
};

/// 创建仓储实例
pub fn create(impl: anytype, vtable: *const AlertRuleRepository.VTable) AlertRuleRepository {
    return .{
        .ptr = impl,
        .vtable = vtable,
    };
}
