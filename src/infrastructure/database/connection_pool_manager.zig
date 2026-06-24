const std = @import("std");
const orm = @import("../../application/services/sql/orm.zig");

/// 连接池监控器
///
/// 对接 ORM 层 ConnectionPool，提供外部可观测性：
/// - 定时采集池统计信息（总量/活跃/空闲）
/// - 接近容量上限时发出警告
/// - 跟踪峰值使用量
/// - 健康检查
///
/// 注意：本监控器只读不写，不参与连接的实际管理。
/// 连接的获取/释放/回收/健康检查由 ORM 层 ConnectionPool 负责。
pub const PoolMonitor = struct {
    pool: *orm.ConnectionPool,
    config: Config,
    peak_active: usize = 0,
    last_check_time: i64 = 0,

    pub const Config = struct {
        /// 活跃连接数警告阈值（比例，默认 0.75 = 75%）
        warn_threshold: f32 = 0.75,
        /// 活跃连接数临界阈值（比例，默认 0.90 = 90%）
        critical_threshold: f32 = 0.90,
        /// 检查间隔（秒），0 表示仅手动检查
        check_interval_secs: i64 = 30,
        /// 是否启用日志输出
        enable_logging: bool = true,
        /// 日志前缀
        log_prefix: []const u8 = "[PoolMonitor]",
    };

    pub fn init(pool: *sql.ConnectionPool, config: Config) PoolMonitor {
        return .{
            .pool = pool,
            .config = config,
        };
    }

    /// 执行一次检查，返回池状态
    pub fn check(self: *PoolMonitor) Status {
        const stats = self.pool.getStats();
        const max_size = self.pool.config.max_size;

        if (stats.active > self.peak_active) {
            self.peak_active = stats.active;
        }

        const usage_rate: f32 = if (max_size > 0)
            @as(f32, @floatFromInt(stats.active)) / @as(f32, @floatFromInt(max_size))
        else
            0.0;

        const level: AlertLevel = if (usage_rate >= self.config.critical_threshold)
            .critical
        else if (usage_rate >= self.config.warn_threshold)
            .warning
        else
            .normal;

        self.last_check_time = std.time.timestamp();

        if (self.config.enable_logging) {
            switch (level) {
                .critical => std.log.err("{s} 连接池接近饱和! 活跃={d}/{d} ({d:.1}%) 空闲={d} 峰值={d}", .{
                    self.config.log_prefix,
                    stats.active, max_size, usage_rate * 100,
                    stats.idle, self.peak_active,
                }),
                .warning => std.log.warn("{s} 连接池使用率较高: 活跃={d}/{d} ({d:.1}%) 空闲={d}", .{
                    self.config.log_prefix,
                    stats.active, max_size, usage_rate * 100,
                    stats.idle,
                }),
                .normal => std.log.info("{s} 连接池正常: 活跃={d}/{d} ({d:.1}%) 空闲={d}", .{
                    self.config.log_prefix,
                    stats.active, max_size, usage_rate * 100,
                    stats.idle,
                }),
            }
        }

        return .{
            .total = stats.total,
            .active = stats.active,
            .idle = stats.idle,
            .max_size = max_size,
            .peak_active = self.peak_active,
            .usage_rate = usage_rate,
            .alert_level = level,
            .healthy = self.pool.isHealthy(),
        };
    }

    /// 启动后台监控线程
    pub fn startMonitoring(self: *PoolMonitor, allocator: std.mem.Allocator) !std.Thread {
        if (self.config.check_interval_secs == 0) return error.IntervalNotSet;
        return try std.Thread.spawn(.{}, monitorWorker, .{ self, allocator });
    }

    fn monitorWorker(self: *PoolMonitor, allocator: std.mem.Allocator) void {
        _ = allocator;
        while (true) {
            const interval_ns = @as(u64, @intCast(self.config.check_interval_secs)) * std.time.ns_per_s;
            std.time.sleep(interval_ns);

            const status = self.check();

            if (status.alert_level == .critical) {
                if (!status.healthy) {
                    std.log.err("{s} 连接池不健康，需要立即关注!", .{self.config.log_prefix});
                }
            }

            if (self.pool.closed) break;
        }
    }

    pub const AlertLevel = enum {
        normal,
        warning,
        critical,
    };

    pub const Status = struct {
        total: usize,
        active: usize,
        idle: usize,
        max_size: usize,
        peak_active: usize,
        usage_rate: f32,
        alert_level: AlertLevel,
        healthy: bool,
    };
};

test "PoolMonitor: basic check" {
    _ = PoolMonitor;
}