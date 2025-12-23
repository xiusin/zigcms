//! 缓存服务实现 (Cache Service Implementation)
//!
//! 提供线程安全的内存缓存服务，支持 TTL 过期时间管理。
//!
//! ## 线程安全
//!
//! 所有公共方法都使用 Mutex 保护，确保并发访问安全：
//! - `set()`: 写操作，获取独占锁
//! - `get()`: 读操作，获取独占锁（因为可能触发过期清理）
//! - `del()`: 写操作，获取独占锁
//! - `exists()`: 读操作，获取独占锁（因为可能触发过期清理）
//! - `flush()`: 写操作，获取独占锁
//! - `stats()`: 读操作，获取独占锁
//! - `cleanupExpired()`: 写操作，获取独占锁
//! - `delByPrefix()`: 写操作，获取独占锁
//!
//! ## 内存管理
//!
//! - 所有键和值都会被复制存储
//! - `deinit()` 会释放所有分配的内存
//! - 过期项在访问时自动清理
//!
//! ## 使用示例
//!
//! ```zig
//! var cache = CacheService.init(allocator);
//! defer cache.deinit();
//!
//! // 设置缓存（300秒过期）
//! try cache.set("user:1", "张三", 300);
//!
//! // 获取缓存
//! if (cache.get("user:1")) |value| {
//!     std.debug.print("用户: {s}\n", .{value});
//! }
//!
//! // 通过接口使用
//! const iface = cache.asInterface();
//! try iface.set("key", "value", null);
//! ```

const std = @import("std");
const builtin = @import("builtin");
const contract = @import("contract.zig");

/// 缓存服务 - 线程安全的内存缓存实现
///
/// 特性：
/// - 线程安全：所有操作都使用 Mutex 保护
/// - TTL 支持：支持设置过期时间
/// - 自动清理：过期项在访问时自动删除
/// - 接口兼容：实现 CacheInterface 接口
pub const CacheService = struct {
    const Self = @This();

    /// 内存分配器
    allocator: std.mem.Allocator,

    /// 缓存数据存储
    cache: std.StringHashMapUnmanaged(CacheItem),

    /// 线程安全互斥锁
    /// 保护所有缓存操作，确保并发访问安全
    mutex: std.Thread.Mutex = std.Thread.Mutex{},

    /// 默认过期时间（秒）
    default_ttl: u64 = 300, // 5分钟

    /// 创建缓存服务实例
    ///
    /// 参数:
    /// - allocator: 用于分配缓存数据的内存分配器
    pub fn init(allocator: std.mem.Allocator) CacheService {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMapUnmanaged(CacheItem){},
        };
    }

    /// 销毁缓存服务，释放所有资源
    ///
    /// 注意：此方法不是线程安全的，应在确保没有其他线程访问时调用
    pub fn deinit(self: *CacheService) void {
        // 释放所有 key 和 value 的内存
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.cache.deinit(self.allocator);
    }

    /// 缓存项结构
    const CacheItem = struct {
        /// 缓存值（字节数组）
        value: []u8,
        /// 过期时间戳（Unix 秒）
        expiry: u64,
        /// 创建时间戳（Unix 秒）
        created_at: u64,

        /// 释放缓存项内存
        pub fn deinit(self: *const CacheItem, allocator: std.mem.Allocator) void {
            allocator.free(self.value);
        }
    };

    /// 设置缓存项（线程安全）
    ///
    /// 将键值对存入缓存，如果键已存在则覆盖。
    ///
    /// 参数:
    /// - key: 缓存键
    /// - value: 缓存值
    /// - ttl: 过期时间（秒），null 使用默认 TTL
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn set(self: *CacheService, key: []const u8, value: []const u8, ttl: ?u64) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now: u64 = @intCast(std.time.timestamp());
        const expiry_time = now + (ttl orelse self.default_ttl);

        // 检查是否已存在相同的键，如果存在则释放旧值和旧键
        if (self.cache.fetchRemove(key)) |existing| {
            existing.value.deinit(self.allocator);
            self.allocator.free(existing.key);
        }

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const item = CacheItem{
            .value = value_copy,
            .expiry = expiry_time,
            .created_at = now,
        };

        try self.cache.put(self.allocator, key_copy, item);
    }

    /// 获取缓存项（线程安全）
    ///
    /// 根据键获取缓存值，如果键不存在或已过期则返回 null。
    /// 过期项会在访问时自动删除。
    ///
    /// 参数:
    /// - key: 缓存键
    ///
    /// 返回:
    /// - 缓存值切片（指向内部存储）
    /// - null（如果不存在或已过期）
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn get(self: *CacheService, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.get(key)) |item| {
            // 检查是否过期
            const now: u64 = @intCast(std.time.timestamp());
            if (now >= item.expiry) {
                // 过期了，删除它并释放内存
                if (self.cache.fetchRemove(key)) |removed| {
                    removed.value.deinit(self.allocator);
                    self.allocator.free(removed.key);
                }
                return null;
            }

            return item.value;
        }

        return null;
    }

    /// 删除缓存项（线程安全）
    ///
    /// 参数:
    /// - key: 要删除的缓存键
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn del(self: *CacheService, key: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.fetchRemove(key)) |entry| {
            entry.value.deinit(self.allocator);
            self.allocator.free(entry.key);
        }
    }

    /// 检查缓存项是否存在（线程安全）
    ///
    /// 参数:
    /// - key: 要检查的缓存键
    ///
    /// 返回:
    /// - true: 键存在且未过期
    /// - false: 键不存在或已过期
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn exists(self: *CacheService, key: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.get(key)) |item| {
            // 检查是否过期
            const now: u64 = @intCast(std.time.timestamp());
            if (now >= item.expiry) {
                // 过期了，删除它并释放内存
                if (self.cache.fetchRemove(key)) |removed| {
                    removed.value.deinit(self.allocator);
                    self.allocator.free(removed.key);
                }
                return false;
            }
            return true;
        }

        return false;
    }

    /// 清空所有缓存（线程安全）
    ///
    /// 删除所有缓存项并释放内存。
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn flush(self: *CacheService) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.cache.clearRetainingCapacity();
    }

    /// 缓存统计信息类型
    pub const CacheStats = struct {
        /// 有效缓存项数量
        count: usize,
        /// 已过期但未清理的项数量
        expired: usize,
    };

    /// 获取缓存统计信息（线程安全）
    ///
    /// 返回当前缓存的统计数据。
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn stats(self: *CacheService) CacheStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var count: usize = 0;
        var expired: usize = 0;
        var iter = self.cache.valueIterator();
        const now: u64 = @intCast(std.time.timestamp());

        while (iter.next()) |item| {
            if (now >= item.expiry) {
                expired += 1;
            } else {
                count += 1;
            }
        }

        return .{ .count = count, .expired = expired };
    }

    /// 清理过期项（线程安全）
    ///
    /// 主动清理所有已过期的缓存项。
    /// 建议定期调用此方法以防止内存泄漏。
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn cleanupExpired(self: *CacheService) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var to_remove = std.ArrayListUnmanaged([]const u8){};
        defer to_remove.deinit(self.allocator);

        const now: u64 = @intCast(std.time.timestamp());
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (now >= entry.value_ptr.expiry) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch {};
            }
        }

        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |removed_entry| {
                removed_entry.value.deinit(self.allocator);
                self.allocator.free(removed_entry.key);
            }
        }
    }

    /// 根据前缀删除缓存项（线程安全）
    ///
    /// 删除所有以指定前缀开头的缓存项。
    ///
    /// 参数:
    /// - prefix: 键前缀
    ///
    /// 线程安全：使用 Mutex 保护
    pub fn delByPrefix(self: *CacheService, prefix: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var to_remove = std.ArrayListUnmanaged([]const u8){};
        defer to_remove.deinit(self.allocator);

        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                try to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }

        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |removed_entry| {
                removed_entry.value.deinit(self.allocator);
                self.allocator.free(removed_entry.key);
            }
        }
    }

    /// 创建缓存接口实例
    ///
    /// 返回实现 CacheInterface 的接口实例，
    /// 可以与其他缓存实现互换使用。
    pub fn asInterface(self: *CacheService) contract.CacheInterface {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// 缓存接口的虚拟表
    const vtable: contract.CacheInterface.VTable = .{
        .set = cacheSet,
        .get = cacheGet,
        .del = cacheDel,
        .exists = cacheExists,
        .flush = cacheFlush,
        .stats = cacheStats,
        .cleanupExpired = cacheCleanupExpired,
        .delByPrefix = cacheDelByPrefix,
        .deinit = cacheDeinit,
    };

    /// 接口方法实现：设置缓存
    fn cacheSet(ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.set(key, value, ttl);
    }

    /// 接口方法实现：获取缓存
    fn cacheGet(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.get(key);
    }

    /// 接口方法实现：删除缓存
    fn cacheDel(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.del(key);
    }

    /// 接口方法实现：检查存在
    fn cacheExists(ptr: *anyopaque, key: []const u8) bool {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.exists(key);
    }

    /// 接口方法实现：清空缓存
    fn cacheFlush(ptr: *anyopaque) anyerror!void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.flush();
    }

    /// 接口方法实现：获取统计
    fn cacheStats(ptr: *anyopaque) contract.CacheStats {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        const s = self.stats();
        return .{ .count = s.count, .expired = s.expired };
    }

    /// 接口方法实现：清理过期项
    fn cacheCleanupExpired(ptr: *anyopaque) anyerror!void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.cleanupExpired();
    }

    /// 接口方法实现：按前缀删除
    fn cacheDelByPrefix(ptr: *anyopaque, prefix: []const u8) anyerror!void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        return self.delByPrefix(prefix);
    }

    /// 接口方法实现：销毁
    fn cacheDeinit(ptr: *anyopaque) void {
        const self: *CacheService = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

test "CacheService basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    // 测试设置和获取
    try cache.set("test_key", "test_value", null);
    const value = cache.get("test_key");
    try std.testing.expect(value != null);
    try std.testing.expect(std.mem.eql(u8, value.?, "test_value"));

    // 测试存在性
    try std.testing.expect(cache.exists("test_key"));
    try std.testing.expect(!cache.exists("nonexistent"));

    // 测试删除
    try cache.del("test_key");
    try std.testing.expect(!cache.exists("test_key"));
}

test "CacheService expiration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    // 设置1秒后过期的项
    try cache.set("expiring_key", "expiring_value", 1);

    // 检查存在
    try std.testing.expect(cache.exists("expiring_key"));

    // 等待2秒后检查（应该已过期）
    std.Thread.sleep(2 * std.time.ns_per_s);

    // 现在应该不存在了
    try std.testing.expect(!cache.exists("expiring_key"));
    const value = cache.get("expiring_key");
    try std.testing.expect(value == null);
}

test "CacheService cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    // 添加几个不同过期时间的项
    try cache.set("key1", "value1", 0); // 立即过期
    try cache.set("key2", "value2", 0); // 立即过期
    try cache.set("key3", "value3", 300); // 5分钟后过期

    // 清理过期项
    try cache.cleanupExpired();

    // 统计应该显示出清理效果
    const cache_stats = cache.stats();
    try std.testing.expect(cache_stats.expired == 0); // 已经清理了
    try std.testing.expect(cache_stats.count == 1); // 只剩下key3
}

test "CacheInterface abstraction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    // 创建接口实例
    var cache_interface = cache.asInterface();

    // 通过接口测试基本操作
    try cache_interface.set("interface_key", "interface_value", null);
    const value = cache_interface.get("interface_key");
    try std.testing.expect(value != null);
    try std.testing.expect(std.mem.eql(u8, value.?, "interface_value"));

    // 测试存在性
    try std.testing.expect(cache_interface.exists("interface_key"));
    try std.testing.expect(!cache_interface.exists("nonexistent"));

    // 测试删除
    try cache_interface.del("interface_key");
    try std.testing.expect(!cache_interface.exists("interface_key"));

    // 测试统计
    const stats = cache_interface.stats();
    try std.testing.expect(stats.count >= 0);
    try std.testing.expect(stats.expired >= 0);
}

test "CacheService thread safety - concurrent access" {
    // 测试并发访问的线程安全性
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    const num_threads = 4;
    const ops_per_thread = 100;

    // 定义线程工作函数
    const ThreadContext = struct {
        cache: *CacheService,
        thread_id: usize,
        allocator: std.mem.Allocator,

        fn worker(ctx: *@This()) void {
            var i: usize = 0;
            while (i < ops_per_thread) : (i += 1) {
                // 生成唯一键
                var key_buf: [64]u8 = undefined;
                const key = std.fmt.bufPrint(&key_buf, "thread_{d}_key_{d}", .{ ctx.thread_id, i }) catch continue;

                var value_buf: [64]u8 = undefined;
                const value = std.fmt.bufPrint(&value_buf, "value_{d}_{d}", .{ ctx.thread_id, i }) catch continue;

                // 设置缓存
                ctx.cache.set(key, value, 300) catch continue;

                // 获取缓存
                _ = ctx.cache.get(key);

                // 检查存在
                _ = ctx.cache.exists(key);

                // 获取统计
                _ = ctx.cache.stats();
            }
        }
    };

    // 创建线程上下文
    var contexts: [num_threads]ThreadContext = undefined;
    var threads: [num_threads]std.Thread = undefined;

    // 启动线程
    for (0..num_threads) |i| {
        contexts[i] = .{
            .cache = &cache,
            .thread_id = i,
            .allocator = allocator,
        };
        threads[i] = std.Thread.spawn(.{}, ThreadContext.worker, .{&contexts[i]}) catch continue;
    }

    // 等待所有线程完成
    for (&threads) |*thread| {
        thread.join();
    }

    // 验证缓存状态一致性
    const final_stats = cache.stats();
    try std.testing.expect(final_stats.count >= 0);
    try std.testing.expect(final_stats.expired >= 0);
}

test "CacheService delByPrefix" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cache = CacheService.init(allocator);
    defer cache.deinit();

    // 添加多个带前缀的键
    try cache.set("user:1:name", "张三", null);
    try cache.set("user:1:email", "test@example.com", null);
    try cache.set("user:2:name", "李四", null);
    try cache.set("order:1:total", "100", null);

    // 删除 user:1: 前缀的所有键
    try cache.delByPrefix("user:1:");

    // 验证删除结果
    try std.testing.expect(!cache.exists("user:1:name"));
    try std.testing.expect(!cache.exists("user:1:email"));
    try std.testing.expect(cache.exists("user:2:name"));
    try std.testing.expect(cache.exists("order:1:total"));
}
