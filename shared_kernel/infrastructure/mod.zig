//! 共享内核基础设施 (Shared Kernel Infrastructure)
//!
//! 共享内核依赖的外部服务实现，如事件发布、消息总线等。
//! 这些服务被设计为可替换的实现。

const std = @import("std");

// ============================================================================
// 事件发布器 (Event Publisher)
// ============================================================================

/// 领域事件发布器接口
pub const DomainEventPublisher = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        publish: *const fn (*anyopaque, anyopaque) anyerror!void,
        publishSync: *const fn (*anyopaque, anyopaque) anyerror!void,
        subscribe: *const fn (*anyopaque, type, *const fn (anyopaque) void) anyerror!void,
    };

    pub fn publish(self: Self, event: anyopaque) !void {
        return self.vtable.publish(self.ptr, event);
    }

    pub fn publishSync(self: Self, event: anyopaque) !void {
        return self.vtable.publishSync(self.ptr, event);
    }

    pub fn subscribe(self: Self, comptime EventType: type, handler: *const fn (anyopaque) void) !void {
        return self.vtable.subscribe(self.ptr, EventType, handler);
    }
};

// ============================================================================
// 消息总线 (Message Bus)
// ============================================================================

/// 消息总线
pub const MessageBus = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(std.ArrayList(*const fn (anyopaque) void)),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .handlers = std.StringHashMap(std.ArrayList(*const fn (anyopaque) void)).init(allocator),
        };
    }

    pub fn registerHandler(self: *Self, message_type: []const u8, handler: *const fn (anyopaque) void) !void {
        if (self.handlers.get(message_type)) |list| {
            try list.append(handler);
        } else {
            var new_list = std.ArrayList(*const fn (anyopaque) void).init(self.allocator);
            try new_list.append(handler);
            try self.handlers.put(message_type, new_list);
        }
    }

    pub fn send(self: *Self, message_type: []const u8, message: anyopaque) !void {
        if (self.handlers.get(message_type)) |list| {
            for (list.items) |handler| {
                handler(message);
            }
        }
    }

    pub fn deinit(self: *Self) void {
        var it = self.handlers.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        self.handlers.deinit();
    }
};

// ============================================================================
// 领域事件存储 (Event Store)
// ============================================================================

/// 领域事件存储接口
pub const EventStore = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        append: *const fn (*anyopaque, []const u8, anyopaque, i64, u32) anyerror!void,
        getEvents: *const fn (*anyopaque, []const u8, ?u32) anyerror![]anyopaque,
        getEventsSince: *const fn (*anyopaque, []const u8, i64) anyerror![]anyopaque,
    };

    pub fn append(self: Self, aggregate_id: []const u8, event: anyopaque, occurred_on: i64, version: u32) !void {
        return self.vtable.append(self.ptr, aggregate_id, event, occurred_on, version);
    }

    pub fn getEvents(self: Self, aggregate_id: []const u8, from_version: ?u32) ![]anyopaque {
        return self.vtable.getEvents(self.ptr, aggregate_id, from_version);
    }

    pub fn getEventsSince(self: Self, aggregate_id: []const u8, since: i64) ![]anyopaque {
        return self.vtable.getEventsSince(self.ptr, aggregate_id, since);
    }
};

// ============================================================================
// 查询总线 (Query Bus)
// ============================================================================

/// 查询总线接口
pub const QueryBus = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(*const fn (*anyopaque, anyopaque) anyerror!anyopaque),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .handlers = std.StringHashMap(*const fn (*anyopaque, anyopaque) anyerror!anyopaque).init(allocator),
        };
    }

    pub fn registerHandler(self: *Self, query_type: []const u8, handler: *const fn (*anyopaque, anyopaque) anyerror!anyopaque) !void {
        try self.handlers.put(query_type, handler);
    }

    pub fn execute(self: *Self, query_type: []const u8, query: anyopaque) !anyopaque {
        const handler = self.handlers.get(query_type) orelse return error.QueryHandlerNotFound;
        return handler(undefined, query);
    }

    pub fn deinit(self: *Self) void {
        self.handlers.deinit();
    }
};

// ============================================================================
// 命令总线 (Command Bus)
// ============================================================================

/// 命令总线接口
pub const CommandBus = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    handlers: std.StringHashMap(*const fn (*anyopaque, anyopaque) anyerror!void),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .handlers = std.StringHashMap(*const fn (*anyopaque, anyopaque) anyerror!void).init(allocator),
        };
    }

    pub fn registerHandler(self: *Self, command_type: []const u8, handler: *const fn (*anyopaque, anyopaque) anyerror!void) !void {
        try self.handlers.put(command_type, handler);
    }

    pub fn execute(self: *Self, command_type: []const u8, command: anyopaque) !void {
        const handler = self.handlers.get(command_type) orelse return error.CommandHandlerNotFound;
        return handler(undefined, command);
    }

    pub fn deinit(self: *Self) void {
        self.handlers.deinit();
    }
};

// ============================================================================
// 投影 (Projection)
// ============================================================================

/// 投影接口
pub const Projection = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        apply: *const fn (*anyopaque, anyopaque) anyerror!void,
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
        getState: *const fn (*anyopaque, []const u8) anyerror!?anyopaque,
    };

    pub fn apply(self: Self, event: anyopaque) !void {
        return self.vtable.apply(self.ptr, event);
    }

    pub fn delete(self: Self, id: []const u8) !void {
        return self.vtable.delete(self.ptr, id);
    }

    pub fn getState(self: Self, id: []const u8) !?anyopaque {
        return self.vtable.getState(self.ptr, id);
    }
};

// ============================================================================
// 读模型仓储 (Read Model Repository)
// ============================================================================

/// 读模型仓储接口
pub const ReadModelRepository = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        findById: *const fn (*anyopaque, []const u8) anyerror!?anyopaque,
        findBy: *const fn (*anyopaque, []const []const u8, []const std.json.Value) anyerror![]anyopaque,
        save: *const fn (*anyopaque, []const u8, anyopaque) anyerror!void,
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
    };

    pub fn findById(self: Self, id: []const u8) !?anyopaque {
        return self.vtable.findById(self.ptr, id);
    }

    pub fn findBy(self: Self, fields: []const []const u8, values: []const std.json.Value) ![]anyopaque {
        return self.vtable.findBy(self.ptr, fields, values);
    }

    pub fn save(self: Self, id: []const u8, read_model: anyopaque) !void {
        return self.vtable.save(self.ptr, id, read_model);
    }

    pub fn delete(self: Self, id: []const u8) !void {
        return self.vtable.delete(self.ptr, id);
    }
};
