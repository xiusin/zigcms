//! 基础设施层入口文件
//!
//! 职责：
//! - 提供数据库、缓存、HTTP 客户端等外部服务的实现
//! - 实现领域层定义的仓库接口
//! - 处理外部系统集成
//! - 与外部系统通信的适配器

const std = @import("std");
const logger = @import("../application/services/logger/logger.zig");
const sql = @import("../application/services/sql/orm.zig");

// ============================================================================
// 导出基础设施层模块
// ============================================================================

/// 数据库基础设施
pub const database = @import("database/mod.zig");

/// 缓存基础设施
pub const cache = @import("cache/mod.zig");

/// HTTP 客户端基础设施
pub const http = @import("http/mod.zig");

/// 消息系统基础设施
// pub const messaging = @import("messaging/mod.zig");

// ============================================================================
// 基础设施层配置
// ============================================================================

/// 基础设施层配置
pub const InfraConfig = struct {
    // 数据库连接配置
    db_host: []const u8 = "localhost",
    db_port: u16 = 5432,
    db_name: []const u8 = "zigcms",
    db_user: []const u8 = "postgres",
    db_password: []const u8 = "password",
    db_pool_size: u32 = 10,

    // 缓存配置
    cache_enabled: bool = true,
    cache_backend: cache.CacheBackend = .Memory,
    cache_host: []const u8 = "localhost",
    cache_port: u16 = 6379,
    cache_password: ?[]const u8 = null,
    cache_ttl: u64 = 3600,

    // HTTP 客户端配置
    http_timeout_ms: u32 = 30000,
    http_max_redirects: u32 = 5,
};

// ============================================================================
// 初始化和清理
// ============================================================================

/// 基础设施层初始化函数
pub fn init(allocator: std.mem.Allocator, config: InfraConfig) !*sql.Database {
    // 创建数据库配置
    const db_config = sql.MySQLConfig{
        .host = config.db_host,
        .port = config.db_port,
        .user = config.db_user,
        .password = config.db_password,
        .database = config.db_name,
    };

    // 初始化数据库
    const db = try allocator.create(sql.Database);
    errdefer allocator.destroy(db);

    db.* = try sql.Database.mysql(allocator, db_config);

    // 初始化基础设施组件
    logger.info("基础设施层初始化完成，数据库配置: host={s}, port={}, user={s}", .{ config.db_host, config.db_port, config.db_user });

    return db;
}

/// 基础设施层清理函数
pub fn deinit() void {
    std.debug.print("👋 基础设施层已清理\n", .{});

    // TODO: 关闭数据库连接
    // TODO: 关闭缓存连接
    // TODO: 清理 HTTP 客户端
}
