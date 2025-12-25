//! 依赖注入容器 - 统一管理服务生命周期
//!
//! 本模块提供依赖注入功能：
//! - 支持单例 (Singleton) 和瞬态 (Transient) 模式
//! - 生命周期托管：单例实例由容器持有的分配器管理

const std = @import("std");

pub const ServiceLifetime = enum {
    Singleton,
    Transient,
};

pub const ServiceDescriptor = struct {
    service_type_name: []const u8,
    implementation_type_name: []const u8,
    factory: ?*const fn (*DIContainer, std.mem.Allocator) anyerror!*anyopaque,
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
    pub fn registerSingleton(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, factory: fn (*DIContainer, std.mem.Allocator) anyerror!*ImplementationType) !void {
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
    pub fn registerTransient(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, factory: fn (*DIContainer, std.mem.Allocator) anyerror!*ImplementationType) !void {
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

        if (self.singletons.get(service_name)) |instance| {
            return @ptrCast(@alignCast(instance));
        }

        const descriptor = self.descriptors.get(service_name) orelse return error.ServiceNotRegistered;

        return switch (descriptor.lifetime) {
            .Singleton => self.resolveSingleton(ServiceType, descriptor),
            .Transient => self.resolveTransient(ServiceType, descriptor),
        };
    }

    fn resolveSingleton(self: *Self, comptime ServiceType: type, descriptor: ServiceDescriptor) !*ServiceType {
        const service_name = @typeName(ServiceType);
        if (descriptor.instance) |instance| return @ptrCast(@alignCast(instance));

        if (descriptor.factory) |factory| {
            const instance = try factory(self, self.allocator);
            try self.singletons.put(service_name, instance);

            var updated = descriptor;
            updated.instance = instance;
            try self.descriptors.put(service_name, updated);

            return @ptrCast(@alignCast(instance));
        }
        return error.FactoryNotAvailable;
    }

    fn resolveTransient(self: *Self, comptime ServiceType: type, descriptor: ServiceDescriptor) !*ServiceType {
        if (descriptor.factory) |factory| {
            const instance = try factory(self, self.allocator);
            return @ptrCast(@alignCast(instance));
        }
        return error.FactoryNotAvailable;
    }

    pub fn isRegistered(self: *Self, comptime ServiceType: type) bool {
        return self.descriptors.contains(@typeName(ServiceType));
    }

    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;
        self.singletons.deinit();
        self.descriptors.deinit();
        self.initialized = false;
    }
};

pub fn createContainer(allocator: std.mem.Allocator) !*DIContainer {
    const container = try allocator.create(DIContainer);
    container.* = DIContainer.init(allocator);
    return container;
}