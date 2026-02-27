//! 代码生成器实现 - 负责具体文件的生成逻辑
//! 
//! 包含模型、DTO、控制器的模板和生成逻辑。

const std = @import("std");
const base = @import("base");
const Command = base.Command;

/// 字段定义
pub const FieldDef = struct {
    name: []const u8,
    zig_type: []const u8,
    sql_type: []const u8,
};

/// 默认字段列表
pub const default_fields = [_]FieldDef{
    .{ .name = "id", .zig_type = "i32", .sql_type = "INTEGER PRIMARY KEY" },
    .{ .name = "created_at", .zig_type = "i64", .sql_type = "INTEGER" },
    .{ .name = "updated_at", .zig_type = "i64", .sql_type = "INTEGER" },
};

/// 生成模型文件
pub fn generateModel(allocator: std.mem.Allocator, name: []const u8, table_name: []const u8, custom_fields: []const FieldDef) !void {
    const snake_name = try toSnakeCase(allocator, name);
    defer allocator.free(snake_name);

    const path = try std.fmt.allocPrint(allocator, "domain/entities/{s}.zig", .{snake_name});
    defer allocator.free(path);

    if (base.fileExists(path)) {
        const warning_msg = try std.fmt.allocPrint(allocator, "文件已存在: {s}，跳过生成", .{path});
        defer allocator.free(warning_msg);
        Command.showWarning(warning_msg);
        return;
    }

    var content = std.ArrayListUnmanaged(u8){};
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    try writer.print(
        \\\\//! {s} 实体模型
        \\\\//! 
        \\\\//! 自动生成的模型文件，对应数据库表: {s}
        \\\\ 
        \\\\const std = @import("std");
        \\\\const Model = @import("../../infrastructure/database/orm.zig").Model;
        \\\\
        \\\\/// {s} 实体
        \\\\pub const {s} = Model.define(struct {{
        \\\\    const Self = @This();
        \\\\    pub const table_name = "{s}";
        \\\\
        \\\\
    , .{ name, table_name, name, name, table_name });

    for (default_fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, field.zig_type });
    }

    for (custom_fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, field.zig_type });
    }

    try writer.writeAll(
        \\\\ 
        \\\\    /// 验证模型数据
        \\\\    pub fn validate(self: *const Self) bool {
        \\\\        _ = self;
        \\\\        // TODO: 添加验证逻辑
        \\\\        return true;
        \\\\    }
        \\\\});
        \\\\
    );

    try base.writeFile(path, content.items);
    
    const success_msg = try std.fmt.allocPrint(allocator, "生成模型: {s}", .{path});
    defer allocator.free(success_msg);
    Command.showSuccess(success_msg);
}

/// 生成 DTO 文件
pub fn generateDto(allocator: std.mem.Allocator, name: []const u8, custom_fields: []const FieldDef) !void {
    const snake_name = try toSnakeCase(allocator, name);
    defer allocator.free(snake_name);

    const path = try std.fmt.allocPrint(allocator, "api/dto/{s}_dto.zig", .{snake_name});
    defer allocator.free(path);

    if (base.fileExists(path)) {
        const warning_msg = try std.fmt.allocPrint(allocator, "文件已存在: {s}，跳过生成", .{path});
        defer allocator.free(warning_msg);
        Command.showWarning(warning_msg);
        return;
    }

    var content = std.ArrayListUnmanaged(u8){};
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    try writer.print(
        \\\\//! {s} 数据传输对象
        \\\\//! 
        \\\\//! 用于 API 层的请求和响应数据结构
        \\\\
        \\\\const std = @import("std");
        \\\\
        \\\\/// 创建 {s} 请求
        \\\\pub const Create{s}Request = struct {{
        \\\\ 
    , .{ name, name, name });

    for (custom_fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, field.zig_type });
    }

    try writer.print(
        \\\\}};
        \\\\
        \\\\/// 更新 {s} 请求
        \\\\pub const Update{s}Request = struct {{
        \\\\ 
    , .{ name, name });

    for (custom_fields) |field| {
        try writer.print("    {s}: ?{s} = null,\n", .{ field.name, field.zig_type });
    }

    try writer.print(
        \\\\}};
        \\\\
        \\\\/// {s} 响应
        \\\\pub const {s}Response = struct {{
        \\\\    id: i32,
        \\\\ 
    , .{ name, name });

    for (custom_fields) |field| {
        try writer.print("    {s}: {s},\n", .{ field.name, field.zig_type });
    }

    try writer.writeAll(
        \\\\    created_at: i64,
        \\\\    updated_at: i64,
        \\\\};
        \\\\
        \\\\/// 分页列表响应
        \\\\pub const ListResponse = struct {{
        \\\\    items: []const @This().Response,
        \\\\    total: usize,
        \\\\    page: usize,
        \\\\    page_size: usize,
        \\\\
        \\\\    pub const Response = @This();
        \\\\};
        \\\\
    );

    try base.writeFile(path, content.items);
    
    const success_msg = try std.fmt.allocPrint(allocator, "生成 DTO: {s}", .{path});
    defer allocator.free(success_msg);
    Command.showSuccess(success_msg);
}

/// 生成控制器文件
pub fn generateController(allocator: std.mem.Allocator, name: []const u8) !void {
    const snake_name = try toSnakeCase(allocator, name);
    defer allocator.free(snake_name);

    const path = try std.fmt.allocPrint(allocator, "api/controllers/{s}_controller.zig", .{snake_name});
    defer allocator.free(path);

    if (base.fileExists(path)) {
        const warning_msg = try std.fmt.allocPrint(allocator, "文件已存在: {s}，跳过生成", .{path});
        defer allocator.free(warning_msg);
        Command.showWarning(warning_msg);
        return;
    }

    var content = std.ArrayListUnmanaged(u8){};
    defer content.deinit(allocator);

    const writer = content.writer(allocator);

    try writer.print(
        \\\\//! {s} 控制器
        \\\\//! 
        \\\\//! 处理 {s} 相关的 HTTP 请求
        \\\\ 
        \\\\const std = @import("std");
        \\\\const zap = @import("zap");
        \\\\
        \\\\/// {s} 控制器
        \\\\pub const {s}Controller = struct {{
        \\\\    allocator: std.mem.Allocator,
        \\\\
        \\\\    pub fn init(allocator: std.mem.Allocator) {s}Controller {{
        \\\\        return .{{ .allocator = allocator }};
        \\\\    }}
        \\\\
        \\\\    /// 获取列表
        \\\\    pub fn index(self: *{s}Controller, req: zap.Request) !void {{
        \\\\        _ = self;
        \\\\        req.setHeader("Content-Type", "application/json") catch {{}};
        \\\\        req.setBody(
        \\\\            \{{"message": "GET /{s}s - 列表接口"}}
        \\\\        ) catch {{}};
        \\\\    }}
        \\\\
        \\\\    /// 获取详情
        \\\\    pub fn show(self: *{s}Controller, req: zap.Request, id: []const u8) !void {{
        \\\\        _ = self;
        \\\\        _ = id;
        \\\\        req.setHeader("Content-Type", "application/json") catch {{}};
        \\\\        req.setBody(
        \\\\            \{{"message": "GET /{s}s/:id - 详情接口"}}
        \\\\        ) catch {{}};
        \\\\    }}
        \\\\
        \\\\    /// 创建
        \\\\    pub fn create(self: *{s}Controller, req: zap.Request) !void {{
        \\\\        _ = self;
        \\\\        req.setHeader("Content-Type", "application/json") catch {{}};
        \\\\        req.setBody(
        \\\\            \{{"message": "POST /{s}s - 创建接口"}}
        \\\\        ) catch {{}};
        \\\\    }}
        \\\\
        \\\\    /// 更新
        \\\\    pub fn update(self: *{s}Controller, req: zap.Request, id: []const u8) !void {{
        \\\\        _ = self;
        \\\\        _ = id;
        \\\\        req.setHeader("Content-Type", "application/json") catch {{}};
        \\\\        req.setBody(
        \\\\            \{{"message": "PUT /{s}s/:id - 更新接口"}}
        \\\\        ) catch {{}};
        \\\\    }}
        \\\\
        \\\\    /// 删除
        \\\\    pub fn delete(self: *{s}Controller, req: zap.Request, id: []const u8) !void {{
        \\\\        _ = self;
        \\\\        _ = id;
        \\\\        req.setHeader("Content-Type", "application/json") catch {{}};
        \\\\        req.setBody(
        \\\\            \{{"message": "DELETE /{s}s/:id - 删除接口"}}
        \\\\        ) catch {{}};
        \\\\    }}
        \\\\}};
        \\\\
    , .{ name, name, name, name, name, name, snake_name, name, snake_name, name, snake_name, name, snake_name, name, snake_name });

    try base.writeFile(path, content.items);
    
    const success_msg = try std.fmt.allocPrint(allocator, "生成控制器: {s}", .{path});
    defer allocator.free(success_msg);
    Command.showSuccess(success_msg);
}

/// 转换为 snake_case
pub fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    for (input, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i > 0) {
                try result.append(allocator, '_');
            }
            try result.append(allocator, std.ascii.toLower(c));
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}
