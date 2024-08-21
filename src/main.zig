const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const Allocator = std.mem.Allocator;

const global = @import("global/global.zig");
const controllers = @import("controllers/controllers.zig");
const base = @import("controllers/base.fn.zig");
const models = @import("models/models.zig");
const strings = @import("modules/strings.zig");

pub fn main() !void {
    // std.log.debug("{?}", Struct2Tuple(models.Admin));
    const model = try controllers.Generic.get_model("banner");
    std.log.debug("model = {s}", .{@typeName(model)});

    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    global.set_allocator(allocator);

    // std.log.debug("repeat = {s}", .{strings.trim("hello wosld ", "hd ")});
    // std.log.debug("repeat = {s}", .{strings.strtolower("HELLO world")});
    // std.log.debug("shuffle = {s}", .{try strings.shuffle(allocator, "HELLO world,你好,我的世界")});
    // std.log.debug("shuffle = {s}", .{strings.lcfrist(@constCast("HELLO world,你好,我的世界"))});
    // std.log.debug("lcfrist 世界 = {s}", .{strings.lcfrist("你好,我的世界")});

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

    var upload = controllers.Upload.init(allocator);
    try simpleRouter.handle_func("/upload/list", &upload, &controllers.Upload.list);
    try simpleRouter.handle_func("/upload/delete", &upload, &controllers.Upload.delete);

    const generic = controllers.Generic.Generic(models.Banner);

    var generics = generic.init(allocator);
    try simpleRouter.handle_func("/generic/get", &generics, &generic.get);
    try simpleRouter.handle_func("/generic/list", &generics, &generic.list);
    try simpleRouter.handle_func("/generic/delete", &generics, &generic.delete);
    try simpleRouter.handle_func("/generic/save", &generics, &generic.save);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = simpleRouter.on_request_handler(),
        .log = false,
        .public_folder = "resources",
        .max_clients = 10000,
    });
    try listener.listen();
    zap.start(.{ .threads = 1, .workers = 1 });
}
