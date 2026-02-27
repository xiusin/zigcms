//! 依赖注入模块 (Dependency Injection Module)
//!
//! 提供统一的依赖注入容器，合并了原 shared/di 和 shared/primitives/container 的功能。
//! 使用双分配器策略确保内存零泄漏。
//!
//! ## 使用示例
//! ```zig
//! const di = @import("core/di/mod.zig");
//!
//! // 初始化全局容器
//! try di.initGlobalDISystem(allocator);
//! defer di.deinitGlobalDISystem();
//!
//! // 注册服务
//! try di.registerService(UserService, SqliteUserRepository, createUserService, .Singleton);
//!
//! // 解析服务
//! const user_service = try di.resolveService(UserService);
//! ```

const std = @import("std");
pub const container = @import("container.zig");

pub const DIContainer = container.DIContainer;
pub const ServiceLifetime = container.ServiceLifetime;

/// 全局 DI 资源管理器
var di_arena: ?std.heap.ArenaAllocator = null;
var global_container: ?*DIContainer = null;
var di_mutex = std.Thread.Mutex{};

/// 初始化全局 DI 系统
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

    std.debug.print("全局 DI 系统已启动 (Arena 托管模式)\n", .{});
}

/// 获取全局容器
pub fn getGlobalContainer() ?*DIContainer {
    di_mutex.lock();
    defer di_mutex.unlock();
    return global_container;
}

/// 清理全局 DI 系统
pub fn deinitGlobalDISystem() void {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (di_arena) |*arena| {
        if (global_container) |container_ptr| {
            container_ptr.deinit();
        }

        // Arena 回收所有内存
        arena.deinit();
        di_arena = null;
        global_container = null;
    }
    std.debug.print("全局 DI 系统已清理\n", .{});
}

/// 注册服务
pub fn registerService(comptime ServiceType: type, comptime ImplementationType: type, factory: anytype, lifetime: ServiceLifetime) !void {
    di_mutex.lock();
    defer di_mutex.unlock();

    if (global_container) |c| {
        switch (lifetime) {
            .Singleton => try c.registerSingleton(ServiceType, ImplementationType, factory, null),
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
