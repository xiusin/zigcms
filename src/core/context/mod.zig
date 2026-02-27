//! 应用上下文模块 (Context Module)
//!
//! 提供应用上下文管理，替代全局状态，支持显式依赖注入。

const std = @import("std");

/// 应用上下文
pub const AppContext = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    db: ?*anyopaque = null,
    service_manager: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 设置数据库连接
    pub fn setDb(self: *Self, db: *anyopaque) void {
        self.db = db;
    }

    /// 获取数据库连接
    pub fn getDb(self: *Self) ?*anyopaque {
        return self.db;
    }

    /// 设置服务管理器
    pub fn setServiceManager(self: *Self, sm: *anyopaque) void {
        self.service_manager = sm;
    }

    /// 获取服务管理器
    pub fn getServiceManager(self: *Self) ?*anyopaque {
        return self.service_manager;
    }
};

/// 请求上下文
pub const RequestContext = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    request_id: ?[]const u8 = null,
    user_id: ?i64 = null,
    start_time: i64,
    deadline: ?i64 = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .start_time = std.time.timestamp(),
        };
    }

    /// 设置超时时间
    pub fn withTimeout(self: *Self, timeout_ms: u64) *Self {
        self.deadline = self.start_time + @as(i64, @intCast(timeout_ms));
        return self;
    }

    /// 检查是否超时
    pub fn isExpired(self: *const Self) bool {
        if (self.deadline) |d| {
            return std.time.timestamp() > d;
        }
        return false;
    }

    /// 获取剩余时间（毫秒）
    pub fn remainingMs(self: *const Self) ?u64 {
        if (self.deadline) |d| {
            const now = std.time.timestamp();
            if (now >= d) return 0;
            return @intCast(d - now);
        }
        return null;
    }
};
