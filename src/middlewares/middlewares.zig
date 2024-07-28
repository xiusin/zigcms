const zap = @import("zap");
pub const authMiddleware = @import("./auth.middleware.zig").AuthMiddleWare;
pub const Handler = zap.Middleware.Handler(Context);

pub const Context = struct {
    auth: ?authMiddleware.auth = null,
};
