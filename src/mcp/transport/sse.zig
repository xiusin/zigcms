/// SSE (Server-Sent Events) 传输层实现
/// 符合 ZigCMS 内存管理规范
const std = @import("std");
const zap = @import("zap");
const protocol = @import("../protocol/mod.zig");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;

/// SSE 连接
pub const Connection = struct {
    /// 连接 ID
    id: u64,
    
    /// 最后心跳时间
    last_ping: i64,
    
    /// 是否活跃
    active: bool,
};

/// SSE 传输层
pub const SseTransport = struct {
    allocator: std.mem.Allocator,
    config: McpConfig.TransportConfig,
    connections: std.AutoHashMap(u64, Connection),
    next_conn_id: u64,
    
    pub fn init(allocator: std.mem.Allocator, config: McpConfig.TransportConfig) !*SseTransport {
        const self = try allocator.create(SseTransport);
        self.* = .{
            .allocator = allocator,
            .config = config,
            .connections = std.AutoHashMap(u64, Connection).init(allocator),
            .next_conn_id = 1,
        };
        return self;
    }
    
    pub fn deinit(self: *SseTransport) void {
        self.connections.deinit();
        self.allocator.destroy(self);
    }
    
    /// 处理 SSE 连接
    pub fn handleSse(self: *SseTransport, req: *zap.Request) !void {
        // 设置 SSE 响应头
        try req.setHeader("Content-Type", "text/event-stream");
        try req.setHeader("Cache-Control", "no-cache");
        try req.setHeader("Connection", "keep-alive");
        try req.setHeader("Access-Control-Allow-Origin", "*");
        
        // 创建连接
        const conn_id = self.next_conn_id;
        self.next_conn_id += 1;
        
        const conn = Connection{
            .id = conn_id,
            .last_ping = std.time.timestamp(),
            .active = true,
        };
        
        try self.connections.put(conn_id, conn);
        
        // 发送连接成功事件
        const init_data = try std.fmt.allocPrint(
            self.allocator,
            "{{\"id\":{d},\"status\":\"connected\"}}",
            .{conn_id},
        );
        defer self.allocator.free(init_data);
        
        try self.sendEvent(req, "connected", init_data);
    }
    
    /// 处理消息
    pub fn handleMessage(self: *SseTransport, req: *zap.Request) !void {
        const body = req.body orelse return error.EmptyBody;
        
        // 解析 JSON-RPC 请求
        var handler = protocol.JsonRpcHandler.init(self.allocator);
        const request = try handler.parseRequest(body);
        
        // 验证请求
        try handler.validateRequest(&request);
        
        // 处理请求（TODO: 路由到具体工具）
        const response = protocol.types.createSuccessResponse(
            self.allocator,
            request.id,
            std.json.Value{ .null = {} },
        ) catch |err| {
            return protocol.types.createErrorResponse(
                self.allocator,
                request.id,
                .internal_error,
                @errorName(err),
            );
        };
        
        // 序列化响应
        const response_json = try handler.serializeResponse(response);
        defer self.allocator.free(response_json);
        
        // 发送响应
        try req.sendJson(response_json);
    }
    
    /// 发送 SSE 事件
    fn sendEvent(self: *SseTransport, req: *zap.Request, event: []const u8, data: []const u8) !void {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "event: {s}\ndata: {s}\n\n",
            .{ event, data },
        );
        defer self.allocator.free(message);
        
        try req.sendBody(message);
    }
    
    /// 心跳检测
    pub fn heartbeat(self: *SseTransport) !void {
        const now = std.time.timestamp();
        var to_remove = std.array_list.AlignedManaged(u64, null).init(self.allocator);
        defer to_remove.deinit();
        
        var it = self.connections.iterator();
        while (it.next()) |entry| {
            const conn = entry.value_ptr.*;
            if (now - conn.last_ping > self.config.heartbeat_interval) {
                try to_remove.append(conn.id);
            }
        }
        
        // 移除超时连接
        for (to_remove.items) |conn_id| {
            _ = self.connections.remove(conn_id);
        }
    }
    
    /// 获取活跃连接数
    pub fn getActiveConnections(self: *const SseTransport) usize {
        return self.connections.count();
    }
};
