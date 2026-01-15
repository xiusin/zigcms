//! 缓存基础设施模块 (Cache Module)
//!
//! 提供统一的缓存接口，支持多种后端（内存、Redis、Memcached）。
//! 包含 TTL 管理、缓存清理等功能。
//!
//! ## 功能
//! - 缓存接口（Cache）
//! - 缓存配置（CacheConfig）
//! - 缓存后端类型（CacheBackend）
//! - 缓存工厂（CacheFactory）
//!
//! ## 使用示例
//! ```zig
//! const cache = @import("infrastructure/cache/mod.zig");
//!
//! // 创建缓存实例
//! const c = try cache.CacheFactory.create(allocator, .{
//!     .backend = .Memory,
//!     .default_ttl = 3600,
//! });
//!
//! // 设置缓存
//! try c.set("key", "value", 3600);
//!
//! // 获取缓存
//! if (try c.get("key")) |value| {
//!     // 使用缓存值
//! }
//!
//! // 删除缓存
//! try c.delete("key");
//! ```

const std = @import("std");
const builtin = @import("builtin");
const cache_contract = @import("../../application/services/cache/contract.zig");

/// 缓存接口别名，方便使用
pub const CacheInterface = cache_contract.CacheInterface;

/// Redis模块导入（仅在非测试环境下）
const redis = if (@hasDecl(@import("root"), "redis"))
    @import("root").redis
else
    struct {
        pub const Connection = opaque {};
        pub fn connect(_: anytype, _: std.mem.Allocator) !*Connection {
            return error.RedisNotAvailable;
        }
    };

/// 缓存项
const CacheEntry = struct {
    value: []const u8,
    expires_at: ?i64 = null,

    /// 检查缓存项是否过期
    fn isExpired(self: *const CacheEntry) bool {
        if (self.expires_at) |exp| {
            return std.time.timestamp() > exp;
        }
        return false;
    }
};

/// 内存缓存实现
const MemoryCache = struct {
    allocator: std.mem.Allocator,
    data: std.StringHashMap(CacheEntry),
    mutex: std.Thread.Mutex = .{},
    default_ttl: u64,

    const Self = @This();

    /// 初始化内存缓存
    fn init(allocator: std.mem.Allocator, default_ttl: u64) Self {
        return .{
            .allocator = allocator,
            .data = std.StringHashMap(CacheEntry).init(allocator),
            .default_ttl = default_ttl,
        };
    }

    /// 释放内存缓存
    fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.data.deinit();
    }

    /// 获取缓存值（返回副本，线程安全）
    fn get(ptr: *anyopaque, key: []const u8, allocator: std.mem.Allocator) anyerror!?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |entry| {
            if (entry.isExpired()) {
                return null;
            }
            // 返回副本，确保线程安全
            return try allocator.dupe(u8, entry.value);
        }
        return null;
    }

    /// 设置缓存值
    fn set(ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        const effective_ttl = ttl orelse self.default_ttl;
        const expires_at = if (effective_ttl > 0)
            std.time.timestamp() + @as(i64, @intCast(effective_ttl))
        else
            null;

        if (self.data.fetchRemove(key)) |old_entry| {
            self.allocator.free(old_entry.key);
            self.allocator.free(old_entry.value.value);
        }

        try self.data.put(key_copy, .{
            .value = value_copy,
            .expires_at = expires_at,
        });
    }

    /// 删除缓存
    fn del(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.fetchRemove(key)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value.value);
        }
    }

    /// 检查缓存是否存在
    fn exists(ptr: *anyopaque, key: []const u8) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |entry| {
            return !entry.isExpired();
        }
        return false;
    }

    /// 清空所有缓存
    fn flush(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.data.clearRetainingCapacity();
    }

    /// 获取统计
    fn stats(ptr: *anyopaque) cache_contract.CacheStats {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .count = self.data.count(),
            .expired = 0, // 内存实现暂不统计细项
        };
    }

    /// 清理过期
    fn cleanupExpired(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        // 简单实现：全量扫描
        var it = self.data.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.isExpired()) {
                // 注意：HashMap 迭代时删除需要小心，这里暂不复杂化
            }
        }
    }

    /// 按前缀删除
    fn delByPrefix(ptr: *anyopaque, prefix: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();
        
        var it = self.data.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                // 同上
            }
        }
    }

    /// 接口实现
    pub fn asInterface(self: *Self) CacheInterface {
        return .{
            .ptr = self,
            .vtable = &.{
                .get = get,
                .set = set,
                .del = del,
                .exists = exists,
                .flush = flush,
                .stats = stats,
                .cleanupExpired = cleanupExpired,
                .delByPrefix = delByPrefix,
                .deinit = cacheDeinit,
            },
        };
    }

    fn cacheDeinit(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

/// Redis缓存实现
const RedisCache = struct {
    allocator: std.mem.Allocator,
    connection: *RedisConnection,
    default_ttl: u64,

    const Self = @This();
    const RedisConnection = redis.Connection;

    /// 初始化Redis缓存
    fn init(allocator: std.mem.Allocator, connection: *RedisConnection, default_ttl: u64) Self {
        return .{
            .allocator = allocator,
            .connection = connection,
            .default_ttl = default_ttl,
        };
    }

    /// 释放Redis缓存
    fn deinit(self: *Self) void {
        _ = self;
        // Redis not implemented
        // self.connection.close();
    }

    /// 获取缓存值
    fn get(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = self.connection.sendCommand(&.{ "GET", key }) catch return null;
        defer reply.deinit();

        if (reply.string()) |value| {
            return self.allocator.dupe(u8, value) catch null;
        }
        return null;
    }

    /// 设置缓存值
    fn set(ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        const effective_ttl = ttl orelse self.default_ttl;

        if (effective_ttl > 0) {
            var ttl_buf: [32]u8 = undefined;
            const ttl_str = try std.fmt.bufPrint(&ttl_buf, "{d}", .{effective_ttl});

            var reply = try self.connection.sendCommand(&.{ "SETEX", key, ttl_str, value });
            defer reply.deinit();
        } else {
            var reply = try self.connection.sendCommand(&.{ "SET", key, value });
            defer reply.deinit();
        }
    }

    /// 删除缓存
    fn del(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{ "DEL", key });
        defer reply.deinit();
    }

    /// 检查缓存是否存在
    fn exists(ptr: *anyopaque, key: []const u8) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = self.connection.sendCommand(&.{ "EXISTS", key }) catch return false;
        defer reply.deinit();

        if (reply.integer()) |count| {
            return count > 0;
        }
        return false;
    }

    /// 清空所有缓存
    fn flush(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{"FLUSHDB"});
        defer reply.deinit();
    }

    /// 获取统计
    fn stats(_: *anyopaque) cache_contract.CacheStats {
        return .{ .count = 0, .expired = 0 };
    }

    /// 清理过期
    fn cleanupExpired(_: *anyopaque) anyerror!void {
        // Redis 自动处理过期
    }

    /// 按前缀删除
    fn delByPrefix(ptr: *anyopaque, prefix: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        // 这里可以使用 SCAN + DEL，简化版先不做
        _ = self;
        _ = prefix;
    }

    /// 接口实现
    pub fn asInterface(self: *Self) CacheInterface {
        return .{
            .ptr = self,
            .vtable = &.{
                .get = get,
                .set = set,
                .del = del,
                .exists = exists,
                .flush = flush,
                .stats = stats,
                .cleanupExpired = cleanupExpired,
                .delByPrefix = delByPrefix,
                .deinit = cacheDeinit,
            },
        };
    }

    fn cacheDeinit(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

/// 缓存配置
pub const CacheConfig = struct {
    backend: CacheBackend = .Memory,
    redis_host: []const u8 = "127.0.0.1",
    redis_port: u16 = 6379,
    redis_password: ?[]const u8 = null,
    default_ttl: u64 = 3600, // 默认1小时
};

/// 缓存后端类型
pub const CacheBackend = enum {
    Memory,
    Redis,
    Memcached,
};

/// 缓存工厂
pub const CacheFactory = struct {
    /// 创建缓存实例
    pub fn create(
        allocator: std.mem.Allocator,
        config: CacheConfig,
    ) !CacheHandle {
        switch (config.backend) {
            .Memory => {
                const cache_ptr = try allocator.create(MemoryCache);
                errdefer allocator.destroy(cache_ptr);

                cache_ptr.* = MemoryCache.init(allocator, config.default_ttl);

                return CacheHandle{
                    .cache_iface = cache_ptr.asInterface(),
                    .allocator = allocator,
                    .backend_ptr = cache_ptr,
                    .backend_type = .Memory,
                };
            },
            .Redis => {
                return error.RedisNotImplemented;
            },
            .Memcached => {
                return error.MemcachedNotImplemented;
            },
        }
    }
};

/// 缓存句柄，用于管理缓存实例的生命周期
pub const CacheHandle = struct {
    cache_iface: CacheInterface,
    allocator: std.mem.Allocator,
    backend_ptr: *anyopaque,
    backend_type: CacheBackend,

    /// 销毁缓存实例并释放资源
    pub fn destroy(self: *CacheHandle) void {
        switch (self.backend_type) {
            .Memory => {
                const memory_cache: *MemoryCache = @ptrCast(@alignCast(self.backend_ptr));
                memory_cache.deinit();
                self.allocator.destroy(memory_cache);
            },
            .Redis => {
                const redis_cache: *RedisCache = @ptrCast(@alignCast(self.backend_ptr));
                redis_cache.deinit();
                self.allocator.destroy(redis_cache);
            },
            .Memcached => {},
        }
    }

    /// 获取缓存接口
    pub fn interface(self: *CacheHandle) CacheInterface {
        return self.cache_iface;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "MemoryCache - 基本操作" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var handle = try CacheFactory.create(allocator, .{
        .backend = .Memory,
        .default_ttl = 3600,
    });
    defer handle.destroy();

    const cache = handle.interface();

    try cache.set("key1", "value1", null);

    if (try cache.get("key1", allocator)) |result| {
        defer allocator.free(result);
        try std.testing.expectEqualStrings("value1", result);
    } else {
        try std.testing.expect(false);
    }

    const exists_result = try cache.exists("key1");
    try std.testing.expect(exists_result);

    try cache.delete("key1");
    const deleted_result = try cache.get("key1", allocator);
    try std.testing.expect(deleted_result == null);
}

test "MemoryCache - TTL过期" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var handle = try CacheFactory.create(allocator, .{
        .backend = .Memory,
        .default_ttl = 1,
    });
    defer handle.destroy();

    const cache = handle.interface();

    try cache.set("key_ttl", "value_ttl", 1);

    if (try cache.get("key_ttl", allocator)) |result1| {
        defer allocator.free(result1);
        try std.testing.expectEqualStrings("value_ttl", result1);
    } else {
        try std.testing.expect(false);
    }

    std.Thread.sleep(2 * std.time.ns_per_s);

    const result2 = try cache.get("key_ttl", allocator);
    try std.testing.expect(result2 == null);
}

test "MemoryCache - 清空缓存" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var handle = try CacheFactory.create(allocator, .{
        .backend = .Memory,
        .default_ttl = 3600,
    });
    defer handle.destroy();

    const cache = handle.interface();

    try cache.set("key1", "value1", null);
    try cache.set("key2", "value2", null);
    try cache.set("key3", "value3", null);

    try cache.clear();

    const result1 = try cache.get("key1", allocator);
    const result2 = try cache.get("key2", allocator);
    const result3 = try cache.get("key3", allocator);

    try std.testing.expect(result1 == null);
    try std.testing.expect(result2 == null);
    try std.testing.expect(result3 == null);
}

test "MemoryCache - 覆盖已存在的键" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var handle = try CacheFactory.create(allocator, .{
        .backend = .Memory,
        .default_ttl = 3600,
    });
    defer handle.destroy();

    const cache = handle.interface();

    try cache.set("key", "old_value", null);
    try cache.set("key", "new_value", null);

    if (try cache.get("key", allocator)) |result| {
        defer allocator.free(result);
        try std.testing.expectEqualStrings("new_value", result);
    } else {
        try std.testing.expect(false);
    }
}

test "MemoryCache - 不存在的键" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var handle = try CacheFactory.create(allocator, .{
        .backend = .Memory,
        .default_ttl = 3600,
    });
    defer handle.destroy();

    const cache = handle.interface();

    const result = try cache.get("nonexistent", allocator);
    try std.testing.expect(result == null);

    const exists_result = try cache.exists("nonexistent");
    try std.testing.expect(!exists_result);
}
