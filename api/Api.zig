//! API 层入口文件
//!
//! 职责：
//! - 统一导出 API 层的所有组件
//! - 提供 HTTP 控制器、DTO、中间件的统一访问点

const std = @import("std");

// API 层组件
pub const controllers = @import("controllers/controllers.zig");
pub const dto = @import("dto/dtos.zig");
pub const middleware = @import("middleware/middlewares.zig");

/// API 服务器配置
pub const ServerConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 3000,
    max_clients: u32 = 10000,
    timeout: u32 = 30,
    public_folder: []const u8 = "resources",
};

/// API 层初始化函数
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // 初始化 API 层组件
    std.log.info("API 层初始化完成", .{});
}