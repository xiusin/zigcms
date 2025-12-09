// 主程序入口 - 整洁架构实现
const std = @import("std");
const zigcms = @import("root.zig");
const App = @import("api/App.zig").App;
const controllers = @import("api/controllers/controllers.zig");
const models = @import("domain/entities/models.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("内存泄漏");
        } else std.log.debug("服务器正常退出", .{});
        std.log.info("👋 ZigCMS 服务器已关闭", .{});
    }

    const allocator = gpa.allocator();

    // 初始化系统各层
    const config = zigcms.SystemConfig{};
    try zigcms.initSystem(allocator, config);

    // 初始化应用框架
    var app = try App.init(allocator);
    defer app.deinit();

    // ========================================================================
    // 领域层 - 注册实体模型
    // ========================================================================
    // 模型现在位于 domain/entities 目录

    // ========================================================================
    // 应用层 - 注册 CRUD 模块（自动生成 list/get/save/delete/modify/select 路由）
    // ========================================================================
    try app.crud("category", models.Category);
    try app.crud("upload", models.Upload);
    try app.crud("article", models.Article);
    try app.crud("role", models.Role);

    // ========================================================================
    // API 层 - 注册自定义控制器
    // ========================================================================

    // 登录控制器
    var login = controllers.auth.Login.init(allocator);
    try app.route("/login", &login, &controllers.auth.Login.login);
    try app.route("/register", &login, &controllers.auth.Login.register);

    // 公共接口
    var public = controllers.common.Public.init(allocator);
    try app.route("/public/upload", &public, &controllers.common.Public.upload);
    try app.route("/public/folder", &public, &controllers.common.Public.folder);
    try app.route("/public/files", &public, &controllers.common.Public.files);

    // 菜单控制器
    var menu = controllers.admin.Menu.init(allocator);
    try app.route("/menu/list", &menu, &controllers.admin.Menu.list);

    // 设置控制器
    var setting = controllers.admin.Setting.init(allocator);
    try app.route("/setting/get", &setting, &controllers.admin.Setting.get);
    try app.route("/setting/save", &setting, &controllers.admin.Setting.save);
    try app.route("/setting/send_email", &setting, &controllers.admin.Setting.send_mail);

    // ========================================================================
    // 启动服务器
    // ========================================================================
    std.log.info("🚀 启动 ZigCMS 服务器", .{});
    try app.listen(3000);
}