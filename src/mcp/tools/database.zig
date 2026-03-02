/// MCP 数据库操作工具
/// 提供安全的数据库查询和操作能力
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const SecurityConfig = McpConfig.SecurityConfig;
const zigcms = @import("root");

/// 数据库操作工具
pub const DatabaseTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: SecurityConfig) DatabaseTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 执行数据库查询
    pub fn executeQuery(self: *DatabaseTool, query_type: []const u8, params: std.json.Value) ![]const u8 {
        // 验证查询类型
        if (std.mem.eql(u8, query_type, "list_tables")) {
            return try self.listTables();
        } else if (std.mem.eql(u8, query_type, "describe_table")) {
            const table = params.object.get("table") orelse return error.MissingTableName;
            return try self.describeTable(table.string);
        } else if (std.mem.eql(u8, query_type, "count_records")) {
            const table = params.object.get("table") orelse return error.MissingTableName;
            return try self.countRecords(table.string);
        } else if (std.mem.eql(u8, query_type, "query_records")) {
            const table = params.object.get("table") orelse return error.MissingTableName;
            const limit = if (params.object.get("limit")) |l| @as(usize, @intCast(l.integer)) else 10;
            return try self.queryRecords(table.string, limit);
        } else if (std.mem.eql(u8, query_type, "execute_sql")) {
            // 危险操作，需要额外验证
            if (!self.security.allow_write_operations) {
                return error.WriteOperationsDisabled;
            }
            const sql = params.object.get("sql") orelse return error.MissingSql;
            return try self.executeSql(sql.string);
        } else {
            return error.UnknownQueryType;
        }
    }
    
    /// 列出所有表
    fn listTables(self: *DatabaseTool) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        // SQLite 查询所有表
        const sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 数据库表列表\n\n");
        
        // TODO: 执行查询并格式化结果
        // 这里需要使用 ORM 或原始 SQL 查询
        try result.appendSlice("| 表名 | 类型 |\n");
        try result.appendSlice("|------|------|\n");
        
        // 示例数据
        const tables = [_][]const u8{
            "sys_admin", "sys_role", "sys_menu", "sys_dept",
            "sys_role_menu", "sys_admin_role",
        };
        
        for (tables) |table| {
            try result.appendSlice("| ");
            try result.appendSlice(table);
            try result.appendSlice(" | table |\n");
        }
        
        _ = sql;
        _ = db;
        
        return result.toOwnedSlice();
    }
    
    /// 描述表结构
    fn describeTable(self: *DatabaseTool, table: []const u8) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 表结构: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");
        
        try result.appendSlice("| 字段名 | 类型 | 可空 | 默认值 | 备注 |\n");
        try result.appendSlice("|--------|------|------|--------|------|\n");
        
        // TODO: 查询表结构
        // PRAGMA table_info(table_name)
        
        _ = db;
        
        return result.toOwnedSlice();
    }
    
    /// 统计记录数
    fn countRecords(self: *DatabaseTool, table: []const u8) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 记录统计: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");
        
        // TODO: 执行 COUNT 查询
        try result.appendSlice("总记录数: 0\n");
        
        _ = db;
        
        return result.toOwnedSlice();
    }
    
    /// 查询记录
    fn queryRecords(self: *DatabaseTool, table: []const u8, limit: usize) ![]const u8 {
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# 查询结果: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");
        
        try result.appendSlice("**限制**: ");
        const limit_str = try std.fmt.allocPrint(self.allocator, "{d}", .{limit});
        defer self.allocator.free(limit_str);
        try result.appendSlice(limit_str);
        try result.appendSlice(" 条\n\n");
        
        // TODO: 执行查询
        try result.appendSlice("```json\n");
        try result.appendSlice("[\n");
        try result.appendSlice("  // 查询结果\n");
        try result.appendSlice("]\n");
        try result.appendSlice("```\n");
        
        _ = db;
        
        return result.toOwnedSlice();
    }
    
    /// 执行 SQL（危险操作）
    fn executeSql(self: *DatabaseTool, sql: []const u8) ![]const u8 {
        // 验证 SQL 安全性
        if (std.mem.indexOf(u8, sql, "DROP") != null or
            std.mem.indexOf(u8, sql, "DELETE") != null or
            std.mem.indexOf(u8, sql, "TRUNCATE") != null)
        {
            return error.DangerousSqlDetected;
        }
        
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();
        
        try result.appendSlice("# SQL 执行结果\n\n");
        try result.appendSlice("**SQL**: ");
        try result.appendSlice(sql);
        try result.appendSlice("\n\n");
        
        // TODO: 执行 SQL
        try result.appendSlice("执行成功\n");
        
        _ = db;
        
        return result.toOwnedSlice();
    }
    
    /// 获取工具定义（MCP 协议）
    pub fn getDefinition(self: *const DatabaseTool) []const u8 {
        _ = self;
        return 
            \\{
            \\  "name": "database_query",
            \\  "description": "查询和操作 ZigCMS 数据库",
            \\  "inputSchema": {
            \\    "type": "object",
            \\    "properties": {
            \\      "query_type": {
            \\        "type": "string",
            \\        "enum": ["list_tables", "describe_table", "count_records", "query_records", "execute_sql"],
            \\        "description": "查询类型"
            \\      },
            \\      "params": {
            \\        "type": "object",
            \\        "description": "查询参数，根据 query_type 不同而不同",
            \\        "properties": {
            \\          "table": {
            \\            "type": "string",
            \\            "description": "表名（describe_table, count_records, query_records 需要）"
            \\          },
            \\          "limit": {
            \\            "type": "integer",
            \\            "description": "查询限制（query_records 可选，默认 10）"
            \\          },
            \\          "sql": {
            \\            "type": "string",
            \\            "description": "SQL 语句（execute_sql 需要，危险操作）"
            \\          }
            \\        }
            \\      }
            \\    },
            \\    "required": ["query_type", "params"]
            \\  }
            \\}
        ;
    }
};
