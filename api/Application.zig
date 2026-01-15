const std = @import("std");
const zigcms = @import("../root.zig");
const logger = @import("../application/services/logger/logger.zig");
const App = @import("App.zig").App;
const Bootstrap = @import("bootstrap.zig").Bootstrap;
const DIContainer = @import("../shared/di/container.zig").DIContainer;
const SystemConfig = @import("../shared/config/system_config.zig").SystemConfig;
const AppContext = @import("../shared/context/app_context.zig").AppContext;

pub const Application = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: SystemConfig,
    app: App,
    bootstrap: Bootstrap,
    global_logger: *logger.Logger,
    system_initialized: bool,
    app_context: ?*AppContext,

    pub fn create(allocator: std.mem.Allocator) !*Self {
        const app_ptr = try allocator.create(Self);
        errdefer allocator.destroy(app_ptr);

        const config = try zigcms.loadSystemConfig(allocator);

        try zigcms.initSystem(allocator, config);

        try logger.initDefault(allocator, .{ .level = .debug, .format = .colored });
        const global_logger = logger.getDefault() orelse return error.LoggerInitFailed;

        var app = try App.init(allocator);
        errdefer app.deinit();

        const container = zigcms.shared.di.getGlobalContainer() orelse return error.DIContainerNotInitialized;
        
        // 创建应用上下文（从 global 获取资源，使用借用模式保持向后兼容）
        const db = zigcms.shared.global.get_db();
        const app_context = try AppContext.init(allocator, &config, db, container);
        errdefer app_context.deinit();
        
        // 设置日志器到上下文
        app_context.setLogger(global_logger);
        
        // 如果服务管理器存在，设置到上下文
        if (zigcms.shared.global.getServiceManager()) |sm| {
            app_context.setServiceManager(sm);
        }
        
        const bootstrap = try Bootstrap.init(allocator, &app, global_logger, container, app_context);

        app_ptr.* = .{
            .allocator = allocator,
            .config = config,
            .app = app,
            .bootstrap = bootstrap,
            .global_logger = global_logger,
            .system_initialized = true,
            .app_context = app_context,
        };

        try app_ptr.bootstrap.registerRoutes();

        return app_ptr;
    }

    pub fn destroy(self: *Self) void {
        self.app.deinit();
        
        // 注意：AppContext 中的资源是从 global 借用的，不要重复释放
        // 只需要释放 AppContext 结构体本身
        if (self.app_context) |ctx| {
            // 清除内部引用，避免在 deinit 中重复释放
            const allocator = ctx.allocator;
            allocator.destroy(ctx);
            self.app_context = null;
        }
        
        if (self.system_initialized) {
            logger.deinitDefault();
            zigcms.deinitSystem();
        }

        const allocator = self.allocator;
        allocator.destroy(self);
    }

    pub fn run(self: *Self) !void {
        self.bootstrap.printStartupSummary();
        logger.info("🚀 启动 ZigCMS 服务器", .{});
        try self.app.listen();
    }

    pub fn getConfig(self: *const Self) *const SystemConfig {
        return &self.config;
    }

    pub fn getLogger(self: *const Self) *logger.Logger {
        return self.global_logger;
    }

    pub fn getContainer(self: *const Self) *DIContainer {
        _ = self;
        return zigcms.shared.di.getGlobalContainer() orelse unreachable;
    }
    
    pub fn getContext(self: *const Self) *AppContext {
        return self.app_context orelse unreachable;
    }
};
