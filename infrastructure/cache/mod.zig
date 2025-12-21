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
    pub fn create(
        allocator: std.mem.Allocator,
        config: CacheConfig,
    ) !Cache {
        _ = allocator;
        _ = config;
        // TODO: 实现缓存工厂
        return error.NotImplemented;
    }
};
