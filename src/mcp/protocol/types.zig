/// MCP 协议类型定义
/// 符合 JSON-RPC 2.0 规范
const std = @import("std");

/// JSON-RPC 请求
pub const JsonRpcRequest = struct {
    /// 协议版本
    jsonrpc: []const u8 = "2.0",
    
    /// 请求 ID（可选）
    id: ?i64 = null,
    
    /// 方法名
    method: []const u8,
    
    /// 参数（可选）
    params: ?std.json.Value = null,
};

/// JSON-RPC 响应
pub const JsonRpcResponse = struct {
    /// 协议版本
    jsonrpc: []const u8 = "2.0",
    
    /// 请求 ID
    id: ?i64 = null,
    
    /// 结果（成功时）
    result: ?std.json.Value = null,
    
    /// 错误（失败时）
    @"error": ?JsonRpcError = null,
};

/// JSON-RPC 错误
pub const JsonRpcError = struct {
    /// 错误码
    code: i32,
    
    /// 错误消息
    message: []const u8,
    
    /// 错误数据（可选）
    data: ?std.json.Value = null,
};

/// 错误码枚举
pub const ErrorCode = enum(i32) {
    /// 解析错误
    parse_error = -32700,
    
    /// 无效请求
    invalid_request = -32600,
    
    /// 方法未找到
    method_not_found = -32601,
    
    /// 无效参数
    invalid_params = -32602,
    
    /// 内部错误
    internal_error = -32603,
    
    /// 服务器错误（自定义）
    server_error = -32000,
};

/// MCP 工具信息
pub const ToolInfo = struct {
    /// 工具名称
    name: []const u8,
    
    /// 工具描述
    description: []const u8,
    
    /// 输入模式（JSON Schema）
    inputSchema: std.json.Value,
};

/// MCP 资源信息
pub const ResourceInfo = struct {
    /// 资源 URI
    uri: []const u8,
    
    /// 资源名称
    name: []const u8,
    
    /// 资源描述
    description: []const u8,
    
    /// MIME 类型
    mimeType: []const u8,
};

/// MCP 提示信息
pub const PromptInfo = struct {
    /// 提示名称
    name: []const u8,
    
    /// 提示描述
    description: []const u8,
    
    /// 参数列表
    arguments: []PromptArgument,
};

/// 提示参数
pub const PromptArgument = struct {
    /// 参数名称
    name: []const u8,
    
    /// 参数描述
    description: []const u8,
    
    /// 是否必需
    required: bool,
};

/// 创建成功响应
pub fn createSuccessResponse(allocator: std.mem.Allocator, id: ?i64, result: std.json.Value) !JsonRpcResponse {
    _ = allocator;
    return JsonRpcResponse{
        .id = id,
        .result = result,
    };
}

/// 创建错误响应
pub fn createErrorResponse(allocator: std.mem.Allocator, id: ?i64, code: ErrorCode, message: []const u8) !JsonRpcResponse {
    _ = allocator;
    return JsonRpcResponse{
        .id = id,
        .@"error" = JsonRpcError{
            .code = @intFromEnum(code),
            .message = message,
        },
    };
}
