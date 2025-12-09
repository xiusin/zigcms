//! Redis Set 命令实现
//!
//! Set 是无序的字符串集合，不允许重复元素。
//! 支持集合运算（交集、并集、差集）。
//!
//! ## 应用场景
//! - 标签系统：每个用户的标签集合
//! - 好友关系：共同好友 = 交集
//! - 唯一性检查：SADD 返回 0 表示已存在

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

/// Set 命令接口
pub const SetCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) SetCommands {
        return .{ .conn = conn };
    }

    /// SADD - 添加成员
    ///
    /// 返回实际添加的新成员数量（已存在的不计）
    ///
    /// ## 时间复杂度: O(N)，N 为添加的成员数
    pub fn sadd(self: SetCommands, key: []const u8, members: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SADD");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(members);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SREM - 移除成员
    ///
    /// 返回实际移除的成员数量
    pub fn srem(self: SetCommands, key: []const u8, members: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SREM");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(members);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SMEMBERS - 获取所有成员
    ///
    /// ## 时间复杂度: O(N)
    ///
    /// ## 注意
    /// 大集合慎用，推荐使用 SSCAN
    pub fn smembers(self: SetCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "SMEMBERS", key });
    }

    /// SISMEMBER - 检查成员是否存在
    ///
    /// ## 时间复杂度: O(1)
    pub fn sismember(self: SetCommands, key: []const u8, member: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "SISMEMBER", key, member });
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// SMISMEMBER - 批量检查成员是否存在（Redis 6.2+）
    ///
    /// 返回数组，每个元素表示对应成员是否存在
    pub fn smismember(self: SetCommands, key: []const u8, members: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SMISMEMBER");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(members);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SCARD - 获取成员数量
    ///
    /// ## 时间复杂度: O(1)
    pub fn scard(self: SetCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "SCARD", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SPOP - 随机弹出成员
    ///
    /// 移除并返回一个随机成员
    pub fn spop(self: SetCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "SPOP", key });
    }

    /// SRANDMEMBER - 随机获取成员（不移除）
    ///
    /// ## count 参数
    /// - count > 0: 返回 count 个不重复的成员
    /// - count < 0: 返回 |count| 个成员（可能重复）
    pub fn srandmember(self: SetCommands, key: []const u8, count: ?i64) !Reply {
        if (count) |c| {
            self.conn.mutex.lock();
            defer self.conn.mutex.unlock();

            self.conn.cmd_builder.reset();
            _ = try self.conn.cmd_builder.addStr("SRANDMEMBER");
            _ = try self.conn.cmd_builder.addStr(key);
            _ = try self.conn.cmd_builder.addInt(c);

            return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        }
        return self.conn.sendCommand(&.{ "SRANDMEMBER", key });
    }

    /// SMOVE - 移动成员到另一个集合
    ///
    /// 原子操作
    /// 返回 true 表示移动成功，false 表示源集合不包含该成员
    pub fn smove(self: SetCommands, source: []const u8, destination: []const u8, member: []const u8) !bool {
        var reply = try self.conn.sendCommand(&.{ "SMOVE", source, destination, member });
        defer reply.deinit();
        return reply.int() == 1;
    }

    /// SUNION - 并集
    ///
    /// 返回多个集合的并集
    ///
    /// ## 时间复杂度: O(N)，N 为所有集合的成员总数
    pub fn sunion(self: SetCommands, keys: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SUNION");
        _ = try self.conn.cmd_builder.addSlice(keys);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SUNIONSTORE - 并集并存储
    ///
    /// 返回结果集合的成员数量
    pub fn sunionStore(self: SetCommands, destination: []const u8, keys: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SUNIONSTORE");
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addSlice(keys);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SINTER - 交集
    ///
    /// 返回多个集合的交集
    pub fn sinter(self: SetCommands, keys: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SINTER");
        _ = try self.conn.cmd_builder.addSlice(keys);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SINTERSTORE - 交集并存储
    pub fn sinterStore(self: SetCommands, destination: []const u8, keys: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SINTERSTORE");
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addSlice(keys);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SINTERCARD - 交集计数（Redis 7.0+）
    ///
    /// 返回交集的成员数量，可以设置 limit 提前终止
    pub fn sinterCard(self: SetCommands, keys: []const []const u8, limit: ?u64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SINTERCARD");
        _ = try self.conn.cmd_builder.addUint(@as(u64, keys.len));
        _ = try self.conn.cmd_builder.addSlice(keys);

        if (limit) |l| {
            _ = try self.conn.cmd_builder.addStr("LIMIT");
            _ = try self.conn.cmd_builder.addUint(l);
        }

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SDIFF - 差集
    ///
    /// 返回第一个集合与其他集合的差集
    ///
    /// ## 差集定义
    ///
    /// A - B - C = A 中存在但 B 和 C 中都不存在的元素
    pub fn sdiff(self: SetCommands, keys: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SDIFF");
        _ = try self.conn.cmd_builder.addSlice(keys);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// SDIFFSTORE - 差集并存储
    pub fn sdiffStore(self: SetCommands, destination: []const u8, keys: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SDIFFSTORE");
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addSlice(keys);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SSCAN - 增量迭代集合
    pub fn sscan(self: SetCommands, key: []const u8, cursor: u64, opts: types.ScanOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SSCAN");
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

/// 便捷函数：创建 Set 命令接口
pub fn set(conn: *Connection) SetCommands {
    return SetCommands.init(conn);
}
