//! Redis 连接池实现
//!
//! 连接池用于管理和复用 Redis 连接，避免频繁创建/销毁连接的开销。
//!
//! ## 为什么需要连接池？
//!
//! 1. **减少连接开销**: TCP 握手和 Redis 认证都需要时间
//! 2. **限制资源使用**: 防止创建过多连接耗尽系统资源
//! 3. **提高吞吐量**: 复用连接可以处理更多请求
//!
//! ## Zig vs Go: 连接池实现对比
//!
//! Go 可以使用 channel 实现简单的连接池：
//! ```go
//! type Pool struct {
//!     conns chan *Conn
//! }
//!
//! func (p *Pool) Get() *Conn {
//!     select {
//!     case conn := <-p.conns:
//!         return conn
//!     default:
//!         return newConn()
//!     }
//! }
//! ```
//!
//! Zig 没有内置的 channel，我们使用队列和条件变量实现

const std = @import("std");
const types = @import("types.zig");
const connection = @import("connection.zig");

const Connection = connection.Connection;
const PoolOptions = types.PoolOptions;
const ConnectOptions = types.ConnectOptions;
const RedisError = types.RedisError;

/// 池化连接包装器
///
/// ## 为什么需要包装器？
///
/// 池化连接需要额外的元数据：
/// - 创建时间：判断是否超过最大生命周期
/// - 最后使用时间：判断是否空闲超时
/// - 所属连接池：释放时归还到正确的池
///
/// 这相当于 Go 中的 ActiveConn 结构
pub const PooledConnection = struct {
    /// 底层连接
    conn: *Connection,
    /// 创建时间（纳秒时间戳）
    created_at: i128,
    /// 最后使用时间
    last_used_at: i128,
    /// 所属连接池
    pool: *Pool,
    /// 是否已归还
    returned: bool = false,

    /// 获取底层连接
    ///
    /// ## 使用方式
    ///
    /// ```zig
    /// var pooled = try pool.acquire();
    /// defer pooled.release();
    ///
    /// const conn = pooled.connection();
    /// var reply = try conn.get("key");
    /// defer reply.deinit();
    /// ```
    pub fn connection(self: *PooledConnection) *Connection {
        return self.conn;
    }

    /// 释放连接回池
    ///
    /// ## 重要：必须调用此方法！
    ///
    /// 如果忘记调用 release()：
    /// 1. 连接不会归还到池中
    /// 2. 池的可用连接会减少
    /// 3. 最终导致 PoolExhausted 错误
    ///
    /// 使用 defer 确保释放：
    /// ```zig
    /// var pooled = try pool.acquire();
    /// defer pooled.release(); // 无论如何都会执行
    /// ```
    pub fn release(self: *PooledConnection) void {
        if (self.returned) {
            return;
        }
        self.returned = true;
        self.last_used_at = std.time.nanoTimestamp();
        self.pool.releaseConnection(self);
    }

    /// 关闭连接（不归还池）
    ///
    /// 当连接出现问题时使用，会直接关闭而非归还
    pub fn closeAndDiscard(self: *PooledConnection) void {
        if (self.returned) {
            return;
        }
        self.returned = true;
        self.pool.discardConnection(self);
    }

    // ========================================
    // 便捷方法：转发到底层连接
    // 这样调用方不需要先调用 connection()
    // ========================================

    pub fn get(self: *PooledConnection, key: []const u8) !@import("reply.zig").Reply {
        return self.conn.get(key);
    }

    pub fn set(self: *PooledConnection, key: []const u8, value: []const u8) !@import("reply.zig").Reply {
        return self.conn.set(key, value);
    }

    pub fn del(self: *PooledConnection, key: []const u8) !@import("reply.zig").Reply {
        return self.conn.del(key);
    }

    pub fn ping(self: *PooledConnection) !bool {
        return self.conn.ping();
    }

    pub fn sendCommand(self: *PooledConnection, args: []const []const u8) !@import("reply.zig").Reply {
        return self.conn.sendCommand(args);
    }

    pub fn exec(self: *PooledConnection, cmd: []const u8, args: anytype) !@import("reply.zig").Reply {
        return self.conn.exec(cmd, args);
    }
};

/// Redis 连接池
///
/// ## 线程安全设计
///
/// 连接池需要在多线程环境中安全使用：
/// - 使用 Mutex 保护共享状态
/// - 使用 Condition 实现等待/通知机制
///
/// ## 状态转换
///
/// 连接的生命周期：
/// ```
/// [创建] -> [池中空闲] <-> [被借用] -> [销毁]
///               |                        ^
///               +-- (超时/失效) ---------+
/// ```
pub const Pool = struct {
    const Self = @This();

    /// 空闲连接队列
    ///
    /// 使用 ArrayListUnmanaged 作为 LIFO 栈（后进先出）
    /// LIFO 可以更好地利用热连接
    idle_connections: std.ArrayListUnmanaged(*PooledConnection),
    /// 互斥锁
    mutex: std.Thread.Mutex,
    /// 条件变量，用于等待可用连接
    ///
    /// ## 条件变量 vs Go 的 channel
    ///
    /// Go 使用 channel 阻塞等待：
    /// ```go
    /// conn := <-pool.conns // 阻塞直到有连接
    /// ```
    ///
    /// Zig 使用条件变量：
    /// ```zig
    /// while (no_connection_available) {
    ///     self.cond.wait(&self.mutex);
    /// }
    /// ```
    cond: std.Thread.Condition,
    /// 当前活跃连接数（包括正在使用的和空闲的）
    active_count: u32,
    /// 连接池是否已关闭
    closed: bool,
    /// 连接池选项
    options: PoolOptions,
    /// 内存分配器
    allocator: std.mem.Allocator,

    /// 创建连接池
    ///
    /// ## 初始化流程
    ///
    /// 1. 验证配置参数
    /// 2. 初始化内部状态
    /// 3. 预创建最小空闲连接（可选，这里延迟创建）
    pub fn init(options: PoolOptions, allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .idle_connections = .{},
            .mutex = .{},
            .cond = .{},
            .active_count = 0,
            .closed = false,
            .options = options,
            .allocator = allocator,
        };

        // 预创建最小空闲连接
        var i: u32 = 0;
        while (i < options.min_idle_connections) : (i += 1) {
            const pooled = self.createNewConnection() catch break;
            self.idle_connections.append(allocator, pooled) catch {
                pooled.conn.close();
                allocator.destroy(pooled);
                break;
            };
        }

        return self;
    }

    /// 关闭连接池
    ///
    /// ## 清理流程
    ///
    /// 1. 标记为已关闭
    /// 2. 唤醒所有等待的线程
    /// 3. 关闭所有空闲连接
    /// 4. 释放资源
    ///
    /// 注意：正在使用的连接会在归还时被关闭
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        self.closed = true;

        // 唤醒所有等待的线程
        self.cond.broadcast();

        // 关闭所有空闲连接
        for (self.idle_connections.items) |pooled| {
            pooled.conn.close();
            self.allocator.destroy(pooled);
        }
        self.idle_connections.deinit(self.allocator);

        self.mutex.unlock();
        self.allocator.destroy(self);
    }

    /// 获取连接
    ///
    /// ## 获取流程
    ///
    /// 1. 尝试从空闲队列获取
    /// 2. 检查连接是否有效（超时、存活时间）
    /// 3. 如果没有空闲连接且未达上限，创建新连接
    /// 4. 如果达到上限，等待或返回错误
    ///
    /// ## 超时等待
    ///
    /// Go 中可以使用 context.WithTimeout：
    /// ```go
    /// ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    /// conn, err := pool.GetContext(ctx)
    /// ```
    ///
    /// Zig 中我们使用带超时的条件变量等待
    pub fn acquire(self: *Self) !*PooledConnection {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) {
            return RedisError.ConnectionClosed;
        }

        const now = std.time.nanoTimestamp();
        const deadline = now + @as(i128, self.options.wait_timeout_ns);

        while (true) {
            // 尝试从空闲队列获取
            if (self.idle_connections.pop()) |pooled| {
                // 检查连接是否过期
                if (self.isConnectionExpired(pooled, now)) {
                    pooled.conn.close();
                    self.allocator.destroy(pooled);
                    self.active_count -= 1;
                    continue;
                }

                // 测试连接是否可用
                if (!pooled.conn.isActive()) {
                    pooled.conn.close();
                    self.allocator.destroy(pooled);
                    self.active_count -= 1;
                    continue;
                }

                pooled.returned = false;
                return pooled;
            }

            // 没有空闲连接，尝试创建新连接
            if (self.active_count < self.options.max_connections) {
                // 先释放锁再创建连接（创建连接可能很慢）
                self.mutex.unlock();
                const pooled = self.createNewConnection() catch |err| {
                    self.mutex.lock();
                    return err;
                };
                self.mutex.lock();

                if (self.closed) {
                    pooled.conn.close();
                    self.allocator.destroy(pooled);
                    return RedisError.ConnectionClosed;
                }

                self.active_count += 1;
                return pooled;
            }

            // 达到上限，等待
            const current = std.time.nanoTimestamp();
            if (current >= deadline) {
                return RedisError.PoolExhausted;
            }

            // 计算剩余等待时间
            const remaining_ns: u64 = @intCast(deadline - current);

            // 等待条件变量（带超时）
            // 注意：timedWait 会在超时或被唤醒时返回
            self.cond.timedWait(&self.mutex, remaining_ns) catch {
                // 超时
                return RedisError.PoolExhausted;
            };

            if (self.closed) {
                return RedisError.ConnectionClosed;
            }
        }
    }

    /// 创建新连接
    fn createNewConnection(self: *Self) !*PooledConnection {
        const conn = try Connection.connect(self.options.conn_options, self.allocator);
        errdefer conn.close();

        const pooled = try self.allocator.create(PooledConnection);
        const now = std.time.nanoTimestamp();
        pooled.* = PooledConnection{
            .conn = conn,
            .created_at = now,
            .last_used_at = now,
            .pool = self,
        };

        return pooled;
    }

    /// 检查连接是否过期
    fn isConnectionExpired(self: *Self, pooled: *PooledConnection, now: i128) bool {
        // 检查最大存活时间
        if (self.options.max_lifetime_ns > 0) {
            const age: u64 = @intCast(now - pooled.created_at);
            if (age > self.options.max_lifetime_ns) {
                return true;
            }
        }

        // 检查空闲超时
        if (self.options.idle_timeout_ns > 0) {
            const idle_time: u64 = @intCast(now - pooled.last_used_at);
            if (idle_time > self.options.idle_timeout_ns) {
                return true;
            }
        }

        return false;
    }

    /// 释放连接回池
    fn releaseConnection(self: *Self, pooled: *PooledConnection) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.closed) {
            pooled.conn.close();
            self.allocator.destroy(pooled);
            self.active_count -= 1;
            return;
        }

        // 检查连接是否仍然有效
        if (!pooled.conn.isActive()) {
            pooled.conn.close();
            self.allocator.destroy(pooled);
            self.active_count -= 1;
            return;
        }

        // 归还到空闲队列
        self.idle_connections.append(self.allocator, pooled) catch {
            // 队列满了，关闭连接
            pooled.conn.close();
            self.allocator.destroy(pooled);
            self.active_count -= 1;
            return;
        };

        // 通知等待的线程
        self.cond.signal();
    }

    /// 丢弃连接（不归还）
    fn discardConnection(self: *Self, pooled: *PooledConnection) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        pooled.conn.close();
        self.allocator.destroy(pooled);

        if (self.active_count > 0) {
            self.active_count -= 1;
        }
    }

    /// 获取统计信息
    pub fn stats(self: *Self) PoolStats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return PoolStats{
            .total_connections = self.active_count,
            .idle_connections = @intCast(self.idle_connections.items.len),
            .active_connections = self.active_count - @as(u32, @intCast(self.idle_connections.items.len)),
            .max_connections = self.options.max_connections,
        };
    }

    /// 清理过期连接
    ///
    /// 可以定期调用此方法清理过期的空闲连接
    pub fn cleanup(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.nanoTimestamp();
        var i: usize = 0;

        while (i < self.idle_connections.items.len) {
            const pooled = self.idle_connections.items[i];
            if (self.isConnectionExpired(pooled, now)) {
                _ = self.idle_connections.orderedRemove(i);
                pooled.conn.close();
                self.allocator.destroy(pooled);
                self.active_count -= 1;
            } else {
                i += 1;
            }
        }
    }
};

/// 连接池统计信息
pub const PoolStats = struct {
    /// 总连接数
    total_connections: u32,
    /// 空闲连接数
    idle_connections: u32,
    /// 活跃连接数（正在使用）
    active_connections: u32,
    /// 最大连接数
    max_connections: u32,
};

/// 创建连接池的便捷函数
///
/// ## 使用示例
///
/// ```zig
/// const pool = try redis.createPool(.{
///     .max_connections = 20,
///     .conn_options = .{
///         .host = "localhost",
///         .password = "secret",
///     },
/// }, allocator);
/// defer pool.deinit();
///
/// // 获取连接
/// var conn = try pool.acquire();
/// defer conn.release();
///
/// // 使用连接
/// var reply = try conn.get("key");
/// defer reply.deinit();
/// ```
pub fn createPool(options: PoolOptions, allocator: std.mem.Allocator) !*Pool {
    return Pool.init(options, allocator);
}

/// 使用默认选项创建连接池
pub fn createDefaultPool(allocator: std.mem.Allocator) !*Pool {
    return Pool.init(.{}, allocator);
}
