//! 应用层入口文件
//!
//! 职责：
//! - 定义业务用例和应用服务
//! - 协调领域对象执行业务逻辑
//! - 处理事务管理
//! - 提供应用级别的接口

const std = @import("std");

// 应用服务管理器
pub const services = @import("Services.zig").ServiceManager;

/// 应用层配置
pub const AppConfig = struct {
    // 业务逻辑相关的配置参数
    enable_cache: bool = true,
    cache_ttl_seconds: u64 = 3600,
    max_concurrent_tasks: u32 = 100,
};

/// 应用层初始化函数
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // 初始化应用层组件
    std.log.info("应用层初始化完成", .{});
}