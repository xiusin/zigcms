const std = @import("std");
const testing = std.testing;
const AutoConfigLoader = @import("../shared/config/auto_loader.zig").AutoConfigLoader;

const TestConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    max_connections: u32 = 100,
    enabled: bool = true,
    optional_value: ?[]const u8 = null,
};

test "AutoConfigLoader - 泛型配置加载" {
    const allocator = testing.allocator;

    const config_json =
        \\{
        \\  "host": "0.0.0.0",
        \\  "port": 3000,
        \\  "max_connections": 500,
        \\  "enabled": true,
        \\  "optional_value": "test"
        \\}
    ;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var file = try temp_dir.dir.createFile("test.json", .{});
    defer file.close();
    try file.writeAll(config_json);

    var loader = AutoConfigLoader.init(allocator, config_path);
    defer loader.deinit();

    const config = try loader.loadConfig(TestConfig, "test.json");

    try testing.expectEqualStrings("0.0.0.0", config.host);
    try testing.expectEqual(@as(u16, 3000), config.port);
    try testing.expectEqual(@as(u32, 500), config.max_connections);
    try testing.expect(config.enabled);
    try testing.expect(config.optional_value != null);
    if (config.optional_value) |val| {
        try testing.expectEqualStrings("test", val);
    }
}

test "AutoConfigLoader - loadConfigOr 默认值" {
    const allocator = testing.allocator;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var loader = AutoConfigLoader.init(allocator, config_path);
    defer loader.deinit();

    const config = loader.loadConfigOr(TestConfig, "nonexistent.json", .{
        .host = "default_host",
        .port = 9999,
        .max_connections = 200,
        .enabled = false,
    });

    try testing.expectEqualStrings("default_host", config.host);
    try testing.expectEqual(@as(u16, 9999), config.port);
    try testing.expectEqual(@as(u32, 200), config.max_connections);
    try testing.expect(!config.enabled);
}

test "AutoConfigLoader - 环境变量覆盖 (字符串)" {
    const allocator = testing.allocator;

    var loader = AutoConfigLoader.init(allocator, ".");
    defer loader.deinit();

    var config = TestConfig{};

    try std.posix.setenv("TEST_HOST", "env_host", 1);
    defer std.posix.unsetenv("TEST_HOST");

    try loader.applyEnvOverride(TestConfig, &config, "host", "TEST_HOST");

    try testing.expectEqualStrings("env_host", config.host);
}

test "AutoConfigLoader - 环境变量覆盖 (数字)" {
    const allocator = testing.allocator;

    var loader = AutoConfigLoader.init(allocator, ".");
    defer loader.deinit();

    var config = TestConfig{};

    try std.posix.setenv("TEST_PORT", "5000", 1);
    defer std.posix.unsetenv("TEST_PORT");

    try loader.applyEnvOverride(TestConfig, &config, "port", "TEST_PORT");

    try testing.expectEqual(@as(u16, 5000), config.port);
}

test "AutoConfigLoader - 环境变量覆盖 (布尔)" {
    const allocator = testing.allocator;

    var loader = AutoConfigLoader.init(allocator, ".");
    defer loader.deinit();

    var config = TestConfig{ .enabled = false };

    try std.posix.setenv("TEST_ENABLED", "true", 1);
    defer std.posix.unsetenv("TEST_ENABLED");

    try loader.applyEnvOverride(TestConfig, &config, "enabled", "TEST_ENABLED");

    try testing.expect(config.enabled);

    config.enabled = false;
    try std.posix.setenv("TEST_ENABLED", "1", 1);
    try loader.applyEnvOverride(TestConfig, &config, "enabled", "TEST_ENABLED");

    try testing.expect(config.enabled);
}

test "AutoConfigLoader - 批量环境变量覆盖" {
    const allocator = testing.allocator;

    var loader = AutoConfigLoader.init(allocator, ".");
    defer loader.deinit();

    var config = TestConfig{};

    try std.posix.setenv("TEST_HOST", "batch_host", 1);
    defer std.posix.unsetenv("TEST_HOST");

    try std.posix.setenv("TEST_PORT", "6000", 1);
    defer std.posix.unsetenv("TEST_PORT");

    try loader.applyEnvOverrides(TestConfig, &config, &.{
        .{ .field = "host", .env = "TEST_HOST" },
        .{ .field = "port", .env = "TEST_PORT" },
    });

    try testing.expectEqualStrings("batch_host", config.host);
    try testing.expectEqual(@as(u16, 6000), config.port);
}

test "AutoConfigLoader - 字符串内存管理" {
    const allocator = testing.allocator;

    const config_json =
        \\{
        \\  "host": "test_host_1",
        \\  "port": 3000,
        \\  "max_connections": 100,
        \\  "enabled": true
        \\}
    ;

    const temp_dir = testing.tmpDir(.{});
    defer temp_dir.cleanup();

    const config_path = try temp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(config_path);

    var file = try temp_dir.dir.createFile("test.json", .{});
    defer file.close();
    try file.writeAll(config_json);

    var loader = AutoConfigLoader.init(allocator, config_path);
    defer loader.deinit();

    _ = try loader.loadConfig(TestConfig, "test.json");
    _ = try loader.loadConfig(TestConfig, "test.json");
    _ = try loader.loadConfig(TestConfig, "test.json");
}
