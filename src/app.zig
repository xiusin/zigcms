//! 应用框架
//!
//! 基于 DI 容器的统一应用入口，提供：
//! - 服务注册与解析
//! - CRUD 控制器批量注册
//! - 中间件支持
//! - 内存安全的生命周期管理
//!
//! ## 使用示例
//!
//! ```zig
//! var app = try App.init(allocator);
//! defer app.deinit();
//!
//! // 注册 CRUD 模块
//! app.crud("category", models.Category);
//! app.crud("article", models.Article);
//!
//! // 注册自定义路由
//! app.get("/login", LoginController.login);
//! app.post("/upload", PublicController.upload);
//!
//! // 启动服务
//! try app.listen(3000);
//! ```

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const global = @import("global/global.zig");
const base = @import("controllers/base.fn.zig");
const strings = @import("modules/strings.zig");
const controllers = @import("controllers/controllers.zig");
const models = @import("models/models.zig");
const container = @import("global/container.zig");

/// 应用实例
pub const App = struct {
    const Self = @This();

    allocator: Allocator,
    router: zap.Router,
    services: Services,
    initialized: bool = false,

    /// 服务容器
    pub const Services = struct {
        const ControllerEntry = struct {
            ptr: *anyopaque,
            allocator: Allocator,
            size: usize,
            alignment: u8,
            deinitFn: ?*const fn (*anyopaque) void,

            /// 释放控制器：先调用 deinit，再释放内存
            pub fn destroy(self: ControllerEntry) void {
                if (self.deinitFn) |deinitFn| {
                    deinitFn(self.ptr);
                }
                // 释放内存
                const slice_ptr: [*]u8 = @ptrCast(self.ptr);
                const slice = slice_ptr[0..self.size];
                self.allocator.rawFree(slice, @enumFromInt(self.alignment), @returnAddress());
            }
        };

        allocator: Allocator,

        // 控制器存储（用于生命周期管理）
        // 存储 (指针, 销毁函数) 对，确保类型擦除后仍能正确释放
        controller_ptrs: std.ArrayListUnmanaged(ControllerEntry),

        // 缓存服务
        cache: ?*container.Cache = null,
        config: ?*container.Config = null,

        pub fn init(allocator: Allocator) Services {
            return .{
                .allocator = allocator,
                .controller_ptrs = .empty,
            };
        }

        pub fn deinit(self: *Services) void {
            // 清理控制器
            for (self.controller_ptrs.items) |entry| {
                entry.destroy();
            }
            self.controller_ptrs.deinit(self.allocator);

            // 清理服务
            if (self.cache) |c| {
                c.deinit();
                self.allocator.destroy(c);
            }
            if (self.config) |c| {
                c.deinit();
                self.allocator.destroy(c);
            }
        }

        /// 获取缓存服务（延迟初始化）
        pub fn getCache(self: *Services) *container.Cache {
            if (self.cache == null) {
                self.cache = self.allocator.create(container.Cache) catch unreachable;
                self.cache.?.* = container.Cache.init(self.allocator);
            }
            return self.cache.?;
        }

        /// 获取配置服务（延迟初始化）
        pub fn getConfig(self: *Services) *container.Config {
            if (self.config == null) {
                self.config = self.allocator.create(container.Config) catch unreachable;
                self.config.?.* = container.Config.init(self.allocator);
            }
            return self.config.?;
        }
    };

    /// 初始化应用
    pub fn init(allocator: Allocator) !Self {
        global.init(allocator);

        return .{
            .allocator = allocator,
            .router = zap.Router.init(allocator, .{
                .not_found = notFoundHandler,
            }),
            .services = Services.init(allocator),
            .initialized = true,
        };
    }

    /// 销毁应用
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        self.services.deinit();
        self.router.deinit();
        global.deinit();
        self.initialized = false;
    }

    /// 注册 CRUD 路由
    pub fn crud(self: *Self, comptime name: []const u8, comptime T: type) !void {
        const Controller = controllers.Crud(T, "zigcms");
        const ctrl_ptr = try self.allocator.create(Controller);
        ctrl_ptr.* = Controller.init(self.allocator);

        // 创建类型擦除的 deinit 函数
        const deinitFn: ?*const fn (*anyopaque) void = if (@hasDecl(Controller, "deinit"))
            struct {
                fn deinit(ptr: *anyopaque) void {
                    const typed: *Controller = @ptrCast(@alignCast(ptr));
                    typed.deinit();
                }
            }.deinit
        else
            null;

        try self.services.controller_ptrs.append(self.allocator, .{
            .ptr = ctrl_ptr,
            .allocator = self.allocator,
            .size = @sizeOf(Controller),
            .alignment = std.math.log2_int(usize, @alignOf(Controller)),
            .deinitFn = deinitFn,
        });

        try self.router.handle_func("/" ++ name ++ "/list", ctrl_ptr, Controller.list);
        try self.router.handle_func("/" ++ name ++ "/get", ctrl_ptr, Controller.get);
        try self.router.handle_func("/" ++ name ++ "/save", ctrl_ptr, Controller.save);
        try self.router.handle_func("/" ++ name ++ "/delete", ctrl_ptr, Controller.delete);
        try self.router.handle_func("/" ++ name ++ "/modify", ctrl_ptr, Controller.modify);
        try self.router.handle_func("/" ++ name ++ "/select", ctrl_ptr, Controller.select);
    }

    /// 注册路由
    pub fn route(self: *Self, path: []const u8, ctrl: anytype, handler: anytype) !void {
        try self.router.handle_func(path, ctrl, handler);
    }

    /// 获取服务容器
    pub fn services_ref(self: *Self) *Services {
        return &self.services;
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
        base.send_failed(req, "404 Not Found");
    }
};

/// 批量注册 CRUD 模块
pub fn registerCrudModules(app: *App, comptime modules: anytype) !void {
    inline for (std.meta.fields(@TypeOf(modules))) |field| {
        const module = @field(modules, field.name);
        try app.crud(field.name, module);
    }
}
