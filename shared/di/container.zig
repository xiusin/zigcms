//! 依赖注入容器 (DI Container)
//!
//! 此文件重导出 src/core/di/container.zig 的内容。
//! 保留此文件以保持向后兼容。

const core_container = @import("../../src/core/di/container.zig");

pub const DIContainer = core_container.DIContainer;
pub const ServiceLifetime = core_container.ServiceLifetime;
