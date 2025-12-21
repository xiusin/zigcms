//! 领域层入口文件 (Domain Layer)
//!
//! ZigCMS 领域层是整洁架构的核心，包含所有业务逻辑和规则。
//! 该层独立于框架和基础设施，确保业务逻辑的纯粹性和可测试性。
//!
//! ## 职责
//! - 定义核心业务实体和值对象
//! - 实现业务规则和约束验证
//! - 定义领域服务接口（跨实体的业务逻辑）
//! - 提供业务实体的仓储接口（数据访问契约）
//!
//! ## 模块结构
//! - `entities`: 业务实体模型（User, Article, Category 等）
//! - `services`: 领域服务（业务规则验证、计算逻辑）
//! - `repositories`: 仓储接口定义（数据访问契约）
//!
//! ## 使用示例
//! ```zig
//! const domain = @import("domain/mod.zig");
//!
//! // 使用实体模型
//! const User = domain.entities.User;
//!
//! // 使用领域服务验证业务规则
//! try domain.services.DomainServices.User.validateUsername("john_doe");
//! try domain.services.DomainServices.User.validatePassword("secure123");
//!
//! // 使用仓储接口
//! const UserRepo = domain.repositories.Repository.Interface(User);
//! ```
//!
//! ## 依赖规则
//! - 领域层仅依赖共享层（shared）
//! - 不依赖应用层、API 层或基础设施层
//! - 仓储接口在此定义，实现在基础设施层

const std = @import("std");
const logger = @import("../application/services/logger/logger.zig");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// 业务实体模型
///
/// 定义系统的核心业务对象，如用户、文章、分类等。
/// 实体包含业务属性和基本的验证逻辑。
pub const entities = @import("entities/models.zig");

/// 领域服务
///
/// 封装跨实体的业务规则和复杂逻辑。
/// 领域服务是无状态的，不依赖外部系统。
pub const services = @import("services/mod.zig");

/// 仓储接口
///
/// 定义数据访问的抽象契约，具体实现在基础设施层。
/// 使用接口隔离领域层与数据存储细节。
pub const repositories = @import("repositories/mod.zig");

// ============================================================================
// 层配置
// ============================================================================

/// 领域层配置
///
/// 控制领域层的行为，如模型验证、业务规则执行等。
pub const DomainConfig = struct {
    /// 是否验证模型数据
    validate_models: bool = true,
    /// 是否强制执行业务规则
    enforce_business_rules: bool = true,
};

// ============================================================================
// 生命周期管理
// ============================================================================

/// 初始化领域层
///
/// 在应用程序启动时调用，初始化领域层组件。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config`: 领域层配置
pub fn init(allocator: std.mem.Allocator, config: DomainConfig) !void {
    _ = allocator;
    _ = config;
    std.debug.print("✅ 领域层初始化完成\n", .{});

    // 初始化实体模型
    _ = entities;

    // 初始化领域服务
    _ = services;

    // 初始化仓库接口
    _ = repositories;
}

/// 清理领域层
///
/// 在应用程序关闭时调用，释放领域层资源。
pub fn deinit() void {
    std.debug.print("👋 领域层已清理\n", .{});
}
