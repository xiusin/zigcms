const std = @import("std");
const testing = std.testing;
const ConfigLoaderV2 = @import("../shared/config/config_loader_v2.zig").ConfigLoaderV2;
const SystemConfig = @import("../shared/config/system_config.zig").SystemConfig;

test "ConfigLoaderV2 - 加载默认配置" {
    const allocator = testing.allocator;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var loader = ConfigLoaderV2.init(allocator, config_path);
    defer loader.deinit();

    const config = try loader.loadAll();

    try testing.expectEqualStrings("127.0.0.1", config.api.host);
    try testing.expectEqual(@as(u16, 3000), config.api.port);
    try testing.expectEqualStrings("localhost", config.infra.db_host);
    try testing.expectEqual(@as(u16, 5432), config.infra.db_port);
}

test "ConfigLoaderV2 - 从 JSON 文件加载" {
    const allocator = testing.allocator;

    const api_json =
        \\{
        \\  "host": "0.0.0.0",
        \\  "port": 8080,
        \\  "max_clients": 5000,
        \\  "timeout": 60,
        \\  "public_folder": "public"
        \\}
    ;

    const infra_json =
        \\{
        \\  "db_host": "db.example.com",
        \\  "db_port": 3306,
        \\  "db_name": "testdb",
        \\  "db_user": "testuser",
        \\  "db_password": "testpass",
        \\  "db_pool_size": 20,
        \\  "cache_enabled": true,
        \\  "cache_host": "redis.example.com",
        \\  "cache_port": 6380,
        \\  "cache_ttl": 7200,
        \\  "http_timeout_ms": 10000,
        \\  "http_max_redirects": 10
        \\}
    ;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var api_file = try temp_dir.dir.createFile("api.json", .{});
    defer api_file.close();
    try api_file.writeAll(api_json);

    var infra_file = try temp_dir.dir.createFile("infra.json", .{});
    defer infra_file.close();
    try infra_file.writeAll(infra_json);

    var loader = ConfigLoaderV2.init(allocator, config_path);
    defer loader.deinit();

    const config = try loader.loadAll();

    try testing.expectEqualStrings("0.0.0.0", config.api.host);
    try testing.expectEqual(@as(u16, 8080), config.api.port);
    try testing.expectEqual(@as(u32, 5000), config.api.max_clients);

    try testing.expectEqualStrings("db.example.com", config.infra.db_host);
    try testing.expectEqual(@as(u16, 3306), config.infra.db_port);
    try testing.expectEqualStrings("testdb", config.infra.db_name);
    try testing.expectEqualStrings("testuser", config.infra.db_user);
    try testing.expectEqualStrings("testpass", config.infra.db_password);
    try testing.expectEqual(@as(u32, 20), config.infra.db_pool_size);
}

test "ConfigLoaderV2 - 环境变量覆盖" {
    const allocator = testing.allocator;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    try std.posix.setenv("ZIGCMS_API_HOST", "env.example.com", 1);
    defer std.posix.unsetenv("ZIGCMS_API_HOST");

    try std.posix.setenv("ZIGCMS_API_PORT", "9000", 1);
    defer std.posix.unsetenv("ZIGCMS_API_PORT");

    try std.posix.setenv("ZIGCMS_DB_HOST", "db.env.com", 1);
    defer std.posix.unsetenv("ZIGCMS_DB_HOST");

    try std.posix.setenv("ZIGCMS_DB_PORT", "5433", 1);
    defer std.posix.unsetenv("ZIGCMS_DB_PORT");

    var loader = ConfigLoaderV2.init(allocator, config_path);
    defer loader.deinit();

    const config = try loader.loadAll();

    try testing.expectEqualStrings("env.example.com", config.api.host);
    try testing.expectEqual(@as(u16, 9000), config.api.port);
    try testing.expectEqualStrings("db.env.com", config.infra.db_host);
    try testing.expectEqual(@as(u16, 5433), config.infra.db_port);
}

test "ConfigLoaderV2 - 配置验证通过" {
    const allocator = testing.allocator;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var loader = ConfigLoaderV2.init(allocator, config_path);
    defer loader.deinit();

    const config = try loader.loadAll();

    try loader.validate(&config);
}

test "ConfigLoaderV2 - 配置验证失败 (端口为 0)" {
    const allocator = testing.allocator;

    var loader = ConfigLoaderV2.init(allocator, ".");
    defer loader.deinit();

    var config = SystemConfig{};
    config.api.port = 0;

    const result = loader.validate(&config);
    try testing.expectError(error.InvalidValue, result);
}

test "ConfigLoaderV2 - 配置验证失败 (缺少数据库配置)" {
    const allocator = testing.allocator;

    var loader = ConfigLoaderV2.init(allocator, ".");
    defer loader.deinit();

    var config = SystemConfig{};
    config.infra.db_host = "";

    const result = loader.validate(&config);
    try testing.expectError(error.MissingRequiredField, result);
}
