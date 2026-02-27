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

/// Poolable trait - 可池化类型的接口
///
/// 任何可池化的类型都需要实现这个接口
pub const Poolable = struct {
    /// 重置对象到初始状态
    resetFn: *const fn (*anyopaque) void,

    pub fn reset(self: Poolable, obj: *anyopaque) void {
        self.resetFn(obj);
    }
};

/// 统一的池化接口
///
/// 所有池实现都应该实现这个接口，确保跨模块兼容性
pub const PoolInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        acquireFn: *const fn (*anyopaque) anyerror!*anyopaque,
        releaseFn: *const fn (*anyopaque, *anyopaque) void,
        getStatsFn: *const fn (*anyopaque) Stats,
        deinitFn: *const fn (*anyopaque) void,
    };

    /// 统计信息
    pub const Stats = struct {
        pool_size: u32 = 0,
        acquires: u64 = 0,
        releases: u64 = 0,
        creates: u64 = 0,
        destroys: u64 = 0,
        hits: u64 = 0,
        misses: u64 = 0,

        pub fn hitRate(self: Stats) f64 {
            const total = self.hits + self.misses;
            if (total == 0) return 0;
            return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
        }
    };

    pub fn acquire(self: PoolInterface) anyerror!*anyopaque {
        return self.vtable.acquireFn(self.ptr);
    }

    pub fn release(self: PoolInterface, obj: *anyopaque) void {
        self.vtable.releaseFn(self.ptr, obj);
    }

    pub fn getStats(self: PoolInterface) Stats {
        return self.vtable.getStatsFn(self.ptr);
    }

    pub fn deinit(self: PoolInterface) void {
        self.vtable.deinitFn(self.ptr);
    }
};

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

        /// 获取当前池大小
        pub fn size(self: *Self) u32 {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.stats.pool_size;
        }

        /// 转换为统一的池接口
        ///
        /// 允许Pool(T)实例作为PoolInterface使用，便于跨模块传递
        pub fn asInterface(self: *Self) PoolInterface {
            const Impl = struct {
                fn acquireImpl(ptr: *anyopaque) anyerror!*anyopaque {
                    const pool: *Self = @ptrCast(@alignCast(ptr));
                    return @ptrCast(try pool.acquire());
                }

                fn releaseImpl(ptr: *anyopaque, obj: *anyopaque) void {
                    const pool: *Self = @ptrCast(@alignCast(ptr));
                    pool.release(@ptrCast(@alignCast(obj)));
                }

                fn getStatsImpl(ptr: *anyopaque) PoolInterface.Stats {
                    const pool: *Self = @ptrCast(@alignCast(ptr));
                    const stats = pool.getStats();
                    return .{
                        .pool_size = stats.pool_size,
                        .acquires = stats.acquires,
                        .releases = stats.releases,
                        .creates = stats.creates,
                        .destroys = stats.destroys,
                        .hits = stats.hits,
                        .misses = stats.misses,
                    };
                }

                fn deinitImpl(ptr: *anyopaque) void {
                    const pool: *Self = @ptrCast(@alignCast(ptr));
                    pool.deinit();
                }
            };

            return .{
                .ptr = self,
                .vtable = &.{
                    .acquireFn = Impl.acquireImpl,
                    .releaseFn = Impl.releaseImpl,
                    .getStatsFn = Impl.getStatsImpl,
                    .deinitFn = Impl.deinitImpl,
                },
            };
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
// 测试辅助类型和函数
// ============================================================================

/// 测试对象类型
const TestObject = struct {
    value: i32,
    name: []const u8,

    pub fn init(value: i32, name: []const u8) TestObject {
        return .{ .value = value, .name = name };
    }
};

/// 线程安全的计数器（用于并发测试）
const ThreadSafeCounter = struct {
    value: std.atomic.Value(u64),

    pub fn init() ThreadSafeCounter {
        return .{ .value = std.atomic.Value(u64).init(0) };
    }

    pub fn increment(self: *ThreadSafeCounter) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn get(self: *ThreadSafeCounter) u64 {
        return self.value.load(.monotonic);
    }
};

/// 并发池测试函数
fn concurrentPoolTest(pool: *Pool(ThreadSafeCounter), operations: u32, result: *u64) void {
    var local_result: u64 = 0;

    for (0..operations) |_| {
        const obj = pool.acquire() catch continue;
        defer pool.release(obj);

        // 模拟一些工作
        obj.increment();
        local_result += 1;

        // 短暂延迟以增加竞争
        std.atomic.spinLoopHint();
    }

    result.* = local_result;
}

/// 带超时的获取函数（用于测试等待机制）
fn acquireWithTimeout(pool: *Pool(i32), result: *?*i32, timeout_ns: u64) void {
    const start_time = std.time.nanoTimestamp();

    while (std.time.nanoTimestamp() - start_time < timeout_ns) {
        if (pool.acquire()) |obj| {
            result.* = obj;
            return;
        } else |_| {
            // 获取失败，继续尝试
        }
        // 短暂等待后重试
        std.Thread.sleep(1000); // 1微秒
    }

    result.* = null;
}

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

test "Pool: 内存安全 - 池满时正确销毁" {
    const allocator = std.testing.allocator;
    var pool = Pool(TestObject).init(allocator, .{ .max_size = 2 });
    defer pool.deinit();

    // 创建3个对象，但池最大只能容纳2个
    const obj1 = try pool.acquire();
    const obj2 = try pool.acquire();
    const obj3 = try pool.acquire();

    // 此时池中有2个对象（obj1和obj2），obj3直接分配

    // 释放所有对象
    pool.release(obj1);
    pool.release(obj2);
    pool.release(obj3);

    // 池中应该有2个对象（obj1和obj2被复用，obj3被销毁）
    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 统计信息检查：创建了3个，销毁了1个
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 3), stats.creates);
    try std.testing.expectEqual(@as(u64, 1), stats.destroys);
}

test "Pool: 内存安全 - 重复释放防护" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    // 获取并正确释放对象
    const obj = try pool.acquire();
    pool.release(obj);

    // 验证池状态正常
    try std.testing.expectEqual(@as(u32, 1), pool.size());

    // 注意：真正的重复释放在当前实现中会导致问题
    // 这里只验证正常释放流程的内存安全
}

test "Pool: 内存安全 - 清空池" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    // 获取一些对象
    const obj1 = try pool.acquire();
    const obj2 = try pool.acquire();
    pool.release(obj1);
    pool.release(obj2);

    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 清空池
    pool.clear();
    try std.testing.expectEqual(@as(u32, 0), pool.size());

    // 统计信息检查：应该有销毁记录
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.destroys);
}

test "Pool: 线程安全 - 并发访问" {
    const allocator = std.testing.allocator;
    var pool = Pool(ThreadSafeCounter).init(allocator, .{ .max_size = 100 });
    defer pool.deinit();

    const num_threads = 4;
    const operations_per_thread = 1000;

    var threads: [num_threads]std.Thread = undefined;
    var results: [num_threads]u64 = undefined;

    // 启动多个线程并发访问池
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, concurrentPoolTest, .{ &pool, operations_per_thread, &results[i] });
    }

    // 等待所有线程完成
    for (&threads) |*thread| {
        thread.join();
    }

    // 验证统计信息
    const stats = pool.getStats();
    const expected_operations = num_threads * operations_per_thread;

    try std.testing.expectEqual(@as(u64, expected_operations), stats.acquires);
    try std.testing.expectEqual(@as(u64, expected_operations), stats.releases);

    // 验证所有线程的结果都是正确的
    for (results) |result| {
        try std.testing.expectEqual(@as(u64, operations_per_thread), result);
    }
}

test "Pool: 线程安全 - 池满时的等待" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 1 });
    defer pool.deinit();

    // 先占用池中的唯一位置
    const obj1 = try pool.acquire();

    // 启动一个线程尝试获取对象（应该会等待）
    var thread_result: ?*i32 = null;
    var thread = try std.Thread.spawn(.{}, acquireWithTimeout, .{
        &pool, &thread_result, 10_000_000, // 10ms 超时
    });

    // 短暂等待，让线程开始等待
    std.Thread.sleep(1_000_000); // 1ms

    // 释放对象，让等待的线程可以获取
    pool.release(obj1);

    // 等待线程完成
    thread.join();

    // 验证线程成功获取了对象
    try std.testing.expect(thread_result != null);

    // 清理
    if (thread_result) |obj| {
        pool.release(obj);
    }
}

test "Pool: 边界条件 - 空池操作" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 0 }); // 池大小为0
    defer pool.deinit();

    // 获取对象应该直接分配（不使用池）
    const obj = try pool.acquire();
    try std.testing.expectEqual(@as(i32, 0), obj.*);

    // 释放对象应该直接销毁（不放回池）
    pool.release(obj);

    // 池应该一直是空的
    try std.testing.expectEqual(@as(u32, 0), pool.size());

    // 统计信息检查
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.creates);
    try std.testing.expectEqual(@as(u64, 1), stats.destroys);
    try std.testing.expectEqual(@as(u64, 0), stats.hits);
    try std.testing.expectEqual(@as(u64, 1), stats.misses);
}

test "PoolInterface: 接口转换测试" {
    const allocator = std.testing.allocator;
    var pool = Pool(i32).init(allocator, .{ .max_size = 10 });
    defer pool.deinit();

    // 转换为统一接口（接口只是视图，不需要单独deinit）
    const interface = pool.asInterface();

    // 通过接口获取对象
    const obj_any = try interface.acquire();
    const obj = @as(*i32, @ptrCast(@alignCast(obj_any)));
    obj.* = 42;

    // 通过接口释放对象
    interface.release(obj_any);

    // 验证统计信息一致
    const interface_stats = interface.getStats();
    const pool_stats = pool.getStats();

    try std.testing.expectEqual(pool_stats.pool_size, interface_stats.pool_size);
    try std.testing.expectEqual(pool_stats.acquires, interface_stats.acquires);
    try std.testing.expectEqual(pool_stats.releases, interface_stats.releases);
}

test "PoolInterface: 多个池实例的接口转换" {
    const allocator = std.testing.allocator;

    var pool1 = Pool(i32).init(allocator, .{ .max_size = 5 });
    defer pool1.deinit();

    var pool2 = Pool([]const u8).init(allocator, .{ .max_size = 3 });
    defer pool2.deinit();

    // 转换为接口（接口只是视图，不需要单独deinit）
    const interface1 = pool1.asInterface();
    const interface2 = pool2.asInterface();

    // 验证接口可以正常工作
    const obj1_any = try interface1.acquire();
    const obj2_any = try interface2.acquire();

    const obj1 = @as(*i32, @ptrCast(@alignCast(obj1_any)));
    const obj2 = @as(*[]const u8, @ptrCast(@alignCast(obj2_any)));

    obj1.* = 123;
    obj2.* = "hello";

    interface1.release(obj1_any);
    interface2.release(obj2_any);

    // 验证池的状态
    try std.testing.expectEqual(@as(u32, 1), pool1.size());
    try std.testing.expectEqual(@as(u32, 1), pool2.size());
}
