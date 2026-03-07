//! CSRF 防护中间件
//!
//! 提供跨站请求伪造（CSRF）防护功能

const std = @import("std");
const zap = @import("zap");
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;

/// CSRF Token 长度
const TOKEN_LENGTH = 32;

/// CSRF Token 有效期（秒）
const TOKEN_EXPIRY = 3600; // 1 小时

/// CSRF 防护配置
pub const CsrfConfig = struct {
    /// 是否启用 CSRF 防护
    enabled: bool = true,
    /// Token 头名称
    header_name: []const u8 = "X-CSRF-Token",
    /// Cookie 名称
    cookie_name: []const u8 = "csrf_token",
    /// 安全方法（不需要 CSRF 验证）
    safe_methods: []const []const u8 = &.{ "GET", "HEAD", "OPTIONS" },
    /// 白名单路径（不需要 CSRF 验证）
    whitelist_paths: []const []const u8 = &.{
        "/api/auth/login",
        "/api/auth/register",
        "/api/health",
    },
};

/// CSRF 防护中间件
pub const CsrfProtection = struct {
    allocator: std.mem.Allocator,
    config: CsrfConfig,
    cache: *CacheInterface,

    const Self = @This();

    /// 初始化 CSRF 防护
    pub fn init(allocator: std.mem.Allocator, config: CsrfConfig, cache: *CacheInterface) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .cache = cache,
        };
    }

    /// 生成 CSRF Token
    pub fn generateToken(self: *Self, session_id: []const u8) ![]const u8 {
        // 生成随机 token
        var token_bytes: [TOKEN_LENGTH]u8 = undefined;
        std.crypto.random.bytes(&token_bytes);
        
        const token = try std.fmt.allocPrint(
            self.allocator,
            "{x}",
            .{std.fmt.fmtSliceHexLower(&token_bytes)},
        );
        
        // 存储到缓存（关联到 session）
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "csrf:{s}",
            .{session_id},
        );
        defer self.allocator.free(cache_key);
        
        try self.cache.set(cache_key, token, TOKEN_EXPIRY);
        
        return token;
    }

    /// 验证 CSRF Token
    pub fn verifyToken(self: *Self, session_id: []const u8, token: []const u8) !bool {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "csrf:{s}",
            .{session_id},
        );
        defer self.allocator.free(cache_key);
        
        const stored_token = self.cache.get(cache_key, self.allocator) catch |err| {
            if (err == error.KeyNotFound) return false;
            return err;
        };
        defer self.allocator.free(stored_token);
        
        return std.mem.eql(u8, token, stored_token);
    }

    /// 中间件处理函数
    pub fn handle(self: *Self, req: *zap.Request) !void {
        if (!self.config.enabled) return;
        
        // 检查是否是安全方法
        const method = req.method orelse return error.MethodNotFound;
        for (self.config.safe_methods) |safe_method| {
            if (std.mem.eql(u8, method, safe_method)) return;
        }
        
        // 检查是否在白名单中
        const path = req.path orelse return error.PathNotFound;
        for (self.config.whitelist_paths) |whitelist_path| {
            if (std.mem.eql(u8, path, whitelist_path)) return;
        }
        
        // 获取 session ID
        const session_id = req.getCookie("session_id") orelse return error.SessionNotFound;
        
        // 获取 CSRF Token
        const token = req.getHeader(self.config.header_name) orelse {
            return error.CsrfTokenMissing;
        };
        
        // 验证 Token
        const valid = try self.verifyToken(session_id, token);
        if (!valid) {
            return error.CsrfTokenInvalid;
        }
    }

    /// 设置 CSRF Cookie
    pub fn setCookie(self: *Self, req: *zap.Request, token: []const u8) !void {
        const cookie = try std.fmt.allocPrint(
            self.allocator,
            "{s}={s}; Path=/; HttpOnly; SameSite=Strict; Max-Age={d}",
            .{ self.config.cookie_name, token, TOKEN_EXPIRY },
        );
        defer self.allocator.free(cookie);
        
        try req.setHeader("Set-Cookie", cookie);
    }
};

/// CSRF 错误类型
pub const CsrfError = error{
    SessionNotFound,
    CsrfTokenMissing,
    CsrfTokenInvalid,
    MethodNotFound,
    PathNotFound,
};
