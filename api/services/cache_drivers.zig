//! 缓存驱动实现
//!
//! 提供不同缓存后端的具体实现：
//! - MemoryCacheDriver: 基于内存的缓存实现
//! - RedisCacheDriver: 基于 Redis 的缓存实现
//!
//! 所有驱动都实现 CacheInterface 接口，可以互相替换使用。

const std = @import("std");
const cache_contract = @import("cache_contract.zig");
const cache_service = @import("cache.zig");
const redis = @import("../../redis/redis.zig");

// ========================================
// 内存缓存驱动
// ========================================

/// 内存缓存驱动 - 使用 CacheService 实现
pub const MemoryCacheDriver = struct {
    cache_service: cache_service.CacheService,

    /// 创建内存缓存驱动
    pub fn init(allocator: std.mem.Allocator) MemoryCacheDriver {
        return .{
            .cache_service = cache_service.CacheService.init(allocator),
        };
    }

    /// 销毁内存缓存驱动
    pub fn deinit(self: *MemoryCacheDriver) void {
        self.cache_service.deinit();
    }

    /// 获取缓存接口
    pub fn asInterface(self: *MemoryCacheDriver) cache_contract.CacheInterface {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// 虚拟表
    const vtable: cache_contract.CacheInterface.VTable = .{
        .set = memorySet,
        .get = memoryGet,
        .del = memoryDel,
        .exists = memoryExists,
        .flush = memoryFlush,
        .stats = memoryStats,
        .cleanupExpired = memoryCleanupExpired,
        .delByPrefix = memoryDelByPrefix,
        .deinit = memoryDeinit,
    };

    /// 实现：设置缓存
    fn memorySet(ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.set(key, value, ttl);
    }

    /// 实现：获取缓存
    fn memoryGet(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.get(key);
    }

    /// 实现：删除缓存
    fn memoryDel(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.del(key);
    }

    /// 实现：检查存在
    fn memoryExists(ptr: *anyopaque, key: []const u8) bool {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.exists(key);
    }

    /// 实现：清空缓存
    fn memoryFlush(ptr: *anyopaque) anyerror!void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.flush();
    }

    /// 实现：获取统计
    fn memoryStats(ptr: *anyopaque) cache_contract.CacheStats {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        const stats = self.cache_service.stats();
        return .{ .count = stats.count, .expired = stats.expired };
    }

    /// 实现：清理过期项
    fn memoryCleanupExpired(ptr: *anyopaque) anyerror!void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.cleanupExpired();
    }

    /// 实现：按前缀删除
    fn memoryDelByPrefix(ptr: *anyopaque, prefix: []const u8) anyerror!void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        return self.cache_service.delByPrefix(prefix);
    }

    /// 实现：销毁
    fn memoryDeinit(ptr: *anyopaque) void {
        const self: *MemoryCacheDriver = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

// ========================================
// Redis 缓存驱动
// ========================================

/// Redis 缓存驱动配置
pub const RedisCacheConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 6379,
    password: ?[]const u8 = null,
    database: u8 = 0,
    max_connections: u32 = 10,
};

/// Redis 缓存驱动
pub const RedisCacheDriver = struct {
    pool: *redis.Pool,
    allocator: std.mem.Allocator,

    /// 创建 Redis 缓存驱动
    pub fn init(config: RedisCacheConfig, allocator: std.mem.Allocator) !RedisCacheDriver {
        const pool_options = redis.PoolOptions{
            .max_connections = config.max_connections,
            .conn_options = .{
                .host = config.host,
                .port = config.port,
                .password = config.password,
                .database = config.database,
            },
        };

        const pool = try redis.createPool(pool_options, allocator);

        return .{
            .pool = pool,
            .allocator = allocator,
        };
    }

    /// 销毁 Redis 缓存驱动
    pub fn deinit(self: *RedisCacheDriver) void {
        self.pool.deinit();
    }

    /// 获取缓存接口
    pub fn asInterface(self: *RedisCacheDriver) cache_contract.CacheInterface {
        return .{
            .ptr = self,
            .vtable = &redis_vtable,
        };
    }

    /// Redis 虚拟表
    const redis_vtable: cache_contract.CacheInterface.VTable = .{
        .set = redisSet,
        .get = redisGet,
        .del = redisDel,
        .exists = redisExists,
        .flush = redisFlush,
        .stats = redisStats,
        .cleanupExpired = redisCleanupExpired,
        .delByPrefix = redisDelByPrefix,
        .deinit = redisDeinit,
    };

    /// 实现：设置缓存
    fn redisSet(ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = try self.pool.acquire();
        defer conn.release();

        const strings = redis.strings(conn.conn);

        if (ttl) |t| {
            // 使用 SETEX 设置带过期时间的键
            try strings.setEx(key, t, value);
        } else {
            // 使用 SET 设置不带过期时间的键
            try strings.set(key, value);
        }
    }

    /// 实现：获取缓存
    fn redisGet(ptr: *anyopaque, key: []const u8) ?[]const u8 {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = self.pool.acquire() catch return null;
        defer conn.release();

        const strings = redis.strings(conn.conn);
        const reply = strings.get(key) catch return null;
        defer reply.deinit();

        return reply.string();
    }

    /// 实现：删除缓存
    fn redisDel(ptr: *anyopaque, key: []const u8) anyerror!void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = try self.pool.acquire();
        defer conn.release();

        const strings = redis.strings(conn.conn);
        try strings.del(&.{key});
    }

    /// 实现：检查存在
    fn redisExists(ptr: *anyopaque, key: []const u8) bool {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = self.pool.acquire() catch return false;
        defer conn.release();

        const strings = redis.strings(conn.conn);
        const result = strings.exists(&.{key}) catch return false;
        return result > 0;
    }

    /// 实现：清空缓存
    fn redisFlush(ptr: *anyopaque) anyerror!void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = try self.pool.acquire();
        defer conn.release();

        // 使用 FLUSHDB 清空当前数据库
        const reply = try conn.conn.do(&.{"FLUSHDB"});
        defer reply.deinit();
    }

    /// 实现：获取统计
    fn redisStats(ptr: *anyopaque) cache_contract.CacheStats {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = self.pool.acquire() catch return .{ .count = 0, .expired = 0 };
        defer conn.release();

        // Redis 不提供直接的活跃键数量统计，这里返回近似值
        // 可以使用 DBSIZE 获取数据库中的键数量
        const reply = conn.conn.do(&.{"DBSIZE"}) catch return .{ .count = 0, .expired = 0 };
        defer reply.deinit();

        const count = reply.integer() catch 0;

        // Redis 自动处理过期，expired 统计不可用
        return .{ .count = @intCast(count), .expired = 0 };
    }

    /// 实现：清理过期项
    fn redisCleanupExpired(ptr: *anyopaque) anyerror!void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = try self.pool.acquire();
        defer conn.release();

        // Redis 自动清理过期键，这里执行一个空操作
    }

    /// 实现：按前缀删除
    fn redisDelByPrefix(ptr: *anyopaque, prefix: []const u8) anyerror!void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));

        var conn = try self.pool.acquire();
        defer conn.release();

        // 构建 KEYS 模式
        var pattern_buf: [1024]u8 = undefined;
        const pattern = if (prefix.len + 1 <= pattern_buf.len) blk: {
            @memcpy(pattern_buf[0..prefix.len], prefix);
            pattern_buf[prefix.len] = '*';
            break :blk pattern_buf[0 .. prefix.len + 1];
        } else blk: {
            // 如果前缀太长，使用堆分配
            const pattern_alloc = try self.allocator.alloc(u8, prefix.len + 1);
            defer self.allocator.free(pattern_alloc);
            @memcpy(pattern_alloc[0..prefix.len], prefix);
            pattern_alloc[prefix.len] = '*';
            break :blk pattern_alloc;
        };

        // 使用 KEYS 命令查找匹配的键
        const keys_reply = try conn.conn.do(&.{ "KEYS", pattern });
        defer keys_reply.deinit();

        if (keys_reply.array()) |keys| {
            if (keys.len > 0) {
                // 构建 DEL 命令参数
                var args = redis.Args.init(self.allocator);
                defer args.deinit();

                _ = try args.add("DEL");
                for (keys) |key_reply| {
                    if (key_reply.string()) |key| {
                        _ = try args.add(key);
                    }
                }

                // 执行 DEL 命令
                const del_reply = try conn.conn.doArgs(&args);
                defer del_reply.deinit();
            }
        }
    }

    /// 实现：销毁
    fn redisDeinit(ptr: *anyopaque) void {
        const self: *RedisCacheDriver = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
