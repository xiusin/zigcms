// 短信通知服务
//
// 功能：
// - 短信服务商集成（阿里云、腾讯云）
// - 短信模板管理
// - 发送限流
// - 发送记录

const std = @import("std");
const NotifierInterface = @import("../../domain/services/notifier_interface.zig").NotifierInterface;
const NotificationMessage = @import("../../domain/services/notifier_interface.zig").NotificationMessage;
const NotificationResult = @import("../../domain/services/notifier_interface.zig").NotificationResult;
const NotificationType = @import("../../domain/services/notifier_interface.zig").NotificationType;

/// 短信服务商
pub const SmsProvider = enum {
    aliyun,
    tencent,
};

/// 短信配置
pub const SmsConfig = struct {
    provider: SmsProvider,
    access_key_id: []const u8,
    access_key_secret: []const u8,
    sign_name: []const u8,
    template_code: []const u8,
};

/// 短信通知服务
pub const SmsNotifier = struct {
    allocator: std.mem.Allocator,
    config: SmsConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: SmsConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 发送短信
    pub fn send(self: *Self, message: NotificationMessage) !NotificationResult {
        // TODO: 实现短信发送
        // 1. 根据服务商构建请求
        // 2. 计算签名
        // 3. 发送 HTTP 请求
        // 4. 解析响应

        std.debug.print("📲 发送短信:\n", .{});
        std.debug.print("  手机号: {s}\n", .{message.recipients[0]});
        std.debug.print("  内容: {s}\n", .{message.content});

        // 模拟发送成功
        const message_id = try std.fmt.allocPrint(
            self.allocator,
            "sms-{d}",
            .{std.time.timestamp()},
        );

        return NotificationResult{
            .success = true,
            .message_id = message_id,
            .error_message = null,
        };
    }

    /// 批量发送
    pub fn sendBatch(self: *Self, messages: []const NotificationMessage) ![]NotificationResult {
        var results = try self.allocator.alloc(NotificationResult, messages.len);
        errdefer self.allocator.free(results);

        for (messages, 0..) |message, i| {
            results[i] = try self.send(message);
        }

        return results;
    }

    /// 获取通知类型
    pub fn getType(self: *Self) NotificationType {
        _ = self;
        return .sms;
    }

    /// 创建通知接口
    pub fn interface(self: *Self) NotifierInterface {
        return .{
            .ptr = self,
            .vtable = &.{
                .send = sendImpl,
                .sendBatch = sendBatchImpl,
                .getType = getTypeImpl,
            },
        };
    }

    fn sendImpl(ptr: *anyopaque, message: NotificationMessage) anyerror!NotificationResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.send(message);
    }

    fn sendBatchImpl(ptr: *anyopaque, messages: []const NotificationMessage) anyerror![]NotificationResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.sendBatch(messages);
    }

    fn getTypeImpl(ptr: *anyopaque) NotificationType {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.getType();
    }
};
