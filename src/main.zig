const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const Login = @import("./controllers/login.controller.zig").Login;
const global = @import("global/global.zig");

fn not_found(req: zap.Request) void {
    std.debug.print("not found handler", .{});

    req.sendBody("Not found") catch return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);
    var simpleRouter = zap.Router.init(allocator, .{ .not_found = not_found });
    defer simpleRouter.deinit();

    var login = Login.init(allocator);
    try simpleRouter.handle_func("/login", &login, &Login.login);
    try simpleRouter.handle_func("/register", &login, &Login.register);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(), // TODO 闭包执行中间件
        .log = false,
        .public_folder = "reources",
        .max_clients = 10000,
    });
    try listener.listen();
    zap.enableDebugLog();
    zap.start(.{ .threads = 2, .workers = 1 });
}
