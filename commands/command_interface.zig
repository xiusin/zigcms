const std = @import("std");

pub const CommandError = error{
    InvalidArguments,
    ExecutionFailed,
    MissingRequiredOption,
    OutOfMemory,
};

pub const CommandInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, args: []const []const u8) anyerror!void,
        help: *const fn (ptr: *anyopaque) void,
        getName: *const fn (ptr: *anyopaque) []const u8,
        getDescription: *const fn (ptr: *anyopaque) []const u8,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn execute(self: @This(), allocator: std.mem.Allocator, args: []const []const u8) !void {
        return self.vtable.execute(self.ptr, allocator, args);
    }

    pub fn help(self: @This()) void {
        return self.vtable.help(self.ptr);
    }

    pub fn getName(self: @This()) []const u8 {
        return self.vtable.getName(self.ptr);
    }

    pub fn getDescription(self: @This()) []const u8 {
        return self.vtable.getDescription(self.ptr);
    }

    pub fn deinit(self: @This()) void {
        return self.vtable.deinit(self.ptr);
    }
};

pub const CommandRegistry = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    commands: std.StringHashMapUnmanaged(CommandInterface),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .commands = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.commands.valueIterator();
        while (iter.next()) |cmd| {
            cmd.deinit();
        }
        self.commands.deinit(self.allocator);
    }

    pub fn register(self: *Self, name: []const u8, cmd: CommandInterface) !void {
        try self.commands.put(self.allocator, name, cmd);
    }

    pub fn get(self: *Self, name: []const u8) ?CommandInterface {
        return self.commands.get(name);
    }

    pub fn list(self: *Self) []const []const u8 {
        var names = std.ArrayList([]const u8).init(self.allocator);
        defer names.deinit();

        var iter = self.commands.keyIterator();
        while (iter.next()) |key| {
            names.append(key.*) catch continue;
        }

        return names.toOwnedSlice() catch &[_][]const u8{};
    }

    pub fn run(self: *Self, name: []const u8, allocator: std.mem.Allocator, args: []const []const u8) !void {
        const cmd = self.get(name) orelse {
            std.debug.print("错误: 未知命令 '{s}'\n", .{name});
            std.debug.print("可用命令:\n", .{});
            var iter = self.commands.iterator();
            while (iter.next()) |entry| {
                const c = entry.value_ptr.*;
                std.debug.print("  {s: <15} - {s}\n", .{ c.getName(), c.getDescription() });
            }
            return CommandError.InvalidArguments;
        };

        try cmd.execute(allocator, args);
    }

    pub fn showHelp(self: *Self, name: []const u8) void {
        const cmd = self.get(name) orelse {
            std.debug.print("错误: 未知命令 '{s}'\n", .{name});
            return;
        };

        cmd.help();
    }

    pub fn showAllCommands(self: *Self) void {
        std.debug.print("ZigCMS 命令行工具\n", .{});
        std.debug.print("==================================================\n\n", .{});
        std.debug.print("可用命令:\n\n", .{});

        var iter = self.commands.iterator();
        while (iter.next()) |entry| {
            const cmd = entry.value_ptr.*;
            std.debug.print("  {s: <15} - {s}\n", .{ cmd.getName(), cmd.getDescription() });
        }

        std.debug.print("\n使用 'zig build <命令> -- --help' 查看命令详细帮助\n", .{});
    }
};
