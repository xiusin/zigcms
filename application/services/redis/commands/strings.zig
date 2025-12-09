//! Redis String 命令实现
//!
//! String 是 Redis 最基本的数据类型，可以存储字符串、整数、浮点数。
//! 最大长度 512 MB。
//!
//! ## 常用命令
//! - GET/SET: 基本读写
//! - INCR/DECR: 原子计数
//! - MGET/MSET: 批量操作
//! - APPEND: 追加内容
//! - GETRANGE/SETRANGE: 范围操作

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

const SetOptions = types.SetOptions;

/// String 命令扩展
///
/// ## 实现方式说明
///
/// 我们使用 Zig 的 "usingnamespace" 或直接扩展方法的方式
/// 这里采用独立函数的方式，便于组织和测试
///
/// Go 中你会在 string.go 中定义 Redis 结构体的方法：
/// ```go
/// func (r *Redis) Get(key string) (string, error)
/// ```
///
/// Zig 中我们可以：
/// 1. 在 Connection 结构体中直接添加方法
/// 2. 使用扩展函数（这里采用的方式）
pub const StringCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) StringCommands {
        return .{ .conn = conn };
    }

    /// GET 命令
    ///
    /// 获取 key 的值，如果 key 不存在返回 nil
    ///
    /// ## 时间复杂度: O(1)
    pub fn get(self: StringCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "GET", key });
    }

    /// SET 命令
    ///
    /// 设置 key 的值，覆盖旧值
    ///
    /// ## 时间复杂度: O(1)
    pub fn set(self: StringCommands, key: []const u8, value: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "SET", key, value });
    }

    /// SET 带选项
    ///
    /// 支持 EX/PX/NX/XX/KEEPTTL 选项
    ///
    /// ## 使用示例
    /// ```zig
    /// // 设置 10 秒过期，仅当 key 不存在时
    /// try strings.setOpts("mykey", "value", .{
    ///     .ex_seconds = 10,
    ///     .nx = true,
    /// });
    /// ```
    pub fn setOpts(self: StringCommands, key: []const u8, value: []const u8, opts: SetOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SET");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addStr(value);

        // 添加过期时间选项
        if (opts.ex_seconds) |ex| {
            _ = try self.conn.cmd_builder.addStr("EX");
            _ = try self.conn.cmd_builder.addInt(ex);
        } else if (opts.px_milliseconds) |px| {
            _ = try self.conn.cmd_builder.addStr("PX");
            _ = try self.conn.cmd_builder.addInt(px);
        }

        // 添加 NX/XX 选项
        if (opts.nx) {
            _ = try self.conn.cmd_builder.addStr("NX");
        } else if (opts.xx) {
            _ = try self.conn.cmd_builder.addStr("XX");
        }

        // 添加 KEEPTTL 选项
        if (opts.keep_ttl) {
            _ = try self.conn.cmd_builder.addStr("KEEPTTL");
        }

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SETNX - SET if Not eXists
    ///
    /// 仅当 key 不存在时设置
    /// 返回 true 表示设置成功，false 表示 key 已存在
    ///
    /// ## 时间复杂度: O(1)
    ///
    /// ## 注意
    /// 
    /// 这个命令已被弃用，推荐使用 SET ... NX
    /// 但为了兼容性仍然提供
    pub fn setNx(self: StringCommands, key: []const u8, value: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "SETNX", key, value });
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// SETEX - SET with EXpire
    ///
    /// 设置 key 的值，并指定过期时间（秒）
    ///
    /// ## 时间复杂度: O(1)
    pub fn setEx(self: StringCommands, key: []const u8, seconds: i64, value: []const u8) !bool {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SETEX");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(seconds);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// PSETEX - SET with expire in milliseconds
    pub fn pSetEx(self: StringCommands, key: []const u8, milliseconds: i64, value: []const u8) !bool {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("PSETEX");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(milliseconds);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// GETSET - 设置新值并返回旧值
    ///
    /// ## 原子操作
    /// 
    /// 这是一个原子操作，可以用于实现锁等场景
    ///
    /// ## 注意
    ///
    /// 此命令在 Redis 6.2.0 被弃用，推荐使用 SET ... GET
    pub fn getSet(self: StringCommands, key: []const u8, value: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "GETSET", key, value });
    }

    /// APPEND - 追加内容
    ///
    /// 如果 key 存在，追加内容到末尾
    /// 如果 key 不存在，等同于 SET
    ///
    /// 返回追加后字符串的长度
    ///
    /// ## 时间复杂度: O(1)
    pub fn append(self: StringCommands, key: []const u8, value: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "APPEND", key, value });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// STRLEN - 获取字符串长度
    ///
    /// ## 时间复杂度: O(1)
    pub fn strlen(self: StringCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "STRLEN", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// INCR - 自增 1
    ///
    /// 将 key 的值加 1，如果 key 不存在则先设为 0
    /// 返回自增后的值
    ///
    /// ## 时间复杂度: O(1)
    ///
    /// ## 错误情况
    ///
    /// 如果 key 的值不是整数，会返回错误
    pub fn incr(self: StringCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "INCR", key });
        defer reply.deinit();
        return reply.int() orelse return types.RedisError.InvalidResponse;
    }

    /// INCRBY - 自增指定值
    pub fn incrBy(self: StringCommands, key: []const u8, increment: i64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("INCRBY");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(increment);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse return types.RedisError.InvalidResponse;
    }

    /// INCRBYFLOAT - 自增浮点数
    pub fn incrByFloat(self: StringCommands, key: []const u8, increment: f64) !f64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("INCRBYFLOAT");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addFloat(increment);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.float() orelse return types.RedisError.InvalidResponse;
    }

    /// DECR - 自减 1
    pub fn decr(self: StringCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "DECR", key });
        defer reply.deinit();
        return reply.int() orelse return types.RedisError.InvalidResponse;
    }

    /// DECRBY - 自减指定值
    pub fn decrBy(self: StringCommands, key: []const u8, decrement: i64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("DECRBY");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(decrement);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse return types.RedisError.InvalidResponse;
    }

    /// GETRANGE - 获取子字符串
    ///
    /// 返回 key 的值中从 start 到 end 的子字符串（包含两端）
    /// 支持负数索引，-1 表示最后一个字符
    ///
    /// ## 时间复杂度: O(N)，N 为返回字符串的长度
    pub fn getRange(self: StringCommands, key: []const u8, start: i64, end: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("GETRANGE");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(start);
        _ = try self.conn.cmd_builder.addInt(end);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SETRANGE - 覆盖部分字符串
    ///
    /// 从 offset 位置开始，用 value 覆盖原字符串
    /// 返回修改后字符串的长度
    ///
    /// ## 时间复杂度: O(1)
    pub fn setRange(self: StringCommands, key: []const u8, offset: i64, value: []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SETRANGE");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(offset);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// MGET - 批量获取
    ///
    /// 返回多个 key 的值，不存在的返回 nil
    ///
    /// ## 时间复杂度: O(N)
    pub fn mget(self: StringCommands, keys: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("MGET");
        _ = try self.conn.cmd_builder.addSlice(keys);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// MSET - 批量设置
    ///
    /// ## 参数格式
    ///
    /// pairs 应该是 key-value 交替的数组：
    /// ```zig
    /// try strings.mset(&.{ "k1", "v1", "k2", "v2" });
    /// ```
    ///
    /// ## 时间复杂度: O(N)
    pub fn mset(self: StringCommands, pairs: []const []const u8) !bool {
        if (pairs.len == 0 or pairs.len % 2 != 0) {
            return types.RedisError.InvalidArgument;
        }

        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("MSET");
        _ = try self.conn.cmd_builder.addSlice(pairs);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// MSETNX - 批量设置（仅当所有 key 都不存在时）
    ///
    /// 原子操作：要么全部设置，要么全部不设置
    pub fn msetNx(self: StringCommands, pairs: []const []const u8) !bool {
        if (pairs.len == 0 or pairs.len % 2 != 0) {
            return types.RedisError.InvalidArgument;
        }

        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("MSETNX");
        _ = try self.conn.cmd_builder.addSlice(pairs);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// SETBIT - 设置位
    pub fn setBit(self: StringCommands, key: []const u8, offset: u64, value: u1) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SETBIT");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addUint(offset);
        _ = try self.conn.cmd_builder.addInt(@intCast(value));

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// GETBIT - 获取位
    pub fn getBit(self: StringCommands, key: []const u8, offset: u64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("GETBIT");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addUint(offset);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// BITCOUNT - 统计位为 1 的数量
    pub fn bitCount(self: StringCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "BITCOUNT", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }
};

/// 便捷函数：创建 String 命令接口
pub fn strings(conn: *Connection) StringCommands {
    return StringCommands.init(conn);
}
