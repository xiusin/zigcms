// 通知服务接口
//
// 定义统一的通知接口，支持多种通知渠道（邮件、短信、钉钉、企业微信）

const std = @import("std");

/// 通知类型
pub const NotificationType = enum {
    email,
    sms,
    dingtalk,
    wechat_work,
};

/// 通知优先级
pub const NotificationPriority = enum {
    low,
    normal,
    high,
    urgent,
};

/// 通知消息
pub const NotificationMessage = struct {
    /// 接收者（邮箱、手机号、用户ID等）
    recipients: []const []const u8,
    /// 主题
    subject: []const u8,
    /// 内容
    content: []const u8,
    /// 优先级
    priority: NotificationPriority = .normal,
    /// 附加数据
    metadata: ?std.json.Value = null,
};

/// 通知结果
pub const NotificationResult = struct {
    /// 是否成功
    success: bool,
    /// 消息ID
    message_id: ?[]const u8 = null,
    /// 错误信息
    error_message: ?[]const u8 = null,
};

/// 通知服务接口
pub const NotifierInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        send: *const fn (*anyopaque, NotificationMessage) anyerror!NotificationResult,
        sendBatch: *const fn (*anyopaque, []const NotificationMessage) anyerror![]NotificationResult,
        getType: *const fn (*anyopaque) NotificationType,
    };

    /// 发送通知
    pub fn send(self: *NotifierInterface, message: NotificationMessage) !NotificationResult {
        return self.vtable.send(self.ptr, message);
    }

    /// 批量发送通知
    pub fn sendBatch(self: *NotifierInterface, messages: []const NotificationMessage) ![]NotificationResult {
        return self.vtable.sendBatch(self.ptr, messages);
    }

    /// 获取通知类型
    pub fn getType(self: *NotifierInterface) NotificationType {
        return self.vtable.getType(self.ptr);
    }
};
