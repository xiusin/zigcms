//! 认证中间件 (Auth Middleware)
//!
//! 提供基于 zap 中间件模式的认证功能。
//! 这是旧版中间件实现，新代码推荐使用 `chain.zig` 和 `wrapper.zig`。
//!
//! ## 使用示例
//! ```zig
//! const auth_mw = @import("auth.middleware.zig");
//! var auth = auth_mw.AuthMiddleWare.init(other_handler);
//! router.handle_func("/api/protected", auth.getHandler());
//! ```

const std = @import("std");
const zap = @import("zap");
const middlewares = @import("mod.zig");

pub const AuthMiddleWare = struct {
    handler: middlewares.Handler,
    const Self = @This();

    pub const auth = struct {
        info: []const u8 = undefined,
        token: []const u8 = undefined,
    };

    pub fn init(other: ?*middlewares.Handler) Self {
        return .{
            .handler = middlewares.Handler.init(onRequest, other),
        };
    }

    // we need the handler as a common interface to chain stuff
    pub fn getHandler(self: *Self) *middlewares.Handler {
        return &self.handler;
    }

    // note that the first parameter is of type *Handler, not *Self !!!
    pub fn onRequest(handler: *middlewares.Handler, r: zap.Request, context: *middlewares.Context) bool {
        const self: *Self = @fieldParentPtr("handler", handler);
        _ = self;
        context.auth = auth{
            .info = "secret session",
            .token = "rot47-asdlkfjsaklfdj",
        };

        std.debug.print("\n\nSessionMiddleware: set session in context {any}\n\n", .{context.auth});
        return handler.handleOther(r, context);
    }
};
