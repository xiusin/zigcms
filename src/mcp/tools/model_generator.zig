/// 模型生成器工具
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const protocol = @import("../protocol/mod.zig");

/// 模型生成器
pub const ModelGeneratorTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) ModelGeneratorTool {
        return .{ .allocator = allocator, .security = security };
    }
    
    pub fn getInfo(self: *const ModelGeneratorTool) protocol.ToolInfo {
        return .{
            .name = "model_generator",
            .description = "Generate ZigCMS model with ORM integration and validation",
            .inputSchema = std.json.Value{ .object = std.json.ObjectMap.init(self.allocator) },
        };
    }
    
    pub fn execute(self: *ModelGeneratorTool, params: std.json.Value) !std.json.Value {
        const name = params.object.get("name") orelse return error.MissingName;
        const table = params.object.get("table") orelse name;
        const fields_value = params.object.get("fields") orelse return error.MissingFields;
        
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        const fields = try self.parseFields(arena_alloc, fields_value);
        const code = try self.generateModel(arena_alloc, name.string, table.string, fields);
        
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("code", std.json.Value{ .string = code });
        try result.put("path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "src/domain/entities/{s}.model.zig", .{name.string}) });
        
        return std.json.Value{ .object = result };
    }
    
    fn parseFields(self: *ModelGeneratorTool, allocator: std.mem.Allocator, fields_value: std.json.Value) ![]Field {
        _ = self;
        var fields = std.array_list.AlignedManaged(Field, null).init(allocator);
        
        if (fields_value != .array) return error.InvalidFieldsFormat;
        
        for (fields_value.array.items) |field_value| {
            if (field_value != .object) continue;
            
            const field_name = field_value.object.get("name") orelse continue;
            const field_type = field_value.object.get("type") orelse continue;
            const required = if (field_value.object.get("required")) |r| r.bool else true;
            const primary_key = if (field_value.object.get("primary_key")) |pk| pk.bool else false;
            
            try fields.append(.{
                .name = field_name.string,
                .type = field_type.string,
                .required = required,
                .primary_key = primary_key,
            });
        }
        
        return fields.items;
    }
    
    fn generateModel(self: *ModelGeneratorTool, allocator: std.mem.Allocator, name: []const u8, table: []const u8, fields: []const Field) ![]const u8 {
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头
        try writer.print("//! {s} 模型\n//! 表名: {s}\n\n", .{ name, table });
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.writeAll("const orm = @import(\"../../application/services/sql/orm.zig\");\n\n");
        
        // 结构体定义
        try writer.print("pub const {s} = struct {{\n", .{name});
        
        // 字段
        for (fields) |field| {
            const zig_type = try self.mapType(allocator, field.type);
            if (field.required) {
                try writer.print("    {s}: {s},\n", .{ field.name, zig_type });
            } else {
                try writer.print("    {s}: ?{s} = null,\n", .{ field.name, zig_type });
            }
        }
        
        try writer.writeAll("\n    // ORM 配置\n");
        try writer.print("    pub const table_name = \"{s}\";\n", .{table});
        
        // 主键
        for (fields) |field| {
            if (field.primary_key) {
                try writer.print("    pub const primary_key = \"{s}\";\n", .{field.name});
                break;
            }
        }
        
        try writer.writeAll("};\n");
        
        return code.items;
    }
    
    fn mapType(self: *ModelGeneratorTool, allocator: std.mem.Allocator, type_name: []const u8) ![]const u8 {
        _ = self;
        if (std.mem.eql(u8, type_name, "string")) return try allocator.dupe(u8, "[]const u8");
        if (std.mem.eql(u8, type_name, "int")) return try allocator.dupe(u8, "i32");
        if (std.mem.eql(u8, type_name, "bool")) return try allocator.dupe(u8, "bool");
        if (std.mem.eql(u8, type_name, "float")) return try allocator.dupe(u8, "f64");
        if (std.mem.eql(u8, type_name, "timestamp")) return try allocator.dupe(u8, "i64");
        return try allocator.dupe(u8, type_name);
    }
};

const Field = struct {
    name: []const u8,
    type: []const u8,
    required: bool,
    primary_key: bool,
};
