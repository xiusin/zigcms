//! Shared Primitives Module
//!
//! 基础原语模块入口
//! 提供全局变量、容器、注册表等基础设施

// 全局变量管理
pub const global = @import("global.zig");

// 依赖注入容器
pub const container = @import("container.zig");

// 服务注册表
pub const registry = @import("registry.zig");

// 日志记录器
pub const logger = @import("logger.zig");

// 导出所有原语模块
pub const Primitives = struct {
    pub const Global = global;
    pub const Container = container;
    pub const Registry = registry;
    pub const Logger = logger;
};
