//! Bootstrap 模块 - 系统启动编排
//!
//! 职责：
//! - 按正确顺序初始化各层
//! - 注册路由
//! - 配置服务
//! - 提供启动摘要信息

const std = @import("std");
const zigcms = @import("../../root.zig");
const logger = @import("../application/services/logger/logger.zig");
const App = @import("App.zig").App;
const controllers = @import("controllers/mod.zig");
const models = @import("../domain/entities/mod.zig");

const DIContainer = @import("../core/di/container.zig").DIContainer;
const AppContext = @import("../core/context/app_context.zig").AppContext;

/// Bootstrap 模块 - 系统启动编排器
pub const Bootstrap = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    app: *App,
    global_logger: *logger.Logger,
    container: *DIContainer,
    app_context: *AppContext,
    route_count: usize,
    crud_count: usize,

    /// 初始化 Bootstrap 模块
    pub fn init(allocator: std.mem.Allocator, app: *App, global_logger: *logger.Logger, container: *DIContainer, app_context: *AppContext) !Self {
        // 注册日志服务实例
        if (!container.isRegistered(logger.Logger)) {
            try container.registerInstance(logger.Logger, global_logger, null);
        }

        return .{
            .allocator = allocator,
            .app = app,
            .global_logger = global_logger,
            .container = container,
            .app_context = app_context,
            .route_count = 0,
            .crud_count = 0,
        };
    }

    /// 获取应用上下文
    pub fn getContext(self: *const Self) *AppContext {
        return self.app_context;
    }

    /// 注册所有路由
    /// 包括 CRUD 模块和自定义控制器路由
    pub fn registerRoutes(self: *Self) !void {
        // 注册 CRUD 模块
        try self.registerCrudModules();

        // 注册自定义控制器路由
        try self.registerCustomRoutes();

        // 打印所有已注册的路由
        self.app.printRoutes();
    }

    /// 注册 CRUD 模块
    /// 自动生成 list/get/save/delete/modify/select 路由
    fn registerCrudModules(self: *Self) !void {
        // =====================================================
        // ecom-admin-dashboard 对接模块 (sys/biz/op 新表)
        // =====================================================

        // Phase 1: 组织/管理员/职位/角色
        try self.app.crud("system/dept", models.SysDept);
        try self.app.crud("system/admin", models.SysAdmin);
        try self.app.crud("system/position", models.SysPosition);
        try self.app.crud("system/role", models.SysRole);
        self.crud_count += 4;

        // Phase 2: 菜单/字典
        try self.app.crud("system/menu", models.SysMenu);
        try self.app.crud("system/dict", models.SysDict);
        try self.app.crud("system/dict_item", models.SysDictItem);
        self.crud_count += 3;

        // Phase 3: 配置/会员
        try self.app.crud("system/config", models.SysConfig);
        try self.app.crud("business/member", models.BizMember);
        self.crud_count += 2;

        // Phase 4: 任务
        try self.app.crud("operation/task", models.OpTask);
        self.crud_count += 1;

        // 每个 CRUD 模块生成 7 个路由 (list/get/save/delete/modify/set/select)
        self.route_count += self.crud_count * 7;
    }

    /// 注册自定义控制器路由
    fn registerCustomRoutes(self: *Self) !void {
        // 登录控制器
        try self.registerAuthRoutes();

        // 公共接口
        try self.registerPublicRoutes();

        // 管理后台路由
        try self.registerAdminRoutes();

        // 系统扩展路由（独立控制器）
        try self.registerSystemExtRoutes();

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
                    const auth_service = try di.resolve(@import("./services/auth_service.zig").AuthService);

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

    /// 注册系统扩展路由
    fn registerSystemExtRoutes(self: *Self) !void {
        if (!self.container.isRegistered(controllers.system_ext.Dept)) {
            try self.container.registerSingleton(controllers.system_ext.Dept, controllers.system_ext.Dept, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Dept {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Dept);
                    ctrl.* = controllers.system_ext.Dept.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Admin)) {
            try self.container.registerSingleton(controllers.system_ext.Admin, controllers.system_ext.Admin, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Admin {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Admin);
                    ctrl.* = controllers.system_ext.Admin.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Menu)) {
            try self.container.registerSingleton(controllers.system_ext.Menu, controllers.system_ext.Menu, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Menu {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Menu);
                    ctrl.* = controllers.system_ext.Menu.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.DictItem)) {
            try self.container.registerSingleton(controllers.system_ext.DictItem, controllers.system_ext.DictItem, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.DictItem {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.DictItem);
                    ctrl.* = controllers.system_ext.DictItem.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Role)) {
            try self.container.registerSingleton(controllers.system_ext.Role, controllers.system_ext.Role, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Role {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Role);
                    ctrl.* = controllers.system_ext.Role.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Payment)) {
            try self.container.registerSingleton(controllers.system_ext.Payment, controllers.system_ext.Payment, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Payment {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Payment);
                    ctrl.* = controllers.system_ext.Payment.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Version)) {
            try self.container.registerSingleton(controllers.system_ext.Version, controllers.system_ext.Version, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Version {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Version);
                    ctrl.* = controllers.system_ext.Version.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Log)) {
            try self.container.registerSingleton(controllers.system_ext.Log, controllers.system_ext.Log, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Log {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Log);
                    ctrl.* = controllers.system_ext.Log.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        const dept = try self.container.resolve(controllers.system_ext.Dept);
        const admin = try self.container.resolve(controllers.system_ext.Admin);
        const menu = try self.container.resolve(controllers.system_ext.Menu);
        const dict_item = try self.container.resolve(controllers.system_ext.DictItem);
        const role = try self.container.resolve(controllers.system_ext.Role);
        const payment = try self.container.resolve(controllers.system_ext.Payment);
        const version = try self.container.resolve(controllers.system_ext.Version);
        const log_ctrl = try self.container.resolve(controllers.system_ext.Log);

        try self.app.route("/system/dept/tree", dept, &controllers.system_ext.Dept.dept_tree);
        try self.app.route("/system/dept/all", dept, &controllers.system_ext.Dept.dept_all);

        try self.app.route("/system/admin/resetPassword", admin, &controllers.system_ext.Admin.reset_password);
        try self.app.route("/system/admin/assignRoles", admin, &controllers.system_ext.Admin.assign_roles);
        try self.app.route("/resetPassword", admin, &controllers.system_ext.Admin.reset_password);
        try self.app.route("/userInfo", admin, &controllers.system_ext.Admin.user_info);

        try self.app.route("/system/menu/tree", menu, &controllers.system_ext.Menu.tree);
        try self.app.route("/system/menu/permissions", menu, &controllers.system_ext.Menu.permissions);
        try self.app.route("/system/menu/save-permissions", menu, &controllers.system_ext.Menu.save_permissions);
        try self.app.route("/system/menu/export", menu, &controllers.system_ext.Menu.menu_export);

        try self.app.route("/system/dict/items", dict_item, &controllers.system_ext.DictItem.items);
        try self.app.route("/system/dict/item/save", dict_item, &controllers.system_ext.DictItem.save);
        try self.app.route("/system/dict/item/delete", dict_item, &controllers.system_ext.DictItem.delete);
        try self.app.route("/system/dict/item/set", dict_item, &controllers.system_ext.DictItem.set);

        try self.app.route("/role/button-perms", role, &controllers.system_ext.Role.button_perms);

        try self.app.route("/system/payment/list", payment, &controllers.system_ext.Payment.list);
        try self.app.route("/system/payment/save", payment, &controllers.system_ext.Payment.save);
        try self.app.route("/system/payment/delete", payment, &controllers.system_ext.Payment.delete);
        try self.app.route("/system/payment/set", payment, &controllers.system_ext.Payment.set);
        try self.app.route("/system/payment/test", payment, &controllers.system_ext.Payment.test_conn);

        try self.app.route("/system/version/list", version, &controllers.system_ext.Version.list);
        try self.app.route("/system/version/save", version, &controllers.system_ext.Version.save);
        try self.app.route("/system/version/delete", version, &controllers.system_ext.Version.delete);
        try self.app.route("/system/version/set", version, &controllers.system_ext.Version.set);

        try self.app.route("/log/list", log_ctrl, &controllers.system_ext.Log.list);
        try self.app.route("/log/statistics", log_ctrl, &controllers.system_ext.Log.statistics);
        try self.app.route("/log/clean", log_ctrl, &controllers.system_ext.Log.clean);
        try self.app.route("/log/archive", log_ctrl, &controllers.system_ext.Log.archive);
        try self.app.route("/log/export", log_ctrl, &controllers.system_ext.Log.export_logs);

        self.route_count += 29;
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
