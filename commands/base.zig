//! 命令基类 - 所有命令行工具的基础结构
//!
//! 提供统一的命令行参数解析、帮助信息显示和错误处理机制。
//! 所有命令工具都应基于此模块实现。

const std = @import("std");

/// 命令行参数
pub const CommandArgs = struct {
    allocator: std.mem.Allocator,
    positional: std.ArrayListUnmanaged([]const u8),
    options: std.StringHashMapUnmanaged([]const u8),
    flags: std.StringHashMapUnmanaged(bool),

    pub fn init(allocator: std.mem.Allocator) CommandArgs {
        return .{
            .allocator = allocator,
            .positional = .{},
            .options = .{},
            .flags = .{},
        };
    }

    pub fn deinit(self: *CommandArgs) void {
        self.positional.deinit(self.allocator);
        self.options.deinit(self.allocator);
        self.flags.deinit(self.allocator);
    }

    /// 获取选项值
    pub fn getOption(self: *const CommandArgs, key: []const u8) ?[]const u8 {
        return self.options.get(key);
    }

    /// 获取选项值，如果不存在则返回默认值
    pub fn getOptionOr(self: *const CommandArgs, key: []const u8, default: []const u8) []const u8 {
        return self.options.get(key) orelse default;
    }

    /// 检查标志是否存在
    pub fn hasFlag(self: *const CommandArgs, key: []const u8) bool {
        return self.flags.get(key) orelse false;
    }

    /// 获取第 n 个位置参数
    pub fn getPositional(self: *const CommandArgs, index: usize) ?[]const u8 {
        if (index < self.positional.items.len) {
            return self.positional.items[index];
        }
        return null;
    }
};

/// 命令选项定义
pub const OptionDef = struct {
    name: []const u8,
    short: ?u8 = null,
    description: []const u8,
    required: bool = false,
    default: ?[]const u8 = null,
    is_flag: bool = false,
};

/// 命令基类
pub const Command = struct {
    name: []const u8,
    description: []const u8,
    usage: []const u8,
    options: []const OptionDef,
    examples: []const []const u8,

    /// 显示帮助信息
    pub fn showHelp(self: *const Command) void {
        std.debug.print("{s}\n", .{self.description});
        std.debug.print("==================================================\n\n", .{});

        std.debug.print("用法:\n", .{});
        std.debug.print("  {s}\n\n", .{self.usage});

        if (self.options.len > 0) {
            std.debug.print("选项:\n", .{});
            for (self.options) |opt| {
                if (opt.short) |s| {
                    std.debug.print("  -{c}, --{s}", .{ s, opt.name });
                } else {
                    std.debug.print("      --{s}", .{opt.name});
                }

                if (!opt.is_flag) {
                    std.debug.print("=<值>", .{});
                }

                std.debug.print("\n", .{});
                std.debug.print("        {s}", .{opt.description});

                if (opt.required) {
                    std.debug.print(" (必填)", .{});
                }
                if (opt.default) |d| {
                    std.debug.print(" (默认: {s})", .{d});
                }
                std.debug.print("\n", .{});
            }
            std.debug.print("\n", .{});
        }

        if (self.examples.len > 0) {
            std.debug.print("示例:\n", .{});
            for (self.examples) |example| {
                std.debug.print("  {s}\n", .{example});
            }
        }
    }

    /// 显示错误信息
    pub fn showError(self: *const Command, message: []const u8) void {
        std.debug.print("错误: {s}\n", .{message});
        std.debug.print("使用 '{s} --help' 查看帮助信息\n", .{self.name});
    }

    /// 显示成功信息
    pub fn showSuccess(message: []const u8) void {
        std.debug.print("✓ {s}\n", .{message});
    }

    /// 显示信息
    pub fn showInfo(message: []const u8) void {
        std.debug.print("ℹ {s}\n", .{message});
    }

    /// 显示警告
    pub fn showWarning(message: []const u8) void {
        std.debug.print("⚠ {s}\n", .{message});
    }
};

/// 解析命令行参数
pub fn parseArgs(allocator: std.mem.Allocator, args_iter: anytype) !CommandArgs {
    var result = CommandArgs.init(allocator);
    errdefer result.deinit();

    while (args_iter.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            // 长选项: --name=value 或 --flag
            const option_part = arg[2..];
            if (std.mem.indexOf(u8, option_part, "=")) |eq_pos| {
                const key = option_part[0..eq_pos];
                const value = option_part[eq_pos + 1 ..];
                try result.options.put(allocator, key, value);
            } else {
                // 标志选项
                try result.flags.put(allocator, option_part, true);
            }
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len == 2) {
            // 短选项: -n value 或 -f (标志)
            const key = arg[1..2];
            if (args_iter.next()) |value| {
                if (!std.mem.startsWith(u8, value, "-")) {
                    try result.options.put(allocator, key, value);
                } else {
                    // 是标志，下一个参数是另一个选项
                    try result.flags.put(allocator, key, true);
                }
            } else {
                try result.flags.put(allocator, key, true);
            }
        } else {
            // 位置参数
            try result.positional.append(allocator, arg);
        }
    }

    return result;
}

/// 验证必填选项
pub fn validateRequired(args: *const CommandArgs, options: []const OptionDef) ?[]const u8 {
    for (options) |opt| {
        if (opt.required) {
            if (args.getOption(opt.name) == null) {
                return opt.name;
            }
        }
    }
    return null;
}

/// 写入文件的辅助函数
pub fn writeFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(content);
}

/// 检查文件是否存在
pub fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// 创建目录（如果不存在）
pub fn ensureDir(path: []const u8) !void {
    std.fs.cwd().makePath(path) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };
}
