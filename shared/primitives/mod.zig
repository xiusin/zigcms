//! 基础原语模块 (Primitives Module)
//!
//! 提供应用程序的基础设施组件，包括全局状态管理、
//! 依赖注入容器、服务注册表和日志记录器。
//!
//! ## 包含的组件
//! - `global`: 全局变量管理器
//! - `container`: 依赖注入容器
//! - `registry`: 服务注册表
//! - `logger`: 日志记录器

/// 全局变量管理器
///
/// 管理应用程序的全局状态，如数据库连接、配置等。
/// 注意：优先使用依赖注入而非全局变量。
pub const global = @import("global.zig");

/// 依赖注入容器
///
/// 提供服务的注册和解析功能，支持单例和瞬态生命周期。
pub const container = @import("container.zig");

/// 服务注册表
///
/// 管理服务的注册和查找，支持按名称或类型查找服务。
pub const registry = @import("registry.zig");

/// 日志记录器
///
/// 提供统一的日志记录接口，支持不同级别的日志输出。
pub const logger = @import("logger.zig");

/// 原语模块统一访问结构
///
/// 提供所有原语的统一访问点。
pub const Primitives = struct {
    pub const Global = global;
    pub const Container = container;
    pub const Registry = registry;
    pub const Logger = logger;
};
