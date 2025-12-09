//! SQL ORM 模块
//!
//! 提供完整的多数据库 ORM 功能（MySQL/SQLite/PostgreSQL）：
//! - 安全的参数绑定（防SQL注入）
//! - Laravel 风格的 Eloquent 模型
//! - 链式查询构建器
//! - 事务支持
//! - 软删除
//! - 时间戳自动管理
//!
//! ## 快速开始
//!
//! ```zig
//! const sql = @import("services").sql;
//!
//! // 定义模型
//! const User = sql.Model(struct {
//!     pub const table = "users";
//!     pub const soft_deletes = true;
//!
//!     id: u64,
//!     name: []const u8,
//!     email: []const u8,
//!     age: ?u32 = null,
//! });
//!
//! // 查询
//! var query = User.where(allocator, "age", .{ ">", 18 })
//!     .orderByDesc("created_at")
//!     .limit(10);
//! defer query.deinit();
//!
//! const sql = try query.toSql();
//! defer allocator.free(sql);
//! ```

const std = @import("std");

// 核心模块
pub const core = @import("query.zig");
pub const eloquent = @import("model.zig");
pub const advanced = @import("advanced.zig");
pub const driver = @import("driver.zig");
pub const orm = @import("orm.zig");
pub const interface = @import("interface.zig");

// 重导出常用类型
pub const Config = core.Config;
pub const Value = core.Value;
pub const PreparedStatement = core.PreparedStatement;
pub const DB = core.DB;
pub const Tx = core.Tx;
pub const Result = core.Result;
pub const Row = core.Row;
pub const OrderDir = core.OrderDir;
pub const JoinType = core.JoinType;

// Eloquent ORM
pub const Model = eloquent.Model;
pub const QueryBuilder = eloquent.QueryBuilder;
pub const Op = eloquent.Op;
pub const ModelOptions = eloquent.ModelOptions;

// 驱动接口（统一抽象）
pub const Driver = interface.Driver;
pub const DriverType = interface.DriverType;
pub const UnifiedConnection = interface.Connection;
pub const SQLiteConfig = interface.SQLiteConfig;
pub const PostgreSQLConfig = interface.PostgreSQLConfig;

// MySQL原生驱动
pub const MySQLConnection = driver.Connection;
pub const ConnectionConfig = driver.ConnectionConfig;
pub const MySQLError = driver.MySQLError;

// 高阶ORM
pub const Database = orm.Database;
pub const MySQLConfig = orm.MySQLConfig;  // MySQL配置（包含连接池选项）
pub const define = orm.define;
pub const ModelQuery = orm.ModelQuery;
pub const HasMany = orm.HasMany;
pub const BelongsTo = orm.BelongsTo;

// 内部实现（不导出，用户不需要）
// ConnectionPool、Transaction 等由 Database 内部自动管理

// 高级功能
pub const AdvancedQueryBuilder = advanced.AdvancedQueryBuilder;
pub const AggregateType = advanced.AggregateType;
pub const AggregateExpr = advanced.AggregateExpr;
pub const Subquery = advanced.Subquery;
pub const SubqueryType = advanced.SubqueryType;
pub const GlobalScope = advanced.GlobalScope;
pub const ScopeManager = advanced.ScopeManager;
pub const ModelEvent = advanced.ModelEvent;
pub const ModelEventPayload = advanced.ModelEventPayload;
pub const ModelEventHandler = advanced.ModelEventHandler;
pub const ModelObserver = advanced.ModelObserver;
pub const ConnectionPool = advanced.ConnectionPool;
pub const ConnectionPoolConfig = advanced.ConnectionPoolConfig;
pub const PoolStats = advanced.PoolStats;

// 便捷函数
pub const open = core.open;
pub const format = core.format;
pub const escapeString = core.escapeString;
pub const escapeBytes = core.escapeBytes;

// 测试
test {
    std.testing.refAllDecls(@This());
}
