const std = @import("std");
const WebSocketServer = @import("../websocket/ws_server.zig").WebSocketServer;
const Message = @import("../websocket/ws_server.zig").Message;
const MessageType = @import("../websocket/ws_server.zig").MessageType;

/// 安全监控器 WebSocket 扩展
pub const SecurityMonitorWebSocketExt = struct {
    allocator: std.mem.Allocator,
    ws_server: ?*WebSocketServer,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .ws_server = null,
        };
    }

    /// 设置 WebSocket 服务器
    pub fn setWebSocketServer(self: *Self, ws_server: *WebSocketServer) void {
        self.ws_server = ws_server;
    }

    /// 推送告警到 WebSocket
    pub fn pushAlert(self: *Self, alert: anytype) !void {
        if (self.ws_server) |ws| {
            // 构造消息
            const alert_json = try std.json.stringifyAlloc(self.allocator, alert, .{});
            defer self.allocator.free(alert_json);

            var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, alert_json, .{});
            defer parsed.deinit();

            const message = Message{
                .type = .alert,
                .data = parsed.value,
            };

            // 广播到所有已认证的客户端
            try ws.broadcastToAuthenticated(message);

            std.log.info("Alert pushed to WebSocket clients", .{});
        }
    }

    /// 推送事件到 WebSocket
    pub fn pushEvent(self: *Self, event: anytype) !void {
        if (self.ws_server) |ws| {
            // 构造消息
            const event_json = try std.json.stringifyAlloc(self.allocator, event, .{});
            defer self.allocator.free(event_json);

            var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, event_json, .{});
            defer parsed.deinit();

            const message = Message{
                .type = .event,
                .data = parsed.value,
            };

            // 广播到所有已认证的客户端
            try ws.broadcastToAuthenticated(message);

            std.log.info("Event pushed to WebSocket clients", .{});
        }
    }

    /// 推送通知到特定用户
    pub fn pushNotificationToUser(self: *Self, user_id: u32, notification: anytype) !void {
        if (self.ws_server) |ws| {
            // 构造消息
            const notif_json = try std.json.stringifyAlloc(self.allocator, notification, .{});
            defer self.allocator.free(notif_json);

            var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, notif_json, .{});
            defer parsed.deinit();

            const message = Message{
                .type = .notification,
                .data = parsed.value,
            };

            // 发送到特定用户
            try ws.sendToUser(user_id, message);

            std.log.info("Notification pushed to user {d}", .{user_id});
        }
    }

    /// 推送通知到所有用户
    pub fn pushNotificationToAll(self: *Self, notification: anytype) !void {
        if (self.ws_server) |ws| {
            // 构造消息
            const notif_json = try std.json.stringifyAlloc(self.allocator, notification, .{});
            defer self.allocator.free(notif_json);

            var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, notif_json, .{});
            defer parsed.deinit();

            const message = Message{
                .type = .notification,
                .data = parsed.value,
            };

            // 广播到所有已认证的客户端
            try ws.broadcastToAuthenticated(message);

            std.log.info("Notification pushed to all users", .{});
        }
    }
};
