//! 用户聚合根 (User Aggregate Root)
//!
//! 用户是系统的核心聚合根之一，包含用户的所有业务逻辑和规则。
//! 遵循领域驱动设计原则，封装用户状态变更和领域事件。
//!
//! ## 特性
//! - 聚合根：外部访问用户相关数据的唯一入口
//! - 领域事件：状态变更时会发布领域事件
//! - 业务规则：验证用户名、邮箱等业务规则
//!
//! ## 使用示例
//! ```zig
//! var user = try UserAgg.create(.{
//!     .id = null,
//!     .username = "john_doe",
//!     .email = "john@example.com",
//!     .nickname = "John",
//! }, allocator);
//!
//! // 激活用户（发布 UserActivated 事件）
//! user.activate();
//!
//! // 获取未发布的事件
//! const events = user.getUncommittedEvents();
//! ```

const std = @import("std");
const AggregateRoot = @import("../../shared_kernel/patterns/aggregate_root.zig").AggregateRoot;
const DomainEvent = @import("../../shared_kernel/patterns/domain_event.zig").DomainEvent;
const UserEvents = @import("../events/user_events.zig");

// ============================================================================
// 用户数据结构
// ============================================================================

/// 用户数据结构
pub const UserData = struct {
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
    /// 密码哈希
    password_hash: []const u8 = "",
    /// 状态（0:禁用 1:启用 2:待验证）
    status: UserStatus = .Pending,
    /// 最后登录IP
    last_login_ip: []const u8 = "",
    /// 最后登录时间
    last_login_at: ?i64 = null,
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
};

/// 用户状态枚举
pub const UserStatus = enum(i32) {
    /// 待验证
    Pending = 0,
    /// 激活
    Active = 1,
    /// 禁用
    Inactive = 2,
    /// 已删除
    Deleted = 3,
};

// ============================================================================
// 用户聚合根
// ============================================================================

/// 用户聚合根
pub const UserAgg = AggregateRoot(UserData, UserEvents.UserCreated);

// ============================================================================
// 聚合根实现
// ============================================================================

impl: *UserAgg,

const Self = @This();

/// 初始化
pub fn init(allocator: std.mem.Allocator) !Self {
    const agg = try allocator.create(UserAgg);
    agg.* = try UserAgg.create(std.mem.zeroes(UserData), allocator);
    return Self{ .impl = agg };
}

/// 从数据创建聚合根
pub fn fromData(data: UserData, allocator: std.mem.Allocator) !*UserAgg {
    return try UserAgg.create(data, allocator);
}

/// 从事件重放创建聚合根
pub fn fromEvents(events: []UserEvents.UserCreated, allocator: std.mem.Allocator) !*UserAgg {
    return try UserAgg.fromEvents(events, allocator);
}

/// 获取用户ID
pub fn getId(self: Self) ?i32 {
    return self.impl.data.id;
}

/// 获取用户名
pub fn getUsername(self: Self) []const u8 {
    return self.impl.data.username;
}

/// 获取邮箱
pub fn getEmail(self: Self) []const u8 {
    return self.impl.data.email;
}

/// 获取昵称
pub fn getNickname(self: Self) []const u8 {
    return self.impl.data.nickname;
}

/// 获取头像
pub fn getAvatar(self: Self) []const u8 {
    return self.impl.data.avatar;
}

/// 获取状态
pub fn getStatus(self: Self) UserStatus {
    return self.impl.data.status;
}

/// 检查用户是否激活
pub fn isActive(self: Self) bool {
    return self.impl.data.status == .Active;
}

/// 检查用户是否待验证
pub fn isPending(self: Self) bool {
    return self.impl.data.status == .Pending;
}

/// 检查用户是否已删除
pub fn isDeleted(self: Self) bool {
    return self.impl.data.status == .Deleted;
}

/// 获取显示名称
pub fn getDisplayName(self: Self) []const u8 {
    if (self.impl.data.nickname.len > 0) {
        return self.impl.data.nickname;
    }
    return self.impl.data.username;
}

/// 获取最后登录时间
pub fn getLastLoginAt(self: Self) ?i64 {
    return self.impl.data.last_login_at;
}

/// 获取未发布的领域事件
pub fn getUncommittedEvents(self: *Self) []UserEvents.UserCreated {
    return self.impl.getUncommittedEvents();
}

/// 获取并清空未发布的事件
pub fn drainEvents(self: *Self) std.ArrayList(UserEvents.UserCreated) {
    return self.impl.drainEvents();
}

// ============================================================================
// 业务方法
// ============================================================================

/// 创建新用户
pub fn createUser(
    self: *Self,
    username: []const u8,
    email: []const u8,
    nickname: []const u8,
    password_hash: []const u8,
    allocator: std.mem.Allocator,
) !void {
    // 验证用户名
    try validateUsername(username);

    // 验证邮箱
    try validateEmail(email);

    // 设置数据
    self.impl.data.username = try allocator.dupe(u8, username);
    self.impl.data.email = try allocator.dupe(u8, email);
    self.impl.data.nickname = try allocator.dupe(u8, nickname);
    self.impl.data.password_hash = try allocator.dupe(u8, password_hash);
    self.impl.data.status = .Active;
    self.impl.data.create_time = std.time.timestamp();
    self.impl.data.update_time = std.time.timestamp();

    // 发布用户创建事件
    const event = try UserEvents.UserCreated.create(.{
        .user_id = 0, // 新用户ID为0，后续由仓储分配
        .username = self.impl.data.username,
        .email = self.impl.data.email,
        .created_at = self.impl.data.create_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_CREATED);

    self.impl.publish(event);
}

/// 激活用户
pub fn activate(self: *Self, allocator: std.mem.Allocator) !void {
    if (self.impl.data.status == .Active) {
        return error.UserAlreadyActive;
    }

    self.impl.data.status = .Active;
    self.impl.data.update_time = std.time.timestamp();

    const event = try UserEvents.UserActivated.create(.{
        .user_id = self.impl.data.id orelse 0,
        .activated_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_ACTIVATED);

    self.impl.publish(event);
}

/// 禁用用户
pub fn deactivate(self: *Self, reason: []const u8, allocator: std.mem.Allocator) !void {
    if (self.impl.data.status != .Active) {
        return error.UserNotActive;
    }

    self.impl.data.status = .Inactive;
    self.impl.data.update_time = std.time.timestamp();

    const event = try UserEvents.UserDeactivated.create(.{
        .user_id = self.impl.data.id orelse 0,
        .reason = reason,
        .deactivated_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_DEACTIVATED);

    self.impl.publish(event);
}

/// 更新昵称
pub fn updateNickname(self: *Self, nickname: []const u8, allocator: std.mem.Allocator) !void {
    if (nickname.len == 0 or nickname.len > 50) {
        return error.NicknameInvalid;
    }

    const old_nickname = self.impl.data.nickname;
    self.impl.data.nickname = try allocator.dupe(u8, nickname);
    self.impl.data.update_time = std.time.timestamp();

    if (old_nickname.len > 0) {
        allocator.free(old_nickname);
    }

    const event = try UserEvents.UserUpdated.create(.{
        .user_id = self.impl.data.id orelse 0,
        .field = "nickname",
        .old_value = old_nickname,
        .new_value = nickname,
        .updated_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_UPDATED);

    self.impl.publish(event);
}

/// 更新头像
pub fn updateAvatar(self: *Self, avatar: []const u8, allocator: std.mem.Allocator) !void {
    const old_avatar = self.impl.data.avatar;
    self.impl.data.avatar = try allocator.dupe(u8, avatar);
    self.impl.data.update_time = std.time.timestamp();

    if (old_avatar.len > 0) {
        allocator.free(old_avatar);
    }
}

/// 更新邮箱
pub fn updateEmail(self: *Self, new_email: []const u8, allocator: std.mem.Allocator) !void {
    try validateEmail(new_email);

    const old_email = self.impl.data.email;
    self.impl.data.email = try allocator.dupe(u8, new_email);
    self.impl.data.update_time = std.time.timestamp();

    allocator.free(old_email);

    const event = try UserEvents.UserUpdated.create(.{
        .user_id = self.impl.data.id orelse 0,
        .field = "email",
        .old_value = old_email,
        .new_value = new_email,
        .updated_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_UPDATED);

    self.impl.publish(event);
}

/// 更新密码
pub fn updatePassword(self: *Self, new_password_hash: []const u8, allocator: std.mem.Allocator) !void {
    const old_hash = self.impl.data.password_hash;
    self.impl.data.password_hash = try allocator.dupe(u8, new_password_hash);
    self.impl.data.update_time = std.time.timestamp();

    if (old_hash.len > 0) {
        allocator.free(old_hash);
    }

    const event = try UserEvents.UserPasswordChanged.create(.{
        .user_id = self.impl.data.id orelse 0,
        .changed_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_PASSWORD_CHANGED);

    self.impl.publish(event);
}

/// 记录登录
pub fn recordLogin(self: *Self, ip: []const u8, allocator: std.mem.Allocator) !void {
    const old_ip = self.impl.data.last_login_ip;
    self.impl.data.last_login_ip = try allocator.dupe(u8, ip);
    self.impl.data.last_login_at = std.time.timestamp();
    self.impl.data.update_time = self.impl.data.last_login_at;

    if (old_ip.len > 0) {
        allocator.free(old_ip);
    }

    const event = try UserEvents.UserLoggedIn.create(.{
        .user_id = self.impl.data.id orelse 0,
        .login_ip = ip,
        .login_at = self.impl.data.last_login_at.?,
    }, allocator, UserEvents.EventTypeNames.USER_LOGGED_IN);

    self.impl.publish(event);
}

/// 标记为已删除
pub fn markAsDeleted(self: *Self, allocator: std.mem.Allocator) !void {
    self.impl.data.status = .Deleted;
    self.impl.data.update_time = std.time.timestamp();

    const event = try UserEvents.UserDeleted.create(.{
        .user_id = self.impl.data.id orelse 0,
        .deleted_at = self.impl.data.update_time.?,
    }, allocator, UserEvents.EventTypeNames.USER_DELETED);

    self.impl.publish(event);
}

// ============================================================================
// 事件应用
// ============================================================================

/// 应用用户创建事件
pub fn applyUserCreated(self: *Self, event: UserEvents.UserCreated) !void {
    self.impl.data.id = event.payload.user_id;
    self.impl.data.username = event.payload.username;
    self.impl.data.email = event.payload.email;
    self.impl.data.create_time = event.payload.created_at;
    self.impl.data.update_time = event.payload.created_at;
}

/// 应用用户激活事件
pub fn applyUserActivated(self: *Self, event: UserEvents.UserActivated) !void {
    self.impl.data.status = .Active;
    self.impl.data.update_time = event.payload.activated_at;
}

/// 应用用户禁用事件
pub fn applyUserDeactivated(self: *Self, event: UserEvents.UserDeactivated) !void {
    self.impl.data.status = .Inactive;
    self.impl.data.update_time = event.payload.deactivated_at;
}

/// 应用用户登录事件
pub fn applyUserLoggedIn(self: *Self, event: UserEvents.UserLoggedIn) !void {
    self.impl.data.last_login_ip = event.payload.login_ip;
    self.impl.data.last_login_at = event.payload.login_at;
    self.impl.data.update_time = event.payload.login_at;
}

// ============================================================================
// 验证函数
// ============================================================================

/// 验证用户名
fn validateUsername(username: []const u8) !void {
    if (username.len < 3) return error.UsernameTooShort;
    if (username.len > 20) return error.UsernameTooLong;

    for (username) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return error.InvalidUsernameCharacter;
        }
    }
}

/// 验证邮箱
fn validateEmail(email: []const u8) !void {
    if (email.len == 0) return error.EmailRequired;

    const at_pos = std.mem.indexOf(u8, email, "@") orelse return error.InvalidEmailFormat;
    const dot_pos = std.mem.lastIndexOf(u8, email, ".") orelse return error.InvalidEmailFormat;

    if (at_pos == 0 or dot_pos <= at_pos + 1 or dot_pos == email.len - 1) {
        return error.InvalidEmailFormat;
    }
}

// ============================================================================
// 错误类型
// ============================================================================

pub const UserError = error{
    UsernameTooShort,
    UsernameTooLong,
    InvalidUsernameCharacter,
    EmailRequired,
    InvalidEmailFormat,
    NicknameInvalid,
    UserAlreadyActive,
    UserNotActive,
};

// ============================================================================
// 便利类型别名
// ============================================================================

/// 为了向后兼容，提供 User 类型别名
pub const User = UserAgg;