//! 用户实体 (User Entity)
//!
//! 领域层用户实体定义，包含用户的基本信息和业务方法。
//! 该实体遵循领域驱动设计原则，封装用户相关的业务规则。

const std = @import("std");

/// 用户实体
pub const User = struct {
    /// 用户ID
    id: ?i32 = null,
    /// 用户名
    username: []const u8 = "",
    /// 邮箱
    email: []const u8 = "",
    /// 昵称
    nickname: []const u8 = "",
    /// 头像URL
    avatar: []const u8 = "",
    /// 状态（0:禁用 1:启用）
    status: i32 = 1,
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,

    /// 创建新用户
    pub fn create(username: []const u8, email: []const u8, nickname: []const u8) User {
        const now = std.time.timestamp();
        return .{
            .username = username,
            .email = email,
            .nickname = nickname,
            .status = 1,
            .create_time = now,
            .update_time = now,
        };
    }

    /// 更新用户信息
    pub fn update(self: *User, nickname: ?[]const u8, avatar: ?[]const u8) void {
        const now = std.time.timestamp();

        if (nickname) |nick| {
            self.nickname = nick;
        }
        if (avatar) |ava| {
            self.avatar = ava;
        }
        self.update_time = now;
    }

    /// 启用用户
    pub fn enable(self: *User) void {
        self.status = 1;
        self.update_time = std.time.timestamp();
    }

    /// 禁用用户
    pub fn disable(self: *User) void {
        self.status = 0;
        self.update_time = std.time.timestamp();
    }

    /// 检查用户是否启用
    pub fn isActive(self: User) bool {
        return self.status == 1;
    }

    /// 验证邮箱格式（简单的业务规则）
    pub fn isValidEmail(_: User, email: []const u8) bool {
        // 简单的邮箱格式验证
        const at_index = std.mem.indexOf(u8, email, "@");
        const dot_index = std.mem.lastIndexOf(u8, email, ".");

        if (at_index == null or dot_index == null) return false;
        return at_index.? < dot_index.? and at_index.? > 0 and dot_index.? < email.len - 1;
    }

    /// 获取用户显示名称
    pub fn getDisplayName(self: User) []const u8 {
        if (self.nickname.len > 0) {
            return self.nickname;
        }
        return self.username;
    }

    /// 释放用户资源
    pub fn deinit(self: *User, allocator: std.mem.Allocator) void {
        if (self.username.len > 0) allocator.free(self.username);
        if (self.email.len > 0) allocator.free(self.email);
        if (self.nickname.len > 0) allocator.free(self.nickname);
        if (self.avatar.len > 0) allocator.free(self.avatar);
    }
};
