//! Request Context - 请求级别上下文（类似 Go 的 context.Context）
//!
//! 提供请求范围的生命周期管理，包括：
//! - 超时控制（WithTimeout）
//! - 取消信号（WithCancel）
//! - 截止时间（WithDeadline）
//! - 值传递（WithValue）
//!
//! ## 设计理念
//! 借鉴 Go 的 context 包，提供请求级别的控制：
//! - 每个 HTTP 请求创建一个 RequestContext
//! - 支持超时自动取消
//! - 支持手动取消操作
//! - 支持请求范围的值存储
//!
//! ## 使用示例
//! ```zig
//! // 创建带超时的上下文
//! var ctx = try RequestContext.withTimeout(allocator, app_context, 5000); // 5秒超时
//! defer ctx.deinit();
//!
//! // 检查是否已取消
//! if (ctx.isDone()) {
//!     return error.RequestTimeout;
//! }
//!
//! // 执行操作
//! const result = try ctx.doWork();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const AppContext = @import("app_context.zig").AppContext;

/// 取消原因
pub const CancelReason = enum {
    timeout,       // 超时
    cancelled,     // 手动取消
    deadline,      // 到达截止时间
    none,          // 未取消
};

/// 请求上下文 - 类似 Go 的 context.Context
///
/// 职责：
/// - 管理请求生命周期
/// - 提供超时和取消机制
/// - 存储请求范围的值
/// - 关联应用上下文
pub const RequestContext = struct {
    allocator: Allocator,
    app: *AppContext,
    deadline: ?i64,           // 截止时间戳（毫秒）
    cancel_fn: ?*const fn () void,
    cancelled: std.atomic.Value(bool),
    cancel_reason: std.atomic.Value(CancelReason),
    values: std.StringHashMap([]const u8),
    
    const Self = @This();
    
    /// 创建基础请求上下文
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - app_context: 应用上下文（关联全局资源）
    ///
    /// 返回：RequestContext 实例（调用者必须调用 deinit）
    pub fn init(allocator: Allocator, app_context: *AppContext) !Self {
        return .{
            .allocator = allocator,
            .app = app_context,
            .deadline = null,
            .cancel_fn = null,
            .cancelled = std.atomic.Value(bool).init(false),
            .cancel_reason = std.atomic.Value(CancelReason).init(.none),
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }
    
    /// 创建带超时的请求上下文（类似 Go 的 context.WithTimeout）
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - app_context: 应用上下文
    /// - timeout_ms: 超时时间（毫秒）
    ///
    /// 返回：带超时的 RequestContext
    ///
    /// 示例：
    /// ```zig
    /// var ctx = try RequestContext.withTimeout(allocator, app_ctx, 5000);
    /// defer ctx.deinit();
    /// 
    /// // 5 秒后自动超时
    /// if (ctx.isDone()) {
    ///     std.debug.print("Request timeout: {}\n", .{ctx.err()});
    /// }
    /// ```
    pub fn withTimeout(allocator: Allocator, app_context: *AppContext, timeout_ms: u64) !Self {
        const now = std.time.milliTimestamp();
        const deadline = now + @as(i64, @intCast(timeout_ms));
        
        var ctx = try Self.init(allocator, app_context);
        ctx.deadline = deadline;
        
        return ctx;
    }
    
    /// 创建带截止时间的请求上下文（类似 Go 的 context.WithDeadline）
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - app_context: 应用上下文
    /// - deadline: 截止时间戳（毫秒）
    ///
    /// 返回：带截止时间的 RequestContext
    pub fn withDeadline(allocator: Allocator, app_context: *AppContext, deadline: i64) !Self {
        var ctx = try Self.init(allocator, app_context);
        ctx.deadline = deadline;
        return ctx;
    }
    
    /// 创建可取消的请求上下文（类似 Go 的 context.WithCancel）
    ///
    /// 参数：
    /// - allocator: 内存分配器
    /// - app_context: 应用上下文
    ///
    /// 返回：可手动取消的 RequestContext
    ///
    /// 示例：
    /// ```zig
    /// var ctx = try RequestContext.withCancel(allocator, app_ctx);
    /// defer ctx.deinit();
    /// 
    /// // 手动取消
    /// ctx.cancel();
    /// ```
    pub fn withCancel(allocator: Allocator, app_context: *AppContext) !Self {
        return Self.init(allocator, app_context);
    }
    
    /// 检查上下文是否已完成（超时或取消）
    ///
    /// 返回：
    /// - true: 已完成（应停止操作）
    /// - false: 仍在进行
    pub fn isDone(self: *const Self) bool {
        // 检查手动取消
        if (self.cancelled.load(.acquire)) {
            return true;
        }
        
        // 检查超时
        if (self.deadline) |dl| {
            const now = std.time.milliTimestamp();
            if (now >= dl) {
                // 原子设置超时原因
                _ = self.cancel_reason.cmpxchgStrong(.none, .timeout, .release, .acquire);
                return true;
            }
        }
        
        return false;
    }
    
    /// 获取取消错误
    ///
    /// 返回：
    /// - error.RequestTimeout: 请求超时
    /// - error.RequestCancelled: 请求被取消
    /// - error.DeadlineExceeded: 超过截止时间
    /// - null: 未取消
    pub fn err(self: *const Self) ?anyerror {
        if (!self.isDone()) return null;
        
        return switch (self.cancel_reason.load(.acquire)) {
            .timeout => error.RequestTimeout,
            .cancelled => error.RequestCancelled,
            .deadline => error.DeadlineExceeded,
            .none => null,
        };
    }
    
    /// 手动取消上下文
    ///
    /// 调用后，isDone() 将返回 true，err() 返回 RequestCancelled
    pub fn cancel(self: *Self) void {
        self.cancelled.store(true, .release);
        _ = self.cancel_reason.cmpxchgStrong(.none, .cancelled, .release, .acquire);
        
        if (self.cancel_fn) |cancel_callback| {
            cancel_callback();
        }
    }
    
    /// 获取剩余时间（毫秒）
    ///
    /// 返回：
    /// - 剩余毫秒数
    /// - null: 无截止时间
    /// - 0 或负数: 已超时
    pub fn remaining(self: *const Self) ?i64 {
        const dl = self.deadline orelse return null;
        const now = std.time.milliTimestamp();
        return dl - now;
    }
    
    /// 设置请求范围的值
    ///
    /// 参数：
    /// - key: 键
    /// - value: 值（字符串）
    ///
    /// 注意：值会被复制存储
    pub fn setValue(self: *Self, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);
        
        // 如果键已存在，释放旧值
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        
        try self.values.put(key_copy, value_copy);
    }
    
    /// 获取请求范围的值
    ///
    /// 参数：
    /// - key: 键
    ///
    /// 返回：
    /// - 值（借用引用，不可释放）
    /// - null: 键不存在
    pub fn getValue(self: *const Self, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }
    
    /// 获取应用上下文
    ///
    /// 返回：关联的 AppContext（借用引用）
    pub fn getAppContext(self: *const Self) *AppContext {
        return self.app;
    }
    
    /// 获取数据库连接（便捷方法）
    pub fn getDatabase(self: *const Self) @import("../../application/services/sql/mod.zig").Database {
        return self.app.getDatabase().*;
    }
    
    /// 获取缓存服务（便捷方法）
    pub fn getCache(self: *const Self) !@import("../../application/services/cache/contract.zig").CacheInterface {
        return self.app.getCache();
    }
    
    /// 释放资源
    pub fn deinit(self: *Self) void {
        // 释放所有键值对
        var it = self.values.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }
};

// ============================================================================
// 使用示例
// ============================================================================

// 示例：带超时的数据库查询
//
// ```zig
// fn queryWithTimeout(ctx: *RequestContext) ![]User {
//     const db = ctx.getDatabase();
//     
//     // 执行查询前检查超时
//     if (ctx.isDone()) return ctx.err().?;
//     
//     const users = try User.all(db);
//     
//     // 长时间操作中定期检查
//     for (users) |user| {
//         if (ctx.isDone()) {
//             User.freeModels(db.allocator, users);
//             return ctx.err().?;
//         }
//         // 处理用户...
//     }
//     
//     return users;
// }
// ```

// 示例：手动取消
//
// ```zig
// fn cancellableOperation(ctx: *RequestContext) !void {
//     var i: usize = 0;
//     while (i < 1000) : (i += 1) {
//         // 定期检查取消状态
//         if (ctx.isDone()) {
//             return ctx.err().?;
//         }
//         
//         // 执行操作...
//         std.time.sleep(10 * std.time.ns_per_ms);
//     }
// }
// 
// // 在另一个线程或信号处理中取消
// ctx.cancel();
// ```
