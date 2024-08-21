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
    .admin = models.Admin,
    .cate = models.Category,
    .article = models.Article,
};

fn auth(instance: *anyopaque, handler: anytype) fn (req: zap.Request) void {
    // TODO 鉴权
    //    @call(.auto, @as(zap.BoundHandler, @ptrFromInt(b.handler)), .{ @as(*anyopaque, @ptrFromInt(b.instance)), r })
}

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

    var article = controllers.Article.init(allocator);
    try simpleRouter.handle_func("/article/get", &article, &controllers.Article.get);
    try simpleRouter.handle_func("/article/list", &article, &controllers.Article.list);
    try simpleRouter.handle_func("/article/delete", &article, &controllers.Article.delete);
    try simpleRouter.handle_func("/article/save", &article, &controllers.Article.save);
    try simpleRouter.handle_func("/article/modify", &article, &controllers.Article.modify);

    var category = controllers.Category.init(allocator);
    try simpleRouter.handle_func("/category/get", &category, &controllers.Category.get);
    try simpleRouter.handle_func("/category/list", &category, &controllers.Category.list);
    try simpleRouter.handle_func("/category/delete", &category, &controllers.Category.delete);
    try simpleRouter.handle_func("/category/save", &category, &controllers.Category.save);
    try simpleRouter.handle_func("/category/modify", &category, &controllers.Category.modify);

    simpleRouter.handle_func_unbound("/xxx", fn (req: zap.Request) void{});

    var upload = controllers.Upload.init(allocator);
    try simpleRouter.handle_func("/upload/list", &upload, &controllers.Upload.list);
    try simpleRouter.handle_func("/upload/delete", &upload, &controllers.Upload.delete);

    inline for (std.meta.fields(@TypeOf(cruds))) |field| {
        const field_value = @field(cruds, field.name);
        const generic = controllers.Generic.Generic(field_value);

        var generics = generic.init(allocator);
        try simpleRouter.handle_func("/" ++ field.name ++ "/get", &generics, &generic.get);
        try simpleRouter.handle_func("/" ++ field.name ++ "/list", &generics, &generic.list);
        try simpleRouter.handle_func("/" ++ field.name ++ "/delete", &generics, &generic.delete);
        try simpleRouter.handle_func("/" ++ field.name ++ "/save", &generics, &generic.save);
    }

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = false,
        .public_folder = "resources",
        .max_clients = 10000,
    });
    try listener.listen();
    zap.start(.{ .threads = 2, .workers = 2 });
}
