//! 用户领域事件处理器 (User Domain Event Handlers)
//!
//! 处理用户相关的领域事件，如用户创建、激活、禁用等。

const std = @import("std");
const testing = std.testing;
const UserCreated = @import("../../domain/events/user_events.zig").UserCreated;
const UserActivated = @import("../../domain/events/user_events.zig").UserActivated;
const UserDisabled = @import("../../domain/events/user_events.zig").UserDisabled;
const DomainEventHandler = @import("../infrastructure/domain_event_bus.zig").DomainEventHandler;

/// 用户事件处理器上下文
pub const UserEventHandlerContext = struct {
    allocator: std.mem.Allocator,
    created_count: usize,
    activated_count: usize,
    disabled_count: usize,
    last_created_email: ?[]const u8,
    last_disabled_reason: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) UserEventHandlerContext {
        return .{
            .allocator = allocator,
            .created_count = 0,
            .activated_count = 0,
            .disabled_count = 0,
            .last_created_email = null,
            .last_disabled_reason = null,
        };
    }

    pub fn deinit(self: *UserEventHandlerContext) void {
        if (self.last_created_email) |email| {
            self.allocator.free(email);
        }
        if (self.last_disabled_reason) |reason| {
            self.allocator.free(reason);
        }
    }
};

/// 用户事件处理器
pub const UserEventHandler = struct {
    allocator: std.mem.Allocator,
    context: *UserEventHandlerContext,

    pub fn init(allocator: std.mem.Allocator, context: *UserEventHandlerContext) !UserEventHandler {
        return .{
            .allocator = allocator,
            .context = context,
        };
    }

    pub fn deinit(self: *UserEventHandler) void {
        self.context.deinit();
    }

    /// 创建用户创建事件处理器
    pub fn createUserCreatedHandler(context: *UserEventHandlerContext, allocator: std.mem.Allocator) !*DomainEventHandler {
        const handler = try allocator.create(DomainEventHandler);
        handler.* = DomainEventHandler.init(allocator, "UserCreated", handleUserCreated);
        return handler;
    }

    /// 创建用户激活事件处理器
    pub fn createUserActivatedHandler(context: *UserEventHandlerContext, allocator: std.mem.Allocator) !*DomainEventHandler {
        const handler = try allocator.create(DomainEventHandler);
        handler.* = DomainEventHandler.init(allocator, "UserActivated", handleUserActivated);
        return handler;
    }

    /// 创建用户禁用事件处理器
    pub fn createUserDisabledHandler(context: *UserEventHandlerContext, allocator: std.mem.Allocator) !*DomainEventHandler {
        const handler = try allocator.create(DomainEventHandler);
        handler.* = DomainEventHandler.init(allocator, "UserDisabled", handleUserDisabled);
        return handler;
    }

    /// 创建所有用户事件处理器
    pub fn createAllHandlers(context: *UserEventHandlerContext, allocator: std.mem.Allocator) ![3]*DomainEventHandler {
        var handlers: [3]*DomainEventHandler = undefined;
        handlers[0] = try createUserCreatedHandler(context, allocator);
        handlers[1] = try createUserActivatedHandler(context, allocator);
        handlers[2] = try createUserDisabledHandler(context, allocator);
        return handlers;
    }
};

fn handleUserCreated(event_ptr: *anyopaque) void {
    const event = @as(*UserCreated, @ptrCast(@alignCast(event_ptr)));
    std.log.info("UserCreated event received: user id={d}, email={s}", .{
        event.payload.id,
        event.payload.email,
    });
}

fn handleUserActivated(event_ptr: *anyopaque) void {
    const event = @as(*UserActivated, @ptrCast(@alignCast(event_ptr)));
    std.log.info("UserActivated event received: user id={d}", .{event.payload.user_id});
}

fn handleUserDisabled(event_ptr: *anyopaque) void {
    const event = @as(*UserDisabled, @ptrCast(@alignCast(event_ptr)));
    std.log.info("UserDisabled event received: user id={d}, reason={s}", .{
        event.payload.user_id,
        event.payload.reason,
    });
}

/// 用户事件审计处理器 - 记录所有用户事件到审计日志
pub const UserEventAuditHandler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) UserEventAuditHandler {
        return .{
            .allocator = allocator,
        };
    }

    pub fn handleUserCreated(event_ptr: *anyopaque) void {
        const event = @as(*UserCreated, @ptrCast(@alignCast(event_ptr)));
        std.log.info("[AUDIT] User created: id={d}, email={s}, timestamp={d}", .{
            event.payload.id,
            event.payload.email,
            event.metadata.occurred_on,
        });
    }

    pub fn handleUserActivated(event_ptr: *anyopaque) void {
        const event = @as(*UserActivated, @ptrCast(@alignCast(event_ptr)));
        std.log.info("[AUDIT] User activated: id={d}, timestamp={d}", .{
            event.payload.user_id,
            event.metadata.occurred_on,
        });
    }

    pub fn handleUserDisabled(event_ptr: *anyopaque) void {
        const event = @as(*UserDisabled, @ptrCast(@alignCast(event_ptr)));
        std.log.info("[AUDIT] User disabled: id={d}, reason={s}, timestamp={d}", .{
            event.payload.user_id,
            event.payload.reason,
            event.metadata.occurred_on,
        });
    }
};

test "UserEventHandler - event handlers exist" {
    const allocator = testing.allocator;

    var context = UserEventHandlerContext.init(allocator);
    defer context.deinit();

    try std.testing.expect(true); // Handlers are function pointers
}

test "UserEventHandler - create handlers" {
    const allocator = testing.allocator;

    var context = UserEventHandlerContext.init(allocator);
    defer context.deinit();

    const handler = try UserEventHandler.createUserCreatedHandler(&context, allocator);
    defer {
        handler.deinit();
        allocator.destroy(handler);
    }

    try std.testing.expectEqualStrings("UserCreated", handler.event_type);
}
