/// 代码生成工具
/// 用于 MCP 的代码生成功能
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const protocol = @import("../protocol/mod.zig");

/// CRUD 生成器工具
pub const CrudGeneratorTool = struct {
    allocator: std.mem.Allocator,
    security: McpConfig.SecurityConfig,
    
    pub fn init(allocator: std.mem.Allocator, security: McpConfig.SecurityConfig) CrudGeneratorTool {
        return .{
            .allocator = allocator,
            .security = security,
        };
    }
    
    /// 获取工具信息
    pub fn getInfo(self: *const CrudGeneratorTool) protocol.ToolInfo {
        return .{
            .name = "crud_generator",
            .description = "Generate complete CRUD module (Model + Controller + Routes) following ZigCMS architecture",
            .inputSchema = std.json.Value{
                .object = std.json.ObjectMap.init(self.allocator),
            },
        };
    }
    
    /// 执行生成
    pub fn execute(self: *CrudGeneratorTool, params: std.json.Value) !std.json.Value {
        const name = params.object.get("name") orelse return error.MissingName;
        const fields_value = params.object.get("fields") orelse return error.MissingFields;
        
        // 使用 Arena 分配器
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_alloc = arena.allocator();
        
        // 解析字段定义
        const fields = try self.parseFields(arena_alloc, fields_value);
        
        // 生成模型
        const model_code = try self.generateModel(arena_alloc, name.string, fields);
        
        // 生成控制器
        const controller_code = try self.generateController(arena_alloc, name.string, fields);
        
        // 生成路由注册代码
        const route_code = try self.generateRouteRegistration(arena_alloc, name.string);
        
        // 构建响应
        var result = std.json.ObjectMap.init(arena_alloc);
        try result.put("model", std.json.Value{ .string = model_code });
        try result.put("controller", std.json.Value{ .string = controller_code });
        try result.put("routes", std.json.Value{ .string = route_code });
        try result.put("model_path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "src/domain/entities/{s}.model.zig", .{name.string}) });
        try result.put("controller_path", std.json.Value{ .string = try std.fmt.allocPrint(arena_alloc, "src/api/controllers/{s}.controller.zig", .{name.string}) });
        
        return std.json.Value{ .object = result };
    }
    
    /// 解析字段定义
    fn parseFields(self: *CrudGeneratorTool, allocator: std.mem.Allocator, fields_value: std.json.Value) ![]Field {
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
    
    /// 生成模型代码
    fn generateModel(self: *CrudGeneratorTool, allocator: std.mem.Allocator, name: []const u8, fields: []const Field) ![]const u8 {
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头注释
        try writer.print("//! {s} 模型\n", .{name});
        try writer.writeAll("//! 自动生成 - 请勿手动修改\n\n");
        try writer.writeAll("const std = @import(\"std\");\n\n");
        
        // 结构体定义
        try writer.print("pub const {s} = struct {{\n", .{name});
        
        // 字段定义
        for (fields) |field| {
            const zig_type = try self.mapTypeToZig(allocator, field.type);
            if (field.required) {
                try writer.print("    {s}: {s},\n", .{ field.name, zig_type });
            } else {
                try writer.print("    {s}: ?{s} = null,\n", .{ field.name, zig_type });
            }
        }
        
        try writer.writeAll("};\n");
        
        return code.items;
    }
    
    /// 生成控制器代码
    fn generateController(self: *CrudGeneratorTool, allocator: std.mem.Allocator, name: []const u8, fields: []const Field) ![]const u8 {
        _ = fields;
        _ = self;
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头
        try writer.print("//! {s} 控制器\n", .{name});
        try writer.writeAll("//! 自动生成 - 请勿手动修改\n\n");
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.writeAll("const zap = @import(\"zap\");\n");
        try writer.print("const {s} = @import(\"../../domain/entities/{s}.model.zig\").{s};\n\n", .{ name, name, name });
        
        // 控制器结构
        try writer.print("pub const {s}Controller = struct {{\n", .{name});
        try writer.writeAll("    allocator: std.mem.Allocator,\n\n");
        
        // init 方法
        try writer.print("    pub fn init(allocator: std.mem.Allocator) {s}Controller {{\n", .{name});
        try writer.writeAll("        return .{ .allocator = allocator };\n");
        try writer.writeAll("    }\n\n");
        
        // list 方法
        try writer.writeAll("    pub fn list(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        _ = req;\n");
        try writer.writeAll("        // TODO: 实现列表查询\n");
        try writer.writeAll("    }\n\n");
        
        // get 方法
        try writer.writeAll("    pub fn get(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        _ = req;\n");
        try writer.writeAll("        // TODO: 实现详情查询\n");
        try writer.writeAll("    }\n\n");
        
        // create 方法
        try writer.writeAll("    pub fn create(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        _ = req;\n");
        try writer.writeAll("        // TODO: 实现创建\n");
        try writer.writeAll("    }\n\n");
        
        // update 方法
        try writer.writeAll("    pub fn update(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        _ = req;\n");
        try writer.writeAll("        // TODO: 实现更新\n");
        try writer.writeAll("    }\n\n");
        
        // delete 方法
        try writer.writeAll("    pub fn delete(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        _ = req;\n");
        try writer.writeAll("        // TODO: 实现删除\n");
        try writer.writeAll("    }\n");
        
        try writer.writeAll("};\n");
        
        return code.items;
    }
    
    /// 生成路由注册代码
    fn generateRouteRegistration(self: *CrudGeneratorTool, allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
        _ = self;
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        try writer.writeAll("// 在 bootstrap.zig 中添加以下代码：\n\n");
        try writer.print("// 1. 导入控制器\n", .{});
        try writer.print("const {s}Controller = @import(\"controllers/{s}.controller.zig\").{s}Controller;\n\n", .{ name, name, name });
        
        try writer.print("// 2. 注册到 DI 容器\n", .{});
        try writer.print("if (!self.container.isRegistered({s}Controller)) {{\n", .{name});
        try writer.print("    try self.container.registerSingleton({s}Controller, {s}Controller, struct {{\n", .{ name, name });
        try writer.writeAll("        fn factory(di: *DIContainer, allocator: std.mem.Allocator) anyerror!*Controller {\n");
        try writer.writeAll("            _ = di;\n");
        try writer.writeAll("            const ctrl = try allocator.create(Controller);\n");
        try writer.writeAll("            ctrl.* = Controller.init(allocator);\n");
        try writer.writeAll("            return ctrl;\n");
        try writer.writeAll("        }\n");
        try writer.writeAll("    }.factory, null);\n");
        try writer.writeAll("}\n\n");
        
        try writer.print("// 3. 注册路由\n", .{});
        try writer.print("const {s}_ctrl = try self.container.resolve({s}Controller);\n", .{ name, name });
        try writer.print("try self.app.route(\"/api/{s}\", {s}_ctrl, &{s}Controller.list);\n", .{ name, name, name });
        try writer.print("try self.app.route(\"/api/{s}/:id\", {s}_ctrl, &{s}Controller.get);\n", .{ name, name, name });
        try writer.print("try self.app.route(\"/api/{s}/create\", {s}_ctrl, &{s}Controller.create);\n", .{ name, name, name });
        try writer.print("try self.app.route(\"/api/{s}/update/:id\", {s}_ctrl, &{s}Controller.update);\n", .{ name, name, name });
        try writer.print("try self.app.route(\"/api/{s}/delete/:id\", {s}_ctrl, &{s}Controller.delete);\n", .{ name, name, name });
        
        return code.items;
    }
    
    /// 映射类型到 Zig 类型
    fn mapTypeToZig(self: *CrudGeneratorTool, allocator: std.mem.Allocator, type_name: []const u8) ![]const u8 {
        _ = self;
        if (std.mem.eql(u8, type_name, "string")) {
            return try allocator.dupe(u8, "[]const u8");
        } else if (std.mem.eql(u8, type_name, "int")) {
            return try allocator.dupe(u8, "i32");
        } else if (std.mem.eql(u8, type_name, "bool")) {
            return try allocator.dupe(u8, "bool");
        } else if (std.mem.eql(u8, type_name, "float")) {
            return try allocator.dupe(u8, "f64");
        } else if (std.mem.eql(u8, type_name, "timestamp")) {
            return try allocator.dupe(u8, "i64");
        } else {
            return try allocator.dupe(u8, type_name);
        }
    }
};

/// 字段定义
const Field = struct {
    name: []const u8,
    type: []const u8,
    required: bool,
};
