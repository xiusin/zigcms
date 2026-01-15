//! Bootstrap 模块 - 系统启动编排
//!
//! 职责：
//! - 按正确顺序初始化各层
//! - 注册路由
//! - 配置服务
//! - 提供启动摘要信息

const std = @import("std");
const zigcms = @import("../root.zig");
const logger = @import("../application/services/logger/logger.zig");
const App = @import("App.zig").App;
const controllers = @import("controllers/mod.zig");
const models = @import("../domain/entities/models.zig");

const DIContainer = @import("../shared/di/container.zig").DIContainer;

/// Bootstrap 模块 - 系统启动编排器
pub const Bootstrap = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    app: *App,
    global_logger: *logger.Logger,
    container: *DIContainer,
    route_count: usize,
    crud_count: usize,

    /// 初始化 Bootstrap 模块
    pub fn init(allocator: std.mem.Allocator, app: *App, global_logger: *logger.Logger, container: *DIContainer) !Self {
        // 注册日志服务实例
        if (!container.isRegistered(logger.Logger)) {
            try container.registerInstance(logger.Logger, global_logger, null);
        }

        return .{
            .allocator = allocator,
            .app = app,
            .global_logger = global_logger,
            .container = container,
            .route_count = 0,
            .crud_count = 0,
        };
    }

    /// 注册所有路由
    /// 包括 CRUD 模块和自定义控制器路由
    pub fn registerRoutes(self: *Self) !void {
        // 注册 CRUD 模块
        try self.registerCrudModules();

        // 注册自定义控制器路由
        try self.registerCustomRoutes();
    }

    /// 注册 CRUD 模块
    /// 自动生成 list/get/save/delete/modify/select 路由
    fn registerCrudModules(self: *Self) !void {
        // 基础模块
        try self.app.crud("category", models.Category);
        try self.app.crud("upload", models.Upload);
        try self.app.crud("article", models.Article);
        try self.app.crud("role", models.Role);
        try self.app.crud("dict", models.Dict);
        self.crud_count += 5;

        // CMS 内容管理模块
        try self.app.crud("cms_model", models.CmsModel);
        try self.app.crud("cms_field", models.CmsField);
        try self.app.crud("document", models.Document);
        try self.app.crud("material_category", models.MaterialCategory);
        try self.app.crud("material", models.Material);
        self.crud_count += 5;

        // 会员管理模块
        try self.app.crud("member_group", models.MemberGroup);
        try self.app.crud("member", models.Member);
        self.crud_count += 2;

        // 友链管理模块
        try self.app.crud("friend_link", models.FriendLink);
        self.crud_count += 1;

        // 每个 CRUD 模块生成 6 个路由
        self.route_count += self.crud_count * 6;
    }

    /// 注册自定义控制器路由
    fn registerCustomRoutes(self: *Self) !void {
        // 登录控制器
        try self.registerAuthRoutes();

        // 公共接口
        try self.registerPublicRoutes();

        // 管理后台路由
        try self.registerAdminRoutes();

        // 实时通信路由
        try self.registerRealtimeRoutes();
    }

    /// 注册认证相关路由
    fn registerAuthRoutes(self: *Self) !void {
        // 注册 Login 控制器
        if (!self.container.isRegistered(controllers.auth.Login)) {
            try self.container.registerSingleton(controllers.auth.Login, controllers.auth.Login, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.auth.Login {
                    const l = try di.resolve(logger.Logger);
                    // 从容器中解析 AuthService
                    const auth_service = try di.resolve(@import("../application/services/auth_service.zig").AuthService);
                    
                    const ctrl = try allocator.create(controllers.auth.Login);
                    ctrl.* = controllers.auth.Login.init(allocator, l, auth_service);
                    return ctrl;
                }
            }.factory, null);
        }

        const login = try self.container.resolve(controllers.auth.Login);
        try self.app.route("/login", login, &controllers.auth.Login.login);
        try self.app.route("/register", login, &controllers.auth.Login.register);
        self.route_count += 2;
    }

    /// 注册公共接口路由
    fn registerPublicRoutes(self: *Self) !void {
        // 注册 Public 控制器
        if (!self.container.isRegistered(controllers.common.Public)) {
            try self.container.registerSingleton(controllers.common.Public, controllers.common.Public, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.common.Public {
                    const l = try di.resolve(logger.Logger);
                    const ctrl = try allocator.create(controllers.common.Public);
                    ctrl.* = controllers.common.Public.init(allocator, l);
                    return ctrl;
                }
            }.factory, null);
        }

        const public = try self.container.resolve(controllers.common.Public);
        try self.app.route("/public/upload", public, &controllers.common.Public.upload);
        try self.app.route("/public/folder", public, &controllers.common.Public.folder);
        try self.app.route("/public/files", public, &controllers.common.Public.files);
        self.route_count += 3;
    }

    /// 注册管理后台路由
    fn registerAdminRoutes(self: *Self) !void {
        // 注册 Menu 控制器
        if (!self.container.isRegistered(controllers.admin.Menu)) {
            try self.container.registerSingleton(controllers.admin.Menu, controllers.admin.Menu, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.admin.Menu {
                    const l = try di.resolve(logger.Logger);
                    const ctrl = try allocator.create(controllers.admin.Menu);
                    ctrl.* = controllers.admin.Menu.init(allocator, l);
                    return ctrl;
                }
            }.factory, null);
        }
        
        const menu = try self.container.resolve(controllers.admin.Menu);
        try self.app.route("/menu/list", menu, &controllers.admin.Menu.list);
        self.route_count += 1;

        // 注册 Setting 控制器
        if (!self.container.isRegistered(controllers.admin.Setting)) {
            try self.container.registerSingleton(controllers.admin.Setting, controllers.admin.Setting, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.admin.Setting {
                    _ = di; // Setting 控制器不需要其他依赖
                    const ctrl = try allocator.create(controllers.admin.Setting);
                    ctrl.* = controllers.admin.Setting.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        const setting = try self.container.resolve(controllers.admin.Setting);
        try self.app.route("/setting/get", setting, &controllers.admin.Setting.get);
        try self.app.route("/setting/save", setting, &controllers.admin.Setting.save);
        try self.app.route("/setting/send_email", setting, &controllers.admin.Setting.send_mail);
        try self.app.route("/setting/upload_config/get", setting, &controllers.admin.Setting.get_upload_config);
        try self.app.route("/setting/upload_config/save", setting, &controllers.admin.Setting.save_upload_config);
        try self.app.route("/setting/upload_config/test", setting, &controllers.admin.Setting.test_upload_config);
        self.route_count += 6;

        // 注意：角色管理路由已在 registerCrudModules 中通过 crud("role", models.Role) 注册
        // 如果需要自定义角色控制器，请使用不同的路径前缀，如 /admin/role/*
    }

    /// 注册实时通信路由
    fn registerRealtimeRoutes(self: *Self) !void {
        _ = self; // TODO: 实时通信功能需要 zap 支持，暂时注释
        // WebSocket 控制器
        // TODO: WebSocket 功能需要 zap 支持，暂时注释
        // const WSController = controllers.realtime.WebSocket;
        // const ws_ctrl_ptr = try self.allocator.create(WSController);

        // var owned_ws = false;
        // errdefer if (!owned_ws) self.allocator.destroy(ws_ctrl_ptr);

        // ws_ctrl_ptr.* = WSController.init(self.allocator);

        // // 追踪控制器指针以便后续清理
        // const wsDestroyFn = struct {
        //     fn destroy(ptr: *anyopaque, alloc: std.mem.Allocator) void {
        //         const typed_ptr: *WSController = @ptrCast(@alignCast(ptr));
        //         typed_ptr.deinit();
        //         alloc.destroy(typed_ptr);
        //     }
        // }.destroy;

        // try self.app.controllers.append(self.allocator, .{
        //     .ptr = @ptrCast(ws_ctrl_ptr),
        //     .deinit_fn = wsDestroyFn,
        // });
        // owned_ws = true;

        // try self.app.route("/ws", ws_ctrl_ptr, &WSController.upgrade);
        // self.route_count += 1;

        // SSE 控制器
        // TODO: SSE 功能需要 zap 支持，暂时注释
        // const SSEController = controllers.realtime.SSE;
        // const sse_ctrl_ptr = try self.allocator.create(SSEController);

        // var owned_sse = false;
        // errdefer if (!owned_sse) self.allocator.destroy(sse_ctrl_ptr);

        // sse_ctrl_ptr.* = SSEController.init(self.allocator);

        // // 追踪控制器指针以便后续清理
        // const sseDestroyFn = struct {
        //     fn destroy(ptr: *anyopaque, alloc: std.mem.Allocator) void {
        //         const typed_ptr: *SSEController = @ptrCast(@alignCast(ptr));
        //         typed_ptr.deinit();
        //         alloc.destroy(typed_ptr);
        //     }
        // }.destroy;

        // try self.app.controllers.append(self.allocator, .{
        //     .ptr = @ptrCast(sse_ctrl_ptr),
        //     .deinit_fn = sseDestroyFn,
        // });
        // owned_sse = true;

        // try self.app.route("/sse", sse_ctrl_ptr, &SSEController.connect);
        // self.route_count += 1;
    }

    /// 获取路由统计信息
    pub fn getRouteStats(self: *const Self) RouteStats {
        return .{
            .total_routes = self.route_count,
            .crud_modules = self.crud_count,
            .crud_routes = self.crud_count * 6,
            .custom_routes = self.route_count - (self.crud_count * 6),
        };
    }

    /// 打印启动摘要
    /// 显示服务器配置信息和路由统计
    pub fn printStartupSummary(self: *const Self) void {
        const stats = self.getRouteStats();
        const service_mgr = zigcms.getServiceManager() orelse return;
        const config = service_mgr.getConfig();

        // 打印分隔线和标题
        logger.info("", .{});
        logger.info("╔══════════════════════════════════════════════════════════════╗", .{});
        logger.info("║                    ZigCMS 启动摘要                           ║", .{});
        logger.info("╠══════════════════════════════════════════════════════════════╣", .{});

        // 服务器配置
        logger.info("║ 📡 服务器配置:                                               ║", .{});
        logger.info("║    地址: http://{s}:{d}", .{ config.api.host, config.api.port });
        logger.info("║    最大连接数: {d}", .{config.api.max_clients});
        logger.info("║    超时时间: {d}s", .{config.api.timeout});
        logger.info("║    静态资源目录: {s}", .{config.api.public_folder});

        // 应用配置
        logger.info("╠══════════════════════════════════════════════════════════════╣", .{});
        logger.info("║ ⚙️  应用配置:                                                 ║", .{});
        logger.info("║    缓存: {s}", .{if (config.app.enable_cache) "已启用" else "已禁用"});
        logger.info("║    缓存 TTL: {d}s", .{config.app.cache_ttl_seconds});
        logger.info("║    插件系统: {s}", .{if (config.app.enable_plugins) "已启用" else "已禁用"});
        logger.info("║    最大并发任务: {d}", .{config.app.max_concurrent_tasks});

        // 路由统计
        logger.info("╠══════════════════════════════════════════════════════════════╣", .{});
        logger.info("║ 🛣️  路由统计:                                                 ║", .{});
        logger.info("║    CRUD 模块: {d} 个 (每个模块 6 条路由)", .{stats.crud_modules});
        logger.info("║    CRUD 路由: {d} 条", .{stats.crud_routes});
        logger.info("║    自定义路由: {d} 条", .{stats.custom_routes});
        logger.info("║    总路由数: {d} 条", .{stats.total_routes});

        // 结束
        logger.info("╚══════════════════════════════════════════════════════════════╝", .{});
        logger.info("", .{});
    }
};

/// 路由统计信息
pub const RouteStats = struct {
    total_routes: usize,
    crud_modules: usize,
    crud_routes: usize,
    custom_routes: usize,
};
