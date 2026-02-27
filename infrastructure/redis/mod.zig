//! Redis 模块重导出
//!
//! 从 application/services/redis 重导出 Redis 功能，保持原始实现位置不变。

const redis = @import("../../application/services/redis/mod.zig");

// 重导出所有 Redis 类型
pub const Connection = redis.Connection;
pub const ConnectionOptions = redis.ConnectionOptions;
pub const Pool = redis.Pool;
pub const PoolOptions = redis.PoolOptions;
pub const PoolStats = redis.PoolStats;

// 命令模块
pub const strings = redis.strings;
pub const hash = redis.hash;
pub const list = redis.list;
pub const set = redis.set;
pub const zset = redis.zset;
pub const generic = redis.generic;

// 便捷函数
pub const connect = redis.connect;
pub const createPool = redis.createPool;

// 类型
pub const Reply = redis.Reply;
pub const Result = redis.Result;
pub const Command = redis.Command;
