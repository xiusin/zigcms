//! 类型安全缓存包装器
//!
//! 提供类似 Go 泛型的类型安全缓存访问。

const std = @import("std");
const base_cache = @import("cache.zig");

/// 带前缀的缓存包装器
///
/// 自动为所有键添加前缀，方便命名空间隔离
pub fn PrefixedCache(comptime V: type) type {
    return struct {
        const Self = @This();
        const InnerCache = base_cache.Cache(V);

        inner: *InnerCache,
        prefix: []const u8,
        allocator: std.mem.Allocator,

        pub fn init(inner: *InnerCache, prefix: []const u8, allocator: std.mem.Allocator) Self {
            return .{
                .inner = inner,
                .prefix = prefix,
                .allocator = allocator,
            };
        }

        fn prefixedKey(self: *Self, key: []const u8) ![]const u8 {
            return try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ self.prefix, key });
        }

        pub fn set(self: *Self, key: []const u8, value: V, ttl_ms: ?u64) !void {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            try self.inner.set(pkey, value, ttl_ms);
        }

        pub fn get(self: *Self, key: []const u8) !?V {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            return self.inner.get(pkey);
        }

        pub fn delete(self: *Self, key: []const u8) !bool {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            return self.inner.delete(pkey);
        }
    };
}

/// 懒加载缓存
///
/// 当缓存未命中时，自动调用 loader 函数加载数据
pub fn LazyCache(comptime V: type, comptime Loader: type) type {
    return struct {
        const Self = @This();
        const InnerCache = base_cache.Cache(V);

        inner: InnerCache,
        loader: Loader,
        default_ttl: ?u64,

        pub fn init(
            allocator: std.mem.Allocator,
            loader: Loader,
            default_ttl: ?u64,
        ) Self {
            return .{
                .inner = InnerCache.init(allocator, .{}),
                .loader = loader,
                .default_ttl = default_ttl,
            };
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        /// 获取缓存，未命中时自动加载
        pub fn get(self: *Self, key: []const u8) !V {
            if (self.inner.get(key)) |value| {
                return value;
            }

            // 调用 loader 加载
            const value = try self.loader.load(key);
            try self.inner.set(key, value, self.default_ttl);
            return value;
        }

        pub fn invalidate(self: *Self, key: []const u8) bool {
            return self.inner.delete(key);
        }

        pub fn refresh(self: *Self, key: []const u8) !V {
            _ = self.inner.delete(key);
            return try self.get(key);
        }
    };
}

// ============================================================================
// 测试
// ============================================================================

test "PrefixedCache: 前缀隔离" {
    const allocator = std.testing.allocator;
    var inner = base_cache.Cache(i32).init(allocator, .{});
    defer inner.deinit();

    var users = PrefixedCache(i32).init(&inner, "user", allocator);
    var orders = PrefixedCache(i32).init(&inner, "order", allocator);

    try users.set("1", 100, null);
    try orders.set("1", 200, null);

    // 实际存储的键是 "user:1" 和 "order:1"
    try std.testing.expectEqual(@as(?i32, 100), inner.get("user:1"));
    try std.testing.expectEqual(@as(?i32, 200), inner.get("order:1"));
}

test "LazyCache: 懒加载" {
    const Loader = struct {
        call_count: *usize,

        pub fn load(self: @This(), key: []const u8) !i32 {
            self.call_count.* += 1;
            // 模拟从数据库加载
            if (std.mem.eql(u8, key, "user:1")) return 100;
            if (std.mem.eql(u8, key, "user:2")) return 200;
            return error.NotFound;
        }
    };

    const allocator = std.testing.allocator;
    var call_count: usize = 0;
    var c = LazyCache(i32, Loader).init(allocator, .{ .call_count = &call_count }, 60_000);
    defer c.deinit();

    // 第一次调用，触发 loader
    const v1 = try c.get("user:1");
    try std.testing.expectEqual(@as(i32, 100), v1);
    try std.testing.expectEqual(@as(usize, 1), call_count);

    // 第二次调用，使用缓存
    const v2 = try c.get("user:1");
    try std.testing.expectEqual(@as(i32, 100), v2);
    try std.testing.expectEqual(@as(usize, 1), call_count); // 没有再次调用 loader

    // 刷新缓存
    _ = try c.refresh("user:1");
    try std.testing.expectEqual(@as(usize, 2), call_count);
}
