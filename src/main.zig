const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;
const Mustache = zap.Mustache;
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

fn not_found(req: zap.Request) void {
    req.setStatus(.not_found);
    base.send_failed(req, "the url not found");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    var router = zap.Router.init(allocator, .{ .not_found = not_found });
    defer router.deinit();

    var login = controllers.Login.init(allocator);
    try router.handle_func("/login", &login, &controllers.Login.login);
    try router.handle_func("/register", &login, &controllers.Login.register);

    var public = controllers.Public.init(allocator);
    try router.handle_func("/public/upload", &public, &controllers.Public.upload);

    var menu = controllers.Menu.init(allocator);
    try router.handle_func("/menu/list", &menu, &controllers.Menu.list);

    var setting = controllers.Setting.init(allocator);
    try router.handle_func("/setting/get", &setting, &controllers.Setting.get);
    try router.handle_func("/setting/save", &setting, &controllers.Setting.save);

    inline for (std.meta.fields(@TypeOf(cruds))) |field| {
        const generic = controllers.Generic.Generic(@field(cruds, field.name));
        var generics = generic.init(allocator);
        try router.handle_func("/" ++ field.name ++ "/get", &generics, &generic.get);
        try router.handle_func("/" ++ field.name ++ "/list", &generics, &generic.list);
        try router.handle_func("/" ++ field.name ++ "/delete", &generics, &generic.delete);
        try router.handle_func("/" ++ field.name ++ "/save", &generics, &generic.save);
        try router.handle_func("/" ++ field.name ++ "/modify", &generics, &generic.modify);
    }

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = router.on_request_handler(),
        .log = true,
        .public_folder = "resources",
        .max_clients = 10000,
        .timeout = 3,
    });
    try listener.listen();
    zap.start(.{ .threads = 1, .workers = 1 });
}
