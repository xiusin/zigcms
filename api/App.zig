//! 更新后的应用框架 - 遵循整洁架构
//!
//! 职责：
//! - 作为 API 层的统一入口点
//! - 管理 HTTP 路由和请求处理
//! - 协调各层组件处理请求

const std = @import("std");
const zap = @import("zap");

// 导入各层组件
const controllers = @import("controllers/controllers.zig");
const application = @import("../application/Application.zig");
const domain = @import("../domain/Domain.zig");

/// 应用框架
pub const App = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    router: zap.Router,

    /// 初始化应用
    pub fn init(allocator: std.mem.Allocator) !Self {
        // 初始化各层（App本身只负责路由，不需要初始化API层）
        try domain.init(allocator);
        try application.init(allocator);

        return .{
            .allocator = allocator,
            .router = zap.Router.init(allocator, .{
                .not_found = notFoundHandler,
            }),
        };
    }

    /// 销毁应用
    pub fn deinit(self: *Self) void {
        self.router.deinit();
    }

    /// 注册 CRUD 路由 - 适配新的目录结构
    pub fn crud(self: *Self, comptime name: []const u8, comptime T: type) !void {
        const Controller = controllers.common.Crud(T, "zigcms");
        const ctrl_ptr = try self.allocator.create(Controller);
        ctrl_ptr.* = Controller.init(self.allocator);

        try self.router.handle_func("/" ++ name ++ "/list", ctrl_ptr, Controller.list);
        try self.router.handle_func("/" ++ name ++ "/get", ctrl_ptr, Controller.get);
        try self.router.handle_func("/" ++ name ++ "/save", ctrl_ptr, Controller.save);
        try self.router.handle_func("/" ++ name ++ "/delete", ctrl_ptr, Controller.delete);
        try self.router.handle_func("/" ++ name ++ "/modify", ctrl_ptr, Controller.modify);
        try self.router.handle_func("/" ++ name ++ "/select", ctrl_ptr, Controller.select);
    }

    /// 注册路由 - 适配新的控制器路径
    pub fn route(self: *Self, path: []const u8, ctrl: anytype, handler: anytype) !void {
        try self.router.handle_func(path, ctrl, handler);
    }

    /// 启动 HTTP 服务器
    pub fn listen(self: *Self, port: u16) !void {
        var listener = zap.HttpListener.init(.{
            .port = port,
            .on_request = self.router.on_request_handler(),
            .log = true,
            .public_folder = "resources",
            .max_clients = 10000,
            .timeout = 3,
        });
        try listener.listen();
        std.log.info("🚀 服务器启动于 http://127.0.0.1:{d}", .{port});
        zap.start(.{ .threads = 4, .workers = 4 });
    }

    fn notFoundHandler(req: zap.Request) !void {
        req.setStatus(.not_found);
        // 需要导入基础响应函数
        // base.send_failed(req, "404 Not Found");
    }
};