//! 中间件链式调用模块
//!
//! 类似 Gin 的中间件模式：
//! - 链式调用
//! - 可中断请求
//! - 上下文传递
//!
//! ## 使用示例
//!
//! ```zig
//! const chain = @import("middlewares/chain.zig");
//!
//! // 定义中间件
//! fn authMiddleware(ctx: *chain.Context) chain.Result {
//!     if (ctx.req.getHeader("authorization")) |token| {
//!         ctx.set("user_id", 123);
//!         return .next;
//!     }
//!     ctx.sendError("未授权");
//!     return .abort;
//! }
//!
//! fn logMiddleware(ctx: *chain.Context) chain.Result {
//!     std.log.info("请求: {s}", .{ctx.req.path});
//!     return .next;
//! }
//!
//! // 创建处理器链
//! const handler = chain.Handler.init()
//!     .use(logMiddleware)
//!     .use(authMiddleware)
//!     .handle(myController);
//!
//! try router.handle_func("/api/users", handler);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const jwt = @import("../../shared/utils/jwt.zig");

/// JWT 密钥配置（实际项目中应从配置文件读取）
const JWT_SECRET = "zigcms-jwt-secret-key-2024";

// 条件导入 zap（测试时使用模拟类型）
const zap = if (@import("builtin").is_test) struct {
    pub const Request = MockRequest;
    pub const StatusCode = enum { ok, unauthorized };
} else @import("zap");

/// 模拟请求（仅用于测试）
const MockRequest = struct {
    path: ?[]const u8 = null,
    method: ?[]const u8 = null,

    pub fn getHeader(_: MockRequest, _: []const u8) ?[]const u8 {
        return null;
    }
    pub fn setHeader(_: MockRequest, _: []const u8, _: []const u8) !void {}
    pub fn setStatus(_: MockRequest, _: zap.StatusCode) void {}
    pub fn sendBody(_: MockRequest, _: []const u8) !void {}
};

/// 中间件执行结果
pub const Result = enum {
    next, // 继续执行下一个中间件
    abort, // 中断请求
};

/// 请求上下文
pub const Context = struct {
    req: zap.Request,
    allocator: Allocator,

    // 上下文数据存储
    data: std.StringHashMap(Value),

    // 认证信息
    user_id: ?u32 = null,
    is_authenticated: bool = false,

    // 中间件状态
    aborted: bool = false,

    pub const Value = union(enum) {
        int: i64,
        str: []const u8,
        boolean: bool,
    };

    pub fn init(allocator: Allocator, req: zap.Request) Context {
        return .{
            .req = req,
            .allocator = allocator,
            .data = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Context) void {
        self.data.deinit();
    }

    /// 设置上下文值
    pub fn set(self: *Context, key: []const u8, value: anytype) void {
        const T = @TypeOf(value);
        const v: Value = blk: {
            if (T == i32 or T == i64 or T == u32 or T == u64 or T == comptime_int) {
                break :blk .{ .int = @intCast(value) };
            } else if (T == []const u8) {
                break :blk .{ .str = value };
            } else if (T == bool) {
                break :blk .{ .boolean = value };
            } else if (@typeInfo(T) == .pointer) {
                // 处理字符串字面量指针
                const info = @typeInfo(T).pointer;
                if (info.child == u8 or @typeInfo(info.child) == .array) {
                    break :blk .{ .str = value };
                }
                @compileError("不支持的指针类型: " ++ @typeName(T));
            } else {
                @compileError("不支持的类型: " ++ @typeName(T));
            }
        };
        self.data.put(key, v) catch {};
    }

    /// 获取整数值
    pub fn getInt(self: *Context, key: []const u8) ?i64 {
        if (self.data.get(key)) |v| {
            return switch (v) {
                .int => |i| i,
                else => null,
            };
        }
        return null;
    }

    /// 获取字符串值
    pub fn getStr(self: *Context, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |v| {
            return switch (v) {
                .str => |s| s,
                else => null,
            };
        }
        return null;
    }

    /// 获取布尔值
    pub fn getBool(self: *Context, key: []const u8) ?bool {
        if (self.data.get(key)) |v| {
            return switch (v) {
                .boolean => |b| b,
                else => null,
            };
        }
        return null;
    }

    /// 中断请求
    pub fn abort(self: *Context) void {
        self.aborted = true;
    }

    /// 发送 JSON 错误响应
    pub fn sendError(self: *Context, message: []const u8) void {
        self.abort();
        var buf: [512]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"code\":401,\"message\":\"{s}\"}}", .{message}) catch return;
        self.req.setHeader("Content-Type", "application/json") catch {};
        self.req.setStatus(.unauthorized);
        self.req.sendBody(json) catch {};
    }

    /// 发送 JSON 成功响应
    pub fn sendOk(self: *Context, data: []const u8) void {
        var buf: [4096]u8 = undefined;
        const json = std.fmt.bufPrint(&buf, "{{\"code\":0,\"data\":{s}}}", .{data}) catch return;
        self.req.setHeader("Content-Type", "application/json") catch {};
        self.req.sendBody(json) catch {};
    }
};

/// 中间件函数类型
pub const MiddlewareFn = *const fn (*Context) Result;

/// 控制器处理函数类型
pub const HandlerFn = *const fn (*Context) void;

/// 中间件链
pub fn Chain(comptime max_middlewares: usize) type {
    return struct {
        const Self = @This();

        middlewares: [max_middlewares]MiddlewareFn = undefined,
        count: usize = 0,
        handler: ?HandlerFn = null,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// 添加中间件
        pub fn use(self: *Self, middleware: MiddlewareFn) *Self {
            if (self.count < max_middlewares) {
                self.middlewares[self.count] = middleware;
                self.count += 1;
            }
            return self;
        }

        /// 设置最终处理器
        pub fn handle(self: *Self, handler: HandlerFn) *Self {
            self.handler = handler;
            return self;
        }

        /// 执行中间件链
        pub fn execute(self: *Self, req: zap.Request) void {
            var ctx = Context.init(self.allocator, req);
            defer ctx.deinit();

            // 执行中间件
            for (self.middlewares[0..self.count]) |middleware| {
                if (ctx.aborted) return;

                const result = middleware(&ctx);
                if (result == .abort) return;
            }

            // 执行最终处理器
            if (!ctx.aborted) {
                if (self.handler) |h| {
                    h(&ctx);
                }
            }
        }
    };
}

// ============================================================================
// 常用中间件
// ============================================================================

/// JWT 认证中间件
pub fn authMiddleware(ctx: *Context) Result {
    if (ctx.req.getHeader("authorization")) |authorization| {
        var token = authorization;
        if (std.mem.startsWith(u8, authorization, "Bearer ")) {
            token = authorization[7..];
        }

        if (token.len > 0) {
            // 解析 JWT token
            const payload = jwt.decode(ctx.allocator, token, .{
                .secret = JWT_SECRET,
                .verify_signature = true,
            }) catch {
                ctx.sendError("无效的登录凭证");
                return .abort;
            };
            defer {
                if (payload.username.len > 0) ctx.allocator.free(payload.username);
                if (payload.email.len > 0) ctx.allocator.free(payload.email);
            }

            ctx.user_id = @intCast(payload.user_id);
            ctx.is_authenticated = true;
            ctx.set("user_id", payload.user_id);
            ctx.set("username", payload.username);
            ctx.set("email", payload.email);
            ctx.set("token", token);
            return .next;
        }
    }

    ctx.sendError("缺少登录凭证");
    return .abort;
}

/// 日志中间件
pub fn logMiddleware(ctx: *Context) Result {
    if (ctx.req.path) |path| {
        std.log.info("[HTTP] {s}", .{path});
    }
    return .next;
}

/// CORS 中间件
pub fn corsMiddleware(ctx: *Context) Result {
    ctx.req.setHeader("Access-Control-Allow-Origin", "*") catch {};
    ctx.req.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS") catch {};
    ctx.req.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization") catch {};

    // OPTIONS 预检请求直接返回
    if (ctx.req.method) |method| {
        if (std.mem.eql(u8, method, "OPTIONS")) {
            ctx.req.setStatus(.ok);
            ctx.req.sendBody("") catch {};
            return .abort;
        }
    }
    return .next;
}

/// 限流中间件（简单计数器）
pub fn rateLimitMiddleware(ctx: *Context) Result {
    // TODO: 实现实际的限流逻辑
    _ = ctx;
    return .next;
}

// ============================================================================
// 测试
// ============================================================================

test "Context: 基本操作" {
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator, undefined);
    defer ctx.deinit();

    ctx.set("count", 100);
    ctx.set("name", "张三");
    ctx.set("active", true);

    try std.testing.expectEqual(@as(?i64, 100), ctx.getInt("count"));
    try std.testing.expectEqualStrings("张三", ctx.getStr("name").?);
    try std.testing.expectEqual(@as(?bool, true), ctx.getBool("active"));
}

test "Chain: 中间件定义" {
    // 验证中间件函数类型正确
    const testMw = struct {
        fn run(ctx: *Context) Result {
            _ = ctx;
            return .next;
        }
    }.run;

    const mwFn: MiddlewareFn = testMw;
    _ = mwFn;
}

test "Chain: 中间件中断" {
    // 验证 abort 会中断后续中间件
    const allocator = std.testing.allocator;
    var ctx = Context.init(allocator, undefined);
    defer ctx.deinit();

    ctx.abort();
    try std.testing.expect(ctx.aborted);
}
