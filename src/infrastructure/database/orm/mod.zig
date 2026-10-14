//! ORM 模块重导出
//!
//! 从 application/services/sql 重导出 ORM 功能，保持原始实现位置不变。
//! 这是架构重构的过渡方案，避免大量路径修改。

const sql = @import("../../../application/services/sql/mod.zig");

// 重导出所有 ORM 类型
pub const Database = sql.Database;
pub const MySQLConfig = sql.MySQLConfig;
pub const define = sql.define;
pub const ModelQuery = sql.ModelQuery;
pub const HasMany = sql.HasMany;
pub const BelongsTo = sql.BelongsTo;
pub const Migrator = sql.Migrator;
pub const Dialect = sql.Dialect;

// 核心类型
pub const Config = sql.Config;
pub const Value = sql.Value;
pub const PreparedStatement = sql.PreparedStatement;
pub const DB = sql.DB;
pub const Tx = sql.Tx;
pub const Result = sql.Result;
pub const Row = sql.Row;
pub const OrderDir = sql.OrderDir;
pub const JoinType = sql.JoinType;

// Eloquent ORM
pub const Model = sql.Model;
pub const QueryBuilder = sql.QueryBuilder;
pub const Op = sql.Op;
pub const ModelOptions = sql.ModelOptions;

// 驱动接口
pub const Driver = sql.Driver;
pub const DriverType = sql.DriverType;
pub const UnifiedConnection = sql.UnifiedConnection;
pub const SQLiteConfig = sql.SQLiteConfig;
pub const PostgreSQLConfig = sql.PostgreSQLConfig;

// MySQL 驱动
pub const MySQLConnection = sql.MySQLConnection;
pub const ConnectionConfig = sql.ConnectionConfig;
pub const MySQLError = sql.MySQLError;

// SQL 错误处理
pub const SqlError = sql.SqlError;
pub const SqlErrorCode = sql.SqlErrorCode;
pub const SqlErrorBuilder = sql.SqlErrorBuilder;
pub const getLastSqlError = sql.getLastSqlError;
pub const clearLastSqlError = sql.clearLastSqlError;
pub const isRetryableError = sql.isRetryableError;
pub const RetryConfig = sql.RetryConfig;
pub const withRetry = sql.withRetry;

// 高级功能
pub const AdvancedQueryBuilder = sql.AdvancedQueryBuilder;
pub const ConnectionPool = sql.ConnectionPool;
pub const ConnectionPoolConfig = sql.ConnectionPoolConfig;
pub const PoolStats = sql.PoolStats;

// JSON 字段
pub const JsonField = sql.JsonField;
pub const JsonArray = sql.JsonArray;

// 字段绑定
pub const FieldInfo = sql.FieldInfo;
pub const FieldType = sql.FieldType;
pub const ModelFields = sql.ModelFields;

// 便捷函数
pub const open = sql.open;
pub const format = sql.format;
pub const escapeString = sql.escapeString;
pub const escapeBytes = sql.escapeBytes;
