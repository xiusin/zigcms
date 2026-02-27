//! 领域事件模块 (Domain Events Module)
//!
//! 导出所有领域事件

pub const user_events = @import("user_events.zig");

pub const UserCreated = user_events.UserCreated;
pub const UserUpdated = user_events.UserUpdated;
pub const UserActivated = user_events.UserActivated;
pub const UserDeactivated = user_events.UserDeactivated;
pub const UserDeleted = user_events.UserDeleted;
pub const UserLoggedIn = user_events.UserLoggedIn;
pub const UserLoggedOut = user_events.UserLoggedOut;
pub const UserPasswordChanged = user_events.UserPasswordChanged;
pub const EventTypeNames = user_events.EventTypeNames;
