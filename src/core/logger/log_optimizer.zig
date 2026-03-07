const std = @import("std");

/// 日志优化器
/// 减少不必要的日志输出，提升性能
pub const LogOptimizer = struct {
    config: Config,
    
    pub const Config = struct {
        // 日志级别
        level: Level = .info,
        
        // 是否启用采样（高频日志只记录部分）
        enable_sampling: bool = true,
        
        // 采样率（1/N 的日志会被记录）
        sample_rate: u32 = 10,
        
        // 是否启用日志聚合（相同日志只记录一次）
        enable_aggregation: bool = true,
        
        // 聚合时间窗口（秒）
        aggregation_window: u32 = 60,
        
        // 慢查询阈值（毫秒）
        slow_query_threshold: u32 = 1000,
        
        // 是否记录请求详情
        log_request_details: bool = false,
        
        // 是否记录响应详情
        log_response_details: bool = false,
        
        // 排除的路径（不记录日志）
        exclude_paths: [][]const u8 = &.{
            "/health",
            "/metrics",
            "/favicon.ico",
        },
    };
    
    pub const Level = enum {
        debug,
        info,
        warn,
        err,
    };
    
    pub fn init(config: Config) LogOptimizer {
        return .{ .config = config };
    }
    
    /// 判断是否应该记录日志
    pub fn shouldLog(self: *LogOptimizer, level: Level, path: []const u8) bool {
        // 1. 检查日志级别
        if (@intFromEnum(level) < @intFromEnum(self.config.level)) {
            return false;
        }
        
        // 2. 检查排除路径
        for (self.config.exclude_paths) |exclude_path| {
            if (std.mem.eql(u8, path, exclude_path)) {
                return false;
            }
        }
        
        return true;
    }
    
    /// 判断是否应该采样记录
    pub fn shouldSample(self: *LogOptimizer, counter: u32) bool {
        if (!self.config.enable_sampling) {
            return true;
        }
        
        return counter % self.config.sample_rate == 0;
    }
    
    /// 记录优化后的请求日志
    pub fn logRequest(self: *LogOptimizer, method: []const u8, path: []const u8, duration_ms: u32) void {
        // 只记录慢请求
        if (duration_ms >= self.config.slow_query_threshold) {
            std.log.warn("慢请求: {s} {s} - {d}ms", .{ method, path, duration_ms });
        } else if (self.config.log_request_details) {
            std.log.info("{s} {s} - {d}ms", .{ method, path, duration_ms });
        }
    }
    
    /// 记录优化后的数据库查询日志
    pub fn logQuery(self: *LogOptimizer, sql: []const u8, duration_ms: u32) void {
        // 只记录慢查询
        if (duration_ms >= self.config.slow_query_threshold) {
            std.log.warn("慢查询: {s} - {d}ms", .{ sql, duration_ms });
        }
    }
    
    /// 记录优化后的错误日志
    pub fn logError(self: *LogOptimizer, context: []const u8, err: anyerror) void {
        _ = self;
        std.log.err("{s}: {}", .{ context, err });
    }
    
    /// 记录优化后的调试日志（采样）
    pub fn logDebug(self: *LogOptimizer, counter: u32, message: []const u8) void {
        if (self.shouldSample(counter)) {
            std.log.debug("{s} (采样: 1/{d})", .{ message, self.config.sample_rate });
        }
    }
};

/// 全局日志优化器实例
var global_optimizer: ?LogOptimizer = null;

/// 初始化全局日志优化器
pub fn initGlobalOptimizer(config: LogOptimizer.Config) void {
    global_optimizer = LogOptimizer.init(config);
}

/// 获取全局日志优化器
pub fn getGlobalOptimizer() *LogOptimizer {
    return &global_optimizer.?;
}

/// 优化后的日志宏
pub fn logInfo(comptime fmt: []const u8, args: anytype) void {
    if (global_optimizer) |*opt| {
        if (opt.config.level == .info or opt.config.level == .debug) {
            std.log.info(fmt, args);
        }
    } else {
        std.log.info(fmt, args);
    }
}

pub fn logWarn(comptime fmt: []const u8, args: anytype) void {
    std.log.warn(fmt, args);
}

pub fn logErr(comptime fmt: []const u8, args: anytype) void {
    std.log.err(fmt, args);
}

pub fn logDebug(comptime fmt: []const u8, args: anytype) void {
    if (global_optimizer) |*opt| {
        if (opt.config.level == .debug) {
            std.log.debug(fmt, args);
        }
    }
}

/// 请求日志中间件
pub const RequestLogger = struct {
    optimizer: *LogOptimizer,
    counter: std.atomic.Value(u32),
    
    pub fn init(optimizer: *LogOptimizer) RequestLogger {
        return .{
            .optimizer = optimizer,
            .counter = std.atomic.Value(u32).init(0),
        };
    }
    
    pub fn logRequest(self: *RequestLogger, method: []const u8, path: []const u8, duration_ms: u32) void {
        // 检查是否应该记录
        if (!self.optimizer.shouldLog(.info, path)) {
            return;
        }
        
        // 采样记录
        const count = self.counter.fetchAdd(1, .monotonic);
        if (self.optimizer.shouldSample(count)) {
            self.optimizer.logRequest(method, path, duration_ms);
        }
    }
};
