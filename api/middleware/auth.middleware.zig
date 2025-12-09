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
