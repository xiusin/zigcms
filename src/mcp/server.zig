/// MCP Server 主逻辑
/// 符合 ZigCMS 整洁架构规范
const std = @import("std");
const zap = @import("zap");
const McpConfig = @import("../core/config/mcp.zig").McpConfig;
const transport = @import("transport/mod.zig");
const protocol = @import("protocol/mod.zig");
const tools = @import("tools/mod.zig");

/// MCP Server
pub const McpServer = struct {
    allocator: std.mem.Allocator,
    config: McpConfig,
    sse_transport: *transport.SseTransport,
    project_structure_tool: tools.ProjectStructureTool,
    file_search_tool: tools.FileSearchTool,
    file_read_tool: tools.FileReadTool,
    crud_generator_tool: tools.CrudGeneratorTool,
    model_generator_tool: tools.ModelGeneratorTool,
    migration_generator_tool: tools.MigrationGeneratorTool,
    test_generator_tool: tools.TestGeneratorTool,
    knowledge_base_tool: tools.KnowledgeBaseTool,
    database_tool: tools.DatabaseTool,
    running: bool,
    
    pub fn init(allocator: std.mem.Allocator, config: McpConfig) !*McpServer {
        // 验证配置
        try config.validate();
        
        const self = try allocator.create(McpServer);
        errdefer allocator.destroy(self);
        
        // 初始化传输层
        const sse_transport = try transport.SseTransport.init(allocator, config.transport);
        errdefer sse_transport.deinit();
        
        // 初始化工具
        const project_structure_tool = tools.ProjectStructureTool.init(allocator, config.security);
        const file_search_tool = tools.FileSearchTool.init(allocator, config.security);
        const file_read_tool = tools.FileReadTool.init(allocator, config.security);
        const crud_generator_tool = tools.CrudGeneratorTool.init(allocator, config.security);
        const model_generator_tool = tools.ModelGeneratorTool.init(allocator, config.security);
        const migration_generator_tool = tools.MigrationGeneratorTool.init(allocator, config.security);
        const test_generator_tool = tools.TestGeneratorTool.init(allocator, config.security);
        const knowledge_base_tool = tools.KnowledgeBaseTool.init(allocator, config.security);
        const database_tool = tools.DatabaseTool.init(allocator, config.security);
        
        self.* = .{
            .allocator = allocator,
            .config = config,
            .sse_transport = sse_transport,
            .project_structure_tool = project_structure_tool,
            .file_search_tool = file_search_tool,
            .file_read_tool = file_read_tool,
            .crud_generator_tool = crud_generator_tool,
            .model_generator_tool = model_generator_tool,
            .migration_generator_tool = migration_generator_tool,
            .test_generator_tool = test_generator_tool,
            .knowledge_base_tool = knowledge_base_tool,
            .database_tool = database_tool,
            .running = false,
        };
        
        return self;
    }
    
    pub fn deinit(self: *McpServer) void {
        self.sse_transport.deinit();
        self.allocator.destroy(self);
    }
    
    /// 启动服务器
    pub fn start(self: *McpServer) !void {
        if (!self.config.enabled) {
            std.log.info("MCP Server is disabled", .{});
            return;
        }
        
        self.running = true;
        
        std.log.info("MCP Server starting on {s}:{d}", .{
            self.config.transport.host,
            self.config.transport.port,
        });
        
        // TODO: 启动 HTTP 服务器
        // 注册路由：
        // - GET /mcp/sse -> handleSse
        // - POST /mcp/message -> handleMessage
        
        std.log.info("MCP Server started successfully", .{});
        std.log.info("SSE Endpoint: http://{s}:{d}{s}", .{
            self.config.transport.host,
            self.config.transport.port,
            self.config.transport.sse_path,
        });
        std.log.info("Message Endpoint: http://{s}:{d}{s}", .{
            self.config.transport.host,
            self.config.transport.port,
            self.config.transport.message_path,
        });
    }
    
    /// 停止服务器
    pub fn stop(self: *McpServer) void {
        self.running = false;
        std.log.info("MCP Server stopped", .{});
    }
    
    /// 处理 SSE 连接
    pub fn handleSse(self: *McpServer, req: *zap.Request) !void {
        try self.sse_transport.handleSse(req);
    }
    
    /// 处理消息
    pub fn handleMessage(self: *McpServer, req: *zap.Request) !void {
        try self.sse_transport.handleMessage(req);
    }
    
    /// 获取服务器状态
    pub fn getStatus(self: *const McpServer) ServerStatus {
        return .{
            .running = self.running,
            .active_connections = self.sse_transport.getActiveConnections(),
            .version = self.config.version,
        };
    }
};

/// 服务器状态
pub const ServerStatus = struct {
    running: bool,
    active_connections: usize,
    version: []const u8,
};
