//! 项目根模块 - 组织各层入口
//!
//! 遵循整洁架构原则，将项目分为以下层次：
//! - API 层: 处理 HTTP 请求和响应
//! - 应用层: 协调业务流程和用例
//! - 领域层: 核心业务逻辑和模型
//! - 基础设施层: 外部服务集成和实现
//! - 共享层: 跨层通用组件

const std = @import("std");

// 各层入口
pub const api = @import("api/Api.zig");
pub const application = @import("application/mod.zig");
pub const domain = @import("domain/mod.zig");
pub const infrastructure = @import("infrastructure/mod.zig");
pub const shared = @import("shared/mod.zig");

/// 系统主配置
pub const SystemConfig = struct {
    api: api.ServerConfig = .{},
    app: application.AppConfig = .{},
    infra: infrastructure.InfraConfig = .{},
};

/// 初始化整个系统
pub fn initSystem(allocator: std.mem.Allocator, config: SystemConfig) !void {
    _ = config; // 忽略未使用的参数
    
    // 初始化各层，遵循依赖关系
    try shared.init(allocator);
    try domain.init(allocator);
    try infrastructure.init(allocator);
    try application.init(allocator);
    try api.init(allocator);
    
    std.log.info("系统初始化完成", .{});
}