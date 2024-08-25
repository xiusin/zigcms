const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const global = @import("global/global.zig");
const controllers = @import("controllers/controllers.zig");
const base = @import("controllers/base.fn.zig");
const models = @import("models/models.zig");
const strings = @import("modules/strings.zig");

const cruds = .{
    .category = models.Category,
    .upload = models.Upload,
    .article = models.Article,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    var simpleRouter = zap.Router.init(allocator, .{});
    defer simpleRouter.deinit();

    var login = controllers.Login.init(allocator);
    try simpleRouter.handle_func("/login", &login, &controllers.Login.login);
    try simpleRouter.handle_func("/register", &login, &controllers.Login.register);

    var public = controllers.Public.init(allocator);
    try simpleRouter.handle_func("/public/upload", &public, &controllers.Public.upload);

    var menu = controllers.Menu.init(allocator);
    try simpleRouter.handle_func("/menu/list", &menu, &controllers.Menu.list);

    var setting = controllers.Setting.init(allocator);
    try simpleRouter.handle_func("/setting/get", &setting, &controllers.Setting.get);
    try simpleRouter.handle_func("/setting/save", &setting, &controllers.Setting.save);

    inline for (std.meta.fields(@TypeOf(cruds))) |field| {
        const generic = controllers.Generic.Generic(@field(cruds, field.name));
        var generics = generic.init(allocator);
        try simpleRouter.handle_func("/" ++ field.name ++ "/get", &generics, &generic.get);
        try simpleRouter.handle_func("/" ++ field.name ++ "/list", &generics, &generic.list);
        try simpleRouter.handle_func("/" ++ field.name ++ "/delete", &generics, &generic.delete);
        try simpleRouter.handle_func("/" ++ field.name ++ "/save", &generics, &generic.save);
        try simpleRouter.handle_func("/" ++ field.name ++ "/modify", &generics, &generic.modify);
    }

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = true,
        .public_folder = "resources",
        .max_clients = 10000,
        .timeout = 3,
    });
    try listener.listen();
    zap.start(.{ .threads = 1, .workers = 1 });
}
