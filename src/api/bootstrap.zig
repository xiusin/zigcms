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
        const registerCrudWithAlias = struct {
            fn exec(app: *App, comptime path: []const u8, comptime Model: type) !void {
                try app.crud(path, Model);
                try app.crud("api/" ++ path, Model);
            }
        }.exec;

        // =====================================================
        // ecom-admin-dashboard 对接模块 (sys/biz/op 新表)
        // =====================================================

        // Phase 1: 组织/职位/角色（管理员由 system_ext.Admin 接管完整接口）
        try registerCrudWithAlias(self.app, "system/dept", models.SysDept);
        try registerCrudWithAlias(self.app, "system/position", models.SysPosition);
        // 注意：sys_role 使用自定义控制器处理菜单权限关联，不使用通用 CRUD
        // try registerCrudWithAlias(self.app, "system/role", models.SysRole);
        self.crud_count += 2;  // 原来是 3，现在是 2

        // Phase 2: 菜单/字典
        try registerCrudWithAlias(self.app, "system/menu", models.SysMenu);
        try registerCrudWithAlias(self.app, "system/dict", models.SysDict);
        try registerCrudWithAlias(self.app, "system/dict_item", models.SysDictItem);
        try registerCrudWithAlias(self.app, "system/dict/category", models.SysDictCategory);
        self.crud_count += 3;

        // Phase 3: 配置/会员
        try registerCrudWithAlias(self.app, "system/config", models.SysConfig);
        try registerCrudWithAlias(self.app, "business/member", models.BizMember);
        self.crud_count += 2;

        // Phase 4: 任务
        try registerCrudWithAlias(self.app, "operation/task", models.OpTask);
        self.crud_count += 1;

        // 每个 CRUD 模块生成 14 个路由（原路径 7 条 + /api 前缀别名 7 条）
        self.route_count += self.crud_count * 14;
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
        try self.app.route("/member/login", login, &controllers.auth.Login.member_login);
        try self.app.route("/api/member/login", login, &controllers.auth.Login.member_login);
        try self.app.route("/member/refreshInfo", login, &controllers.auth.Login.member_refresh_info);
        try self.app.route("/api/member/refreshInfo", login, &controllers.auth.Login.member_refresh_info);
        try self.app.route("/member/refreshPermissions", login, &controllers.auth.Login.member_refresh_permissions);
        try self.app.route("/api/member/refreshPermissions", login, &controllers.auth.Login.member_refresh_permissions);
        self.route_count += 8;
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
        const registerWithAlias = struct {
            fn exec(app: *App, comptime path: []const u8, ctrl: anytype, handler: anytype) !void {
                app.route("/api" ++ path, ctrl, handler) catch |err| switch (err) {
                    else => {
                        if (!std.mem.eql(u8, @errorName(err), "AlreadyExists")) return err;
                    },
                };
            }
        }.exec;

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
                    const l = try di.resolve(logger.Logger);
                    const ctrl = try allocator.create(controllers.system_ext.Role);
                    ctrl.* = controllers.system_ext.Role.init(allocator, l);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Config)) {
            try self.container.registerSingleton(controllers.system_ext.Config, controllers.system_ext.Config, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Config {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Config);
                    ctrl.* = controllers.system_ext.Config.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Member)) {
            try self.container.registerSingleton(controllers.system_ext.Member, controllers.system_ext.Member, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Member {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Member);
                    ctrl.* = controllers.system_ext.Member.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        if (!self.container.isRegistered(controllers.system_ext.Task)) {
            try self.container.registerSingleton(controllers.system_ext.Task, controllers.system_ext.Task, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Task {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Task);
                    ctrl.* = controllers.system_ext.Task.init(allocator);
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
        const config_ctrl = try self.container.resolve(controllers.system_ext.Config);
        const member_ctrl = try self.container.resolve(controllers.system_ext.Member);
        const task_ctrl = try self.container.resolve(controllers.system_ext.Task);
        const payment = try self.container.resolve(controllers.system_ext.Payment);
        const log_ctrl = try self.container.resolve(controllers.system_ext.Log);

        try registerWithAlias(self.app, "/system/dept/tree", dept, &controllers.system_ext.Dept.dept_tree);
        try registerWithAlias(self.app, "/system/dept/all", dept, &controllers.system_ext.Dept.dept_all);
        try registerWithAlias(self.app, "/system/dept/remove", dept, &controllers.system_ext.Dept.dept_delete);

        try registerWithAlias(self.app, "/system/admin/list", admin, &controllers.system_ext.Admin.list_with_roles);
        try registerWithAlias(self.app, "/system/admin/get", admin, &controllers.system_ext.Admin.get);
        try registerWithAlias(self.app, "/system/admin/save", admin, &controllers.system_ext.Admin.save);
        try registerWithAlias(self.app, "/system/admin/set", admin, &controllers.system_ext.Admin.set);
        try registerWithAlias(self.app, "/system/admin/delete", admin, &controllers.system_ext.Admin.delete);
        try registerWithAlias(self.app, "/system/admin/select", admin, &controllers.system_ext.Admin.select);
        try registerWithAlias(self.app, "/system/admin/resetPassword", admin, &controllers.system_ext.Admin.reset_password);
        try registerWithAlias(self.app, "/system/admin/assignRoles", admin, &controllers.system_ext.Admin.assign_roles);
        try registerWithAlias(self.app, "/system/userInfo", admin, &controllers.system_ext.Admin.user_info);

        try registerWithAlias(self.app, "/system/menu/tree", menu, &controllers.system_ext.Menu.tree);
        try registerWithAlias(self.app, "/system/menu/export", menu, &controllers.system_ext.Menu.menu_export);

        try registerWithAlias(self.app, "/system/dict/items", dict_item, &controllers.system_ext.DictItem.items);
        try registerWithAlias(self.app, "/system/dict/item/save", dict_item, &controllers.system_ext.DictItem.save);
        try registerWithAlias(self.app, "/system/dict/item/delete", dict_item, &controllers.system_ext.DictItem.delete);
        try registerWithAlias(self.app, "/system/dict/item/set", dict_item, &controllers.system_ext.DictItem.set);

        try registerWithAlias(self.app, "/system/role/save", role, &controllers.system_ext.Role.save);
        try registerWithAlias(self.app, "/system/role/permissions/get", role, &controllers.system_ext.Role.role_permissions_get);
        try registerWithAlias(self.app, "/system/role/permissions/info", role, &controllers.system_ext.Role.role_permissions_info);
        try registerWithAlias(self.app, "/system/role/delete", role, &controllers.system_ext.Role.delete);

        // 角色列表使用通用 CRUD（只注册 list 相关路由）
        try self.app.crud("system/role", models.SysRole);
        try self.app.crud("api/system/role", models.SysRole);

        try registerWithAlias(self.app, "/system/config/refresh-cache", config_ctrl, &controllers.system_ext.Config.refresh_cache);
        try registerWithAlias(self.app, "/system/config/export", config_ctrl, &controllers.system_ext.Config.config_export);
        try registerWithAlias(self.app, "/system/config/import", config_ctrl, &controllers.system_ext.Config.config_import);
        try registerWithAlias(self.app, "/system/config/backup", config_ctrl, &controllers.system_ext.Config.config_backup);

        try registerWithAlias(self.app, "/business/member/export", member_ctrl, &controllers.system_ext.Member.member_export);
        try registerWithAlias(self.app, "/business/member/batchEnable", member_ctrl, &controllers.system_ext.Member.batch_enable);
        try registerWithAlias(self.app, "/business/member/batchDisable", member_ctrl, &controllers.system_ext.Member.batch_disable);
        try registerWithAlias(self.app, "/business/member/batchDelete", member_ctrl, &controllers.system_ext.Member.batch_delete);
        try registerWithAlias(self.app, "/business/member/tag/add", member_ctrl, &controllers.system_ext.Member.tag_add);
        try registerWithAlias(self.app, "/business/member/pointRecharge", member_ctrl, &controllers.system_ext.Member.point_recharge);
        try registerWithAlias(self.app, "/business/member/balanceRecharge", member_ctrl, &controllers.system_ext.Member.balance_recharge);

        try registerWithAlias(self.app, "/operation/task/run", task_ctrl, &controllers.system_ext.Task.run);
        try registerWithAlias(self.app, "/operation/task/logs", task_ctrl, &controllers.system_ext.Task.logs);
        try registerWithAlias(self.app, "/operation/task/schedule-logs", task_ctrl, &controllers.system_ext.Task.schedule_logs);

        try registerWithAlias(self.app, "/system/payment/list", payment, &controllers.system_ext.Payment.list);
        try registerWithAlias(self.app, "/system/payment/save", payment, &controllers.system_ext.Payment.save);
        try registerWithAlias(self.app, "/system/payment/delete", payment, &controllers.system_ext.Payment.delete);
        try registerWithAlias(self.app, "/system/payment/set", payment, &controllers.system_ext.Payment.set);
        try registerWithAlias(self.app, "/system/payment/test", payment, &controllers.system_ext.Payment.test_conn);

        try registerWithAlias(self.app, "/system/log/list", log_ctrl, &controllers.system_ext.Log.list);
        try registerWithAlias(self.app, "/system/log/statistics", log_ctrl, &controllers.system_ext.Log.statistics);
        try registerWithAlias(self.app, "/system/log/clean", log_ctrl, &controllers.system_ext.Log.clean);
        try registerWithAlias(self.app, "/system/log/archive", log_ctrl, &controllers.system_ext.Log.archive);
        try registerWithAlias(self.app, "/system/log/export", log_ctrl, &controllers.system_ext.Log.export_logs);

        self.route_count += 100;
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
