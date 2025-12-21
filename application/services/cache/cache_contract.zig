//! 缓存契约接口 (Cache Contract Interface)
//!
//! 该模块定义了缓存服务的统一契约接口，所有缓存实现都必须遵循此契约。
//! 支持多种缓存后端（内存、Redis、Memcached、文件等），可以无缝切换。
//!
//! ## 设计原则
//!
//! - **统一契约**: 所有缓存实现遵循相同的接口，便于替换和测试
//! - **线程安全**: 所有操作都应该是线程安全的
//! - **TTL 支持**: 支持缓存项的过期时间管理
//! - **内存安全**: 明确的内存所有权和生命周期管理
//!
//! ## 标准方法
//!
//! | 方法 | 描述 |
//! |------|------|
//! | `set` | 设置缓存项，支持可选的 TTL |
//! | `get` | 获取缓存项，过期项返回 null |
//! | `del` | 删除指定缓存项 |
//! | `exists` | 检查缓存项是否存在且未过期 |
//! | `flush` | 清空所有缓存项 |
//! | `stats` | 获取缓存统计信息 |
//! | `cleanupExpired` | 清理所有过期项 |
//! | `delByPrefix` | 根据前缀批量删除缓存项 |
//! | `deinit` | 销毁缓存实例，释放所有资源 |
//!
//! ## 使用示例
//!
//! ```zig
//! const cache_contract = @import("cache_contract.zig");
//!
//! // 通过接口使用缓存（不关心具体实现）
//! fn useCache(cache: cache_contract.CacheInterface) !void {
//!     // 设置缓存，TTL 为 300 秒
//!     try cache.set("user:1:name", "张三", 300);
//!
//!     // 获取缓存
//!     if (cache.get("user:1:name")) |name| {
//!         std.debug.print("用户名: {s}\n", .{name});
//!     }
//!
//!     // 检查是否存在
//!     if (cache.exists("user:1:name")) {
//!         // 缓存存在且未过期
//!     }
//!
//!     // 删除缓存
//!     try cache.del("user:1:name");
//!
//!     // 按前缀删除
//!     try cache.delByPrefix("user:1:");
//!
//!     // 获取统计信息
//!     const stats = cache.stats();
//!     std.debug.print("缓存项数: {d}, 过期项数: {d}\n", .{stats.count, stats.expired});
//! }
//! ```
//!
//! ## 实现指南
//!
//! 要实现此接口，需要：
//! 1. 创建一个结构体包含缓存状态
//! 2. 实现所有 VTable 中定义的方法
//! 3. 提供 `asInterface()` 方法返回 CacheInterface
//!
//! ```zig
//! pub const MyCacheDriver = struct {
//!     // ... 内部状态 ...
//!
//!     pub fn asInterface(self: *MyCacheDriver) CacheInterface {
//!         return .{
//!             .ptr = self,
//!             .vtable = &vtable,
//!         };
//!     }
//!
//!     const vtable: CacheInterface.VTable = .{
//!         .set = mySet,
//!         .get = myGet,
//!         // ... 其他方法 ...
//!     };
//! };
//! ```

const std = @import("std");

/// 缓存统计信息
///
/// 提供缓存的运行时统计数据，用于监控和调试。
pub const CacheStats = struct {
    /// 当前有效（未过期）的缓存项数量
    count: usize,

    /// 已过期但尚未清理的缓存项数量
    expired: usize,

    /// 缓存命中次数（可选，某些实现可能不支持）
    hits: usize = 0,

    /// 缓存未命中次数（可选，某些实现可能不支持）
    misses: usize = 0,

    /// 计算命中率
    /// 返回 0.0 到 1.0 之间的值，如果没有访问则返回 0.0
    pub fn hitRate(self: CacheStats) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

/// 缓存错误类型
pub const CacheError = error{
    /// 设置缓存失败
    SetFailed,
    /// 获取缓存失败
    GetFailed,
    /// 序列化失败
    SerializationFailed,
    /// 反序列化失败
    DeserializationFailed,
    /// 连接失败（用于远程缓存）
    ConnectionFailed,
    /// 键不存在
    KeyNotFound,
    /// 内存不足
    OutOfMemory,
};

/// 缓存接口 - 定义缓存服务的统一契约
///
/// 所有缓存实现都必须遵循此接口，确保可以无缝切换不同的缓存后端。
/// 使用 vtable 模式实现多态，避免运行时类型检查。
pub const CacheInterface = struct {
    /// 上下文指针，指向具体的缓存实现实例
    ptr: *anyopaque,

    /// 虚拟表，包含所有缓存操作的方法指针
    vtable: *const VTable,

    /// 虚拟表结构体 - 定义所有缓存操作的函数签名
    pub const VTable = struct {
        /// 设置缓存项
        ///
        /// 参数:
        /// - ptr: 缓存实现的上下文指针
        /// - key: 缓存键（UTF-8 字符串）
        /// - value: 缓存值（字节数组）
        /// - ttl: 过期时间（秒），null 表示使用默认 TTL
        ///
        /// 错误:
        /// - OutOfMemory: 内存分配失败
        /// - SetFailed: 设置操作失败
        set: *const fn (ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void,

        /// 获取缓存项
        ///
        /// 参数:
        /// - ptr: 缓存实现的上下文指针
        /// - key: 缓存键
        ///
        /// 返回:
        /// - 缓存值（如果存在且未过期）
        /// - null（如果不存在或已过期）
        ///
        /// 注意: 返回的切片指向缓存内部存储，不应修改或释放
        get: *const fn (ptr: *anyopaque, key: []const u8) ?[]const u8,

        /// 删除缓存项
        ///
        /// 参数:
        /// - ptr: 缓存实现的上下文指针
        /// - key: 要删除的缓存键
        ///
        /// 注意: 如果键不存在，不会返回错误
        del: *const fn (ptr: *anyopaque, key: []const u8) anyerror!void,

        /// 检查缓存项是否存在
        ///
        /// 参数:
        /// - ptr: 缓存实现的上下文指针
        /// - key: 要检查的缓存键
        ///
        /// 返回:
        /// - true: 键存在且未过期
        /// - false: 键不存在或已过期
        exists: *const fn (ptr: *anyopaque, key: []const u8) bool,

        /// 清空所有缓存
        ///
        /// 删除所有缓存项，释放相关内存。
        /// 此操作不可逆，请谨慎使用。
        flush: *const fn (ptr: *anyopaque) anyerror!void,

        /// 获取缓存统计信息
        ///
        /// 返回当前缓存的统计数据，包括：
        /// - 有效缓存项数量
        /// - 过期缓存项数量
        /// - 命中/未命中统计（如果支持）
        stats: *const fn (ptr: *anyopaque) CacheStats,

        /// 清理过期项
        ///
        /// 主动清理所有已过期的缓存项，释放内存。
        /// 建议定期调用此方法以防止内存泄漏。
        cleanupExpired: *const fn (ptr: *anyopaque) anyerror!void,

        /// 根据前缀删除缓存项
        ///
        /// 删除所有以指定前缀开头的缓存项。
        /// 适用于批量清理相关缓存，如清理某用户的所有缓存。
        ///
        /// 参数:
        /// - ptr: 缓存实现的上下文指针
        /// - prefix: 键前缀
        ///
        /// 示例:
        /// - delByPrefix("user:1:") 删除所有以 "user:1:" 开头的键
        delByPrefix: *const fn (ptr: *anyopaque, prefix: []const u8) anyerror!void,

        /// 销毁缓存实例
        ///
        /// 释放缓存实例占用的所有资源，包括：
        /// - 所有缓存项的内存
        /// - 内部数据结构
        /// - 连接池（如果有）
        ///
        /// 调用此方法后，缓存实例不可再使用。
        deinit: *const fn (ptr: *anyopaque) void,
    };

    // ========================================
    // 便捷方法 - 委托给 vtable 中的实现
    // ========================================

    /// 设置缓存项
    ///
    /// 将键值对存入缓存，可选指定过期时间。
    ///
    /// 参数:
    /// - key: 缓存键（建议使用命名空间格式，如 "user:1:profile"）
    /// - value: 缓存值（字节数组）
    /// - ttl: 过期时间（秒），null 表示使用默认 TTL
    ///
    /// 示例:
    /// ```zig
    /// try cache.set("user:1:name", "张三", 300); // 5分钟过期
    /// try cache.set("config:app", config_json, null); // 使用默认 TTL
    /// ```
    pub fn set(self: CacheInterface, key: []const u8, value: []const u8, ttl: ?u64) !void {
        return self.vtable.set(self.ptr, key, value, ttl);
    }

    /// 获取缓存项
    ///
    /// 根据键获取缓存值，如果键不存在或已过期则返回 null。
    ///
    /// 参数:
    /// - key: 缓存键
    ///
    /// 返回:
    /// - 缓存值切片（指向内部存储，不要修改或释放）
    /// - null（如果不存在或已过期）
    ///
    /// 示例:
    /// ```zig
    /// if (cache.get("user:1:name")) |name| {
    ///     std.debug.print("用户名: {s}\n", .{name});
    /// } else {
    ///     std.debug.print("缓存未命中\n", .{});
    /// }
    /// ```
    pub fn get(self: CacheInterface, key: []const u8) ?[]const u8 {
        return self.vtable.get(self.ptr, key);
    }

    /// 删除缓存项
    ///
    /// 从缓存中删除指定键的项。如果键不存在，不会返回错误。
    ///
    /// 参数:
    /// - key: 要删除的缓存键
    pub fn del(self: CacheInterface, key: []const u8) !void {
        return self.vtable.del(self.ptr, key);
    }

    /// 检查缓存项是否存在
    ///
    /// 检查指定键是否存在于缓存中且未过期。
    ///
    /// 参数:
    /// - key: 要检查的缓存键
    ///
    /// 返回:
    /// - true: 键存在且未过期
    /// - false: 键不存在或已过期
    pub fn exists(self: CacheInterface, key: []const u8) bool {
        return self.vtable.exists(self.ptr, key);
    }

    /// 清空所有缓存
    ///
    /// 删除所有缓存项并释放相关内存。
    /// 此操作不可逆，请谨慎使用。
    pub fn flush(self: CacheInterface) !void {
        return self.vtable.flush(self.ptr);
    }

    /// 获取缓存统计信息
    ///
    /// 返回当前缓存的运行时统计数据。
    pub fn stats(self: CacheInterface) CacheStats {
        return self.vtable.stats(self.ptr);
    }

    /// 清理过期项
    ///
    /// 主动清理所有已过期的缓存项。
    /// 建议在低峰期定期调用此方法。
    pub fn cleanupExpired(self: CacheInterface) !void {
        return self.vtable.cleanupExpired(self.ptr);
    }

    /// 根据前缀删除缓存项
    ///
    /// 批量删除所有以指定前缀开头的缓存项。
    ///
    /// 参数:
    /// - prefix: 键前缀
    ///
    /// 示例:
    /// ```zig
    /// // 删除用户 1 的所有缓存
    /// try cache.delByPrefix("user:1:");
    /// ```
    pub fn delByPrefix(self: CacheInterface, prefix: []const u8) !void {
        return self.vtable.delByPrefix(self.ptr, prefix);
    }

    /// 销毁缓存实例
    ///
    /// 释放缓存实例占用的所有资源。
    /// 调用后缓存实例不可再使用。
    pub fn deinit(self: CacheInterface) void {
        self.vtable.deinit(self.ptr);
    }

    // ========================================
    // 扩展便捷方法
    // ========================================

    /// 获取或设置缓存（Remember 模式）
    ///
    /// 如果缓存存在则返回缓存值，否则调用回调函数生成值并缓存。
    /// 这是 Laravel 风格的 remember 方法。
    ///
    /// 参数:
    /// - key: 缓存键
    /// - ttl: 过期时间（秒）
    /// - loader: 加载函数，当缓存未命中时调用
    /// - allocator: 用于分配返回值的分配器
    ///
    /// 返回:
    /// - 缓存值或新生成的值
    ///
    /// 示例:
    /// ```zig
    /// const user = try cache.getOrSet("user:1", 300, struct {
    ///     pub fn load() ![]const u8 {
    ///         return try db.findUser(1);
    ///     }
    /// }.load, allocator);
    /// ```
    pub fn getOrSet(
        self: CacheInterface,
        key: []const u8,
        ttl: ?u64,
        comptime loader: fn () anyerror![]const u8,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        if (self.get(key)) |value| {
            return try allocator.dupe(u8, value);
        }

        const value = try loader();
        try self.set(key, value, ttl);
        return value;
    }

    /// 获取并删除缓存（Pull 模式）
    ///
    /// 获取缓存值后立即删除该缓存项。
    /// 适用于一次性使用的缓存，如验证码。
    ///
    /// 参数:
    /// - key: 缓存键
    /// - allocator: 用于复制返回值的分配器
    ///
    /// 返回:
    /// - 缓存值（调用者拥有内存）
    /// - null（如果不存在）
    pub fn pull(self: CacheInterface, key: []const u8, allocator: std.mem.Allocator) !?[]u8 {
        if (self.get(key)) |value| {
            const result = try allocator.dupe(u8, value);
            try self.del(key);
            return result;
        }
        return null;
    }

    /// 仅在键不存在时设置（Add 模式）
    ///
    /// 只有当键不存在时才设置缓存，如果键已存在则不做任何操作。
    /// 适用于防止缓存覆盖的场景。
    ///
    /// 参数:
    /// - key: 缓存键
    /// - value: 缓存值
    /// - ttl: 过期时间（秒）
    ///
    /// 返回:
    /// - true: 成功设置（键之前不存在）
    /// - false: 未设置（键已存在）
    pub fn add(self: CacheInterface, key: []const u8, value: []const u8, ttl: ?u64) !bool {
        if (self.exists(key)) {
            return false;
        }
        try self.set(key, value, ttl);
        return true;
    }

    /// 永久设置缓存（Forever 模式）
    ///
    /// 设置一个永不过期的缓存项（使用非常大的 TTL）。
    ///
    /// 参数:
    /// - key: 缓存键
    /// - value: 缓存值
    pub fn forever(self: CacheInterface, key: []const u8, value: []const u8) !void {
        // 使用 100 年作为"永久"的 TTL
        const forever_ttl: u64 = 100 * 365 * 24 * 60 * 60;
        try self.set(key, value, forever_ttl);
    }
};

// ========================================
// 测试
// ========================================

test "CacheStats hitRate calculation" {
    const stats1 = CacheStats{ .count = 10, .expired = 2, .hits = 80, .misses = 20 };
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), stats1.hitRate(), 0.001);

    const stats2 = CacheStats{ .count = 0, .expired = 0, .hits = 0, .misses = 0 };
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), stats2.hitRate(), 0.001);

    const stats3 = CacheStats{ .count = 5, .expired = 0, .hits = 100, .misses = 0 };
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), stats3.hitRate(), 0.001);
}
