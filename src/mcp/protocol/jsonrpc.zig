/// JSON-RPC 2.0 协议实现
/// 符合 ZigCMS 错误处理规范
const std = @import("std");
const types = @import("types.zig");

/// JSON-RPC 处理器
pub const JsonRpcHandler = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) JsonRpcHandler {
        return .{ .allocator = allocator };
    }
    
    /// 解析请求
    pub fn parseRequest(self: *JsonRpcHandler, json_str: []const u8) !types.JsonRpcRequest {
        const parsed = try std.json.parseFromSlice(
            types.JsonRpcRequest,
            self.allocator,
            json_str,
            .{},
        );
        defer parsed.deinit();
        
        return parsed.value;
    }
    
    /// 序列化响应
    pub fn serializeResponse(self: *JsonRpcHandler, response: types.JsonRpcResponse) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, response, .{});
    }
    
    /// 验证请求
    pub fn validateRequest(self: *JsonRpcHandler, request: *const types.JsonRpcRequest) !void {
        _ = self;
        
        // 验证协议版本
        if (!std.mem.eql(u8, request.jsonrpc, "2.0")) {
            return error.InvalidJsonRpcVersion;
        }
        
        // 验证方法名
        if (request.method.len == 0) {
            return error.EmptyMethod;
        }
    }
};
