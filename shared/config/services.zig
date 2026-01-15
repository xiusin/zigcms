//! 服务注册配置
//!
//! 本模块定义服务注册的配置结构，用于驱动自动服务注册。
//! 使用配置文件而非硬编码，提高系统的可扩展性和可维护性。
//!
//! ## 使用示例
//! ```zig
//! const service_config = @import("shared/config/services.zig");
//!
//! // 获取所有 CRUD 模块配置
//! const crud_modules = service_config.getCrudModules();
//! for (crud_modules) |module| {
//!     try app.crud(module.name, module.model);
//! }
//!
//! // 获取所有控制器路由配置
//! const controller_routes = service_config.getControllerRoutes();
//! for (controller_routes) |route| {
//!     try app.route(route.path, route.controller, route.handler);
//! }
//! ```

const std = @import("std");
const models = @import("../../domain/entities/models.zig");

/// CRUD 模块配置
pub const CrudModuleConfig = struct {
    /// 模块名称
    name: []const u8,
    /// 模块对应的实体类型
    model: type,
    /// 是否启用
    enabled: bool = true,
    /// 路由前缀
    prefix: []const u8 = "",
};

/// 控制器路由配置
pub const ControllerRouteConfig = struct {
    /// HTTP 路径
    path: []const u8,
    /// 控制器类型
    controller: type,
    /// 处理函数
    handler: *const fn () anyerror!void,
    /// HTTP 方法
    method: HttpMethod = .GET,
    /// 路由名称
    name: []const u8 = "",
};

/// HTTP 方法枚举
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
};

/// 服务注册配置
pub const ServiceRegistryConfig = struct {
    const Self = @This();

    /// CRUD 模块列表
    crud_modules: []const CrudModuleConfig = &.{},
    /// 控制器路由列表
    controller_routes: []const ControllerRouteConfig = &.{},
    /// 服务依赖配置
    dependencies: []const ServiceDependency = &.{},
};

/// 服务依赖配置
pub const ServiceDependency = struct {
    service: type,
    dependencies: []const type = &.{},
};

/// 获取默认的 CRUD 模块配置
pub fn getDefaultCrudModules() []const CrudModuleConfig {
    return &.{
        // 基础模块
        .{ .name = "category", .model = models.Category },
        .{ .name = "upload", .model = models.Upload },
        .{ .name = "article", .model = models.Article },
        .{ .name = "role", .model = models.Role },
        .{ .name = "dict", .model = models.Dict },
        // CMS 内容管理模块
        .{ .name = "cms_model", .model = models.CmsModel },
        .{ .name = "cms_field", .model = models.CmsField },
        .{ .name = "document", .model = models.Document },
        .{ .name = "material_category", .model = models.MaterialCategory },
        .{ .name = "material", .model = models.Material },
        // 会员管理模块
        .{ .name = "member_group", .model = models.MemberGroup },
        .{ .name = "member", .model = models.Member },
        // 友链管理模块
        .{ .name = "friend_link", .model = models.FriendLink },
    };
}

/// 创建服务注册配置
pub fn createServiceRegistryConfig(allocator: std.mem.Allocator) ServiceRegistryConfig {
    _ = allocator;
    return .{
        .crud_modules = getDefaultCrudModules(),
        .controller_routes = &.{},
        .dependencies = &.{},
    };
}

/// 启用/禁用 CRUD 模块
pub fn setCrudModuleEnabled(config: *ServiceRegistryConfig, name: []const u8, enabled: bool) void {
    _ = config;
    _ = name;
    _ = enabled;
    // TODO: 实现动态修改模块启用状态
}

/// 获取启用的 CRUD 模块数量
pub fn getEnabledCrudModuleCount(config: *const ServiceRegistryConfig) usize {
    var count: usize = 0;
    for (config.crud_modules) |module| {
        if (module.enabled) count += 1;
    }
    return count;
}
