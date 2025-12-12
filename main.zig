// 主程序入口 - 整洁架构实现
const std = @import("std");
const zigcms = @import("root.zig");
const logger = @import("application/services/logger/logger.zig");

// ✅ 启用 MySQL 驱动（编译时标志，供 interface.zig 检测）
pub const mysql_enabled = true;
const App = @import("api/App.zig").App;
const controllers = @import("api/controllers/mod.zig");
const models = @import("domain/entities/models.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            // 服务器被终止时可能有未释放资源，这是正常的
            std.debug.print("⚠️ 检测到内存泄漏（可能是服务器被强制终止）\n", .{});
        } else {
            std.debug.print("✅ 服务器正常退出，无内存泄漏\n", .{});
        }
        std.debug.print("👋 ZigCMS 服务器已关闭\n", .{});
    }

    const allocator = gpa.allocator();

    // 初始化系统各层
    const config = zigcms.SystemConfig{};
    try zigcms.initSystem(allocator, config);
    defer zigcms.deinitSystem();

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
    try app.crud("dict", models.Dict); // 添加字典模型的CRUD

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

    // 字典管理控制器
    var dict_ctrl = controllers.dict.Dict.init(allocator);
    try app.route("/dict/types", &dict_ctrl, &controllers.dict.Dict.getDictTypes);
    try app.route("/dict/by_type", &dict_ctrl, &controllers.dict.Dict.getDictByType);
    try app.route("/dict/search", &dict_ctrl, &controllers.dict.Dict.searchDict);
    try app.route("/dict/count", &dict_ctrl, &controllers.dict.Dict.countDict);
    try app.route("/dict/validate", &dict_ctrl, &controllers.dict.Dict.validateDictValue);
    try app.route("/dict/label", &dict_ctrl, &controllers.dict.Dict.getDictLabel);
    try app.route("/dict/refresh_cache", &dict_ctrl, &controllers.dict.Dict.refreshCache);
    try app.route("/dict/cache_stats", &dict_ctrl, &controllers.dict.Dict.getCacheStats);
    try app.route("/dict/cleanup_cache", &dict_ctrl, &controllers.dict.Dict.cleanupCache);

    // ========================================================================
    // 启动服务器
    // ========================================================================
    logger.info("🚀 启动 ZigCMS 服务器", .{});
    try app.listen(3000);
}
