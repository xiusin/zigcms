//! 配置结构生成器 - 从 .env 文件生成 Zig 配置结构
//!
//! 本工具用于解析 .env 文件并生成对应的 Zig 配置结构体，
//! 支持类型推断、分段配置和环境变量覆盖。
//!
//! ## 使用方式
//! ```
//! zig build config-gen -- .env ./generated_config.zig
//! zig build config-gen -- --help
//! ```

const std = @import("std");
const base = @import("base.zig");

const Command = base.Command;
const CommandArgs = base.CommandArgs;
const OptionDef = base.OptionDef;

/// 配置生成命令定义
pub const command = Command{
    .name = "config-gen",
    .description = "配置结构生成器 - 从 .env 文件生成 Zig 配置结构",
    .usage = "zig build config-gen -- [输入文件] [输出文件]",
    .options = &[_]OptionDef{
        .{
            .name = "input",
            .short = 'i',
            .description = "输入的 .env 文件路径",
            .default = ".env",
        },
        .{
            .name = "output",
            .short = 'o',
            .description = "输出的 Zig 文件路径",
            .default = "shared/config/generated_config.zig",
        },
        .{
            .name = "help",
            .short = 'h',
            .description = "显示帮助信息",
            .is_flag = true,
        },
    },
    .examples = &[_][]const u8{
        "zig build config-gen                                    # 使用默认路径",
        "zig build config-gen -- .env ./config.zig              # 指定输入输出",
        "zig build config-gen -- --input=.env.prod --output=prod_config.zig",
    },
};

/// 配置变量
const ConfigVariable = struct {
    key: []const u8,
    value: []const u8,
    type_hint: []const u8,
};

/// 解析后的配置
const ParsedConfig = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMapUnmanaged(ConfigVariable),
    sections: std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(ConfigVariable)),

    fn init(allocator: std.mem.Allocator) ParsedConfig {
        return .{
            .allocator = allocator,
            .variables = .{},
            .sections = .{},
        };
    }

    fn deinit(self: *ParsedConfig) void {
        self.variables.deinit(self.allocator);

        var sections_it = self.sections.iterator();
        while (sections_it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.sections.deinit(self.allocator);
    }
};

/// 配置生成器
pub const ConfigGenerator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ConfigGenerator {
        return .{ .allocator = allocator };
    }

    /// 解析 .env 文件并生成配置结构
    pub fn parseEnvAndGenerateConfig(self: *ConfigGenerator, env_file_path: []const u8, output_file_path: []const u8) !void {
        Command.showInfo(try std.fmt.allocPrint(self.allocator, "解析 .env 文件: {s}", .{env_file_path}));

        const env_content = std.fs.cwd().readFileAlloc(self.allocator, env_file_path, 10 * 1024) catch |err| {
            command.showError(try std.fmt.allocPrint(self.allocator, "无法读取文件 {s}: {}", .{ env_file_path, err }));
            return;
        };
        defer self.allocator.free(env_content);

        // 解析环境变量
        var parsed_config = try self.parseEnvContent(env_content);
        defer parsed_config.deinit();

        // 生成 Zig 配置结构
        const config_code = try self.generateConfigStruct(&parsed_config);
        defer self.allocator.free(config_code);

        // 确保输出目录存在
        if (std.mem.lastIndexOf(u8, output_file_path, "/")) |last_slash| {
            const dir_path = output_file_path[0..last_slash];
            try base.ensureDir(dir_path);
        }

        // 写入输出文件
        try base.writeFile(output_file_path, config_code);

        Command.showSuccess(try std.fmt.allocPrint(self.allocator, "配置结构已生成: {s}", .{output_file_path}));
    }

    /// 解析环境内容
    fn parseEnvContent(self: *ConfigGenerator, content: []const u8) !ParsedConfig {
        var result = ParsedConfig.init(self.allocator);
        errdefer result.deinit();

        var current_section: ?[]const u8 = null;
        var current_subconfig = std.StringHashMapUnmanaged(ConfigVariable){};

        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed_line = std.mem.trim(u8, line, " \t\r\n");

            // 跳过空行
            if (trimmed_line.len == 0) {
                continue;
            }

            // 检查分段标记 (# SECTION: xxx)
            if (std.mem.startsWith(u8, trimmed_line, "# SECTION:")) {
                // 保存之前的分段
                if (current_section) |section_name| {
                    try result.sections.put(self.allocator, section_name, current_subconfig);
                    current_subconfig = std.StringHashMapUnmanaged(ConfigVariable){};
                }

                // 开始新分段
                const section_start = std.mem.indexOfScalar(u8, trimmed_line, ':') orelse continue;
                current_section = std.mem.trim(u8, trimmed_line[section_start + 1 ..], " \t");
            }
            // 跳过普通注释
            else if (std.mem.startsWith(u8, trimmed_line, "#")) {
                continue;
            }
            // 解析变量赋值
            else if (std.mem.indexOfScalar(u8, trimmed_line, '=')) |eq_idx| {
                const key = std.mem.trim(u8, trimmed_line[0..eq_idx], " \t");
                var value = std.mem.trim(u8, trimmed_line[eq_idx + 1 ..], " \t");

                // 移除引号
                if ((std.mem.startsWith(u8, value, "\"") and std.mem.endsWith(u8, value, "\"")) or
                    (std.mem.startsWith(u8, value, "'") and std.mem.endsWith(u8, value, "'")))
                {
                    if (value.len >= 2) {
                        value = value[1 .. value.len - 1];
                    }
                }

                const config_var = ConfigVariable{
                    .key = key,
                    .value = value,
                    .type_hint = inferType(value),
                };

                if (current_section != null) {
                    try current_subconfig.put(self.allocator, key, config_var);
                } else {
                    try result.variables.put(self.allocator, key, config_var);
                }
            }
        }

        // 保存最后一个分段
        if (current_section) |section_name| {
            try result.sections.put(self.allocator, section_name, current_subconfig);
        } else {
            current_subconfig.deinit(self.allocator);
        }

        return result;
    }

    /// 生成 Zig 配置结构代码
    fn generateConfigStruct(self: *ConfigGenerator, parsed_config: *ParsedConfig) ![]const u8 {
        var content = std.ArrayListUnmanaged(u8){};
        errdefer content.deinit(self.allocator);

        const writer = content.writer(self.allocator);

        // 写入文件头
        try writer.writeAll(
            \\//! 自动生成的配置结构 - 从 .env 文件生成
            \\//!
            \\//! 警告: 此文件由 config-gen 工具自动生成，请勿手动修改
            \\//! 重新生成: zig build config-gen
            \\
            \\const std = @import("std");
            \\
        );

        // 生成分段配置结构
        var sections_it = parsed_config.sections.iterator();
        while (sections_it.next()) |entry| {
            const section_name = entry.key_ptr.*;
            const section_vars = entry.value_ptr.*;

            const pascal_name = try toPascalCase(self.allocator, section_name);
            defer self.allocator.free(pascal_name);

            try writer.print(
                \\
                \\/// {s} 配置
                \\pub const {s}Config = struct {{
                \\
            , .{ section_name, pascal_name });

            var vars_it = section_vars.iterator();
            while (vars_it.next()) |var_entry| {
                const var_name = var_entry.key_ptr.*;
                const var_info = var_entry.value_ptr.*;

                const snake_name = try toSnakeCaseLower(self.allocator, var_name);
                defer self.allocator.free(snake_name);

                try writer.print("    /// {s} = {s}\n", .{ var_name, var_info.value });
                try writer.print("    {s}: {s} = ", .{ snake_name, var_info.type_hint });

                try writeValue(writer, var_info.type_hint, var_info.value);
                try writer.writeAll(",\n");
            }

            try writer.writeAll("};\n");
        }

        // 生成主配置结构
        try writer.writeAll(
            \\
            \\/// 主配置结构
            \\pub const Config = struct {
            \\
        );

        // 添加分段字段
        sections_it = parsed_config.sections.iterator();
        while (sections_it.next()) |entry| {
            const section_name = entry.key_ptr.*;
            const pascal_name = try toPascalCase(self.allocator, section_name);
            defer self.allocator.free(pascal_name);

            const snake_name = try toSnakeCaseLower(self.allocator, section_name);
            defer self.allocator.free(snake_name);

            try writer.print("    {s}: {s}Config = .{{}},\n", .{ snake_name, pascal_name });
        }

        // 添加根级变量
        var vars_it = parsed_config.variables.iterator();
        while (vars_it.next()) |var_entry| {
            const var_name = var_entry.key_ptr.*;
            const var_info = var_entry.value_ptr.*;

            const snake_name = try toSnakeCaseLower(self.allocator, var_name);
            defer self.allocator.free(snake_name);

            try writer.print("    /// {s} = {s}\n", .{ var_name, var_info.value });
            try writer.print("    {s}: {s} = ", .{ snake_name, var_info.type_hint });

            try writeValue(writer, var_info.type_hint, var_info.value);
            try writer.writeAll(",\n");
        }

        try writer.writeAll(
            \\
            \\    /// 从环境变量加载配置（运行时）
            \\    pub fn loadFromEnvironment(allocator: std.mem.Allocator) !Config {
            \\        _ = allocator;
            \\        // TODO: 实现运行时环境变量加载
            \\        return .{};
            \\    }
            \\};
            \\
        );

        return content.toOwnedSlice(self.allocator);
    }
};

/// 推断类型
fn inferType(value: []const u8) []const u8 {
    // 检查是否为数字
    if (std.fmt.parseInt(i64, value, 10)) |_| {
        return "i32";
    } else |_| {}

    // 检查是否为浮点数
    if (std.fmt.parseFloat(f64, value)) |_| {
        return "f64";
    } else |_| {}

    // 检查是否为布尔值
    if (std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "false")) {
        return "bool";
    }

    // 默认为字符串
    return "[]const u8";
}

/// 写入值
fn writeValue(writer: anytype, type_hint: []const u8, value: []const u8) !void {
    if (std.mem.eql(u8, type_hint, "[]const u8")) {
        try writer.print("\"{s}\"", .{value});
    } else if (std.mem.eql(u8, type_hint, "bool")) {
        if (std.ascii.eqlIgnoreCase(value, "true")) {
            try writer.writeAll("true");
        } else {
            try writer.writeAll("false");
        }
    } else {
        try writer.writeAll(value);
    }
}

/// 转换为 PascalCase
fn toPascalCase(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var capitalize_next = true;

    for (input) |c| {
        if (c == '_' or c == '-' or c == '.') {
            capitalize_next = true;
        } else if (std.ascii.isAlphabetic(c)) {
            if (capitalize_next) {
                try result.append(allocator, std.ascii.toUpper(c));
                capitalize_next = false;
            } else {
                try result.append(allocator, std.ascii.toLower(c));
            }
        } else if (std.ascii.isDigit(c)) {
            try result.append(allocator, c);
            capitalize_next = false;
        }
    }

    return result.toOwnedSlice(allocator);
}

/// 转换为 snake_case (小写)
fn toSnakeCaseLower(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    for (input, 0..) |c, i| {
        if (std.ascii.isUpper(c)) {
            if (i > 0) {
                try result.append(allocator, '_');
            }
            try result.append(allocator, std.ascii.toLower(c));
        } else if (c == '-' or c == '.') {
            try result.append(allocator, '_');
        } else {
            try result.append(allocator, std.ascii.toLower(c));
        }
    }

    return result.toOwnedSlice(allocator);
}

/// 运行配置生成命令
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

    // 获取输入输出路径
    const input_path = args.getOption("input") orelse
        args.getOption("i") orelse
        args.getPositional(0) orelse
        ".env";

    const output_path = args.getOption("output") orelse
        args.getOption("o") orelse
        args.getPositional(1) orelse
        "shared/config/generated_config.zig";

    var generator = ConfigGenerator.init(allocator);
    try generator.parseEnvAndGenerateConfig(input_path, output_path);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try run(gpa.allocator());
}
