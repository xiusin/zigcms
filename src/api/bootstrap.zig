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
const zap = @import("zap");

const DIContainer = @import("../core/di/container.zig").DIContainer;
const AppContext = @import("../core/context/app_context.zig").AppContext;

/// MCP 控制器包装器（全局定义以便类型安全释放）
const McpControllerWrapper = struct {
    server: *@import("../mcp/mod.zig").McpServer,

    pub fn handleSse(ctrl: *@This(), req: zap.Request) !void {
        var mutable_req = req;
        try ctrl.server.sse_transport.handleSse(&mutable_req);
    }

    pub fn handleMessage(ctrl: *@This(), req: zap.Request) !void {
        var mutable_req = req;
        try ctrl.server.sse_transport.handleMessage(&mutable_req);
    }
};

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
    mcp_controller: ?*McpControllerWrapper = null, // 跟踪 MCP 控制器

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
            .mcp_controller = null,
        };
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        // 清理 MCP Server（如果已注册）
        const mcp = @import("../mcp/mod.zig");
        if (self.container.isRegistered(mcp.McpServer)) {
            if (self.container.resolve(mcp.McpServer)) |mcp_server| {
                mcp_server.deinit();
            } else |_| {}
        }

        // 清理 MCP 控制器
        if (self.mcp_controller) |ctrl| {
            self.allocator.destroy(ctrl);
            self.mcp_controller = null;
        }
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
        self.crud_count += 2; // 原来是 3，现在是 2

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

        // 自动化测试路由
        try self.registerAutoTestRoutes();

        // 质量中心路由
        try self.registerQualityCenterRoutes();

        // MCP 路由（AI 辅助开发）
        try self.registerMcpRoutes();
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

        // 注册 OAuth 控制器
        if (!self.container.isRegistered(controllers.auth.OAuth)) {
            try self.container.registerSingleton(controllers.auth.OAuth, controllers.auth.OAuth, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.auth.OAuth {
                    _ = di;
                    const ctrl = try allocator.create(controllers.auth.OAuth);
                    ctrl.* = controllers.auth.OAuth.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        const oauth = try self.container.resolve(controllers.auth.OAuth);
        try self.app.route("/api/oauth/authorize", oauth, &controllers.auth.OAuth.authorize);
        try self.app.route("/api/oauth/callback", oauth, &controllers.auth.OAuth.callback);
        try self.app.route("/api/oauth/refresh", oauth, &controllers.auth.OAuth.refresh);
        try self.app.route("/api/oauth/bind", oauth, &controllers.auth.OAuth.bind);
        try self.app.route("/api/oauth/bind/list", oauth, &controllers.auth.OAuth.bindList);
        try self.app.route("/api/oauth/unbind", oauth, &controllers.auth.OAuth.unbind);

        self.route_count += 14;
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

        if (!self.container.isRegistered(controllers.system_ext.Dict)) {
            try self.container.registerSingleton(controllers.system_ext.Dict, controllers.system_ext.Dict, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*controllers.system_ext.Dict {
                    _ = di;
                    const ctrl = try allocator.create(controllers.system_ext.Dict);
                    ctrl.* = controllers.system_ext.Dict.init(allocator);
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
        const dict = try self.container.resolve(controllers.system_ext.Dict);
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

        try registerWithAlias(self.app, "/system/dict/list", dict, &controllers.system_ext.Dict.list);
        try registerWithAlias(self.app, "/system/dict/save", dict, &controllers.system_ext.Dict.save);
        try registerWithAlias(self.app, "/system/dict/delete", dict, &controllers.system_ext.Dict.delete);
        try registerWithAlias(self.app, "/system/dict/set", dict, &controllers.system_ext.Dict.set);
        try registerWithAlias(self.app, "/system/dict/items", dict, &controllers.system_ext.Dict.items);
        try registerWithAlias(self.app, "/system/dict/item/save", dict, &controllers.system_ext.Dict.itemSave);
        try registerWithAlias(self.app, "/system/dict/item/delete", dict, &controllers.system_ext.Dict.itemDelete);
        try registerWithAlias(self.app, "/system/dict/item/set", dict, &controllers.system_ext.Dict.itemSet);

        try registerWithAlias(self.app, "/system/dict/items", dict_item, &controllers.system_ext.DictItem.items);
        try registerWithAlias(self.app, "/system/dict/item/save", dict_item, &controllers.system_ext.DictItem.save);
        try registerWithAlias(self.app, "/system/dict/item/delete", dict_item, &controllers.system_ext.DictItem.delete);
        try registerWithAlias(self.app, "/system/dict/item/set", dict_item, &controllers.system_ext.DictItem.set);

        try registerWithAlias(self.app, "/system/role/save", role, &controllers.system_ext.Role.save);
        try registerWithAlias(self.app, "/system/role/list", role, &controllers.system_ext.Role.list);
        try registerWithAlias(self.app, "/system/role/permissions/get", role, &controllers.system_ext.Role.role_permissions_get);
        try registerWithAlias(self.app, "/system/role/permissions/info", role, &controllers.system_ext.Role.role_permissions_info);
        try registerWithAlias(self.app, "/system/role/delete", role, &controllers.system_ext.Role.delete);

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

    /// 注册自动化测试路由（需要 JWT 认证）
    fn registerAutoTestRoutes(self: *Self) !void {
        const AutoTest = controllers.auto_test.AutoTest;
        const wrapper = @import("middleware/wrapper.zig");
        const Auth = wrapper.Controller(AutoTest);

        if (!self.container.isRegistered(AutoTest)) {
            try self.container.registerSingleton(AutoTest, AutoTest, struct {
                fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*AutoTest {
                    _ = di;
                    const ctrl = try allocator.create(AutoTest);
                    ctrl.* = AutoTest.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        const ctrl = try self.container.resolve(AutoTest);

        const registerWithAlias = struct {
            fn exec(app: *App, comptime path: []const u8, c: anytype, handler: anytype) !void {
                app.route("/api" ++ path, c, handler) catch |err| switch (err) {
                    else => {
                        if (!std.mem.eql(u8, @errorName(err), "AlreadyExists")) return err;
                    },
                };
            }
        }.exec;

        // 所有 auto-test 路由均挂载 JWT 认证中间件
        try registerWithAlias(self.app, "/auto-test/report/create", ctrl, Auth.requireAuth(&AutoTest.report_create));
        try registerWithAlias(self.app, "/auto-test/report/list", ctrl, Auth.requireAuth(&AutoTest.report_list));
        try registerWithAlias(self.app, "/auto-test/report/detail", ctrl, Auth.requireAuth(&AutoTest.report_detail));
        try registerWithAlias(self.app, "/auto-test/bug/create", ctrl, Auth.requireAuth(&AutoTest.bug_create));
        try registerWithAlias(self.app, "/auto-test/bug/list", ctrl, Auth.requireAuth(&AutoTest.bug_list));
        try registerWithAlias(self.app, "/auto-test/bug/update-status", ctrl, Auth.requireAuth(&AutoTest.bug_update_status));
        try registerWithAlias(self.app, "/auto-test/statistics", ctrl, Auth.requireAuth(&AutoTest.statistics));

        self.route_count += 7;
    }

    /// 注册质量中心路由
    fn registerQualityCenterRoutes(self: *Self) !void {
        const QC = controllers.quality_center.QualityCenter;
        const wrapper = @import("middleware/wrapper.zig");
        const Auth = wrapper.Controller(QC);

        if (!self.container.isRegistered(QC)) {
            try self.container.registerSingleton(QC, QC, struct {
                fn factory(_: *DIContainer, allocator: std.mem.Allocator) anyerror!*QC {
                    const ctrl = try allocator.create(QC);
                    ctrl.* = QC.init(allocator);
                    return ctrl;
                }
            }.factory, null);
        }

        const ctrl = try self.container.resolve(QC);

        const registerWithAlias = struct {
            fn exec(app: *App, comptime path: []const u8, c: anytype, handler: anytype) !void {
                app.route("/api" ++ path, c, handler) catch |err| switch (err) {
                    else => {
                        if (!std.mem.eql(u8, @errorName(err), "AlreadyExists")) return err;
                    },
                };
            }
        }.exec;

        // Dashboard 统计
        try registerWithAlias(self.app, "/quality-center/overview", ctrl, Auth.requireAuth(&QC.overview));
        try registerWithAlias(self.app, "/quality-center/trend", ctrl, Auth.requireAuth(&QC.trend));
        try registerWithAlias(self.app, "/quality-center/module-quality", ctrl, Auth.requireAuth(&QC.module_quality));
        try registerWithAlias(self.app, "/quality-center/bug-distribution", ctrl, Auth.requireAuth(&QC.bug_distribution));
        try registerWithAlias(self.app, "/quality-center/feedback-distribution", ctrl, Auth.requireAuth(&QC.feedback_distribution));

        // 反馈与测试联动
        try registerWithAlias(self.app, "/quality-center/feedback-to-task", ctrl, Auth.requireAuth(&QC.feedback_to_task));
        try registerWithAlias(self.app, "/quality-center/bug-to-feedback", ctrl, Auth.requireAuth(&QC.bug_to_feedback));
        try registerWithAlias(self.app, "/quality-center/link-records", ctrl, Auth.requireAuth(&QC.link_records));

        // 活动流 + AI 洞察
        try registerWithAlias(self.app, "/quality-center/activities", ctrl, Auth.requireAuth(&QC.activities));
        try registerWithAlias(self.app, "/quality-center/ai-insights", ctrl, Auth.requireAuth(&QC.ai_insights));

        // 定时报表 CRUD
        try registerWithAlias(self.app, "/quality-center/scheduled-reports", ctrl, Auth.requireAuth(&QC.scheduled_report_list));
        try registerWithAlias(self.app, "/quality-center/scheduled-reports/create", ctrl, Auth.requireAuth(&QC.scheduled_report_create));
        try registerWithAlias(self.app, "/quality-center/scheduled-reports/update", ctrl, Auth.requireAuth(&QC.scheduled_report_update));
        try registerWithAlias(self.app, "/quality-center/scheduled-reports/delete", ctrl, Auth.requireAuth(&QC.scheduled_report_delete));
        try registerWithAlias(self.app, "/quality-center/scheduled-reports/toggle", ctrl, Auth.requireAuth(&QC.scheduled_report_toggle));
        try registerWithAlias(self.app, "/quality-center/scheduled-reports/trigger", ctrl, Auth.requireAuth(&QC.scheduled_report_trigger));

        // 报表历史
        try registerWithAlias(self.app, "/quality-center/report-history", ctrl, Auth.requireAuth(&QC.report_history));

        // Bug 关联 + 反馈分类
        try registerWithAlias(self.app, "/quality-center/bug-links", ctrl, Auth.requireAuth(&QC.bug_links));
        try registerWithAlias(self.app, "/quality-center/feedback-classification", ctrl, Auth.requireAuth(&QC.feedback_classification));

        // 报表模板 CRUD
        try registerWithAlias(self.app, "/quality-center/report-templates", ctrl, Auth.requireAuth(&QC.report_template_list));
        try registerWithAlias(self.app, "/quality-center/report-templates/create", ctrl, Auth.requireAuth(&QC.report_template_create));
        try registerWithAlias(self.app, "/quality-center/report-templates/update", ctrl, Auth.requireAuth(&QC.report_template_update));
        try registerWithAlias(self.app, "/quality-center/report-templates/delete", ctrl, Auth.requireAuth(&QC.report_template_delete));

        // 邮件模板 CRUD
        try registerWithAlias(self.app, "/quality-center/email-templates", ctrl, Auth.requireAuth(&QC.email_template_list));
        try registerWithAlias(self.app, "/quality-center/email-templates/create", ctrl, Auth.requireAuth(&QC.email_template_create));
        try registerWithAlias(self.app, "/quality-center/email-templates/update", ctrl, Auth.requireAuth(&QC.email_template_update));
        try registerWithAlias(self.app, "/quality-center/email-templates/delete", ctrl, Auth.requireAuth(&QC.email_template_delete));
        try registerWithAlias(self.app, "/quality-center/email-templates/preview", ctrl, Auth.requireAuth(&QC.email_template_preview));

        // AI 分析
        try registerWithAlias(self.app, "/quality-center/ai-analysis", ctrl, Auth.requireAuth(&QC.ai_analysis));
        try registerWithAlias(self.app, "/quality-center/ai-analysis/history", ctrl, Auth.requireAuth(&QC.ai_analysis_history));

        self.route_count += 30;
    }

    /// 注册 MCP 路由（AI 辅助开发）
    fn registerMcpRoutes(self: *Self) !void {
        const mcp = @import("../mcp/mod.zig");

        // 从配置中获取 MCP 配置
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const config = service_mgr.getConfig();

        // 检查 MCP 是否启用
        if (!config.mcp.enabled) {
            logger.info("ℹ️  MCP 服务未启用", .{});
            return;
        }

        // 初始化 MCP Server
        const mcp_server = try mcp.McpServer.init(self.allocator, config.mcp);
        errdefer mcp_server.deinit();

        // 注册到 DI 容器
        if (!self.container.isRegistered(mcp.McpServer)) {
            try self.container.registerInstance(mcp.McpServer, mcp_server, null);
        }

        // 创建 MCP 控制器包装器
        const mcp_ctrl = try self.allocator.create(McpControllerWrapper);
        mcp_ctrl.* = .{ .server = mcp_server };

        // 保存控制器指针以便后续清理
        self.mcp_controller = mcp_ctrl;

        // 注册 SSE 端点（用于建立连接）- 使用 handle_func
        try self.app.route(config.mcp.transport.sse_path, mcp_ctrl, &McpControllerWrapper.handleSse);
        logger.info("✅ SSE 端点已注册: {s}", .{config.mcp.transport.sse_path});

        // 注册消息端点（用于接收 JSON-RPC 消息）
        try self.app.route(config.mcp.transport.message_path, mcp_ctrl, &McpControllerWrapper.handleMessage);

        self.route_count += 2;

        // 注意：MCP 路由注册到主 HTTP 服务器，使用 API 端口而不是 MCP 配置的端口
        logger.info("✅ MCP 服务已启用: {s}:{d}{s}", .{
            config.api.host,
            config.api.port,
            config.mcp.transport.sse_path,
        });
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

        // MCP 服务配置
        logger.info("╠══════════════════════════════════════════════════════════════╣", .{});
        logger.info("║ 🤖 MCP 服务:                                                 ║", .{});
        if (config.mcp.enabled) {
            logger.info("║    状态: ✅ 已启用", .{});
            logger.info("║    SSE 端点: http://{s}:{d}{s}", .{
                config.api.host,
                config.api.port,
                config.mcp.transport.sse_path,
            });
            logger.info("║    消息端点: http://{s}:{d}{s}", .{
                config.api.host,
                config.api.port,
                config.mcp.transport.message_path,
            });
            logger.info("║    工具数量: 10 个", .{});
            logger.info("║      - 项目结构/搜索/读取", .{});
            logger.info("║      - CRUD/模型/迁移/测试生成", .{});
            logger.info("║      - 知识库问答/数据库/缓存操作", .{});
            logger.info("║    📖 文档: src/mcp/docs/INDEX.md", .{});
        } else {
            logger.info("║    状态: ⚠️  未启用", .{});
            logger.info("║    提示: 在 config/mcp.yaml 中设置 enabled: true", .{});
        }

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
