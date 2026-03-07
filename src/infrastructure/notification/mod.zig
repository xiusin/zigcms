//! 通知模块 - 统一导出
//!
//! 本模块提供统一的通知服务接口和实现，支持多种通知渠道：
//! - 邮件通知（SMTP）
//! - 短信通知（阿里云短信）
//! - 钉钉通知（Webhook）
//!
//! ## 使用示例
//!
//! ```zig
//! const notification = @import("infrastructure/notification/mod.zig");
//!
//! // 创建通知管理器
//! var manager = try notification.NotificationManager.init(allocator);
//! defer manager.deinit();
//!
//! // 注册邮件通知器
//! const email_config = notification.EmailConfig{
//!     .smtp_host = "smtp.example.com",
//!     .smtp_port = 587,
//!     .username = "user@example.com",
//!     .password = "password",
//!     .from_address = "noreply@example.com",
//!     .from_name = "System",
//! };
//! const email_notifier = try notification.EmailNotifier.init(allocator, email_config);
//! try manager.registerNotifier("email", email_notifier.asInterface());
//!
//! // 发送通知
//! try manager.send("email", "user@example.com", "Test Subject", "Test Body");
//! ```

const std = @import("std");

// 导出通知接口
pub const NotifierInterface = @import("../../domain/services/notifier_interface.zig").NotifierInterface;

// 导出通知实现
pub const EmailNotifier = @import("email_notifier.zig").EmailNotifier;
pub const EmailConfig = @import("email_notifier.zig").EmailConfig;

pub const SmsNotifier = @import("sms_notifier.zig").SmsNotifier;
pub const SmsConfig = @import("sms_notifier.zig").SmsConfig;

pub const DingTalkNotifier = @import("dingtalk_notifier.zig").DingTalkNotifier;
pub const DingTalkConfig = @import("dingtalk_notifier.zig").DingTalkConfig;
pub const DingTalkMessageType = @import("dingtalk_notifier.zig").MessageType;

// 导出通知管理器
pub const NotificationManager = @import("notification_manager.zig").NotificationManager;

// 导出通知类型
pub const NotificationType = enum {
    email,
    sms,
    dingtalk,
    wechat_work,
};

// 导出通知优先级
pub const NotificationPriority = enum {
    low,
    normal,
    high,
    urgent,
};

// 导出通知消息结构
pub const NotificationMessage = struct {
    recipient: []const u8,
    subject: []const u8,
    body: []const u8,
    priority: NotificationPriority = .normal,
    metadata: ?std.StringHashMap([]const u8) = null,
};

/// 创建默认通知管理器
///
/// 根据环境变量配置自动注册可用的通知渠道。
///
/// ## 环境变量
/// - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`: 邮件配置
/// - `SMS_ACCESS_KEY`, `SMS_ACCESS_SECRET`, `SMS_SIGN_NAME`: 短信配置
/// - `DINGTALK_WEBHOOK`, `DINGTALK_SECRET`: 钉钉配置
///
/// ## 参数
/// - `allocator`: 内存分配器
///
/// ## 返回
/// 返回配置好的通知管理器
pub fn createDefaultManager(allocator: std.mem.Allocator) !*NotificationManager {
    var manager = try allocator.create(NotificationManager);
    errdefer allocator.destroy(manager);
    manager.* = NotificationManager.init(allocator);

    // 尝试注册邮件通知器
    if (std.process.getEnvVarOwned(allocator, "SMTP_HOST")) |smtp_host| {
        defer allocator.free(smtp_host);

        const smtp_port = blk: {
            const port_str = std.process.getEnvVarOwned(allocator, "SMTP_PORT") catch break :blk 587;
            defer allocator.free(port_str);
            break :blk std.fmt.parseInt(u16, port_str, 10) catch 587;
        };

        const smtp_user = std.process.getEnvVarOwned(allocator, "SMTP_USER") catch "";
        defer allocator.free(smtp_user);

        const smtp_password = std.process.getEnvVarOwned(allocator, "SMTP_PASSWORD") catch "";
        defer allocator.free(smtp_password);

        const email_config = EmailConfig{
            .smtp_host = try allocator.dupe(u8, smtp_host),
            .smtp_port = smtp_port,
            .username = try allocator.dupe(u8, smtp_user),
            .password = try allocator.dupe(u8, smtp_password),
            .from_address = try allocator.dupe(u8, smtp_user),
            .from_name = "ZigCMS",
        };

        const email_notifier = try allocator.create(EmailNotifier);
        email_notifier.* = EmailNotifier.init(allocator, email_config);
        try manager.registerNotifier("email", email_notifier.asInterface());

        std.log.info("✅ 邮件通知器已注册", .{});
    } else |_| {
        std.log.info("⚠️  未配置邮件通知器（缺少 SMTP_HOST 环境变量）", .{});
    }

    // 尝试注册短信通知器
    if (std.process.getEnvVarOwned(allocator, "SMS_ACCESS_KEY")) |access_key| {
        defer allocator.free(access_key);

        const access_secret = std.process.getEnvVarOwned(allocator, "SMS_ACCESS_SECRET") catch "";
        defer allocator.free(access_secret);

        const sign_name = std.process.getEnvVarOwned(allocator, "SMS_SIGN_NAME") catch "ZigCMS";
        defer allocator.free(sign_name);

        const sms_config = SmsConfig{
            .access_key_id = try allocator.dupe(u8, access_key),
            .access_key_secret = try allocator.dupe(u8, access_secret),
            .sign_name = try allocator.dupe(u8, sign_name),
            .template_code = "SMS_123456",
        };

        const sms_notifier = try allocator.create(SmsNotifier);
        sms_notifier.* = SmsNotifier.init(allocator, sms_config);
        try manager.registerNotifier("sms", sms_notifier.asInterface());

        std.log.info("✅ 短信通知器已注册", .{});
    } else |_| {
        std.log.info("⚠️  未配置短信通知器（缺少 SMS_ACCESS_KEY 环境变量）", .{});
    }

    // 尝试注册钉钉通知器
    if (std.process.getEnvVarOwned(allocator, "DINGTALK_WEBHOOK")) |webhook| {
        defer allocator.free(webhook);

        const secret = std.process.getEnvVarOwned(allocator, "DINGTALK_SECRET") catch null;
        defer if (secret) |s| allocator.free(s);

        const dingtalk_config = DingTalkConfig{
            .webhook_url = try allocator.dupe(u8, webhook),
            .secret = if (secret) |s| try allocator.dupe(u8, s) else null,
        };

        const dingtalk_notifier = try allocator.create(DingTalkNotifier);
        dingtalk_notifier.* = DingTalkNotifier.init(allocator, dingtalk_config);
        try manager.registerNotifier("dingtalk", dingtalk_notifier.asInterface());

        std.log.info("✅ 钉钉通知器已注册", .{});
    } else |_| {
        std.log.info("⚠️  未配置钉钉通知器（缺少 DINGTALK_WEBHOOK 环境变量）", .{});
    }

    return manager;
}

test "notification module exports" {
    const testing = std.testing;

    // 验证所有导出类型可用
    _ = NotifierInterface;
    _ = EmailNotifier;
    _ = EmailConfig;
    _ = SmsNotifier;
    _ = SmsConfig;
    _ = DingTalkNotifier;
    _ = DingTalkConfig;
    _ = DingTalkMessageType;
    _ = NotificationManager;
    _ = NotificationType;
    _ = NotificationPriority;
    _ = NotificationMessage;

    try testing.expect(true);
}
