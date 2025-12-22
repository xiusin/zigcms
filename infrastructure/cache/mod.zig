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
/// @allocator-policy EXPLICIT-LIFETIME
/// @ownership [PARAM: allocator] NON-OWNING (caller retains ownership)
/// @thread-safety GUARDED_BY(mutex)
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

    /// 获取缓存值
    fn get(ptr: *anyopaque, key: []const u8) anyerror!?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |entry| {
            if (entry.isExpired()) {
                return null;
            }
            return entry.value;
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
    fn delete(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.fetchRemove(key)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value.value);
        }
    }

    /// 检查缓存是否存在
    fn exists(ptr: *anyopaque, key: []const u8) anyerror!bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.data.get(key)) |entry| {
            return !entry.isExpired();
        }
        return false;
    }

    /// 清空所有缓存
    fn clear(ptr: *anyopaque) anyerror!void {
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

    /// 获取 VTable
    fn vtable() *const Cache.VTable {
        const vtable_instance = Cache.VTable{
            .get = get,
            .set = set,
            .delete = delete,
            .exists = exists,
            .clear = clear,
        };
        return &vtable_instance;
    }
};

/// Redis缓存实现
/// @allocator-policy EXPLICIT-LIFETIME
/// @ownership [PARAM: allocator] NON-OWNING (caller retains ownership)
/// @thread-safety GUARDED_BY(redis connection mutex)
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
        self.connection.close();
    }

    /// 获取缓存值
    fn get(ptr: *anyopaque, key: []const u8) anyerror!?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{ "GET", key });
        defer reply.deinit();

        if (reply.string()) |value| {
            return try self.allocator.dupe(u8, value);
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
    fn delete(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{ "DEL", key });
        defer reply.deinit();
    }

    /// 检查缓存是否存在
    fn exists(ptr: *anyopaque, key: []const u8) anyerror!bool {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{ "EXISTS", key });
        defer reply.deinit();

        if (reply.integer()) |count| {
            return count > 0;
        }
        return false;
    }

    /// 清空所有缓存
    fn clear(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var reply = try self.connection.sendCommand(&.{"FLUSHDB"});
        defer reply.deinit();
    }

    /// 获取 VTable
    fn vtable() *const Cache.VTable {
        const vtable_instance = Cache.VTable{
            .get = get,
            .set = set,
            .delete = delete,
            .exists = exists,
            .clear = clear,
        };
        return &vtable_instance;
    }
};

/// 缓存接口
pub const Cache = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        get: *const fn (*anyopaque, []const u8) anyerror!?[]const u8,
        set: *const fn (*anyopaque, []const u8, []const u8, ?u64) anyerror!void,
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
        exists: *const fn (*anyopaque, []const u8) anyerror!bool,
        clear: *const fn (*anyopaque) anyerror!void,
    };

    /// 获取缓存值
    pub fn get(self: @This(), key: []const u8) !?[]const u8 {
        return self.vtable.get(self.ptr, key);
    }

    /// 设置缓存值
    pub fn set(self: @This(), key: []const u8, value: []const u8, ttl: ?u64) !void {
        return self.vtable.set(self.ptr, key, value, ttl);
    }

    /// 删除缓存
    pub fn delete(self: @This(), key: []const u8) !void {
        return self.vtable.delete(self.ptr, key);
    }

    /// 检查缓存是否存在
    pub fn exists(self: @This(), key: []const u8) !bool {
        return self.vtable.exists(self.ptr, key);
    }

    /// 清空所有缓存
    pub fn clear(self: @This()) !void {
        return self.vtable.clear(self.ptr);
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
    /// @allocator-policy EXPLICIT-LIFETIME
    /// @ownership [PARAM: allocator] NON-OWNING (caller retains ownership)
    /// @leak-risk MITIGATED_BY caller must call destroy() on returned cache
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
                    .cache = Cache{
                        .ptr = cache_ptr,
                        .vtable = &memory_cache_vtable,
                    },
                    .allocator = allocator,
                    .backend_ptr = cache_ptr,
                    .backend_type = .Memory,
                };
            },
            .Redis => {
                const redis_conn = try redis.connect(.{
                    .host = config.redis_host,
                    .port = config.redis_port,
                    .password = config.redis_password,
                }, allocator);
                errdefer redis_conn.close();

                const cache_ptr = try allocator.create(RedisCache);
                errdefer allocator.destroy(cache_ptr);

                cache_ptr.* = RedisCache.init(allocator, redis_conn, config.default_ttl);

                return CacheHandle{
                    .cache = Cache{
                        .ptr = cache_ptr,
                        .vtable = &redis_cache_vtable,
                    },
                    .allocator = allocator,
                    .backend_ptr = cache_ptr,
                    .backend_type = .Redis,
                };
            },
            .Memcached => {
                return error.MemcachedNotImplemented;
            },
        }
    }

    const memory_cache_vtable = Cache.VTable{
        .get = MemoryCache.get,
        .set = MemoryCache.set,
        .delete = MemoryCache.delete,
        .exists = MemoryCache.exists,
        .clear = MemoryCache.clear,
    };

    const redis_cache_vtable = Cache.VTable{
        .get = RedisCache.get,
        .set = RedisCache.set,
        .delete = RedisCache.delete,
        .exists = RedisCache.exists,
        .clear = RedisCache.clear,
    };
};

/// 缓存句柄，用于管理缓存实例的生命周期
/// @ownership OWNING (must call destroy() to free resources)
pub const CacheHandle = struct {
    cache: Cache,
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
    pub fn interface(self: *CacheHandle) Cache {
        return self.cache;
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

    const result = try cache.get("key1");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("value1", result.?);

    const exists_result = try cache.exists("key1");
    try std.testing.expect(exists_result);

    try cache.delete("key1");
    const deleted_result = try cache.get("key1");
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

    const result1 = try cache.get("key_ttl");
    try std.testing.expect(result1 != null);

    std.Thread.sleep(2 * std.time.ns_per_s);

    const result2 = try cache.get("key_ttl");
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

    const result1 = try cache.get("key1");
    const result2 = try cache.get("key2");
    const result3 = try cache.get("key3");

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

    const result = try cache.get("key");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("new_value", result.?);
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

    const result = try cache.get("nonexistent");
    try std.testing.expect(result == null);

    const exists_result = try cache.exists("nonexistent");
    try std.testing.expect(!exists_result);
}
