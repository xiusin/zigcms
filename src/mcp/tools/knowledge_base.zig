/// MCP 知识库问答工具
/// 提供项目文档、架构、最佳实践的智能问答
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const SecurityConfig = McpConfig.SecurityConfig;

/// 知识库问答工具
pub const KnowledgeBaseTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: SecurityConfig) KnowledgeBaseTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 执行知识库查询
    pub fn execute(self: *KnowledgeBaseTool, query: []const u8) ![]const u8 {
        // 搜索相关文档
        const docs = try self.searchDocs(query);
        defer self.allocator.free(docs);
        
        // 构建答案
        return try self.buildAnswer(query, docs);
    }
    
    /// 搜索相关文档
    fn searchDocs(self: *KnowledgeBaseTool, query: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        // 知识库目录
        const kb_dirs = [_][]const u8{
            "docs",
            "src/mcp/docs",
            "knowlages",
            "AGENTS.md",
            "README.md",
        };
        
        // 搜索关键词
        const keywords = try self.extractKeywords(query);
        defer self.allocator.free(keywords);
        
        // 遍历知识库目录
        for (kb_dirs) |dir| {
            try self.searchInDir(dir, keywords, &result);
        }
        
        return result.toOwnedSlice();
    }
    
    /// 在目录中搜索
    fn searchInDir(self: *KnowledgeBaseTool, dir_path: []const u8, keywords: []const []const u8, result: *std.ArrayList(u8)) !void {
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
                try self.searchInFile(dir, entry.name, keywords, result);
            }
        }
    }
    
    /// 在文件中搜索
    fn searchInFile(self: *KnowledgeBaseTool, dir: std.fs.Dir, filename: []const u8, keywords: []const []const u8, result: *std.ArrayList(u8)) !void {
        const content = dir.readFileAlloc(self.allocator, filename, 1024 * 1024) catch return;
        defer self.allocator.free(content);
        
        // 检查是否包含关键词
        var matched = false;
        for (keywords) |keyword| {
            if (std.mem.indexOf(u8, content, keyword) != null) {
                matched = true;
                break;
            }
        }
        
        if (matched) {
            try result.appendSlice("## ");
            try result.appendSlice(filename);
            try result.appendSlice("\n\n");
            
            // 提取相关段落（前 500 字符）
            const preview_len = @min(500, content.len);
            try result.appendSlice(content[0..preview_len]);
            try result.appendSlice("\n\n---\n\n");
        }
    }
    
    /// 提取关键词
    fn extractKeywords(self: *KnowledgeBaseTool, query: []const u8) ![]const []const u8 {
        var keywords = std.ArrayList([]const u8).init(self.allocator);
        errdefer keywords.deinit();
        
        // 简单分词（按空格分割）
        var iter = std.mem.splitScalar(u8, query, ' ');
        while (iter.next()) |word| {
            if (word.len > 2) { // 忽略太短的词
                const word_copy = try self.allocator.dupe(u8, word);
                try keywords.append(word_copy);
            }
        }
        
        return keywords.toOwnedSlice();
    }
    
    /// 构建答案
    fn buildAnswer(self: *KnowledgeBaseTool, query: []const u8, docs: []const u8) ![]const u8 {
        var answer = std.ArrayList(u8).init(self.allocator);
        errdefer answer.deinit();
        
        try answer.appendSlice("# 知识库查询结果\n\n");
        try answer.appendSlice("**查询**: ");
        try answer.appendSlice(query);
        try answer.appendSlice("\n\n");
        
        if (docs.len == 0) {
            try answer.appendSlice("未找到相关文档。\n\n");
            try answer.appendSlice("**建议**:\n");
            try answer.appendSlice("- 查看 `README.md` 了解项目概览\n");
            try answer.appendSlice("- 查看 `AGENTS.md` 了解开发规范\n");
            try answer.appendSlice("- 查看 `src/mcp/docs/INDEX.md` 了解 MCP 文档\n");
            try answer.appendSlice("- 查看 `knowlages/` 目录了解技术细节\n");
        } else {
            try answer.appendSlice("## 相关文档\n\n");
            try answer.appendSlice(docs);
        }
        
        return answer.toOwnedSlice();
    }
    
    /// 获取工具定义（MCP 协议）
    pub fn getDefinition(self: *const KnowledgeBaseTool) []const u8 {
        _ = self;
        return 
            \\{
            \\  "name": "knowledge_base_query",
            \\  "description": "查询 ZigCMS 项目知识库，包括文档、架构、最佳实践等",
            \\  "inputSchema": {
            \\    "type": "object",
            \\    "properties": {
            \\      "query": {
            \\        "type": "string",
            \\        "description": "查询问题，例如：'如何使用 ORM'、'内存管理规范'、'MCP 工具列表'"
            \\      }
            \\    },
            \\    "required": ["query"]
            \\  }
            \\}
        ;
    }
};
