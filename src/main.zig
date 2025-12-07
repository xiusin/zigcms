const std = @import("std");
const App = @import("app.zig").App;
const controllers = @import("controllers/controllers.zig");
const models = @import("models/models.zig");

// 重新导出 pg 模块供 interface.zig 使用
pub const pg = @import("pg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("内存泄漏");
        } else std.log.debug("服务器正常退出", .{});
    }

    const allocator = gpa.allocator();

    // 初始化应用
    var app = try App.init(allocator);
    defer app.deinit();

    // ========================================================================
    // 注册 CRUD 模块（自动生成 list/get/save/delete/modify/select 路由）
    // ========================================================================
    try app.crud("category", models.Category);
    try app.crud("upload", models.Upload);
    try app.crud("article", models.Article);
    try app.crud("role", models.Role);

    // ========================================================================
    // 注册自定义控制器
    // ========================================================================

    // 登录控制器
    var login = controllers.Login.init(allocator);
    try app.route("/login", &login, &controllers.Login.login);
    try app.route("/register", &login, &controllers.Login.register);

    // 公共接口
    var public = controllers.Public.init(allocator);
    try app.route("/public/upload", &public, &controllers.Public.upload);
    try app.route("/public/folder", &public, &controllers.Public.folder);
    try app.route("/public/files", &public, &controllers.Public.files);

    // 菜单控制器
    var menu = controllers.Menu.init(allocator);
    try app.route("/menu/list", &menu, &controllers.Menu.list);

    // 设置控制器
    var setting = controllers.Setting.init(allocator);
    try app.route("/setting/get", &setting, &controllers.Setting.get);
    try app.route("/setting/save", &setting, &controllers.Setting.save);
    try app.route("/setting/send_email", &setting, &controllers.Setting.send_mail);

    // ========================================================================
    // 使用服务容器（可选）
    // ========================================================================
    // const services = app.services_ref();
    // const cache = services.getCache();
    // try cache.set("app_started", std.time.timestamp());

    // 启动服务器
    try app.listen(3000);
}
