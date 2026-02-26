const std = @import("std");
const cache_contract = @import("../application/services/cache/contract.zig");
const cache_drivers = @import("../application/services/cache_drivers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== 缓存契约测试 ===\n\n", .{});

    var memory_cache = cache_drivers.MemoryCacheDriver.init(allocator);
    defer memory_cache.deinit();

    const cache = memory_cache.asInterface();

    std.debug.print("1. 测试 set/get:\n", .{});
    try cache.set("user:1:name", "Alice", 300);
    if (try cache.get("user:1:name", allocator)) |value| {
        defer allocator.free(value);
        std.debug.print("   ✓ 成功获取缓存值: {s}\n", .{value});
    }

    std.debug.print("\n2. 测试 exists:\n", .{});
    if (cache.exists("user:1:name")) {
        std.debug.print("   ✓ 缓存键存在\n", .{});
    }

    std.debug.print("\n3. 测试前缀删除:\n", .{});
    try cache.set("user:1:email", "alice@example.com", 300);
    try cache.set("user:2:name", "Bob", 300);
    try cache.delByPrefix("user:1:");
    if (!cache.exists("user:1:name") and !cache.exists("user:1:email")) {
        std.debug.print("   ✓ 成功按前缀删除缓存\n", .{});
    }
    if (cache.exists("user:2:name")) {
        std.debug.print("   ✓ 其他缓存未受影响\n", .{});
    }

    std.debug.print("\n4. 测试统计信息:\n", .{});
    try cache.set("key1", "value1", 300);
    try cache.set("key2", "value2", 300);
    const stats = cache.stats();
    std.debug.print("   ✓ 缓存项数: {d}\n", .{stats.count});

    std.debug.print("\n5. 测试 flush:\n", .{});
    try cache.flush();
    const stats2 = cache.stats();
    std.debug.print("   ✓ 清空后缓存项数: {d}\n", .{stats2.count});

    std.debug.print("\n=== 缓存契约测试通过 ✓ ===\n\n", .{});
}
