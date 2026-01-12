const std = @import("std");
const ConfigLoaderV2 = @import("../shared/config/config_loader_v2.zig").ConfigLoaderV2;
const AutoConfigLoader = @import("../shared/config/auto_loader.zig").AutoConfigLoader;

const CustomConfig = struct {
    app_name: []const u8 = "MyApp",
    version: []const u8 = "1.0.0",
    port: u16 = 3000,
    debug: bool = false,
    max_connections: u32 = 1000,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== 配置自动化加载示例 ===\n\n", .{});

    std.debug.print("1. 使用 ConfigLoaderV2 加载系统配置:\n", .{});
    {
        var loader = ConfigLoaderV2.init(allocator, "configs");
        defer loader.deinit();

        const config = try loader.loadAll();

        std.debug.print("   API 配置:\n", .{});
        std.debug.print("     - Host: {s}\n", .{config.api.host});
        std.debug.print("     - Port: {d}\n", .{config.api.port});
        std.debug.print("     - Max Clients: {d}\n", .{config.api.max_clients});

        std.debug.print("   数据库配置:\n", .{});
        std.debug.print("     - Host: {s}\n", .{config.infra.db_host});
        std.debug.print("     - Port: {d}\n", .{config.infra.db_port});
        std.debug.print("     - Database: {s}\n", .{config.infra.db_name});
        std.debug.print("     - User: {s}\n", .{config.infra.db_user});

        try loader.validate(&config);
        std.debug.print("   ✓ 配置验证通过\n", .{});
    }

    std.debug.print("\n2. 使用 AutoConfigLoader 加载自定义配置:\n", .{});
    {
        var auto_loader = AutoConfigLoader.init(allocator, ".");
        defer auto_loader.deinit();

        const config = auto_loader.loadConfigOr(CustomConfig, "custom.json", .{
            .app_name = "DefaultApp",
            .version = "0.0.1",
            .port = 8080,
            .debug = true,
            .max_connections = 500,
        });

        std.debug.print("   应用配置:\n", .{});
        std.debug.print("     - App Name: {s}\n", .{config.app_name});
        std.debug.print("     - Version: {s}\n", .{config.version});
        std.debug.print("     - Port: {d}\n", .{config.port});
        std.debug.print("     - Debug: {}\n", .{config.debug});
        std.debug.print("     - Max Connections: {d}\n", .{config.max_connections});
    }

    std.debug.print("\n3. 环境变量覆盖示例:\n", .{});
    {
        try std.posix.setenv("CUSTOM_PORT", "9000", 1);
        defer std.posix.unsetenv("CUSTOM_PORT");

        try std.posix.setenv("CUSTOM_DEBUG", "true", 1);
        defer std.posix.unsetenv("CUSTOM_DEBUG");

        var auto_loader = AutoConfigLoader.init(allocator, ".");
        defer auto_loader.deinit();

        var config = CustomConfig{};

        try auto_loader.applyEnvOverrides(CustomConfig, &config, &.{
            .{ .field = "port", .env = "CUSTOM_PORT" },
            .{ .field = "debug", .env = "CUSTOM_DEBUG" },
        });

        std.debug.print("   覆盖后的配置:\n", .{});
        std.debug.print("     - Port: {d} (从环境变量)\n", .{config.port});
        std.debug.print("     - Debug: {} (从环境变量)\n", .{config.debug});
    }

    std.debug.print("\n=== 配置自动化加载完成 ✓ ===\n\n", .{});
}
