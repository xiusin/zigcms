const std = @import("std");
const testing = std.testing;
const cache_contract = @import("../application/services/cache/contract.zig");
const cache_drivers = @import("../application/services/cache_drivers.zig");

test "CacheInterface - MemoryCacheDriver 契约测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("test_key", "test_value", 300);
    
    if (cache.get("test_key")) |value| {
        try testing.expectEqualStrings("test_value", value);
    } else {
        try testing.expect(false);
    }

    try testing.expect(cache.exists("test_key"));
    try cache.del("test_key");
    try testing.expect(!cache.exists("test_key"));
}

test "CacheInterface - 内存缓存 TTL 过期测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("expire_key", "expire_value", 1);
    
    try testing.expect(cache.exists("expire_key"));
    
    std.time.sleep(2 * std.time.ns_per_s);
    
    try testing.expect(!cache.exists("expire_key"));
}

test "CacheInterface - 前缀删除测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("user:1:name", "Alice", 300);
    try cache.set("user:1:email", "alice@example.com", 300);
    try cache.set("user:2:name", "Bob", 300);

    try cache.delByPrefix("user:1:");
    
    try testing.expect(!cache.exists("user:1:name"));
    try testing.expect(!cache.exists("user:1:email"));
    try testing.expect(cache.exists("user:2:name"));
}

test "CacheInterface - 统计信息测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("key1", "value1", 300);
    try cache.set("key2", "value2", 300);
    try cache.set("key3", "value3", 1);

    std.time.sleep(2 * std.time.ns_per_s);

    const stats = cache.stats();
    try testing.expectEqual(@as(usize, 2), stats.count);
    try testing.expectEqual(@as(usize, 1), stats.expired);
}

test "CacheInterface - 清理过期项测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("expire1", "value1", 1);
    try cache.set("expire2", "value2", 1);
    try cache.set("keep", "value3", 300);

    std.time.sleep(2 * std.time.ns_per_s);

    try cache.cleanupExpired();

    const stats = cache.stats();
    try testing.expectEqual(@as(usize, 1), stats.count);
    try testing.expectEqual(@as(usize, 0), stats.expired);
}

test "CacheInterface - flush 测试" {
    const allocator = testing.allocator;

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    try cache.set("key1", "value1", 300);
    try cache.set("key2", "value2", 300);
    try cache.set("key3", "value3", 300);

    try cache.flush();

    const stats = cache.stats();
    try testing.expectEqual(@as(usize, 0), stats.count);
}
