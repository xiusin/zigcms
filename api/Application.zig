const std = @import("std");
const zigcms = @import("../root.zig");
const logger = @import("../application/services/logger/logger.zig");
const App = @import("App.zig").App;
const Bootstrap = @import("bootstrap.zig").Bootstrap;
const DIContainer = @import("../shared/di/container.zig").DIContainer;
const SystemConfig = @import("../shared/config/system_config.zig").SystemConfig;

pub const Application = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: SystemConfig,
    app: App,
    bootstrap: Bootstrap,
    global_logger: *logger.Logger,
    system_initialized: bool,

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
        const bootstrap = try Bootstrap.init(allocator, &app, global_logger, container);

        app_ptr.* = .{
            .allocator = allocator,
            .config = config,
            .app = app,
            .bootstrap = bootstrap,
            .global_logger = global_logger,
            .system_initialized = true,
        };

        try app_ptr.bootstrap.registerRoutes();

        return app_ptr;
    }

    pub fn destroy(self: *Self) void {
        self.app.deinit();
        
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
};
