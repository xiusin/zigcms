//! 项目根模块 - 组织各层入口
//!
//! 遏循整洁架构原则，将项目分为以下层次：
//! - API 层: 处理 HTTP 请求和响应
//! - 应用层: 协调业务流程和用例
//! - 领域层: 核心业务逻辑和模型
//! - 基础设施层: 外部服务集成和实现
//! - 共享层: 跨层通用组件

const std = @import("std");
const logger = @import("application/services/logger/logger.zig");

// ✅ 启用 MySQL 驱动（告诉 interface.zig 使用真正的 MySQL 驱动而非存根）
pub const mysql_enabled = true;

// 各层入口
pub const api = @import("api/Api.zig");
pub const application = @import("application/mod.zig");
pub const domain = @import("domain/mod.zig");
pub const infrastructure = @import("infrastructure/mod.zig");
pub const shared = @import("shared/mod.zig");

// 服务管理器
pub const ServiceManager = @import("application/services/Services.zig").ServiceManager;

// 全局服务实例
var service_manager: ?ServiceManager = null;

/// 系统主配置
pub const SystemConfig = struct {
    api: api.ServerConfig = .{},
    app: application.AppConfig = .{},
    infra: infrastructure.InfraConfig = .{},
    domain: domain.DomainConfig = .{},
    shared: shared.SharedConfig = .{},
};

/// 全局服务管理器获取函数
pub fn getServiceManager() *ServiceManager {
    return service_manager.?;
}

/// 初始化整个系统
pub fn initSystem(allocator: std.mem.Allocator, config: SystemConfig) !void {
    // 初始化各层，遵照依赖关系
    try shared.init(allocator, config.shared);
    try domain.init(allocator, config.domain);
    try application.init(allocator, config.app);
    try api.init(allocator, config.api);
    const db = try infrastructure.init(allocator, config.infra);
    logger.info("系统初始化完成", .{});

    // 初始化服务管理器
    service_manager = try ServiceManager.init(allocator, db, config);
    logger.info("服务管理器初始化完成", .{});
}

/// 清理整个系统
pub fn deinitSystem() void {
    logger.info("开始系统清理...", .{});

    // 按照初始化相反的顺序进行清理
    // 目前只有 shared 层包含需要显式清理的全局资源
    shared.deinit();

    logger.info("系统清理完成", .{});
}
