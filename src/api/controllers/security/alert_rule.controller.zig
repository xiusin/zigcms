const std = @import("std");
const zap = @import("zap");
const AlertRule = @import("../../../domain/entities/alert_rule.zig").AlertRule;
const AlertRuleService = @import("../../../application/services/alert_rule_service.zig").AlertRuleService;

/// 告警规则控制器
pub const AlertRuleController = struct {
    allocator: std.mem.Allocator,
    service: *AlertRuleService,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, service: *AlertRuleService) Self {
        return .{
            .allocator = allocator,
            .service = service,
        };
    }

    /// 获取规则列表
    /// GET /api/security/alert-rules
    pub fn list(self: *Self, req: zap.Request) !void {
        const rules = try self.service.list();
        try req.sendJson(.{
            .code = 200,
            .message = "success",
            .data = rules,
        });
    }

    /// 获取启用的规则
    /// GET /api/security/alert-rules/enabled
    pub fn listEnabled(self: *Self, req: zap.Request) !void {
        const rules = try self.service.listEnabled();
        try req.sendJson(.{
            .code = 200,
            .message = "success",
            .data = rules,
        });
    }

    /// 获取规则详情
    /// GET /api/security/alert-rules/:id
    pub fn get(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        const rule = try self.service.get(id);
        if (rule == null) {
            try req.sendJson(.{
                .code = 404,
                .message = "Rule not found",
            });
            return;
        }

        try req.sendJson(.{
            .code = 200,
            .message = "success",
            .data = rule,
        });
    }

    /// 创建规则
    /// POST /api/security/alert-rules
    pub fn create(self: *Self, req: zap.Request) !void {
        const body = try req.parseBody(AlertRule);
        var rule = body;

        try self.service.create(&rule);

        try req.sendJson(.{
            .code = 200,
            .message = "Rule created successfully",
            .data = rule,
        });
    }

    /// 更新规则
    /// PUT /api/security/alert-rules/:id
    pub fn update(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        const body = try req.parseBody(AlertRule);
        var rule = body;

        try self.service.update(id, &rule);

        try req.sendJson(.{
            .code = 200,
            .message = "Rule updated successfully",
            .data = rule,
        });
    }

    /// 删除规则
    /// DELETE /api/security/alert-rules/:id
    pub fn delete(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        try self.service.delete(id);

        try req.sendJson(.{
            .code = 200,
            .message = "Rule deleted successfully",
        });
    }

    /// 启用规则
    /// POST /api/security/alert-rules/:id/enable
    pub fn enable(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        try self.service.enable(id);

        try req.sendJson(.{
            .code = 200,
            .message = "Rule enabled successfully",
        });
    }

    /// 禁用规则
    /// POST /api/security/alert-rules/:id/disable
    pub fn disable(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        try self.service.disable(id);

        try req.sendJson(.{
            .code = 200,
            .message = "Rule disabled successfully",
        });
    }

    /// 测试规则
    /// POST /api/security/alert-rules/:id/test
    pub fn test(self: *Self, req: zap.Request) !void {
        const id_str = req.getParam("id") orelse return error.MissingId;
        const id = try std.fmt.parseInt(i32, id_str, 10);

        const rule = try self.service.get(id);
        if (rule == null) {
            try req.sendJson(.{
                .code = 404,
                .message = "Rule not found",
            });
            return;
        }

        const body = try req.parseBody(std.json.Value);
        const result = try self.service.test(&rule.?, body);

        try req.sendJson(.{
            .code = 200,
            .message = "Test completed",
            .data = .{
                .matched = result,
            },
        });
    }
};

/// 路由注册
pub fn registerRoutes(app: *zap.App, controller: *AlertRuleController) !void {
    try app.route("GET", "/api/security/alert-rules", controller.list);
    try app.route("GET", "/api/security/alert-rules/enabled", controller.listEnabled);
    try app.route("GET", "/api/security/alert-rules/:id", controller.get);
    try app.route("POST", "/api/security/alert-rules", controller.create);
    try app.route("PUT", "/api/security/alert-rules/:id", controller.update);
    try app.route("DELETE", "/api/security/alert-rules/:id", controller.delete);
    try app.route("POST", "/api/security/alert-rules/:id/enable", controller.enable);
    try app.route("POST", "/api/security/alert-rules/:id/disable", controller.disable);
    try app.route("POST", "/api/security/alert-rules/:id/test", controller.test);
}
