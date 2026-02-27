//! 命令模式 (Command Pattern)
//!
//! 命令模式封装请求作为对象，从而允许使用不同的请求、队列或日志来参数化其他对象。
//! 在 CQRS 模式中，命令用于改变系统状态的写操作。
//!
//! ## 特性
//! - 命令是不可变的
//! - 命令包含执行所需的所有信息
//! - 命令可以排队、记录和重试

const std = @import("std");

/// 命令元数据
pub const CommandMetadata = struct {
    /// 命令ID（用于幂等性）
    id: []const u8,
    /// 命令类型
    type: []const u8,
    /// 命令创建时间
    created_at: i64,
    /// 命令来源
    source: []const u8,
    /// 用户ID（如果已认证）
    user_id: ?i32 = null,
    /// 关联聚合根ID
    aggregate_id: ?i32 = null,
};

/// 命令结果
pub const CommandResult = struct {
    /// 是否成功
    success: bool,
    /// 结果数据（可选）
    data: ?*anyopaque = null,
    /// 错误信息（如果失败）
    error: ?[]const u8 = null,
    /// 产生的领域事件
    events: std.ArrayListUnmanaged(*anyopaque),
    /// 影响的聚合根版本
    aggregate_version: u32 = 0,
};

/// 命令接口
pub const Command = struct {
    metadata: CommandMetadata,

    pub fn getId(self: *const Command) []const u8 {
        return self.metadata.id;
    }

    pub fn getType(self: *const Command) []const u8 {
        return self.metadata.type;
    }
};

/// 命令处理函数类型
pub fn CommandHandlerFunc(comptime CommandType: type, comptime ResultType: type) type {
    return fn (cmd: CommandType) ResultType;
}

/// 命令处理器接口
pub const CommandHandler = struct {
    allocator: std.mem.Allocator,
    command_type: []const u8,
    handleFn: *const fn (cmd: *anyopaque) CommandResult,

    pub fn init(
        allocator: std.mem.Allocator,
        command_type: []const u8,
        handleFn: *const fn (cmd: *anyopaque) CommandResult,
    ) CommandHandler {
        return .{
            .allocator = allocator,
            .command_type = command_type,
            .handleFn = handleFn,
        };
    }

    pub fn deinit(self: *CommandHandler) void {
        self.allocator.free(self.command_type);
    }
};

/// 命令总线 (Command Bus)
///
/// 负责将命令路由到对应的处理器
pub const CommandBus = struct {
    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(*CommandHandler),
    middleware: std.ArrayListUnmanaged(*const fn (cmd: *anyopaque, next: *const fn (*anyopaque) CommandResult) CommandResult),

    pub fn init(allocator: std.mem.Allocator) CommandBus {
        return .{
            .allocator = allocator,
            .handlers = std.StringHashMap(*CommandHandler).init(allocator),
            .middleware = .{},
        };
    }

    pub fn deinit(self: *CommandBus) void {
        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
            self.allocator.destroy(entry.value_ptr);
        }
        self.handlers.deinit();
        self.middleware.deinit(self.allocator);
    }

    /// 注册命令处理器
    pub fn register(self: *CommandBus, command_type: []const u8, handler: *CommandHandler) !void {
        const key = try self.allocator.dupe(u8, command_type);
        errdefer self.allocator.free(key);

        try self.handlers.put(key, handler);
        std.log.info("Command handler registered for '{s}'", .{command_type});
    }

    /// 发送命令到总线
    pub fn send(self: *CommandBus, cmd: *anyopaque, command_type: []const u8) CommandResult {
        if (self.handlers.get(command_type)) |handler| {
            return handler.handleFn(cmd);
        }
        return CommandResult{
            .success = false,
            .data = null,
            .error = try self.allocator.dupe(u8, "No handler registered for command"),
            .events = .{},
        };
    }

    /// 添加中间件
    pub fn use(self: *CommandBus, middleware: *const fn (cmd: *anyopaque, next: *const fn (*anyopaque) CommandResult) CommandResult) !void {
        try self.middleware.append(self.allocator, middleware);
    }
};

/// 创建简单命令
pub fn createCommand(
    allocator: std.mem.Allocator,
    id: []const u8,
    command_type: []const u8,
    source: []const u8,
) !Command {
    return Command{
        .metadata = CommandMetadata{
            .id = try allocator.dupe(u8, id),
            .type = try allocator.dupe(u8, command_type),
            .created_at = std.time.timestamp(),
            .source = try allocator.dupe(u8, source),
        },
    };
}

/// 释放命令内存
pub fn freeCommand(cmd: *Command, allocator: std.mem.Allocator) void {
    allocator.free(cmd.metadata.id);
    allocator.free(cmd.metadata.type);
    allocator.free(cmd.metadata.source);
}

test "CommandBus - register and send" {
    const allocator = testing.allocator;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    var received = false;

    const handler = try allocator.create(CommandHandler);
    handler.* = CommandHandler.init(allocator, "TestCommand", struct {
        fn handle(cmd: *anyopaque) CommandResult {
            _ = cmd;
            received = true;
            return CommandResult{ .success = true, .events = .{} };
        }
    }.handle);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try bus.register("TestCommand", handler);

    const result = bus.send(undefined, "TestCommand");
    try testing.expect(result.success);
    try testing.expect(received);
}

test "CommandBus - unknown command returns error" {
    const allocator = testing.allocator;

    var bus = CommandBus.init(allocator);
    defer bus.deinit();

    const result = bus.send(undefined, "UnknownCommand");
    try testing.expect(!result.success);
    try testing.expect(result.error != null);
}
