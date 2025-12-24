//! 依赖注入容器 - 统一管理服务生命周期
//!
//! 本模块提供完整的依赖注入功能：
//! - 类型安全的服务注册和解析
//! - 服务生命周期管理
//! - 单例和瞬态服务支持
//! - 依赖关系验证

const std = @import("std");

pub const ServiceLifetime = enum {
    Singleton,
    Transient,
};

pub const ServiceDescriptor = struct {
    service_type_name: []const u8,
    implementation_type_name: []const u8,
    factory: ?*const fn (std.mem.Allocator) anyerror!*anyopaque,
    lifetime: ServiceLifetime,
    instance: ?*anyopaque = null,
};

pub const DIContainer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    descriptors: std.StringHashMap(ServiceDescriptor),
    singletons: std.StringHashMap(*anyopaque),
    initialized: bool = false,

    /// 初始化DI容器
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .descriptors = std.StringHashMap(ServiceDescriptor).init(allocator),
            .singletons = std.StringHashMap(*anyopaque).init(allocator),
            .initialized = true,
        };
    }

    /// 注册服务（单例模式）
    pub fn registerSingleton(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, factory: fn (std.mem.Allocator) anyerror!*ImplementationType) !void {
        const service_name = @typeName(ServiceType);

        const descriptor = ServiceDescriptor{
            .service_type_name = service_name,
            .implementation_type_name = @typeName(ImplementationType),
            .factory = @ptrCast(&factory),
            .lifetime = .Singleton,
        };

        try self.descriptors.put(service_name, descriptor);
    }

    /// 注册服务（瞬态模式）
    pub fn registerTransient(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, factory: fn (std.mem.Allocator) anyerror!*ImplementationType) !void {
        const service_name = @typeName(ServiceType);

        const descriptor = ServiceDescriptor{
            .service_type_name = service_name,
            .implementation_type_name = @typeName(ImplementationType),
            .factory = @ptrCast(&factory),
            .lifetime = .Transient,
        };

        try self.descriptors.put(service_name, descriptor);
    }

    /// 注册已存在的实例（单例）
    pub fn registerInstance(self: *Self, comptime ServiceType: type, instance: *ServiceType) !void {
        const service_name = @typeName(ServiceType);

        try self.singletons.put(service_name, @ptrCast(instance));

        // 同时创建描述符以便统一管理
        const descriptor = ServiceDescriptor{
            .service_type_name = service_name,
            .implementation_type_name = service_name,
            .factory = null,
            .lifetime = .Singleton,
            .instance = @ptrCast(instance),
        };

        try self.descriptors.put(service_name, descriptor);
    }

    /// 解析服务
    pub fn resolve(self: *Self, comptime ServiceType: type) !*ServiceType {
        const service_name = @typeName(ServiceType);

        // 首先检查单例缓存
        if (self.singletons.get(service_name)) |instance| {
            return @ptrCast(@alignCast(instance));
        }

        // 检查描述符
        const descriptor = self.descriptors.get(service_name) orelse
            return error.ServiceNotRegistered;

        return switch (descriptor.lifetime) {
            .Singleton => self.resolveSingleton(ServiceType, descriptor),
            .Transient => self.resolveTransient(ServiceType, descriptor),
        };
    }

    /// 解析单例服务
    fn resolveSingleton(self: *Self, comptime ServiceType: type, descriptor: ServiceDescriptor) !*ServiceType {
        const service_name = @typeName(ServiceType);

        // 已经有实例直接返回
        if (descriptor.instance) |instance| {
            return @ptrCast(@alignCast(instance));
        }

        // 创建新实例
        if (descriptor.factory) |factory| {
            const instance = try factory(self.allocator);
            const typed_instance: *ServiceType = @ptrCast(@alignCast(instance));

            // 缓存单例
            try self.singletons.put(service_name, instance);

            // 更新描述符
            var updated_descriptor = descriptor;
            updated_descriptor.instance = instance;
            try self.descriptors.put(service_name, updated_descriptor);

            return typed_instance;
        } else {
            return error.FactoryNotAvailable;
        }
    }

    /// 解析瞬态服务
    fn resolveTransient(self: *Self, comptime ServiceType: type, descriptor: ServiceDescriptor) !*ServiceType {
        if (descriptor.factory) |factory| {
            const instance = try factory(self.allocator);
            return @ptrCast(@alignCast(instance));
        } else {
            return error.FactoryNotAvailable;
        }
    }

    /// 检查服务是否已注册
    pub fn isRegistered(self: *Self, comptime ServiceType: type) bool {
        const service_name = @typeName(ServiceType);
        return self.descriptors.contains(service_name);
    }

    /// 获取所有已注册的服务名称
    pub fn getRegisteredServices(self: *Self, allocator: std.mem.Allocator) ![][]const u8 {
        var services = std.ArrayList([]const u8).init(allocator);
        defer services.deinit();

        var it = self.descriptors.iterator();
        while (it.next()) |entry| {
            try services.append(entry.key_ptr.*);
        }

        return services.toOwnedSlice();
    }

    /// 验证依赖关系
    pub fn validateDependencies(self: *Self) !void {
        var it = self.descriptors.iterator();
        while (it.next()) |entry| {
            // 这里可以添加更复杂的依赖验证逻辑
            // 调试日志: 验证服务
            std.debug.print("验证服务: {s}\n", .{entry.key_ptr.*});
        }
    }

    /// 获取服务统计信息
    pub fn getStats(self: *Self) struct {
        total_services: usize,
        singleton_count: usize,
        transient_count: usize,
    } {
        var singleton_count: usize = 0;
        var transient_count: usize = 0;

        var it = self.descriptors.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*.lifetime) {
                .Singleton => singleton_count += 1,
                .Transient => transient_count += 1,
            }
        }

        return .{
            .total_services = singleton_count + transient_count,
            .singleton_count = singleton_count,
            .transient_count = transient_count,
        };
    }

    /// 清理容器资源
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        // 注意：单例实例不由容器负责销毁，由应用层管理
        // 这里只清理容器的内部数据结构

        self.singletons.deinit();
        self.descriptors.deinit();
        self.initialized = false;
    }
};

/// 便捷函数：创建DI容器
pub fn createContainer(allocator: std.mem.Allocator) !*DIContainer {
    const container = try allocator.create(DIContainer);
    container.* = DIContainer.init(allocator);
    return container;
}
