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
    const allocator = std.heap.page_allocator;

    // 解析启动参数（Zig 0.16 兼容：使用 C 标准库获取环境变量）
    var print_routes: bool = false;

    // 检查环境变量 PRINT_ROUTES
    if (std.c.getenv("PRINT_ROUTES")) |env_ptr| {
        const env_val = std.mem.span(env_ptr);
        if (std.mem.eql(u8, env_val, "1") or std.mem.eql(u8, env_val, "true") or std.mem.eql(u8, env_val, "yes")) {
            print_routes = true;
        }
    }

    var app = try Application.create(allocator, print_routes);
    defer app.destroy();

    try app.run();
}
