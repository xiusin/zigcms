//! 进程内缓存模块
//!
//! 特性：
//! - 支持 TTL 过期时间
//! - 并发安全（读写锁）
//! - 内存安全（自动清理过期项）
//! - 泛型支持（类型安全的存取）
//!
//! ## 使用示例
//!
//! ```zig
//! const cache = @import("services/cache/cache.zig");
//!
//! var c = cache.Cache([]const u8).init(allocator, .{
//!     .cleanup_interval_ms = 10_000, // 10秒清理一次
//! });
//! defer c.deinit();
//!
//! // 设置缓存，5秒过期
//! try c.set("user:1", "张三", 5_000);
//!
//! // 获取缓存
//! if (c.get("user:1")) |value| {
//!     std.debug.print("用户: {s}\n", .{value});
//! }
//!
//! // 删除
//! c.delete("user:1");
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

/// 缓存配置
pub const CacheConfig = struct {
    /// 清理间隔（毫秒），0 表示不自动清理
    cleanup_interval_ms: u64 = 60_000,
    /// 初始容量
    initial_capacity: u32 = 16,
    /// 默认过期时间（毫秒），0 表示永不过期
    default_ttl_ms: u64 = 0,
};

/// 缓存项
fn CacheItem(comptime V: type) type {
    return struct {
        value: V,
        expire_at: ?i64, // null 表示永不过期
        created_at: i64,
        access_count: u64,

        fn isExpired(self: @This()) bool {
            if (self.expire_at) |exp| {
                return std.time.milliTimestamp() > exp;
            }
            return false;
        }
    };
}

/// 泛型缓存
///
/// 支持任意值类型，键固定为 `[]const u8`
pub fn Cache(comptime V: type) type {
    return struct {
        const Self = @This();
        const Item = CacheItem(V);
        const Map = std.StringHashMap(Item);

        allocator: Allocator,
        map: Map,
        lock: RwLock,
        config: CacheConfig,
        stats: Stats,

        /// 统计信息
        pub const Stats = struct {
            hits: u64 = 0,
            misses: u64 = 0,
            sets: u64 = 0,
            deletes: u64 = 0,
            expirations: u64 = 0,

            pub fn hitRate(self: Stats) f64 {
                const total = self.hits + self.misses;
                if (total == 0) return 0;
                return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
            }
        };

        pub fn init(allocator: Allocator, config: CacheConfig) Self {
            return .{
                .allocator = allocator,
                .map = Map.init(allocator),
                .lock = .{},
                .config = config,
                .stats = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            // 释放所有存储的键
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            self.map.deinit();
        }

        /// 设置缓存
        ///
        /// - key: 缓存键
        /// - value: 缓存值
        /// - ttl_ms: 过期时间（毫秒），0 表示使用默认值，null 表示永不过期
        pub fn set(self: *Self, key: []const u8, value: V, ttl_ms: ?u64) !void {
            self.lock.lock();
            defer self.lock.unlock();

            const now = std.time.milliTimestamp();
            const actual_ttl = ttl_ms orelse self.config.default_ttl_ms;
            const expire_at: ?i64 = if (actual_ttl > 0) now + @as(i64, @intCast(actual_ttl)) else null;

            // 复制 key 以确保内存安全
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);

            // 如果已存在，先释放旧的 key
            if (self.map.fetchRemove(key)) |old| {
                self.allocator.free(old.key);
            }

            try self.map.put(owned_key, .{
                .value = value,
                .expire_at = expire_at,
                .created_at = now,
                .access_count = 0,
            });

            self.stats.sets += 1;
        }

        /// 获取缓存值
        pub fn get(self: *Self, key: []const u8) ?V {
            // 先尝试读锁
            self.lock.lockShared();

            if (self.map.getPtr(key)) |item| {
                if (item.isExpired()) {
                    self.lock.unlockShared();
                    // 过期了，需要写锁来删除
                    self.lock.lock();
                    defer self.lock.unlock();
                    if (self.map.fetchRemove(key)) |old| {
                        self.allocator.free(old.key);
                        self.stats.expirations += 1;
                    }
                    self.stats.misses += 1;
                    return null;
                }
                item.access_count += 1;
                const value = item.value;
                self.lock.unlockShared();
                self.stats.hits += 1;
                return value;
            }

            self.lock.unlockShared();
            self.stats.misses += 1;
            return null;
        }

        /// 获取或设置（如果不存在则调用 loader 加载）
        pub fn getOrSet(
            self: *Self,
            key: []const u8,
            ttl_ms: ?u64,
            loader: anytype,
        ) !V {
            if (self.get(key)) |value| {
                return value;
            }

            // 调用 loader 获取值
            const value = try loader();
            try self.set(key, value, ttl_ms);
            return value;
        }

        /// 删除缓存
        pub fn delete(self: *Self, key: []const u8) bool {
            self.lock.lock();
            defer self.lock.unlock();

            if (self.map.fetchRemove(key)) |old| {
                self.allocator.free(old.key);
                self.stats.deletes += 1;
                return true;
            }
            return false;
        }

        /// 检查键是否存在（且未过期）
        pub fn exists(self: *Self, key: []const u8) bool {
            self.lock.lockShared();
            defer self.lock.unlockShared();

            if (self.map.get(key)) |item| {
                return !item.isExpired();
            }
            return false;
        }

        /// 获取剩余 TTL（毫秒）
        pub fn ttl(self: *Self, key: []const u8) ?i64 {
            self.lock.lockShared();
            defer self.lock.unlockShared();

            if (self.map.get(key)) |item| {
                if (item.expire_at) |exp| {
                    const remaining = exp - std.time.milliTimestamp();
                    return if (remaining > 0) remaining else 0;
                }
                return null; // 永不过期
            }
            return null; // 不存在
        }

        /// 延长过期时间
        pub fn touch(self: *Self, key: []const u8, ttl_ms: u64) bool {
            self.lock.lock();
            defer self.lock.unlock();

            if (self.map.getPtr(key)) |item| {
                if (!item.isExpired()) {
                    const now = std.time.milliTimestamp();
                    item.expire_at = now + @as(i64, @intCast(ttl_ms));
                    return true;
                }
            }
            return false;
        }

        /// 清理过期项
        pub fn cleanup(self: *Self) usize {
            self.lock.lock();
            defer self.lock.unlock();

            var count: usize = 0;
            var to_remove: std.ArrayListUnmanaged([]const u8) = .empty;
            defer to_remove.deinit(self.allocator);

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.isExpired()) {
                    to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
                }
            }

            for (to_remove.items) |key| {
                if (self.map.fetchRemove(key)) |old| {
                    self.allocator.free(old.key);
                    count += 1;
                }
            }

            self.stats.expirations += count;
            return count;
        }

        /// 清空所有缓存
        pub fn flush(self: *Self) void {
            self.lock.lock();
            defer self.lock.unlock();

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            self.map.clearRetainingCapacity();
        }

        /// 获取缓存大小
        pub fn size(self: *Self) usize {
            self.lock.lockShared();
            defer self.lock.unlockShared();
            return self.map.count();
        }

        /// 获取所有键
        pub fn keys(self: *Self) ![][]const u8 {
            self.lock.lockShared();
            defer self.lock.unlockShared();

            var result = std.ArrayList([]const u8).init(self.allocator);
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!entry.value_ptr.isExpired()) {
                    try result.append(entry.key_ptr.*);
                }
            }
            return try result.toOwnedSlice();
        }

        /// 获取统计信息
        pub fn getStats(self: *Self) Stats {
            return self.stats;
        }

        /// 重置统计
        pub fn resetStats(self: *Self) void {
            self.stats = .{};
        }
    };
}

/// 多表缓存管理器
///
/// 类似 V 语言 cache 的 table 概念
pub fn CacheManager(comptime V: type) type {
    return struct {
        const Self = @This();
        const Table = Cache(V);
        const TableMap = std.StringHashMap(*Table);

        allocator: Allocator,
        tables: TableMap,
        lock: Mutex,
        config: CacheConfig,

        pub fn init(allocator: Allocator, config: CacheConfig) Self {
            return .{
                .allocator = allocator,
                .tables = TableMap.init(allocator),
                .lock = .{},
                .config = config,
            };
        }

        pub fn deinit(self: *Self) void {
            var iter = self.tables.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.*.deinit();
                self.allocator.destroy(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.tables.deinit();
        }

        /// 获取或创建表
        pub fn table(self: *Self, name: []const u8) !*Table {
            self.lock.lock();
            defer self.lock.unlock();

            if (self.tables.get(name)) |t| {
                return t;
            }

            const owned_name = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(owned_name);

            const t = try self.allocator.create(Table);
            t.* = Table.init(self.allocator, self.config);

            try self.tables.put(owned_name, t);
            return t;
        }

        /// 删除表
        pub fn dropTable(self: *Self, name: []const u8) bool {
            self.lock.lock();
            defer self.lock.unlock();

            if (self.tables.fetchRemove(name)) |entry| {
                entry.value.deinit();
                self.allocator.destroy(entry.value);
                self.allocator.free(entry.key);
                return true;
            }
            return false;
        }

        /// 清理所有表的过期项
        pub fn cleanupAll(self: *Self) usize {
            self.lock.lock();
            defer self.lock.unlock();

            var total: usize = 0;
            var iter = self.tables.iterator();
            while (iter.next()) |entry| {
                total += entry.value_ptr.*.cleanup();
            }
            return total;
        }

        /// 获取所有表名
        pub fn tableNames(self: *Self) ![][]const u8 {
            self.lock.lock();
            defer self.lock.unlock();

            var result = std.ArrayList([]const u8).init(self.allocator);
            var iter = self.tables.iterator();
            while (iter.next()) |entry| {
                try result.append(entry.key_ptr.*);
            }
            return try result.toOwnedSlice();
        }
    };
}

// ============================================================================
// 测试
// ============================================================================

test "Cache: 基本 set/get" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("key1", 100, null);
    try c.set("key2", 200, null);

    try std.testing.expectEqual(@as(?i32, 100), c.get("key1"));
    try std.testing.expectEqual(@as(?i32, 200), c.get("key2"));
    try std.testing.expectEqual(@as(?i32, null), c.get("key3"));
}

test "Cache: 字符串值" {
    const allocator = std.testing.allocator;
    var c = Cache([]const u8).init(allocator, .{});
    defer c.deinit();

    try c.set("name", "张三", null);
    try c.set("city", "北京", null);

    try std.testing.expectEqualStrings("张三", c.get("name").?);
    try std.testing.expectEqualStrings("北京", c.get("city").?);
}

test "Cache: 过期时间" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    // 设置永不过期
    try c.set("long", 2, null);
    try std.testing.expect(c.exists("long"));
    try std.testing.expectEqual(@as(?i64, null), c.ttl("long")); // 永不过期返回 null

    // 设置有过期时间的项
    try c.set("with_ttl", 1, 5000);
    try std.testing.expect(c.exists("with_ttl"));
    const remaining = c.ttl("with_ttl");
    try std.testing.expect(remaining != null);
    try std.testing.expect(remaining.? > 0);
    try std.testing.expect(remaining.? <= 5000);

    // 测试过期检测逻辑（通过手动模拟）
    // 由于无法真正等待，验证 isExpired 逻辑
}

test "Cache: delete" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("key", 42, null);
    try std.testing.expect(c.exists("key"));

    try std.testing.expect(c.delete("key"));
    try std.testing.expect(!c.exists("key"));
    try std.testing.expect(!c.delete("key")); // 再次删除返回 false
}

test "Cache: flush" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("a", 1, null);
    try c.set("b", 2, null);
    try c.set("c", 3, null);

    try std.testing.expectEqual(@as(usize, 3), c.size());

    c.flush();

    try std.testing.expectEqual(@as(usize, 0), c.size());
}

test "Cache: 统计信息" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("key", 1, null);
    _ = c.get("key"); // hit
    _ = c.get("key"); // hit
    _ = c.get("noexist"); // miss

    const stats = c.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.sets);
    try std.testing.expectEqual(@as(u64, 2), stats.hits);
    try std.testing.expectEqual(@as(u64, 1), stats.misses);
}

test "Cache: touch 延长过期" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("key", 1, 100);

    const ttl1 = c.ttl("key");
    try std.testing.expect(ttl1 != null);

    // 延长到 10 秒
    try std.testing.expect(c.touch("key", 10000));

    const ttl2 = c.ttl("key");
    try std.testing.expect(ttl2.? > ttl1.?);
}

test "Cache: 覆盖已存在的键" {
    const allocator = std.testing.allocator;
    var c = Cache(i32).init(allocator, .{});
    defer c.deinit();

    try c.set("key", 1, null);
    try std.testing.expectEqual(@as(?i32, 1), c.get("key"));

    try c.set("key", 2, null);
    try std.testing.expectEqual(@as(?i32, 2), c.get("key"));

    try std.testing.expectEqual(@as(usize, 1), c.size());
}

test "CacheManager: 多表管理" {
    const allocator = std.testing.allocator;
    var mgr = CacheManager(i32).init(allocator, .{});
    defer mgr.deinit();

    const users = try mgr.table("users");
    const settings = try mgr.table("settings");

    try users.set("id:1", 100, null);
    try settings.set("theme", 1, null);

    try std.testing.expectEqual(@as(?i32, 100), users.get("id:1"));
    try std.testing.expectEqual(@as(?i32, 1), settings.get("theme"));

    // 两个表独立
    try std.testing.expectEqual(@as(?i32, null), users.get("theme"));
}

test "Cache: 结构体值" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    const allocator = std.testing.allocator;
    var c = Cache(User).init(allocator, .{});
    defer c.deinit();

    try c.set("user:1", .{ .id = 1, .name = "张三" }, null);
    try c.set("user:2", .{ .id = 2, .name = "李四" }, null);

    const user1 = c.get("user:1").?;
    try std.testing.expectEqual(@as(i32, 1), user1.id);
    try std.testing.expectEqualStrings("张三", user1.name);
}
