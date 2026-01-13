//! 依赖注入模块入口 - 极致内存管理版
//!
//! 本模块使用双分配器策略确保内存零泄漏：
//! 1. 系统级 Arena：管理所有服务单例、容器和注册表的生命周期。
//! 2. GPA：传递给服务用于处理运行时临时业务。
//!
//! //! ## 使用示例
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
pub const container = @import("./container.zig");
pub const service_registry = @import("./service_registry.zig");

pub const DIContainer = container.DIContainer;
pub const ServiceRegistry = service_registry.ServiceRegistry;
pub const ServiceLifetime = container.ServiceLifetime;

/// 全局DI资源管理器
var di_arena: ?std.heap.ArenaAllocator = null;
var global_container: ?*DIContainer = null;
var global_registry: ?*ServiceRegistry = null;
var di_mutex = std.Thread.Mutex{};

/// 初始化全局DI系统
pub fn initGlobalDISystem(allocator: std.mem.Allocator) !void {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (di_arena != null) return;

    // 创建 Arena，专门托管 DI 相关的持久内存
    di_arena = std.heap.ArenaAllocator.init(allocator);
    const arena_allocator = di_arena.?.allocator();

    // 所有 DI 核心组件都分配在 Arena 中
    global_container = try arena_allocator.create(DIContainer);
    global_container.?.* = DIContainer.init(arena_allocator);

    global_registry = try arena_allocator.create(ServiceRegistry);
    global_registry.?.* = service_registry.ServiceRegistry.init(arena_allocator);

    std.debug.print("全局DI系统已启动 (Arena 托管模式)\n", .{});
}

/// 获取全局容器
pub fn getGlobalContainer() ?*DIContainer {
    di_mutex.lock();
    defer di_mutex.unlock();
    return global_container;
}

/// 获取全局注册表
pub fn getGlobalRegistry() ?*ServiceRegistry {
    di_mutex.lock();
    defer di_mutex.unlock();
    return global_registry;
}

/// 清理全局 DI 系统
pub fn deinitGlobalDISystem() void {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (di_arena) |*arena| {
        // 这一步是核武器：直接释放 Arena 块。
        // 它会瞬间销毁容器、注册表以及所有在里面分配的服务实例。
        // 由于这些服务是单例且随程序结束而销毁，这是最安全的做法。
        arena.deinit();
        di_arena = null;
        global_container = null;
        global_registry = null;
    }
    std.debug.print("全局DI系统已清理 (Arena 持久内存已安全回收)\n", .{});
}

/// 便捷函数：注册服务
pub fn registerService(comptime ServiceType: type, comptime ImplementationType: type, factory: anytype, lifetime: ServiceLifetime) !void {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (global_container) |c| {
        switch (lifetime) {
            .Singleton => try c.registerSingleton(ServiceType, ImplementationType, factory),
            .Transient => try c.registerTransient(ServiceType, ImplementationType, factory),
        }
    }
}

/// 解析服务
pub fn resolveService(comptime ServiceType: type) !*ServiceType {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (global_container) |c| return c.resolve(ServiceType);
    return error.DIContainerNotInitialized;
}
