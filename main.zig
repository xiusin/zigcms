//! ZigCMS 主程序入口
//!
//! 职责：
//! - 初始化内存分配器
//! - 调用 Bootstrap 模块进行系统初始化
//! - 启动 HTTP 服务器
//!
//! 遵循整洁架构原则，main.zig 只负责高层初始化和启动逻辑，
//! 具体的路由注册和服务配置委托给 Bootstrap 模块处理。

const std = @import("std");
const zigcms = @import("root.zig");
const logger = @import("application/services/logger/logger.zig");
const App = @import("api/App.zig").App;
const Bootstrap = @import("api/bootstrap.zig").Bootstrap;

// ✅ 启用 MySQL 驱动（编译时标志，供 interface.zig 检测）
pub const mysql_enabled = true;

pub fn main() !void {
    // ========================================================================
    // 1. 初始化内存分配器
    // ========================================================================
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            std.debug.print("⚠️ 检测到内存泄漏（可能是服务器被强制终止）\n", .{});
        } else {
            std.debug.print("✅ 服务器正常退出，无内存泄漏\n", .{});
        }
        std.debug.print("👋 ZigCMS 服务器已关闭\n", .{});
    }
    const allocator = gpa.allocator();

    // ========================================================================
    // 2. 初始化系统各层
    // ========================================================================
    const config = zigcms.SystemConfig{};
    try zigcms.initSystem(allocator, config);
    defer zigcms.deinitSystem();

    // 初始化日志系统
    try logger.initDefault(allocator, .{ .level = .debug, .format = .colored });
    defer logger.deinitDefault();
    const global_logger = logger.getDefault() orelse @panic("Logger not initialized");

    // ========================================================================
    // 3. 初始化应用框架
    // ========================================================================
    var app = try App.init(allocator);
    defer app.deinit();

    // ========================================================================
    // 4. 使用 Bootstrap 注册路由
    // ========================================================================
    var bootstrap = Bootstrap.init(allocator, &app, global_logger);
    try bootstrap.registerRoutes();

    // ========================================================================
    // 5. 打印启动摘要并启动服务器
    // ========================================================================
    bootstrap.printStartupSummary();
    logger.info("🚀 启动 ZigCMS 服务器", .{});
    try app.listen();
}
