//! API 层 - 处理 HTTP 请求和响应
//!
//! 职责：
//! - 接收 HTTP 请求
//! - 验证请求参数
//! - 调用应用服务
//! - 返回 HTTP 响应
//! - 处理路由和中间件

const std = @import("std");

// API 层导出
pub const controllers = @import("controllers/controllers.zig");
pub const dto = @import("dto");
pub const middleware = @import("middleware");

/// API 层配置
pub const Config = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 3000,
    max_clients: u32 = 10000,
    timeout: u32 = 30,
};