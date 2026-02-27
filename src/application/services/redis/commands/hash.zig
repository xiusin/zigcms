//! Redis Hash 命令实现
//!
//! Hash 是字符串字段和字符串值之间的映射，适合存储对象。
//! 每个 Hash 可以存储 2^32 - 1 个字段值对。
//!
//! ## 应用场景
//! - 存储用户信息：HSET user:1000 name "John" age "30"
//! - 存储配置：HSET config timeout "30" retries "3"
//! - 计数器：HINCRBY article:123 views 1

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

/// Hash 命令接口
///
/// ## Zig 方法接收器
///
/// Go 中方法接收器可以是值或指针：
/// ```go
/// func (h HashCommands) HGet(...) // 值接收器
/// func (h *HashCommands) HSet(...) // 指针接收器
/// ```
///
/// Zig 中使用 `self: HashCommands` 或 `self: *HashCommands`
/// 这里使用值类型，因为 HashCommands 很小（只有一个指针）
pub const HashCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) HashCommands {
        return .{ .conn = conn };
    }

    /// HSET - 设置字段值
    ///
    /// 设置哈希表中字段的值
    /// 返回 true 如果是新字段，false 如果是更新
    ///
    /// ## 时间复杂度: O(1)
    ///
    /// ## 使用示例
    /// ```zig
    /// const isNew = try hash.hset("user:1", "name", "John");
    /// ```
    pub fn hset(self: HashCommands, key: []const u8, field: []const u8, value: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "HSET", key, field, value });
        defer reply.deinit();
        // HSET 返回添加的新字段数量（0 或 1）
        return reply.int() orelse 0 >= 0;
    }

    /// HSETNX - 仅当字段不存在时设置
    ///
    /// 返回 true 表示设置成功，false 表示字段已存在
    ///
    /// ## 原子操作
    ///
    /// 适合实现分布式锁等场景
    pub fn hsetNx(self: HashCommands, key: []const u8, field: []const u8, value: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "HSETNX", key, field, value });
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// HGET - 获取字段值
    ///
    /// 返回哈希表中字段的值，字段不存在时返回 nil
    ///
    /// ## 时间复杂度: O(1)
    pub fn hget(self: HashCommands, key: []const u8, field: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "HGET", key, field });
    }

    /// HMSET - 批量设置字段
    ///
    /// ## 参数格式
    ///
    /// field_values 是 field-value 交替的数组：
    /// ```zig
    /// try hash.hmset("user:1", &.{ "name", "John", "age", "30" });
    /// ```
    ///
    /// ## 注意
    ///
    /// Redis 4.0.0 起 HMSET 被认为是弃用的，推荐使用 HSET
    /// 但 HSET 多字段支持需要 Redis 4.0.0+
    pub fn hmset(self: HashCommands, key: []const u8, field_values: []const []const u8) !bool {
        if (field_values.len == 0 or field_values.len % 2 != 0) {
            return types.RedisError.InvalidArgument;
        }

        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HMSET");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(field_values);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// HMGET - 批量获取字段值
    ///
    /// 返回多个字段的值，不存在的字段返回 nil
    ///
    /// ## 时间复杂度: O(N)
    pub fn hmget(self: HashCommands, key: []const u8, fields: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HMGET");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(fields);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// HGETALL - 获取所有字段和值
    ///
    /// 返回哈希表中所有字段和值
    /// 返回的数组格式：[field1, value1, field2, value2, ...]
    ///
    /// ## 时间复杂度: O(N)
    ///
    /// ## 注意
    ///
    /// 大哈希表慎用，可能阻塞 Redis
    /// 推荐使用 HSCAN 进行增量迭代
    pub fn hgetAll(self: HashCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "HGETALL", key });
    }

    /// HDEL - 删除字段
    ///
    /// 返回实际删除的字段数量
    ///
    /// ## 时间复杂度: O(N)，N 为删除的字段数
    pub fn hdel(self: HashCommands, key: []const u8, fields: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HDEL");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(fields);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// HEXISTS - 检查字段是否存在
    pub fn hexists(self: HashCommands, key: []const u8, field: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "HEXISTS", key, field });
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// HLEN - 获取字段数量
    ///
    /// ## 时间复杂度: O(1)
    pub fn hlen(self: HashCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "HLEN", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// HKEYS - 获取所有字段名
    ///
    /// ## 时间复杂度: O(N)
    pub fn hkeys(self: HashCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "HKEYS", key });
    }

    /// HVALS - 获取所有字段值
    ///
    /// ## 时间复杂度: O(N)
    pub fn hvals(self: HashCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "HVALS", key });
    }

    /// HINCRBY - 整数自增
    ///
    /// 将哈希表中字段的值增加 increment
    /// 如果字段不存在，先设为 0 再自增
    ///
    /// ## 时间复杂度: O(1)
    pub fn hincrBy(self: HashCommands, key: []const u8, field: []const u8, increment: i64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HINCRBY");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addStr(field);
        _ = try self.conn.cmd_builder.addInt(increment);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// HINCRBYFLOAT - 浮点数自增
    pub fn hincrByFloat(self: HashCommands, key: []const u8, field: []const u8, increment: f64) !f64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HINCRBYFLOAT");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addStr(field);
        _ = try self.conn.cmd_builder.addFloat(increment);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.float() orelse 0;
    }

    /// HSTRLEN - 获取字段值的长度
    ///
    /// ## 时间复杂度: O(1)
    pub fn hstrLen(self: HashCommands, key: []const u8, field: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "HSTRLEN", key, field });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// HSCAN - 增量迭代哈希表
    ///
    /// ## 迭代说明
    ///
    /// SCAN 系列命令是增量迭代，不会阻塞 Redis
    /// 适合大数据量场景
    ///
    /// ## 返回格式
    ///
    /// 返回数组 [cursor, [field1, value1, field2, value2, ...]]
    pub fn hscan(self: HashCommands, key: []const u8, cursor: u64, opts: types.ScanOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("HSCAN");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addUint(cursor);

        if (opts.pattern) |pattern| {
            _ = try self.conn.cmd_builder.addStr("MATCH");
            _ = try self.conn.cmd_builder.addStr(pattern);
        }
        if (opts.count) |count| {
            _ = try self.conn.cmd_builder.addStr("COUNT");
            _ = try self.conn.cmd_builder.addUint(count);
        }

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }
};

/// 便捷函数：创建 Hash 命令接口
pub fn hash(conn: *Connection) HashCommands {
    return HashCommands.init(conn);
}
