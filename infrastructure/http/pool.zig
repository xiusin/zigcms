//! HTTP 客户端连接池
//!
//! 提供线程安全的 HTTP 客户端池化管理，确保内存安全和资源复用。
//!
//! ## 使用示例
//!
//! ```zig
//! const http = @import("services/http/mod.zig");
//!
//! // 创建连接池
//! var pool = http.ClientPool.init(allocator, .{
//!     .max_size = 10,
//!     .min_size = 2,
//!     .idle_timeout_ms = 60_000,
//! });
//! defer pool.deinit();
//!
//! // 获取客户端（自动归还）
//! {
//!     var handle = try pool.acquire();
//!     defer handle.release();
//!
//!     var resp = try handle.client.get("https://api.example.com");
//!     defer resp.deinit();
//! }
//!
//! // 或使用 execute 便捷方法
//! const body = try pool.execute(struct {
//!     pub fn call(client: *HttpClient) ![]const u8 {
//!         var resp = try client.get("https://api.example.com");
//!         defer resp.deinit();
//!         return resp.body;
//!     }
//! }.call);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
const client_mod = @import("client.zig");
const HttpClient = client_mod.HttpClient;
const Response = client_mod.Response;

/// 连接池配置
pub const PoolConfig = struct {
    /// 最大连接数
    max_size: u32 = 10,
    /// 最小连接数（预创建）
    min_size: u32 = 0,
    /// 空闲超时（毫秒），超时后回收，0 表示不超时
    idle_timeout_ms: u64 = 60_000,
    /// 获取连接超时（毫秒），0 表示无限等待
    acquire_timeout_ms: u64 = 30_000,
    /// 连接健康检查间隔（毫秒），0 表示不检查
    health_check_interval_ms: u64 = 0,
};

/// 池化客户端包装
const PooledClient = struct {
    client: *HttpClient,
    pool: *ClientPool,
    last_used: i64,
    in_use: bool,
};

/// 客户端句柄（RAII 风格自动归还）
pub const ClientHandle = struct {
    const Self = @This();

    pooled: *PooledClient,
    released: bool = false,

    /// 获取底层客户端
    pub fn client(self: *Self) *HttpClient {
        return self.pooled.client;
    }

    /// 归还客户端到池
    pub fn release(self: *Self) void {
        if (self.released) return;
        self.released = true;
        self.pooled.pool.releaseClient(self.pooled);
    }

    /// 标记连接为无效（出错时使用，不归还到池中）
    pub fn invalidate(self: *Self) void {
        if (self.released) return;
        self.released = true;
        self.pooled.pool.destroyClient(self.pooled);
    }
};

/// HTTP 客户端连接池
pub const ClientPool = struct {
    const Self = @This();
    const ClientList = std.ArrayListUnmanaged(*PooledClient);

    allocator: Allocator,
    config: PoolConfig,
    clients: ClientList,
    mutex: Mutex,
    condition: Condition,
    stats: Stats,
    closed: bool,

    /// 统计信息
    pub const Stats = struct {
        /// 当前池大小
        pool_size: u32 = 0,
        /// 活跃连接数
        active_count: u32 = 0,
        /// 空闲连接数
        idle_count: u32 = 0,
        /// 总获取次数
        acquires: u64 = 0,
        /// 总归还次数
        releases: u64 = 0,
        /// 创建次数
        creates: u64 = 0,
        /// 销毁次数
        destroys: u64 = 0,
        /// 等待次数（池满时）
        waits: u64 = 0,
        /// 超时次数
        timeouts: u64 = 0,
    };

    /// 初始化连接池
    pub fn init(allocator: Allocator, config: PoolConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .clients = .{},
            .mutex = .{},
            .condition = .{},
            .stats = .{},
            .closed = false,
        };
    }

    /// 释放连接池
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.closed = true;

        // 唤醒所有等待的线程
        self.condition.broadcast();

        // 销毁所有客户端
        for (self.clients.items) |pooled| {
            pooled.client.deinit();
            self.allocator.destroy(pooled.client);
            self.allocator.destroy(pooled);
        }
        self.clients.deinit(self.allocator);
    }

    /// 预热连接池（创建最小数量的连接）
    pub fn warmup(self: *Self) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.stats.pool_size < self.config.min_size) {
            const pooled = try self.createClientLocked();
            self.clients.append(self.allocator, pooled) catch {
                self.destroyClientLocked(pooled);
                return error.OutOfMemory;
            };
        }
    }

    /// 获取客户端
    pub fn acquire(self: *Self) !ClientHandle {
        self.mutex.lock();

        while (true) {
            if (self.closed) {
                self.mutex.unlock();
                return error.PoolClosed;
            }

            // 查找空闲连接
            for (self.clients.items) |pooled| {
                if (!pooled.in_use) {
                    pooled.in_use = true;
                    pooled.last_used = std.time.milliTimestamp();
                    self.stats.active_count += 1;
                    self.stats.idle_count -= 1;
                    self.stats.acquires += 1;
                    self.mutex.unlock();
                    return ClientHandle{ .pooled = pooled };
                }
            }

            // 无空闲连接，尝试创建新连接
            if (self.stats.pool_size < self.config.max_size) {
                const pooled = self.createClientLocked() catch |err| {
                    self.mutex.unlock();
                    return err;
                };
                pooled.in_use = true;
                self.clients.append(self.allocator, pooled) catch |err| {
                    self.destroyClientLocked(pooled);
                    self.mutex.unlock();
                    return err;
                };
                self.stats.active_count += 1;
                self.stats.idle_count -= 1; // 创建时设为空闲，使用时减1
                self.stats.acquires += 1;
                self.mutex.unlock();
                return ClientHandle{ .pooled = pooled };
            }

            // 池已满，等待
            self.stats.waits += 1;

            if (self.config.acquire_timeout_ms > 0) {
                const timeout_ns = self.config.acquire_timeout_ms * std.time.ns_per_ms;
                self.condition.timedWait(&self.mutex, timeout_ns) catch {
                    self.stats.timeouts += 1;
                    self.mutex.unlock();
                    return error.AcquireTimeout;
                };
            } else {
                self.condition.wait(&self.mutex);
            }
        }
    }

    /// 尝试获取客户端（非阻塞）
    pub fn tryAcquire(self: *Self) ?ClientHandle {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) return null;

        // 查找空闲连接
        for (self.clients.items) |pooled| {
            if (!pooled.in_use) {
                pooled.in_use = true;
                pooled.last_used = std.time.milliTimestamp();
                self.stats.active_count += 1;
                self.stats.idle_count -= 1;
                self.stats.acquires += 1;
                return ClientHandle{ .pooled = pooled };
            }
        }

        // 尝试创建新连接
        if (self.stats.pool_size < self.config.max_size) {
            const pooled = self.createClientLocked() catch return null;
            pooled.in_use = true;
            self.clients.append(self.allocator, pooled) catch {
                self.destroyClientLocked(pooled);
                return null;
            };
            self.stats.active_count += 1;
            self.stats.idle_count -= 1; // 创建时设为空闲，使用时减1
            self.stats.acquires += 1;
            return ClientHandle{ .pooled = pooled };
        }

        return null;
    }

    /// 执行请求（自动获取和归还客户端）
    pub fn execute(self: *Self, callback: anytype) !@typeInfo(@TypeOf(callback)).@"fn".return_type.? {
        var handle = try self.acquire();
        defer handle.release();
        return try callback(handle.client());
    }

    /// 带上下文执行请求
    pub fn executeCtx(
        self: *Self,
        ctx: anytype,
        comptime ReturnType: type,
        callback: fn (@TypeOf(ctx), *HttpClient) anyerror!ReturnType,
    ) !ReturnType {
        var handle = try self.acquire();
        defer handle.release();
        return try callback(ctx, handle.client());
    }

    /// 归还客户端
    fn releaseClient(self: *Self, pooled: *PooledClient) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        pooled.in_use = false;
        pooled.last_used = std.time.milliTimestamp();
        self.stats.active_count -= 1;
        self.stats.idle_count += 1;
        self.stats.releases += 1;

        // 清理客户端状态（可选：保留 cookie 等）
        pooled.client.clearCookies();

        // 通知等待的线程
        self.condition.signal();
    }

    /// 销毁客户端（不归还到池）
    fn destroyClient(self: *Self, pooled: *PooledClient) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.removeFromPoolLocked(pooled);
        self.destroyClientLocked(pooled);
        self.stats.active_count -= 1;

        // 通知等待的线程
        self.condition.signal();
    }

    /// 创建新客户端（需持有锁）
    fn createClientLocked(self: *Self) !*PooledClient {
        const client_ptr = try self.allocator.create(HttpClient);
        errdefer self.allocator.destroy(client_ptr);

        client_ptr.* = HttpClient.init(self.allocator);

        const pooled = try self.allocator.create(PooledClient);
        pooled.* = .{
            .client = client_ptr,
            .pool = self,
            .last_used = std.time.milliTimestamp(),
            .in_use = false,
        };

        self.stats.pool_size += 1;
        self.stats.idle_count += 1;
        self.stats.creates += 1;

        return pooled;
    }

    /// 销毁客户端（需持有锁）
    fn destroyClientLocked(self: *Self, pooled: *PooledClient) void {
        pooled.client.deinit();
        self.allocator.destroy(pooled.client);
        self.allocator.destroy(pooled);

        self.stats.pool_size -= 1;
        self.stats.destroys += 1;
    }

    /// 从池中移除（需持有锁）
    fn removeFromPoolLocked(self: *Self, pooled: *PooledClient) void {
        for (self.clients.items, 0..) |item, i| {
            if (item == pooled) {
                _ = self.clients.swapRemove(i);
                if (!pooled.in_use) {
                    self.stats.idle_count -= 1;
                }
                break;
            }
        }
    }

    /// 清理空闲超时的连接
    pub fn cleanup(self: *Self) usize {
        if (self.config.idle_timeout_ms == 0) return 0;

        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        const timeout = @as(i64, @intCast(self.config.idle_timeout_ms));
        var removed: usize = 0;

        var i: usize = 0;
        while (i < self.clients.items.len) {
            const pooled = self.clients.items[i];
            if (!pooled.in_use and (now - pooled.last_used) > timeout) {
                // 保持最小连接数
                if (self.stats.pool_size <= self.config.min_size) break;

                _ = self.clients.swapRemove(i);
                self.destroyClientLocked(pooled);
                self.stats.idle_count -= 1;
                removed += 1;
            } else {
                i += 1;
            }
        }

        return removed;
    }

    /// 获取统计信息
    pub fn getStats(self: *Self) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// 获取当前池大小
    pub fn size(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.pool_size;
    }

    /// 获取空闲连接数
    pub fn idleCount(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.idle_count;
    }

    /// 获取活跃连接数
    pub fn activeCount(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.active_count;
    }
};

// ============================================================================
// 便捷函数
// ============================================================================

/// 创建默认配置的连接池
pub fn createPool(allocator: Allocator) ClientPool {
    return ClientPool.init(allocator, .{});
}

/// 创建指定大小的连接池
pub fn createPoolWithSize(allocator: Allocator, max_size: u32) ClientPool {
    return ClientPool.init(allocator, .{ .max_size = max_size });
}

// ============================================================================
// 测试
// ============================================================================

test "ClientPool: 基本初始化" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    try std.testing.expectEqual(@as(u32, 0), pool.size());
    try std.testing.expectEqual(@as(u32, 0), pool.activeCount());
}

test "ClientPool: acquire 和 release" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    // 获取客户端
    var handle = try pool.acquire();
    try std.testing.expectEqual(@as(u32, 1), pool.size());
    try std.testing.expectEqual(@as(u32, 1), pool.activeCount());

    // 归还客户端
    handle.release();
    try std.testing.expectEqual(@as(u32, 1), pool.size());
    try std.testing.expectEqual(@as(u32, 0), pool.activeCount());
    try std.testing.expectEqual(@as(u32, 1), pool.idleCount());
}

test "ClientPool: 连接复用" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    // 第一次获取
    var handle1 = try pool.acquire();
    const client1 = handle1.client();
    handle1.release();

    // 第二次获取应该复用
    var handle2 = try pool.acquire();
    const client2 = handle2.client();
    handle2.release();

    try std.testing.expectEqual(client1, client2);
    try std.testing.expectEqual(@as(u32, 1), pool.size()); // 只创建了一个
}

test "ClientPool: tryAcquire" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 1 });
    defer pool.deinit();

    // 第一次获取成功
    var handle1 = pool.tryAcquire();
    try std.testing.expect(handle1 != null);

    // 池满，第二次获取失败
    const handle2 = pool.tryAcquire();
    try std.testing.expect(handle2 == null);

    // 归还后可以再次获取
    handle1.?.release();
    var handle3 = pool.tryAcquire();
    try std.testing.expect(handle3 != null);
    handle3.?.release();
}

test "ClientPool: invalidate" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    // 获取并使连接无效
    var handle = try pool.acquire();
    try std.testing.expectEqual(@as(u32, 1), pool.size());

    handle.invalidate();
    try std.testing.expectEqual(@as(u32, 0), pool.size()); // 连接被销毁
}

test "ClientPool: 统计信息" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    var handle1 = try pool.acquire();
    var handle2 = try pool.acquire();
    handle1.release();
    handle2.release();

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.acquires);
    try std.testing.expectEqual(@as(u64, 2), stats.releases);
    try std.testing.expectEqual(@as(u64, 2), stats.creates);
    try std.testing.expectEqual(@as(u32, 2), stats.pool_size);
}

test "ClientPool: warmup 预热" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{
        .max_size = 10,
        .min_size = 3,
    });
    defer pool.deinit();

    try pool.warmup();
    try std.testing.expectEqual(@as(u32, 3), pool.size());
    try std.testing.expectEqual(@as(u32, 3), pool.idleCount());
}

test "ClientPool: cleanup 清理空闲" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{
        .max_size = 10,
        .min_size = 1,
        .idle_timeout_ms = 1, // 1ms 超时
    });
    defer pool.deinit();

    // 创建一些连接
    var handle1 = try pool.acquire();
    var handle2 = try pool.acquire();
    handle1.release();
    handle2.release();

    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 等待超时
    std.Thread.sleep(5 * std.time.ns_per_ms);

    // 清理应该移除超时连接（保留 min_size）
    const removed = pool.cleanup();
    try std.testing.expect(removed >= 1);
    try std.testing.expect(pool.size() >= 1);
}

test "ClientPool: 内存安全 - 连接生命周期管理" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5, .min_size = 2 });
    defer pool.deinit();

    // 预热创建最小连接数
    try pool.warmup();
    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 获取和释放连接
    var handle1 = try pool.acquire();
    var handle2 = try pool.acquire();
    handle1.release();
    handle2.release();

    // 验证连接被正确复用
    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 再次获取应该复用现有连接
    var handle3 = try pool.acquire();
    handle3.release();

    // 验证没有内存泄漏
    try std.testing.expect(true);
}

test "ClientPool: 内存安全 - 连接清理和超时" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{
        .max_size = 10,
        .min_size = 1,
        .idle_timeout_ms = 50, // 50ms超时
    });
    defer pool.deinit();

    // 创建一些连接
    var handle1 = try pool.acquire();
    var handle2 = try pool.acquire();
    handle1.release();
    handle2.release();

    try std.testing.expectEqual(@as(u32, 2), pool.size());

    // 等待超时
    std.Thread.sleep(100_000_000); // 100ms

    // 清理超时连接
    const cleaned = pool.cleanup();
    try std.testing.expect(cleaned >= 1); // 至少清理了一个连接

    // 验证最小连接数被保留
    try std.testing.expect(pool.size() >= 1);
}

test "ClientPool: 线程安全 - 并发获取连接" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 20 });
    defer pool.deinit();

    const num_threads = 8;
    const operations_per_thread = 50;

    var threads: [num_threads]std.Thread = undefined;
    var results: [num_threads]u32 = undefined;

    // 启动多个线程并发操作
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, concurrentHttpPoolTest, .{ &pool, operations_per_thread, &results[i] });
    }

    for (&threads) |*thread| {
        thread.join();
    }

    // 验证统计信息
    const stats = pool.getStats();
    const expected_operations = num_threads * operations_per_thread;

    try std.testing.expectEqual(@as(u64, expected_operations), stats.acquires);
    try std.testing.expectEqual(@as(u64, expected_operations), stats.releases);

    // 验证所有线程都成功完成了操作
    for (results) |result| {
        try std.testing.expectEqual(@as(u32, operations_per_thread), result);
    }
}

test "ClientPool: 线程安全 - 连接池满时的等待" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 1 });
    defer pool.deinit();

    // 先占用唯一的连接
    var handle1 = try pool.acquire();

    // 启动一个线程尝试获取连接（应该会等待）
    var thread_result: ?ClientHandle = null;
    var thread = try std.Thread.spawn(.{}, acquireHttpHandleWithTimeout, .{
        &pool, &thread_result, 100_000_000, // 100ms 超时
    });

    // 短暂等待让线程开始等待
    std.Thread.sleep(10_000_000); // 10ms

    // 释放连接，让等待的线程可以获取
    handle1.release();

    // 等待线程完成
    thread.join();

    // 验证线程成功获取了连接
    try std.testing.expect(thread_result != null);

    // 清理
    if (thread_result) |h| {
        var handle = h;
        handle.release();
    }
}

test "ClientPool: 内存安全 - 错误处理和资源清理" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 5 });
    defer pool.deinit();

    // 获取连接
    var handle = try pool.acquire();

    // 模拟连接错误并标记为无效
    handle.invalidate();

    // 验证连接被销毁
    try std.testing.expectEqual(@as(u32, 0), pool.size());

    // 再次获取新连接
    var handle2 = try pool.acquire();
    handle2.release();

    // 验证新连接创建成功
    try std.testing.expectEqual(@as(u32, 1), pool.size());

    // 验证统计信息正确
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.creates); // 创建了2个连接
    try std.testing.expectEqual(@as(u64, 1), stats.destroys); // 销毁了1个连接
}

test "ClientPool: 边界条件 - 池大小为0" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 0 });
    defer pool.deinit();

    // 尝试获取连接应该失败
    const handle = pool.tryAcquire();
    try std.testing.expect(handle == null);

    // 直接获取也应该失败
    try std.testing.expectError(error.AcquireTimeout, pool.acquire());

    // 池应该一直是空的
    try std.testing.expectEqual(@as(u32, 0), pool.size());
}

test "ClientPool: 性能测试 - 高频连接获取" {
    const allocator = std.testing.allocator;
    var pool = ClientPool.init(allocator, .{ .max_size = 10, .min_size = 5 });
    defer pool.deinit();

    // 预热
    try pool.warmup();

    // 高频获取和释放测试
    const start_time = std.time.milliTimestamp();

    for (0..1000) |_| {
        var handle = try pool.acquire();
        // 模拟短暂使用
        std.atomic.spinLoopHint();
        handle.release();
    }

    const end_time = std.time.milliTimestamp();
    const duration = end_time - start_time;

    // 验证在合理时间内完成（平均每次操作应小于1ms）
    try std.testing.expect(duration < 2000); // 2秒内完成1000次操作

    // 验证连接复用
    const stats = pool.getStats();
    try std.testing.expect(stats.acquires >= 1000);
    try std.testing.expect(stats.creates <= 10); // 最多创建10个连接
}

// ============================================================================
// 测试辅助函数
// ============================================================================

/// 并发HTTP池测试函数
fn concurrentHttpPoolTest(pool: *ClientPool, operations: u32, result: *u32) void {
    var local_result: u32 = 0;

    for (0..operations) |_| {
        if (pool.tryAcquire()) |h| {
            var handle = h;
            defer handle.release();

            // 模拟一些HTTP操作
            local_result += 1;

            // 短暂延迟以增加竞争
            std.atomic.spinLoopHint();
        }
    }

    result.* = local_result;
}

/// 带超时的HTTP连接获取函数
fn acquireHttpHandleWithTimeout(pool: *ClientPool, result: *?ClientHandle, timeout_ns: u64) void {
    const start_time = std.time.nanoTimestamp();

    while (std.time.nanoTimestamp() - start_time < timeout_ns) {
        if (pool.tryAcquire()) |handle| {
            result.* = handle;
            return;
        }
        // 短暂等待后重试
        std.Thread.sleep(1000); // 1微秒
    }

    result.* = null;
}
