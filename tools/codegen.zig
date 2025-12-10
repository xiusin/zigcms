//! 代码生成工具 - 根据数据库表结构自动生成模型、控制器、DTO等文件
//!
//! 该工具可以：
//! - 连接到数据库并获取表结构信息
//! - 生成对应的模型文件（domain/entities/）
//! - 生成对应的 DTO 文件（api/dto/）
//! - 生成对应的控制器文件（api/controllers/）  
//! - 生成对应的路由配置（在 main.zig 中注册）

const std = @import("std");
const sql_interface = @import("application/services/sql/interface.zig");

pub const Generator = struct {
    allocator: std.mem.Allocator,
    db: sql.Connection,
    
    /// 初始化生成器
    pub fn init(allocator: std.mem.Allocator, db_config: DatabaseConfig) !Generator {
        const db = try connectToDatabase(allocator, db_config);
        return Generator{
            .allocator = allocator,
            .db = db,
        };
    }
    
    /// 数据库配置
    pub const DatabaseConfig = union(enum) {
        mysql: sql_interface.MySQLConfig,
        sqlite: []const u8,
        postgres: sql_interface.PostgreSQLConfig,
    };
    
    /// 连接到数据库
    fn connectToDatabase(allocator: std.mem.Allocator, config: DatabaseConfig) !sql_interface.Connection {
        return switch (config) {
            .mysql => |mysql_config| try sql_interface.Driver.mysql(allocator, mysql_config),
            .sqlite => |path| try sql_interface.Driver.sqlite(allocator, path),
            .postgres => |pg_config| try sql_interface.Driver.postgres(allocator, pg_config),
        };
    }
    
    /// 生成指定表的完整代码
    pub fn generateForTable(self: *Generator, table_name: []const u8) !void {
        std.debug.print("开始生成表 {s} 的代码...\n", .{table_name});
        
        // 获取表结构信息
        const table_info = try self.getTableSchema(table_name);
        
        // 生成模型文件
        try self.generateModelFile(table_name, table_info);
        
        // 生成 DTO 文件
        try self.generateDtoFiles(table_name, table_info);
        
        // 生成控制器文件
        try self.generateControllerFile(table_name, table_info);
        
        // 更新 models.zig 文件以包含新模型
        try self.updateModelsFile(table_name);
        
        // 输出在 main.zig 中需要添加的代码行
        try self.outputRouteRegistration(table_name);
        
        std.debug.print("表 {s} 的代码生成完成！\n", .{table_name});
    }
    
    /// 获取表结构信息
    fn getTableSchema(self: *Generator, table_name: []const u8) !TableSchema {
        // 根据数据库类型使用不同的查询语句
        const driver_type = self.db.getDriverType();
        
        if (driver_type == .sqlite) {
            // SQLite 使用 PRAGMA 获取表结构
            const pragma_result = try self.db.query(try std.fmt.alloc(self.allocator, "PRAGMA table_info({s})", .{table_name}));
            defer pragma_result.deinit();
            
            var schema = TableSchema{
                .columns = std.ArrayList(Column).init(self.allocator),
            };
            defer schema.columns.deinit();
            
            while (pragma_result.next()) |row_ptr| {
                const row = row_ptr.*;
                const notnull = if (row.getInt("notnull")) |nn| nn != 0 else false;
                const pk = if (row.getInt("pk")) |p| p != 0 else false;
                
                const column = Column{
                    .name = row.getString("name") orelse continue,
                    .data_type = row.getString("type") orelse "TEXT",
                    .nullable = !notnull,
                    .primary_key = pk,
                    .auto_increment = pk and std.mem.eql(u8, row.getString("type") orelse "", "INTEGER"),
                };
                
                try schema.columns.append(column);
            }
            
            // 转移到堆内存
            const final_columns = try self.allocator.dupe(Column, schema.columns.items);
            schema.columns.deinit();
            schema.columns = std.ArrayList(Column).initCapacity(self.allocator, final_columns.len);
            for (final_columns) |col| {
                try schema.columns.append(col);
            }
            
            return schema;
        }
        
        // MySQL and PostgreSQL - simplified for basic functionality
        var sql_query: []const u8 = undefined;
        
        switch (driver_type) {
            .mysql => {
                sql_query = try std.fmt.alloc(self.allocator,
                    \\SELECT 
                    \\    COLUMN_NAME as column_name,
                    \\    DATA_TYPE as data_type,
                    \\    IS_NULLABLE as is_nullable
                    \\FROM INFORMATION_SCHEMA.COLUMNS 
                    \\WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '{s}'
                    \\ORDER BY ORDINAL_POSITION
                , .{table_name});
            },
            .postgresql => {
                sql_query = try std.fmt.alloc(self.allocator,
                    \\SELECT 
                    \\    column_name,
                    \\    data_type,
                    \\    is_nullable
                    \\FROM information_schema.columns
                    \\WHERE table_name = '{s}'
                    \\ORDER BY ordinal_position
                , .{table_name});
            },
            else => return error.UnsupportedDatabase,
        }
        
        var result = try self.db.query(sql_query);
        defer result.deinit();
        
        var schema = TableSchema{
            .columns = std.ArrayList(Column).init(self.allocator),
        };
        defer schema.columns.deinit();
        
        while (result.next()) |row_ptr| {
            const row = row_ptr.*;
            
            const column = Column{
                .name = row.getString("column_name") orelse continue,
                .data_type = row.getString("data_type") orelse "text",
                .nullable = if (row.getString("is_nullable")) |nullable| 
                    std.mem.eql(u8, nullable, "YES") or std.mem.eql(u8, nullable, "yes") 
                else false,
                .primary_key = false,
                .auto_increment = false,
            };
            
            // 根据数据库类型处理特定字段
            switch (driver_type) {
                .mysql => {
                    // For now, simplified logic
                },
                .postgresql => {
                    // For now, simplified logic
                },
                else => {},
            }
            
            try schema.columns.append(column);
        }
        
        // 转移到堆内存
        const final_columns = try self.allocator.dupe(Column, schema.columns.items);
        schema.columns.deinit();
        schema.columns = std.ArrayList(Column).initCapacity(self.allocator, final_columns.len);
        for (final_columns) |col| {
            try schema.columns.append(col);
        }
        
        return schema;
    }
    
    /// 生成模型文件
    fn generateModelFile(self: *Generator, table_name: []const u8, schema: TableSchema) !void {
        const model_name = try self.toPascalCase(table_name);
        const file_path = try std.fmt.alloc(self.allocator, "domain/entities/{s}.model.zig", .{std.mem.toLower(table_name)});
        
        var file_content = std.ArrayList(u8).init(self.allocator);
        defer file_content.deinit();
        
        try file_content.writer().print("pub const {s} = struct {{\n", .{model_name});
        
        for (schema.columns.items) |column| {
            const field_type = try self.mapDataType(column.data_type, column.nullable);
            const default_value = try getDefaultValue(field_type, column.nullable, column.auto_increment);
            
            try file_content.writer().print("    {s}: {s} = {s},\n", .{
                self.toSnakeCase(column.name),
                field_type,
                default_value,
            });
        }
        
        try file_content.writer().print("}};\n", .{});
        
        // 写入文件
        try std.fs.cwd().writeFile(file_path, file_content.items);
        std.debug.print("模型文件已生成: {s}\n", .{file_path});
    }
    
    /// 生成 DTO 文件
    fn generateDtoFiles(self: *Generator, table_name: []const u8, schema: TableSchema) !void {
        const lower_name = std.mem.toLower(table_name);
        const pascal_name = try self.toPascalCase(table_name);
        
        // 创建 DTO 目录
        try std.fs.cwd().makeDir("api/dto");
        
        // 生成 Create DTO
        const create_dto_path = try std.fmt.alloc(self.allocator, "api/dto/{s}_create.dto.zig", .{lower_name});
        var create_content = std.ArrayList(u8).init(self.allocator);
        defer create_content.deinit();
        
        try create_content.writer().print(
            \\//! {s} 创建数据传输对象
            \\//!
            \\//! 用于创建 {s} 实体的数据结构
            \\
            \\const std = @import("std");
            \\
            \\pub const {s}CreateDto = struct {{
        , .{ pascal_name, pascal_name, pascal_name });
        
        for (schema.columns.items) |column| {
            // 跳过自增主键
            if (column.primary_key and column.auto_increment) {
                continue;
            }
            
            const field_type = try self.mapDataType(column.data_type, false);
            try create_content.writer().print("    {s}: {s},\n", .{
                self.toSnakeCase(column.name),
                field_type,
            });
        }
        
        try create_content.writer().print("}};\n", .{});
        try std.fs.cwd().writeFile(create_dto_path, create_content.items);
        std.debug.print("创建 DTO 文件已生成: {s}\n", .{create_dto_path});
        
        // 生成 Update DTO
        const update_dto_path = try std.fmt.alloc(self.allocator, "api/dto/{s}_update.dto.zig", .{lower_name});
        var update_content = std.ArrayList(u8).init(self.allocator);
        defer update_content.deinit();
        
        try update_content.writer().print(
            \\//! {s} 更新数据传输对象
            \\//!
            \\//! 用于更新 {s} 实体的数据结构
            \\
            \\const std = @import("std");
            \\
            \\pub const {s}UpdateDto = struct {{
        , .{ pascal_name, pascal_name, pascal_name });
        
        for (schema.columns.items) |column| {
            // 跳过自增主键
            if (column.primary_key and column.auto_increment) {
                continue;
            }
            
            const field_type = try self.mapDataType(column.data_type, true);
            try update_content.writer().print("    {s}: ?{s} = null,\n", .{
                self.toSnakeCase(column.name),
                field_type,
            });
        }
        
        try update_content.writer().print("}};\n", .{});
        try std.fs.cwd().writeFile(update_dto_path, update_content.items);
        std.debug.print("更新 DTO 文件已生成: {s}\n", .{update_dto_path});
        
        // 生成 Response DTO
        const response_dto_path = try std.fmt.alloc(self.allocator, "api/dto/{s}_response.dto.zig", .{lower_name});
        var response_content = std.ArrayList(u8).init(self.allocator);
        defer response_content.deinit();
        
        try response_content.writer().print(
            \\//! {s} 响应数据传输对象
            \\//!
            \\//! 用于返回 {s} 实体的数据结构
            \\
            \\const std = @import("std");
            \\
            \\pub const {s}ResponseDto = struct {{
        , .{ pascal_name, pascal_name, pascal_name });
        
        for (schema.columns.items) |column| {
            const field_type = try self.mapDataType(column.data_type, column.nullable);
            try response_content.writer().print("    {s}: {s},\n", .{
                self.toSnakeCase(column.name),
                field_type,
            });
        }
        
        try response_content.writer().print("}};\n", .{});
        try std.fs.cwd().writeFile(response_dto_path, response_content.items);
        std.debug.print("响应 DTO 文件已生成: {s}\n", .{response_dto_path});
    }
    
    /// 生成控制器文件
    fn generateControllerFile(self: *Generator, table_name: []const u8, schema: TableSchema) !void {
        _ = schema; // 未在控制器生成中直接使用，但可扩展
        
        const pascal_name = try self.toPascalCase(table_name);
        const lower_name = std.mem.toLower(table_name);
        
        // 创建控制器目录
        try std.fs.cwd().makeDir("api/controllers");
        
        const controller_path = try std.fmt.alloc(self.allocator, "api/controllers/{s}_crud.controller.zig", .{lower_name});
        var controller_content = std.ArrayList(u8).init(self.allocator);
        defer controller_content.deinit();
        
        try controller_content.writer().print(
            \\//! {s} CRUD 控制器
            \\//!
            \\//! 为 {s} 实体提供基本的 CRUD 操作
            \\
            \\const std = @import("std");
            \\const zap = @import("zap");
            \\const Allocator = std.mem.Allocator;
            \\
            \\const base = @import("base.fn.zig");
            \\const dtos = @import("../dto/mod.zig");
            \\const models = @import("../../domain/entities/models.zig");
            \\const sql = @import("../../application/services/sql/orm.zig");
            \\const global = @import("../../shared/primitives/global.zig");
            \\const json_mod = @import("../../application/services/json/json.zig");
            \\const strings = @import("../../shared/utils/strings.zig");
            \\
            \\const Self = @This();
            \\
            \\allocator: Allocator,
            \\
            \\pub fn init(allocator: Allocator) Self {{
            \\    return .{{
            \\        .allocator = allocator,
            \\    }};
            \\}}
            \\
            \\// 使用 ORM 定义 {s} 模型操作
            \\const Orm{s} = sql.defineWithConfig(models.{s}, .{{
            \\    .table_name = \"{s}\",
            \\    .primary_key = \"id\",
            \\}});
            \\
            \\// 列表查询
            \\pub fn list(self: *Self, req: zap.Request) !void {{
            \\    req.parseQuery();
            \\
            \\    // 解析分页参数
            \\    var page: i32 = 1;
            \\    var limit: i32 = 10;
            \\    var sort_field: []const u8 = \"id\";
            \\    var sort_order: []const u8 = \"desc\";
            \\
            \\    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
            \\    defer params.deinit();
            \\
            \\    for (params.items) |value| {{
            \\        if (strings.eql(value.key, \"page\")) {{
            \\            page = @intCast(strings.to_int(value.value) catch 1);
            \\        }} else if (strings.eql(value.key, \"limit\")) {{
            \\            limit = @intCast(strings.to_int(value.value) catch 10);
            \\        }} else if (strings.eql(value.key, \"field\") and strings.starts_with(value.key, \"sort[\")) {{
            \\            sort_field = value.value;
            \\        }} else if (strings.eql(value.key, \"sort\")) {{
            \\            sort_order = value.value;
            \\        }}
            \\    }}
            \\
            \\    // 使用 ORM 统计总数
            \\    const total = Orm{s}.Count() catch |e| return base.send_error(req, e);
            \\
            \\    // 使用 ORM QueryBuilder 分页查询
            \\    const order_dir: sql.OrderDir = if (strings.eql(sort_order, \"asc\")) .asc else .desc;
            \\    var q = Orm{s}.OrderBy(sort_field, order_dir);
            \\    defer q.deinit();
            \\    _ = q.page(page, limit);
            \\
            \\    const items_slice = q.get() catch |e| return base.send_error(req, e);
            \\    defer Orm{s}.freeModels(self.allocator, items_slice);
            \\
            \\    var items = std.ArrayListUnmanaged(models.{s}){{}};
            \\    defer items.deinit(self.allocator);
            \\    for (items_slice) |item| {{
            \\        items.append(self.allocator, item) catch {{}};
            \\    }}
            \\
            \\    base.send_layui_table_response(req, items.items, total, .{{}});
            \\}}
            \\
            \\// 获取单条记录
            \\pub fn get(self: *Self, req: zap.Request) !void {{
            \\    req.parseQuery();
            \\    const id_str = req.getParamSlice(\"id\") orelse return base.send_failed(req, \"缺少 id\");
            \\    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, \"id 格式错误\"));
            \\
            \\    // 使用 ORM 查询
            \\    const item_opt = Orm{s}.Find(id) catch |e| return base.send_error(req, e);
            \\    if (item_opt == null) {{
            \\        return base.send_failed(req, \"记录不存在\");
            \\    }}
            \\
            \\    var item = item_opt.?;
            \\    defer Orm{s}.freeModel(self.allocator, &item);
            \\
            \\    return base.send_ok(req, item);
            \\}}
            \\
            \\// 创建记录
            \\pub fn save(self: *Self, req: zap.Request) !void {{
            \\    req.parseBody() catch return base.send_failed(req, \"解析请求体失败\");
            \\
            \\    const body = req.body orelse return base.send_failed(req, \"请求体为空\");
            \\    var dto = models.{s}{{}};
            \\    // 在实际项目中，应该使用专门的 DTO 类型
            \\
            \\    // 使用 ORM 进行数据库操作
            \\    var new_item = Orm{s}.Create(dto) catch |e| return base.send_error(req, e);
            \\    defer Orm{s}.freeModel(self.allocator, &new_item);
            \\
            \\    return base.send_ok(req, new_item);
            \\}}
            \\
            \\// 更新记录
            \\pub fn modify(self: *Self, req: zap.Request) !void {{
            \\    req.parseBody() catch return base.send_failed(req, \"解析请求体失败\");
            \\
            \\    var params = req.parametersToOwnedStrList(self.allocator) catch return;
            \\    defer params.deinit();
            \\
            \\    var id: i32 = 0;
            \\    var field: []const u8 = \"\";
            \\    var value: []const u8 = \"\";
            \\
            \\    for (params.items) |item| {{
            \\        if (strings.eql(\"id\", item.key)) {{
            \\            id = @intCast(strings.to_int(item.value) catch 0);
            \\        }} else if (strings.eql(\"field\", item.key)) {{
            \\            field = item.value;
            \\        }} else if (strings.eql(\"value\", item.key)) {{
            \\            value = item.value;
            \\        }}
            \\    }}
            \\
            \\    if (id == 0 or field.len == 0) return base.send_failed(req, \"参数不完整\");
            \\
            \\    // 验证字段（运行时检查）
            \\    var field_valid = false;
            \\    inline for (std.meta.fields(models.{s})) |f| {{
            \\        if (std.mem.eql(u8, f.name, field)) {{
            \\            field_valid = true;
            \\            break;
            \\        }}
            \\    }}
            \\    if (!field_valid) return base.send_failed(req, \"字段不存在\");
            \\
            \\    // 使用 ORM 更新
            \\    const affected = Orm{s}.Update(id, .{{}}) catch |e| return base.send_error(req, e);
            \\    // 简化更新，实际应构建更新数据
            \\
            \\    if (affected == 0) {{
            \\        return base.send_failed(req, \"更新失败\");
            \\    }}
            \\
            \\    return base.send_ok(req, \"更新成功\");
            \\}}
            \\
            \\// 删除记录
            \\pub fn delete(self: *Self, req: zap.Request) !void {{
            \\    req.parseQuery();
            \\    const id_str = req.getParamSlice(\"id\") orelse return base.send_failed(req, \"缺少 id\");
            \\    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, \"id 格式错误\"));
            \\
            \\    // 使用 ORM 删除
            \\    const affected = Orm{s}.Destroy(id) catch |e| return base.send_error(req, e);
            \\
            \\    if (affected == 0) {{
            \\        return base.send_failed(req, \"删除失败\");
            \\    }}
            \\
            \\    return base.send_ok(req, affected);
            \\}}
            \\
            \\// 选择操作（用于下拉框等）
            \\pub fn select(self: *Self, req: zap.Request) !void {{
            \\    // 使用 ORM 获取所有记录
            \\    const items_slice = Orm{s}.All() catch return;
            \\    defer Orm{s}.freeModels(self.allocator, items_slice);
            \\
            \\    var items = std.ArrayListUnmanaged(models.{s}){{}};
            \\    defer items.deinit(self.allocator);
            \\
            \\    for (items_slice) |item| {{
            \\        items.append(self.allocator, item) catch {{}};
            \\    }}
            \\
            \\    base.send_ok(req, items.items);
            \\}}
        , .{ pascal_name, pascal_name, pascal_name, table_name, pascal_name, pascal_name, pascal_name, pascal_name, pascal_name, pascal_name, pascal_name });
        
        try std.fs.cwd().writeFile(controller_path, controller_content.items);
        std.debug.print("控制器文件已生成: {s}\n", .{controller_path});
    }
    
    /// 更新 models.zig 文件以包含新生成的模型
    fn updateModelsFile(self: *Generator, table_name: []const u8) !void {
        const pascal_name = try self.toPascalCase(table_name);
        const lower_name = std.mem.toLower(table_name);
        
        // Read the existing models.zig file, or create a template if it doesn't exist
        const content = std.fs.cwd().readFileAlloc(self.allocator, "domain/entities/models.zig", 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => {
                // 如果文件不存在，创建新的 models.zig 文件
                const template_content = 
                    \\//! 领域实体入口 - 统一导出所有业务实体
                    \\//!
                    \\//! 遵循领域驱动设计，这些实体包含业务规则和状态
                    \\
                    \\const std = @import("std");
                    \\
                    \\// 导入所有领域实体
                    \\pub const {s} = @import("{s}.model.zig").{s};
                    \\
                    \\/// 实体类型枚举，用于泛型操作
                    \\pub const EntityType = enum {{
                    \\    {s},
                    \\}};
                    \\
                    \\/// 通用实体接口
                    \\pub const EntityInterface = struct {{
                    \\    /// 获取实体表名
                    \\    pub fn getTableName(entity_type: EntityType) []const u8 {{
                    \\        return switch (entity_type) {{
                    \\            .{s} => "{s}",
                    \\        }};
                    \\    }}
                    \\}};
                ;
                
                const new_content = try std.fmt.alloc(self.allocator, template_content, .{ 
                    pascal_name, 
                    lower_name, 
                    pascal_name, 
                    lower_name, 
                    lower_name, 
                    table_name 
                });
                
                try std.fs.cwd().createFile("domain/entities/models.zig", .{}).writeAll(new_content);
                std.debug.print("创建新的 models.zig 文件\n", .{});
                return;
            },
            else => return err,
        };
        
        // 检查是否模型已存在
        const existing_check = try std.fmt.alloc(self.allocator, "pub const {s} =", .{pascal_name});
        if (std.mem.indexOf(u8, content, existing_check)) |_| {
            std.debug.print("模型 {s} 已存在于 models.zig 中\n", .{pascal_name});
            return;
        }
        
        // Create new content by adding the import and updating enum/switch
        var new_content = std.ArrayList(u8).init(self.allocator);
        defer new_content.deinit();
        
        var line_iter = std.mem.split(u8, content, "\n");
        var added_import = false;
        var added_enum = false;
        var added_switch = false;
        
        while (line_iter.next()) |line| {
            try new_content.writer().print("{s}\n", .{line});
            
            // Add import after the comment
            if (!added_import and std.mem.indexOf(u8, line, "// 导入所有领域实体")) |_| {
                try new_content.writer().print("pub const {s} = @import(\"{s}.model.zig\").{s};\n", .{
                    pascal_name, lower_name, pascal_name
                });
                added_import = true;
            }
            // Add enum value after the opening brace
            else if (!added_enum and std.mem.eql(u8, std.trim(line), "pub const EntityType = enum {")) {
                try new_content.writer().print("    {s},\n", .{lower_name});
                added_enum = true;
            }
            // Add switch case before the closing brace of the switch statement
            else if (std.mem.indexOf(u8, line, "return switch (entity_type) {")) |_| {
                // We found the start of the switch, mark that we're in the right place
                // The case will be added when we find the closing brace
            }
            else if (std.mem.eql(u8, std.trim(line), "};") and 
                     std.mem.indexOf(u8, new_content.items, "return switch (entity_type) {")) |_| {
                // This is the closing brace of the switch statement, add our case before it
                if (!added_switch) {
                    try new_content.writer().print("            .{s} => \"{s}\",\n", .{lower_name, table_name});
                    added_switch = true;
                }
            }
        }
        
        // Write the updated content
        try std.fs.cwd().writeFile("domain/entities/models.zig", new_content.items);
        std.debug.print("已更新 models.zig 文件\n", .{});
    }
    
    /// 输出在 main.zig 中需要添加的路由注册代码
    fn outputRouteRegistration(self: *Generator, table_name: []const u8) !void {
        const lower_name = std.mem.toLower(table_name);
        const pascal_name = try self.toPascalCase(table_name);
        
        std.debug.print("\n在 main.zig 中添加以下代码行:\n", .{});
        std.debug.print("    try app.crud(\"{s}\", models.{s});\n", .{ lower_name, pascal_name });
        std.debug.print("\n如果需要手动注册控制器，需要先在 api/controllers/mod.zig 中添加导入:\n", .{});
        std.debug.print("    pub const {s} = struct {{\n", .{lower_name});
        std.debug.print("        pub const Crud = @import(\"{s}_crud.controller.zig\");\n", .{lower_name});
        std.debug.print("    }};\n", .{});
        std.debug.print("\n然后在 main.zig 中注册路由:\n", .{});
        std.debug.print("    var {s}_ctrl = controllers.{s}.Crud.init(allocator);\n", .{ lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/list\", &{s}_ctrl, &controllers.{s}.Crud.list);\n", .{ lower_name, lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/get\", &{s}_ctrl, &controllers.{s}.Crud.get);\n", .{ lower_name, lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/save\", &{s}_ctrl, &controllers.{s}.Crud.save);\n", .{ lower_name, lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/modify\", &{s}_ctrl, &controllers.{s}.Crud.modify);\n", .{ lower_name, lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/delete\", &{s}_ctrl, &controllers.{s}.Crud.delete);\n", .{ lower_name, lower_name, lower_name });
        std.debug.print("    try app.route(\"/{s}/select\", &{s}_ctrl, &controllers.{s}.Crud.select);\n", .{ lower_name, lower_name, lower_name });
    }
    
    /// 将数据类型映射到 Zig 类型
    fn mapDataType(self: *Generator, sql_type: []const u8, is_nullable: bool) ![]const u8 {
        const lower_type = std.ascii.lowerString(self.allocator, sql_type) catch sql_type;
        const base_type = blk: {
            if (std.mem.eql(u8, lower_type, "int") or 
                std.mem.eql(u8, lower_type, "integer") or 
                std.mem.eql(u8, lower_type, "tinyint") or 
                std.mem.eql(u8, lower_type, "smallint") or 
                std.mem.eql(u8, lower_type, "mediumint")) {
                break :blk "i32";
            } else if (std.mem.eql(u8, lower_type, "bigint")) {
                break :blk "i64";
            } else if (std.mem.eql(u8, lower_type, "decimal") or 
                      std.mem.eql(u8, lower_type, "numeric") or 
                      std.mem.eql(u8, lower_type, "real") or 
                      std.mem.eql(u8, lower_type, "double") or 
                      std.mem.eql(u8, lower_type, "float")) {
                break :blk "f64";
            } else if (std.mem.eql(u8, lower_type, "boolean") or 
                      std.mem.eql(u8, lower_type, "bool")) {
                break :blk "bool";
            } else if (std.mem.eql(u8, lower_type, "varchar") or 
                      std.mem.eql(u8, lower_type, "char") or 
                      std.mem.eql(u8, lower_type, "text") or 
                      std.mem.eql(u8, lower_type, "longtext") or 
                      std.mem.eql(u8, lower_type, "mediumtext") or 
                      std.mem.eql(u8, lower_type, "tinytext") or 
                      std.mem.eql(u8, lower_type, "json") or 
                      std.mem.eql(u8, lower_type, "jsonb")) {
                break :blk "[]const u8";
            } else if (std.mem.eql(u8, lower_type, "date") or 
                      std.mem.eql(u8, lower_type, "time") or 
                      std.mem.eql(u8, lower_type, "datetime") or 
                      std.mem.eql(u8, lower_type, "timestamp")) {
                break :blk "i64"; // 使用时间戳
            } else if (std.mem.eql(u8, lower_type, "blob") or 
                      std.mem.eql(u8, lower_type, "binary") or 
                      std.mem.eql(u8, lower_type, "varbinary")) {
                break :blk "[]u8";
            } else {
                break :blk "[]const u8"; // 默认为字符串
            }
        };
        
        if (is_nullable) {
            return try std.fmt.alloc(self.allocator, "?{s}", .{base_type});
        } else {
            return base_type;
        }
    }
    
    /// 生成默认值
    fn getDefaultValue(field_type: []const u8, is_nullable: bool, auto_increment: bool) ![]const u8 {
        if (auto_increment) {
            return "0"; // 自增字段默认为0（实际插入时会自动生成）
        }

        if (is_nullable) {
            return "null";
        }

        const default_val = blk: {
            if (std.mem.eql(u8, field_type, "i32") or std.mem.eql(u8, field_type, "i64")) {
                break :blk "0";
            } else if (std.mem.eql(u8, field_type, "f64")) {
                break :blk "0.0";
            } else if (std.mem.eql(u8, field_type, "bool")) {
                break :blk "false";
            } else if (std.mem.eql(u8, field_type, "[]const u8")) {
                break :blk "\"\"";
            } else if (std.mem.eql(u8, field_type, "[]u8")) {
                break :blk "[]u8{}";
            } else {
                if (std.mem.startsWith(u8, field_type, "?")) {
                    break :blk "null";
                } else {
                    break :blk "0";
                }
            }
        };

        return default_val;
    }
    
    /// 转换为驼峰命名法
    fn toPascalCase(self: *Generator, input: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        var capitalize_next = true;
        
        for (input) |c| {
            if (c == '_' or c == '-') {
                capitalize_next = true;
            } else if (capitalize_next) {
                try result.append(std.ascii.toUpper(c));
                capitalize_next = false;
            } else {
                try result.append(std.ascii.toLower(c));
            }
        }
        
        return result.toOwnedSlice();
    }
    
    /// 转换为蛇形命名法
    fn toSnakeCase(self: *Generator, input: []const u8) []const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        var first_char = true;
        
        for (input) |c| {
            if (std.ascii.isUpper(c) and !first_char) {
                result.append('_') catch return input; // fallback to original
                result.append(std.ascii.toLower(c)) catch return input; // fallback to original
            } else if (c == '-' or c == ' ') {
                result.append('_') catch return input; // fallback to original
            } else {
                result.append(std.ascii.toLower(c)) catch return input; // fallback to original
            }
            first_char = false;
        }
        
        return result.toOwnedSlice() catch input; // fallback to original
    }
    
    /// 销毁生成器
    pub fn deinit(self: *Generator) void {
        self.db.deinit();
    }
    
    /// 表结构信息
    const TableSchema = struct {
        columns: std.ArrayList(Column),
    };
    
    /// 列信息
    const Column = struct {
        name: []const u8,
        data_type: []const u8,
        nullable: bool,
        primary_key: bool,
        auto_increment: bool,
    };
};

/// 主入口点 - 用于命令行调用
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 3) {
        std.debug.print(
            \\代码生成工具 - 根据数据库表结构自动生成模型、控制器、DTO等文件
            \\
            \\用法: {s} [table_name] [database_type] [connection_params...]
            \\
            \\示例:
            \\  {s} users mysql --host=localhost --user=root --password= --database=myapp
            \\  {s} posts sqlite ./database.db
            \\  {s} articles postgres --host=localhost --user=postgres --password= --database=myapp
            \\
        , .{ args[0], args[0], args[0], args[0] });
        return;
    }
    
    const table_name = args[1];
    const db_type = args[2];
    
    var gen: Generator = undefined;
    
    // 连接数据库
    if (std.mem.eql(u8, db_type, "mysql")) {
        if (args.len < 6) {
            std.debug.print("MySQL 连接需要更多参数: --host, --user, --database\n", .{});
            return;
        }
        
        var host: []const u8 = "localhost";
        var user: []const u8 = "root";
        var password: []const u8 = "";
        var database: []const u8 = "";
        var port: u16 = 3306;
        
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--host")) {
                i += 1;
                if (i < args.len) host = args[i];
            } else if (std.mem.eql(u8, args[i], "--user")) {
                i += 1;
                if (i < args.len) user = args[i];
            } else if (std.mem.eql(u8, args[i], "--password")) {
                i += 1;
                if (i < args.len) password = args[i];
            } else if (std.mem.eql(u8, args[i], "--database")) {
                i += 1;
                if (i < args.len) database = args[i];
            } else if (std.mem.eql(u8, args[i], "--port")) {
                i += 1;
                if (i < args.len) {
                    port = try std.fmt.parseInt(u16, args[i], 10);
                }
            }
        }
        
        const config = Generator.DatabaseConfig{ .mysql = .{
            .host = host,
            .port = port,
            .user = user,
            .password = password,
            .database = database,
        } };
        
        gen = try Generator.init(allocator, config);
    } else if (std.mem.eql(u8, db_type, "sqlite")) {
        if (args.len < 4) {
            std.debug.print("SQLite 连接需要数据库路径: {s} [table_name] sqlite [path]\n", .{args[0]});
            return;
        }
        
        const config = Generator.DatabaseConfig{ .sqlite = args[3] };
        gen = try Generator.init(allocator, config);
    } else if (std.mem.eql(u8, db_type, "postgres")) {
        if (args.len < 6) {
            std.debug.print("PostgreSQL 连接需要更多参数: --host, --user, --database\n", .{});
            return;
        }
        
        var host: []const u8 = "localhost";
        var user: []const u8 = "postgres";
        var password: []const u8 = "";
        var database: []const u8 = "postgres";
        var port: u16 = 5432;
        
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--host")) {
                i += 1;
                if (i < args.len) host = args[i];
            } else if (std.mem.eql(u8, args[i], "--user")) {
                i += 1;
                if (i < args.len) user = args[i];
            } else if (std.mem.eql(u8, args[i], "--password")) {
                i += 1;
                if (i < args.len) password = args[i];
            } else if (std.mem.eql(u8, args[i], "--database")) {
                i += 1;
                if (i < args.len) database = args[i];
            } else if (std.mem.eql(u8, args[i], "--port")) {
                i += 1;
                if (i < args.len) {
                    port = try std.fmt.parseInt(u16, args[i], 10);
                }
            }
        }
        
        const config = Generator.DatabaseConfig{ .postgres = .{
            .host = host,
            .port = port,
            .user = user,
            .password = password,
            .database = database,
        } };
        
        gen = try Generator.init(allocator, config);
    } else {
        std.debug.print("不支持的数据库类型: {s}\n", .{db_type});
        return;
    }
    
    defer gen.deinit();
    
    try gen.generateForTable(table_name);
}