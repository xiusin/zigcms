//! 值对象模块 (Value Objects Module)
//!
//! 导出所有领域值对象

pub const Email = @import("email.zig").Email;
pub const createEmail = @import("email.zig").createEmail;
pub const EmailError = @import("email.zig").EmailError;

pub const Username = @import("username.zig").Username;
pub const createUsername = @import("username.zig").createUsername;
pub const UsernameError = @import("username.zig").UsernameError;
