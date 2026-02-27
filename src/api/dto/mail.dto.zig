//! 邮件数据传输对象

const std = @import("std");

/// 邮件 DTO
pub const MailDto = struct {
    to: []const u8 = "",
    subject: []const u8 = "",
    body: []const u8 = "",
    html: bool = false,
    cc: []const u8 = "",
    bcc: []const u8 = "",
    attachments: []const []const u8 = &[_][]const u8{},
};
