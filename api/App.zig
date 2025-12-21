//! 更新后的应用框架 - 遵循整洁架构
//!
//! 职责：
//! - 作为 API 层的统一入口点
//! - 管理 HTTP 路由和请求处理
//! - 协调各层组件处理请求

const std = @import("std");
const zap = @import("zap");
const logger = @import("../application/services/logger/logger.zig");
const root = @import("../root.zig");
const controllers = @import("controllers/mod.zig");

/// 应用框架
pub const App = struct {
    const Self = @This();

    const ControllerEntry = struct {
        ptr: *anyopaque,
        deinit_fn: *const fn (*anyopaque, std.mem.Allocator) void,
    };

    allocator: std.mem.Allocator,
    router: zap.Router,
    /// 存储已创建的控制器指针，用于清理
    controllers: std.ArrayListUnmanaged(ControllerEntry),

    /// 初始化应用
    pub fn init(allocator: std.mem.Allocator) !Self {
        // 各层已在 zigcms.initSystem() 中初始化，这里只初始化路由
        return .{
            .allocator = allocator,
            .router = zap.Router.init(allocator, .{
                .not_found = notFoundHandler,
            }),
            .controllers = .{},
        };
    }

    /// 销毁应用
    pub fn deinit(self: *Self) void {
        // 清理所有控制器
        for (self.controllers.items) |entry| {
            entry.deinit_fn(entry.ptr, self.allocator);
        }
        self.controllers.deinit(self.allocator);
        self.router.deinit();
    }

    /// 注册 CRUD 路由 - 适配新的目录结构
    pub fn crud(self: *Self, comptime name: []const u8, comptime T: type) !void {
        const Controller = controllers.common.Crud(T, "zigcms");
        const ctrl_ptr = try self.allocator.create(Controller);

        var owned = false;
        errdefer if (!owned) self.allocator.destroy(ctrl_ptr);

        ctrl_ptr.* = Controller.init(self.allocator);

        // 追踪控制器指针以便后续清理
        const destroyFn = struct {
            fn destroy(ptr: *anyopaque, alloc: std.mem.Allocator) void {
                const typed_ptr: *Controller = @ptrCast(@alignCast(ptr));
                alloc.destroy(typed_ptr);
            }
        }.destroy;

        try self.controllers.append(self.allocator, .{
            .ptr = @ptrCast(ctrl_ptr),
            .deinit_fn = destroyFn,
        });
        owned = true;

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

    /// 注册动态 CRUD 路由
    pub fn dynamicCrud(self: *Self) !void {
        const DynamicController = controllers.common.Dynamic;
        const ctrl_ptr = try self.allocator.create(DynamicController);

        var owned = false;
        errdefer if (!owned) self.allocator.destroy(ctrl_ptr);

        ctrl_ptr.* = DynamicController.init(self.allocator);

        // 追踪控制器指针以便后续清理
        const destroyFn = struct {
            fn destroy(ptr: *anyopaque, alloc: std.mem.Allocator) void {
                const typed_ptr: *DynamicController = @ptrCast(@alignCast(ptr));
                typed_ptr.deinit();
                alloc.destroy(typed_ptr);
            }
        }.destroy;

        try self.controllers.append(self.allocator, .{
            .ptr = @ptrCast(ctrl_ptr),
            .deinit_fn = destroyFn,
        });
        owned = true;

        // 注册动态 CRUD 路由 - 基础操作
        try self.router.handle_func("/dynamic/list", ctrl_ptr, DynamicController.list);
        try self.router.handle_func("/dynamic/get", ctrl_ptr, DynamicController.get);
        try self.router.handle_func("/dynamic/save", ctrl_ptr, DynamicController.save);
        try self.router.handle_func("/dynamic/delete", ctrl_ptr, DynamicController.delete);
        try self.router.handle_func("/dynamic/schema", ctrl_ptr, DynamicController.schema);

        // 扩展操作
        try self.router.handle_func("/dynamic/query", ctrl_ptr, DynamicController.query);
        try self.router.handle_func("/dynamic/count", ctrl_ptr, DynamicController.count);
        try self.router.handle_func("/dynamic/exists", ctrl_ptr, DynamicController.exists);
        try self.router.handle_func("/dynamic/tables", ctrl_ptr, DynamicController.tables);
        try self.router.handle_func("/dynamic/batch_save", ctrl_ptr, DynamicController.batchSave);
        try self.router.handle_func("/dynamic/batch_update", ctrl_ptr, DynamicController.batchUpdate);
    }

    /// 启动 HTTP 服务器
    pub fn listen(self: *Self) !void {
        const service_mgr = root.getServiceManager() orelse @panic("ServiceManager not initialized");
        const config = service_mgr.getConfig();
        const api_config = config.api;

        var listener = zap.HttpListener.init(.{
            .port = api_config.port,
            .on_request = self.router.on_request_handler(),
            .log = true,
            .public_folder = api_config.public_folder,
            .max_clients = api_config.max_clients,
            .timeout = @intCast(api_config.timeout),
        });
        try listener.listen();
        logger.info("🚀 服务器启动于 http://{s}:{d}", .{ api_config.host, api_config.port });
        zap.start(.{ .threads = 4, .workers = 4 });
    }

    fn notFoundHandler(req: zap.Request) !void {
        req.setStatus(.not_found);
        // 需要导入基础响应函数
        // base.send_failed(req, "404 Not Found");
    }
};
