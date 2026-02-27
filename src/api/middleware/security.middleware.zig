//! 安全防护中间件
//!
//! 提供全局的安全防护功能，包括：
//! - SQL 注入检测
//! - XSS 攻击检测
//! - 命令注入检测
//! - 路径遍历检测
//! - 请求频率限制
//!
//! ## 使用示例
//!
//! ```zig
//! const security_mw = @import("middleware/security.middleware.zig");
//!
//! // 在路由中使用
//! pub const save = MW.compose(saveImpl, &.{
//!     security_mw.securityCheck,
//!     MW.requireAuth,
//! });
//! ```

const std = @import("std");
const zap = @import("zap");
const security = @import("../../application/services/validator/security.zig");
const chain = @import("chain.zig");

/// 安全检查中间件
pub fn securityCheckMiddleware(ctx: *chain.Context) chain.Result {
    // 检查查询参数
    if (ctx.req.query) |query| {
        if (!security.isClean(query)) {
            ctx.sendError("检测到潜在的安全威胁，请求已被拦截");
            return .abort;
        }
    }

    // 检查请求体
    ctx.req.parseBody() catch {};
    if (ctx.req.body) |body| {
        if (!security.isClean(body)) {
            ctx.sendError("检测到潜在的安全威胁，请求已被拦截");
            return .abort;
        }
    }

    return .next;
}

/// 安全配置
pub const SecurityConfig = struct {
    /// 是否启用 SQL 注入检测
    sql_injection: bool = true,
    /// 是否启用 XSS 检测
    xss: bool = true,
    /// 是否启用命令注入检测
    command_injection: bool = true,
    /// 是否启用路径遍历检测
    path_traversal: bool = true,
    /// 白名单路径（跳过检测）
    whitelist: []const []const u8 = &.{},
    /// 最大请求体大小（字节）
    max_body_size: usize = 10 * 1024 * 1024, // 10MB
};

/// 可配置的安全检查
pub fn SecurityMiddleware(comptime config: SecurityConfig) type {
    return struct {
        pub fn check(ctx: *chain.Context) chain.Result {
            // 检查白名单
            if (ctx.req.path) |path| {
                for (config.whitelist) |whitelist_path| {
                    if (std.mem.startsWith(u8, path, whitelist_path)) {
                        return .next;
                    }
                }
            }

            var sec = security.Security.init(ctx.allocator);

            // 检查查询参数
            if (ctx.req.query) |query| {
                if (config.sql_injection) {
                    const result = sec.detectSqlInjection(query);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "SQL_INJECTION", query);
                        ctx.sendError("检测到 SQL 注入攻击");
                        return .abort;
                    }
                }

                if (config.xss) {
                    const result = sec.detectXss(query);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "XSS", query);
                        ctx.sendError("检测到 XSS 攻击");
                        return .abort;
                    }
                }

                if (config.path_traversal) {
                    const result = sec.detectPathTraversal(query);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "PATH_TRAVERSAL", query);
                        ctx.sendError("检测到路径遍历攻击");
                        return .abort;
                    }
                }
            }

            // 检查请求体
            ctx.req.parseBody() catch {};
            if (ctx.req.body) |body| {
                // 检查请求体大小
                if (body.len > config.max_body_size) {
                    ctx.sendError("请求体过大");
                    return .abort;
                }

                if (config.sql_injection) {
                    const result = sec.detectSqlInjection(body);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "SQL_INJECTION", body[0..@min(body.len, 200)]);
                        ctx.sendError("检测到 SQL 注入攻击");
                        return .abort;
                    }
                }

                if (config.xss) {
                    const result = sec.detectXss(body);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "XSS", body[0..@min(body.len, 200)]);
                        ctx.sendError("检测到 XSS 攻击");
                        return .abort;
                    }
                }

                if (config.command_injection) {
                    const result = sec.detectCommandInjection(body);
                    if (!result.is_safe) {
                        logSecurityEvent(ctx, "COMMAND_INJECTION", body[0..@min(body.len, 200)]);
                        ctx.sendError("检测到命令注入攻击");
                        return .abort;
                    }
                }
            }

            // 检查 HTTP 头注入
            if (ctx.req.getHeader("referer")) |referer| {
                const result = sec.detectHeaderInjection(referer);
                if (!result.is_safe) {
                    logSecurityEvent(ctx, "HEADER_INJECTION", referer);
                    ctx.sendError("检测到 HTTP 头注入攻击");
                    return .abort;
                }
            }

            return .next;
        }
    };
}

/// 默认安全中间件
pub const DefaultSecurity = SecurityMiddleware(.{});

/// 记录安全事件
fn logSecurityEvent(ctx: *chain.Context, event_type: []const u8, payload: []const u8) void {
    const path = ctx.req.path orelse "unknown";
    const method = ctx.req.method orelse "unknown";

    std.log.warn("[SECURITY] {s} attack detected - Method: {s}, Path: {s}, Payload: {s}", .{
        event_type,
        method,
        path,
        payload,
    });
}

// ============================================================================
// 独立函数（用于非中间件场景）
// ============================================================================

/// 检查请求参数是否安全
pub fn checkParams(req: zap.Request) bool {
    req.parseQuery();

    if (req.query) |query| {
        if (!security.isClean(query)) {
            return false;
        }
    }

    return true;
}

/// 检查请求体是否安全
pub fn checkBody(req: zap.Request) bool {
    req.parseBody() catch return true;

    if (req.body) |body| {
        if (!security.isClean(body)) {
            return false;
        }
    }

    return true;
}

/// 清理用户输入
pub fn sanitizeInput(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return security.sanitize(allocator, input);
}

/// 转义 HTML
pub fn escapeHtml(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return security.escapeHtml(allocator, input);
}

/// 转义 SQL
pub fn escapeSql(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return security.escapeSql(allocator, input);
}

// ============================================================================
// IP 黑名单管理
// ============================================================================

/// IP 黑名单（简单实现）
pub const IpBlacklist = struct {
    const Self = @This();

    blocked_ips: std.StringHashMap(i64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .blocked_ips = std.StringHashMap(i64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocked_ips.deinit();
    }

    /// 添加 IP 到黑名单
    pub fn block(self: *Self, ip: []const u8, duration_seconds: i64) !void {
        const expiry = std.time.timestamp() + duration_seconds;
        try self.blocked_ips.put(ip, expiry);
    }

    /// 检查 IP 是否被封禁
    pub fn isBlocked(self: *Self, ip: []const u8) bool {
        if (self.blocked_ips.get(ip)) |expiry| {
            if (std.time.timestamp() < expiry) {
                return true;
            }
            // 已过期，移除
            _ = self.blocked_ips.remove(ip);
        }
        return false;
    }

    /// 解除封禁
    pub fn unblock(self: *Self, ip: []const u8) void {
        _ = self.blocked_ips.remove(ip);
    }
};

// ============================================================================
// 请求频率限制
// ============================================================================

/// 简单的请求频率限制器
pub const RateLimiter = struct {
    const Self = @This();

    /// 请求记录
    const RequestRecord = struct {
        count: u32,
        window_start: i64,
    };

    records: std.StringHashMap(RequestRecord),
    allocator: std.mem.Allocator,
    max_requests: u32,
    window_seconds: i64,

    pub fn init(allocator: std.mem.Allocator, max_requests: u32, window_seconds: i64) Self {
        return .{
            .records = std.StringHashMap(RequestRecord).init(allocator),
            .allocator = allocator,
            .max_requests = max_requests,
            .window_seconds = window_seconds,
        };
    }

    pub fn deinit(self: *Self) void {
        self.records.deinit();
    }

    /// 检查是否允许请求
    pub fn allow(self: *Self, key: []const u8) bool {
        const now = std.time.timestamp();

        if (self.records.get(key)) |*record| {
            // 检查是否在同一窗口期
            if (now - record.window_start < self.window_seconds) {
                if (record.count >= self.max_requests) {
                    return false;
                }
                // 更新记录需要重新 put
                self.records.put(key, .{
                    .count = record.count + 1,
                    .window_start = record.window_start,
                }) catch {};
            } else {
                // 新窗口期
                self.records.put(key, .{
                    .count = 1,
                    .window_start = now,
                }) catch {};
            }
        } else {
            // 新记录
            self.records.put(key, .{
                .count = 1,
                .window_start = now,
            }) catch {};
        }

        return true;
    }

    /// 获取剩余请求次数
    pub fn remaining(self: *Self, key: []const u8) u32 {
        const now = std.time.timestamp();

        if (self.records.get(key)) |record| {
            if (now - record.window_start < self.window_seconds) {
                if (record.count >= self.max_requests) {
                    return 0;
                }
                return self.max_requests - record.count;
            }
        }
        return self.max_requests;
    }
};
