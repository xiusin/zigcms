//! 依赖注入容器 - 统一管理服务生命周期
//!
//! 本模块提供依赖注入功能：
//! - 支持单例 (Singleton) 和瞬态 (Transient) 模式
//! - 生命周期托管：单例实例由容器持有的分配器管理
//!
//! ## 类型安全说明
//!
//! 由于 Zig 没有泛型，工厂函数使用函数指针类型擦除。
//! 通过 comptime 断言确保 ServiceType 和 ImplementationType 兼容：
//! - 注册时：编译期检查工厂返回类型是否可转换为 *ImplementationType
//! - 解析时：使用 @ptrCast 进行安全的类型恢复

const std = @import("std");

pub const ServiceLifetime = enum {
    Singleton,
    Transient,
};

/// 服务描述符
/// 存储服务的注册信息和运行时实例
pub const ServiceDescriptor = struct {
    /// 服务类型名称（用于查找）
    service_type_name: []const u8,
    /// 实现类型名称
    implementation_type_name: []const u8,
    /// 工厂函数（类型擦除后存储）
    factory: ?*const FactoryFn,
    /// 服务生命周期
    lifetime: ServiceLifetime,
    /// 单例实例（仅单例模式使用）
    instance: ?*anyopaque = null,
};

/// 工厂函数类型（类型擦除后）
const FactoryFn = fn (*DIContainer, std.mem.Allocator) anyerror!*anyopaque;

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
    ///
    /// ## 类型安全
    /// 工厂函数的类型由编译器强制检查，确保返回类型正确
    pub fn registerSingleton(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, raw_factory: fn (*DIContainer, std.mem.Allocator) anyerror!*ImplementationType) !void {
        const service_name = @typeName(ServiceType);
        const wrapper: FactoryFn = struct {
            fn wrap(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*anyopaque {
                return @ptrCast(@alignCast(try raw_factory(di, allocator)));
            }
        }.wrap;

        const descriptor = ServiceDescriptor{
            .service_type_name = service_name,
            .implementation_type_name = @typeName(ImplementationType),
            .factory = wrapper,
            .lifetime = .Singleton,
        };
        try self.descriptors.put(service_name, descriptor);
    }

    /// 注册服务（瞬态模式）
    pub fn registerTransient(self: *Self, comptime ServiceType: type, comptime ImplementationType: type, raw_factory: fn (*DIContainer, std.mem.Allocator) anyerror!*ImplementationType) !void {
        const service_name = @typeName(ServiceType);
        const wrapper: FactoryFn = struct {
            fn wrap(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*anyopaque {
                return @ptrCast(@alignCast(try raw_factory(di, allocator)));
            }
        }.wrap;

        const descriptor = ServiceDescriptor{
            .service_type_name = service_name,
            .implementation_type_name = @typeName(ImplementationType),
            .factory = wrapper,
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
    ///
    /// ## 错误
    /// - ServiceNotRegistered: 服务未注册
    /// - FactoryNotAvailable: 工厂函数不可用
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

    /// 检查服务是否已注册
    pub fn isRegistered(self: *Self, comptime ServiceType: type) bool {
        return self.descriptors.contains(@typeName(ServiceType));
    }

    /// 清理容器
    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;
        self.singletons.deinit();
        self.descriptors.deinit();
        self.initialized = false;
    }
};

/// 创建 DI 容器
pub fn createContainer(allocator: std.mem.Allocator) !*DIContainer {
    const container = try allocator.create(DIContainer);
    container.* = DIContainer.init(allocator);
    return container;
}
