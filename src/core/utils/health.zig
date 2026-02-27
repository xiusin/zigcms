//! 健康检查工具模块
//!
//! 提供系统健康检查相关的工具函数。

const std = @import("std");

/// 健康状态
pub const HealthStatus = enum {
    Healthy,
    Degraded,
    Unhealthy,
};

/// 健康检查结果
pub const HealthCheckResult = struct {
    status: HealthStatus,
    message: []const u8,
    duration_ms: u64,
    details: ?std.StringHashMap([]const u8) = null,
};

/// 系统健康信息
pub const SystemHealth = struct {
    status: HealthStatus,
    uptime_seconds: u64,
    memory_used_bytes: u64,
    checks: []HealthCheckResult,
};

/// 健康检查器接口
pub const HealthChecker = struct {
    name: []const u8,
    check_fn: *const fn () HealthCheckResult,

    pub fn check(self: HealthChecker) HealthCheckResult {
        return self.check_fn();
    }
};
