//! Redis List 命令实现
//!
//! List 是简单的字符串列表，按插入顺序排序。
//! 可以从头部或尾部添加元素，支持阻塞操作。
//!
//! ## 应用场景
//! - 消息队列：LPUSH + BRPOP
//! - 最新消息列表：LPUSH + LTRIM
//! - 时间线：LPUSH + LRANGE

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

/// 阻塞弹出结果
pub const BPopResult = struct {
    key: []const u8,
    value: []const u8,
};

/// List 命令接口
pub const ListCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) ListCommands {
        return .{ .conn = conn };
    }

    /// LPUSH - 从左边（头部）插入元素
    ///
    /// 返回插入后列表的长度
    ///
    /// ## 时间复杂度: O(1) for each element
    ///
    /// ## 插入顺序
    ///
    /// 多个元素会从左到右依次插入头部，所以：
    /// LPUSH list a b c 结果是 [c, b, a]
    pub fn lpush(self: ListCommands, key: []const u8, values: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LPUSH");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(values);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// LPUSHX - 仅当列表存在时从左边插入
    pub fn lpushX(self: ListCommands, key: []const u8, value: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "LPUSHX", key, value });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// RPUSH - 从右边（尾部）插入元素
    ///
    /// 返回插入后列表的长度
    pub fn rpush(self: ListCommands, key: []const u8, values: []const []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("RPUSH");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addSlice(values);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// RPUSHX - 仅当列表存在时从右边插入
    pub fn rpushX(self: ListCommands, key: []const u8, value: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "RPUSHX", key, value });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// LPOP - 从左边弹出元素
    ///
    /// 移除并返回列表头部元素
    /// 列表为空时返回 nil
    ///
    /// ## 时间复杂度: O(1)
    pub fn lpop(self: ListCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "LPOP", key });
    }

    /// RPOP - 从右边弹出元素
    pub fn rpop(self: ListCommands, key: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "RPOP", key });
    }

    /// LLEN - 获取列表长度
    ///
    /// ## 时间复杂度: O(1)
    pub fn llen(self: ListCommands, key: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "LLEN", key });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// LRANGE - 获取范围内的元素
    ///
    /// 返回列表中指定范围的元素
    /// 支持负数索引，-1 表示最后一个元素
    ///
    /// ## 时间复杂度: O(S+N)，S 是起始偏移，N 是返回元素数
    ///
    /// ## 使用示例
    /// ```zig
    /// // 获取所有元素
    /// const reply = try list.lrange("mylist", 0, -1);
    /// defer reply.deinit();
    /// ```
    pub fn lrange(self: ListCommands, key: []const u8, start: i64, stop: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LRANGE");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(start);
        _ = try self.conn.cmd_builder.addInt(stop);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// LINDEX - 获取指定位置的元素
    ///
    /// ## 时间复杂度: O(N)，N 是遍历的元素数
    pub fn lindex(self: ListCommands, key: []const u8, index: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LINDEX");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(index);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// LSET - 设置指定位置的元素值
    ///
    /// 索引超出范围时返回错误
    ///
    /// ## 时间复杂度: O(N)
    pub fn lset(self: ListCommands, key: []const u8, index: i64, value: []const u8) !bool {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LSET");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(index);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// LINSERT - 在指定元素前/后插入
    ///
    /// ## 参数
    /// - before: true 在 pivot 前插入，false 在 pivot 后插入
    /// - pivot: 参照元素
    /// - value: 要插入的值
    ///
    /// ## 返回值
    /// - 成功：返回插入后列表长度
    /// - pivot 不存在：返回 -1
    /// - key 不存在：返回 0
    pub fn linsert(self: ListCommands, key: []const u8, before: bool, pivot: []const u8, value: []const u8) !i64 {
        const pos = if (before) "BEFORE" else "AFTER";

        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LINSERT");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addStr(pos);
        _ = try self.conn.cmd_builder.addStr(pivot);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse -1;
    }

    /// LREM - 移除元素
    ///
    /// 从列表中移除与 value 相等的元素
    ///
    /// ## count 参数含义
    /// - count > 0: 从头到尾移除 count 个
    /// - count < 0: 从尾到头移除 |count| 个
    /// - count = 0: 移除所有匹配的元素
    ///
    /// ## 返回值
    /// 返回实际移除的元素数量
    pub fn lrem(self: ListCommands, key: []const u8, count: i64, value: []const u8) !i64 {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LREM");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(count);
        _ = try self.conn.cmd_builder.addStr(value);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// LTRIM - 修剪列表
    ///
    /// 只保留指定范围内的元素，其他元素删除
    /// 常用于限制列表长度
    ///
    /// ## 使用示例
    /// ```zig
    /// // 只保留最新 100 个元素
    /// try list.lpush("news", &.{"new item"});
    /// try list.ltrim("news", 0, 99);
    /// ```
    pub fn ltrim(self: ListCommands, key: []const u8, start: i64, stop: i64) !bool {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("LTRIM");
        _ = try self.conn.cmd_builder.addStr(key);
        _ = try self.conn.cmd_builder.addInt(start);
        _ = try self.conn.cmd_builder.addInt(stop);

        var reply = try self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
        defer reply.deinit();
        return reply.isOk();
    }

    /// RPOPLPUSH - 从一个列表弹出，推入另一个列表
    ///
    /// 原子操作，适合实现可靠队列
    ///
    /// ## 可靠队列模式
    /// ```
    /// 1. RPOPLPUSH queue processing
    /// 2. 处理任务
    /// 3. LREM processing 1 <task>
    /// ```
    /// 如果步骤 2 失败，任务仍在 processing 列表中
    pub fn rpopLpush(self: ListCommands, source: []const u8, destination: []const u8) !Reply {
        return self.conn.sendCommand(&.{ "RPOPLPUSH", source, destination });
    }

    /// BLPOP - 阻塞式左弹出
    ///
    /// 如果列表为空，阻塞等待直到有元素或超时
    ///
    /// ## 参数
    /// - keys: 要监听的 key 列表
    /// - timeout: 超时秒数，0 表示永久阻塞
    ///
    /// ## 返回值
    /// 返回 [key, value]，超时返回 nil
    ///
    /// ## 多 key 监听
    ///
    /// 可以同时监听多个列表，返回第一个非空列表的元素
    /// 这是实现优先级队列的方式
    pub fn blpop(self: ListCommands, keys: []const []const u8, timeout: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("BLPOP");
        _ = try self.conn.cmd_builder.addSlice(keys);
        _ = try self.conn.cmd_builder.addInt(timeout);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// BRPOP - 阻塞式右弹出
    pub fn brpop(self: ListCommands, keys: []const []const u8, timeout: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("BRPOP");
        _ = try self.conn.cmd_builder.addSlice(keys);
        _ = try self.conn.cmd_builder.addInt(timeout);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// BRPOPLPUSH - 阻塞式 RPOPLPUSH
    pub fn brpopLpush(self: ListCommands, source: []const u8, destination: []const u8, timeout: i64) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("BRPOPLPUSH");
        _ = try self.conn.cmd_builder.addStr(source);
        _ = try self.conn.cmd_builder.addStr(destination);
        _ = try self.conn.cmd_builder.addInt(timeout);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// LPOS - 获取元素位置（Redis 6.0.6+）
    ///
    /// 返回元素在列表中的索引
    pub fn lpos(self: ListCommands, key: []const u8, element: []const u8) !?i64 {
        var reply = try self.conn.sendCommand(&.{ "LPOS", key, element });
        defer reply.deinit();

        if (reply.isNil()) {
            return null;
        }
        return reply.int();
    }
};

/// 便捷函数：创建 List 命令接口
pub fn list(conn: *Connection) ListCommands {
    return ListCommands.init(conn);
}
