//! 代码生成工具 - 根据表结构自动生成模型、控制器、DTO等文件
//!
//! 本工具用于快速生成 ZigCMS 项目中的常用代码文件，
//! 支持生成模型、控制器、DTO 等文件，遵循项目的整洁架构规范。
//!
//! ## 使用方式
//! ```
//! zig build codegen -- --name=Article
//! zig build codegen -- --name=User --table=users --all
//! zig build codegen -- --help
//! ```

const std = @import("std");
const base = @import("base");
const generators = @import("generators.zig");

const Command = base.Command;
const CommandArgs = base.CommandArgs;
const OptionDef = base.OptionDef;
const FieldDef = generators.FieldDef;

/// 代码生成命令定义
pub const command = Command{
    .name = "codegen",
    .description = "代码生成工具 - 根据表结构自动生成模型、控制器、DTO等文件",
    .usage = "zig build codegen -- --name=<模型名> [选项]",
    .options = &[_]OptionDef{
        .{
            .name = "name",
            .short = 'n',
            .description = "模型名称（PascalCase，如 Article）",
            .required = true,
        },
        .{
            .name = "table",
            .short = 't',
            .description = "数据库表名（默认为模型名的 snake_case 复数形式）",
            .required = false,
        },
        .{
            .name = "fields",
            .short = 'f',
            .description = "字段定义，格式: name:type,name:type（如 title:string,views:i32）",
            .required = false,
        },
        .{
            .name = "all",
            .short = 'a',
            .description = "生成所有文件（模型、DTO、控制器）",
            .is_flag = true,
        },
        .{
            .name = "model",
            .short = 'm',
            .description = "仅生成模型文件",
            .is_flag = true,
        },
        .{
            .name = "dto",
            .short = 'd',
            .description = "仅生成 DTO 文件",
            .is_flag = true,
        },
        .{
            .name = "controller",
            .short = 'c',
            .description = "仅生成控制器文件",
            .is_flag = true,
        },
        .{
            .name = "help",
            .short = 'h',
            .description = "显示帮助信息",
            .is_flag = true,
        },
    },
    .examples = &[_][]const u8{
        "zig build codegen -- --name=Article",
        "zig build codegen -- --name=User --table=users",
        "zig build codegen -- --name=Product --fields=name:string,price:f64,stock:i32",
        "zig build codegen -- --name=Category --all",
        "zig build codegen -- --name=Tag --model --dto",
    },
};

/// 运行代码生成命令
pub fn run(allocator: std.mem.Allocator) !void {
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    // 跳过程序名
    _ = args_iter.skip();

    var args = try base.parseArgs(allocator, &args_iter);
    defer args.deinit();

    // 检查帮助标志
    if (args.hasFlag("help") or args.hasFlag("h")) {
        command.showHelp();
        return;
    }

    // 获取模型名称
    const name = args.getOption("name") orelse args.getOption("n") orelse {
        command.showError("缺少必填参数: --name");
        return;
    };

    // 获取表名（默认为模型名的 snake_case）
    const table_name = args.getOption("table") orelse args.getOption("t") orelse blk: {
        const snake_name = try generators.toSnakeCase(allocator, name);
        defer allocator.free(snake_name);
        break :blk try allocator.dupe(u8, snake_name);
    };
    defer if (args.getOption("table") == null and args.getOption("t") == null) allocator.free(table_name);

    // 解析字段定义
    const fields_str = args.getOption("fields") orelse args.getOption("f");
    var custom_fields = std.ArrayListUnmanaged(FieldDef){};
    defer {
        for (custom_fields.items) |field| {
            allocator.free(field.name);
            allocator.free(field.zig_type);
            allocator.free(field.sql_type);
        }
        custom_fields.deinit(allocator);
    }

    if (fields_str) |fs| {
        try parseFields(allocator, fs, &custom_fields);
    }

    // 确定要生成的文件类型
    const gen_all = args.hasFlag("all") or args.hasFlag("a");
    const gen_model = gen_all or args.hasFlag("model") or args.hasFlag("m");
    const gen_dto = gen_all or args.hasFlag("dto") or args.hasFlag("d");
    const gen_controller = gen_all or args.hasFlag("controller") or args.hasFlag("c");

    // 如果没有指定任何类型，默认生成模型
    const should_gen_model = gen_model or (!gen_dto and !gen_controller);
    const should_gen_dto = gen_dto;
    const should_gen_controller = gen_controller;

    Command.showInfo("开始生成代码...");

    // 生成模型
    if (should_gen_model) {
        try generators.generateModel(allocator, name, table_name, custom_fields.items);
    }

    // 生成 DTO
    if (should_gen_dto) {
        try generators.generateDto(allocator, name, custom_fields.items);
    }

    // 生成控制器
    if (should_gen_controller) {
        try generators.generateController(allocator, name);
    }

    Command.showSuccess("代码生成完成！");
}

/// 解析字段定义字符串
fn parseFields(allocator: std.mem.Allocator, fields_str: []const u8, result: *std.ArrayListUnmanaged(FieldDef)) !void {
    var iter = std.mem.splitScalar(u8, fields_str, ',');
    while (iter.next()) |field_def| {
        const trimmed = std.mem.trim(u8, field_def, " ");
        if (trimmed.len == 0) continue;

        var parts = std.mem.splitScalar(u8, trimmed, ':');
        const field_name = parts.next() orelse continue;
        const field_type = parts.next() orelse "string";

        const zig_type = mapType(field_type);
        const sql_type = mapSqlType(field_type);

        try result.append(allocator, .{
            .name = try allocator.dupe(u8, field_name),
            .zig_type = try allocator.dupe(u8, zig_type),
            .sql_type = try allocator.dupe(u8, sql_type),
        });
    }
}

/// 映射类型到 Zig 类型
fn mapType(type_str: []const u8) []const u8 {
    if (std.mem.eql(u8, type_str, "string")) return "[]const u8";
    if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "i32")) return "i32";
    if (std.mem.eql(u8, type_str, "i64") or std.mem.eql(u8, type_str, "bigint")) return "i64";
    if (std.mem.eql(u8, type_str, "f32") or std.mem.eql(u8, type_str, "float")) return "f32";
    if (std.mem.eql(u8, type_str, "f64") or std.mem.eql(u8, type_str, "double")) return "f64";
    if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) return "bool";
    return "[]const u8";
}

/// 映射类型到 SQL 类型
fn mapSqlType(type_str: []const u8) []const u8 {
    if (std.mem.eql(u8, type_str, "string")) return "TEXT";
    if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "i32")) return "INTEGER";
    if (std.mem.eql(u8, type_str, "i64") or std.mem.eql(u8, type_str, "bigint")) return "BIGINT";
    if (std.mem.eql(u8, type_str, "f32") or std.mem.eql(u8, type_str, "float")) return "REAL";
    if (std.mem.eql(u8, type_str, "f64") or std.mem.eql(u8, type_str, "double")) return "REAL";
    if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) return "INTEGER";
    return "TEXT";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try run(gpa.allocator());
}