//! 对象池模块
//!
//! 提供通用的对象池化管理，减少内存分配开销。
//!
//! ## 功能特性
//!
//! - **泛型对象池**：支持任意类型的对象池化
//! - **字节缓冲区池**：固定大小的缓冲区池
//! - **动态缓冲区池**：按大小自动选择合适的池
//! - **线程安全**：所有操作都是线程安全的
//! - **统计信息**：获取命中率、创建/销毁次数等
//!
//! ## 使用示例
//!
//! ```zig
//! const pool = @import("services/pool/mod.zig");
//!
//! // 创建对象池
//! var int_pool = pool.Pool(i32).init(allocator, .{ .max_size = 100 });
//! defer int_pool.deinit();
//!
//! // 获取和释放
//! const item = try int_pool.acquire();
//! defer int_pool.release(item);
//! item.* = 42;
//!
//! // 字节缓冲区池
//! var buf_pool = pool.ByteBufferPool(4096).init(allocator, .{});
//! defer buf_pool.deinit();
//!
//! const buf = try buf_pool.acquire();
//! defer buf_pool.release(buf);
//! ```

const p = @import("pool.zig");

pub const Pool = p.Pool;
pub const ByteBufferPool = p.ByteBufferPool;
pub const DynamicBufferPool = p.DynamicBufferPool;
pub const PooledHandle = p.PooledHandle;
pub const PoolConfig = p.PoolConfig;

pub const createPool = p.createPool;
pub const createPoolWithSize = p.createPoolWithSize;

test {
    _ = p;
}
