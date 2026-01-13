//! 控制器包装器
//!
//! 将中间件链与现有控制器无缝集成。
//!
//! ## 使用示例
//!
//! ```zig
//! const wrapper = @import("middlewares/wrapper.zig");
//!
//! // 包装需要认证的控制器方法
//! const protected = wrapper.withAuth(MyController.secretMethod);
//!
//! // 包装多个中间件
//! const handler = wrapper.wrap(MyController.method, &.{
//!     wrapper.log,
//!     wrapper.cors,
//!     wrapper.auth,
//! });
//!
//! try router.handle_func("/api/secret", &ctrl, protected);
//! ```

const std = @import("std");
const chain = @import("chain.zig");
const jwt = @import("../../shared/utils/jwt.zig");
const context = @import("../../shared/utils/context.zig");

/// JWT 密钥配置
const JWT_SECRET = "zigcms-jwt-secret-key-2024";

// 条件导入 zap（测试时使用模拟类型）
const zap = if (@import("builtin").is_test) struct {
    pub const Request = MockRequest;
    pub const StatusCode = enum { ok, unauthorized };
} else @import("zap");

/// 模拟请求（仅用于测试）
const MockRequest = struct {
    pub fn getHeader(_: MockRequest, _: []const u8) ?[]const u8 {
        return null;
    }
    pub fn setHeader(_: MockRequest, _: []const u8, _: []const u8) !void {}
    pub fn setStatus(_: MockRequest, _: zap.StatusCode) void {}
    pub fn sendBody(_: MockRequest, _: []const u8) !void {}
};

/// 原始处理器函数类型（带 self 和 request）
pub fn ControllerMethod(comptime T: type) type {
    return *const fn (*T, zap.Request) anyerror!void;
}

/// 中间件检查结果
pub const CheckResult = struct {
    ok: bool,
    user_id: ?u32 = null,
    error_msg: ?[]const u8 = null,
};

/// 认证检查器
pub fn AuthChecker(comptime T: type) type {
    return struct {
        /// 检查认证状态
        pub fn check(req: zap.Request) CheckResult {
            if (req.getHeader("authorization")) |authorization| {
                var token = authorization;
                if (std.mem.startsWith(u8, authorization, "Bearer ")) {
                    token = authorization[7..];
                }

                if (token.len > 0) {
                    // 解析 JWT token
                    const payload = jwt.decode(std.heap.page_allocator, token, .{
                        .secret = JWT_SECRET,
                        .verify_signature = true,
                    }) catch {
                        return .{ .ok = false, .error_msg = "无效的登录凭证" };
                    };

                    // 设置用户上下文
                    context.setContext(.{
                        .user_id = payload.user_id,
                        .username = payload.username,
                        .email = payload.email,
                        .is_authenticated = true,
                    });

                    return .{ .ok = true, .user_id = @intCast(payload.user_id) };
                }
            }
            return .{ .ok = false, .error_msg = "缺少登录凭证" };
        }

        /// 包装需要认证的方法
        pub fn withAuth(
            comptime method: ControllerMethod(T),
        ) ControllerMethod(T) {
            return struct {
                fn wrapped(self: *T, req: zap.Request) !void {
                    const result = check(req);
                    if (!result.ok) {
                        sendAuthError(req, result.error_msg orelse "认证失败");
                        return;
                    }
                    // 认证通过，调用原方法
                    try method(self, req);
                    // 请求结束后清除上下文
                    context.clearContext();
                }
            }.wrapped;
        }

        /// 包装可选认证的方法（不强制要求登录）
        pub fn withOptionalAuth(
            comptime method: ControllerMethod(T),
        ) ControllerMethod(T) {
            return struct {
                fn wrapped(self: *T, req: zap.Request) !void {
                    // 可选认证，不管结果都继续
                    _ = check(req);
                    try method(self, req);
                }
            }.wrapped;
        }

        fn sendAuthError(req: zap.Request, message: []const u8) void {
            var buf: [512]u8 = undefined;
            const json = std.fmt.bufPrint(&buf, "{{\"code\":401,\"message\":\"{s}\"}}", .{message}) catch return;
            req.setHeader("Content-Type", "application/json") catch {};
            req.setStatus(.unauthorized);
            req.sendBody(json) catch {};
        }
    };
}

/// 创建带中间件的控制器
///
/// 用于将多个中间件组合到控制器中
pub fn Controller(comptime T: type) type {
    return struct {
        const Auth = AuthChecker(T);

        /// 需要认证的方法包装
        pub fn requireAuth(comptime method: ControllerMethod(T)) ControllerMethod(T) {
            return Auth.withAuth(method);
        }

        /// 可选认证的方法包装
        pub fn optionalAuth(comptime method: ControllerMethod(T)) ControllerMethod(T) {
            return Auth.withOptionalAuth(method);
        }

        /// 添加日志的方法包装
        pub fn withLog(comptime method: ControllerMethod(T)) ControllerMethod(T) {
            return struct {
                fn wrapped(self: *T, req: zap.Request) !void {
                    if (req.path) |path| {
                        std.log.info("[REQ] {s}", .{path});
                    }
                    try method(self, req);
                }
            }.wrapped;
        }

        /// 添加 CORS 的方法包装
        pub fn withCors(comptime method: ControllerMethod(T)) ControllerMethod(T) {
            return struct {
                fn wrapped(self: *T, req: zap.Request) !void {
                    req.setHeader("Access-Control-Allow-Origin", "*") catch {};
                    req.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE") catch {};

                    if (req.method) |m| {
                        if (std.mem.eql(u8, m, "OPTIONS")) {
                            req.setStatus(.ok);
                            req.sendBody("") catch {};
                            return;
                        }
                    }
                    try method(self, req);
                }
            }.wrapped;
        }

        /// 组合多个中间件
        pub fn compose(
            comptime method: ControllerMethod(T),
            comptime wrappers: []const fn (ControllerMethod(T)) ControllerMethod(T),
        ) ControllerMethod(T) {
            var result = method;
            // 反向应用，让第一个中间件最先执行
            comptime var i = wrappers.len;
            inline while (i > 0) {
                i -= 1;
                result = wrappers[i](result);
            }
            return result;
        }
    };
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 检查认证状态
pub fn checkAuth(req: zap.Request) CheckResult {
    return AuthChecker(void).check(req);
}

/// 发送 JSON 错误
pub fn sendError(req: zap.Request, message: []const u8) void {
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"code\":1,\"message\":\"{s}\"}}", .{message}) catch return;
    req.setHeader("Content-Type", "application/json") catch {};
    req.sendBody(json) catch {};
}

/// 发送 JSON 成功
pub fn sendOk(req: zap.Request, data: []const u8) void {
    var buf: [8192]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"code\":0,\"data\":{s}}}", .{data}) catch return;
    req.setHeader("Content-Type", "application/json") catch {};
    req.sendBody(json) catch {};
}

// ============================================================================
// 测试
// ============================================================================

test "AuthChecker: 无 token" {
    // 模拟无 token 的请求
    const result = AuthChecker(void).check(undefined);
    try std.testing.expect(!result.ok);
    try std.testing.expectEqualStrings("缺少登录凭证", result.error_msg.?);
}
