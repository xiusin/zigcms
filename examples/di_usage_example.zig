//! DI系统使用示例
//!
//! 展示如何使用新的依赖注入系统来管理和使用服务

const std = @import("std");
const zigcms = @import("../root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== ZigCMS DI系统使用示例 ===\n", .{});

    // 1. 初始化系统
    std.debug.print("1. 初始化系统...\n", .{});
    try zigcms.initSystem(allocator, .{
        .api = .{ .port = 8080 },
        .app = .{ .enable_cache = true },
        .infra = .{
            .db_host = "localhost",
            .db_port = 5432,
            .db_name = "zigcms",
            .db_user = "postgres",
            .db_password = "password",
        },
    });
    defer zigcms.deinitSystem();

    // 2. 使用全局DI容器获取服务
    std.debug.print("2. 使用DI容器获取服务...\n", .{});
    const di = zigcms.shared.di;

    // 2.1 解析用户服务
    if (di.tryResolveService(zigcms.UserService)) |user_service| {
        std.debug.print("✅ 成功获取用户服务\n", .{});
        // 这里可以调用 user_service 的方法
    } else {
        std.debug.print("❌ 无法获取用户服务\n", .{});
    }

    // 2.2 解析会员服务
    if (di.tryResolveService(zigcms.MemberService)) |member_service| {
        std.debug.print("✅ 成功获取会员服务\n", .{});
        // 这里可以调用 member_service 的方法
    } else {
        std.debug.print("❌ 无法获取会员服务\n", .{});
    }

    // 2.3 解析分类服务
    if (di.tryResolveService(zigcms.CategoryService)) |category_service| {
        std.debug.print("✅ 成功获取分类服务\n", .{});
        // 这里可以调用 category_service 的方法
    } else {
        std.debug.print("❌ 无法获取分类服务\n", .{});
    }

    // 3. 获取服务统计信息
    std.debug.print("3. 获取服务统计信息...\n", .{});
    if (di.getGlobalContainer()) |container| {
        const stats = container.getStats();
        std.debug.print("DI容器统计: 共 {} 个服务 ({} 个单例, {} 个瞬态)\n", .{
            stats.total_services,
            stats.singleton_count,
            stats.transient_count,
        });
    }

    // 4. 验证依赖关系
    std.debug.print("4. 验证依赖关系...\n", .{});
    if (di.getGlobalRegistry()) |registry| {
        if (registry.analyzeDependencies(allocator)) {
            std.debug.print("✅ 依赖关系验证通过\n", .{});
        } else |err| {
            std.debug.print("❌ 依赖关系验证失败: {}\n", .{err});
        }
    }

    // 5. 演示配置管理器使用
    std.debug.print("5. 配置管理器演示...\n", .{});
    const config_manager = try zigcms.shared.config.config_manager.createConfigManager(allocator, "configs");
    defer config_manager.deinit();

    const current_config = config_manager.getConfig();
    std.debug.print("当前API配置: 端口 {}, 最大客户端 {}\n", .{
        current_config.api.port,
        current_config.api.max_clients,
    });

    std.debug.print("=== 示例执行完成 ===\n", .{});
}

// 测试用例
test "DI系统基本功能" {
    const di = zigcms.shared.di;

    // 测试全局容器是否可用
    try std.testing.expect(di.getGlobalContainer() != null);

    // 测试服务注册表是否可用
    try std.testing.expect(di.getGlobalRegistry() != null);
}

test "配置管理器功能" {
    const config = zigcms.shared.config;
    
    // 测试配置加载器创建
    var loader = try config.ConfigLoader.init(std.testing.allocator, "configs");
    defer loader.deinit();

    const sys_config = try loader.loadAll();
    try std.testing.expect(sys_config.api.port > 0);
}