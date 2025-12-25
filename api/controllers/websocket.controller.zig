//! WebSocket 控制器 - 支持现代化通信服务
//!
//! 提供 WebSocket 连接支持，包括连接升级、消息收发、广播等功能。
//! 遵循 Zig 内存安全规范，确保并发安全。

const std = @import("std");
const zap = @import("zap");
const logger = @import("../../application/services/logger/logger.zig");

pub const WebSocketController = struct {
    const Self = @This();

    const Handler = struct {
        allocator: std.mem.Allocator,
        /// 连接 ID，用于标识客户端
        connection_id: std.atomic.Atomic(usize) = .{},

        /// 连接的客户端列表
        clients: std.AutoHashMap(usize, *zap.WebSocket),
        mutex: std.Thread.Mutex = .{},

        /// 初始化处理器
        pub fn init(alloc: std.mem.Allocator) Handler {
            return .{
                .allocator = alloc,
                .clients = std.AutoHashMap(usize, *zap.WebSocket).init(alloc),
            };
        }

        /// 清理资源
        pub fn deinit(self: *Handler) void {
            self.clients.deinit();
        }

        /// 处理 WebSocket 连接
        pub fn onConnect(self: *Handler, ws: *zap.WebSocket) !void {
            const id = self.connection_id.fetchAdd(1, .monotonic);
            logger.info("WebSocket 客户端连接，ID: {}", .{id});

            // 添加到客户端列表
            _ = self.mutex.acquire();
            defer self.mutex.release();
            try self.clients.put(id, ws);

            // 发送欢迎消息
            const welcome_msg = std.fmt.allocPrint(self.allocator, "欢迎连接！您的ID是 {}", .{id}) catch |err| {
                logger.err("分配欢迎消息失败: {}", .{err});
                return err;
            };
            defer self.allocator.free(welcome_msg);

            ws.send(welcome_msg) catch |err| {
                logger.err("发送欢迎消息失败: {}", .{err});
            };
        }

        /// 处理 WebSocket 断开连接
        pub fn onDisconnect(self: *Handler, ws: *zap.WebSocket) void {
            logger.info("WebSocket 客户端断开连接", .{});

            // 从客户端列表移除
            _ = self.mutex.acquire();
            defer self.mutex.release();

            var iter = self.clients.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.* == ws) {
                    _ = self.clients.remove(entry.key_ptr.*);
                    break;
                }
            }
        }

        /// 处理接收到的消息
        pub fn onMessage(self: *Handler, _: *zap.WebSocket, message: []const u8) !void {
            logger.debug("收到 WebSocket 消息: {s}", .{message});

            // 广播消息给所有客户端
            const broadcast_msg = std.fmt.allocPrint(self.allocator, "广播: {s}", .{message}) catch |err| {
                logger.err("分配广播消息失败: {}", .{err});
                return err;
            };
            defer self.allocator.free(broadcast_msg);

            _ = self.mutex.acquire();
            defer self.mutex.release();

            var iter = self.clients.valueIterator();
            while (iter.next()) |client_ws| {
                client_ws.*.send(broadcast_msg) catch |err| {
                    logger.warn("广播消息失败: {}", .{err});
                };
            }
        }
    };

    /// 处理器实例
    handler: Handler,

    /// 初始化控制器
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .handler = Handler.init(allocator),
        };
    }

    /// 清理控制器
    pub fn deinit(self: *Self) void {
        self.handler.deinit();
    }

    /// 处理 WebSocket 升级请求
    pub fn upgrade(self: *Self, r: zap.Request) void {
        // 检查是否是 WebSocket 升级请求
        const upgrade_header = r.getHeader("upgrade") orelse {
            r.setStatus(.bad_request);
            r.sendJson("{\"error\":\"Missing upgrade header\"}") catch {};
            return;
        };

        if (!std.mem.eql(u8, std.mem.span(upgrade_header), "websocket")) {
            r.setStatus(.bad_request);
            r.sendJson("{\"error\":\"Invalid upgrade header\"}") catch {};
            return;
        }

        // 升级到 WebSocket 连接
        const ws = r.upgradeToWebSocket() catch |err| {
            logger.err("WebSocket 升级失败: {}", .{err});
            r.setStatus(.internal_server_error);
            r.sendJson("{\"error\":\"WebSocket upgrade failed\"}") catch {};
            return;
        };

        // 设置处理器
        ws.set(.{
            .on_connect = Self.onConnectHandler,
            .on_disconnect = Self.onDisconnectHandler,
            .on_message = Self.onMessageHandler,
        }, &self.handler);

        logger.info("WebSocket 连接升级成功", .{});
    }

    /// WebSocket 连接处理器
    fn onConnectHandler(handler_ptr: *anyopaque, ws: *zap.WebSocket) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onConnect(ws) catch |err| {
            logger.err("WebSocket 连接处理失败: {}", .{err});
        };
    }

    /// WebSocket 断开处理器
    fn onDisconnectHandler(handler_ptr: *anyopaque, ws: *zap.WebSocket) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onDisconnect(ws);
    }

    /// WebSocket 消息处理器
    fn onMessageHandler(handler_ptr: *anyopaque, ws: *zap.WebSocket, message: []const u8) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onMessage(ws, message) catch |err| {
            logger.err("WebSocket 消息处理失败: {}", .{err});
        };
    }

    /// WebSocket ping 处理器
    fn onPingHandler(handler_ptr: *anyopaque, ws: *zap.WebSocket, data: []const u8) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onPing(ws, data);
    }

    /// WebSocket pong 处理器
    fn onPongHandler(handler_ptr: *anyopaque, ws: *zap.WebSocket, data: []const u8) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onPong(ws, data);
    }

    /// 获取连接状态
    pub fn getConnectionCount(self: *const Self) usize {
        _ = self.handler.mutex.acquire();
        defer self.handler.mutex.release();
        return self.handler.clients.count();
    }
};
