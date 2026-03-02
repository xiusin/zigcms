/// MCP 缓存操作工具
/// 提供缓存查询、设置、删除等操作
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const SecurityConfig = McpConfig.SecurityConfig;
const zigcms = @import("root");

/// 缓存操作工具
pub const CacheTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: SecurityConfig) CacheTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 执行缓存操作
    pub fn execute(self: *CacheTool, operation: []const u8, params: std.json.Value) ![]const u8 {
        if (std.mem.eql(u8, operation, "get")) {
            const key = params.object.get("key") orelse return error.MissingKey;
            return try self.get(key.string);
        } else if (std.mem.eql(u8, operation, "set")) {
            const key = params.object.get("key") orelse return error.MissingKey;
            const value = params.object.get("value") orelse return error.MissingValue;
            const ttl = if (params.object.get("ttl")) |t| @as(u32, @intCast(t.integer)) else 300;
            return try self.set(key.string, value.string, ttl);
        } else if (std.mem.eql(u8, operation, "delete")) {
            const key = params.object.get("key") orelse return error.MissingKey;
            return try self.delete(key.string);
        } else if (std.mem.eql(u8, operation, "exists")) {
            const key = params.object.get("key") orelse return error.MissingKey;
            return try self.exists(key.string);
        } else if (std.mem.eql(u8, operation, "keys")) {
            const pattern = if (params.object.get("pattern")) |p| p.string else "*";
            return try self.keys(pattern);
        } else if (std.mem.eql(u8, operation, "clear")) {
            const pattern = if (params.object.get("pattern")) |p| p.string else null;
            return try self.clear(pattern);
        } else if (std.mem.eql(u8, operation, "stats")) {
            return try self.stats();
        } else {
            return error.UnknownOperation;
        }
    }
    
    /// 获取缓存值
    fn get(self: *CacheTool, key: []const u8) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const cache = service_mgr.getCache();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存查询结果\n\n");
        try result.appendSlice("**Key**: ");
        try result.appendSlice(key);
        try result.appendSlice("\n\n");
        
        if (cache.get(key, self.allocator)) |value| {
            defer self.allocator.free(value);
            try result.appendSlice("**Value**:\n```\n");
            try result.appendSlice(value);
            try result.appendSlice("\n```\n");
        } else |_| {
            try result.appendSlice("**状态**: 未找到\n");
        }
        
        return result.toOwnedSlice();
    }
    
    /// 设置缓存值
    fn set(self: *CacheTool, key: []const u8, value: []const u8, ttl: u32) ![]const u8 {
        if (!self.security.allow_write_operations) {
            return error.WriteOperationsDisabled;
        }
        
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const cache = service_mgr.getCache();
        
        try cache.set(key, value, ttl);
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存设置成功\n\n");
        try result.appendSlice("**Key**: ");
        try result.appendSlice(key);
        try result.appendSlice("\n");
        try result.appendSlice("**TTL**: ");
        const ttl_str = try std.fmt.allocPrint(self.allocator, "{d}s", .{ttl});
        defer self.allocator.free(ttl_str);
        try result.appendSlice(ttl_str);
        try result.appendSlice("\n");
        
        return result.toOwnedSlice();
    }
    
    /// 删除缓存
    fn delete(self: *CacheTool, key: []const u8) ![]const u8 {
        if (!self.security.allow_write_operations) {
            return error.WriteOperationsDisabled;
        }
        
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const cache = service_mgr.getCache();
        
        try cache.del(key);
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存删除成功\n\n");
        try result.appendSlice("**Key**: ");
        try result.appendSlice(key);
        try result.appendSlice("\n");
        
        return result.toOwnedSlice();
    }
    
    /// 检查缓存是否存在
    fn exists(self: *CacheTool, key: []const u8) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const cache = service_mgr.getCache();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存存在性检查\n\n");
        try result.appendSlice("**Key**: ");
        try result.appendSlice(key);
        try result.appendSlice("\n");
        
        if (cache.get(key, self.allocator)) |value| {
            defer self.allocator.free(value);
            try result.appendSlice("**状态**: ✅ 存在\n");
        } else |_| {
            try result.appendSlice("**状态**: ❌ 不存在\n");
        }
        
        return result.toOwnedSlice();
    }
    
    /// 列出缓存键
    fn keys(self: *CacheTool, pattern: []const u8) ![]const u8 {
        _ = pattern;
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存键列表\n\n");
        try result.appendSlice("**提示**: 当前实现不支持列出所有键\n");
        try result.appendSlice("**建议**: 使用统一的键前缀，如 `user:*`、`post:*`\n");
        
        return result.toOwnedSlice();
    }
    
    /// 清空缓存
    fn clear(self: *CacheTool, pattern: ?[]const u8) ![]const u8 {
        if (!self.security.allow_write_operations) {
            return error.WriteOperationsDisabled;
        }
        
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const cache = service_mgr.getCache();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        if (pattern) |p| {
            try cache.delByPrefix(p);
            try result.appendSlice("# 缓存清空成功\n\n");
            try result.appendSlice("**模式**: ");
            try result.appendSlice(p);
            try result.appendSlice("\n");
        } else {
            try result.appendSlice("# 清空所有缓存\n\n");
            try result.appendSlice("**警告**: 此操作将清空所有缓存\n");
            try result.appendSlice("**建议**: 使用 pattern 参数指定前缀\n");
        }
        
        return result.toOwnedSlice();
    }
    
    /// 缓存统计
    fn stats(self: *CacheTool) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const config = service_mgr.getConfig();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 缓存统计\n\n");
        try result.appendSlice("| 配置项 | 值 |\n");
        try result.appendSlice("|--------|----|\n");
        
        try result.appendSlice("| 缓存状态 | ");
        try result.appendSlice(if (config.app.enable_cache) "✅ 已启用" else "❌ 已禁用");
        try result.appendSlice(" |\n");
        
        try result.appendSlice("| 默认 TTL | ");
        const ttl_str = try std.fmt.allocPrint(self.allocator, "{d}s", .{config.app.cache_ttl_seconds});
        defer self.allocator.free(ttl_str);
        try result.appendSlice(ttl_str);
        try result.appendSlice(" |\n");
        
        try result.appendSlice("| 缓存类型 | ");
        try result.appendSlice(config.cache.driver);
        try result.appendSlice(" |\n");
        
        if (std.mem.eql(u8, config.cache.driver, "redis")) {
            try result.appendSlice("| Redis 地址 | ");
            try result.appendSlice(config.cache.redis_host);
            try result.appendSlice(":");
            const port_str = try std.fmt.allocPrint(self.allocator, "{d}", .{config.cache.redis_port});
            defer self.allocator.free(port_str);
            try result.appendSlice(port_str);
            try result.appendSlice(" |\n");
        }
        
        return result.toOwnedSlice();
    }
    
    /// 获取工具定义（MCP 协议）
    pub fn getDefinition(self: *const CacheTool) []const u8 {
        _ = self;
        return 
            \\{
            \\  "name": "cache_operation",
            \\  "description": "操作 ZigCMS 缓存系统",
            \\  "inputSchema": {
            \\    "type": "object",
            \\    "properties": {
            \\      "operation": {
            \\        "type": "string",
            \\        "enum": ["get", "set", "delete", "exists", "keys", "clear", "stats"],
            \\        "description": "操作类型"
            \\      },
            \\      "params": {
            \\        "type": "object",
            \\        "description": "操作参数",
            \\        "properties": {
            \\          "key": {
            \\            "type": "string",
            \\            "description": "缓存键"
            \\          },
            \\          "value": {
            \\            "type": "string",
            \\            "description": "缓存值（set 需要）"
            \\          },
            \\          "ttl": {
            \\            "type": "integer",
            \\            "description": "过期时间（秒，默认 300）"
            \\          },
            \\          "pattern": {
            \\            "type": "string",
            \\            "description": "键模式（keys/clear 可选）"
            \\          }
            \\        }
            \\      }
            \\    },
            \\    "required": ["operation", "params"]
            \\  }
            \\}
        ;
    }
};
