// 通知管理器
//
// 统一的通知管理入口，支持多种通知渠道

const std = @import("std");
const NotifierInterface = @import("../../domain/services/notifier_interface.zig").NotifierInterface;
const NotificationMessage = @import("../../domain/services/notifier_interface.zig").NotificationMessage;
const NotificationResult = @import("../../domain/services/notifier_interface.zig").NotificationResult;
const NotificationType = @import("../../domain/services/notifier_interface.zig").NotificationType;

/// 通知管理器
pub const NotificationManager = struct {
    allocator: std.mem.Allocator,
    notifiers: std.AutoHashMap(NotificationType, NotifierInterface),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .notifiers = std.AutoHashMap(NotificationType, NotifierInterface).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.notifiers.deinit();
    }

    /// 注册通知服务
    pub fn register(self: *Self, notifier: NotifierInterface) !void {
        const notifier_type = notifier.getType();
        try self.notifiers.put(notifier_type, notifier);
    }

    /// 发送通知
    pub fn send(
        self: *Self,
        notifier_type: NotificationType,
        message: NotificationMessage,
    ) !NotificationResult {
        const notifier = self.notifiers.get(notifier_type) orelse {
            return error.NotifierNotFound;
        };

        return try notifier.send(message);
    }

    /// 发送到所有渠道
    pub fn sendToAll(
        self: *Self,
        message: NotificationMessage,
    ) ![]NotificationResult {
        var results = std.ArrayList(NotificationResult).init(self.allocator);
        defer results.deinit();

        var it = self.notifiers.valueIterator();
        while (it.next()) |notifier| {
            const result = try notifier.send(message);
            try results.append(result);
        }

        return try results.toOwnedSlice();
    }

    /// 批量发送
    pub fn sendBatch(
        self: *Self,
        notifier_type: NotificationType,
        messages: []const NotificationMessage,
    ) ![]NotificationResult {
        const notifier = self.notifiers.get(notifier_type) orelse {
            return error.NotifierNotFound;
        };

        return try notifier.sendBatch(messages);
    }
};
