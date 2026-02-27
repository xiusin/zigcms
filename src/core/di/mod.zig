//! 依赖注入模块 (Dependency Injection Module)
//!
//! 此模块重导出 shared/di/mod.zig 的功能，确保整个系统使用同一个 DI 实例。
//! 保留此文件以保持 core 层 API 的一致性。

const shared_di = @import("../../../shared/di/mod.zig");

pub const container = @import("container.zig");
pub const DIContainer = container.DIContainer;
pub const ServiceLifetime = container.ServiceLifetime;

/// 初始化全局 DI 系统（委托给 shared/di）
pub const initGlobalDISystem = shared_di.initGlobalDISystem;

/// 获取全局容器（委托给 shared/di）
pub const getGlobalContainer = shared_di.getGlobalContainer;

/// 清理全局 DI 系统（委托给 shared/di）
pub const deinitGlobalDISystem = shared_di.deinitGlobalDISystem;

/// 注册服务（委托给 shared/di）
pub const registerService = shared_di.registerService;

/// 解析服务（委托给 shared/di）
pub const resolveService = shared_di.resolveService;

/// 获取全局注册表（委托给 shared/di）
pub const getGlobalRegistry = shared_di.getGlobalRegistry;
