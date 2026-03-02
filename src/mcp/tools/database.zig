/// MCP 数据库操作工具
/// 通过系统 ORM 提供安全的数据库查询和操作能力
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const SecurityConfig = McpConfig.SecurityConfig;
const global = @import("../../core/primitives/global.zig");
const sql_mod = @import("../../application/services/sql/orm.zig");

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

    /// 获取系统数据库连接
    fn getDb() *sql_mod.Database {
        return global.get_db();
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

    /// 列出所有表（自动适配 MySQL/SQLite）
    fn listTables(self: *DatabaseTool) ![]const u8 {
        const db = getDb();

        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("# 数据库表列表\n\n");
        try result.appendSlice("| 表名 | 类型 |\n");
        try result.appendSlice("|------|------|\n");

        var rs = db.rawQuery("SHOW TABLES", .{}) catch |err| {
            const msg = try std.fmt.allocPrint(self.allocator, "查询失败: {s}\n", .{@errorName(err)});
            defer self.allocator.free(msg);
            try result.appendSlice(msg);
            return result.toOwnedSlice();
        };
        defer rs.deinit();

        var count: usize = 0;
        while (rs.next()) {
            const row = rs.getCurrentRow() orelse continue;
            if (row.values.len > 0) {
                const table_name = row.values[0] orelse "(null)";
                try result.appendSlice("| ");
                try result.appendSlice(table_name);
                try result.appendSlice(" | table |\n");
                count += 1;
            }
        }

        const summary = try std.fmt.allocPrint(self.allocator, "\n共 {d} 张表\n", .{count});
        defer self.allocator.free(summary);
        try result.appendSlice(summary);

        return result.toOwnedSlice();
    }

    /// 描述表结构（DESCRIBE table）
    fn describeTable(self: *DatabaseTool, table: []const u8) ![]const u8 {
        if (!isValidIdentifier(table)) return error.InvalidTableName;

        const db = getDb();

        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("# 表结构: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");

        try result.appendSlice("| 字段名 | 类型 | 可空 | 默认值 | 键 |\n");
        try result.appendSlice("|--------|------|------|--------|-----|\n");

        const query = try std.fmt.allocPrint(self.allocator, "DESCRIBE `{s}`", .{table});
        defer self.allocator.free(query);

        var rs = db.rawQuery(query, .{}) catch |err| {
            const msg = try std.fmt.allocPrint(self.allocator, "查询失败: {s}\n", .{@errorName(err)});
            defer self.allocator.free(msg);
            try result.appendSlice(msg);
            return result.toOwnedSlice();
        };
        defer rs.deinit();

        while (rs.next()) {
            const row = rs.getCurrentRow() orelse continue;
            const field = row.getString("Field") orelse "?";
            const col_type = row.getString("Type") orelse "?";
            const nullable = row.getString("Null") orelse "?";
            const default_val = row.getString("Default") orelse "NULL";
            const key = row.getString("Key") orelse "";

            try result.appendSlice("| ");
            try result.appendSlice(field);
            try result.appendSlice(" | ");
            try result.appendSlice(col_type);
            try result.appendSlice(" | ");
            try result.appendSlice(nullable);
            try result.appendSlice(" | ");
            try result.appendSlice(default_val);
            try result.appendSlice(" | ");
            try result.appendSlice(key);
            try result.appendSlice(" |\n");
        }

        return result.toOwnedSlice();
    }

    /// 统计记录数
    fn countRecords(self: *DatabaseTool, table: []const u8) ![]const u8 {
        if (!isValidIdentifier(table)) return error.InvalidTableName;

        const db = getDb();

        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("# 记录统计: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");

        const query = try std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) AS cnt FROM `{s}`", .{table});
        defer self.allocator.free(query);

        var rs = db.rawQuery(query, .{}) catch |err| {
            const msg = try std.fmt.allocPrint(self.allocator, "查询失败: {s}\n", .{@errorName(err)});
            defer self.allocator.free(msg);
            try result.appendSlice(msg);
            return result.toOwnedSlice();
        };
        defer rs.deinit();

        if (rs.next()) {
            const row = rs.getCurrentRow();
            if (row) |r| {
                const cnt = r.getString("cnt") orelse "0";
                try result.appendSlice("总记录数: ");
                try result.appendSlice(cnt);
                try result.appendSlice("\n");
            }
        } else {
            try result.appendSlice("总记录数: 0\n");
        }

        return result.toOwnedSlice();
    }

    /// 查询记录
    fn queryRecords(self: *DatabaseTool, table: []const u8, limit: usize) ![]const u8 {
        if (!isValidIdentifier(table)) return error.InvalidTableName;
        const safe_limit = if (limit > 100) @as(usize, 100) else if (limit == 0) @as(usize, 10) else limit;

        const db = getDb();

        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("# 查询结果: ");
        try result.appendSlice(table);
        try result.appendSlice("\n\n");

        const limit_str = try std.fmt.allocPrint(self.allocator, "**限制**: {d} 条\n\n", .{safe_limit});
        defer self.allocator.free(limit_str);
        try result.appendSlice(limit_str);

        const query = try std.fmt.allocPrint(self.allocator, "SELECT * FROM `{s}` LIMIT {d}", .{ table, safe_limit });
        defer self.allocator.free(query);

        var rs = db.rawQuery(query, .{}) catch |err| {
            const msg = try std.fmt.allocPrint(self.allocator, "查询失败: {s}\n", .{@errorName(err)});
            defer self.allocator.free(msg);
            try result.appendSlice(msg);
            return result.toOwnedSlice();
        };
        defer rs.deinit();

        // 输出表头
        if (rs.field_names.len > 0) {
            try result.appendSlice("| ");
            for (rs.field_names) |col_name| {
                try result.appendSlice(col_name);
                try result.appendSlice(" | ");
            }
            try result.appendSlice("\n|");
            for (rs.field_names) |_| {
                try result.appendSlice("---|");
            }
            try result.appendSlice("\n");
        }

        // 输出数据行
        var row_count: usize = 0;
        while (rs.next()) {
            const row = rs.getCurrentRow() orelse continue;
            try result.appendSlice("| ");
            for (row.values) |val| {
                const cell = val orelse "NULL";
                const display = if (cell.len > 50) cell[0..50] else cell;
                try result.appendSlice(display);
                if (cell.len > 50) try result.appendSlice("...");
                try result.appendSlice(" | ");
            }
            try result.appendSlice("\n");
            row_count += 1;
        }

        const summary = try std.fmt.allocPrint(self.allocator, "\n共 {d} 条记录\n", .{row_count});
        defer self.allocator.free(summary);
        try result.appendSlice(summary);

        return result.toOwnedSlice();
    }

    /// 执行 SQL（危险操作，仅允许 SELECT）
    fn executeSql(self: *DatabaseTool, raw_sql: []const u8) ![]const u8 {
        // 安全检查：禁止 DDL/DML 危险操作
        if (containsIgnoreCase(raw_sql, "DROP") or
            containsIgnoreCase(raw_sql, "DELETE") or
            containsIgnoreCase(raw_sql, "TRUNCATE") or
            containsIgnoreCase(raw_sql, "ALTER") or
            containsIgnoreCase(raw_sql, "INSERT") or
            containsIgnoreCase(raw_sql, "UPDATE"))
        {
            if (!self.security.allow_write_operations) {
                return error.DangerousSqlDetected;
            }
        }

        const db = getDb();

        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("# SQL 执行结果\n\n");
        try result.appendSlice("**SQL**: `");
        try result.appendSlice(raw_sql);
        try result.appendSlice("`\n\n");

        // 判断是否为 SELECT 类查询
        const is_select = containsIgnoreCase(raw_sql, "SELECT") or
            containsIgnoreCase(raw_sql, "SHOW") or
            containsIgnoreCase(raw_sql, "DESCRIBE") or
            containsIgnoreCase(raw_sql, "EXPLAIN");

        if (is_select) {
            var rs = db.rawQuery(raw_sql, .{}) catch |err| {
                const msg = try std.fmt.allocPrint(self.allocator, "查询失败: {s}\n", .{@errorName(err)});
                defer self.allocator.free(msg);
                try result.appendSlice(msg);
                return result.toOwnedSlice();
            };
            defer rs.deinit();

            // 输出表头
            if (rs.field_names.len > 0) {
                try result.appendSlice("| ");
                for (rs.field_names) |col| {
                    try result.appendSlice(col);
                    try result.appendSlice(" | ");
                }
                try result.appendSlice("\n|");
                for (rs.field_names) |_| {
                    try result.appendSlice("---|");
                }
                try result.appendSlice("\n");
            }

            var row_count: usize = 0;
            while (rs.next()) {
                const row = rs.getCurrentRow() orelse continue;
                try result.appendSlice("| ");
                for (row.values) |val| {
                    const cell = val orelse "NULL";
                    const display = if (cell.len > 80) cell[0..80] else cell;
                    try result.appendSlice(display);
                    if (cell.len > 80) try result.appendSlice("...");
                    try result.appendSlice(" | ");
                }
                try result.appendSlice("\n");
                row_count += 1;
            }

            const summary = try std.fmt.allocPrint(self.allocator, "\n共 {d} 条记录\n", .{row_count});
            defer self.allocator.free(summary);
            try result.appendSlice(summary);
        } else {
            const affected = db.exec(raw_sql, .{}) catch |err| {
                const msg = try std.fmt.allocPrint(self.allocator, "执行失败: {s}\n", .{@errorName(err)});
                defer self.allocator.free(msg);
                try result.appendSlice(msg);
                return result.toOwnedSlice();
            };

            const msg = try std.fmt.allocPrint(self.allocator, "执行成功，影响 {d} 行\n", .{affected});
            defer self.allocator.free(msg);
            try result.appendSlice(msg);
        }

        return result.toOwnedSlice();
    }

    /// 表名合法性校验（防止 SQL 注入）
    fn isValidIdentifier(name: []const u8) bool {
        if (name.len == 0 or name.len > 64) return false;
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
        }
        return true;
    }

    /// 大小写不敏感子串匹配
    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;
        var i: usize = 0;
        while (i + needle.len <= haystack.len) : (i += 1) {
            var matched = true;
            for (needle, 0..) |nc, j| {
                const hc = haystack[i + j];
                if (std.ascii.toLower(hc) != std.ascii.toLower(nc)) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
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
