//! 依赖注入模块入口
//!
//! 本模块提供完整的依赖注入功能，包括：
//! - DI容器管理
//! - 服务注册表
//! - 配置集成
//!
//! ## 使用示例
//! ```zig
//! const di = @import("shared/di/mod.zig");
//!
//! // 创建全局容器
//! var container = try di.createGlobalContainer(allocator);
//!
//! // 注册服务
//! try container.registerSingleton(UserService, SqliteUserRepository, createUserService);
//!
//! // 解析服务
//! const user_service = try container.resolve(UserService);
//! ```

const std = @import("std");

// ============================================================================
// 核心模块导入
// ============================================================================

/// DI容器
pub const container = @import("./container.zig");

/// 服务注册表
pub const service_registry = @import("./service_registry.zig");

// ============================================================================
// 便捷类型导出
// ============================================================================

/// DI容器类型
pub const DIContainer = container.DIContainer;

/// 服务注册表类型
pub const ServiceRegistry = service_registry.ServiceRegistry;

/// 服务生命周期枚举
pub const ServiceLifetime = container.ServiceLifetime;

/// 服务信息结构
pub const ServiceInfo = service_registry.ServiceInfo;

// ============================================================================
// 全局容器管理
// ============================================================================

/// 全局DI容器实例
var global_container: ?*DIContainer = null;

/// 全局服务注册表实例
var global_registry: ?*ServiceRegistry = null;

/// 初始化全局DI系统
pub fn initGlobalDISystem(allocator: std.mem.Allocator) !void {
    if (global_container != null) {
        return error.GlobalContainerAlreadyInitialized;
    }

    // 创建全局容器
    global_container = try container.createContainer(allocator);

    // 创建全局注册表
    global_registry = try service_registry.createServiceRegistry(allocator);

    std.debug.print("全局DI系统初始化完成\n", .{});
}

/// 获取全局DI容器
pub fn getGlobalContainer() ?*DIContainer {
    return global_container;
}

/// 获取全局服务注册表
pub fn getGlobalRegistry() ?*ServiceRegistry {
    return global_registry;
}

/// 清理全局DI系统
pub fn deinitGlobalDISystem() void {
    if (global_registry) |registry| {
        registry.deinit();
    }

    if (global_container) |container_instance| {
        container_instance.deinit();
    }

    global_registry = null;
    global_container = null;

    std.debug.print("全局DI系统已清理\n", .{});
}

/// 便捷函数：创建并配置标准服务
pub fn createStandardContainer(allocator: std.mem.Allocator) !*DIContainer {
    const container_instance = try container.createContainer(allocator);

    // 这里可以预先注册一些标准服务
    // 例如：日志服务、配置服务等

    return container_instance;
}

/// 便捷函数：创建服务注册表并配置标准服务
pub fn createStandardRegistry(allocator: std.mem.Allocator) !*ServiceRegistry {
    const registry = try service_registry.createServiceRegistry(allocator);

    // 这里可以预先注册一些标准服务信息

    return registry;
}

/// 便捷函数：验证DI系统配置
pub fn validateDISystem() !void {
    if (global_container) |container_instance| {
        try container_instance.validateDependencies();
    }

    if (global_registry) |registry| {
        try registry.analyzeDependencies(std.heap.page_allocator);
    }
}

// ============================================================================
// 便捷宏和辅助函数
// ============================================================================

/// 便捷宏：服务注册助手
pub fn registerService(comptime ServiceType: type, comptime ImplementationType: type, factory: anytype, lifetime: ServiceLifetime) !void {
    if (global_container) |container_instance| {
        switch (lifetime) {
            .Singleton => try container_instance.registerSingleton(ServiceType, ImplementationType, factory),
            .Transient => try container_instance.registerTransient(ServiceType, ImplementationType, factory),
        }
    } else {
        return error.GlobalContainerNotInitialized;
    }
}

/// 便捷函数：解析服务（带错误处理）
pub fn resolveService(comptime ServiceType: type) !*ServiceType {
    if (global_container) |container_instance| {
        return container_instance.resolve(ServiceType);
    } else {
        return error.GlobalContainerNotInitialized;
    }
}

/// 便捷函数：安全解析服务（返回可选类型）
pub fn tryResolveService(comptime ServiceType: type) ?*ServiceType {
    if (global_container) |container_instance| {
        return container_instance.resolve(ServiceType) catch null;
    } else {
        return null;
    }
}

// ============================================================================
// 配置集成
// ============================================================================

/// 配置DI容器集成
pub const ConfigIntegration = struct {
    /// 从配置创建服务实例的工厂函数
    pub fn createServiceFromConfig(comptime ServiceType: type, allocator: std.mem.Allocator, config: anytype) !*ServiceType {
        _ = allocator;
        _ = config;
        // 实际实现需要根据配置创建服务实例
        return error.NotImplemented;
    }

    /// 配置驱动的服务注册
    pub fn registerServicesFromConfig(container_instance: *DIContainer, config: anytype) !void {
        _ = container_instance;
        _ = config;
        // 实际实现需要根据配置自动注册服务
        return error.NotImplemented;
    }
};

// ============================================================================
// 测试辅助函数
// ============================================================================

/// 为测试创建隔离的DI容器
pub fn createTestContainer(allocator: std.mem.Allocator) !*DIContainer {
    const container_instance = try container.createContainer(allocator);

    // 这里可以注册测试专用的Mock服务

    return container_instance;
}

/// 重置全局DI系统（用于测试）
pub fn resetGlobalDISystem() void {
    deinitGlobalDISystem();
    global_container = null;
    global_registry = null;
}
