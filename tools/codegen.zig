//! 代码生成工具 - 根据表结构自动生成模型、控制器、DTO等文件

const std = @import("std");

pub fn main() !void {
    std.debug.print("代码生成工具\n", .{});
    std.debug.print("================\n\n", .{});
    std.debug.print("用法:\n", .{});
    std.debug.print("  zig build codegen -- --name=<模型名> [选项]\n\n", .{});
    std.debug.print("选项:\n", .{});
    std.debug.print("  --name=<名称>      模型名称（必填，如 Article）\n", .{});
    std.debug.print("  --table=<表名>     数据库表名（默认为模型名小写）\n", .{});
    std.debug.print("  --fields=<字段>    字段定义，格式: name:type,name:type\n", .{});
    std.debug.print("  --all              生成所有文件（模型、DTO、控制器）\n\n", .{});
    std.debug.print("示例:\n", .{});
    std.debug.print("  zig build codegen -- --name=Article\n", .{});
    std.debug.print("  zig build codegen -- --name=User --table=users\n", .{});
}
