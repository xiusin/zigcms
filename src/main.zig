const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const Public = @import("./controllers/public.controller.zig").Public;
const Login = @import("./controllers/login.controller.zig").Login;
const Menu = @import("./controllers/menu.controller.zig").Menu;
const global = @import("global/global.zig");
const base = @import("./controllers/base.fn.zig");
const models = @import("./models/models.zig");

fn structToTuple(structure: anytype) @TypeOf(structure) {
    var tuple: @TypeOf(structure) = undefined;
    inline for (std.meta.fields(@TypeOf(structure))) |field| {
        @field(tuple, field.name) = @field(structure, field.name);
    }
    return tuple;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    const sql = try base.build_insert_sql(models.Admin, allocator);
    defer allocator.free(sql);

    var pool = try global.get_pg_pool();

    const admin = models.Admin{
        .username = "admin",
        .password = "123456",
    };

    try pool.exec(sql, structToTuple(admin));

    var simpleRouter = zap.Router.init(allocator, .{});
    defer simpleRouter.deinit();

    var login = Login.init(allocator);
    try simpleRouter.handle_func("/login", &login, &Login.login);
    try simpleRouter.handle_func("/register", &login, &Login.register);

    var public = Public.init(allocator);
    try simpleRouter.handle_func("/public/upload", &public, &Public.upload);

    var menu = Menu.init(allocator);
    try simpleRouter.handle_func("/menu/list", &menu, &Menu.list);

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
