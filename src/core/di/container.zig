//! DI 容器实现 (DI Container Implementation)
//!
//! 提供服务的注册和解析功能，支持单例和瞬态生命周期。
//! 合并了原 shared/di/container.zig 的实现。

const std = @import("std");

/// 服务生命周期
pub const ServiceLifetime = enum {
    Singleton,
    Transient,
};

/// DI 容器
pub const DIContainer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    singletons: std.StringHashMap(*anyopaque),
    factories: std.StringHashMap(FactoryEntry),

    const FactoryEntry = struct {
        factory: *const anyopaque,
        lifetime: ServiceLifetime,
    };

    /// 初始化容器
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .singletons = std.StringHashMap(*anyopaque).init(allocator),
            .factories = std.StringHashMap(FactoryEntry).init(allocator),
        };
    }

    /// 销毁容器
    pub fn deinit(self: *Self) void {
        self.singletons.deinit();
        self.factories.deinit();
    }

    /// 注册单例服务
    pub fn registerSingleton(
        self: *Self,
        comptime ServiceType: type,
        comptime _: type,
        factory: anytype,
        _: ?*anyopaque,
    ) !void {
        const type_name = @typeName(ServiceType);
        try self.factories.put(type_name, .{
            .factory = @ptrCast(&factory),
            .lifetime = .Singleton,
        });
    }

    /// 注册瞬态服务
    pub fn registerTransient(
        self: *Self,
        comptime ServiceType: type,
        comptime _: type,
        factory: anytype,
    ) !void {
        const type_name = @typeName(ServiceType);
        try self.factories.put(type_name, .{
            .factory = @ptrCast(&factory),
            .lifetime = .Transient,
        });
    }

    /// 注册实例
    pub fn registerInstance(
        self: *Self,
        comptime ServiceType: type,
        instance: *ServiceType,
        _: ?*anyopaque,
    ) !void {
        const type_name = @typeName(ServiceType);
        try self.singletons.put(type_name, @ptrCast(instance));
    }

    /// 检查服务是否已注册
    pub fn isRegistered(self: *Self, comptime ServiceType: type) bool {
        const type_name = @typeName(ServiceType);
        return self.singletons.contains(type_name) or self.factories.contains(type_name);
    }

    /// 解析服务
    pub fn resolve(self: *Self, comptime ServiceType: type) !*ServiceType {
        const type_name = @typeName(ServiceType);

        // 先检查是否有已注册的实例
        if (self.singletons.get(type_name)) |ptr| {
            return @ptrCast(@alignCast(ptr));
        }

        // 检查是否有工厂
        if (self.factories.get(type_name)) |entry| {
            const FactoryFn = *const fn (*Self, std.mem.Allocator) anyerror!*ServiceType;
            const factory: FactoryFn = @ptrCast(@alignCast(entry.factory));
            const instance = try factory(self, self.allocator);

            if (entry.lifetime == .Singleton) {
                try self.singletons.put(type_name, @ptrCast(instance));
            }

            return instance;
        }

        return error.ServiceNotRegistered;
    }
};
