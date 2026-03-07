const std = @import("std");
const Allocator = std.mem.Allocator;

/// 数据库连接池管理器
/// 支持动态调整连接池大小
pub const ConnectionPoolManager = struct {
    allocator: Allocator,
    config: Config,
    current_size: std.atomic.Value(u32),
    active_connections: std.atomic.Value(u32),
    peak_connections: std.atomic.Value(u32),
    last_scale_time: std.atomic.Value(i64),
    
    pub const Config = struct {
        min_size: u32 = 5,
        max_size: u32 = 50,
        initial_size: u32 = 10,
        scale_up_threshold: f32 = 0.8,  // 80% 使用率时扩容
        scale_down_threshold: f32 = 0.3,  // 30% 使用率时缩容
        scale_interval: i64 = 60,  // 调整间隔（秒）
        scale_step: u32 = 5,  // 每次调整的连接数
    };
    
    pub fn init(allocator: Allocator, config: Config) ConnectionPoolManager {
        return .{
            .allocator = allocator,
            .config = config,
            .current_size = std.atomic.Value(u32).init(config.initial_size),
            .active_connections = std.atomic.Value(u32).init(0),
            .peak_connections = std.atomic.Value(u32).init(0),
            .last_scale_time = std.atomic.Value(i64).init(0),
        };
    }
    
    /// 获取连接时调用
    pub fn onAcquire(self: *ConnectionPoolManager) void {
        const active = self.active_connections.fetchAdd(1, .monotonic) + 1;
        
        // 更新峰值
        const peak = self.peak_connections.load(.monotonic);
        if (active > peak) {
            _ = self.peak_connections.cmpxchgWeak(peak, active, .monotonic, .monotonic);
        }
        
        // 检查是否需要扩容
        self.checkScaleUp();
    }
    
    /// 释放连接时调用
    pub fn onRelease(self: *ConnectionPoolManager) void {
        _ = self.active_connections.fetchSub(1, .monotonic);
        
        // 检查是否需要缩容
        self.checkScaleDown();
    }
    
    /// 检查是否需要扩容
    fn checkScaleUp(self: *ConnectionPoolManager) void {
        const now = std.time.timestamp();
        const last_scale = self.last_scale_time.load(.monotonic);
        
        // 检查调整间隔
        if (now - last_scale < self.config.scale_interval) {
            return;
        }
        
        const current = self.current_size.load(.monotonic);
        const active = self.active_connections.load(.monotonic);
        
        // 计算使用率
        const usage_rate = @as(f32, @floatFromInt(active)) / @as(f32, @floatFromInt(current));
        
        // 如果使用率超过阈值且未达到最大值，则扩容
        if (usage_rate >= self.config.scale_up_threshold and current < self.config.max_size) {
            const new_size = @min(current + self.config.scale_step, self.config.max_size);
            
            if (self.current_size.cmpxchgStrong(current, new_size, .monotonic, .monotonic) == null) {
                _ = self.last_scale_time.cmpxchgStrong(last_scale, now, .monotonic, .monotonic);
                std.log.info("连接池扩容: {d} -> {d} (使用率: {d:.1}%)", .{ current, new_size, usage_rate * 100 });
            }
        }
    }
    
    /// 检查是否需要缩容
    fn checkScaleDown(self: *ConnectionPoolManager) void {
        const now = std.time.timestamp();
        const last_scale = self.last_scale_time.load(.monotonic);
        
        // 检查调整间隔
        if (now - last_scale < self.config.scale_interval) {
            return;
        }
        
        const current = self.current_size.load(.monotonic);
        const active = self.active_connections.load(.monotonic);
        
        // 计算使用率
        const usage_rate = @as(f32, @floatFromInt(active)) / @as(f32, @floatFromInt(current));
        
        // 如果使用率低于阈值且未达到最小值，则缩容
        if (usage_rate <= self.config.scale_down_threshold and current > self.config.min_size) {
            const new_size = @max(current - self.config.scale_step, self.config.min_size);
            
            if (self.current_size.cmpxchgStrong(current, new_size, .monotonic, .monotonic) == null) {
                _ = self.last_scale_time.cmpxchgStrong(last_scale, now, .monotonic, .monotonic);
                std.log.info("连接池缩容: {d} -> {d} (使用率: {d:.1}%)", .{ current, new_size, usage_rate * 100 });
            }
        }
    }
    
    /// 获取当前统计信息
    pub fn getStats(self: *ConnectionPoolManager) Stats {
        const current = self.current_size.load(.monotonic);
        const active = self.active_connections.load(.monotonic);
        const peak = self.peak_connections.load(.monotonic);
        
        return .{
            .current_size = current,
            .active_connections = active,
            .idle_connections = current - active,
            .peak_connections = peak,
            .usage_rate = @as(f32, @floatFromInt(active)) / @as(f32, @floatFromInt(current)),
        };
    }
    
    pub const Stats = struct {
        current_size: u32,
        active_connections: u32,
        idle_connections: u32,
        peak_connections: u32,
        usage_rate: f32,
    };
};
