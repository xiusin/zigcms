//! 用户领域事件 (User Domain Events)
//!
//! 定义用户聚合相关的所有领域事件

const std = @import("std");
const DomainEvent = @import("../../shared_kernel/patterns/domain_event.zig").DomainEvent;

/// 用户创建事件
pub const UserCreated = DomainEvent(struct {
    user_id: i32,
    username: []const u8,
    email: []const u8,
    created_at: i64,
});

/// 用户更新事件
pub const UserUpdated = DomainEvent(struct {
    user_id: i32,
    field: []const u8,
    old_value: []const u8,
    new_value: []const u8,
    updated_at: i64,
});

/// 用户激活事件
pub const UserActivated = DomainEvent(struct {
    user_id: i32,
    activated_at: i64,
});

/// 用户禁用事件
pub const UserDeactivated = DomainEvent(struct {
    user_id: i32,
    reason: []const u8,
    deactivated_at: i64,
});

/// 用户删除事件
pub const UserDeleted = DomainEvent(struct {
    user_id: i32,
    deleted_at: i64,
});

/// 用户登录事件
pub const UserLoggedIn = DomainEvent(struct {
    user_id: i32,
    login_ip: []const u8,
    login_at: i64,
});

/// 用户登出事件
pub const UserLoggedOut = DomainEvent(struct {
    user_id: i32,
    logout_at: i64,
});

/// 用户密码修改事件
pub const UserPasswordChanged = DomainEvent(struct {
    user_id: i32,
    changed_at: i64,
});

/// 事件类型名称
pub const EventTypeNames = struct {
    pub const USER_CREATED = "user.created";
    pub const USER_UPDATED = "user.updated";
    pub const USER_ACTIVATED = "user.activated";
    pub const USER_DEACTIVATED = "user.deactivated";
    pub const USER_DELETED = "user.deleted";
    pub const USER_LOGGED_IN = "user.logged_in";
    pub const USER_LOGGED_OUT = "user.logged_out";
    pub const USER_PASSWORD_CHANGED = "user.password_changed";
};
