const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;

/// API 限流中间件
/// 防止恶意请求和 DDoS 攻击
pub const RateLimiter = struct {
    allocator: Allocator,
    cache: *CacheInterface,
    config: Config,
    
    pub const Config = struct {
        // 全局限流配置
        global_limit: u32 = 1000,  // 每分钟最多 1000 个请求
        global_window: u32 = 60,   // 时间窗口（秒）
        
        // IP 限流配置
        ip_limit: u32 = 100,       // 每个 IP 每分钟最多 100 个请求
        ip_window: u32 = 60,       // 时间窗口（秒）
        
        // 用户限流配置
        user_limit: u32 = 200,     // 每个用户每分钟最多 200 个请求
        user_window: u32 = 60,     // 时间窗口（秒）
        
        // 端点限流配置
        endpoint_limits: []EndpointLimit = &.{},
        
        // 白名单 IP
        whitelist_ips: [][]const u8 = &.{},
        
        // 黑名单 IP
        blacklist_ips: [][]const u8 = &.{},
    };
    
    pub const EndpointLimit = struct {
        path: []const u8,
        limit: u32,
        window: u32,
    };
    
    pub fn init(allocator: Allocator, cache: *CacheInterface, config: Config) RateLimiter {
        return .{
            .allocator = allocator,
            .cache = cache,
            .config = config,
        };
    }
    
    /// 中间件处理函数
    pub fn handle(self: *RateLimiter, req: *zap.Request) !bool {
        // 1. 检查黑名单
        const client_ip = req.getClientIP() orelse "unknown";
        if (self.isBlacklisted(client_ip)) {
            try self.sendRateLimitResponse(req, "IP 已被封禁");
            return false;
        }
        
        // 2. 检查白名单（白名单 IP 不限流）
        if (self.isWhitelisted(client_ip)) {
            return true;
        }
        
        // 3. 全局限流检查
        if (!try self.checkGlobalLimit()) {
            try self.sendRateLimitResponse(req, "系统繁忙，请稍后重试");
            return false;
        }
        
        // 4. IP 限流检查
        if (!try self.checkIPLimit(client_ip)) {
            try self.sendRateLimitResponse(req, "请求过于频繁，请稍后重试");
            return false;
        }
        
        // 5. 用户限流检查（如果已登录）
        if (req.getUserId()) |user_id| {
            if (!try self.checkUserLimit(user_id)) {
                try self.sendRateLimitResponse(req, "请求过于频繁，请稍后重试");
                return false;
            }
        }
        
        // 6. 端点限流检查
        const path = req.getPath() orelse "/";
        if (!try self.checkEndpointLimit(path, client_ip)) {
            try self.sendRateLimitResponse(req, "该接口请求过于频繁，请稍后重试");
            return false;
        }
        
        return true;
    }
    
    /// 检查全局限流
    fn checkGlobalLimit(self: *RateLimiter) !bool {
        const key = "rate_limit:global";
        return try self.checkLimit(key, self.config.global_limit, self.config.global_window);
    }
    
    /// 检查 IP 限流
    fn checkIPLimit(self: *RateLimiter, ip: []const u8) !bool {
        const key = try std.fmt.allocPrint(self.allocator, "rate_limit:ip:{s}", .{ip});
        defer self.allocator.free(key);
        
        return try self.checkLimit(key, self.config.ip_limit, self.config.ip_window);
    }
    
    /// 检查用户限流
    fn checkUserLimit(self: *RateLimiter, user_id: i32) !bool {
        const key = try std.fmt.allocPrint(self.allocator, "rate_limit:user:{d}", .{user_id});
        defer self.allocator.free(key);
        
        return try self.checkLimit(key, self.config.user_limit, self.config.user_window);
    }
    
    /// 检查端点限流
    fn checkEndpointLimit(self: *RateLimiter, path: []const u8, ip: []const u8) !bool {
        // 查找端点配置
        for (self.config.endpoint_limits) |endpoint| {
            if (std.mem.startsWith(u8, path, endpoint.path)) {
                const key = try std.fmt.allocPrint(
                    self.allocator,
                    "rate_limit:endpoint:{s}:{s}",
                    .{ endpoint.path, ip },
                );
                defer self.allocator.free(key);
                
                return try self.checkLimit(key, endpoint.limit, endpoint.window);
            }
        }
        
        return true;
    }
    
    /// 通用限流检查（滑动窗口算法）
    fn checkLimit(self: *RateLimiter, key: []const u8, limit: u32, window: u32) !bool {
        // 获取当前计数
        const count_str = self.cache.get(key, self.allocator) catch null;
        defer if (count_str) |s| self.allocator.free(s);
        
        const current_count = if (count_str) |s| 
            std.fmt.parseInt(u32, s, 10) catch 0
        else 
            0;
        
        // 检查是否超过限制
        if (current_count >= limit) {
            return false;
        }
        
        // 增加计数
        const new_count = current_count + 1;
        const new_count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{new_count});
        defer self.allocator.free(new_count_str);
        
        // 设置缓存（带过期时间）
        try self.cache.set(key, new_count_str, window);
        
        return true;
    }
    
    /// 检查是否在白名单
    fn isWhitelisted(self: *RateLimiter, ip: []const u8) bool {
        for (self.config.whitelist_ips) |whitelist_ip| {
            if (std.mem.eql(u8, ip, whitelist_ip)) {
                return true;
            }
        }
        return false;
    }
    
    /// 检查是否在黑名单
    fn isBlacklisted(self: *RateLimiter, ip: []const u8) bool {
        for (self.config.blacklist_ips) |blacklist_ip| {
            if (std.mem.eql(u8, ip, blacklist_ip)) {
                return true;
            }
        }
        return false;
    }
    
    /// 发送限流响应
    fn sendRateLimitResponse(self: *RateLimiter, req: *zap.Request, message: []const u8) !void {
        _ = self;
        
        const response = try std.json.stringifyAlloc(
            req.allocator,
            .{
                .code = 429,
                .message = message,
                .data = null,
            },
            .{},
        );
        defer req.allocator.free(response);
        
        try req.setStatus(.too_many_requests);
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Retry-After", "60");
        try req.sendBody(response);
    }
    
    /// 获取限流统计信息
    pub fn getStats(self: *RateLimiter) !Stats {
        const global_key = "rate_limit:global";
        const global_count_str = self.cache.get(global_key, self.allocator) catch null;
        defer if (global_count_str) |s| self.allocator.free(s);
        
        const global_count = if (global_count_str) |s|
            std.fmt.parseInt(u32, s, 10) catch 0
        else
            0;
        
        return .{
            .global_requests = global_count,
            .global_limit = self.config.global_limit,
            .global_usage_rate = @as(f32, @floatFromInt(global_count)) / @as(f32, @floatFromInt(self.config.global_limit)),
        };
    }
    
    pub const Stats = struct {
        global_requests: u32,
        global_limit: u32,
        global_usage_rate: f32,
    };
};
