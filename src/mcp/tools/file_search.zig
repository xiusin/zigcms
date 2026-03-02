/// 文件搜索工具
/// 符合 ZigCMS 安全规范
const std = @import("std");
const protocol = @import("../protocol/mod.zig");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;

/// 搜索结果
const SearchResult = struct {
    path: []const u8,
    name: []const u8,
    type: []const u8,
    matches: usize,
};

/// 文件搜索工具
pub const FileSearchTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) FileSearchTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 获取工具信息
    pub fn getInfo(self: *const FileSearchTool) protocol.ToolInfo {
        _ = self;
        return .{
            .name = "file_search",
            .description = "Search files by name or content in ZigCMS project",
            .inputSchema = std.json.Value{
                .object = std.json.ObjectMap.init(self.allocator),
            },
        };
    }
    
    /// 执行搜索
    pub fn execute(self: *FileSearchTool, params: std.json.Value) !std.json.Value {
        const query = params.object.get("query") orelse return error.MissingQuery;
        const search_type = params.object.get("type") orelse std.json.Value{ .string = "filename" };
        
        // 使用 Arena 分配器
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        var results = std.ArrayList(SearchResult).init(arena_alloc);
        
        if (std.mem.eql(u8, search_type.string, "filename")) {
            try self.searchByFilename(query.string, &results, arena_alloc);
        } else if (std.mem.eql(u8, search_type.string, "content")) {
            try self.searchByContent(query.string, &results, arena_alloc);
        }
        
        // 构建响应
        var result_array = std.json.Array.init(arena_alloc);
        for (results.items) |result| {
            var obj = std.json.ObjectMap.init(arena_alloc);
            try obj.put("path", std.json.Value{ .string = result.path });
            try obj.put("name", std.json.Value{ .string = result.name });
            try obj.put("type", std.json.Value{ .string = result.type });
            try result_array.append(std.json.Value{ .object = obj });
        }
        
        return std.json.Value{ .array = result_array };
    }
    
    /// 按文件名搜索
    fn searchByFilename(
        self: *FileSearchTool,
        query: []const u8,
        results: *std.ArrayList(SearchResult),
        arena_alloc: std.mem.Allocator,
    ) !void {
        try self.walkDirectory("src/", query, results, arena_alloc);
    }
    
    /// 按内容搜索
    fn searchByContent(
        self: *FileSearchTool,
        query: []const u8,
        results: *std.ArrayList(SearchResult),
        arena_alloc: std.mem.Allocator,
    ) !void {
        _ = self;
        _ = query;
        _ = results;
        _ = arena_alloc;
        // TODO: 实现内容搜索
    }
    
    /// 遍历目录
    fn walkDirectory(
        self: *FileSearchTool,
        path: []const u8,
        query: []const u8,
        results: *std.ArrayList(SearchResult),
        arena_alloc: std.mem.Allocator,
    ) !void {
        // 检查路径是否允许
        if (!try self.isPathAllowed(path)) return;
        
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (self.shouldSkip(entry.name)) continue;
            
            const full_path = try std.fs.path.join(arena_alloc, &.{ path, entry.name });
            
            // 模糊匹配
            if (std.mem.indexOf(u8, entry.name, query) != null) {
                try results.append(.{
                    .path = full_path,
                    .name = try arena_alloc.dupe(u8, entry.name),
                    .type = if (entry.kind == .directory) "directory" else "file",
                    .matches = 1,
                });
            }
            
            if (entry.kind == .directory) {
                try self.walkDirectory(full_path, query, results, arena_alloc);
            }
        }
    }
    
    /// 检查路径是否允许
    fn isPathAllowed(self: *const FileSearchTool, path: []const u8) !bool {
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
    
    /// 是否应该跳过
    fn shouldSkip(self: *const FileSearchTool, name: []const u8) bool {
        _ = self;
        const skip_list = [_][]const u8{ ".", "..", ".git", "node_modules", "zig-cache", "zig-out" };
        for (skip_list) |skip| {
            if (std.mem.eql(u8, name, skip)) return true;
        }
        return false;
    }
};
