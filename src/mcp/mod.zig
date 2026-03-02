/// MCP 模块入口
/// Model Context Protocol for ZigCMS
pub const server = @import("server.zig");
pub const transport = @import("transport/mod.zig");
pub const protocol = @import("protocol/mod.zig");
pub const tools = @import("tools/mod.zig");

pub const McpServer = server.McpServer;
pub const ServerStatus = server.ServerStatus;
