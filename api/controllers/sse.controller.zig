//! SSE (Server-Sent Events) 控制器 - 支持服务器推送事件
//!
//! 提供 SSE 支持，实现服务器向客户端推送事件的功能。
//! 遵循 Zig 内存安全规范，确保并发安全。

const std = @import("std");
const zap = @import("zap");
const logger = @import("../../application/services/logger/logger.zig");

pub const SSEController = struct {
    const Self = @This();

    const Handler = struct {
        allocator: std.mem.Allocator,
        /// 连接 ID
        connection_id: std.atomic.Value(usize) = .{},

        /// 活跃的 SSE 连接
        clients: std.AutoHashMap(usize, *zap.SSE),
        mutex: std.Thread.Mutex = .{},

        /// 事件计数器
        event_counter: std.atomic.Value(usize) = .{},

        /// 初始化处理器
        pub fn init(alloc: std.mem.Allocator) Handler {
            return .{
                .allocator = alloc,
                .clients = std.AutoHashMap(usize, *zap.SSE).init(alloc),
            };
        }

        /// 清理资源
        pub fn deinit(self: *Handler) void {
            self.clients.deinit();
        }

        /// 处理 SSE 连接
        pub fn onConnect(self: *Handler, sse: *zap.SSE) !void {
            const id = self.connection_id.fetchAdd(1, .monotonic);
            logger.info("SSE 客户端连接，ID: {}", .{id});

            // 添加到客户端列表
            _ = self.mutex.acquire();
            defer self.mutex.release();
            try self.clients.put(id, sse);

            // 发送连接确认事件
            const connect_event = try std.fmt.allocPrint(self.allocator, "event: connect\ndata: {{\"id\": {}, \"timestamp\": {}}}\n\n", .{ id, std.time.timestamp() });
            defer self.allocator.free(connect_event);

            sse.send(connect_event) catch |err| {
                logger.err("发送连接事件失败: {}", .{err});
            };
        }

        /// 处理 SSE 断开连接
        pub fn onDisconnect(self: *Handler, sse: *zap.SSE) void {
            logger.info("SSE 客户端断开连接", .{});

            // 从客户端列表移除
            _ = self.mutex.acquire();
            defer self.mutex.release();

            var iter = self.clients.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.* == sse) {
                    _ = self.clients.remove(entry.key_ptr.*);
                    break;
                }
            }
        }

        /// 广播事件到所有客户端
        pub fn broadcastEvent(self: *Handler, event_type: []const u8, data: []const u8) !void {
            const event_id = self.event_counter.fetchAdd(1, .monotonic);

            const event_msg = try std.fmt.allocPrint(self.allocator, "id: {}\nevent: {s}\ndata: {s}\n\n", .{ event_id, event_type, data });
            defer self.allocator.free(event_msg);

            _ = self.mutex.acquire();
            defer self.mutex.release();

            var iter = self.clients.valueIterator();
            while (iter.next()) |client_sse| {
                client_sse.*.send(event_msg) catch |err| {
                    logger.warn("广播 SSE 事件失败: {}", .{err});
                };
            }

            logger.debug("广播 SSE 事件: {s} - {s}", .{ event_type, data });
        }

        /// 发送心跳事件
        pub fn sendHeartbeat(self: *Handler) !void {
            const timestamp = std.time.timestamp();
            const heartbeat_data = try std.fmt.allocPrint(self.allocator, "{{\"timestamp\": {}, \"type\": \"heartbeat\"}}", .{timestamp});
            defer self.allocator.free(heartbeat_data);

            try self.broadcastEvent("heartbeat", heartbeat_data);
        }
    };

    allocator: std.mem.Allocator,

    /// 处理器实例
    handler: Handler,

    /// 心跳定时器
    heartbeat_timer: ?std.time.Timer,

    /// 初始化控制器
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .handler = Handler.init(allocator),
            .heartbeat_timer = null,
        };
    }

    /// 清理控制器
    pub fn deinit(self: *Self) void {
        if (self.heartbeat_timer) |timer| {
            timer.cancel();
        }
        self.handler.deinit();
    }

    /// 处理 SSE 连接请求
    pub fn connect(self: *Self, r: zap.Request) void {
        // 检查 Accept 头
        const accept_header = r.getHeader("accept") orelse {
            r.setStatus(.bad_request);
            r.sendJson("{\"error\":\"Missing accept header\"}") catch {};
            return;
        };

        if (std.mem.indexOf(u8, std.mem.span(accept_header), "text/event-stream") == null) {
            r.setStatus(.bad_request);
            r.sendJson("{\"error\":\"Invalid accept header\"}") catch {};
            return;
        }

        // 设置 SSE 响应头
        r.setHeader("Content-Type", "text/event-stream") catch {};
        r.setHeader("Cache-Control", "no-cache") catch {};
        r.setHeader("Connection", "keep-alive") catch {};
        r.setHeader("Access-Control-Allow-Origin", "*") catch {};
        r.setHeader("Access-Control-Allow-Headers", "Cache-Control") catch {};

        // 创建 SSE 连接
        const sse = r.startSSE() catch |err| {
            logger.err("SSE 连接启动失败: {}", .{err});
            r.setStatus(.internal_server_error);
            r.sendJson("{\"error\":\"SSE connection failed\"}") catch {};
            return;
        };

        // 设置处理器
        sse.set(.{
            .on_connect = Self.onConnectHandler,
            .on_disconnect = Self.onDisconnectHandler,
        }, &self.handler);

        logger.info("SSE 连接启动成功", .{});
    }

    /// SSE 连接处理器
    fn onConnectHandler(handler_ptr: *anyopaque, sse: *zap.SSE) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onConnect(sse) catch |err| {
            logger.err("SSE 连接处理失败: {}", .{err});
        };
    }

    /// SSE 断开处理器
    fn onDisconnectHandler(handler_ptr: *anyopaque, sse: *zap.SSE) void {
        const handler: *Handler = @ptrCast(@alignCast(handler_ptr));
        handler.onDisconnect(sse);
    }

    /// 广播自定义事件
    pub fn broadcastEvent(self: *Self, event_type: []const u8, data: []const u8) !void {
        try self.handler.broadcastEvent(event_type, data);
    }

    /// 发送心跳
    pub fn sendHeartbeat(self: *Self) !void {
        try self.handler.sendHeartbeat();
    }

    /// 获取连接数
    pub fn getConnectionCount(self: *const Self) usize {
        _ = self.handler.mutex.acquire();
        defer self.handler.mutex.release();
        return self.handler.clients.count();
    }
};
