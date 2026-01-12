const std = @import("std");
const base = @import("../base.zig");
const generators = @import("generators.zig");
const CommandInterface = @import("../command_interface.zig").CommandInterface;

const Command = base.Command;
const CommandArgs = base.CommandArgs;
const OptionDef = base.OptionDef;
const FieldDef = generators.FieldDef;

pub const CodegenCommand = struct {
    const Self = @This();

    command_def: Command,

    pub fn init() Self {
        return .{
            .command_def = Command{
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
            },
        };
    }

    pub fn toInterface(self: *Self) CommandInterface {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .execute = executeImpl,
                .help = helpImpl,
                .getName = getNameImpl,
                .getDescription = getDescriptionImpl,
                .deinit = deinitImpl,
            },
        };
    }

    fn executeImpl(ptr: *anyopaque, allocator: std.mem.Allocator, args: []const []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        var args_list = std.ArrayList([]const u8).init(allocator);
        defer args_list.deinit();
        try args_list.appendSlice(args);

        var iter = std.ArrayListUnmanaged([]const u8).fromOwnedSlice(args_list.toOwnedSlice() catch &[_][]const u8{});
        defer iter.deinit(allocator);

        var parsed_args = try parseArgsFromSlice(allocator, iter.items);
        defer parsed_args.deinit();

        if (parsed_args.hasFlag("help") or parsed_args.hasFlag("h")) {
            self.command_def.showHelp();
            return;
        }

        const name = parsed_args.getOption("name") orelse parsed_args.getOption("n") orelse {
            self.command_def.showError("缺少必填参数: --name");
            return error.MissingRequiredOption;
        };

        const table_name = parsed_args.getOption("table") orelse parsed_args.getOption("t") orelse blk: {
            const snake_name = try generators.toSnakeCase(allocator, name);
            defer allocator.free(snake_name);
            break :blk try allocator.dupe(u8, snake_name);
        };
        defer if (parsed_args.getOption("table") == null and parsed_args.getOption("t") == null) allocator.free(table_name);

        const fields_str = parsed_args.getOption("fields") orelse parsed_args.getOption("f");
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

        const gen_all = parsed_args.hasFlag("all") or parsed_args.hasFlag("a");
        const gen_model = gen_all or parsed_args.hasFlag("model") or parsed_args.hasFlag("m");
        const gen_dto = gen_all or parsed_args.hasFlag("dto") or parsed_args.hasFlag("d");
        const gen_controller = gen_all or parsed_args.hasFlag("controller") or parsed_args.hasFlag("c");

        const should_gen_model = gen_model or (!gen_dto and !gen_controller);
        const should_gen_dto = gen_dto;
        const should_gen_controller = gen_controller;

        Command.showInfo("开始生成代码...");

        if (should_gen_model) {
            try generators.generateModel(allocator, name, table_name, custom_fields.items);
        }

        if (should_gen_dto) {
            try generators.generateDto(allocator, name, custom_fields.items);
        }

        if (should_gen_controller) {
            try generators.generateController(allocator, name);
        }

        Command.showSuccess("代码生成完成！");
    }

    fn helpImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.command_def.showHelp();
    }

    fn getNameImpl(ptr: *anyopaque) []const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.command_def.name;
    }

    fn getDescriptionImpl(ptr: *anyopaque) []const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.command_def.description;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        _ = ptr;
    }
};

fn parseArgsFromSlice(allocator: std.mem.Allocator, args: []const []const u8) !CommandArgs {
    var result = CommandArgs.init(allocator);
    errdefer result.deinit();

    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            const option_part = arg[2..];
            if (std.mem.indexOf(u8, option_part, "=")) |eq_pos| {
                const key = option_part[0..eq_pos];
                const value = option_part[eq_pos + 1 ..];
                try result.options.put(allocator, key, value);
            } else {
                try result.flags.put(allocator, option_part, true);
            }
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            const key = arg[1..];
            try result.flags.put(allocator, key, true);
        } else {
            try result.positional.append(allocator, arg);
        }
    }

    return result;
}

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

fn mapType(type_str: []const u8) []const u8 {
    if (std.mem.eql(u8, type_str, "string")) return "[]const u8";
    if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "i32")) return "i32";
    if (std.mem.eql(u8, type_str, "i64") or std.mem.eql(u8, type_str, "bigint")) return "i64";
    if (std.mem.eql(u8, type_str, "f32") or std.mem.eql(u8, type_str, "float")) return "f32";
    if (std.mem.eql(u8, type_str, "f64") or std.mem.eql(u8, type_str, "double")) return "f64";
    if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) return "bool";
    return "[]const u8";
}

fn mapSqlType(type_str: []const u8) []const u8 {
    if (std.mem.eql(u8, type_str, "string")) return "TEXT";
    if (std.mem.eql(u8, type_str, "int") or std.mem.eql(u8, type_str, "i32")) return "INTEGER";
    if (std.mem.eql(u8, type_str, "i64") or std.mem.eql(u8, type_str, "bigint")) return "BIGINT";
    if (std.mem.eql(u8, type_str, "f32") or std.mem.eql(u8, type_str, "float")) return "REAL";
    if (std.mem.eql(u8, type_str, "f64") or std.mem.eql(u8, type_str, "double")) return "REAL";
    if (std.mem.eql(u8, type_str, "bool") or std.mem.eql(u8, type_str, "boolean")) return "INTEGER";
    return "TEXT";
}
