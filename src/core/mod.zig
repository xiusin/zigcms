//! 核心层入口文件 (Core Layer)
//!
//! ZigCMS 核心层是整个系统的基础，提供跨层共享的基础设施。
//! 合并了原 shared 和 shared_kernel 的功能，消除重复实现。
//!
//! ## 职责
//! - 依赖注入容器（DI）
//! - 统一错误处理
//! - 日志系统
//! - 配置管理
//! - 通用类型定义
//! - 工具函数
//! - DDD 设计模式
//!
//! ## 模块结构
//! - `di`: 依赖注入容器
//! - `errors`: 统一错误处理
//! - `logging`: 日志系统
//! - `config`: 配置管理
//! - `types`: 通用类型定义
//! - `utils`: 工具函数
//! - `patterns`: DDD 设计模式
//! - `context`: 应用上下文
//!
//! ## 依赖规则
//! - 核心层不依赖任何业务层（domain, application, api, infrastructure）
//! - 仅依赖标准库

const std = @import("std");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// 依赖注入模块
pub const di = @import("di/mod.zig");

/// 统一错误处理模块
pub const errors = @import("errors/mod.zig");

/// 日志系统模块
pub const logging = @import("logging/mod.zig");

/// 配置管理模块
pub const config = @import("config/mod.zig");

/// 通用类型定义模块
pub const types = @import("types/mod.zig");

/// 工具函数模块
pub const utils = @import("utils/mod.zig");

/// DDD 设计模式模块
pub const patterns = @import("patterns/mod.zig");

/// 应用上下文模块
pub const context = @import("context/mod.zig");

/// 全局模块（原 shared/primitives/global）
pub const global = @import("primitives/global.zig");

/// 原语模块
pub const primitives = @import("primitives/mod.zig");

// ============================================================================
// 便捷访问
// ============================================================================

/// DI 容器类型
pub const DIContainer = di.DIContainer;

/// 服务生命周期
pub const ServiceLifetime = di.ServiceLifetime;

/// 应用错误类型
pub const AppError = errors.AppError;

/// 日志记录器
pub const Logger = logging.Logger;

// ============================================================================
// 层配置
// ============================================================================

/// 核心层配置
pub const CoreConfig = struct {
    /// 日志级别
    log_level: logging.LogLevel = .Info,
    /// 是否启用调试模式
    debug_mode: bool = false,
};

/// 共享层配置（兼容旧代码）
pub const SharedConfig = CoreConfig;

// ============================================================================
// 生命周期管理
// ============================================================================

/// 初始化核心层
pub fn init(allocator: std.mem.Allocator, core_config: CoreConfig) !void {
    _ = core_config;

    // 初始化 DI 系统
    try di.initGlobalDISystem(allocator);

    std.debug.print("✅ 核心层初始化完成\n", .{});
}

/// 清理核心层
pub fn deinit() void {
    // 清理 DI 系统
    di.deinitGlobalDISystem();

    std.debug.print("👋 核心层已清理\n", .{});
}
