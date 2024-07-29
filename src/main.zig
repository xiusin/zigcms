const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const Public = @import("./controllers/public.controller.zig").Public;
const Login = @import("./controllers/login.controller.zig").Login;
const global = @import("global/global.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    var simpleRouter = zap.Router.init(allocator, .{});
    defer simpleRouter.deinit();

    var login = Login.init(allocator);
    try simpleRouter.handle_func("/login", &login, &Login.login);
    try simpleRouter.handle_func("/register", &login, &Login.register);

    var public = Public.init(allocator);
    try simpleRouter.handle_func("/public/upload", &public, &Public.upload);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = false,
        .public_folder = "resources",
        .max_clients = 10000,
    });
    zap.enableDebugLog();
    try listener.listen();
    zap.start(.{ .threads = 2, .workers = 2 });
}
