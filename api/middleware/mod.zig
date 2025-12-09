//! 中间件模块
//!
//! 提供类似 Gin 的中间件模式。
//!
//! ## 使用方式一：控制器包装器（推荐）
//!
//! ```zig
//! const mw = @import("middlewares/middlewares.zig");
//!
//! // 定义控制器
//! const UserController = struct {
//!     const Self = @This();
//!     const MW = mw.Controller(Self);
//!
//!     // 需要认证的方法
//!     pub const getProfile = MW.requireAuth(getProfileImpl);
//!     fn getProfileImpl(self: *Self, req: zap.Request) void {
//!         // 已通过认证
//!     }
//!
//!     // 公开方法（带日志）
//!     pub const list = MW.withLog(listImpl);
//!     fn listImpl(self: *Self, req: zap.Request) void {
//!         // ...
//!     }
//!
//!     // 组合多个中间件
//!     pub const create = MW.compose(createImpl, &.{
//!         MW.withLog,
//!         MW.withCors,
//!         MW.requireAuth,
//!     });
//!     fn createImpl(self: *Self, req: zap.Request) void {
//!         // ...
//!     }
//! };
//! ```
//!
//! ## 使用方式二：链式中间件
//!
//! ```zig
//! var chain = mw.Chain(8).init(allocator);
//! chain.use(mw.logMiddleware)
//!      .use(mw.corsMiddleware)
//!      .use(mw.authMiddleware)
//!      .handle(myHandler);
//!
//! chain.execute(request);
//! ```

const zap = @import("zap");

// 导出子模块
pub const chain = @import("chain.zig");
pub const wrapper = @import("wrapper.zig");

// 类型导出
pub const Context = chain.Context;
pub const Result = chain.Result;
pub const Chain = chain.Chain;
pub const Controller = wrapper.Controller;
pub const AuthChecker = wrapper.AuthChecker;
pub const CheckResult = wrapper.CheckResult;

// 内置中间件
pub const authMiddleware = chain.authMiddleware;
pub const logMiddleware = chain.logMiddleware;
pub const corsMiddleware = chain.corsMiddleware;
pub const rateLimitMiddleware = chain.rateLimitMiddleware;

// 便捷函数
pub const checkAuth = wrapper.checkAuth;
pub const sendError = wrapper.sendError;
pub const sendOk = wrapper.sendOk;

// 旧版兼容
pub const authMiddlewareOld = @import("auth.middleware.zig").AuthMiddleWare;
pub const Handler = zap.Middleware.Handler(OldContext);
pub const OldContext = struct {
    auth: ?authMiddlewareOld.auth = null,
};

test {
    _ = chain;
    _ = wrapper;
}
