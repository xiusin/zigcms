//! Timeout Example Controller - 超时控制示例
//!
//! 展示如何使用 RequestContext 实现类似 Go context 的超时控制
//! 
//! ## 功能展示
//! - 请求超时自动取消
//! - 手动取消操作
//! - 长时间操作的中断
//! - 请求范围值传递

const std = @import("std");
const AppContext = @import("../../shared/context/app_context.zig").AppContext;
const RequestContext = @import("../../shared/context/request_context.zig").RequestContext;
const base = @import("base.fn.zig");

/// 超时控制示例控制器
pub const TimeoutExampleController = struct {
    app_ctx: *AppContext,
    
    const Self = @This();
    
    pub fn init(app_context: *AppContext) Self {
        return .{
            .app_ctx = app_context,
        };
    }
    
    /// 示例 1: 带超时的数据库查询
    ///
    /// GET /api/timeout/query?timeout=5000
    ///
    /// 演示：
    /// - 创建带超时的请求上下文
    /// - 执行数据库查询
    /// - 自动超时保护
    pub fn queryWithTimeout(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        // 从查询参数获取超时时间（默认 5 秒）
        const timeout_ms: u64 = 5000;
        
        // 创建带超时的请求上下文
        var ctx = try RequestContext.withTimeout(allocator, self.app_ctx, timeout_ms);
        defer ctx.deinit();
        
        // 设置请求 ID
        try ctx.setValue("request_id", "req-12345");
        
        // 模拟长时间查询
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            // 检查超时
            if (ctx.isDone()) {
                const err_msg = switch (ctx.err().?) {
                    error.RequestTimeout => "请求超时",
                    error.RequestCancelled => "请求已取消",
                    else => "请求中断",
                };
                return base.send_failed(req, err_msg);
            }
            
            // 模拟耗时操作
            std.time.sleep(600 * std.time.ns_per_ms);
        }
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"message": "查询完成", "iterations": {}, "request_id": "{s}"}}
        , .{ i, ctx.getValue("request_id") orelse "unknown" });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 示例 2: 可取消的长时间操作
    ///
    /// GET /api/timeout/cancellable
    ///
    /// 演示：
    /// - 手动取消机制
    /// - 优雅中断长时间操作
    pub fn cancellableOperation(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        // 创建可取消的上下文
        var ctx = try RequestContext.withCancel(allocator, self.app_ctx);
        defer ctx.deinit();
        
        // 模拟：在另一个条件下取消（实际应用中可能是用户操作或其他信号）
        // ctx.cancel();
        
        var completed: usize = 0;
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            if (ctx.isDone()) {
                const response = try std.fmt.allocPrint(allocator,
                    \\{{"message": "操作被取消", "completed": {}, "total": 100}}
                , .{completed});
                defer allocator.free(response);
                return base.send_json_ok(req, response);
            }
            
            // 执行工作
            completed += 1;
            std.time.sleep(10 * std.time.ns_per_ms);
        }
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"message": "操作完成", "completed": {}}}
        , .{completed});
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 示例 3: 检查剩余时间
    ///
    /// GET /api/timeout/remaining
    ///
    /// 演示：
    /// - 获取剩余时间
    /// - 根据剩余时间调整策略
    pub fn checkRemaining(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        // 创建 3 秒超时
        var ctx = try RequestContext.withTimeout(allocator, self.app_ctx, 3000);
        defer ctx.deinit();
        
        // 模拟工作
        std.time.sleep(1000 * std.time.ns_per_ms);
        
        const remaining = ctx.remaining() orelse 0;
        const is_done = ctx.isDone();
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"remaining_ms": {}, "is_done": {}, "message": "还有 {}ms"}}
        , .{ remaining, is_done, remaining });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 示例 4: 带超时的缓存操作
    ///
    /// POST /api/timeout/cache-with-timeout
    ///
    /// 演示：
    /// - 缓存操作的超时控制
    /// - 组合使用 AppContext 和 RequestContext
    pub fn cacheWithTimeout(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        // 2 秒超时
        var ctx = try RequestContext.withTimeout(allocator, self.app_ctx, 2000);
        defer ctx.deinit();
        
        // 检查超时
        if (ctx.isDone()) {
            return base.send_failed(req, "请求超时");
        }
        
        // 获取缓存服务
        const cache = try ctx.getCache();
        
        // 设置缓存
        try cache.set("timeout:test", "cached_value", 60);
        
        // 检查超时
        if (ctx.isDone()) {
            return base.send_failed(req, "操作超时");
        }
        
        // 读取缓存
        if (try cache.get("timeout:test", allocator)) |value| {
            defer allocator.free(value);
            
            const response = try std.fmt.allocPrint(allocator,
                \\{{"message": "缓存操作成功", "value": "{s}", "remaining_ms": {}}}
            , .{ value, ctx.remaining() orelse 0 });
            defer allocator.free(response);
            
            return base.send_json_ok(req, response);
        }
        
        return base.send_failed(req, "缓存读取失败");
    }
    
    /// 示例 5: 链式超时（父子上下文）
    ///
    /// GET /api/timeout/chained
    ///
    /// 演示：
    /// - 父上下文超时会影响所有子操作
    /// - 分层超时控制
    pub fn chainedTimeout(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        // 父上下文：10 秒总超时
        var parent_ctx = try RequestContext.withTimeout(allocator, self.app_ctx, 10000);
        defer parent_ctx.deinit();
        
        // 子操作 1：最多 3 秒
        const result1 = try self.subOperation(&parent_ctx, 3000, "Operation 1");
        defer allocator.free(result1);
        
        // 检查父上下文
        if (parent_ctx.isDone()) {
            return base.send_failed(req, "父上下文超时");
        }
        
        // 子操作 2：最多 4 秒
        const result2 = try self.subOperation(&parent_ctx, 4000, "Operation 2");
        defer allocator.free(result2);
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"op1": "{s}", "op2": "{s}", "parent_remaining": {}}}
        , .{ result1, result2, parent_ctx.remaining() orelse 0 });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 子操作辅助函数
    fn subOperation(
        self: *Self,
        parent_ctx: *RequestContext,
        timeout_ms: u64,
        name: []const u8,
    ) ![]const u8 {
        const allocator = self.app_ctx.getDatabase().allocator;
        
        // 创建子上下文（继承父上下文的应用上下文）
        var ctx = try RequestContext.withTimeout(
            allocator,
            parent_ctx.getAppContext(),
            timeout_ms,
        );
        defer ctx.deinit();
        
        // 模拟工作
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            // 检查子上下文或父上下文是否超时
            if (ctx.isDone() or parent_ctx.isDone()) {
                return try std.fmt.allocPrint(allocator, "{s} 超时 (i={})", .{ name, i });
            }
            
            std.time.sleep(500 * std.time.ns_per_ms);
        }
        
        return try std.fmt.allocPrint(allocator, "{s} 完成", .{name});
    }
    
    /// 示例 6: 上下文值传递
    ///
    /// GET /api/timeout/context-values
    ///
    /// 演示：
    /// - 在请求范围内传递值
    /// - 类似 Go 的 context.WithValue
    pub fn contextValues(self: *Self, req: *base.zap.Request) !void {
        const db = self.app_ctx.getDatabase();
        const allocator = db.allocator;
        
        var ctx = try RequestContext.withTimeout(allocator, self.app_ctx, 5000);
        defer ctx.deinit();
        
        // 设置请求范围的值
        try ctx.setValue("user_id", "12345");
        try ctx.setValue("session_id", "sess-abc-123");
        try ctx.setValue("trace_id", "trace-xyz-789");
        
        // 在处理过程中访问这些值
        const user_id = ctx.getValue("user_id") orelse "unknown";
        const session_id = ctx.getValue("session_id") orelse "unknown";
        const trace_id = ctx.getValue("trace_id") orelse "unknown";
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"user_id": "{s}", "session_id": "{s}", "trace_id": "{s}"}}
        , .{ user_id, session_id, trace_id });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
};
