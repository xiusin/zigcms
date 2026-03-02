/// 文件读取工具
/// 符合 ZigCMS 安全规范
const std = @import("std");
const protocol = @import("../protocol/mod.zig");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;

/// 文件读取工具
pub const FileReadTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) FileReadTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 获取工具信息
    pub fn getInfo(self: *const FileReadTool) protocol.ToolInfo {
        _ = self;
        return .{
            .name = "file_read",
            .description = "Read file content with security checks",
            .inputSchema = std.json.Value{
                .object = std.json.ObjectMap.init(self.allocator),
            },
        };
    }
    
    /// 执行读取
    pub fn execute(self: *FileReadTool, params: std.json.Value) !std.json.Value {
        const path = params.object.get("path") orelse return error.MissingPath;
        
        // 安全检查
        if (!try self.isPathAllowed(path.string)) {
            return error.PathNotAllowed;
        }
        
        if (!try self.isExtensionAllowed(path.string)) {
            return error.ExtensionNotAllowed;
        }
        
        // 使用 Arena 分配器
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        // 读取文件
        const content = try std.fs.cwd().readFileAlloc(
            arena_alloc,
            path.string,
            self.security.max_file_size,
        );
        
        // 过滤敏感信息
        const filtered = try self.filterSensitive(content, arena_alloc);
        
        // 构建响应
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("path", std.json.Value{ .string = path.string });
        try result.put("content", std.json.Value{ .string = filtered });
        try result.put("size", std.json.Value{ .integer = @intCast(content.len) });
        
        return std.json.Value{ .object = result };
    }
    
    /// 检查路径是否允许
    fn isPathAllowed(self: *const FileReadTool, path: []const u8) !bool {
        for (self.security.allowed_paths) |allowed| {
            if (std.mem.startsWith(u8, path, allowed)) {
                for (self.security.forbidden_paths) |forbidden| {
                    if (std.mem.indexOf(u8, path, forbidden) != null) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }
    
    /// 检查扩展名是否允许
    fn isExtensionAllowed(self: *const FileReadTool, path: []const u8) !bool {
        const ext = std.fs.path.extension(path);
        if (ext.len == 0) return false;
        
        for (self.security.allowed_extensions) |allowed| {
            if (std.mem.eql(u8, ext, allowed)) {
                return true;
            }
        }
        return false;
    }
    
    /// 过滤敏感信息
    fn filterSensitive(self: *const FileReadTool, content: []const u8, arena_alloc: std.mem.Allocator) ![]const u8 {
        _ = self;
        
        // 简单实现：检测常见的敏感字段
        const sensitive_patterns = [_][]const u8{
            "password",
            "secret",
            "api_key",
            "token",
            "private_key",
        };
        
        var has_sensitive = false;
        for (sensitive_patterns) |pattern| {
            if (std.mem.indexOf(u8, content, pattern) != null) {
                has_sensitive = true;
                break;
            }
        }
        
        if (has_sensitive) {
            // 添加警告注释
            const warning = "// ⚠️ This file may contain sensitive information\n";
            const filtered = try arena_alloc.alloc(u8, warning.len + content.len);
            @memcpy(filtered[0..warning.len], warning);
            @memcpy(filtered[warning.len..], content);
            return filtered;
        }
        
        return content;
    }
};
