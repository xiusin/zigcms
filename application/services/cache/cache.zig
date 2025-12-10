//! 缓存服务 - 用于缓存查询结果和字典数据
//!
//! 该服务提供：
//! - 基于内存的缓存实现
//! - TTL（Time To Live）过期机制
//! - 键值对存储
//! - 批量操作支持

const std = @import("std");
const builtin = @import("builtin");

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
        var iter = self.cache.valueIterator();
        while (iter.next()) |item| {
            item.deinit(self.allocator);
        }
        self.cache.deinit(self.allocator);
    }
    
    /// 缓存项结构
    const CacheItem = struct {
        value: []u8,        // JSON序列化后的值
        expiry: u64,        // 过期时间戳（秒）
        created_at: u64,    // 创建时间戳（秒）
        
        pub fn deinit(self: *CacheItem, allocator: std.mem.Allocator) void {
            allocator.free(self.value);
        }
    };
    
    /// 设置缓存项
    pub fn set(self: *CacheService, key: []const u8, value: []const u8, ttl: ?u64) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const alloc = gpa.allocator();
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const expiry_time = std.time.timestamp() + (ttl orelse self.default_ttl);
        
        // 检查是否已存在相同的键，如果存在则释放旧值
        if (self.cache.get(key)) |existing_item| {
            existing_item.deinit(self.allocator);
            _ = self.cache.remove(key);
        }
        
        const value_copy = try self.allocator.dupe(u8, value);
        const item = CacheItem{
            .value = value_copy,
            .expiry = expiry_time,
            .created_at = std.time.timestamp(),
        };
        
        try self.cache.put(self.allocator, try self.allocator.dupe(u8, key), item);
    }
    
    /// 获取缓存项
    pub fn get(self: *CacheService, key: []const u8) !?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.cache.get(key)) |item| {
            // 检查是否过期
            if (std.time.timestamp() > item.expiry) {
                // 过期了，删除它
                _ = self.cache.remove(key);
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
            if (std.time.timestamp() > item.expiry) {
                // 过期了，删除它
                _ = self.cache.remove(key);
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
    
    /// 获取缓存统计信息
    pub fn stats(self: *CacheService) !struct { count: usize, expired: usize } {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        var count: usize = 0;
        var expired: usize = 0;
        var iter = self.cache.valueIterator();
        
        while (iter.next()) |item| {
            if (std.time.timestamp() > item.expiry) {
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
        
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();
        
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (std.time.timestamp() > entry.value.expiry) {
                try to_remove.append(entry.key_ptr.*);
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
        
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();
        
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                try to_remove.append(entry.key_ptr.*);
            }
        }
        
        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |removed_entry| {
                removed_entry.value.deinit(self.allocator);
                self.allocator.free(removed_entry.key);
            }
        }
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
    const value = try cache.get("test_key");
    try std.testing.expect(value != null);
    try std.testing.expect(std.mem.eql(u8, value.?, "test_value"));
    
    // 测试存在性
    try std.testing.expect(try cache.exists("test_key"));
    try std.testing.expect(!try cache.exists("nonexistent"));
    
    // 测试删除
    try cache.del("test_key");
    try std.testing.expect(!try cache.exists("test_key"));
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
    try std.testing.expect(try cache.exists("expiring_key"));
    
    // 等待2秒后检查（应该已过期）
    std.time.sleep(2 * std.time.ns_per_s);
    
    // 现在应该不存在了
    try std.testing.expect(!try cache.exists("expiring_key"));
    const value = try cache.get("expiring_key");
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
    std.time.sleep(2 * std.time.ns_per_s);
    
    // 清理过期项
    try cache.cleanupExpired();
    
    // 统计应该显示出清理效果
    const stats = try cache.stats();
    try std.testing.expect(stats.expired == 0); // 已经清理了
    try std.testing.expect(stats.count == 1);   // 只剩下key3
}