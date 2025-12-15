const std = @import("std");
const builtin = @import("builtin");
const cache_contract = @import("cache_contract.zig");

pub const CacheService = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    cache: std.StringHashMapUnmanaged(CacheItem),
    mutex: std.Thread.Mutex = std.Thread.Mutex{},

    // 默认过期时间（秒）
    default_ttl: u64 = 300, // 5分钟

    pub fn init(allocator: std.mem.Allocator) CacheService {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMapUnmanaged(CacheItem){},
        };
    }

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
        value: []u8, // JSON序列化后的值
        expiry: u64, // 过期时间戳（秒）
        created_at: u64, // 创建时间戳（秒）

        pub fn deinit(self: *const CacheItem, allocator: std.mem.Allocator) void {
            allocator.free(self.value);
        }
    };

    /// 设置缓存项
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

    /// 获取缓存项
    pub fn get(self: *CacheService, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.get(key)) |item| {
            // 检查是否过期
            const now: u64 = @intCast(std.time.timestamp());
            if (now > item.expiry) {
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

    /// 删除缓存项
    pub fn del(self: *CacheService, key: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.fetchRemove(key)) |entry| {
            entry.value.deinit(self.allocator);
            self.allocator.free(entry.key);
        }
    }

    /// 检查缓存项是否存在
    pub fn exists(self: *CacheService, key: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.cache.get(key)) |item| {
            // 检查是否过期
            const now: u64 = @intCast(std.time.timestamp());
            if (now > item.expiry) {
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

    /// 清空所有缓存
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
    pub const CacheStats = struct { count: usize, expired: usize };

    /// 获取缓存统计信息
    pub fn stats(self: *CacheService) CacheStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        var count: usize = 0;
        var expired: usize = 0;
        var iter = self.cache.valueIterator();
        const now: u64 = @intCast(std.time.timestamp());

        while (iter.next()) |item| {
            if (now > item.expiry) {
                expired += 1;
            } else {
                count += 1;
            }
        }

        return .{ .count = count, .expired = expired };
    }

    /// 定期清理过期项（非阻塞）
    pub fn cleanupExpired(self: *CacheService) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var to_remove = std.ArrayListUnmanaged([]const u8){};
        defer to_remove.deinit(self.allocator);

        const now: u64 = @intCast(std.time.timestamp());
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (now > entry.value_ptr.expiry) {
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

    /// 根据前缀删除缓存项
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
    pub fn asInterface(self: *CacheService) cache_contract.CacheInterface {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// 缓存接口的虚拟表
    const vtable: cache_contract.CacheInterface.VTable = .{
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
    fn cacheStats(ptr: *anyopaque) cache_contract.CacheStats {
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
    try cache.set("key1", "value1", 1);
    try cache.set("key2", "value2", 2);
    try cache.set("key3", "value3", 300);

    // 等待几秒让前两个过期
    std.Thread.sleep(2 * std.time.ns_per_s);

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
