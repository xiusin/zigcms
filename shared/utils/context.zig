//! 请求上下文工具
//!
//! 提供请求作用域的用户信息存储，用于在请求处理过程中传递认证用户信息。

const std = @import("std");

/// 用户上下文
pub const UserContext = struct {
    user_id: i32 = 0,
    username: []const u8 = "",
    email: []const u8 = "",
    is_authenticated: bool = false,
};

var context: UserContext = .{};
var context_initialized: bool = false;
var context_mutex = std.Thread.Mutex{};

/// 设置当前请求的用户上下文
pub fn setContext(ctx: UserContext) void {
    context_mutex.lock();
    defer context_mutex.unlock();
    context = ctx;
    context_initialized = true;
}

/// 获取当前请求的用户上下文
pub fn getContext() UserContext {
    context_mutex.lock();
    defer context_mutex.unlock();
    if (context_initialized) {
        return context;
    }
    return .{};
}

/// 检查是否有认证用户
pub fn isAuthenticated() bool {
    return getContext().is_authenticated;
}

/// 获取当前用户ID
pub fn getUserId() i32 {
    return getContext().user_id;
}

/// 获取当前用户名
pub fn getUsername() []const u8 {
    return getContext().username;
}

/// 清除上下文（请求结束后调用）
pub fn clearContext() void {
    context_mutex.lock();
    defer context_mutex.unlock();
    context = .{};
    context_initialized = false;
}

/// RAII 风格的上下文管理器
pub const ContextGuard = struct {
    pub fn init(ctx: UserContext) void {
        setContext(ctx);
    }

    pub fn deinit() void {
        clearContext();
    }
};
