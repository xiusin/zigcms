//! Redis Sorted Set (ZSet) 命令实现
//!
//! Sorted Set 是有序的字符串集合，每个成员关联一个分数。
//! 成员唯一，分数可重复，按分数排序。
//!
//! ## 应用场景
//! - 排行榜：ZADD leaderboard 1000 "player1"
//! - 带权重的队列：分数作为优先级
//! - 时间线：分数作为时间戳
//! - 范围查询：按分数或字典序范围

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

const ZRangeOptions = types.ZRangeOptions;

/// 分数-成员对
pub const ScoreMember = struct {
    score: f64,
    member: []const u8,
};

/// Sorted Set 命令接口
pub const ZSetCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) ZSetCommands {
        return .{ .conn = conn };
    }

    /// ZADD - 添加成员
    ///
    /// 添加一个或多个成员，如果成员已存在则更新分数
    ///
    /// ## 返回值
    /// 返回新添加的成员数量（不包括已存在的更新）
    ///
    /// ## 时间复杂度: O(log(N))，N 为有序集合的成员数
    pub fn zadd(self: ZSetCommands, key: []const u8, score_members: []const ScoreMember) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZADD");
        _ = try self.conn.cmd_builder.addStr(key);

        for (score_members) |sm| {
            _ = try self.conn.cmd_builder.addFloat(sm.score);
            _ = try self.conn.cmd_builder.addStr(sm.member);
        }

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZADD 简化版：添加单个成员
    pub fn zaddOne(self: ZSetCommands, key: []const u8, score: f64, member: []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZADD");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addFloat(score);
        _ = try self.conn.cmd_builder.addStr(member);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZREM - 移除成员
    ///
    /// 返回实际移除的成员数量
    pub fn zrem(self: ZSetCommands, key: []const u8, members: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZREM");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(members);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZSCORE - 获取成员分数
    ///
    /// 成员不存在时返回 nil
    ///
    /// ## 时间复杂度: O(1)
    pub fn zscore(self: ZSetCommands, key: []const u8, member: []const u8) !?f64 {
        var reply = try self.conn.sendCommand(&.{ "ZSCORE", key, member });
        defer reply.deinit();

        if (reply.isNil()) {
            return null;
        }
        return reply.float();
    }

    /// ZRANK - 获取成员排名（按分数升序）
    ///
    /// 排名从 0 开始
    /// 成员不存在时返回 nil
    ///
    /// ## 时间复杂度: O(log(N))
    pub fn zrank(self: ZSetCommands, key: []const u8, member: []const u8) !?i64 {
        var reply = try self.conn.sendCommand(&.{ "ZRANK", key, member });
        defer reply.deinit();

        if (reply.isNil()) {
            return null;
        }
        return reply.int();
    }

    /// ZREVRANK - 获取成员排名（按分数降序）
    pub fn zrevrank(self: ZSetCommands, key: []const u8, member: []const u8) !?i64 {
        var reply = try self.conn.sendCommand(&.{ "ZREVRANK", key, member });
        defer reply.deinit();

        if (reply.isNil()) {
            return null;
        }
        return reply.int();
    }

    /// ZCARD - 获取成员数量
    ///
    /// ## 时间复杂度: O(1)
    pub fn zcard(self: ZSetCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "ZCARD", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZCOUNT - 统计分数范围内的成员数
    ///
    /// min/max 可以使用 "-inf" 和 "+inf"
    ///
    /// ## 时间复杂度: O(log(N))
    pub fn zcount(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "ZCOUNT", key, min, max });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZINCRBY - 增加成员分数
    ///
    /// 返回增加后的新分数
    /// 如果成员不存在，先以 0 为初始分数再增加
    ///
    /// ## 时间复杂度: O(log(N))
    pub fn zincrBy(self: ZSetCommands, key: []const u8, increment: f64, member: []const u8) !f64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZINCRBY");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addFloat(increment);
        _ = try self.conn.cmd_builder.addStr(member);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.float() orelse 0;
    }

    /// ZRANGE - 按排名范围获取成员
    ///
    /// 返回排名在 [start, stop] 范围内的成员
    /// 支持负数索引，-1 表示最后一个成员
    ///
    /// ## WITHSCORES 选项
    ///
    /// 如果 opts.with_scores = true，返回格式为：
    /// [member1, score1, member2, score2, ...]
    ///
    /// ## 时间复杂度: O(log(N) + M)，M 为返回的成员数
    pub fn zrange(self: ZSetCommands, key: []const u8, start: i64, stop: i64, opts: ZRangeOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();

        if (opts.reverse) {
            _ = try self.conn.cmd_builder.addStr("ZREVRANGE");
        } else {
            _ = try self.conn.cmd_builder.addStr("ZRANGE");
        }

        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(start);
        _ = try self.conn.cmd_builder.addInt(stop);

        if (opts.with_scores) {
            _ = try self.conn.cmd_builder.addStr("WITHSCORES");
        }

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// ZREVRANGE - 按排名范围获取成员（降序）
    pub fn zrevrange(self: ZSetCommands, key: []const u8, start: i64, stop: i64, with_scores: bool) !Reply {
        return self.zrange(key, start, stop, .{ .reverse = true, .with_scores = with_scores });
    }

    /// ZRANGEBYSCORE - 按分数范围获取成员
    ///
    /// ## 分数范围格式
    ///
    /// - 普通数字: "100"
    /// - 开区间: "(100" 表示 > 100
    /// - 正负无穷: "-inf", "+inf"
    ///
    /// ## 使用示例
    /// ```zig
    /// // 获取分数 0-100 的成员
    /// const reply = try zset.zrangeByScore("scores", "0", "100", .{});
    /// // 获取分数 > 50 的成员
    /// const reply = try zset.zrangeByScore("scores", "(50", "+inf", .{});
    /// ```
    pub fn zrangeByScore(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8, opts: ZRangeOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();

        if (opts.reverse) {
            _ = try self.conn.cmd_builder.addStr("ZREVRANGEBYSCORE");
            // 逆序时 min 和 max 要交换
            _ = try self.conn.cmd_builder.addStr(key);
            _ = try self.conn.cmd_builder.addStr(max);
            _ = try self.conn.cmd_builder.addStr(min);
        } else {
            _ = try self.conn.cmd_builder.addStr("ZRANGEBYSCORE");
            _ = try self.conn.cmd_builder.addStr(key);
            _ = try self.conn.cmd_builder.addStr(min);
            _ = try self.conn.cmd_builder.addStr(max);
        }

        if (opts.with_scores) {
            _ = try self.conn.cmd_builder.addStr("WITHSCORES");
        }

        if (opts.offset != null or opts.count != null) {
            _ = try self.conn.cmd_builder.addStr("LIMIT");
            _ = try self.conn.cmd_builder.addInt(opts.offset orelse 0);
            _ = try self.conn.cmd_builder.addInt(opts.count orelse 10);
        }

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// ZRANGEBYLEX - 按字典序范围获取成员
    ///
    /// 仅当所有成员分数相同时有意义
    ///
    /// ## 范围格式
    ///
    /// - "[member" 闭区间
    /// - "(member" 开区间
    /// - "-" 最小值
    /// - "+" 最大值
    pub fn zrangeByLex(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8, opts: ZRangeOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZRANGEBYLEX");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addStr(min);
        _ = try self.conn.cmd_builder.addStr(max);

        if (opts.offset != null or opts.count != null) {
            _ = try self.conn.cmd_builder.addStr("LIMIT");
            _ = try self.conn.cmd_builder.addInt(opts.offset orelse 0);
            _ = try self.conn.cmd_builder.addInt(opts.count orelse 10);
        }

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// ZLEXCOUNT - 统计字典序范围内的成员数
    pub fn zlexcount(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "ZLEXCOUNT", key, min, max });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZREMRANGEBYRANK - 按排名范围移除成员
    ///
    /// 返回移除的成员数量
    pub fn zremrangeByRank(self: ZSetCommands, key: []const u8, start: i64, stop: i64) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZREMRANGEBYRANK");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(start);
        _ = try self.conn.cmd_builder.addInt(stop);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZREMRANGEBYSCORE - 按分数范围移除成员
    pub fn zremrangeByScore(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "ZREMRANGEBYSCORE", key, min, max });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZREMRANGEBYLEX - 按字典序范围移除成员
    pub fn zremrangeByLex(self: ZSetCommands, key: []const u8, min: []const u8, max: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "ZREMRANGEBYLEX", key, min, max });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZINTERSTORE - 交集并存储
    ///
    /// 将多个有序集合的交集存储到目标键
    /// 返回结果集合的成员数量
    pub fn zinterStore(self: ZSetCommands, destination: []const u8, keys: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZINTERSTORE");
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addUint(@as(u64, keys.len));
        _ = try self.conn.cmd_builder.addSlice(keys);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZUNIONSTORE - 并集并存储
    pub fn zunionStore(self: ZSetCommands, destination: []const u8, keys: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZUNIONSTORE");
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addUint(@as(u64, keys.len));
        _ = try self.conn.cmd_builder.addSlice(keys);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// ZSCAN - 增量迭代有序集合
    pub fn zscan(self: ZSetCommands, key: []const u8, cursor: u64, opts: types.ScanOptions) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("ZSCAN");
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

    /// ZPOPMIN - 弹出分数最低的成员（Redis 5.0+）
    pub fn zpopmin(self: ZSetCommands, key: []const u8, count: ?u64) !Reply {
        if (count) |c| {
            self.conn.mutex.lock();
            defer self.conn.mutex.unlock();

            self.conn.cmd_builder.reset();
            _ = try self.conn.cmd_builder.addStr("ZPOPMIN");
            _ = try self.conn.cmd_builder.addStr(key);
            _ = try self.conn.cmd_builder.addUint(c);

            return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        }
        return self.conn.sendCommand(&.{ "ZPOPMIN", key });
    }

    /// ZPOPMAX - 弹出分数最高的成员（Redis 5.0+）
    pub fn zpopmax(self: ZSetCommands, key: []const u8, count: ?u64) !Reply {
        if (count) |c| {
            self.conn.mutex.lock();
            defer self.conn.mutex.unlock();

            self.conn.cmd_builder.reset();
            _ = try self.conn.cmd_builder.addStr("ZPOPMAX");
            _ = try self.conn.cmd_builder.addStr(key);
            _ = try self.conn.cmd_builder.addUint(c);

            return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        }
        return self.conn.sendCommand(&.{ "ZPOPMAX", key });
    }

    /// BZPOPMIN - 阻塞式 ZPOPMIN（Redis 5.0+）
    pub fn bzpopmin(self: ZSetCommands, keys: []const []const u8, timeout: f64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("BZPOPMIN");
        _ = try self.conn.cmd_builder.addSlice(keys);
        _ = try self.conn.cmd_builder.addFloat(timeout);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// BZPOPMAX - 阻塞式 ZPOPMAX（Redis 5.0+）
    pub fn bzpopmax(self: ZSetCommands, keys: []const []const u8, timeout: f64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("BZPOPMAX");
        _ = try self.conn.cmd_builder.addSlice(keys);
        _ = try self.conn.cmd_builder.addFloat(timeout);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }
};

/// 便捷函数：创建 ZSet 命令接口
pub fn zset(conn: *Connection) ZSetCommands {
    return ZSetCommands.init(conn);
}
