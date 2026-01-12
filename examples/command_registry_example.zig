const std = @import("std");
const CommandInterface = @import("../commands/command_interface.zig").CommandInterface;
const CommandRegistry = @import("../commands/command_interface.zig").CommandRegistry;
const CodegenCommand = @import("../commands/codegen/command.zig").CodegenCommand;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== ZigCMS 命令行系统演示 ===\n\n", .{});

    var registry = CommandRegistry.init(allocator);
    defer registry.deinit();

    var codegen_cmd = CodegenCommand.init();
    try registry.register("codegen", codegen_cmd.toInterface());

    std.debug.print("✅ 已注册命令:\n", .{});
    registry.showAllCommands();

    std.debug.print("\n=== 测试 codegen 命令帮助 ===\n", .{});
    registry.showHelp("codegen");

    std.debug.print("\n=== 命令系统架构 ===\n", .{});
    std.debug.print("1. CommandInterface (VTable 模式)\n", .{});
    std.debug.print("   - execute(): 执行命令\n", .{});
    std.debug.print("   - help(): 显示帮助\n", .{});
    std.debug.print("   - getName(): 获取命令名\n", .{});
    std.debug.print("   - getDescription(): 获取描述\n", .{});
    std.debug.print("   - deinit(): 清理资源\n\n", .{});

    std.debug.print("2. CommandRegistry\n", .{});
    std.debug.print("   - register(): 注册命令\n", .{});
    std.debug.print("   - get(): 获取命令\n", .{});
    std.debug.print("   - run(): 运行命令\n", .{});
    std.debug.print("   - showHelp(): 显示命令帮助\n", .{});
    std.debug.print("   - showAllCommands(): 显示所有命令\n\n", .{});

    std.debug.print("3. 命令实现 (以 CodegenCommand 为例)\n", .{});
    std.debug.print("   - init(): 初始化命令定义\n", .{});
    std.debug.print("   - toInterface(): 转换为接口\n", .{});
    std.debug.print("   - executeImpl(): 实现执行逻辑\n", .{});
    std.debug.print("   - helpImpl(): 实现帮助显示\n\n", .{});

    std.debug.print("✅ 命令行系统优化完成！\n", .{});
}
