//! 更新后的应用框架 - 遵循整洁架构
//!
//! 职责：
//! - 作为 API 层的统一入口点
//! - 管理 HTTP 路由和请求处理
//! - 协调各层组件处理请求

const std = @import("std");
const zap = @import("zap");
const logger = @import("../application/services/logger/logger.zig");
const root = @import("../../root.zig");
const controllers = @import("controllers/mod.zig");

/// 应用框架
pub const App = struct {
    const Self = @This();

    const ControllerEntry = struct {
        ptr: *anyopaque,
        deinit_fn: *const fn (*anyopaque, std.mem.Allocator) void,
    };

    const RouteEntry = struct {
        path: []const u8,
        method: []const u8,
        controller_type: []const u8,
        handler_name: []const u8,
    };

    allocator: std.mem.Allocator,
    router: zap.Router,
    /// 存储已创建的控制器指针，用于清理
    controllers: std.ArrayListUnmanaged(ControllerEntry),
    /// 存储已注册的路由信息，用于打印
    routes: std.ArrayListUnmanaged(RouteEntry),
    /// MCP 控制器（特殊处理）
    mcp_handler: ?*const fn (zap.Request) void = null,
    mcp_path: ?[]const u8 = null,
    /// Endpoint Listener（支持所有 HTTP 方法）
    endpoint_listener: ?*zap.Endpoint.Listener = null,

    /// 初始化应用
    pub fn init(allocator: std.mem.Allocator) !Self {
        // 各层已在 zigcms.initSystem() 中初始化，这里只初始化路由
        return .{
            .allocator = allocator,
            .router = zap.Router.init(allocator, .{
                .not_found = notFoundHandler,
            }),
            .controllers = .{},
            .routes = .{},
            .mcp_handler = null,
            .mcp_path = null,
            .endpoint_listener = null,
        };
    }

    /// 销毁应用
    pub fn deinit(self: *Self) void {
        // 清理所有控制器
        for (self.controllers.items) |entry| {
            entry.deinit_fn(entry.ptr, self.allocator);
        }
        self.controllers.deinit(self.allocator);

        // 清理路由记录分配的字符串
        for (self.routes.items) |route_entry| {
            self.allocator.free(route_entry.path);
            self.allocator.free(route_entry.method);
            self.allocator.free(route_entry.controller_type);
            self.allocator.free(route_entry.handler_name);
        }
        self.routes.deinit(self.allocator);
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

        try self.router.handle_func("/" ++ name ++ "/list", ctrl_ptr, &Controller.list);
        try self.router.handle_func("/" ++ name ++ "/get", ctrl_ptr, &Controller.get);
        try self.router.handle_func("/" ++ name ++ "/save", ctrl_ptr, &Controller.save);
        try self.router.handle_func("/" ++ name ++ "/delete", ctrl_ptr, &Controller.delete);
        try self.router.handle_func("/" ++ name ++ "/modify", ctrl_ptr, &Controller.modify);
        try self.router.handle_func("/" ++ name ++ "/set", ctrl_ptr, &Controller.modify);
        try self.router.handle_func("/" ++ name ++ "/select", ctrl_ptr, &Controller.select);

        // 记录 CRUD 路由信息
        const crud_paths = [_][]const u8{ "/list", "/get", "/save", "/delete", "/modify", "/set", "/select" };
        const crud_handlers = [_][]const u8{ "list", "get", "save", "delete", "modify", "modify", "select" };
        for (crud_paths, crud_handlers) |path, handler_name| {
            var route_buf: [64]u8 = undefined;
            const route_path = std.fmt.bufPrint(&route_buf, "/{s}{s}", .{ name, path }) catch "route-too-long";
            try self.addRouteRecord(route_path, "POST", "CRUD(" ++ name ++ ")", handler_name);
        }
    }

    /// 注册路由 - 适配新的控制器路径
    pub fn route(self: *Self, path: []const u8, ctrl: anytype, handler: anytype) !void {
        try self.router.handle_func(path, ctrl, handler);

        // 记录独立路由信息
        const controller_type = @TypeOf(ctrl);
        const type_name = @typeName(controller_type);
        const module_name = if (std.mem.lastIndexOf(u8, type_name, ".")) |dot_idx|
            type_name[dot_idx + 1 ..]
        else
            type_name;

        const handler_type = @TypeOf(handler);
        const handler_name = @typeName(handler_type);
        const handler_fn_name = if (std.mem.lastIndexOf(u8, handler_name, ".")) |dot_idx|
            handler_name[dot_idx + 1 ..]
        else
            handler_name;

        try self.addRouteRecord(path, "POST", module_name, handler_fn_name);
    }

    /// 记录路由并托管字符串所有权，保证失败路径不会泄漏
    fn addRouteRecord(
        self: *Self,
        path: []const u8,
        method: []const u8,
        controller_type: []const u8,
        handler_name: []const u8,
    ) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);

        const owned_method = try self.allocator.dupe(u8, method);
        errdefer self.allocator.free(owned_method);

        const owned_controller = try self.allocator.dupe(u8, controller_type);
        errdefer self.allocator.free(owned_controller);

        const owned_handler = try self.allocator.dupe(u8, handler_name);
        errdefer self.allocator.free(owned_handler);

        try self.routes.append(self.allocator, .{
            .path = owned_path,
            .method = owned_method,
            .controller_type = owned_controller,
            .handler_name = owned_handler,
        });
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

    /// 初始化 Endpoint Listener（在注册路由之后调用）
    pub fn initListener(self: *Self) !void {
        const service_mgr = root.getServiceManager() orelse @panic("ServiceManager not initialized");
        const config = service_mgr.getConfig();
        const api_config = config.api;
        
        logger.info("🔧 初始化 Endpoint.Listener（支持所有 HTTP 方法）", .{});
        
        const listener_ptr = try self.allocator.create(zap.Endpoint.Listener);
        listener_ptr.* = zap.Endpoint.Listener.init(self.allocator, .{
            .port = api_config.port,
            .on_request = self.router.on_request_handler(),
            .log = true,
            .public_folder = api_config.public_folder,
            .max_clients = api_config.max_clients,
            .timeout = @intCast(api_config.timeout),
        });
        self.endpoint_listener = listener_ptr;
    }

    /// 注册 MCP Endpoint（支持所有 HTTP 方法）
    pub fn registerMcpEndpoint(self: *Self, endpoint: anytype) !void {
        if (self.endpoint_listener) |listener| {
            try listener.register(endpoint);
            logger.info("✅ MCP Endpoint 已注册", .{});
        } else {
            return error.ListenerNotInitialized;
        }
    }

    /// 启动 HTTP 服务器
    pub fn listen(self: *Self) !void {
        const service_mgr = root.getServiceManager() orelse @panic("ServiceManager not initialized");
        const config = service_mgr.getConfig();
        const api_config = config.api;
        
        const listener = self.endpoint_listener orelse return error.ListenerNotInitialized;
        
        logger.info("🚀 服务器启动于 http://{s}:{d}", .{ api_config.host, api_config.port });
        try listener.listen();
        // 重要：workers 必须为 1，避免多进程 fork 后共享 MySQL 连接导致崩溃
        // MySQL 连接不能跨进程共享，多线程模式是安全的
        zap.start(.{ .threads = 4, .workers = 1 });
    }

    /// 打印所有已注册的路由（调试/运维用）
    pub fn printRoutes(self: *const Self) void {
        logger.info("🛣️  已注册的路由列表:", .{});
        logger.info("┌─────────────────────────────────────────────────────────────────┐", .{});
        logger.info("│ 路由路径                     │ HTTP 方法 │ 控制器类型        │ 处理器    │", .{});
        logger.info("├─────────────────────────────────────────────────────────────────┤", .{});

        // 遍历所有已注册的路由
        for (self.routes.items) |route_entry| {
            logger.info("│ {s:<27} │ {s:<8} │ {s:<16} │ {s:<8} │", .{ route_entry.path, route_entry.method, route_entry.controller_type, route_entry.handler_name });
        }

        logger.info("└─────────────────────────────────────────────────────────────────┘", .{});
        logger.info("总计: {d} 条路由", .{self.routes.items.len});
    }

    fn notFoundHandler(req: zap.Request) !void {
        req.setStatus(.not_found);
        // 需要导入基础响应函数
        // base.send_failed(req, "404 Not Found");
    }
};
