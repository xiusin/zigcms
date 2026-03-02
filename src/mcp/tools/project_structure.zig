/// 项目结构工具
/// 符合 ZigCMS 架构规范
const std = @import("std");
const protocol = @import("../protocol/mod.zig");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;

/// 文件节点
const FileNode = struct {
    name: []const u8,
    type: []const u8, // "file" or "directory"
    path: []const u8,
    depth: usize,
};

/// 项目结构工具
pub const ProjectStructureTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) ProjectStructureTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 获取工具信息
    pub fn getInfo(self: *const ProjectStructureTool) protocol.ToolInfo {
        return .{
            .name = "project_structure",
            .description = "Get ZigCMS project structure and architecture information",
            .inputSchema = std.json.Value{
                .object = std.json.ObjectMap.init(self.allocator),
            },
        };
    }
    
    /// 执行工具
    pub fn execute(self: *ProjectStructureTool, params: std.json.Value) !std.json.Value {
        _ = params;
        
        // 使用 Arena 分配器管理临时内存
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        // 扫描项目结构
        var structure = std.array_list.AlignedManaged(FileNode, null).init(arena_alloc);
        try self.scanDirectory("src/", &structure, 0, arena_alloc);
        
        // 分析架构
        const architecture = try self.analyzeArchitecture(arena_alloc);
        
        // 构建响应
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("structure", std.json.Value{ .array = std.json.Array.init(arena_alloc) });
        try result.put("architecture", architecture);
        
        return std.json.Value{ .object = result };
    }
    
    /// 扫描目录
    fn scanDirectory(
        self: *ProjectStructureTool,
        path: []const u8,
        list: *std.ArrayList(FileNode),
        depth: usize,
        arena_alloc: std.mem.Allocator,
    ) !void {
        if (depth > 3) return; // 限制深度
        
        // 检查路径是否允许
        if (!try self.isPathAllowed(path)) return;
        
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (self.shouldSkip(entry.name)) continue;
            
            const node = FileNode{
                .name = try arena_alloc.dupe(u8, entry.name),
                .type = if (entry.kind == .directory) "directory" else "file",
                .path = try std.fs.path.join(arena_alloc, &.{ path, entry.name }),
                .depth = depth,
            };
            
            try list.append(node);
            
            if (entry.kind == .directory) {
                try self.scanDirectory(node.path, list, depth + 1, arena_alloc);
            }
        }
    }
    
    /// 分析架构
    fn analyzeArchitecture(self: *ProjectStructureTool, arena_alloc: std.mem.Allocator) !std.json.Value {
        _ = self;
        
        var arch = std.json.ObjectMap.init(arena_alloc);
        
        try arch.put("pattern", std.json.Value{ .string = "Clean Architecture + DDD" });
        
        var layers = std.json.Array.init(arena_alloc);
        try layers.append(std.json.Value{ .string = "api (Interface Layer)" });
        try layers.append(std.json.Value{ .string = "application (Application Layer)" });
        try layers.append(std.json.Value{ .string = "domain (Domain Layer)" });
        try layers.append(std.json.Value{ .string = "infrastructure (Infrastructure Layer)" });
        try layers.append(std.json.Value{ .string = "core (Core Layer)" });
        
        try arch.put("layers", std.json.Value{ .array = layers });
        
        return std.json.Value{ .object = arch };
    }
    
    /// 检查路径是否允许
    fn isPathAllowed(self: *const ProjectStructureTool, path: []const u8) !bool {
        // 检查是否在允许的路径中
        for (self.security.allowed_paths) |allowed| {
            if (std.mem.startsWith(u8, path, allowed)) {
                // 检查是否在禁止的路径中
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
    fn shouldSkip(self: *const ProjectStructureTool, name: []const u8) bool {
        _ = self;
        
        const skip_list = [_][]const u8{
            ".",
            "..",
            ".git",
            "node_modules",
            "zig-cache",
            "zig-out",
        };
        
        for (skip_list) |skip| {
            if (std.mem.eql(u8, name, skip)) return true;
        }
        
        return false;
    }
};
