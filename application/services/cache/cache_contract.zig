//! 缓存契约接口 - 定义缓存服务的抽象接口
//!
//! 该接口定义了缓存服务的基本操作，所有缓存实现都应符合此契约。
//! 支持不同的缓存后端（如内存、Redis、文件等）。

const std = @import("std");

/// 缓存统计信息
pub const CacheStats = struct {
    count: usize,
    expired: usize,
};

/// 缓存接口 - 定义缓存服务的抽象操作
pub const CacheInterface = struct {
    /// 上下文指针，指向具体的缓存实现
    ptr: *anyopaque,

    /// 虚拟表，包含所有缓存操作的方法指针
    vtable: *const VTable,

    /// 虚拟表结构体
    pub const VTable = struct {
        /// 设置缓存项
        set: *const fn (ptr: *anyopaque, key: []const u8, value: []const u8, ttl: ?u64) anyerror!void,

        /// 获取缓存项
        get: *const fn (ptr: *anyopaque, key: []const u8) ?[]const u8,

        /// 删除缓存项
        del: *const fn (ptr: *anyopaque, key: []const u8) anyerror!void,

        /// 检查缓存项是否存在
        exists: *const fn (ptr: *anyopaque, key: []const u8) bool,

        /// 清空所有缓存
        flush: *const fn (ptr: *anyopaque) anyerror!void,

        /// 获取缓存统计信息
        stats: *const fn (ptr: *anyopaque) CacheStats,

        /// 清理过期项
        cleanupExpired: *const fn (ptr: *anyopaque) anyerror!void,

        /// 根据前缀删除缓存项
        delByPrefix: *const fn (ptr: *anyopaque, prefix: []const u8) anyerror!void,

        /// 销毁缓存实例
        deinit: *const fn (ptr: *anyopaque) void,
    };

    /// 设置缓存项
    pub fn set(self: CacheInterface, key: []const u8, value: []const u8, ttl: ?u64) !void {
        return self.vtable.set(self.ptr, key, value, ttl);
    }

    /// 获取缓存项
    pub fn get(self: CacheInterface, key: []const u8) ?[]const u8 {
        return self.vtable.get(self.ptr, key);
    }

    /// 删除缓存项
    pub fn del(self: CacheInterface, key: []const u8) !void {
        return self.vtable.del(self.ptr, key);
    }

    /// 检查缓存项是否存在
    pub fn exists(self: CacheInterface, key: []const u8) bool {
        return self.vtable.exists(self.ptr, key);
    }

    /// 清空所有缓存
    pub fn flush(self: CacheInterface) !void {
        return self.vtable.flush(self.ptr);
    }

    /// 获取缓存统计信息
    pub fn stats(self: CacheInterface) CacheStats {
        return self.vtable.stats(self.ptr);
    }

    /// 清理过期项
    pub fn cleanupExpired(self: CacheInterface) !void {
        return self.vtable.cleanupExpired(self.ptr);
    }

    /// 根据前缀删除缓存项
    pub fn delByPrefix(self: CacheInterface, prefix: []const u8) !void {
        return self.vtable.delByPrefix(self.ptr, prefix);
    }

    /// 销毁缓存实例
    pub fn deinit(self: CacheInterface) void {
        self.vtable.deinit(self.ptr);
    }
};
