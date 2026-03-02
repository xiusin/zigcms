/// 数据库迁移生成器
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const protocol = @import("../protocol/mod.zig");

/// 迁移生成器
pub const MigrationGeneratorTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) MigrationGeneratorTool {
        return .{ .allocator = allocator, .security = security };
    }
    
    pub fn getInfo(self: *const MigrationGeneratorTool) protocol.ToolInfo {
        return .{
            .name = "migration_generator",
            .description = "Generate database migration SQL for creating tables",
            .inputSchema = std.json.Value{ .object = std.json.ObjectMap.init(self.allocator) },
        };
    }
    
    pub fn execute(self: *MigrationGeneratorTool, params: std.json.Value) !std.json.Value {
        const table = params.object.get("table") orelse return error.MissingTable;
        const fields_value = params.object.get("fields") orelse return error.MissingFields;
        
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        const fields = try self.parseFields(arena_alloc, fields_value);
        const up_sql = try self.generateUpSQL(arena_alloc, table.string, fields);
        const down_sql = try self.generateDownSQL(arena_alloc, table.string);
        
        // 生成迁移文件名（时间戳）
        const timestamp = std.time.timestamp();
        const filename = try std.fmt.allocPrint(arena_alloc, "{d}_create_{s}_table.sql", .{ timestamp, table.string });
        
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("up", std.json.Value{ .string = up_sql });
        try result.put("down", std.json.Value{ .string = down_sql });
        try result.put("filename", std.json.Value{ .string = filename });
        try result.put("path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "migrations/{s}", .{filename}) });
        
        return std.json.Value{ .object = result };
    }
    
    fn parseFields(self: *MigrationGeneratorTool, allocator: std.mem.Allocator, fields_value: std.json.Value) ![]Field {
        _ = self;
        var fields = std.array_list.AlignedManaged(Field, null).init(allocator);
        
        if (fields_value != .array) return error.InvalidFieldsFormat;
        
        for (fields_value.array.items) |field_value| {
            if (field_value != .object) continue;
            
            const field_name = field_value.object.get("name") orelse continue;
            const field_type = field_value.object.get("type") orelse continue;
            const required = if (field_value.object.get("required")) |r| r.bool else true;
            const primary_key = if (field_value.object.get("primary_key")) |pk| pk.bool else false;
            const auto_increment = if (field_value.object.get("auto_increment")) |ai| ai.bool else false;
            
            try fields.append(.{
                .name = field_name.string,
                .type = field_type.string,
                .required = required,
                .primary_key = primary_key,
                .auto_increment = auto_increment,
            });
        }
        
        return fields.items;
    }
    
    fn generateUpSQL(self: *MigrationGeneratorTool, allocator: std.mem.Allocator, table: []const u8, fields: []const Field) ![]const u8 {
        var sql = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = sql.writer();
        
        try writer.print("-- 创建 {s} 表\n", .{table});
        try writer.print("CREATE TABLE IF NOT EXISTS {s} (\n", .{table});
        
        // 字段定义
        for (fields, 0..) |field, i| {
            const sql_type = try self.mapTypeToSQL(allocator, field.type);
            try writer.print("    {s} {s}", .{ field.name, sql_type });
            
            if (field.auto_increment) {
                try writer.writeAll(" AUTO_INCREMENT");
            }
            
            if (field.primary_key) {
                try writer.writeAll(" PRIMARY KEY");
            }
            
            if (field.required and !field.primary_key) {
                try writer.writeAll(" NOT NULL");
            }
            
            if (i < fields.len - 1) {
                try writer.writeAll(",\n");
            } else {
                try writer.writeAll("\n");
            }
        }
        
        try writer.writeAll(");\n");
        
        return sql.items;
    }
    
    fn generateDownSQL(self: *MigrationGeneratorTool, allocator: std.mem.Allocator, table: []const u8) ![]const u8 {
        _ = self;
        return try std.fmt.allocPrint(allocator, "-- 删除 {s} 表\nDROP TABLE IF EXISTS {s};\n", .{ table, table });
    }
    
    fn mapTypeToSQL(self: *MigrationGeneratorTool, allocator: std.mem.Allocator, type_name: []const u8) ![]const u8 {
        _ = self;
        if (std.mem.eql(u8, type_name, "string")) return try allocator.dupe(u8, "VARCHAR(255)");
        if (std.mem.eql(u8, type_name, "text")) return try allocator.dupe(u8, "TEXT");
        if (std.mem.eql(u8, type_name, "int")) return try allocator.dupe(u8, "INT");
        if (std.mem.eql(u8, type_name, "bigint")) return try allocator.dupe(u8, "BIGINT");
        if (std.mem.eql(u8, type_name, "bool")) return try allocator.dupe(u8, "BOOLEAN");
        if (std.mem.eql(u8, type_name, "float")) return try allocator.dupe(u8, "DOUBLE");
        if (std.mem.eql(u8, type_name, "timestamp")) return try allocator.dupe(u8, "TIMESTAMP");
        if (std.mem.eql(u8, type_name, "datetime")) return try allocator.dupe(u8, "DATETIME");
        return try allocator.dupe(u8, type_name);
    }
};

const Field = struct {
    name: []const u8,
    type: []const u8,
    required: bool,
    primary_key: bool,
    auto_increment: bool,
};
