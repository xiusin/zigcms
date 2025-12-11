//! 插件代码生成器 - 根据配置自动生成插件代码框架

const std = @import("std");

pub fn main() !void {
    std.debug.print("插件代码生成器\n", .{});
    std.debug.print("================\n\n", .{});
    std.debug.print("用法:\n", .{});
    std.debug.print("  zig build plugin-gen -- --name=<插件名> [选项]\n\n", .{});
    std.debug.print("选项:\n", .{});
    std.debug.print("  --name=<名称>      插件名称（必填）\n", .{});
    std.debug.print("  --desc=<描述>      插件描述\n", .{});
    std.debug.print("  --author=<作者>    作者名称\n", .{});
    std.debug.print("  --caps=<能力>      能力列表: http,middleware,scheduler\n\n", .{});
    std.debug.print("示例:\n", .{});
    std.debug.print("  zig build plugin-gen -- --name=MyPlugin --author=\"张三\"\n", .{});
}
