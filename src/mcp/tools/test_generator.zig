/// 测试代码生成器工具
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const protocol = @import("../protocol/mod.zig");

/// 测试生成器
pub const TestGeneratorTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) TestGeneratorTool {
        return .{ .allocator = allocator, .security = security };
    }
    
    pub fn getInfo(self: *const TestGeneratorTool) protocol.ToolInfo {
        return .{
            .name = "test_generator",
            .description = "Generate unit tests and integration tests for CRUD modules",
            .inputSchema = std.json.Value{ .object = std.json.ObjectMap.init(self.allocator) },
        };
    }
    
    pub fn execute(self: *TestGeneratorTool, params: std.json.Value) !std.json.Value {
        const name = params.object.get("name") orelse return error.MissingName;
        const fields_value = params.object.get("fields") orelse return error.MissingFields;
        
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        const fields = try self.parseFields(arena_alloc, fields_value);
        
        // 生成单元测试
        const unit_test = try self.generateUnitTest(arena_alloc, name.string, fields);
        
        // 生成集成测试
        const integration_test = try self.generateIntegrationTest(arena_alloc, name.string, fields);
        
        // 生成 Mock 数据
        const mock_data = try self.generateMockData(arena_alloc, name.string, fields);
        
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("unit_test", std.json.Value{ .string = unit_test });
        try result.put("integration_test", std.json.Value{ .string = integration_test });
        try result.put("mock_data", std.json.Value{ .string = mock_data });
        try result.put("unit_test_path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "test/unit/{s}_test.zig", .{name.string}) });
        try result.put("integration_test_path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "test/integration/{s}_api_test.zig", .{name.string}) });
        
        return std.json.Value{ .object = result };
    }
    
    fn parseFields(self: *TestGeneratorTool, allocator: std.mem.Allocator, fields_value: std.json.Value) ![]Field {
        _ = self;
        var fields = std.array_list.AlignedManaged(Field, null).init(allocator);
        
        if (fields_value != .array) return error.InvalidFieldsFormat;
        
        for (fields_value.array.items) |field_value| {
            if (field_value != .object) continue;
            
            const field_name = field_value.object.get("name") orelse continue;
            const field_type = field_value.object.get("type") orelse continue;
            const required = if (field_value.object.get("required")) |r| r.bool else true;
            
            try fields.append(.{
                .name = field_name.string,
                .type = field_type.string,
                .required = required,
            });
        }
        
        return fields.items;
    }
    
    /// 生成单元测试
    fn generateUnitTest(self: *TestGeneratorTool, allocator: std.mem.Allocator, name: []const u8, fields: []const Field) ![]const u8 {
        _ = self;
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头
        try writer.print("//! {s} 单元测试\n", .{name});
        try writer.writeAll("//! 自动生成 - 测试模型的基本功能\n\n");
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.writeAll("const testing = std.testing;\n");
        try writer.print("const {s} = @import(\"../../src/domain/entities/{s}.model.zig\").{s};\n\n", .{ name, name, name });
        
        // 测试：创建实例
        try writer.print("test \"{s} - create instance\" {{\n", .{name});
        try writer.print("    const item = {s}{{\n", .{name});
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue;
            
            if (field.required) {
                if (std.mem.eql(u8, field.type, "string")) {
                    try writer.print("        .{s} = \"test_{s}\",\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "int")) {
                    try writer.print("        .{s} = 1,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "bool")) {
                    try writer.print("        .{s} = true,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "float")) {
                    try writer.print("        .{s} = 1.0,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "timestamp")) {
                    try writer.print("        .{s} = 1709280000,\n", .{field.name});
                }
            }
        }
        try writer.writeAll("    };\n\n");
        
        // 验证字段
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue;
            if (!field.required) continue;
            
            if (std.mem.eql(u8, field.type, "string")) {
                try writer.print("    try testing.expectEqualStrings(\"test_{s}\", item.{s});\n", .{ field.name, field.name });
            } else {
                try writer.print("    try testing.expect(item.{s} != null);\n", .{field.name});
            }
        }
        try writer.writeAll("}\n\n");
        
        // 测试：字段验证
        try writer.print("test \"{s} - field validation\" {{\n", .{name});
        try writer.writeAll("    // 测试必填字段\n");
        for (fields) |field| {
            if (field.required and std.mem.eql(u8, field.type, "string")) {
                try writer.print("    const empty_{s} = \"\";\n", .{field.name});
                try writer.print("    try testing.expect(empty_{s}.len == 0);\n", .{field.name});
            }
        }
        try writer.writeAll("}\n\n");
        
        return code.items;
    }
    
    /// 生成集成测试
    fn generateIntegrationTest(self: *TestGeneratorTool, allocator: std.mem.Allocator, name: []const u8, fields: []const Field) ![]const u8 {
        _ = self;
        _ = fields;
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头
        try writer.print("//! {s} API 集成测试\n", .{name});
        try writer.writeAll("//! 自动生成 - 测试 CRUD API 接口\n\n");
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.writeAll("const testing = std.testing;\n\n");
        
        // 测试：创建
        try writer.print("test \"{s} API - create\" {{\n", .{name});
        try writer.writeAll("    // TODO: 实现 HTTP 请求测试\n");
        try writer.writeAll("    // 1. 发送 POST 请求到 /api/{s}/create\n");
        try writer.writeAll("    // 2. 验证响应状态码为 200\n");
        try writer.writeAll("    // 3. 验证返回的数据包含 id\n");
        try writer.writeAll("}\n\n");
        
        // 测试：列表查询
        try writer.print("test \"{s} API - list\" {{\n", .{name});
        try writer.writeAll("    // TODO: 实现 HTTP 请求测试\n");
        try writer.writeAll("    // 1. 发送 GET 请求到 /api/{s}?page=1&page_size=20\n");
        try writer.writeAll("    // 2. 验证响应状态码为 200\n");
        try writer.writeAll("    // 3. 验证返回的数据包含 items 和 total\n");
        try writer.writeAll("}\n\n");
        
        // 测试：获取详情
        try writer.print("test \"{s} API - get\" {{\n", .{name});
        try writer.writeAll("    // TODO: 实现 HTTP 请求测试\n");
        try writer.writeAll("    // 1. 发送 GET 请求到 /api/{s}/1\n");
        try writer.writeAll("    // 2. 验证响应状态码为 200\n");
        try writer.writeAll("    // 3. 验证返回的数据包含正确的字段\n");
        try writer.writeAll("}\n\n");
        
        // 测试：更新
        try writer.print("test \"{s} API - update\" {{\n", .{name});
        try writer.writeAll("    // TODO: 实现 HTTP 请求测试\n");
        try writer.writeAll("    // 1. 发送 POST 请求到 /api/{s}/update/1\n");
        try writer.writeAll("    // 2. 验证响应状态码为 200\n");
        try writer.writeAll("    // 3. 验证返回的消息为 Updated\n");
        try writer.writeAll("}\n\n");
        
        // 测试：删除
        try writer.print("test \"{s} API - delete\" {{\n", .{name});
        try writer.writeAll("    // TODO: 实现 HTTP 请求测试\n");
        try writer.writeAll("    // 1. 发送 POST 请求到 /api/{s}/delete/1\n");
        try writer.writeAll("    // 2. 验证响应状态码为 200\n");
        try writer.writeAll("    // 3. 验证返回的消息为 Deleted\n");
        try writer.writeAll("}\n\n");
        
        return code.items;
    }
    
    /// 生成 Mock 数据
    fn generateMockData(self: *TestGeneratorTool, allocator: std.mem.Allocator, name: []const u8, fields: []const Field) ![]const u8 {
        _ = self;
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头
        try writer.print("//! {s} Mock 数据\n", .{name});
        try writer.writeAll("//! 自动生成 - 用于测试的模拟数据\n\n");
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.print("const {s} = @import(\"../../src/domain/entities/{s}.model.zig\").{s};\n\n", .{ name, name, name });
        
        // Mock 数据函数
        try writer.print("pub fn mock{s}(allocator: std.mem.Allocator) !{s} {{\n", .{ name, name });
        try writer.writeAll("    _ = allocator;\n");
        try writer.print("    return {s}{{\n", .{name});
        try writer.writeAll("        .id = 1,\n");
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue;
            
            if (field.required) {
                if (std.mem.eql(u8, field.type, "string")) {
                    try writer.print("        .{s} = \"mock_{s}\",\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "int")) {
                    try writer.print("        .{s} = 1,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "bool")) {
                    try writer.print("        .{s} = true,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "float")) {
                    try writer.print("        .{s} = 1.0,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "timestamp")) {
                    try writer.print("        .{s} = 1709280000,\n", .{field.name});
                }
            } else {
                try writer.print("        .{s} = null,\n", .{field.name});
            }
        }
        try writer.writeAll("    };\n");
        try writer.writeAll("}\n\n");
        
        // Mock 数据列表函数
        try writer.print("pub fn mock{s}List(allocator: std.mem.Allocator, count: usize) ![]const {s} {{\n", .{ name, name });
        try writer.print("    var list = try allocator.alloc({s}, count);\n", .{name});
        try writer.writeAll("    for (list, 0..) |*item, i| {\n");
        try writer.writeAll("        item.* = .{\n");
        try writer.writeAll("            .id = @intCast(i + 1),\n");
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue;
            
            if (field.required) {
                if (std.mem.eql(u8, field.type, "string")) {
                    try writer.print("            .{s} = try std.fmt.allocPrint(allocator, \"mock_{s}_{{d}}\", .{{i}}),\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "int")) {
                    try writer.print("            .{s} = @intCast(i + 1),\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "bool")) {
                    try writer.print("            .{s} = i % 2 == 0,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "float")) {
                    try writer.print("            .{s} = @as(f64, @floatFromInt(i)) + 1.0,\n", .{field.name});
                } else if (std.mem.eql(u8, field.type, "timestamp")) {
                    try writer.print("            .{s} = 1709280000 + @as(i64, @intCast(i)),\n", .{field.name});
                }
            } else {
                try writer.print("            .{s} = null,\n", .{field.name});
            }
        }
        try writer.writeAll("        };\n");
        try writer.writeAll("    }\n");
        try writer.writeAll("    return list;\n");
        try writer.writeAll("}\n\n");
        
        return code.items;
    }
};

const Field = struct {
    name: []const u8,
    type: []const u8,
    required: bool,
};
