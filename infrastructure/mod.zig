//! 基础设施层入口文件 (Infrastructure Layer)
//!
//! ZigCMS 基础设施层提供与外部系统交互的具体实现。
//! 该层实现领域层定义的仓储接口，处理数据库、缓存、HTTP、Redis 等外部服务。
//!
//! ## 职责
//! - 提供数据库、缓存、HTTP 客户端、Redis 等外部服务的实现
//! - 实现领域层定义的仓库接口
//! - 处理外部系统集成
//! - 与外部系统通信的适配器
//!
//! ## 模块结构
//! - `database`: 数据库连接、ORM 和事务管理
//! - `cache`: 缓存服务（内存、Redis）
//! - `http`: HTTP 客户端
//! - `redis`: Redis 客户端
//! - `messaging`: 消息队列（待实现）
//!
//! ## 使用示例
//! ```zig
//! const infra = @import("infrastructure/mod.zig");
//!
//! // 初始化基础设施层
//! const db = try infra.init(allocator, .{});
//! defer infra.deinit();
//!
//! // 使用数据库 ORM
//! const User = infra.database.orm.define(UserEntity, .{});
//! const users = try User.all(db);
//!
//! // 使用缓存
//! var cache_service = infra.cache.CacheService.init(allocator);
//! try cache_service.set("key", "value", 3600);
//!
//! // 使用 Redis
//! var conn = try infra.redis.connect(.{}, allocator);
//! defer conn.close();
//! ```
//!
//! ## 依赖规则
//! - 基础设施层依赖核心层（core）
//! - 实现领域层定义的仓储接口
//! - 是依赖链的最外层，直接与外部系统交互

const std = @import("std");
const logger = @import("../application/services/logger/logger.zig");
const sql = @import("../application/services/sql/mod.zig");

// ============================================================================
// 公共 API 导出
// ============================================================================

/// 数据库基础设施
///
/// 提供数据库连接管理、事务处理、连接池等功能。
/// 支持多种数据库驱动（SQLite、PostgreSQL、MySQL）。
pub const database = @import("database/mod.zig");

/// 缓存基础设施
///
/// 提供统一的缓存接口，支持多种后端（内存、Redis、Memcached）。
/// 包含 TTL 管理、缓存清理等功能。
pub const cache = @import("cache/mod.zig");

/// HTTP 客户端基础设施
///
/// 提供 HTTP 客户端功能，用于与外部 API 交互。
/// 支持各种 HTTP 方法、超时设置、重试机制。
pub const http = @import("http/mod.zig");

/// Redis 客户端基础设施
///
/// 提供完整的 Redis 客户端功能，支持连接池、所有数据类型操作。
pub const redis = @import("redis/mod.zig");

/// 消息系统基础设施（待实现）
///
/// 提供消息队列功能，用于异步任务处理和事件驱动架构。
// pub const messaging = @import("messaging/mod.zig");

// ============================================================================
// 层配置
// ============================================================================

/// 基础设施层配置
///
/// 配置数据库连接、缓存服务、HTTP 客户端等外部服务参数。
pub const InfraConfig = struct {
    pub const DatabaseEngine = enum { sqlite, mysql };

    // 数据库连接配置
    db_engine: DatabaseEngine = .sqlite,
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
// 生命周期管理
// ============================================================================

/// 初始化基础设施层
///
/// 在应用程序启动时调用，初始化数据库连接和其他外部服务。
///
/// ## 参数
/// - `allocator`: 内存分配器
/// - `config`: 基础设施层配置
///
/// ## 返回
/// 返回初始化的数据库实例指针。
///
/// ## 错误
/// 如果数据库连接失败，返回相应的错误。
pub fn init(allocator: std.mem.Allocator, config: InfraConfig) !*sql.Database {
    const db = try allocator.create(sql.Database);
    errdefer allocator.destroy(db);

    switch (config.db_engine) {
        .sqlite => {
            db.* = sql.Database.sqlite(allocator, config.db_name) catch |e| {
                return e;
            };
            logger.info("基础设施层初始化完成，使用 SQLite 数据库({s})", .{config.db_name});
        },
        .mysql => {
            const mysql_cfg = sql.MySQLConfig{
                .host = config.db_host,
                .port = config.db_port,
                .user = config.db_user,
                .password = config.db_password,
                .database = config.db_name,
                .min_connections = 2,
                .max_connections = @max(2, config.db_pool_size),
                .keepalive_interval_ms = 0,
            };

            db.* = sql.Database.mysql(allocator, mysql_cfg) catch |e| {
                logger.err("MySQL 数据库初始化失败: {any}", .{e});
                return e;
            };
            logger.info("基础设施层初始化完成，使用 MySQL 数据库 {s}@{s}:{d}", .{ config.db_name, config.db_host, config.db_port });
        },
    }

    return db;
}

/// 清理基础设施层
///
/// 在应用程序关闭时调用，关闭数据库连接和其他外部服务。
///
/// 注意：基础设施层的实际清理由 root.zig 的 deinitSystem 统一管理：
/// - 数据库连接通过 infrastructure_db 变量清理
/// - 缓存连接通过 ServiceManager 清理
/// - HTTP 客户端资源通过其自身的 deinit 方法清理
///
/// 此函数保留用于独立的清理场景，不应在正常流程中直接调用。
pub fn deinit() void {
    std.debug.print("👋 基础设施层已清理\n", .{});
}
