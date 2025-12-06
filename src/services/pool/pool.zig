//! 通用对象池
//!
//! 提供线程安全的对象池化管理，减少内存分配开销。
//!
//! ## 使用示例
//!
//! ```zig
//! const pool = @import("services/pool/pool.zig");
//!
//! // 创建缓冲区池
//! var buf_pool = pool.Pool([1024]u8).init(allocator, .{ .max_size = 100 });
//! defer buf_pool.deinit();
//!
//! // 获取缓冲区
//! var buf = try buf_pool.acquire();
//! defer buf_pool.release(buf);
//!
//! // 使用缓冲区
//! @memset(buf, 0);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

/// 对象池配置
pub const PoolConfig = struct {
    /// 最大对象数
    max_size: u32 = 64,
    /// 最小对象数（预创建）
    min_size: u32 = 0,
    /// 是否在释放时重置对象
    reset_on_release: bool = true,
};

/// 通用对象池
///
/// 池化管理任意类型的对象，减少频繁的内存分配。
pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        config: PoolConfig,
        items: std.ArrayListUnmanaged(*T),
        mutex: Mutex,
        stats: Stats,

        /// 统计信息
        pub const Stats = struct {
            /// 当前池大小
            pool_size: u32 = 0,
            /// 获取次数
            acquires: u64 = 0,
            /// 释放次数
            releases: u64 = 0,
            /// 创建次数
            creates: u64 = 0,
            /// 销毁次数
            destroys: u64 = 0,
            /// 命中次数（从池中获取）
            hits: u64 = 0,
            /// 未命中次数（需要新建）
            misses: u64 = 0,

            /// 命中率
            pub fn hitRate(self: Stats) f64 {
                const total = self.hits + self.misses;
                if (total == 0) return 0;
                return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
            }
        };

        /// 初始化对象池
        pub fn init(allocator: Allocator, config: PoolConfig) Self {
            return .{
                .allocator = allocator,
                .config = config,
                .items = .{},
                .mutex = .{},
                .stats = .{},
            };
        }

        /// 释放对象池
        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            for (self.items.items) |item| {
                self.allocator.destroy(item);
            }
            self.items.deinit(self.allocator);
        }

        /// 预热对象池
        pub fn warmup(self: *Self) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.stats.pool_size < self.config.min_size) {
                const item = try self.allocator.create(T);
                item.* = std.mem.zeroes(T);
                try self.items.append(self.allocator, item);
                self.stats.pool_size += 1;
                self.stats.creates += 1;
            }
        }

        /// 获取对象
        pub fn acquire(self: *Self) !*T {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.stats.acquires += 1;

            // 尝试从池中获取
            if (self.items.items.len > 0) {
                const item = self.items.items[self.items.items.len - 1];
                self.items.items.len -= 1;
                self.stats.pool_size -= 1;
                self.stats.hits += 1;
                return item;
            }

            // 池为空，创建新对象
            self.stats.misses += 1;
            self.stats.creates += 1;

            const item = try self.allocator.create(T);
            item.* = std.mem.zeroes(T);
            return item;
        }

        /// 释放对象回池
        pub fn release(self: *Self, item: *T) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.stats.releases += 1;

            // 重置对象
            if (self.config.reset_on_release) {
                item.* = std.mem.zeroes(T);
            }

            // 如果池未满，放回池中
            if (self.stats.pool_size < self.config.max_size) {
                self.items.append(self.allocator, item) catch {
                    self.allocator.destroy(item);
                    self.stats.destroys += 1;
                    return;
                };
                self.stats.pool_size += 1;
            } else {
                // 池已满，销毁对象
                self.allocator.destroy(item);
                self.stats.destroys += 1;
            }
        }

        /// 获取统计信息
        pub fn getStats(self: *Self) Stats {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.stats;
        }

        /// 清空池
        pub fn clear(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            for (self.items.items) |item| {
                self.allocator.destroy(item);
                self.stats.destroys += 1;
            }
            self.items.clearRetainingCapacity();
            self.stats.pool_size = 0;
        }

        /// 当前池大小
        pub fn size(self: *Self) u32 {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.stats.pool_size;
        }
    };
}

/// 字节缓冲区池
///
/// 专门用于管理固定大小的字节缓冲区
pub fn ByteBufferPool(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();
        const Buffer = [buffer_size]u8;

        inner: Pool(Buffer),

        pub fn init(allocator: Allocator, config: PoolConfig) Self {
            return .{ .inner = Pool(Buffer).init(allocator, config) };
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub fn acquire(self: *Self) !*Buffer {
            return self.inner.acquire();
        }

        pub fn release(self: *Self, buf: *Buffer) void {
            self.inner.release(buf);
        }

        pub fn getStats(self: *Self) Pool(Buffer).Stats {
            return self.inner.getStats();
        }
    };
}

/// 动态缓冲区池
///
/// 管理可变长度的缓冲区，按大小分级
pub const DynamicBufferPool = struct {
    const Self = @This();

    allocator: Allocator,
    // 不同大小的池：256, 1K, 4K, 16K, 64K
    pool_256: ByteBufferPool(256),
    pool_1k: ByteBufferPool(1024),
    pool_4k: ByteBufferPool(4096),
    pool_16k: ByteBufferPool(16384),
    pool_64k: ByteBufferPool(65536),

    pub fn init(allocator: Allocator) Self {
        const config = PoolConfig{ .max_size = 32 };
        return .{
            .allocator = allocator,
            .pool_256 = ByteBufferPool(256).init(allocator, config),
            .pool_1k = ByteBufferPool(1024).init(allocator, config),
            .pool_4k = ByteBufferPool(4096).init(allocator, config),
            .pool_16k = ByteBufferPool(16384).init(allocator, config),
            .pool_64k = ByteBufferPool(65536).init(allocator, config),
        };
    }

    pub fn deinit(self: *Self) void {
        self.pool_256.deinit();
        self.pool_1k.deinit();
        self.pool_4k.deinit();
        self.pool_16k.deinit();
        self.pool_64k.deinit();
    }

    /// 获取合适大小的缓冲区
    pub fn acquire(self: *Self, min_size: usize) ![]u8 {
        if (min_size <= 256) {
            const buf = try self.pool_256.acquire();
            return buf;
        } else if (min_size <= 1024) {
            const buf = try self.pool_1k.acquire();
            return buf;
        } else if (min_size <= 4096) {
            const buf = try self.pool_4k.acquire();
            return buf;
        } else if (min_size <= 16384) {
            const buf = try self.pool_16k.acquire();
            return buf;
        } else if (min_size <= 65536) {
            const buf = try self.pool_64k.acquire();
            return buf;
        } else {
            // 超大缓冲区直接分配
            return try self.allocator.alloc(u8, min_size);
        }
    }

    /// 释放缓冲区
    pub fn release(self: *Self, buf: []u8) void {
        if (buf.len == 256) {
            self.pool_256.release(@ptrCast(buf.ptr));
        } else if (buf.len == 1024) {
            self.pool_1k.release(@ptrCast(buf.ptr));
        } else if (buf.len == 4096) {
            self.pool_4k.release(@ptrCast(buf.ptr));
        } else if (buf.len == 16384) {
            self.pool_16k.release(@ptrCast(buf.ptr));
        } else if (buf.len == 65536) {
            self.pool_64k.release(@ptrCast(buf.ptr));
        } else {
            // 超大缓冲区直接释放
            self.allocator.free(buf);
        }
    }
};

/// RAII 风格的池化对象句柄
pub fn PooledHandle(comptime T: type) type {
    return struct {
        const Self = @This();

        pool: *Pool(T),
        item: *T,
        released: bool = false,

        /// 获取底层对象
        pub fn get(self: *Self) *T {
            return self.item;
        }

        /// 释放回池
        pub fn release(self: *Self) void {
            if (self.released) return;
            self.released = true;
            self.pool.release(self.item);
        }
    };
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建默认配置的对象池
pub fn createPool(comptime T: type, allocator: Allocator) Pool(T) {
    return Pool(T).init(allocator, .{});
}

/// 创建指定大小的对象池
pub fn createPoolWithSize(comptime T: type, allocator: Allocator, max_size: u32) Pool(T) {
    return Pool(T).init(allocator, .{ .max_size = max_size });
}

// ============================================================================
// 测试
// ============================================================================

test "Pool: 基本使用" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    // 获取对象
    const item1 = try pool.acquire();
    item1.* = 42;
    try std.testing.expectEqual(@as(i32, 42), item1.*);

    // 释放回池
    pool.release(item1);
    try std.testing.expectEqual(@as(u32, 1), pool.size());

    // 再次获取，应该复用
    const item2 = try pool.acquire();
    try std.testing.expectEqual(@as(i32, 0), item2.*); // 已重置
    pool.release(item2);
}

test "Pool: 统计信息" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    const item1 = try pool.acquire();
    const item2 = try pool.acquire();
    pool.release(item1);
    pool.release(item2);

    const item3 = try pool.acquire(); // 从池中获取
    pool.release(item3);

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.acquires);
    try std.testing.expectEqual(@as(u64, 3), stats.releases);
    try std.testing.expectEqual(@as(u64, 2), stats.creates);
    try std.testing.expectEqual(@as(u64, 1), stats.hits);
    try std.testing.expectEqual(@as(u64, 2), stats.misses);
}

test "Pool: 池满时销毁" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 2 });
    defer pool.deinit();

    const item1 = try pool.acquire();
    const item2 = try pool.acquire();
    const item3 = try pool.acquire();

    pool.release(item1);
    pool.release(item2);
    pool.release(item3); // 池已满，会被销毁

    try std.testing.expectEqual(@as(u32, 2), pool.size());

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.destroys);
}

test "ByteBufferPool: 缓冲区池" {
    const allocator = std.testing.allocator;
    var pool = ByteBufferPool(1024).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    const buf = try pool.acquire();
    @memset(buf, 'A');
    try std.testing.expectEqual(@as(u8, 'A'), buf[0]);
    try std.testing.expectEqual(@as(u8, 'A'), buf[1023]);

    pool.release(buf);
}

test "Pool: warmup 预热" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10, .min_size = 5 });
    defer pool.deinit();

    try pool.warmup();
    try std.testing.expectEqual(@as(u32, 5), pool.size());
}
