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
            
            // 解析验证规则
            const min_length = if (field_value.object.get("min_length")) |v| 
                if (v == .integer) @as(?usize, @intCast(v.integer)) else null 
                else null;
            const max_length = if (field_value.object.get("max_length")) |v| 
                if (v == .integer) @as(?usize, @intCast(v.integer)) else null 
                else null;
            const min_value = if (field_value.object.get("min_value")) |v| 
                if (v == .integer) @as(?i64, v.integer) else null 
                else null;
            const max_value = if (field_value.object.get("max_value")) |v| 
                if (v == .integer) @as(?i64, v.integer) else null 
                else null;
            const pattern = if (field_value.object.get("pattern")) |v| 
                if (v == .string) v.string else null 
                else null;
            
            try fields.append(.{
                .name = field_name.string,
                .type = field_type.string,
                .required = required,
                .min_length = min_length,
                .max_length = max_length,
                .min_value = min_value,
                .max_value = max_value,
                .pattern = pattern,
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
        var code = std.array_list.AlignedManaged(u8, null).init(allocator);
        const writer = code.writer();
        
        // 文件头注释
        try writer.print("//! {s} 控制器\n", .{name});
        try writer.writeAll("//! 自动生成 - 包含完整 ORM 集成和字段验证\n");
        try writer.writeAll("//!\n");
        try writer.writeAll("//! ## 功能\n");
        try writer.writeAll("//! - list: 分页查询列表\n");
        try writer.writeAll("//! - get: 获取单条记录\n");
        try writer.writeAll("//! - create: 创建记录（带验证）\n");
        try writer.writeAll("//! - update: 更新记录（部分更新）\n");
        try writer.writeAll("//! - delete: 删除记录\n");
        try writer.writeAll("//!\n");
        try writer.writeAll("//! ## 内存安全\n");
        try writer.writeAll("//! - 所有 ORM 查询结果都使用 defer 自动释放\n");
        try writer.writeAll("//! - JSON 解析使用 Arena 分配器\n");
        try writer.writeAll("//! - 错误处理完善，提前返回避免资源泄漏\n\n");
        try writer.writeAll("const std = @import(\"std\");\n");
        try writer.writeAll("const zap = @import(\"zap\");\n");
        try writer.writeAll("const zigcms = @import(\"../../../root.zig\");\n");
        try writer.print("const {s} = @import(\"../../domain/entities/{s}.model.zig\").{s};\n", .{ name, name, name });
        try writer.writeAll("const base = @import(\"../base.zig\");\n\n");
        
        // ORM 类型别名
        try writer.print("const Orm{s} = zigcms.application.services.sql.orm.ORM({s});\n\n", .{ name, name });
        
        // 控制器结构
        try writer.print("pub const {s}Controller = struct {{\n", .{name});
        try writer.writeAll("    allocator: std.mem.Allocator,\n\n");
        
        // init 方法
        try writer.print("    pub fn init(allocator: std.mem.Allocator) {s}Controller {{\n", .{name});
        try writer.writeAll("        return .{ .allocator = allocator };\n");
        try writer.writeAll("    }\n\n");
        
        // list 方法（带分页）
        try writer.writeAll("    /// 列表查询（带分页）\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 参数\n");
        try writer.writeAll("    /// - page: 页码（默认 1）\n");
        try writer.writeAll("    /// - page_size: 每页数量（默认 20）\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 返回\n");
        try writer.writeAll("    /// - items: 数据列表\n");
        try writer.writeAll("    /// - total: 总数\n");
        try writer.writeAll("    /// - page: 当前页\n");
        try writer.writeAll("    /// - page_size: 每页数量\n");
        try writer.writeAll("    pub fn list(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        var mutable_req = req;\n\n");
        try writer.writeAll("        // 获取分页参数\n");
        try writer.writeAll("        const page = mutable_req.getParamInt(\"page\", i32, 1) catch 1;\n");
        try writer.writeAll("        const page_size = mutable_req.getParamInt(\"page_size\", i32, 20) catch 20;\n\n");
        try writer.writeAll("        // 查询数据\n");
        try writer.print("        var q = Orm{s}.Query();\n", .{name});
        try writer.writeAll("        defer q.deinit();\n\n");
        try writer.writeAll("        _ = q.orderBy(\"id\", \"DESC\")\n");
        try writer.writeAll("             .limit(page_size)\n");
        try writer.writeAll("             .offset((page - 1) * page_size);\n\n");
        try writer.print("        const items = try q.get();\n");
        try writer.print("        defer Orm{s}.freeModels(items);\n\n", .{name});
        try writer.writeAll("        // 获取总数\n");
        try writer.print("        var count_q = Orm{s}.Query();\n", .{name});
        try writer.writeAll("        defer count_q.deinit();\n");
        try writer.writeAll("        const total = try count_q.count();\n\n");
        try writer.writeAll("        // 返回结果\n");
        try writer.writeAll("        try base.send_success(&mutable_req, .{\n");
        try writer.writeAll("            .items = items,\n");
        try writer.writeAll("            .total = total,\n");
        try writer.writeAll("            .page = page,\n");
        try writer.writeAll("            .page_size = page_size,\n");
        try writer.writeAll("        });\n");
        try writer.writeAll("    }\n\n");
        
        // get 方法
        try writer.writeAll("    /// 获取详情\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 参数\n");
        try writer.writeAll("    /// - id: 记录 ID\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 返回\n");
        try writer.writeAll("    /// - 成功: 返回记录详情\n");
        try writer.writeAll("    /// - 失败: 400 (Invalid ID) 或 404 (Not found)\n");
        try writer.writeAll("    pub fn get(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        var mutable_req = req;\n\n");
        try writer.writeAll("        const id = mutable_req.getParamInt(\"id\", i32, 0) catch {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Invalid ID\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n\n");
        try writer.print("        const item = try Orm{s}.FindById(id) orelse {{\n", .{name});
        try writer.writeAll("            try base.send_error(&mutable_req, \"Not found\", 404);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n");
        try writer.print("        defer Orm{s}.freeModel(item);\n\n", .{name});
        try writer.writeAll("        try base.send_success(&mutable_req, item);\n");
        try writer.writeAll("    }\n\n");
        
        // create 方法
        try writer.writeAll("    /// 创建\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 请求体\n");
        try writer.writeAll("    /// JSON 格式，包含所有必填字段\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 验证规则\n");
        try writer.writeAll("    /// - 必填字段不能为空\n");
        try writer.writeAll("    /// - 字符串长度验证\n");
        try writer.writeAll("    /// - 数值范围验证\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 返回\n");
        try writer.writeAll("    /// - 成功: 返回创建的记录（包含 ID）\n");
        try writer.writeAll("    /// - 失败: 400 (验证失败)\n");
        try writer.writeAll("    pub fn create(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        var mutable_req = req;\n\n");
        try writer.writeAll("        // 解析请求体\n");
        try writer.writeAll("        const body = mutable_req.body orelse {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Missing body\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n\n");
        try writer.writeAll("        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Invalid JSON\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n");
        try writer.writeAll("        defer parsed.deinit();\n\n");
        try writer.writeAll("        const obj = parsed.value.object;\n\n");
        
        // 生成字段映射
        try writer.print("        const item = {s}{{\n", .{name});
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue; // 跳过 ID
            
            const zig_type = try self.mapTypeToZig(allocator, field.type);
            
            if (field.required) {
                // 必填字段
                if (std.mem.eql(u8, field.type, "string")) {
                    try writer.print("            .{s} = obj.get(\"{s}\").?.string,\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "int") or std.mem.eql(u8, field.type, "timestamp")) {
                    try writer.print("            .{s} = @intCast(obj.get(\"{s}\").?.integer),\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "bool")) {
                    try writer.print("            .{s} = obj.get(\"{s}\").?.bool,\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "float")) {
                    try writer.print("            .{s} = obj.get(\"{s}\").?.float,\n", .{ field.name, field.name });
                }
            } else {
                // 可选字段
                if (std.mem.eql(u8, field.type, "string")) {
                    try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .string) v.string else null else null,\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "int") or std.mem.eql(u8, field.type, "timestamp")) {
                    try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .integer) @as(?{s}, @intCast(v.integer)) else null else null,\n", .{ field.name, field.name, zig_type });
                } else if (std.mem.eql(u8, field.type, "bool")) {
                    try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .bool) v.bool else null else null,\n", .{ field.name, field.name });
                } else if (std.mem.eql(u8, field.type, "float")) {
                    try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .float) v.float else null else null,\n", .{ field.name, field.name });
                }
            }
        }
        try writer.writeAll("        };\n\n");
        
        // 生成验证代码
        try writer.writeAll("        // 字段验证\n");
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue;
            
            // 只验证必填字段和有验证规则的字段
            if (field.required or field.min_length != null or field.max_length != null or 
                field.min_value != null or field.max_value != null) {
                const var_name = try std.fmt.allocPrint(allocator, "item.{s}", .{field.name});
                try self.generateValidation(writer, field, var_name);
            }
        }
        try writer.writeAll("\n");
        
        try writer.print("        const created = try Orm{s}.Create(item);\n", .{name});
        try writer.print("        defer Orm{s}.freeModel(created);\n\n", .{name});
        try writer.writeAll("        try base.send_success(&mutable_req, created);\n");
        try writer.writeAll("    }\n\n");
        
        // update 方法
        try writer.writeAll("    /// 更新\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 参数\n");
        try writer.writeAll("    /// - id: 记录 ID\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 请求体\n");
        try writer.writeAll("    /// JSON 格式，只需包含要更新的字段（部分更新）\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 特性\n");
        try writer.writeAll("    /// - 只更新提供的字段\n");
        try writer.writeAll("    /// - null 值会被跳过\n");
        try writer.writeAll("    /// - 未提供的字段保持不变\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 返回\n");
        try writer.writeAll("    /// - 成功: 返回更新成功消息\n");
        try writer.writeAll("    /// - 失败: 400 (Invalid ID 或 Invalid JSON)\n");
        try writer.writeAll("    pub fn update(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        var mutable_req = req;\n\n");
        try writer.writeAll("        const id = mutable_req.getParamInt(\"id\", i32, 0) catch {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Invalid ID\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n\n");
        try writer.writeAll("        // 解析请求体\n");
        try writer.writeAll("        const body = mutable_req.body orelse {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Missing body\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n\n");
        try writer.writeAll("        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Invalid JSON\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n");
        try writer.writeAll("        defer parsed.deinit();\n\n");
        try writer.writeAll("        const obj = parsed.value.object;\n\n");
        
        // 生成 UpdateWith 调用
        try writer.print("        _ = try Orm{s}.UpdateWith(id, .{{\n", .{name});
        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) continue; // 跳过 ID
            
            const zig_type = try self.mapTypeToZig(allocator, field.type);
            
            // 所有字段都作为可选更新
            if (std.mem.eql(u8, field.type, "string")) {
                try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .string) v.string else null else null,\n", .{ field.name, field.name });
            } else if (std.mem.eql(u8, field.type, "int") or std.mem.eql(u8, field.type, "timestamp")) {
                try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .integer) @as(?{s}, @intCast(v.integer)) else null else null,\n", .{ field.name, field.name, zig_type });
            } else if (std.mem.eql(u8, field.type, "bool")) {
                try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .bool) v.bool else null else null,\n", .{ field.name, field.name });
            } else if (std.mem.eql(u8, field.type, "float")) {
                try writer.print("            .{s} = if (obj.get(\"{s}\")) |v| if (v == .float) v.float else null else null,\n", .{ field.name, field.name });
            }
        }
        try writer.writeAll("        });\n\n");
        try writer.writeAll("        try base.send_success(&mutable_req, .{ .message = \"Updated\" });\n");
        try writer.writeAll("    }\n\n");
        
        // delete 方法
        try writer.writeAll("    /// 删除\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 参数\n");
        try writer.writeAll("    /// - id: 记录 ID\n");
        try writer.writeAll("    ///\n");
        try writer.writeAll("    /// ## 返回\n");
        try writer.writeAll("    /// - 成功: 返回删除成功消息\n");
        try writer.writeAll("    /// - 失败: 400 (Invalid ID)\n");
        try writer.writeAll("    pub fn delete(self: *@This(), req: zap.Request) !void {\n");
        try writer.writeAll("        _ = self;\n");
        try writer.writeAll("        var mutable_req = req;\n\n");
        try writer.writeAll("        const id = mutable_req.getParamInt(\"id\", i32, 0) catch {\n");
        try writer.writeAll("            try base.send_error(&mutable_req, \"Invalid ID\", 400);\n");
        try writer.writeAll("            return;\n");
        try writer.writeAll("        };\n\n");
        try writer.print("        try Orm{s}.Delete(id);\n\n", .{name});
        try writer.writeAll("        try base.send_success(&mutable_req, .{ .message = \"Deleted\" });\n");
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
    
    /// 生成字段验证代码
    fn generateValidation(self: *CrudGeneratorTool, writer: anytype, field: Field, var_name: []const u8) !void {
        _ = self;
        
        // 字符串长度验证
        if (std.mem.eql(u8, field.type, "string")) {
            if (field.required) {
                try writer.print("        if ({s}.len == 0) {{\n", .{var_name});
                try writer.print("            try base.send_error(&mutable_req, \"{s} is required\", 400);\n", .{field.name});
                try writer.writeAll("            return;\n");
                try writer.writeAll("        }\n");
            }
            
            if (field.min_length) |min| {
                try writer.print("        if ({s}.len < {d}) {{\n", .{ var_name, min });
                try writer.print("            try base.send_error(&mutable_req, \"{s} too short (min {d})\", 400);\n", .{ field.name, min });
                try writer.writeAll("            return;\n");
                try writer.writeAll("        }\n");
            }
            
            if (field.max_length) |max| {
                try writer.print("        if ({s}.len > {d}) {{\n", .{ var_name, max });
                try writer.print("            try base.send_error(&mutable_req, \"{s} too long (max {d})\", 400);\n", .{ field.name, max });
                try writer.writeAll("            return;\n");
                try writer.writeAll("        }\n");
            }
        }
        
        // 数值范围验证
        if (std.mem.eql(u8, field.type, "int") or std.mem.eql(u8, field.type, "float")) {
            if (field.min_value) |min| {
                try writer.print("        if ({s} < {d}) {{\n", .{ var_name, min });
                try writer.print("            try base.send_error(&mutable_req, \"{s} too small (min {d})\", 400);\n", .{ field.name, min });
                try writer.writeAll("            return;\n");
                try writer.writeAll("        }\n");
            }
            
            if (field.max_value) |max| {
                try writer.print("        if ({s} > {d}) {{\n", .{ var_name, max });
                try writer.print("            try base.send_error(&mutable_req, \"{s} too large (max {d})\", 400);\n", .{ field.name, max });
                try writer.writeAll("            return;\n");
                try writer.writeAll("        }\n");
            }
        }
    }
};

/// 字段定义
/// 字段定义
const Field = struct {
    name: []const u8,
    type: []const u8,
    required: bool,
    min_length: ?usize = null,
    max_length: ?usize = null,
    min_value: ?i64 = null,
    max_value: ?i64 = null,
    pattern: ?[]const u8 = null,
};
