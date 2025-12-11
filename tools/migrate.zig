//! 数据库迁移工具 - 支持数据库表结构迁移和版本管理

const std = @import("std");

pub fn main() !void {
    std.debug.print("数据库迁移工具\n", .{});
    std.debug.print("================\n\n", .{});
    std.debug.print("用法:\n", .{});
    std.debug.print("  zig build migrate -- <命令> [选项]\n\n", .{});
    std.debug.print("命令:\n", .{});
    std.debug.print("  create <名称>      创建新的迁移文件\n", .{});
    std.debug.print("  up                 执行所有未执行的迁移\n", .{});
    std.debug.print("  down               回滚最近一次迁移\n", .{});
    std.debug.print("  status             查看迁移状态\n\n", .{});
    std.debug.print("示例:\n", .{});
    std.debug.print("  zig build migrate -- create add_users_table\n", .{});
    std.debug.print("  zig build migrate -- up\n", .{});
}
