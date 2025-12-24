//! 配置模块入口
//!
//! 本模块提供 ZigCMS 的配置加载和管理功能。
//!
//! ## 模块结构
//! - `system_config`: 系统配置结构体定义
//! - `config_loader`: 配置文件加载器
//! - `generated_config`: 自动生成的配置（从 .env 文件）
//! - `config_manager`: 配置管理器，支持热重载
//!
//! ## 使用示例
//! ```zig
//! const config = @import("shared/config/mod.zig");
//!
//! // 使用配置加载器
//! var loader = config.ConfigLoader.init(allocator, "configs");
//! defer loader.deinit();
//! const sys_config = try loader.loadAll();
//!
//! // 直接使用配置结构体
//! var api_config = config.ApiConfig{ .port = 8080 };
//! ```

const std = @import("std");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// 系统配置结构体
pub const system_config = @import("system_config.zig");

/// 配置加载器
pub const config_loader = @import("config_loader.zig");

/// 自动生成的配置（从 .env 文件）
pub const generated_config = @import("generated_config.zig");

/// 配置管理器（支持热重载）
pub const config_manager = @import("config_manager.zig");

// ============================================================================
// 便捷类型导出
// ============================================================================

/// 系统主配置
pub const SystemConfig = system_config.SystemConfig;

/// API 层配置
pub const ApiConfig = system_config.ApiConfig;

/// 应用层配置
pub const AppConfig = system_config.AppConfig;

/// 领域层配置
pub const DomainConfig = system_config.DomainConfig;

/// 基础设施层配置
pub const InfraConfig = system_config.InfraConfig;

/// 配置加载器
pub const ConfigLoader = config_loader.ConfigLoader;

/// 配置错误类型
pub const ConfigError = config_loader.ConfigError;

/// 配置管理器
pub const ConfigManager = config_manager.ConfigManager;

// ============================================================================
// 便捷函数
// ============================================================================

/// 从默认目录加载配置
///
/// 从 "configs" 目录加载所有配置文件。
///
/// ## 参数
/// - `allocator`: 内存分配器
///
/// ## 返回
/// 返回配置加载器和加载的配置
pub fn loadFromDefaultDir(allocator: std.mem.Allocator) !struct { loader: ConfigLoader, config: SystemConfig } {
    var loader = ConfigLoader.init(allocator, "configs");
    errdefer loader.deinit();

    const loaded_config = try loader.loadAll();
    return .{ .loader = loader, .config = loaded_config };
}

/// 加载并验证配置
///
/// 从指定目录加载配置并进行验证。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config_dir`: 配置文件目录
///
/// ## 返回
/// 返回配置加载器和验证后的配置
pub fn loadAndValidate(allocator: std.mem.Allocator, config_dir: []const u8) !struct { loader: ConfigLoader, config: SystemConfig } {
    var loader = ConfigLoader.init(allocator, config_dir);
    errdefer loader.deinit();

    const loaded_config = try loader.loadAll();
    try loader.validate(&loaded_config);

    return .{ .loader = loader, .config = loaded_config };
}
