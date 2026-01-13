//! 工具函数模块 (Utils Module)
//!
//! 提供跨层共享的通用工具函数集合。
//! 所有工具函数都是无状态的，可以安全地在多线程环境中使用。
//!
//! ## 包含的工具
//! - `strings`: 字符串处理工具
//! - `jwt`: JWT 令牌生成和验证
//! - `redis`: Redis 客户端工具
//! - `color`: 终端颜色输出
//! - `regex`: 正则表达式工具
//! - `github`: GitHub API 工具
//! - `tos`: 腾讯云对象存储工具
//! - `webui`: Web UI 工具
//! - `benchmark`: 性能基准测试
//! - `security`: 安全验证模块
//! - `metrics`: 指标收集模块
//! - `health`: 健康检查模块

/// 字符串处理工具
pub const strings = @import("strings.zig");

/// JWT 令牌工具
pub const jwt = @import("jwt.zig");

/// Redis 客户端工具
pub const redis = @import("redis.zig");

/// 终端颜色输出工具
pub const color = @import("color.zig");

/// 正则表达式工具
pub const regex = @import("regex.zig");

/// GitHub API 工具
pub const github = @import("github.zig");

/// 腾讯云对象存储工具
pub const tos = @import("tos.zig");

/// 性能基准测试
pub const benchmark = @import("benchmark.zig");

/// 安全验证模块
pub const security = @import("security.zig");

/// 指标收集模块
pub const metrics = @import("metrics.zig");

/// 健康检查模块
pub const health = @import("health.zig");

/// 工具模块统一访问结构
///
/// 提供所有工具的统一访问点，便于导入和使用。
pub const Utils = struct {
    pub const Strings = strings;
    pub const JWT = jwt;
    pub const Redis = redis;
    pub const Color = color;
    pub const Regex = regex;
    pub const GitHub = github;
    pub const TOS = tos;
    pub const Benchmark = benchmark;
    pub const Security = security;
    pub const Metrics = metrics;
    pub const Health = health;
};
