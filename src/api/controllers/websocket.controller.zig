const std = @import("std");
const zap = @import("zap");
const zigcms = @import("zigcms");
const WebSocketServer = zigcms.infrastructure.websocket.WebSocketServer;
const MessageHandler = zigcms.infrastructure.websocket.MessageHandler;

/// WebSocket 控制器
pub const WebSocketController = struct {
    allocator: std.mem.Allocator,
    ws_server: *WebSocketServer,
    handler: MessageHandler,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, ws_server: *WebSocketServer) Self {
        return .{
            .allocator = allocator,
            .ws_server = ws_server,
            .handler = MessageHandler.init(allocator, ws_server),
        };
    }

    /// WebSocket 连接处理
    pub fn handleConnection(self: *Self, req: zap.Request) !void {
        // 升级到 WebSocket
        const ws = try req.upgradeToWebSocket();

        // 添加客户端
        const client_id = try self.ws_server.addClient(ws);

        // 设置消息处理器
        ws.onMessage(struct {
            controller: *Self,
            client_id: u32,

            pub fn callback(ctx: @This(), message: []const u8) void {
                ctx.controller.handler.handleMessage(ctx.client_id, message) catch |err| {
                    std.log.err("Failed to handle message: {}", .{err});
                };
            }
        }{ .controller = self, .client_id = client_id });

        // 设置关闭处理器
        ws.onClose(struct {
            server: *WebSocketServer,
            client_id: u32,

            pub fn callback(ctx: @This()) void {
                ctx.server.removeClient(ctx.client_id);
            }
        }{ .server = self.ws_server, .client_id = client_id });
    }

    /// 获取在线统计
    pub fn getStats(self: *Self, req: zap.Request) !void {
        const stats = .{
            .client_count = self.ws_server.getClientCount(),
            .user_count = self.ws_server.getUserCount(),
        };

        try req.sendJson(stats);
    }
};

/// 路由注册
pub fn registerRoutes(app: *zap.App, controller: *WebSocketController) !void {
    try app.route("GET", "/ws", controller.handleConnection);
    try app.route("GET", "/api/ws/stats", controller.getStats);
}
