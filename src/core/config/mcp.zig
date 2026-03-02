/// MCP 配置
/// 符合 ZigCMS 配置规范
const std = @import("std");

/// MCP 配置结构
pub const McpConfig = struct {
    /// 服务名称
    name: []const u8 = "ZigCMS_MCP",
    
    /// 版本号
    version: []const u8 = "v1.0.0",
    
    /// 是否启用
    enabled: bool = true,
    
    /// 传输配置
    transport: TransportConfig = .{},
    
    /// 安全配置
    security: SecurityConfig = .{},
    
    /// 工具配置
    tools: ToolsConfig = .{},
    
    /// 传输配置
    pub const TransportConfig = struct {
        /// 传输类型 (sse/stdio)
        type: []const u8 = "sse",
        
        /// 监听地址
        host: []const u8 = "127.0.0.1",
        
        /// 监听端口
        port: u16 = 8889,
        
        /// SSE 端点路径
        sse_path: []const u8 = "/mcp/sse",
        
        /// 消息端点路径
        message_path: []const u8 = "/mcp/message",
        
        /// 心跳间隔（秒）
        heartbeat_interval: u32 = 30,
    };
    
    /// 安全配置
    pub const SecurityConfig = struct {
        /// 允许访问的路径
        allowed_paths: []const []const u8 = &.{
            "src/",
            "docs/",
            "knowlages/",
        },
        
        /// 禁止访问的路径
        forbidden_paths: []const []const u8 = &.{
            ".git/",
            ".env",
            "config/secrets/",
            "node_modules/",
        },
        
        /// 允许的文件扩展名
        allowed_extensions: []const []const u8 = &.{
            ".zig",
            ".md",
            ".yaml",
            ".json",
            ".toml",
        },
        
        /// 最大文件大小（字节）
        max_file_size: usize = 10 * 1024 * 1024, // 10MB
    };
    
    /// 工具配置
    pub const ToolsConfig = struct {
        /// 启用的工具列表
        enabled: []const []const u8 = &.{
            "project_structure",
            "file_search",
            "file_read",
            "generate_crud",
            "generate_model",
            "generate_controller",
        },
    };
    
    /// 从 YAML 加载配置
    pub fn loadFromYaml(allocator: std.mem.Allocator, path: []const u8) !McpConfig {
        _ = allocator;
        _ = path;
        // TODO: 实现 YAML 加载
        return McpConfig{};
    }
    
    /// 验证配置
    pub fn validate(self: *const McpConfig) !void {
        if (self.name.len == 0) return error.InvalidName;
        if (self.version.len == 0) return error.InvalidVersion;
        if (self.transport.port == 0) return error.InvalidPort;
    }
};
