const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

/// WebSocket 客户端
pub const Client = struct {
    id: u32,
    user_id: ?u32,
    conn: *zap.WebSocket,
    last_heartbeat: i64,
    allocator: Allocator,

    pub fn init(allocator: Allocator, id: u32, conn: *zap.WebSocket) !*Client {
        const client = try allocator.create(Client);
        client.* = .{
            .id = id,
            .user_id = null,
            .conn = conn,
            .last_heartbeat = std.time.timestamp(),
            .allocator = allocator,
        };
        return client;
    }

    pub fn deinit(self: *Client) void {
        self.allocator.destroy(self);
    }

    pub fn send(self: *Client, message: []const u8) !void {
        try self.conn.send(message);
    }

    pub fn updateHeartbeat(self: *Client) void {
        self.last_heartbeat = std.time.timestamp();
    }

    pub fn isAlive(self: *Client) bool {
        const now = std.time.timestamp();
        const timeout = 60; // 60秒超时
        return (now - self.last_heartbeat) < timeout;
    }
};

/// WebSocket 消息类型
pub const MessageType = enum {
    auth,
    heartbeat,
    alert,
    event,
    notification,
    error_msg,

    pub fn toString(self: MessageType) []const u8 {
        return switch (self) {
            .auth => "auth",
            .heartbeat => "heartbeat",
            .alert => "alert",
            .event => "event",
            .notification => "notification",
            .error_msg => "error",
        };
    }
};

/// WebSocket 消息
pub const Message = struct {
    type: MessageType,
    data: std.json.Value,

    pub fn toJson(self: Message, allocator: Allocator) ![]u8 {
        var string = std.ArrayList(u8).init(allocator);
        defer string.deinit();

        try std.json.stringify(.{
            .type = self.type.toString(),
            .data = self.data,
        }, .{}, string.writer());

        return try string.toOwnedSlice();
    }
};

/// WebSocket 服务器
pub const WebSocketServer = struct {
    allocator: Allocator,
    clients: std.AutoHashMap(u32, *Client),
    user_clients: std.AutoHashMap(u32, std.ArrayList(u32)),
    next_client_id: u32,
    mutex: std.Thread.Mutex,
    heartbeat_timer: ?std.time.Timer,

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        const server = try allocator.create(Self);
        server.* = .{
            .allocator = allocator,
            .clients = std.AutoHashMap(u32, *Client).init(allocator),
            .user_clients = std.AutoHashMap(u32, std.ArrayList(u32)).init(allocator),
            .next_client_id = 1,
            .mutex = std.Thread.Mutex{},
            .heartbeat_timer = null,
        };
        return server;
    }

    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 清理所有客户端
        var it = self.clients.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.clients.deinit();

        // 清理用户客户端映射
        var user_it = self.user_clients.iterator();
        while (user_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.user_clients.deinit();

        self.allocator.destroy(self);
    }

    /// 添加客户端
    pub fn addClient(self: *Self, conn: *zap.WebSocket) !u32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const client_id = self.next_client_id;
        self.next_client_id += 1;

        const client = try Client.init(self.allocator, client_id, conn);
        try self.clients.put(client_id, client);

        std.log.info("WebSocket client connected: {d}", .{client_id});
        return client_id;
    }

    /// 移除客户端
    pub fn removeClient(self: *Self, client_id: u32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.clients.get(client_id)) |client| {
            // 从用户映射中移除
            if (client.user_id) |user_id| {
                if (self.user_clients.getPtr(user_id)) |client_list| {
                    for (client_list.items, 0..) |id, i| {
                        if (id == client_id) {
                            _ = client_list.swapRemove(i);
                            break;
                        }
                    }
                }
            }

            client.deinit();
            _ = self.clients.remove(client_id);
            std.log.info("WebSocket client disconnected: {d}", .{client_id});
        }
    }

    /// 认证客户端
    pub fn authenticateClient(self: *Self, client_id: u32, user_id: u32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.clients.getPtr(client_id)) |client| {
            client.*.user_id = user_id;

            // 添加到用户映射
            const result = try self.user_clients.getOrPut(user_id);
            if (!result.found_existing) {
                result.value_ptr.* = std.ArrayList(u32).init(self.allocator);
            }
            try result.value_ptr.append(client_id);

            std.log.info("WebSocket client authenticated: {d} -> user {d}", .{ client_id, user_id });
        }
    }

    /// 发送消息到客户端
    pub fn sendToClient(self: *Self, client_id: u32, message: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.clients.get(client_id)) |client| {
            const json = try message.toJson(self.allocator);
            defer self.allocator.free(json);

            try client.send(json);
        }
    }

    /// 发送消息到用户的所有客户端
    pub fn sendToUser(self: *Self, user_id: u32, message: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.user_clients.get(user_id)) |client_list| {
            const json = try message.toJson(self.allocator);
            defer self.allocator.free(json);

            for (client_list.items) |client_id| {
                if (self.clients.get(client_id)) |client| {
                    client.send(json) catch |err| {
                        std.log.err("Failed to send message to client {d}: {}", .{ client_id, err });
                    };
                }
            }
        }
    }

    /// 广播消息到所有客户端
    pub fn broadcast(self: *Self, message: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const json = try message.toJson(self.allocator);
        defer self.allocator.free(json);

        var it = self.clients.iterator();
        while (it.next()) |entry| {
            const client = entry.value_ptr.*;
            client.send(json) catch |err| {
                std.log.err("Failed to broadcast to client {d}: {}", .{ client.id, err });
            };
        }
    }

    /// 广播消息到已认证的客户端
    pub fn broadcastToAuthenticated(self: *Self, message: Message) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const json = try message.toJson(self.allocator);
        defer self.allocator.free(json);

        var it = self.clients.iterator();
        while (it.next()) |entry| {
            const client = entry.value_ptr.*;
            if (client.user_id != null) {
                client.send(json) catch |err| {
                    std.log.err("Failed to broadcast to client {d}: {}", .{ client.id, err });
                };
            }
        }
    }

    /// 更新客户端心跳
    pub fn updateClientHeartbeat(self: *Self, client_id: u32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.clients.getPtr(client_id)) |client| {
            client.*.updateHeartbeat();
        }
    }

    /// 清理死连接
    pub fn cleanupDeadConnections(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var dead_clients = std.ArrayList(u32).init(self.allocator);
        defer dead_clients.deinit();

        var it = self.clients.iterator();
        while (it.next()) |entry| {
            const client = entry.value_ptr.*;
            if (!client.isAlive()) {
                dead_clients.append(client.id) catch {};
            }
        }

        for (dead_clients.items) |client_id| {
            std.log.info("Cleaning up dead connection: {d}", .{client_id});
            self.removeClient(client_id);
        }
    }

    /// 获取在线客户端数量
    pub fn getClientCount(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return @intCast(self.clients.count());
    }

    /// 获取在线用户数量
    pub fn getUserCount(self: *Self) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return @intCast(self.user_clients.count());
    }

    /// 启动心跳检测
    pub fn startHeartbeatCheck(self: *Self) !void {
        const thread = try std.Thread.spawn(.{}, heartbeatCheckLoop, .{self});
        thread.detach();
    }

    fn heartbeatCheckLoop(self: *Self) void {
        while (true) {
            std.time.sleep(30 * std.time.ns_per_s); // 每30秒检查一次
            self.cleanupDeadConnections();
        }
    }
};

/// WebSocket 消息处理器
pub const MessageHandler = struct {
    allocator: Allocator,
    server: *WebSocketServer,

    const Self = @This();

    pub fn init(allocator: Allocator, server: *WebSocketServer) Self {
        return .{
            .allocator = allocator,
            .server = server,
        };
    }

    pub fn handleMessage(self: *Self, client_id: u32, message: []const u8) !void {
        // 解析消息
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, message, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidMessage;

        const obj = root.object;
        const msg_type = obj.get("type") orelse return error.MissingType;
        if (msg_type != .string) return error.InvalidType;

        const type_str = msg_type.string;

        if (std.mem.eql(u8, type_str, "auth")) {
            try self.handleAuth(client_id, obj);
        } else if (std.mem.eql(u8, type_str, "heartbeat")) {
            try self.handleHeartbeat(client_id);
        } else {
            std.log.warn("Unknown message type: {s}", .{type_str});
        }
    }

    fn handleAuth(self: *Self, client_id: u32, obj: std.json.ObjectMap) !void {
        const data = obj.get("data") orelse return error.MissingData;
        if (data != .object) return error.InvalidData;

        const token = data.object.get("token") orelse return error.MissingToken;
        if (token != .string) return error.InvalidToken;

        // TODO: 验证 token，获取 user_id
        // 这里简化处理，实际应该调用认证服务
        const user_id: u32 = 1; // 示例

        try self.server.authenticateClient(client_id, user_id);

        // 发送认证成功消息
        const response = Message{
            .type = .auth,
            .data = .{ .object = std.json.ObjectMap.init(self.allocator) },
        };
        try self.server.sendToClient(client_id, response);
    }

    fn handleHeartbeat(self: *Self, client_id: u32) !void {
        self.server.updateClientHeartbeat(client_id);

        // 发送心跳响应
        const response = Message{
            .type = .heartbeat,
            .data = .{ .object = std.json.ObjectMap.init(self.allocator) },
        };
        try self.server.sendToClient(client_id, response);
    }
};
