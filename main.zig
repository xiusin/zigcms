//! ZigCMS 主程序入口
//!
//! 职责：
//! - 初始化内存分配器
//! - 创建并启动应用实例
//!
//! 遵循整洁架构原则，main.zig 只负责高层初始化，
//! 具体的配置加载、系统初始化、路由注册等逻辑委托给 Application 模块处理。

const std = @import("std");
const Application = @import("src/api/Application.zig").Application;

// ✅ 启用 MySQL 驱动（编译时标志，供 interface.zig 检测）
pub const mysql_enabled = true;

pub fn main() !void {
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

    // 解析启动参数
    var print_routes: bool = false; // 默认不打印路由
    var args_iter = std.process.args();
    _ = args_iter.skip(); // 跳过程序名

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--print-routes")) {
            print_routes = true;
        } else if (std.mem.eql(u8, arg, "--no-print-routes")) {
            print_routes = false;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("ZigCMS 服务器\n\n", .{});
            std.debug.print("用法: zigcms [选项]\n\n", .{});
            std.debug.print("选项:\n", .{});
            std.debug.print("  --print-routes      启动时打印已注册的路由列表\n", .{});
            std.debug.print("  --no-print-routes   启动时不打印路由列表（默认）\n", .{});
            std.debug.print("  --help, -h          显示此帮助信息\n\n", .{});
            std.debug.print("环境变量:\n", .{});
            std.debug.print("  PRINT_ROUTES=1      设置为1时打印路由列表\n", .{});
            std.debug.print("  PRINT_ROUTES=0      设置为0时不打印路由列表\n\n", .{});
            std.debug.print("示例:\n", .{});
            std.debug.print("  zigcms                     # 启动服务器（默认不打印路由）\n", .{});
            std.debug.print("  zigcms --print-routes      # 启动服务器并打印路由\n", .{});
            std.debug.print("  PRINT_ROUTES=1 zigcms      # 通过环境变量控制打印路由\n", .{});
            return;
        }
    }

    // 检查环境变量 PRINT_ROUTES
    if (std.process.getEnvVarOwned(allocator, "PRINT_ROUTES")) |env_val| {
        defer allocator.free(env_val);
        if (std.mem.eql(u8, env_val, "1") or std.mem.eql(u8, env_val, "true") or std.mem.eql(u8, env_val, "yes")) {
            print_routes = true;
        }
    } else |_| {
        // 环境变量不存在，保持默认值
    }

    var app = try Application.create(allocator, print_routes);
    defer app.destroy();

    try app.run();
}
