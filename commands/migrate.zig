//! 数据库迁移工具 - 支持数据库表结构迁移和版本管理
//!
//! 本工具用于管理数据库架构的版本控制，支持创建、执行和回滚迁移。
//!
//! ## 使用方式
//! ```
//! zig build migrate -- up              # 执行所有未执行的迁移
//! zig build migrate -- down            # 回滚最近一次迁移
//! zig build migrate -- status          # 查看迁移状态
//! zig build migrate -- create add_users_table  # 创建新迁移文件
//! zig build migrate -- --help          # 显示帮助
//! ```

const std = @import("std");
const base = @import("base.zig");

const Command = base.Command;
const CommandArgs = base.CommandArgs;
const OptionDef = base.OptionDef;

/// 迁移命令定义
pub const command = Command{
    .name = "migrate",
    .description = "数据库迁移工具 - 支持数据库表结构迁移和版本管理",
    .usage = "zig build migrate -- <命令> [选项]",
    .options = &[_]OptionDef{
        .{
            .name = "help",
            .short = 'h',
            .description = "显示帮助信息",
            .is_flag = true,
        },
        .{
            .name = "force",
            .short = 'f',
            .description = "强制执行（跳过确认）",
            .is_flag = true,
        },
        .{
            .name = "step",
            .short = 's',
            .description = "指定迁移步数（用于 down 命令）",
            .default = "1",
        },
        .{
            .name = "db",
            .short = 'd',
            .description = "数据库文件路径",
            .default = "zigcms.db",
        },
    },
    .examples = &[_][]const u8{
        "zig build migrate -- up                    # 执行所有未执行的迁移",
        "zig build migrate -- down                  # 回滚最近一次迁移",
        "zig build migrate -- down --step=3        # 回滚最近3次迁移",
        "zig build migrate -- status               # 查看迁移状态",
        "zig build migrate -- create add_users_table  # 创建新迁移文件",
        "zig build migrate -- refresh              # 回滚所有并重新执行",
    },
};

/// 迁移记录
const MigrationRecord = struct {
    id: i32,
    name: []const u8,
    batch: i32,
    executed_at: i64,
};

/// 运行迁移命令
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

    // 获取子命令
    const sub_command = args.getPositional(0) orelse {
        showSubcommandHelp();
        return;
    };

    // 获取数据库路径
    const db_path = args.getOptionOr("db", "zigcms.db");
    _ = db_path;

    // 执行子命令
    if (std.mem.eql(u8, sub_command, "up")) {
        try runUp(allocator);
    } else if (std.mem.eql(u8, sub_command, "down")) {
        const step_str = args.getOptionOr("step", "1");
        const step = std.fmt.parseInt(u32, step_str, 10) catch 1;
        try runDown(allocator, step);
    } else if (std.mem.eql(u8, sub_command, "status")) {
        try runStatus(allocator);
    } else if (std.mem.eql(u8, sub_command, "create")) {
        const name = args.getPositional(1) orelse {
            command.showError("create 命令需要指定迁移名称");
            return;
        };
        try runCreate(allocator, name);
    } else if (std.mem.eql(u8, sub_command, "refresh")) {
        try runRefresh(allocator);
    } else {
        const error_msg = try std.fmt.allocPrint(allocator, "未知命令: {s}", .{sub_command});
        defer allocator.free(error_msg);
        command.showError(error_msg);
        showSubcommandHelp();
    }
}

/// 显示子命令帮助
fn showSubcommandHelp() void {
    std.debug.print(
        \\可用命令:
        \\  up        执行所有未执行的迁移
        \\  down      回滚最近一次迁移
        \\  status    查看迁移状态
        \\  create    创建新的迁移文件
        \\  refresh   回滚所有并重新执行
        \\
        \\使用 'zig build migrate -- --help' 查看详细帮助
        \\
    , .{});
}

/// 执行迁移 (up)
fn runUp(allocator: std.mem.Allocator) !void {
    Command.showInfo("执行数据库迁移...");

    // 确保迁移目录存在
    try base.ensureDir("migrations");

    // 获取待执行的迁移文件
    var migrations_dir = std.fs.cwd().openDir("migrations", .{ .iterate = true }) catch {
        Command.showInfo("迁移目录为空，无需执行");
        return;
    };
    defer migrations_dir.close();

    var count: u32 = 0;
    var iter = migrations_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".sql")) {
            // TODO: 检查是否已执行，执行迁移
            const info_msg = try std.fmt.allocPrint(allocator, "发现迁移文件: {s}", .{entry.name});
            defer allocator.free(info_msg);
            Command.showInfo(info_msg);
            count += 1;
        }
    }

    if (count == 0) {
        Command.showInfo("没有待执行的迁移");
    } else {
        const success_msg = try std.fmt.allocPrint(allocator, "发现 {d} 个迁移文件", .{count});
        defer allocator.free(success_msg);
        Command.showSuccess(success_msg);
        Command.showWarning("注意: 实际迁移执行需要数据库连接，当前仅扫描文件");
    }
}

/// 回滚迁移 (down)
fn runDown(allocator: std.mem.Allocator, step: u32) !void {
    const info_msg = try std.fmt.allocPrint(allocator, "回滚最近 {d} 次迁移...", .{step});
    defer allocator.free(info_msg);
    Command.showInfo(info_msg);

    // TODO: 实现实际的回滚逻辑
    Command.showWarning("注意: 实际回滚执行需要数据库连接");
}

/// 查看迁移状态 (status)
fn runStatus(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("\n迁移状态\n", .{});
    std.debug.print("==================================================\n\n", .{});

    // 确保迁移目录存在
    try base.ensureDir("migrations");

    var migrations_dir = std.fs.cwd().openDir("migrations", .{ .iterate = true }) catch {
        std.debug.print("迁移目录为空\n", .{});
        return;
    };
    defer migrations_dir.close();

    std.debug.print("{s:<40} {s:<10}\n", .{ "迁移文件", "状态" });
    std.debug.print("--------------------------------------------------\n", .{});

    var iter = migrations_dir.iterate();
    var has_files = false;
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".sql")) {
            has_files = true;
            // TODO: 检查实际执行状态
            std.debug.print("{s:<40} {s:<10}\n", .{ entry.name, "待执行" });
        }
    }

    if (!has_files) {
        std.debug.print("没有迁移文件\n", .{});
    }

    std.debug.print("\n", .{});
}

/// 创建新迁移文件 (create)
fn runCreate(allocator: std.mem.Allocator, name: []const u8) !void {
    // 确保迁移目录存在
    try base.ensureDir("migrations");

    // 生成时间戳
    const timestamp = std.time.timestamp();

    // 生成文件名
    const filename = try std.fmt.allocPrint(allocator, "migrations/{d}_{s}.sql", .{ timestamp, name });
    defer allocator.free(filename);

    // 检查文件是否已存在
    if (base.fileExists(filename)) {
        command.showError("迁移文件已存在");
        return;
    }

    // 生成迁移模板
    const template = try std.fmt.allocPrint(allocator,
        \\-- 迁移: {s}
        \\-- 创建时间: {d}
        \\
        \\-- ========================================
        \\-- UP: 执行迁移
        \\-- ========================================
        \\
        \\-- 在此添加创建表、添加列等 SQL 语句
        \\-- 例如:
        \\-- CREATE TABLE IF NOT EXISTS {s} (
        \\--     id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\--     created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        \\--     updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        \\-- );
        \\
        \\-- ========================================
        \\-- DOWN: 回滚迁移
        \\-- ========================================
        \\
        \\-- 在此添加删除表、删除列等 SQL 语句
        \\-- 例如:
        \\-- DROP TABLE IF EXISTS {s};
        \\
    , .{ name, timestamp, name, name });
    defer allocator.free(template);

    try base.writeFile(filename, template);
    
    const success_msg = try std.fmt.allocPrint(allocator, "创建迁移文件: {s}", .{filename});
    defer allocator.free(success_msg);
    Command.showSuccess(success_msg);
}

/// 刷新迁移 (refresh)
fn runRefresh(allocator: std.mem.Allocator) !void {
    Command.showInfo("刷新数据库迁移（回滚所有并重新执行）...");

    // 先回滚所有
    try runDown(allocator, 999);

    // 再执行所有
    try runUp(allocator);

    Command.showSuccess("数据库迁移刷新完成");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try run(gpa.allocator());
}
