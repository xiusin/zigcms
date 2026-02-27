//! 共享层兼容入口 (Shared Layer Compatibility)
//!
//! 此文件提供向后兼容，将旧的 shared 导入重定向到新的 core 层。
//! 新代码应直接使用 @import("src/core/mod.zig")。
//!
//! ## 迁移指南
//! 旧代码: const shared = @import("shared/mod.zig");
//! 新代码: const core = @import("src/core/mod.zig");

const std = @import("std");

// 重导出 core 层的所有模块
const core = @import("../src/core/mod.zig");

// ============================================================================
// 兼容性导出（保持旧 API 不变）
// ============================================================================

/// 工具函数模块
pub const utils = core.utils;

/// 基础原语模块（已合并到 core）
pub const primitives = struct {
    pub const global = @import("primitives/global.zig");
    pub const container = core.di.container;
    pub const registry = @import("primitives/registry.zig");
    pub const logger = core.logging;
};

/// 通用类型定义模块
pub const types = core.types;

/// 统一错误处理模块
pub const errors = core.errors;

/// 配置模块
pub const config = core.config;

/// 依赖注入模块
pub const di = core.di;

/// 上下文模块
pub const context = core.context;

// ============================================================================
// 便捷访问（向后兼容）
// ============================================================================

/// 全局变量管理器
pub const global = primitives.global;

/// 日志记录器
pub const logger = core.logging;

// ============================================================================
// 层配置
// ============================================================================

/// 共享层配置（映射到 CoreConfig）
pub const SharedConfig = core.CoreConfig;

// ============================================================================
// 生命周期管理
// ============================================================================

/// 初始化共享层（委托给 core）
pub fn init(allocator: std.mem.Allocator, shared_config: SharedConfig) !void {
    try core.init(allocator, shared_config);
}

/// 清理共享层（委托给 core）
pub fn deinit() void {
    core.deinit();
}
