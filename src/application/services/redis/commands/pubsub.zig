//! Redis Pub/Sub 命令实现
//!
//! Pub/Sub 是 Redis 的发布/订阅消息系统。
//! 发布者发送消息到频道，订阅者接收频道的消息。
//!
//! ## 重要特性
//!
//! 1. **一次性消息**: 消息不会持久化，错过就没了
//! 2. **阻塞模式**: 订阅后连接进入阻塞模式，只能执行有限命令
//! 3. **扇出**: 一条消息会发送给所有订阅者
//!
//! ## 使用场景
//!
//! - 实时通知
//! - 聊天室
//! - 配置更新广播
//!
//! ## 注意事项
//!
//! 订阅会阻塞连接，通常需要单独的连接处理订阅

const std = @import("std");
const Connection = @import("../connection.zig").Connection;
const Reply = @import("../reply.zig").Reply;
const types = @import("../types.zig");

/// 订阅消息类型
pub const MessageType = enum {
    /// 订阅确认
    subscribe,
    /// 取消订阅确认
    unsubscribe,
    /// 收到消息
    message,
    /// 模式订阅确认
    psubscribe,
    /// 模式取消订阅确认
    punsubscribe,
    /// 模式消息
    pmessage,
    /// 未知类型
    unknown,

    pub fn fromString(s: []const u8) MessageType {
        if (std.mem.eql(u8, s, "subscribe")) return .subscribe;
        if (std.mem.eql(u8, s, "unsubscribe")) return .unsubscribe;
        if (std.mem.eql(u8, s, "message")) return .message;
        if (std.mem.eql(u8, s, "psubscribe")) return .psubscribe;
        if (std.mem.eql(u8, s, "punsubscribe")) return .punsubscribe;
        if (std.mem.eql(u8, s, "pmessage")) return .pmessage;
        return .unknown;
    }
};

/// 订阅消息
pub const PubSubMessage = struct {
    /// 消息类型
    msg_type: MessageType,
    /// 频道名
    channel: []const u8,
    /// 消息内容（仅 message/pmessage 类型有效）
    payload: ?[]const u8,
    /// 模式（仅 pmessage 类型有效）
    pattern: ?[]const u8,
    /// 当前订阅数量（订阅/取消订阅时有效）
    count: ?i64,
};

/// Pub/Sub 命令接口
///
/// ## 订阅模式说明
///
/// 一旦进入订阅模式，连接只能执行以下命令：
/// - SUBSCRIBE / UNSUBSCRIBE
/// - PSUBSCRIBE / PUNSUBSCRIBE
/// - PING
/// - QUIT
///
/// 其他命令会返回错误
pub const PubSubCommands = struct {
    conn: *Connection,

    pub fn init(conn: *Connection) PubSubCommands {
        return .{ .conn = conn };
    }

    /// PUBLISH - 发布消息
    ///
    /// 将消息发送到指定频道
    /// 返回接收到消息的订阅者数量
    ///
    /// ## 时间复杂度: O(N+M)
    /// N = 订阅该频道的客户端数
    /// M = 订阅匹配模式的客户端数
    ///
    /// ## 使用示例
    /// ```zig
    /// const count = try pubsub.publish("news", "Hello World!");
    /// std.debug.print("Message sent to {} subscribers\n", .{count});
    /// ```
    pub fn publish(self: PubSubCommands, channel: []const u8, message: []const u8) !i64 {
        var reply = try self.conn.sendCommand(&.{ "PUBLISH", channel, message });
        defer reply.deinit();
        return reply.int() orelse 0;
    }

    /// SUBSCRIBE - 订阅频道
    ///
    /// 订阅一个或多个频道
    ///
    /// ## 阻塞说明
    ///
    /// 调用此方法后，连接进入订阅模式
    /// 需要使用 receiveMessage() 循环接收消息
    ///
    /// ## 使用示例
    /// ```zig
    /// var pubsub = PubSubCommands.init(conn);
    /// try pubsub.subscribe(&.{"channel1", "channel2"});
    ///
    /// // 接收消息循环
    /// while (true) {
    ///     if (try pubsub.receiveMessage()) |msg| {
    ///         std.debug.print("Got message: {s}\n", .{msg.payload.?});
    ///     }
    /// }
    /// ```
    pub fn subscribe(self: PubSubCommands, channel_list: []const []const u8) !void {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("SUBSCRIBE");
        _ = try self.conn.cmd_builder.addSlice(channel_list);

        // 发送订阅命令
        try self.conn.proto.sendCommand(self.conn.cmd_builder.getArgs());

        // 读取订阅确认（每个频道一个）
        for (channel_list) |_| {
            const value = try self.conn.proto.readReply();
            @import("../protocol.zig").freeRedisValue(self.conn.allocator, value);
        }
    }

    /// UNSUBSCRIBE - 取消订阅
    ///
    /// 取消订阅指定频道，如果 channels 为空则取消所有订阅
    pub fn unsubscribe(self: PubSubCommands, channel_list: []const []const u8) !void {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("UNSUBSCRIBE");
        if (channel_list.len > 0) {
            _ = try self.conn.cmd_builder.addSlice(channel_list);
        }

        try self.conn.proto.sendCommand(self.conn.cmd_builder.getArgs());

        // 读取取消订阅确认
        const count = if (channel_list.len > 0) channel_list.len else 1;
        for (0..count) |_| {
            const value = try self.conn.proto.readReply();
            @import("../protocol.zig").freeRedisValue(self.conn.allocator, value);
        }
    }

    /// PSUBSCRIBE - 模式订阅
    ///
    /// 订阅匹配给定模式的所有频道
    ///
    /// ## 模式语法
    ///
    /// - `*` 匹配任意字符
    /// - `?` 匹配单个字符
    /// - `[...]` 匹配字符类
    ///
    /// ## 使用示例
    /// ```zig
    /// // 订阅所有以 news. 开头的频道
    /// try pubsub.psubscribe(&.{"news.*"});
    ///
    /// // 订阅 user:1:notifications, user:2:notifications 等
    /// try pubsub.psubscribe(&.{"user:*:notifications"});
    /// ```
    pub fn psubscribe(self: PubSubCommands, patterns: []const []const u8) !void {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("PSUBSCRIBE");
        _ = try self.conn.cmd_builder.addSlice(patterns);

        try self.conn.proto.sendCommand(self.conn.cmd_builder.getArgs());

        // 读取订阅确认
        for (patterns) |_| {
            const value = try self.conn.proto.readReply();
            @import("../protocol.zig").freeRedisValue(self.conn.allocator, value);
        }
    }

    /// PUNSUBSCRIBE - 取消模式订阅
    pub fn punsubscribe(self: PubSubCommands, patterns: []const []const u8) !void {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("PUNSUBSCRIBE");
        if (patterns.len > 0) {
            _ = try self.conn.cmd_builder.addSlice(patterns);
        }

        try self.conn.proto.sendCommand(self.conn.cmd_builder.getArgs());

        // 读取取消订阅确认
        const count = if (patterns.len > 0) patterns.len else 1;
        for (0..count) |_| {
            const value = try self.conn.proto.readReply();
            @import("../protocol.zig").freeRedisValue(self.conn.allocator, value);
        }
    }

    /// 接收订阅消息
    ///
    /// 在订阅模式下调用，阻塞等待消息
    ///
    /// ## 返回值
    ///
    /// 返回 PubSubMessage 结构体，包含消息类型和内容
    /// 调用方需要检查消息类型来确定如何处理
    ///
    /// ## 错误处理
    ///
    /// 连接断开时返回错误
    pub fn receiveMessage(self: PubSubCommands) !?PubSubMessage {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        const value = self.conn.proto.readReply() catch |err| {
            return err;
        };
        defer @import("../protocol.zig").freeRedisValue(self.conn.allocator, value);

        // 解析消息
        const arr = value.asArray() orelse return null;
        if (arr.len < 3) return null;

        const type_str = arr[0].asString() orelse return null;
        const msg_type = MessageType.fromString(type_str);

        return switch (msg_type) {
            .subscribe, .unsubscribe, .psubscribe, .punsubscribe => PubSubMessage{
                .msg_type = msg_type,
                .channel = arr[1].asString() orelse "",
                .payload = null,
                .pattern = null,
                .count = arr[2].asInt(),
            },
            .message => PubSubMessage{
                .msg_type = msg_type,
                .channel = arr[1].asString() orelse "",
                .payload = arr[2].asString(),
                .pattern = null,
                .count = null,
            },
            .pmessage => blk: {
                if (arr.len < 4) break :blk null;
                break :blk PubSubMessage{
                    .msg_type = msg_type,
                    .channel = arr[2].asString() orelse "",
                    .payload = arr[3].asString(),
                    .pattern = arr[1].asString(),
                    .count = null,
                };
            },
            .unknown => null,
        };
    }

    /// PUBSUB CHANNELS - 列出活跃频道
    ///
    /// 返回当前有订阅者的频道列表
    /// 可以使用模式过滤
    pub fn channels(self: PubSubCommands, pattern: ?[]const u8) !Reply {
        if (pattern) |p| {
            return self.conn.sendCommand(&.{ "PUBSUB", "CHANNELS", p });
        }
        return self.conn.sendCommand(&.{ "PUBSUB", "CHANNELS" });
    }

    /// PUBSUB NUMSUB - 获取频道订阅者数量
    ///
    /// 返回格式: [channel1, count1, channel2, count2, ...]
    pub fn numsub(self: PubSubCommands, channel_list: []const []const u8) !Reply {
        self.conn.mutex.lock();
        defer self.conn.mutex.unlock();

        self.conn.cmd_builder.reset();
        _ = try self.conn.cmd_builder.addStr("PUBSUB");
        _ = try self.conn.cmd_builder.addStr("NUMSUB");
        _ = try self.conn.cmd_builder.addSlice(channel_list);

        return self.conn.sendCommandUnlocked(self.conn.cmd_builder.getArgs());
    }

    /// PUBSUB NUMPAT - 获取模式订阅数量
    ///
    /// 返回当前模式订阅的总数
    pub fn numpat(self: PubSubCommands) !i64 {
        var reply = try self.conn.sendCommand(&.{ "PUBSUB", "NUMPAT" });
        defer reply.deinit();
        return reply.int() orelse 0;
    }
};

/// 便捷函数：创建 Pub/Sub 命令接口
pub fn pubsub(conn: *Connection) PubSubCommands {
    return PubSubCommands.init(conn);
}

/// 订阅者结构体
///
/// 封装订阅相关操作，提供更友好的 API
///
/// ## 使用示例
/// ```zig
/// var subscriber = try Subscriber.init(pool.acquire(), allocator);
/// defer subscriber.deinit();
///
/// try subscriber.subscribe(&.{"channel1"});
///
/// while (try subscriber.next()) |msg| {
///     std.debug.print("Channel: {s}, Message: {s}\n",
///         .{msg.channel, msg.payload.?});
/// }
/// ```
pub const Subscriber = struct {
    conn: *Connection,
    allocator: std.mem.Allocator,
    subscribed: bool = false,

    pub fn init(conn: *Connection, allocator: std.mem.Allocator) Subscriber {
        return .{
            .conn = conn,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Subscriber) void {
        if (self.subscribed) {
            // 尝试取消订阅
            var cmd = PubSubCommands.init(self.conn);
            cmd.unsubscribe(&.{}) catch {};
            cmd.punsubscribe(&.{}) catch {};
        }
        self.conn.close();
    }

    /// 订阅频道
    pub fn subscribe(self: *Subscriber, channel_list: []const []const u8) !void {
        var cmd = PubSubCommands.init(self.conn);
        try cmd.subscribe(channel_list);
        self.subscribed = true;
    }

    /// 模式订阅
    pub fn psubscribe(self: *Subscriber, patterns: []const []const u8) !void {
        var cmd = PubSubCommands.init(self.conn);
        try cmd.psubscribe(patterns);
        self.subscribed = true;
    }

    /// 获取下一条消息
    pub fn next(self: *Subscriber) !?PubSubMessage {
        var cmd = PubSubCommands.init(self.conn);
        return cmd.receiveMessage();
    }
};
