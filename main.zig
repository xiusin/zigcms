//! ZigCMS 主程序入口
//!
//! 职责：
//! - 初始化内存分配器
//! - 创建并启动应用实例
//!
//! 遵循整洁架构原则，main.zig 只负责高层初始化，
//! 具体的配置加载、系统初始化、路由注册等逻辑委托给 Application 模块处理。

const std = @import("std");
const Application = @import("api/Application.zig").Application;

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

    var app = try Application.create(allocator);
    defer app.destroy();

    try app.run();
}
