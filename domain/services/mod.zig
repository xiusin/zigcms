//! Domain Services Module
//!
//! 领域服务层 - 封装核心业务逻辑
//!
//! 职责：
//! - 实现跨实体的业务规则
//! - 封装复杂的领域逻辑
//! - 不依赖基础设施层
//! - 纯业务逻辑，无副作用

const std = @import("std");

/// 领域服务基类
pub fn DomainService(comptime name: []const u8) type {
    return struct {
        pub const service_name = name;

        /// 验证业务规则
        pub fn validate(self: *@This()) !void {
            _ = self;
            // 子类实现具体验证逻辑
        }
    };
}

// 用户领域服务
pub const UserDomainService = struct {
    const Self = @This();

    /// 验证用户名是否符合规则
    pub fn validateUsername(username: []const u8) !void {
        if (username.len < 3) {
            return error.UsernameTooShort;
        }
        if (username.len > 20) {
            return error.UsernameTooLong;
        }

        // 只允许字母、数字和下划线
        for (username) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                return error.InvalidUsernameCharacter;
            }
        }
    }

    /// 验证密码强度
    pub fn validatePassword(password: []const u8) !void {
        if (password.len < 6) {
            return error.PasswordTooWeak;
        }
        if (password.len > 50) {
            return error.PasswordTooLong;
        }

        // 至少包含一个数字和一个字母
        var has_digit = false;
        var has_alpha = false;

        for (password) |c| {
            if (std.ascii.isDigit(c)) has_digit = true;
            if (std.ascii.isAlphabetic(c)) has_alpha = true;
        }

        if (!has_digit or !has_alpha) {
            return error.PasswordMustContainAlphaAndDigit;
        }
    }

    /// 验证邮箱格式
    pub fn validateEmail(email: []const u8) !void {
        if (email.len == 0) {
            return error.EmailRequired;
        }

        // 简单的邮箱格式验证
        const at_pos = std.mem.indexOf(u8, email, "@") orelse {
            return error.InvalidEmailFormat;
        };

        const dot_pos = std.mem.lastIndexOf(u8, email, ".") orelse {
            return error.InvalidEmailFormat;
        };

        if (at_pos == 0 or dot_pos <= at_pos + 1 or dot_pos == email.len - 1) {
            return error.InvalidEmailFormat;
        }
    }
};

// 内容领域服务
pub const ContentDomainService = struct {
    const Self = @This();

    /// 验证文章标题
    pub fn validateArticleTitle(title: []const u8) !void {
        if (title.len == 0) {
            return error.TitleRequired;
        }
        if (title.len > 200) {
            return error.TitleTooLong;
        }
    }

    /// 验证文章内容
    pub fn validateArticleContent(content: []const u8) !void {
        if (content.len == 0) {
            return error.ContentRequired;
        }
        if (content.len > 100000) {
            return error.ContentTooLong;
        }
    }

    /// 计算文章阅读时长（分钟）
    pub fn calculateReadingTime(content: []const u8) u32 {
        // 假设平均阅读速度为 200 字/分钟
        const words = content.len / 2; // 中文按字符数除以2估算字数
        const minutes = @divTrunc(words, 200);
        return if (minutes == 0) 1 else @intCast(minutes);
    }
};

// 权限领域服务
pub const PermissionDomainService = struct {
    const Self = @This();

    /// 检查用户是否有权限执行操作
    pub fn checkPermission(
        user_roles: []const []const u8,
        required_permission: []const u8,
    ) bool {
        // TODO: 实现权限检查逻辑
        _ = user_roles;
        _ = required_permission;
        return true;
    }

    /// 检查用户是否有任一权限
    pub fn hasAnyPermission(
        user_roles: []const []const u8,
        permissions: []const []const u8,
    ) bool {
        for (permissions) |perm| {
            if (Self.checkPermission(user_roles, perm)) {
                return true;
            }
        }
        return false;
    }
};

// 导出所有领域服务
pub const DomainServices = struct {
    pub const User = UserDomainService;
    pub const Content = ContentDomainService;
    pub const Permission = PermissionDomainService;
};
