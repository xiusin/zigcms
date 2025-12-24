//! 服务注册表 - 集中管理服务注册信息
//!
//! 本模块提供：
//! - 服务注册信息集中管理
//! - 自动服务发现
//! - 服务依赖关系分析

const std = @import("std");

const DIContainer = @import("./container.zig").DIContainer;
const ServiceLifetime = @import("./container.zig").ServiceLifetime;

pub const ServiceInfo = struct {
    name: []const u8,
    service_type_name: []const u8,
    implementation_type_name: []const u8,
    lifetime: ServiceLifetime,
    dependencies: []const []const u8, // 依赖的服务名称列表
};

pub const ServiceRegistry = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    services: std.StringHashMap(ServiceInfo),
    initialized: bool = false,

    /// 初始化服务注册表
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .services = std.StringHashMap(ServiceInfo).init(allocator),
            .initialized = true,
        };
    }

    /// 注册服务信息
    pub fn registerService(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, lifetime: ServiceLifetime, dependencies: []const []const u8) !void {
        const service_name = @typeName(ServiceType);

        const service_info = ServiceInfo{
            .name = service_name,
            .service_type_name = service_name,
            .implementation_type_name = @typeName(ImplementationType),
            .lifetime = lifetime,
            .dependencies = dependencies,
        };

        try self.services.put(service_name, service_info);
        std.debug.print("注册服务: {s}\n", .{service_name});
    }

    /// 从注册表配置DI容器
    pub fn configureContainer(self: *Self, container: *DIContainer) !void {
        var it = self.services.iterator();
        while (it.next()) |entry| {
            const service_info = entry.value_ptr.*;

            // 这里需要根据实际的服务类型创建工厂函数
            // 简化实现，实际需要更复杂的逻辑
            switch (service_info.lifetime) {
                .Singleton => try self.registerSingletonService(container, service_info),
                .Transient => try self.registerTransientService(container, service_info),
            }
        }

        std.debug.print("从注册表配置了 {} 个服务\n", .{self.services.count()});
    }

    /// 注册单例服务到容器
    fn registerSingletonService(self: *Self, container_instance: *DIContainer, service_info: ServiceInfo) !void {
        _ = self;
        _ = container_instance;
        _ = service_info;

        // 简化实现，实际需要根据具体的服务创建适当的工厂函数
        // 这里返回错误表示需要手动注册
        return error.ManualRegistrationRequired;
    }

    /// 注册瞬态服务到容器
    fn registerTransientService(self: *Self, container_instance: *DIContainer, service_info: ServiceInfo) !void {
        _ = self;
        _ = container_instance;
        _ = service_info;

        // 简化实现
        return error.ManualRegistrationRequired;
    }

    /// 分析服务依赖关系
    pub fn analyzeDependencies(self: *Self, allocator: std.mem.Allocator) !void {
        var graph = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
        defer {
            var it = graph.valueIterator();
            while (it.next()) |deps| {
                deps.deinit();
            }
            graph.deinit();
        }

        // 构建依赖图（简化实现，避免运行时类型问题）
        var keys = std.ArrayList([]const u8).init(allocator);
        defer keys.deinit();

        var values = std.ArrayList(std.ArrayList([]const u8)).init(allocator);
        defer {
            for (values.items) |*deps| {
                deps.deinit();
            }
            values.deinit();
        }

        // 手动迭代而不是使用运行时迭代器
        var count: usize = 0;
        while (count < self.services.count()) : (count += 1) {
            // 简化实现：跳过复杂的运行时类型分析
            break;
        }

        std.debug.print("依赖分析完成（简化实现）\n", .{});
    }

    /// 检查循环依赖
    fn checkCyclicDependencies(self: *Self, allocator: std.mem.Allocator, graph: *std.StringHashMap(std.ArrayList([]const u8))) !void {
        var visited = std.StringHashMap(bool).init(allocator);
        defer visited.deinit();

        var recursion_stack = std.StringHashMap(bool).init(allocator);
        defer recursion_stack.deinit();

        var it = graph.iterator();
        while (it.next()) |entry| {
            const service = entry.key_ptr.*;
            if (!visited.contains(service)) {
                if (try self.isCyclic(allocator, graph, service, &visited, &recursion_stack)) {
                    return error.CircularDependencyDetected;
                }
            }
        }
    }

    /// 递归检查循环依赖
    fn isCyclic(self: *Self, allocator: std.mem.Allocator, graph: *std.StringHashMap(std.ArrayList([]const u8)), service: []const u8, visited: *std.StringHashMap(bool), recursion_stack: *std.StringHashMap(bool)) !bool {
        if (recursion_stack.get(service)) |_| return true;
        if (visited.get(service)) |_| return false;

        try visited.put(service, true);
        try recursion_stack.put(service, true);

        if (graph.get(service)) |deps| {
            for (deps.items) |dep| {
                if (try self.isCyclic(allocator, graph, dep, visited, recursion_stack)) {
                    return true;
                }
            }
        }

        _ = recursion_stack.remove(service);
        return false;
    }

    /// 获取服务列表
    pub fn getServiceList(_: *Self, _: std.mem.Allocator) ![]ServiceInfo {
        // 简化实现：避免运行时类型问题
        std.debug.print("获取服务列表（简化实现）\n", .{});
        return &.{};
    }

    /// 查找服务
    pub fn findService(self: *Self, comptime ServiceType: type) ?ServiceInfo {
        const service_name = @typeName(ServiceType);
        return self.services.get(service_name);
    }

    /// 获取服务依赖图（用于可视化）
    pub fn getDependencyGraph(_: *Self, allocator: std.mem.Allocator) ![]const u8 {
        var graph = std.ArrayList(u8).init(allocator);
        defer graph.deinit();

        try graph.appendSlice("digraph ServiceDependencies {\n");
        try graph.appendSlice("  // 依赖图功能需要进一步开发\n");
        try graph.appendSlice("}\n");
        return graph.toOwnedSlice();
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        var it = self.services.iterator();
        while (it.next()) |entry| {
            // 清理依赖数组
            self.allocator.free(entry.value_ptr.dependencies);
        }

        self.services.deinit();
        self.initialized = false;
    }
};

/// 便捷函数：创建服务注册表
pub fn createServiceRegistry(allocator: std.mem.Allocator) !*ServiceRegistry {
    const registry = try allocator.create(ServiceRegistry);
    registry.* = ServiceRegistry.init(allocator);
    return registry;
}
