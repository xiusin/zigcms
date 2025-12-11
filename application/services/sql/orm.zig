//! MySQL ORM - 高阶 Eloquent 风格 ORM
//!
//! 提供类似 Laravel Eloquent 的模型操作，支持真正的数据库交互。
//!
//! ## 使用示例
//!
//! ```zig
//! const orm = @import("services").sql.orm;
//!
//! // 定义模型
//! const User = orm.define(struct {
//!     pub const table_name = "users";
//!     pub const primary_key = "id";
//!
//!     id: u64,
//!     name: []const u8,
//!     email: []const u8,
//!     age: ?u32 = null,
//!     created_at: ?[]const u8 = null,
//! });
//!
//! // 使用
//! var db = try orm.Database.init(allocator, config);
//! defer db.deinit();
//!
//! // 查询
//! const users = try User.query(&db)
//!     .where("age", ">", 18)
//!     .orderBy("created_at", .desc)
//!     .limit(10)
//!     .get();
//!
//! // 创建
//! const user = try User.create(&db, .{
//!     .name = "张三",
//!     .email = "zhangsan@example.com",
//! });
//!
//! // 更新
//! try User.find(&db, 1).?.update(.{ .name = "李四" });
//!
//! // 删除
//! try User.destroy(&db, 1);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("interface.zig");
const query_mod = @import("query.zig");
const logger_mod = @import("../logger/logger.zig");

pub const OrderDir = query_mod.OrderDir;

// ============================================================================
// 公共辅助函数
// ============================================================================

/// 格式化 WHERE 条件（顶层函数，供多处使用）
pub fn formatWhere(allocator: Allocator, field: []const u8, op: []const u8, value: anytype) ![]u8 {
    const V = @TypeOf(value);
    const type_info = @typeInfo(V);

    if (V == []const u8) {
        return std.fmt.allocPrint(allocator, "{s} {s} '{s}'", .{ field, op, value });
    } else if (type_info == .pointer and type_info.pointer.size == .one) {
        // 处理字符串字面量类型 *const [N:0]u8
        const child_info = @typeInfo(type_info.pointer.child);
        if (child_info == .array and child_info.array.child == u8) {
            const str: []const u8 = value;
            return std.fmt.allocPrint(allocator, "{s} {s} '{s}'", .{ field, op, str });
        }
        return std.fmt.allocPrint(allocator, "{s} {s} NULL", .{ field, op });
    } else if (type_info == .int or type_info == .comptime_int) {
        return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, value });
    } else if (type_info == .float or type_info == .comptime_float) {
        return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, value });
    } else if (V == bool) {
        return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, @as(u8, if (value) 1 else 0) });
    } else {
        return std.fmt.allocPrint(allocator, "{s} {s} NULL", .{ field, op });
    }
}

/// 将数据库结果映射到模型（顶层泛型函数）
pub fn mapResults(comptime T: type, allocator: Allocator, result: *interface.ResultSet) ![]T {
    var models = std.ArrayListUnmanaged(T){};
    errdefer models.deinit(allocator);

    const fields = std.meta.fields(T);
    var field_indices: [fields.len]?usize = .{null} ** fields.len;

    // 缓存字段映射索引：将模型字段名映射到 ResultSet 列索引
    if (result.field_names.len > 0) {
        for (result.field_names, 0..) |col_name, col_idx| {
            inline for (fields, 0..) |field, f_idx| {
                if (std.mem.eql(u8, col_name, field.name)) {
                    field_indices[f_idx] = col_idx;
                }
            }
        }
    }

    while (result.next()) |row| {
        var model: T = undefined;

        inline for (fields, 0..) |field, f_idx| {
            // 使用缓存索引直接获取值，避免 O(N) 字符串查找
            var value: ?[]const u8 = null;
            if (field_indices[f_idx]) |idx| {
                if (idx < row.values.len) {
                    value = row.values[idx];
                }
            }

            if (@typeInfo(field.type) == .optional) {
                if (value) |v| {
                    @field(model, field.name) = try allocator.dupe(u8, v);
                } else {
                    @field(model, field.name) = null;
                }
            } else if (field.type == []const u8) {
                if (value) |v| {
                    @field(model, field.name) = try allocator.dupe(u8, v);
                } else {
                    @field(model, field.name) = "";
                }
            } else if (@typeInfo(field.type) == .int) {
                if (value) |v| {
                    @field(model, field.name) = std.fmt.parseInt(field.type, v, 10) catch 0;
                } else {
                    @field(model, field.name) = 0;
                }
            } else if (@typeInfo(field.type) == .float) {
                if (value) |v| {
                    @field(model, field.name) = std.fmt.parseFloat(field.type, v) catch 0;
                } else {
                    @field(model, field.name) = 0;
                }
            } else if (field.type == bool) {
                @field(model, field.name) = if (value) |v| std.mem.eql(u8, v, "1") else false;
            }
        }

        try models.append(allocator, model);
    }

    return models.toOwnedSlice(allocator);
}

// ============================================================================
// 数据库管理器
// ============================================================================

/// MySQL 配置（扩展）
pub const MySQLConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 3306,
    user: []const u8 = "root",
    password: []const u8 = "",
    database: []const u8,

    // 连接池配置（可选）
    min_connections: usize = 2,
    max_connections: usize = 10,
    acquire_timeout_ms: u64 = 5000,
    max_idle_time_ms: u64 = 300_000,
    max_lifetime_ms: u64 = 1_800_000,
    transaction_timeout_ms: u64 = 30_000,
    /// 连接保活间隔（毫秒），0 禁用，默认 60 秒
    keepalive_interval_ms: u64 = 60_000,
};

/// 数据库管理器 - 使用统一驱动接口
pub const Database = struct {
    allocator: Allocator,
    conn: interface.Connection,
    pool: ?*ConnectionPool = null, // 内部连接池（MySQL 使用）
    driver_type: interface.DriverType,
    debug: bool = false,
    enable_logging: bool = false,
    logger: ?*logger_mod.Logger = null,

    /// 从统一连接创建
    pub fn fromConnection(allocator: Allocator, conn: interface.Connection) Database {
        return .{
            .allocator = allocator,
            .conn = conn,
            .pool = null,
            .driver_type = conn.getDriverType(),
        };
    }

    /// 创建 SQLite 数据库（开发/测试）
    pub fn sqlite(allocator: Allocator, path: []const u8) !Database {
        var conn = try interface.Driver.sqlite(allocator, path);

        // 启用 WAL 模式
        _ = try conn.exec("PRAGMA journal_mode=WAL");
        _ = try conn.exec("PRAGMA synchronous=NORMAL");

        return .{
            .allocator = allocator,
            .conn = conn,
            .pool = null,
            .driver_type = .sqlite,
        };
    }

    /// 创建 MySQL 数据库（内部自动使用连接池）
    pub fn mysql(allocator: Allocator, config: MySQLConfig) !Database {
        // 创建内部连接池
        const pool = try allocator.create(ConnectionPool);
        errdefer allocator.destroy(pool);

        pool.* = try ConnectionPool.init(allocator, .{
            .host = config.host,
            .port = config.port,
            .user = config.user,
            .password = config.password,
            .database = config.database,
        }, .{
            .min_size = config.min_connections,
            .max_size = config.max_connections,
            .acquire_timeout_ms = config.acquire_timeout_ms,
            .max_idle_time_ms = config.max_idle_time_ms,
            .max_lifetime_ms = config.max_lifetime_ms,
            .transaction_timeout_ms = config.transaction_timeout_ms,
            .keepalive_interval_ms = config.keepalive_interval_ms,
        });

        // 获取一个连接作为 Database.conn（用于兼容性）
        const pooled = try pool.acquire();

        return .{
            .allocator = allocator,
            .conn = pooled.conn,
            .pool = pool,
            .driver_type = .mysql,
        };
    }

    /// 创建内存数据库（纯测试）
    pub fn memory(allocator: Allocator) !Database {
        return .{
            .allocator = allocator,
            .conn = try interface.Driver.memory(allocator),
            .pool = null,
            .driver_type = .memory,
        };
    }

    /// 创建 PostgreSQL 数据库（pg.Pool 内部已线程安全）
    pub fn postgres(allocator: Allocator, config: interface.PostgreSQLConfig) !Database {
        return .{
            .allocator = allocator,
            .conn = try interface.Driver.postgres(allocator, config),
            .pool = null,
            .driver_type = .postgresql,
        };
    }

    pub fn deinit(self: *Database) void {
        // 如果有连接池，只释放连接池（池中的连接会被自动释放）
        if (self.pool) |pool| {
            pool.deinit();
            self.allocator.destroy(pool);
        } else {
            // 只有非池化连接才需要手动释放
            self.conn.deinit();
        }
    }

    /// 执行原始查询（内部自动使用连接池，支持失败重试）
    pub fn rawQuery(self: *Database, sql_query: []const u8) !interface.ResultSet {
        const start_time = std.time.nanoTimestamp();

        if (self.logger) |log| {
            if (self.debug) log.debug("[SQL] {s}", .{sql_query});
        } else if (self.debug) {
            std.debug.print("[SQL] {s}\n", .{sql_query});
        }

        var retry_count: u32 = 0;
        // 最多重试1次
        while (retry_count <= 1) : (retry_count += 1) {
            // MySQL：从连接池获取连接
            var pooled_conn: ?*PooledConnection = null;
            var conn = if (self.pool) |pool| blk: {
                pooled_conn = try pool.acquire();
                break :blk pooled_conn.?.conn;
            } else self.conn;

            // 确保归还连接
            defer if (pooled_conn) |pc| {
                if (self.pool) |pool| pool.release(pc);
            };

            const result = conn.query(sql_query) catch |err| {
                const is_conn_error = switch (err) {
                    error.ConnectionFailed, error.ConnectionLost, error.ServerGone, error.BrokenPipe => true,
                    else => false,
                };

                if (is_conn_error) {
                    if (pooled_conn) |pc| {
                        pc.broken = true; // 标记为损坏，归还时会被销毁
                        if (retry_count < 1) {
                            // 准备重试，continue 会触发 defer 释放当前连接
                            continue;
                        }
                    }
                }

                const elapsed_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start_time)) / 1_000_000.0;

                if (self.logger) |log| {
                    if (self.enable_logging) {
                        log.err("Query failed: {s}", .{@errorName(err)});
                        log.err("SQL: {s}", .{sql_query});
                        log.err("Duration: {d:.2}ms", .{elapsed_ms});
                    }
                } else if (self.enable_logging) {
                    std.debug.print("[ERROR] Query failed: {s}\n", .{@errorName(err)});
                    std.debug.print("[ERROR] SQL: {s}\n", .{sql_query});
                    std.debug.print("[ERROR] Duration: {d:.2}ms\n", .{elapsed_ms});
                }
                return err;
            };

            const elapsed_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start_time)) / 1_000_000.0;
            const row_count = result.rowCount();

            if (self.logger) |log| {
                if (self.enable_logging) {
                    log.info("Query executed: {d} rows, {d:.2}ms", .{ row_count, elapsed_ms });
                    log.debug("SQL: {s}", .{sql_query});
                }
            } else if (self.enable_logging) {
                std.debug.print("[INFO] Query executed: {d} rows, {d:.2}ms\n", .{ row_count, elapsed_ms });
                std.debug.print("[SQL] {s}\n", .{sql_query});
            }

            return result;
        }
        return error.QueryFailed; // Should not reach here
    }

    /// 执行原始命令（内部自动使用连接池，支持失败重试）
    pub fn rawExec(self: *Database, sql_query: []const u8) !u64 {
        const start_time = std.time.nanoTimestamp();

        if (self.logger) |log| {
            if (self.debug) log.debug("[SQL] {s}", .{sql_query});
        } else if (self.debug) {
            std.debug.print("[SQL] {s}\n", .{sql_query});
        }

        var retry_count: u32 = 0;
        // 最多重试1次
        while (retry_count <= 1) : (retry_count += 1) {
            // MySQL：从连接池获取连接
            var pooled_conn: ?*PooledConnection = null;
            var conn = if (self.pool) |pool| blk: {
                pooled_conn = try pool.acquire();
                break :blk pooled_conn.?.conn;
            } else self.conn;

            // 确保归还连接
            defer if (pooled_conn) |pc| {
                if (self.pool) |pool| pool.release(pc);
            };

            const affected = conn.exec(sql_query) catch |err| {
                const is_conn_error = switch (err) {
                    error.ConnectionFailed, error.ConnectionLost, error.ServerGone, error.BrokenPipe => true,
                    else => false,
                };

                if (is_conn_error) {
                    if (pooled_conn) |pc| {
                        pc.broken = true;
                        if (retry_count < 1) {
                            continue;
                        }
                    }
                }

                const elapsed_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start_time)) / 1_000_000.0;

                if (self.logger) |log| {
                    if (self.enable_logging) {
                        log.err("Exec failed: {s}", .{@errorName(err)});
                        log.err("SQL: {s}", .{sql_query});
                        log.err("Duration: {d:.2}ms", .{elapsed_ms});
                    }
                } else if (self.enable_logging) {
                    std.debug.print("[ERROR] Exec failed: {s}\n", .{@errorName(err)});
                    std.debug.print("[ERROR] SQL: {s}\n", .{sql_query});
                    std.debug.print("[ERROR] Duration: {d:.2}ms\n", .{elapsed_ms});
                }
                return err;
            };

            const elapsed_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start_time)) / 1_000_000.0;

            if (self.logger) |log| {
                if (self.enable_logging) {
                    log.info("Exec executed: {d} rows affected, {d:.2}ms", .{ affected, elapsed_ms });
                    log.debug("SQL: {s}", .{sql_query});
                }
            } else if (self.enable_logging) {
                std.debug.print("[INFO] Exec executed: {d} rows affected, {d:.2}ms\n", .{ affected, elapsed_ms });
                std.debug.print("[SQL] {s}\n", .{sql_query});
            }

            return affected;
        }
        return error.QueryFailed;
    }

    /// 开始事务（MySQL 使用连接池事务）
    pub fn beginTransaction(self: *Database) !void {
        if (self.pool) |_| {
            // MySQL：使用 Transaction 对象更安全
            return error.UseTransactionObject;
        }
        try self.conn.beginTransaction();
    }

    /// 提交事务
    pub fn commit(self: *Database) !void {
        try self.conn.commit();
    }

    /// 回滚事务
    pub fn rollback(self: *Database) !void {
        try self.conn.rollback();
    }

    /// 执行事务（自动管理）
    pub fn transaction(self: *Database, comptime func: anytype, args: anytype) !void {
        // MySQL：使用连接池事务
        if (self.pool) |pool| {
            var tx = try Transaction.init(pool);
            defer tx.deinit();

            @call(.auto, func, .{&tx} ++ args) catch |err| {
                try tx.rollback();
                return err;
            };

            try tx.commit();
            return;
        }

        // PostgreSQL/SQLite：使用简单事务
        try self.beginTransaction();

        @call(.auto, func, .{self} ++ args) catch |err| {
            try self.rollback();
            return err;
        };

        try self.commit();
    }

    /// 获取驱动类型
    pub fn getDriverType(self: *const Database) interface.DriverType {
        return self.driver_type;
    }

    /// 获取最后插入的 ID
    pub fn lastInsertId(self: *Database) u64 {
        return self.conn.lastInsertId();
    }
};

// ============================================================================
// 模型构建器
// ============================================================================

/// 数据库方言
pub const Dialect = enum { mysql, sqlite, postgresql };

/// 模型配置
pub const ModelConfig = struct {
    table_name: ?[]const u8 = null,
    primary_key: ?[]const u8 = null,
};

/// 定义模型
pub fn define(comptime T: type) type {
    return defineWithConfig(T, .{});
}

/// 定义模型（带配置）
pub fn defineWithConfig(comptime T: type, comptime config: ModelConfig) type {
    return struct {
        const Self = @This();
        /// 原始模型结构体类型（用于关联查询）
        pub const Model = T;

        // ====================================================================
        // 默认数据库连接 - 实现 Laravel 风格无 db 参数调用
        // ====================================================================

        /// 默认数据库连接（可选）
        var default_db: ?*Database = null;

        /// 设置默认数据库连接
        /// 使用: Product.use(&db);
        /// 之后: Product.where("name", "=", "test").get()
        pub fn use(db: *Database) void {
            default_db = db;
        }

        /// 获取默认数据库连接
        pub fn getDb() *Database {
            return default_db orelse @panic("Model has no default database. Call Model.use(&db) first.");
        }

        /// 检查是否设置了默认连接
        pub fn hasDb() bool {
            return default_db != null;
        }

        /// 获取表名
        pub fn tableName() []const u8 {
            if (config.table_name) |n| return n;
            if (@hasDecl(T, "table_name")) {
                return T.table_name;
            }
            return @typeName(T);
        }

        /// 获取主键名
        pub fn primaryKey() []const u8 {
            if (config.primary_key) |k| return k;
            if (@hasDecl(T, "primary_key")) {
                return T.primary_key;
            }
            return "id";
        }

        // ====================================================================
        // 数据库迁移 - Schema 生成
        // ====================================================================

        /// 将 Zig 类型映射到 SQL 类型（编译期）
        fn zigTypeToSqlType(comptime ZigType: type, comptime dialect: Dialect, comptime field_name: []const u8) []const u8 {
            const is_primary = std.mem.eql(u8, field_name, primaryKey());
            const type_info = @typeInfo(ZigType);

            if (type_info == .optional) {
                return zigTypeToSqlType(type_info.optional.child, dialect, field_name);
            }

            if (ZigType == []const u8) {
                if (std.mem.endsWith(u8, field_name, "content") or
                    std.mem.endsWith(u8, field_name, "description") or
                    std.mem.endsWith(u8, field_name, "body"))
                {
                    return switch (dialect) {
                        .mysql => "LONGTEXT",
                        .sqlite, .postgresql => "TEXT",
                    };
                }
                return switch (dialect) {
                    .mysql, .postgresql => "VARCHAR(255)",
                    .sqlite => "TEXT",
                };
            }

            if (type_info == .int) {
                const bits = type_info.int.bits;
                if (is_primary) {
                    return switch (dialect) {
                        .mysql => if (bits <= 32) "INT AUTO_INCREMENT" else "BIGINT AUTO_INCREMENT",
                        .sqlite => "INTEGER",
                        .postgresql => if (bits <= 32) "SERIAL" else "BIGSERIAL",
                    };
                }
                return switch (dialect) {
                    .mysql => if (bits <= 8) "TINYINT" else if (bits <= 16) "SMALLINT" else if (bits <= 32) "INT" else "BIGINT",
                    .sqlite => "INTEGER",
                    .postgresql => if (bits <= 16) "SMALLINT" else if (bits <= 32) "INTEGER" else "BIGINT",
                };
            }

            if (type_info == .float) {
                const bits = type_info.float.bits;
                return switch (dialect) {
                    .mysql => if (bits <= 32) "FLOAT" else "DOUBLE",
                    .sqlite => "REAL",
                    .postgresql => if (bits <= 32) "REAL" else "DOUBLE PRECISION",
                };
            }

            if (ZigType == bool) {
                return switch (dialect) {
                    .mysql => "TINYINT(1)",
                    .sqlite => "INTEGER",
                    .postgresql => "BOOLEAN",
                };
            }

            return switch (dialect) {
                .mysql, .postgresql => "VARCHAR(255)",
                .sqlite => "TEXT",
            };
        }

        /// 生成 CREATE TABLE SQL 语句（编译期）
        pub fn createTableSql(comptime dialect: Dialect) []const u8 {
            comptime {
                const fields = std.meta.fields(T);
                const pk = primaryKey();
                const tbl = tableName();

                var pure_table_name: []const u8 = tbl;
                for (tbl, 0..) |c, i| {
                    if (c == '.') {
                        pure_table_name = tbl[i + 1 ..];
                        break;
                    }
                }

                var sql: []const u8 = "CREATE TABLE IF NOT EXISTS " ++ pure_table_name ++ " (\n";
                var first_field = true;

                for (fields) |field| {
                    if (@hasDecl(T, "ignore_fields")) {
                        var skip = false;
                        for (T.ignore_fields) |ignore| {
                            if (std.mem.eql(u8, field.name, ignore)) {
                                skip = true;
                                break;
                            }
                        }
                        if (skip) continue;
                    }

                    const is_pk = std.mem.eql(u8, field.name, pk);
                    const sql_type = zigTypeToSqlType(field.type, dialect, field.name);

                    if (!first_field) sql = sql ++ ",\n";
                    first_field = false;
                    sql = sql ++ "    " ++ field.name ++ " " ++ sql_type;

                    if (is_pk and dialect != .sqlite) {
                        sql = sql ++ " NOT NULL";
                    }
                }

                sql = sql ++ ",\n    PRIMARY KEY (" ++ pk ++ ")\n)";

                if (dialect == .mysql) {
                    sql = sql ++ " ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
                }

                return sql ++ ";";
            }
        }

        /// 生成 DROP TABLE SQL 语句
        pub fn dropTableSql() []const u8 {
            const tbl = tableName();
            comptime var pure_table_name: []const u8 = tbl;
            inline for (tbl, 0..) |c, i| {
                if (c == '.') {
                    pure_table_name = tbl[i + 1 ..];
                    break;
                }
            }
            return "DROP TABLE IF EXISTS " ++ pure_table_name ++ ";";
        }

        /// 执行建表
        pub fn createTable(db: *Database) !void {
            const dialect: Dialect = switch (db.driver_type) {
                .mysql => .mysql,
                .sqlite, .memory => .sqlite,
                .postgresql => .postgresql,
            };
            const sql_str = switch (dialect) {
                .mysql => createTableSql(.mysql),
                .sqlite => createTableSql(.sqlite),
                .postgresql => createTableSql(.postgresql),
            };
            _ = try db.rawExec(sql_str);
        }

        /// 执行删表
        pub fn dropTable(db: *Database) !void {
            _ = try db.rawExec(dropTableSql());
        }

        /// 释放模型中的字符串内存
        /// 注意：只释放长度大于0且指针有效的字符串
        pub fn freeModel(allocator: Allocator, model: *T) void {
            inline for (std.meta.fields(T)) |field| {
                if (field.type == []const u8) {
                    const str = @field(model.*, field.name);
                    // 只释放非空字符串（空字符串 "" 是静态分配的）
                    if (str.len > 0 and str.ptr != "".ptr) {
                        allocator.free(str);
                    }
                } else if (@typeInfo(field.type) == .optional) {
                    const ChildType = @typeInfo(field.type).optional.child;
                    if (ChildType == []const u8) {
                        if (@field(model.*, field.name)) |str| {
                            if (str.len > 0 and str.ptr != "".ptr) {
                                allocator.free(str);
                            }
                        }
                    }
                }
            }
        }

        /// 释放模型数组
        pub fn freeModels(allocator: Allocator, models: []T) void {
            for (models) |*model| {
                freeModel(allocator, model);
            }
            allocator.free(models);
        }

        // ====================================================================
        // ModelList - 自动管理内存的模型列表包装器
        // ====================================================================

        /// 模型列表包装器，自动管理内存释放
        /// 使用示例：
        /// ```zig
        /// var list = try Product.collect(db);
        /// defer list.deinit();
        /// for (list.items()) |p| { ... }
        /// ```
        pub const List = struct {
            allocator: Allocator,
            data: []T,

            /// 获取所有项
            pub fn items(self: *const List) []T {
                return self.data;
            }

            /// 获取第一个
            pub fn first(self: *const List) ?T {
                if (self.data.len == 0) return null;
                return self.data[0];
            }

            /// 获取最后一个
            pub fn last(self: *const List) ?T {
                if (self.data.len == 0) return null;
                return self.data[self.data.len - 1];
            }

            /// 获取数量
            pub fn count(self: *const List) usize {
                return self.data.len;
            }

            /// 是否为空
            pub fn isEmpty(self: *const List) bool {
                return self.data.len == 0;
            }

            /// 是否非空
            pub fn isNotEmpty(self: *const List) bool {
                return self.data.len > 0;
            }

            /// 获取指定索引
            pub fn get(self: *const List, index: usize) ?T {
                if (index >= self.data.len) return null;
                return self.data[index];
            }

            /// 遍历并执行函数
            pub fn each(self: *const List, func: fn (T) void) void {
                for (self.data) |item| {
                    func(item);
                }
            }

            // 注意：由于 Zig 编译时限制，pluck 通过迭代器模式实现
            // 使用: for (list.items()) |item| { _ = item.field_name; }

            /// 释放所有内存
            pub fn deinit(self: *List) void {
                freeModels(self.allocator, self.data);
                self.data = &.{};
            }
        };

        /// 创建 List 包装器（从已有数据）
        pub fn toList(allocator: Allocator, data: []T) List {
            return List{ .allocator = allocator, .data = data };
        }

        /// 获取所有记录（返回 List）
        pub fn collect(db: *Database) !List {
            const data = try all(db);
            return List{ .allocator = db.allocator, .data = data };
        }

        /// 创建查询构建器
        pub fn query(db: *Database) ModelQuery(T) {
            return ModelQuery(T).init(db, tableName());
        }

        // ====================================================================
        // 静态快捷方法 - Laravel 风格
        // 用法: Product.where(db, "name", "=", "test").get()
        // ====================================================================

        /// 静态 where - 创建查询并添加条件
        /// 用法: Product.where(db, "category", "=", "电子").get()
        pub fn where(db: *Database, field: []const u8, op: []const u8, value: anytype) ModelQuery(T) {
            var q = query(db);
            _ = q.where(field, op, value);
            return q;
        }

        /// 静态 whereEq - 等于条件
        /// 用法: Product.whereEq(db, "category", "电子").get()
        pub fn whereEq(db: *Database, field: []const u8, value: anytype) ModelQuery(T) {
            return where(db, field, "=", value);
        }

        /// 静态 whereIn - IN 条件
        /// 用法: Product.whereIn(db, "id", &.{1,2,3}).get()
        pub fn whereIn(db: *Database, field: []const u8, values: anytype) ModelQuery(T) {
            var q = query(db);
            _ = q.whereIn(field, values);
            return q;
        }

        /// 静态 whereLike - LIKE 条件
        /// 用法: Product.whereLike(db, "name", "%手机%").get()
        pub fn whereLike(db: *Database, field: []const u8, pattern: []const u8) ModelQuery(T) {
            var q = query(db);
            _ = q.whereLike(field, pattern);
            return q;
        }

        /// 静态 whereNull - IS NULL 条件
        /// 用法: Product.whereNull(db, "deleted_at").get()
        pub fn whereNull(db: *Database, field: []const u8) ModelQuery(T) {
            var q = query(db);
            _ = q.whereNull(field);
            return q;
        }

        /// 静态 whereNotNull - IS NOT NULL 条件
        pub fn whereNotNull(db: *Database, field: []const u8) ModelQuery(T) {
            var q = query(db);
            _ = q.whereNotNull(field);
            return q;
        }

        /// 静态 orderBy - 排序
        /// 用法: Product.orderBy(db, "price", .desc).get()
        pub fn orderBy(db: *Database, field: []const u8, dir: query_mod.OrderDir) ModelQuery(T) {
            var q = query(db);
            _ = q.orderBy(field, dir);
            return q;
        }

        /// 静态 latest - 按 created_at 降序
        /// 用法: Product.latest(db).take(10).get()
        pub fn latest(db: *Database) ModelQuery(T) {
            var q = query(db);
            _ = q.latest();
            return q;
        }

        /// 静态 oldest - 按 created_at 升序
        pub fn oldest(db: *Database) ModelQuery(T) {
            var q = query(db);
            _ = q.oldest();
            return q;
        }

        /// 静态 select - 选择字段
        /// 用法: Product.select(db, &.{"id", "name"}).get()
        pub fn selectFields(db: *Database, fields: []const []const u8) ModelQuery(T) {
            var q = query(db);
            _ = q.select(fields);
            return q;
        }

        /// 静态 limit - 限制数量
        /// 用法: Product.limit(db, 10).get()
        pub fn take(db: *Database, n: u64) ModelQuery(T) {
            var q = query(db);
            _ = q.limit(n);
            return q;
        }

        /// 静态 page - 分页
        /// 用法: Product.page(db, 1, 20).get()
        pub fn paginate(db: *Database, page_num: u64, page_size: u64) ModelQuery(T) {
            var q = query(db);
            _ = q.page(page_num, page_size);
            return q;
        }

        // ====================================================================
        // 无 db 参数的静态方法（需先调用 use(&db)）
        // 用法:
        //   Product.use(&db);  // 初始化时设置一次
        //   Product.Where("name", "=", "test").get()  // 之后无需传 db
        // ====================================================================

        /// 无参 Where - 使用默认连接
        pub fn Where(field: []const u8, op: []const u8, value: anytype) ModelQuery(T) {
            return where(getDb(), field, op, value);
        }

        /// 无参 WhereEq
        pub fn WhereEq(field: []const u8, value: anytype) ModelQuery(T) {
            return whereEq(getDb(), field, value);
        }

        /// 无参 WhereIn
        pub fn WhereIn(field: []const u8, values: anytype) ModelQuery(T) {
            return whereIn(getDb(), field, values);
        }

        /// 无参 WhereLike
        pub fn WhereLike(field: []const u8, pattern: []const u8) ModelQuery(T) {
            return whereLike(getDb(), field, pattern);
        }

        /// 无参 WhereNull
        pub fn WhereNull(field: []const u8) ModelQuery(T) {
            return whereNull(getDb(), field);
        }

        /// 无参 WhereNotNull
        pub fn WhereNotNull(field: []const u8) ModelQuery(T) {
            return whereNotNull(getDb(), field);
        }

        /// 无参 OrderBy
        pub fn OrderBy(field: []const u8, dir: query_mod.OrderDir) ModelQuery(T) {
            return orderBy(getDb(), field, dir);
        }

        /// 无参 Latest - 按 created_at 降序
        pub fn Latest() ModelQuery(T) {
            return latest(getDb());
        }

        /// 无参 Oldest - 按 created_at 升序
        pub fn Oldest() ModelQuery(T) {
            return oldest(getDb());
        }

        /// 无参 Take - 限制数量
        pub fn Take(n: u64) ModelQuery(T) {
            return take(getDb(), n);
        }

        /// 无参 Paginate - 分页
        pub fn Paginate(page_num: u64, page_size: u64) ModelQuery(T) {
            return paginate(getDb(), page_num, page_size);
        }

        /// 无参 Query - 创建查询构建器
        pub fn Query() ModelQuery(T) {
            return query(getDb());
        }

        /// 无参 Find
        pub fn Find(id: anytype) !?T {
            return find(getDb(), id);
        }

        /// 无参 All
        pub fn All() ![]T {
            return all(getDb());
        }

        /// 无参 Collect - 返回 List
        pub fn Collect() !List {
            return collect(getDb());
        }

        /// 无参 First
        pub fn First() !?T {
            return first(getDb());
        }

        /// 无参 Count
        pub fn Count() !u64 {
            return count(getDb());
        }

        /// 无参 Exists
        pub fn Exists(id: anytype) !bool {
            return exists(getDb(), id);
        }

        /// 操作选项
        pub const Options = struct {
            db: ?*Database = null,
        };

        /// 指定数据库连接（用于事务等场景）
        /// 用法: User.withDB(&tx).Create(data)
        pub fn withDB(db: *Database) OptionsBuilder {
            return OptionsBuilder{ .db = db };
        }

        /// 带选项的操作构建器
        /// 用法: User.withOptions(.{ .db = &tx }).Create(data)
        pub fn withOptions(opts: Options) OptionsBuilder {
            return OptionsBuilder{ .db = opts.db orelse getDb() };
        }

        /// 选项构建器 - 提供带指定 db 的写操作方法
        pub const OptionsBuilder = struct {
            db: *Database,

            pub fn Create(self: OptionsBuilder, data: anytype) !T {
                return create(self.db, data);
            }

            pub fn Update(self: OptionsBuilder, id: anytype, data: anytype) !u64 {
                return update(self.db, id, data);
            }

            pub fn Destroy(self: OptionsBuilder, id: anytype) !u64 {
                return destroy(self.db, id);
            }

            pub fn InsertMany(self: OptionsBuilder, items: anytype) !u64 {
                return insertMany(self.db, items);
            }

            pub fn UpdateOrCreate(self: OptionsBuilder, conditions: anytype, data: anytype) !T {
                return updateOrCreate(self.db, conditions, data);
            }

            pub fn FirstOrCreate(self: OptionsBuilder, conditions: anytype, defaults: anytype) !T {
                return firstOrCreate(self.db, conditions, defaults);
            }

            pub fn Increment(self: OptionsBuilder, id: anytype, field: []const u8, amount: i64) !u64 {
                return increment(self.db, id, field, amount);
            }

            pub fn Decrement(self: OptionsBuilder, id: anytype, field: []const u8, amount: i64) !u64 {
                return decrement(self.db, id, field, amount);
            }
        };

        /// Create - 使用默认连接
        pub fn Create(data: anytype) !T {
            return create(getDb(), data);
        }

        /// Update - 使用默认连接
        pub fn Update(id: anytype, data: anytype) !u64 {
            return update(getDb(), id, data);
        }

        /// Destroy - 使用默认连接
        pub fn Destroy(id: anytype) !u64 {
            return destroy(getDb(), id);
        }

        /// InsertMany - 批量插入
        pub fn InsertMany(items: anytype) !u64 {
            return insertMany(getDb(), items);
        }

        /// UpdateOrCreate - 使用默认连接
        pub fn UpdateOrCreate(conditions: anytype, data: anytype) !T {
            return updateOrCreate(getDb(), conditions, data);
        }

        /// FirstOrCreate - 使用默认连接
        pub fn FirstOrCreate(conditions: anytype, defaults: anytype) !T {
            return firstOrCreate(getDb(), conditions, defaults);
        }

        /// Increment - 使用默认连接
        pub fn Increment(id: anytype, field: []const u8, amount: i64) !u64 {
            return increment(getDb(), id, field, amount);
        }

        /// Decrement - 使用默认连接
        pub fn Decrement(id: anytype, field: []const u8, amount: i64) !u64 {
            return decrement(getDb(), id, field, amount);
        }

        /// 查找单条记录
        pub fn find(db: *Database, id: anytype) !?T {
            var q = query(db);
            defer q.deinit();

            const pk = primaryKey();
            _ = q.where(pk, "=", id).limit(1);

            const results = try q.get();
            if (results.len == 0) return null;
            defer db.allocator.free(results);

            return results[0];
        }

        /// 查找或抛出错误
        pub fn findOrFail(db: *Database, id: anytype) !T {
            return find(db, id) orelse error.ModelNotFound;
        }

        /// 获取所有记录
        pub fn all(db: *Database) ![]T {
            var q = query(db);
            defer q.deinit();
            return q.get();
        }

        /// 创建记录
        pub fn create(db: *Database, data: anytype) !T {
            const sql = try buildInsertSql(db.allocator, tableName(), data);
            defer db.allocator.free(sql);

            _ = try db.rawExec(sql);
            const id = db.conn.lastInsertId();

            // 重新查询返回完整记录
            return (try find(db, id)) orelse error.CreateFailed;
        }

        /// 更新记录
        pub fn update(db: *Database, id: anytype, data: anytype) !u64 {
            const sql = try buildUpdateSql(db.allocator, tableName(), primaryKey(), id, data);
            defer db.allocator.free(sql);
            return db.rawExec(sql);
        }

        /// 删除记录
        pub fn destroy(db: *Database, id: anytype) !u64 {
            var buf: [256]u8 = undefined;
            const sql = try std.fmt.bufPrint(&buf, "DELETE FROM {s} WHERE {s} = {any}", .{ tableName(), primaryKey(), id });
            return db.rawExec(sql);
        }

        /// 统计记录数
        pub fn count(db: *Database) !u64 {
            var buf: [256]u8 = undefined;
            const sql = try std.fmt.bufPrint(&buf, "SELECT COUNT(*) as cnt FROM {s}", .{tableName()});

            var result = try db.rawQuery(sql);
            defer result.deinit();

            if (result.next()) |row| {
                return @intCast(row.getInt("cnt") orelse 0);
            }
            return 0;
        }

        /// 检查是否存在
        pub fn exists(db: *Database, id: anytype) !bool {
            if (try find(db, id)) |*model| {
                var m = model.*;
                freeModel(db.allocator, &m);
                return true;
            }
            return false;
        }

        /// 第一条记录
        pub fn first(db: *Database) !?T {
            var q = query(db);
            defer q.deinit();
            _ = q.limit(1);
            const results = try q.get();
            if (results.len == 0) return null;
            defer db.allocator.free(results);
            return results[0];
        }

        /// 批量插入
        pub fn insertMany(db: *Database, comptime RecordType: type, records: []const RecordType) !u64 {
            var total: u64 = 0;
            for (records) |record| {
                _ = try create(db, record);
                total += 1;
            }
            return total;
        }

        /// 更新或创建
        pub fn updateOrCreate(db: *Database, search: anytype, update_data: anytype) !T {
            // 先查找
            var q = query(db);
            defer q.deinit();

            inline for (std.meta.fields(@TypeOf(search))) |field| {
                _ = q.where(field.name, "=", @field(search, field.name));
            }

            const results = try q.get();
            defer if (results.len > 0) db.allocator.free(results);

            if (results.len > 0) {
                // 存在则更新
                const existing = results[0];
                const id_field = primaryKey();

                // 获取ID
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, field.name, id_field)) {
                        const id = @field(existing, field.name);
                        _ = try Self.update(db, id, update_data);
                        return find(db, id) orelse error.UpdateFailed;
                    }
                }
                return error.PrimaryKeyNotFound;
            } else {
                // 不存在则创建
                return create(db, update_data);
            }
        }

        /// 软删除
        pub fn softDelete(db: *Database, id: anytype) !u64 {
            return update(db, id, .{ .deleted_at = "NOW()" });
        }

        /// 恢复软删除
        pub fn restore(db: *Database, id: anytype) !u64 {
            return update(db, id, .{ .deleted_at = null });
        }

        /// 查找或创建
        /// 如果找到则返回，否则创建新记录
        pub fn firstOrCreate(db: *Database, search: anytype, defaults: anytype) !T {
            var q = query(db);
            defer q.deinit();

            inline for (std.meta.fields(@TypeOf(search))) |field| {
                _ = q.where(field.name, "=", @field(search, field.name));
            }
            _ = q.limit(1);

            const results = try q.get();
            if (results.len > 0) {
                defer db.allocator.free(results);
                return results[0];
            }

            // 不存在则创建
            return create(db, defaults);
        }

        /// 自增字段
        pub fn increment(db: *Database, id: anytype, field_name: []const u8, amount: i64) !u64 {
            var buf: [512]u8 = undefined;
            const sql = try std.fmt.bufPrint(&buf, "UPDATE {s} SET {s} = {s} + {d} WHERE {s} = {any}", .{
                tableName(),
                field_name,
                field_name,
                amount,
                primaryKey(),
                id,
            });
            return db.rawExec(sql);
        }

        /// 自减字段
        pub fn decrement(db: *Database, id: anytype, field_name: []const u8, amount: i64) !u64 {
            return increment(db, id, field_name, -amount);
        }

        /// 获取某字段的单个值
        pub fn getValue(db: *Database, id: anytype, field_name: []const u8) !?[]const u8 {
            var buf: [256]u8 = undefined;
            const sql = try std.fmt.bufPrint(&buf, "SELECT {s} FROM {s} WHERE {s} = {any} LIMIT 1", .{
                field_name,
                tableName(),
                primaryKey(),
                id,
            });

            var result = try db.rawQuery(sql);
            defer result.deinit();

            if (result.next()) |row| {
                return row.getString(field_name);
            }
            return null;
        }

        /// 获取某列的所有值
        pub fn pluck(db: *Database, field_name: []const u8) ![][]const u8 {
            var buf: [256]u8 = undefined;
            const sql = try std.fmt.bufPrint(&buf, "SELECT {s} FROM {s}", .{ field_name, tableName() });

            var result = try db.rawQuery(sql);
            defer result.deinit();

            var values = std.ArrayList([]const u8).init(db.allocator);
            errdefer values.deinit();

            while (result.next()) |row| {
                if (row.getString(field_name)) |v| {
                    try values.append(try db.allocator.dupe(u8, v));
                }
            }

            return values.toOwnedSlice();
        }

        /// 释放 pluck 返回的数组
        pub fn freePlucked(allocator: Allocator, values: [][]const u8) void {
            for (values) |v| {
                allocator.free(v);
            }
            allocator.free(values);
        }

        /// 按条件删除多条记录
        pub fn deleteWhere(db: *Database, field: []const u8, op: []const u8, val: anytype) !u64 {
            var q = query(db);
            defer q.deinit();
            _ = q.where(field, op, val);

            var sql_buf = std.ArrayListUnmanaged(u8){};
            defer sql_buf.deinit(db.allocator);

            try sql_buf.appendSlice(db.allocator, "DELETE FROM ");
            try sql_buf.appendSlice(db.allocator, tableName());
            try q.appendWhere(&sql_buf);

            const sql = try sql_buf.toOwnedSlice(db.allocator);
            defer db.allocator.free(sql);

            return db.rawExec(sql);
        }

        /// 按条件更新多条记录
        pub fn updateWhere(db: *Database, conditions: anytype, data: anytype) !u64 {
            var sql_buf = std.ArrayListUnmanaged(u8){};
            defer sql_buf.deinit(db.allocator);

            try sql_buf.appendSlice(db.allocator, "UPDATE ");
            try sql_buf.appendSlice(db.allocator, tableName());
            try sql_buf.appendSlice(db.allocator, " SET ");

            const DataType = @TypeOf(data);
            inline for (std.meta.fields(DataType), 0..) |field, i| {
                if (i > 0) try sql_buf.appendSlice(db.allocator, ", ");
                try sql_buf.appendSlice(db.allocator, field.name);
                try sql_buf.appendSlice(db.allocator, " = ");
                try appendValue(db.allocator, &sql_buf, @field(data, field.name));
            }

            try sql_buf.appendSlice(db.allocator, " WHERE ");

            const CondType = @TypeOf(conditions);
            inline for (std.meta.fields(CondType), 0..) |field, i| {
                if (i > 0) try sql_buf.appendSlice(db.allocator, " AND ");
                try sql_buf.appendSlice(db.allocator, field.name);
                try sql_buf.appendSlice(db.allocator, " = ");
                try appendValue(db.allocator, &sql_buf, @field(conditions, field.name));
            }

            const sql = try sql_buf.toOwnedSlice(db.allocator);
            defer db.allocator.free(sql);

            return db.rawExec(sql);
        }

        // ====================================================================
        // 关联模型 - Laravel Eloquent 风格
        // ====================================================================

        /// 一对一关联 (hasOne)
        /// 用法: const profile = try user.hasOne(Profile, "user_id").get();
        /// 等价于 Laravel: $user->hasOne(Profile::class, 'user_id')
        pub fn hasOne(self: *const T, comptime Related: type, foreign_key: []const u8) RelationQuery(Related) {
            const pk = primaryKey();
            var pk_value: u64 = 0;

            inline for (std.meta.fields(T)) |field| {
                if (std.mem.eql(u8, field.name, pk)) {
                    pk_value = @field(self.*, field.name);
                    break;
                }
            }

            return RelationQuery(Related).init(getDb(), foreign_key, pk_value, .has_one);
        }

        /// 一对多关联 (hasMany)
        /// 用法: const posts = try user.hasMany(Post, "user_id").get();
        /// 等价于 Laravel: $user->hasMany(Post::class, 'user_id')
        pub fn hasMany(self: *const T, comptime Related: type, foreign_key: []const u8) RelationQuery(Related) {
            const pk = primaryKey();
            var pk_value: u64 = 0;

            inline for (std.meta.fields(T)) |field| {
                if (std.mem.eql(u8, field.name, pk)) {
                    pk_value = @field(self.*, field.name);
                    break;
                }
            }

            return RelationQuery(Related).init(getDb(), foreign_key, pk_value, .has_many);
        }

        /// 属于关联 (belongsTo)
        /// 用法: const user = try post.belongsTo(User, "user_id").get();
        /// 等价于 Laravel: $post->belongsTo(User::class, 'user_id')
        pub fn belongsTo(self: *const T, comptime Related: type, foreign_key: []const u8) RelationQuery(Related) {
            var fk_value: u64 = 0;

            inline for (std.meta.fields(T)) |field| {
                if (std.mem.eql(u8, field.name, foreign_key)) {
                    const val = @field(self.*, field.name);
                    if (@TypeOf(val) == ?u64) {
                        fk_value = val orelse 0;
                    } else if (@TypeOf(val) == u64) {
                        fk_value = val;
                    } else if (@TypeOf(val) == ?u32) {
                        fk_value = val orelse 0;
                    } else if (@TypeOf(val) == u32) {
                        fk_value = val;
                    }
                    break;
                }
            }

            // Related 模型的主键
            const RelatedModel = define(Related);
            const related_pk = RelatedModel.primaryKey();

            return RelationQuery(Related).init(getDb(), related_pk, fk_value, .belongs_to);
        }

        /// 静态方法：获取指定 ID 的关联
        /// 用法: const posts = try User.HasMany(Post, "user_id", user_id).get();
        pub fn HasMany(comptime Related: type, foreign_key: []const u8, id: u64) RelationQuery(Related) {
            return RelationQuery(Related).init(getDb(), foreign_key, id, .has_many);
        }

        /// 静态方法：获取指定 ID 的一对一关联
        pub fn HasOne(comptime Related: type, foreign_key: []const u8, id: u64) RelationQuery(Related) {
            return RelationQuery(Related).init(getDb(), foreign_key, id, .has_one);
        }

        /// 静态方法：获取属于的模型
        pub fn BelongsTo(comptime Related: type, foreign_key_value: u64) RelationQuery(Related) {
            const RelatedModel = define(Related);
            const related_pk = RelatedModel.primaryKey();
            return RelationQuery(Related).init(getDb(), related_pk, foreign_key_value, .belongs_to);
        }

        /// 预加载关联 (with)
        /// 用法: const users = try User.With(Post, "user_id").get();
        pub fn With(comptime Related: type, foreign_key: []const u8) WithQuery(T, Related) {
            return WithQuery(T, Related).init(getDb(), foreign_key);
        }

        // 内部辅助函数

        fn buildInsertSql(allocator: Allocator, table: []const u8, data: anytype) ![]u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(allocator);

            try sql.appendSlice(allocator, "INSERT INTO ");
            try sql.appendSlice(allocator, table);
            try sql.appendSlice(allocator, " (");

            const DataType = @TypeOf(data);
            const fields = std.meta.fields(DataType);

            inline for (fields, 0..) |field, i| {
                if (i > 0) try sql.appendSlice(allocator, ", ");
                try sql.appendSlice(allocator, field.name);
            }

            try sql.appendSlice(allocator, ") VALUES (");

            inline for (fields, 0..) |field, i| {
                if (i > 0) try sql.appendSlice(allocator, ", ");
                const value = @field(data, field.name);
                try appendValue(allocator, &sql, value);
            }

            try sql.append(allocator, ')');

            return sql.toOwnedSlice(allocator);
        }

        fn buildUpdateSql(allocator: Allocator, table: []const u8, pk: []const u8, id: anytype, data: anytype) ![]u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(allocator);

            try sql.appendSlice(allocator, "UPDATE ");
            try sql.appendSlice(allocator, table);
            try sql.appendSlice(allocator, " SET ");

            const DataType = @TypeOf(data);
            const fields = std.meta.fields(DataType);

            inline for (fields, 0..) |field, i| {
                if (i > 0) try sql.appendSlice(allocator, ", ");
                try sql.appendSlice(allocator, field.name);
                try sql.appendSlice(allocator, " = ");
                const value = @field(data, field.name);
                try appendValue(allocator, &sql, value);
            }

            try sql.appendSlice(allocator, " WHERE ");
            try sql.appendSlice(allocator, pk);
            try sql.appendSlice(allocator, " = ");
            try appendValue(allocator, &sql, id);

            return sql.toOwnedSlice(allocator);
        }

        fn appendValue(allocator: Allocator, sql: *std.ArrayListUnmanaged(u8), value: anytype) !void {
            const T2 = @TypeOf(value);
            const type_info = @typeInfo(T2);

            // 处理字符串类型（包括 []const u8 和 *const [N:0]u8）
            if (T2 == []const u8) {
                try sql.append(allocator, '\'');
                // 转义单引号
                for (value) |c| {
                    if (c == '\'') {
                        try sql.appendSlice(allocator, "''");
                    } else {
                        try sql.append(allocator, c);
                    }
                }
                try sql.append(allocator, '\'');
            } else if (type_info == .pointer and type_info.pointer.size == .one) {
                // 处理 *const [N:0]u8 类型（字符串字面量）
                const child_info = @typeInfo(type_info.pointer.child);
                if (child_info == .array and child_info.array.child == u8) {
                    try sql.append(allocator, '\'');
                    const str: []const u8 = value;
                    for (str) |c| {
                        if (c == '\'') {
                            try sql.appendSlice(allocator, "''");
                        } else {
                            try sql.append(allocator, c);
                        }
                    }
                    try sql.append(allocator, '\'');
                } else {
                    try sql.appendSlice(allocator, "NULL");
                }
            } else if (type_info == .optional) {
                if (value) |v| {
                    try appendValue(allocator, sql, v);
                } else {
                    try sql.appendSlice(allocator, "NULL");
                }
            } else if (type_info == .int or type_info == .comptime_int) {
                var buf: [32]u8 = undefined;
                const formatted = try std.fmt.bufPrint(&buf, "{d}", .{value});
                try sql.appendSlice(allocator, formatted);
            } else if (type_info == .float or type_info == .comptime_float) {
                var buf: [64]u8 = undefined;
                const formatted = try std.fmt.bufPrint(&buf, "{d}", .{value});
                try sql.appendSlice(allocator, formatted);
            } else if (T2 == bool) {
                try sql.appendSlice(allocator, if (value) "1" else "0");
            } else {
                try sql.appendSlice(allocator, "NULL");
            }
        }
    };
}

// ============================================================================
// 模型查询构建器
// ============================================================================

/// 模型查询构建器
pub fn ModelQuery(comptime T: type) type {
    return struct {
        const Self = @This();

        db: *Database,
        table: []const u8,
        select_fields: std.ArrayListUnmanaged([]const u8),
        where_clauses: std.ArrayListUnmanaged([]const u8),
        order_clauses: std.ArrayListUnmanaged([]const u8),
        group_fields: std.ArrayListUnmanaged([]const u8),
        join_clauses: std.ArrayListUnmanaged([]const u8),
        having_clause: ?[]const u8 = null,
        limit_val: ?u64 = null,
        offset_val: ?u64 = null,
        distinct_flag: bool = false,

        pub fn init(db: *Database, table: []const u8) Self {
            return Self{
                .db = db,
                .table = table,
                .select_fields = .{},
                .where_clauses = .{},
                .order_clauses = .{},
                .group_fields = .{},
                .join_clauses = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            // 释放 where_clauses 中分配的字符串
            for (self.where_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            self.where_clauses.deinit(self.db.allocator);

            // 释放 order_clauses 中分配的字符串
            for (self.order_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            self.order_clauses.deinit(self.db.allocator);

            // 释放 join_clauses 中分配的字符串
            for (self.join_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            self.join_clauses.deinit(self.db.allocator);

            self.select_fields.deinit(self.db.allocator);
            self.group_fields.deinit(self.db.allocator);
        }

        /// SELECT 字段
        pub fn select(self: *Self, fields: []const []const u8) *Self {
            for (fields) |f| {
                self.select_fields.append(self.db.allocator, f) catch {};
            }
            return self;
        }

        /// WHERE 条件
        pub fn where(self: *Self, field: []const u8, op: []const u8, value: anytype) *Self {
            const clause = formatWhere(self.db.allocator, field, op, value) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE IN
        pub fn whereIn(self: *Self, field: []const u8, values: anytype) *Self {
            const clause = formatWhereIn(self.db.allocator, field, values) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE IN (子查询 - SQL 字符串)
        /// 使用: .whereInSub("user_id", "SELECT id FROM admins WHERE active = 1")
        pub fn whereInSub(self: *Self, field: []const u8, subquery_sql: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IN ({s})", .{ field, subquery_sql }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE IN (子查询 - QueryBuilder)
        /// 使用:
        /// ```zig
        /// var subquery = User.query(db);
        /// defer subquery.deinit();
        /// _ = subquery.select(&.{"id"}).whereEq("active", 1);
        ///
        /// var main = Order.query(db);
        /// defer main.deinit();
        /// _ = main.whereInQuery("user_id", &subquery);
        /// ```
        pub fn whereInQuery(self: *Self, field: []const u8, subquery: anytype) *Self {
            const sub_sql = subquery.toSql() catch return self;
            defer self.db.allocator.free(sub_sql);

            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IN ({s})", .{ field, sub_sql }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT IN (子查询 - SQL 字符串)
        pub fn whereNotInSub(self: *Self, field: []const u8, subquery_sql: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} NOT IN ({s})", .{ field, subquery_sql }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT IN (子查询 - QueryBuilder)
        pub fn whereNotInQuery(self: *Self, field: []const u8, subquery: anytype) *Self {
            const sub_sql = subquery.toSql() catch return self;
            defer self.db.allocator.free(sub_sql);

            const clause = std.fmt.allocPrint(self.db.allocator, "{s} NOT IN ({s})", .{ field, sub_sql }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE EXISTS (子查询 - SQL 字符串)
        pub fn whereExists(self: *Self, subquery_sql: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "EXISTS ({s})", .{subquery_sql}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE EXISTS (子查询 - QueryBuilder)
        pub fn whereExistsQuery(self: *Self, subquery: anytype) *Self {
            const sub_sql = subquery.toSql() catch return self;
            defer self.db.allocator.free(sub_sql);

            const clause = std.fmt.allocPrint(self.db.allocator, "EXISTS ({s})", .{sub_sql}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT EXISTS (子查询 - SQL 字符串)
        pub fn whereNotExists(self: *Self, subquery_sql: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "NOT EXISTS ({s})", .{subquery_sql}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT EXISTS (子查询 - QueryBuilder)
        pub fn whereNotExistsQuery(self: *Self, subquery: anytype) *Self {
            const sub_sql = subquery.toSql() catch return self;
            defer self.db.allocator.free(sub_sql);

            const clause = std.fmt.allocPrint(self.db.allocator, "NOT EXISTS ({s})", .{sub_sql}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE 字段比较 (field1 op field2)
        /// 使用: .whereColumn("created_at", ">", "updated_at")
        pub fn whereColumn(self: *Self, field1: []const u8, op: []const u8, field2: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} {s} {s}", .{ field1, op, field2 }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NULL
        pub fn whereNull(self: *Self, field: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IS NULL", .{field}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT NULL
        pub fn whereNotNull(self: *Self, field: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IS NOT NULL", .{field}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE 简化版（默认 = 操作符）
        /// 使用: .whereEq("name", "John")
        pub fn whereEq(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, "=", value);
        }

        /// WHERE NOT EQUAL
        pub fn whereNe(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, "!=", value);
        }

        /// WHERE GREATER THAN
        pub fn whereGt(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, ">", value);
        }

        /// WHERE GREATER THAN OR EQUAL
        pub fn whereGte(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, ">=", value);
        }

        /// WHERE LESS THAN
        pub fn whereLt(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, "<", value);
        }

        /// WHERE LESS THAN OR EQUAL
        pub fn whereLte(self: *Self, field: []const u8, value: anytype) *Self {
            return self.where(field, "<=", value);
        }

        /// WHERE NOT IN
        pub fn whereNotIn(self: *Self, field: []const u8, values: anytype) *Self {
            const clause = formatWhereNotIn(self.db.allocator, field, values) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE BETWEEN
        pub fn whereBetween(self: *Self, field: []const u8, min_val: anytype, max_val: anytype) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} BETWEEN {any} AND {any}", .{ field, min_val, max_val }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT BETWEEN
        pub fn whereNotBetween(self: *Self, field: []const u8, min_val: anytype, max_val: anytype) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} NOT BETWEEN {any} AND {any}", .{ field, min_val, max_val }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE LIKE
        pub fn whereLike(self: *Self, field: []const u8, pattern: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} LIKE '{s}'", .{ field, pattern }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE NOT LIKE
        pub fn whereNotLike(self: *Self, field: []const u8, pattern: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} NOT LIKE '{s}'", .{ field, pattern }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE 原始 SQL
        pub fn whereRaw(self: *Self, raw_sql: []const u8) *Self {
            const clause = self.db.allocator.dupe(u8, raw_sql) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// 快捷方式：按最新排序
        pub fn latest(self: *Self) *Self {
            return self.orderBy("created_at", .desc);
        }

        /// 快捷方式：按最早排序
        pub fn oldest(self: *Self) *Self {
            return self.orderBy("created_at", .asc);
        }

        /// 快捷方式：只取 N 条
        pub fn take(self: *Self, n: u64) *Self {
            return self.limit(n);
        }

        /// 快捷方式：跳过 N 条
        pub fn skip(self: *Self, n: u64) *Self {
            return self.offset(n);
        }

        /// ORDER BY
        pub fn orderBy(self: *Self, field: []const u8, dir: query_mod.OrderDir) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} {s}", .{ field, dir.toSql() }) catch return self;
            self.order_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// LIMIT
        pub fn limit(self: *Self, n: u64) *Self {
            self.limit_val = n;
            return self;
        }

        /// OFFSET
        pub fn offset(self: *Self, n: u64) *Self {
            self.offset_val = n;
            return self;
        }

        /// 分页
        pub fn page(self: *Self, page_num: u64, page_size: u64) *Self {
            self.limit_val = page_size;
            self.offset_val = (page_num - 1) * page_size;
            return self;
        }

        /// GROUP BY
        pub fn groupBy(self: *Self, fields: []const []const u8) *Self {
            for (fields) |f| {
                self.group_fields.append(self.db.allocator, f) catch {};
            }
            return self;
        }

        /// HAVING
        pub fn having(self: *Self, clause: []const u8) *Self {
            self.having_clause = clause;
            return self;
        }

        /// DISTINCT
        pub fn distinct(self: *Self) *Self {
            self.distinct_flag = true;
            return self;
        }

        /// LEFT JOIN
        pub fn leftJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "LEFT JOIN {s} ON {s}", .{ table, on }) catch return self;
            self.join_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// RIGHT JOIN
        pub fn rightJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "RIGHT JOIN {s} ON {s}", .{ table, on }) catch return self;
            self.join_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// INNER JOIN
        pub fn innerJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "INNER JOIN {s} ON {s}", .{ table, on }) catch return self;
            self.join_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// CROSS JOIN
        pub fn crossJoin(self: *Self, table: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "CROSS JOIN {s}", .{table}) catch return self;
            self.join_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// OR WHERE 条件
        pub fn orWhere(self: *Self, field: []const u8, op: []const u8, value: anytype) *Self {
            const cond = formatWhere(self.db.allocator, field, op, value) catch return self;
            defer self.db.allocator.free(cond);

            if (self.where_clauses.items.len > 0) {
                // 修改最后一个条件为 OR
                const clause = std.fmt.allocPrint(self.db.allocator, "OR {s}", .{cond}) catch return self;
                self.where_clauses.append(self.db.allocator, clause) catch {
                    self.db.allocator.free(clause);
                };
            } else {
                const clause = self.db.allocator.dupe(u8, cond) catch return self;
                self.where_clauses.append(self.db.allocator, clause) catch {
                    self.db.allocator.free(clause);
                };
            }
            return self;
        }

        /// OR WHERE 简化版
        pub fn orWhereEq(self: *Self, field: []const u8, value: anytype) *Self {
            return self.orWhere(field, "=", value);
        }

        /// 分组条件查询 (Laravel: ->where(function($query) { ... }))
        /// 使用: .whereGroup(struct { fn apply(q: *Query) void { _ = q.whereEq("a", 1).orWhereEq("b", 2); } }.apply)
        /// 生成: AND (a = 1 OR b = 2)
        pub fn whereGroup(self: *Self, comptime callback: fn (*Self) void) *Self {
            // 创建临时子查询来收集条件
            var sub = Self.init(self.db, self.table);
            callback(&sub);

            // 将子查询条件合并为分组
            if (sub.where_clauses.items.len > 0) {
                var group_sql = std.ArrayListUnmanaged(u8){};
                group_sql.appendSlice(self.db.allocator, "(") catch return self;

                for (sub.where_clauses.items, 0..) |clause, i| {
                    if (i > 0) {
                        // 检查是否是 OR 条件
                        if (std.mem.startsWith(u8, clause, "OR ")) {
                            group_sql.appendSlice(self.db.allocator, " ") catch {};
                        } else {
                            group_sql.appendSlice(self.db.allocator, " AND ") catch {};
                        }
                    }
                    group_sql.appendSlice(self.db.allocator, clause) catch {};
                }

                group_sql.appendSlice(self.db.allocator, ")") catch {};

                const group_str = group_sql.toOwnedSlice(self.db.allocator) catch {
                    group_sql.deinit(self.db.allocator);
                    sub.deinit();
                    return self;
                };

                self.where_clauses.append(self.db.allocator, group_str) catch {
                    self.db.allocator.free(group_str);
                };
            }

            // 释放临时子查询（不释放条件字符串，已转移）
            for (sub.where_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            sub.where_clauses.deinit(self.db.allocator);
            sub.select_fields.deinit(self.db.allocator);
            sub.order_clauses.deinit(self.db.allocator);
            sub.group_fields.deinit(self.db.allocator);
            sub.join_clauses.deinit(self.db.allocator);

            return self;
        }

        /// OR 分组条件查询
        /// 使用: .orWhereGroup(struct { fn apply(q: *Query) void { _ = q.whereEq("a", 1).whereEq("b", 2); } }.apply)
        /// 生成: OR (a = 1 AND b = 2)
        pub fn orWhereGroup(self: *Self, comptime callback: fn (*Self) void) *Self {
            var sub = Self.init(self.db, self.table);
            callback(&sub);

            if (sub.where_clauses.items.len > 0) {
                var group_sql = std.ArrayListUnmanaged(u8){};
                group_sql.appendSlice(self.db.allocator, "OR (") catch return self;

                for (sub.where_clauses.items, 0..) |clause, i| {
                    if (i > 0) {
                        if (std.mem.startsWith(u8, clause, "OR ")) {
                            group_sql.appendSlice(self.db.allocator, " ") catch {};
                        } else {
                            group_sql.appendSlice(self.db.allocator, " AND ") catch {};
                        }
                    }
                    group_sql.appendSlice(self.db.allocator, clause) catch {};
                }

                group_sql.appendSlice(self.db.allocator, ")") catch {};

                const group_str = group_sql.toOwnedSlice(self.db.allocator) catch {
                    group_sql.deinit(self.db.allocator);
                    sub.deinit();
                    return self;
                };

                self.where_clauses.append(self.db.allocator, group_str) catch {
                    self.db.allocator.free(group_str);
                };
            }

            for (sub.where_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            sub.where_clauses.deinit(self.db.allocator);
            sub.select_fields.deinit(self.db.allocator);
            sub.order_clauses.deinit(self.db.allocator);
            sub.group_fields.deinit(self.db.allocator);
            sub.join_clauses.deinit(self.db.allocator);

            return self;
        }

        /// 嵌套条件构建器 - 更灵活的方式
        /// 使用:
        /// ```zig
        /// var nested = query.newNested();
        /// _ = nested.whereEq("role", "admin").orWhereEq("role", "mod");
        /// _ = query.whereNested(&nested);
        /// ```
        pub fn newNested(self: *Self) Self {
            return Self.init(self.db, self.table);
        }

        /// 添加嵌套条件 (AND)
        pub fn whereNested(self: *Self, nested: *Self) *Self {
            if (nested.where_clauses.items.len > 0) {
                var group_sql = std.ArrayListUnmanaged(u8){};
                group_sql.appendSlice(self.db.allocator, "(") catch return self;

                for (nested.where_clauses.items, 0..) |clause, i| {
                    if (i > 0) {
                        if (std.mem.startsWith(u8, clause, "OR ")) {
                            group_sql.appendSlice(self.db.allocator, " ") catch {};
                        } else {
                            group_sql.appendSlice(self.db.allocator, " AND ") catch {};
                        }
                    }
                    group_sql.appendSlice(self.db.allocator, clause) catch {};
                }

                group_sql.appendSlice(self.db.allocator, ")") catch {};

                const group_str = group_sql.toOwnedSlice(self.db.allocator) catch {
                    group_sql.deinit(self.db.allocator);
                    return self;
                };

                self.where_clauses.append(self.db.allocator, group_str) catch {
                    self.db.allocator.free(group_str);
                };
            }

            // 释放嵌套查询
            nested.deinit();
            return self;
        }

        /// 添加嵌套条件 (OR)
        pub fn orWhereNested(self: *Self, nested: *Self) *Self {
            if (nested.where_clauses.items.len > 0) {
                var group_sql = std.ArrayListUnmanaged(u8){};
                group_sql.appendSlice(self.db.allocator, "OR (") catch return self;

                for (nested.where_clauses.items, 0..) |clause, i| {
                    if (i > 0) {
                        if (std.mem.startsWith(u8, clause, "OR ")) {
                            group_sql.appendSlice(self.db.allocator, " ") catch {};
                        } else {
                            group_sql.appendSlice(self.db.allocator, " AND ") catch {};
                        }
                    }
                    group_sql.appendSlice(self.db.allocator, clause) catch {};
                }

                group_sql.appendSlice(self.db.allocator, ")") catch {};

                const group_str = group_sql.toOwnedSlice(self.db.allocator) catch {
                    group_sql.deinit(self.db.allocator);
                    return self;
                };

                self.where_clauses.append(self.db.allocator, group_str) catch {
                    self.db.allocator.free(group_str);
                };
            }

            nested.deinit();
            return self;
        }

        /// WHERE DATE (日期比较)
        pub fn whereDate(self: *Self, field: []const u8, op: []const u8, date: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "DATE({s}) {s} '{s}'", .{ field, op, date }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE YEAR
        pub fn whereYear(self: *Self, field: []const u8, op: []const u8, year: i32) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "YEAR({s}) {s} {d}", .{ field, op, year }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE MONTH
        pub fn whereMonth(self: *Self, field: []const u8, op: []const u8, month: i32) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "MONTH({s}) {s} {d}", .{ field, op, month }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// WHERE DAY
        pub fn whereDay(self: *Self, field: []const u8, op: []const u8, day: i32) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "DAY({s}) {s} {d}", .{ field, op, day }) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// 快捷方式：按字段降序
        pub fn orderByDesc(self: *Self, field: []const u8) *Self {
            return self.orderBy(field, .desc);
        }

        /// 快捷方式：按字段升序
        pub fn orderByAsc(self: *Self, field: []const u8) *Self {
            return self.orderBy(field, .asc);
        }

        /// 随机排序
        pub fn inRandomOrder(self: *Self) *Self {
            // MySQL: RAND(), SQLite: RANDOM(), PostgreSQL: RANDOM()
            const clause = self.db.allocator.dupe(u8, "RAND()") catch return self;
            self.order_clauses.append(self.db.allocator, clause) catch {
                self.db.allocator.free(clause);
            };
            return self;
        }

        /// 重置排序
        pub fn reorder(self: *Self) *Self {
            for (self.order_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            self.order_clauses.clearRetainingCapacity();
            return self;
        }

        /// SELECT RAW
        pub fn selectRaw(self: *Self, raw: []const u8) *Self {
            self.select_fields.append(self.db.allocator, raw) catch {};
            return self;
        }

        /// 条件查询 (when)
        /// 使用: query.when(condition, struct { fn apply(q: *Query) *Query { return q.whereEq("status", 1); } }.apply)
        pub fn when(self: *Self, condition: bool, comptime apply: fn (*Self) *Self) *Self {
            if (condition) {
                return apply(self);
            }
            return self;
        }

        /// SUM 聚合
        pub fn sum(self: *Self, field: []const u8) !?f64 {
            return self.aggregate("SUM", field);
        }

        /// AVG 聚合
        pub fn avg(self: *Self, field: []const u8) !?f64 {
            return self.aggregate("AVG", field);
        }

        /// MIN 聚合
        pub fn min(self: *Self, field: []const u8) !?f64 {
            return self.aggregate("MIN", field);
        }

        /// MAX 聚合
        pub fn max(self: *Self, field: []const u8) !?f64 {
            return self.aggregate("MAX", field);
        }

        /// 通用聚合函数
        fn aggregate(self: *Self, func: []const u8, field: []const u8) !?f64 {
            var sql = std.ArrayListUnmanaged(u8){};
            defer sql.deinit(self.db.allocator);

            try sql.appendSlice(self.db.allocator, "SELECT ");
            try sql.appendSlice(self.db.allocator, func);
            try sql.append(self.db.allocator, '(');
            try sql.appendSlice(self.db.allocator, field);
            try sql.appendSlice(self.db.allocator, ") as agg_result FROM ");
            try sql.appendSlice(self.db.allocator, self.table);
            try self.appendWhere(&sql);

            const sql_str = try sql.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql_str);

            var result = try self.db.rawQuery(sql_str);
            defer result.deinit();

            if (result.next()) |row| {
                if (row.getString("agg_result")) |v| {
                    return std.fmt.parseFloat(f64, v) catch null;
                }
            }
            return null;
        }

        /// 批量更新
        pub fn updateBatch(self: *Self, data: anytype) !u64 {
            var sql = std.ArrayListUnmanaged(u8){};
            defer sql.deinit(self.db.allocator);

            try sql.appendSlice(self.db.allocator, "UPDATE ");
            try sql.appendSlice(self.db.allocator, self.table);
            try sql.appendSlice(self.db.allocator, " SET ");

            const DataType = @TypeOf(data);
            const fields = std.meta.fields(DataType);

            inline for (fields, 0..) |field, i| {
                if (i > 0) try sql.appendSlice(self.db.allocator, ", ");
                try sql.appendSlice(self.db.allocator, field.name);
                try sql.appendSlice(self.db.allocator, " = ");
                const value = @field(data, field.name);
                try appendValueToSql(self.db.allocator, &sql, value);
            }

            try self.appendWhere(&sql);

            const sql_str = try sql.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql_str);

            return self.db.rawExec(sql_str);
        }

        fn appendValueToSql(allocator: Allocator, sql: *std.ArrayListUnmanaged(u8), value: anytype) !void {
            const VT = @TypeOf(value);
            const type_info = @typeInfo(VT);

            if (VT == []const u8) {
                try sql.append(allocator, '\'');
                for (value) |c| {
                    if (c == '\'') {
                        try sql.appendSlice(allocator, "''");
                    } else {
                        try sql.append(allocator, c);
                    }
                }
                try sql.append(allocator, '\'');
            } else if (type_info == .pointer and type_info.pointer.size == .one) {
                const child_info = @typeInfo(type_info.pointer.child);
                if (child_info == .array and child_info.array.child == u8) {
                    try sql.append(allocator, '\'');
                    const str: []const u8 = value;
                    for (str) |c| {
                        if (c == '\'') {
                            try sql.appendSlice(allocator, "''");
                        } else {
                            try sql.append(allocator, c);
                        }
                    }
                    try sql.append(allocator, '\'');
                } else {
                    try sql.appendSlice(allocator, "NULL");
                }
            } else if (type_info == .optional) {
                if (value) |v| {
                    try appendValueToSql(allocator, sql, v);
                } else {
                    try sql.appendSlice(allocator, "NULL");
                }
            } else if (type_info == .int or type_info == .comptime_int) {
                var buf: [32]u8 = undefined;
                const formatted = try std.fmt.bufPrint(&buf, "{d}", .{value});
                try sql.appendSlice(allocator, formatted);
            } else if (type_info == .float or type_info == .comptime_float) {
                var buf: [64]u8 = undefined;
                const formatted = try std.fmt.bufPrint(&buf, "{d}", .{value});
                try sql.appendSlice(allocator, formatted);
            } else if (VT == bool) {
                try sql.appendSlice(allocator, if (value) "1" else "0");
            } else {
                try sql.appendSlice(allocator, "NULL");
            }
        }

        /// 执行查询
        pub fn get(self: *Self) ![]T {
            const sql = try self.toSql();
            defer self.db.allocator.free(sql);

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            return self.mapResults(&result);
        }

        /// 获取结果（返回 List 包装器，自动管理内存）
        /// 使用: var list = try query.collect(); defer list.deinit();
        pub fn collect(self: *Self) !define(T).List {
            const data = try self.get();
            return define(T).List{ .allocator = self.db.allocator, .data = data };
        }

        /// 检查是否存在记录
        pub fn exists(self: *Self) !bool {
            return (try self.count()) > 0;
        }

        /// 检查是否不存在记录
        pub fn doesntExist(self: *Self) !bool {
            return (try self.count()) == 0;
        }

        /// 获取某列的单个值
        pub fn getValue(self: *Self, field_name: []const u8) !?[]const u8 {
            self.limit_val = 1;

            // 临时替换 select
            const old_fields = self.select_fields;
            self.select_fields = .{};
            self.select_fields.append(self.db.allocator, field_name) catch {};

            const sql = try self.toSql();
            defer self.db.allocator.free(sql);

            // 恢复
            self.select_fields.deinit(self.db.allocator);
            self.select_fields = old_fields;

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            if (result.next()) |row| {
                return row.getString(field_name);
            }
            return null;
        }

        /// 获取某列的所有值
        pub fn pluck(self: *Self, field_name: []const u8) ![][]const u8 {
            // 临时替换 select
            const old_fields = self.select_fields;
            self.select_fields = .{};
            self.select_fields.append(self.db.allocator, field_name) catch {};

            const sql = try self.toSql();
            defer self.db.allocator.free(sql);

            // 恢复
            self.select_fields.deinit(self.db.allocator);
            self.select_fields = old_fields;

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            var values = std.ArrayList([]const u8).init(self.db.allocator);
            errdefer values.deinit();

            while (result.next()) |row| {
                if (row.getString(field_name)) |v| {
                    try values.append(try self.db.allocator.dupe(u8, v));
                }
            }

            return values.toOwnedSlice();
        }

        /// 获取第一条
        pub fn first(self: *Self) !?T {
            self.limit_val = 1;
            const results = try self.get();
            if (results.len == 0) return null;
            defer self.db.allocator.free(results);
            return results[0];
        }

        /// 获取数量
        pub fn count(self: *Self) !u64 {
            var sql = std.ArrayListUnmanaged(u8){};
            defer sql.deinit(self.db.allocator);

            try sql.appendSlice(self.db.allocator, "SELECT COUNT(*) as cnt FROM ");
            try sql.appendSlice(self.db.allocator, self.table);
            try self.appendWhere(&sql);

            const sql_str = try sql.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql_str);

            var result = try self.db.rawQuery(sql_str);
            defer result.deinit();

            if (result.next()) |row| {
                return @intCast(row.getInt("cnt") orelse 0);
            }
            return 0;
        }

        /// 删除匹配的记录
        pub fn delete(self: *Self) !u64 {
            var sql = std.ArrayListUnmanaged(u8){};
            defer sql.deinit(self.db.allocator);

            try sql.appendSlice(self.db.allocator, "DELETE FROM ");
            try sql.appendSlice(self.db.allocator, self.table);
            try self.appendWhere(&sql);

            const sql_str = try sql.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql_str);

            return self.db.rawExec(sql_str);
        }

        /// 生成 SQL
        pub fn toSql(self: *Self) ![]u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.db.allocator);

            // SELECT
            try sql.appendSlice(self.db.allocator, "SELECT ");
            if (self.distinct_flag) {
                try sql.appendSlice(self.db.allocator, "DISTINCT ");
            }

            if (self.select_fields.items.len > 0) {
                for (self.select_fields.items, 0..) |f, i| {
                    if (i > 0) try sql.appendSlice(self.db.allocator, ", ");
                    try sql.appendSlice(self.db.allocator, f);
                }
            } else {
                // 自动生成带表名前缀的字段列表，避免 JOIN 时字段歧义
                // 例如: user.id, user.name, ...
                inline for (std.meta.fields(T), 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.db.allocator, ", ");
                    try sql.appendSlice(self.db.allocator, self.table);
                    try sql.append(self.db.allocator, '.');
                    try sql.appendSlice(self.db.allocator, field.name);
                }
            }

            // FROM
            try sql.appendSlice(self.db.allocator, " FROM ");
            try sql.appendSlice(self.db.allocator, self.table);

            // JOINs
            for (self.join_clauses.items) |j| {
                try sql.append(self.db.allocator, ' ');
                try sql.appendSlice(self.db.allocator, j);
            }

            // WHERE
            try self.appendWhere(&sql);

            // GROUP BY
            if (self.group_fields.items.len > 0) {
                try sql.appendSlice(self.db.allocator, " GROUP BY ");
                for (self.group_fields.items, 0..) |f, i| {
                    if (i > 0) try sql.appendSlice(self.db.allocator, ", ");
                    try sql.appendSlice(self.db.allocator, f);
                }
            }

            // HAVING
            if (self.having_clause) |h| {
                try sql.appendSlice(self.db.allocator, " HAVING ");
                try sql.appendSlice(self.db.allocator, h);
            }

            // ORDER BY
            if (self.order_clauses.items.len > 0) {
                try sql.appendSlice(self.db.allocator, " ORDER BY ");
                for (self.order_clauses.items, 0..) |o, i| {
                    if (i > 0) try sql.appendSlice(self.db.allocator, ", ");
                    try sql.appendSlice(self.db.allocator, o);
                }
            }

            // LIMIT
            if (self.limit_val) |lim| {
                const lim_str = try std.fmt.allocPrint(self.db.allocator, " LIMIT {d}", .{lim});
                defer self.db.allocator.free(lim_str);
                try sql.appendSlice(self.db.allocator, lim_str);
            }

            // OFFSET
            if (self.offset_val) |off| {
                const off_str = try std.fmt.allocPrint(self.db.allocator, " OFFSET {d}", .{off});
                defer self.db.allocator.free(off_str);
                try sql.appendSlice(self.db.allocator, off_str);
            }

            return sql.toOwnedSlice(self.db.allocator);
        }

        fn appendWhere(self: *Self, sql: *std.ArrayListUnmanaged(u8)) !void {
            if (self.where_clauses.items.len > 0) {
                try sql.appendSlice(self.db.allocator, " WHERE ");
                for (self.where_clauses.items, 0..) |clause, i| {
                    if (i > 0) try sql.appendSlice(self.db.allocator, " AND ");
                    try sql.appendSlice(self.db.allocator, clause);
                }
            }
        }

        fn mapResults(self: *Self, result: *interface.ResultSet) ![]T {
            var models = std.ArrayListUnmanaged(T){};
            errdefer models.deinit(self.db.allocator);

            const fields = std.meta.fields(T);
            var field_indices: [fields.len]?usize = .{null} ** fields.len;

            // 缓存字段映射索引
            if (result.field_names.len > 0) {
                for (result.field_names, 0..) |col_name, col_idx| {
                    inline for (fields, 0..) |field, f_idx| {
                        if (std.mem.eql(u8, col_name, field.name)) {
                            field_indices[f_idx] = col_idx;
                        }
                    }
                }
            }

            while (result.next()) |row| {
                var model: T = undefined;

                inline for (fields, 0..) |field, f_idx| {
                    // 使用缓存索引
                    var value: ?[]const u8 = null;
                    if (field_indices[f_idx]) |idx| {
                        if (idx < row.values.len) {
                            value = row.values[idx];
                        }
                    }

                    if (@typeInfo(field.type) == .optional) {
                        const child_type = @typeInfo(field.type).optional.child;
                        if (value) |v| {
                            // 根据可选类型的子类型进行转换
                            if (child_type == []const u8) {
                                @field(model, field.name) = try self.db.allocator.dupe(u8, v);
                            } else if (@typeInfo(child_type) == .int) {
                                @field(model, field.name) = std.fmt.parseInt(child_type, v, 10) catch null;
                            } else if (@typeInfo(child_type) == .float) {
                                @field(model, field.name) = std.fmt.parseFloat(child_type, v) catch null;
                            } else {
                                @field(model, field.name) = null;
                            }
                        } else {
                            @field(model, field.name) = null;
                        }
                    } else if (field.type == []const u8) {
                        // 复制字符串到堆内存（避免悬空指针）
                        if (value) |v| {
                            @field(model, field.name) = try self.db.allocator.dupe(u8, v);
                        } else {
                            @field(model, field.name) = "";
                        }
                    } else if (@typeInfo(field.type) == .int) {
                        if (value) |v| {
                            @field(model, field.name) = std.fmt.parseInt(field.type, v, 10) catch 0;
                        } else {
                            @field(model, field.name) = 0;
                        }
                    } else if (@typeInfo(field.type) == .float) {
                        if (value) |v| {
                            @field(model, field.name) = std.fmt.parseFloat(field.type, v) catch 0;
                        } else {
                            @field(model, field.name) = 0;
                        }
                    } else if (field.type == bool) {
                        @field(model, field.name) = if (value) |v| std.mem.eql(u8, v, "1") else false;
                    }
                }

                try models.append(self.db.allocator, model);
            }

            return models.toOwnedSlice(self.db.allocator);
        }

        // 使用顶层的 formatWhere 函数

        fn formatWhereIn(allocator: Allocator, field: []const u8, values: anytype) ![]u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(allocator);

            try sql.appendSlice(allocator, field);
            try sql.appendSlice(allocator, " IN (");

            for (values, 0..) |v, i| {
                if (i > 0) try sql.appendSlice(allocator, ", ");

                const V = @TypeOf(v);
                if (V == []const u8) {
                    try sql.append(allocator, '\'');
                    try sql.appendSlice(allocator, v);
                    try sql.append(allocator, '\'');
                } else {
                    var buf: [32]u8 = undefined;
                    const len = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
                    try sql.appendSlice(allocator, buf[0..len]);
                }
            }

            try sql.append(allocator, ')');
            return sql.toOwnedSlice(allocator);
        }

        fn formatWhereNotIn(allocator: Allocator, field: []const u8, values: anytype) ![]u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(allocator);

            try sql.appendSlice(allocator, field);
            try sql.appendSlice(allocator, " NOT IN (");

            for (values, 0..) |v, i| {
                if (i > 0) try sql.appendSlice(allocator, ", ");

                const V = @TypeOf(v);
                if (V == []const u8) {
                    try sql.append(allocator, '\'');
                    try sql.appendSlice(allocator, v);
                    try sql.append(allocator, '\'');
                } else {
                    var buf: [32]u8 = undefined;
                    const len = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
                    try sql.appendSlice(allocator, buf[0..len]);
                }
            }

            try sql.append(allocator, ')');
            return sql.toOwnedSlice(allocator);
        }
    };
}

// ============================================================================
// 关联关系
// ============================================================================

/// 一对多关联
pub fn HasMany(comptime _: type, comptime Child: type) type {
    return struct {
        pub fn get(db: *Database, parent_id: anytype, foreign_key: []const u8) ![]Child {
            const child_model = define(Child);
            var q = child_model.query(db);
            defer q.deinit();
            _ = q.where(foreign_key, "=", parent_id);
            return q.get();
        }
    };
}

/// 属于关联
pub fn BelongsTo(comptime _: type, comptime Parent: type) type {
    return struct {
        pub fn get(db: *Database, foreign_key_value: anytype) !?Parent {
            const parent_model = define(Parent);
            return parent_model.find(db, foreign_key_value);
        }
    };
}

// ============================================================================
// 测试
// ============================================================================

test "define: 模型定义" {
    const User = define(struct {
        pub const table_name = "users";
        pub const primary_key = "id";

        id: u64,
        name: []const u8,
    });

    try std.testing.expectEqualStrings("users", User.tableName());
    try std.testing.expectEqualStrings("id", User.primaryKey());
}

test "ModelQuery: SQL生成" {
    // 模拟的查询测试
    const UserModel = struct {
        pub const table_name = "users";
        id: u64,
        name: []const u8,
    };

    const User = define(UserModel);

    // 验证模型定义
    try std.testing.expectEqualStrings("users", User.tableName());
    try std.testing.expectEqualStrings("id", User.primaryKey());
}

// ============================================================================
// 连接池（用于 MySQL 高并发）
// ============================================================================

/// 连接池配置
pub const PoolConfig = struct {
    /// 最小连接数
    min_size: usize = 2,
    /// 最大连接数
    max_size: usize = 10,
    /// 获取连接的超时时间（毫秒）
    acquire_timeout_ms: u64 = 5000,
    /// 连接最大空闲时间（毫秒）
    max_idle_time_ms: u64 = 300_000,
    /// 连接最大生命周期（毫秒）
    max_lifetime_ms: u64 = 1_800_000,
    /// 事务超时时间（毫秒）
    transaction_timeout_ms: u64 = 30_000,
    /// 保活间隔（毫秒），0 表示禁用
    keepalive_interval_ms: u64 = 60_000,
};

/// 连接池统计信息
pub const PoolStats = struct {
    total: usize,
    active: usize,
    idle: usize,
    in_transaction: usize,
};

/// 连接包装器
const PooledConnection = struct {
    conn: interface.Connection,
    id: usize,
    in_use: bool,
    in_transaction: bool,
    created_at: i64,
    last_used: i64,
    transaction_start: ?i64,
    is_pinging: std.atomic.Value(bool),
    broken: bool = false,
    borrowed: bool = false,
    mutex: std.Thread.Mutex = .{},

    pub fn init(conn: interface.Connection, id: usize) PooledConnection {
        const now = std.time.milliTimestamp();
        return .{
            .conn = conn,
            .id = id,
            .in_use = false,
            .in_transaction = false,
            .created_at = now,
            .last_used = now,
            .transaction_start = null,
            .is_pinging = std.atomic.Value(bool).init(false),
            .broken = false,
            .borrowed = false,
            .mutex = .{},
        };
    }

    pub fn isHealthy(self: *const PooledConnection, config: PoolConfig) bool {
        const now = std.time.milliTimestamp();

        if (now - self.created_at > config.max_lifetime_ms) {
            return false;
        }

        if (!self.in_use and now - self.last_used > config.max_idle_time_ms) {
            return false;
        }

        if (self.in_transaction) {
            if (self.transaction_start) |start| {
                if (now - start > config.transaction_timeout_ms) {
                    return false;
                }
            }
        }

        return true;
    }
};

/// MySQL 连接池
pub const ConnectionPool = struct {
    allocator: Allocator,
    config: PoolConfig,
    db_config: interface.MySQLConfig,

    // 所有连接（用于管理生命周期和保活）
    all_connections: std.ArrayListUnmanaged(*PooledConnection),
    // 空闲连接（栈结构，LIFO，用于快速获取）
    idle_connections: std.ArrayListUnmanaged(*PooledConnection),

    state_mutex: std.Thread.Mutex = .{},
    idle_mutex: std.Thread.Mutex = .{},
    condition: std.Thread.Condition = .{},
    next_id: usize = 0,
    closed: bool = false,
    keepalive_thread: ?std.Thread = null,

    pub fn init(allocator: Allocator, db_config: interface.MySQLConfig, pool_config: PoolConfig) !ConnectionPool {
        var pool = ConnectionPool{
            .allocator = allocator,
            .config = pool_config,
            .db_config = db_config,
            .all_connections = .{},
            .idle_connections = .{},
            .state_mutex = .{},
            .idle_mutex = .{},
            .condition = .{},
            .next_id = 0,
            .closed = false,
            .keepalive_thread = null,
        };

        // 预创建最小连接数
        for (0..pool_config.min_size) |_| {
            const conn = try interface.Driver.mysql(allocator, db_config);
            const pooled = try allocator.create(PooledConnection);
            pooled.* = PooledConnection.init(conn, pool.next_id);
            pool.next_id += 1;

            try pool.all_connections.append(allocator, pooled);
            try pool.idle_connections.append(allocator, pooled);
        }

        // 启动保活线程
        if (pool_config.keepalive_interval_ms > 0) {
            pool.keepalive_thread = std.Thread.spawn(.{}, keepaliveWorker, .{&pool}) catch null;
        }

        return pool;
    }

    /// 保活工作线程（非阻塞设计）
    fn keepaliveWorker(self: *ConnectionPool) void {
        while (true) {
            // 检查是否关闭
            self.state_mutex.lock();
            if (self.closed) {
                self.state_mutex.unlock();
                break;
            }
            self.state_mutex.unlock();

            // 安全计算 sleep 时间，避免整数溢出
            const sleep_ns: u64 = @as(u64, self.config.keepalive_interval_ms) * @as(u64, std.time.ns_per_ms);
            std.Thread.sleep(sleep_ns);

            // 1. 快速加锁：只收集需要 ping 的连接（标记为 pinging）
            // 只检测空闲连接，因为使用中的连接被认为是最新的
            var conns_to_ping = std.ArrayListUnmanaged(*PooledConnection){};
            defer conns_to_ping.deinit(self.allocator);

            {
                self.idle_mutex.lock();

                // 遍历 idle 列表（从头开始，优先检查旧连接）
                for (self.idle_connections.items) |pooled| {
                    if (conns_to_ping.items.len >= 16) break;

                    // 只有未被 acquire 和未在 pinging 的连接才处理
                    // 增加 borrowed 检查，防止借出后仍在 idle 列表的极端情况
                    if (!pooled.borrowed and !pooled.in_use and !pooled.is_pinging.load(.seq_cst)) {
                        pooled.is_pinging.store(true, .seq_cst);
                        conns_to_ping.append(self.allocator, pooled) catch {};
                    }
                }

                self.idle_mutex.unlock();
            }

            // 2. 不持锁：异步执行 ping
            for (conns_to_ping.items) |pooled| {
                // 检查是否关闭
                self.state_mutex.lock();
                if (self.closed) {
                    self.state_mutex.unlock();
                    break;
                }
                self.state_mutex.unlock();

                // 执行 ping（不持锁，不阻塞业务）
                const ping_ok = if (pooled.conn.exec("SELECT 1")) |_| true else |_| false;

                // 重新加锁更新状态 (仅修改 connection 自身状态，不需要池锁)
                pooled.mutex.lock();
                if (ping_ok) {
                    pooled.last_used = std.time.milliTimestamp();
                } else {
                    pooled.last_used = 0; // 标记为需要重建
                }
                pooled.mutex.unlock();

                pooled.is_pinging.store(false, .seq_cst);
            }
        }
    }

    pub fn deinit(self: *ConnectionPool) void {
        // 先标记关闭，让保活线程退出
        self.state_mutex.lock();
        self.closed = true;
        self.state_mutex.unlock();

        self.condition.broadcast();

        // 等待保活线程结束
        if (self.keepalive_thread) |thread| {
            thread.join();
        }

        self.state_mutex.lock();
        defer self.state_mutex.unlock();

        self.idle_mutex.lock();
        defer self.idle_mutex.unlock();

        // 释放所有连接
        for (self.all_connections.items) |pooled| {
            pooled.conn.deinit();
            self.allocator.destroy(pooled);
        }

        self.all_connections.deinit(self.allocator);
        self.idle_connections.deinit(self.allocator);
    }

    /// 获取连接
    pub fn acquire(self: *ConnectionPool) !*PooledConnection {
        const deadline = std.time.milliTimestamp() + @as(i64, @intCast(self.config.acquire_timeout_ms));

        while (true) {
            // 1. 快速路径：从 idle 栈中查找可用连接 (O(1) ~ O(K))
            self.idle_mutex.lock();

            // 检查关闭状态需要 state_mutex?
            // 简化：acquire 假设 state 不会突然变，除非 deinit
            // 但为了安全，可以在 wait 之前检查。
            // 这里我们尽量只用 idle_mutex 进行快速路径

            if (self.idle_connections.items.len > 0) {
                var found_idx: ?usize = null;
                var i: usize = self.idle_connections.items.len;
                while (i > 0) {
                    i -= 1;
                    const item = self.idle_connections.items[i];
                    if (!item.is_pinging.load(.seq_cst) and !item.borrowed) {
                        found_idx = i;
                        break;
                    }
                }

                if (found_idx) |idx| {
                    const pooled = self.idle_connections.swapRemove(idx);
                    self.idle_mutex.unlock();

                    if (pooled.isHealthy(self.config)) {
                        pooled.mutex.lock();
                        pooled.in_use = true;
                        pooled.borrowed = true;
                        pooled.last_used = std.time.milliTimestamp();
                        pooled.mutex.unlock();
                        return pooled;
                    } else {
                        // 连接不健康处理...
                        pooled.conn.deinit();
                        // 不用再解锁了，上面已经解锁

                        if (interface.Driver.mysql(self.allocator, self.db_config)) |new_conn| {
                            pooled.conn = new_conn;
                            pooled.mutex.lock();
                            pooled.created_at = std.time.milliTimestamp();
                            pooled.last_used = std.time.milliTimestamp();
                            pooled.in_use = true;
                            pooled.borrowed = true;
                            pooled.broken = false;
                            pooled.mutex.unlock();
                            // 注意：swapRemove 已经移除了它，所以直接返回即可，不需要重新加入
                            return pooled;
                        } else |_| {
                            self.state_mutex.lock();
                            for (self.all_connections.items, 0..) |p, k| {
                                if (p == pooled) {
                                    _ = self.all_connections.swapRemove(k);
                                    break;
                                }
                            }
                            self.state_mutex.unlock();

                            self.allocator.destroy(pooled);
                            continue;
                        }
                    }
                }
            }
            self.idle_mutex.unlock();

            // 2. 慢速路径：如果没有空闲连接，检查是否可以创建新连接
            // 需要锁定 state_mutex 来检查 all_connections
            self.state_mutex.lock();

            if (self.closed) {
                self.state_mutex.unlock();
                return error.PoolClosed;
            }

            if (self.all_connections.items.len < self.config.max_size) {
                // 预留名额？不，直接释放锁去创建。
                // 风险：可能创建超限。
                // 解决方案：使用 CAS 或者乐观创建。
                // 这里采用乐观创建：释放锁 -> 创建 -> 加锁 -> 检查 -> 放入。

                self.state_mutex.unlock();

                // 在锁外创建连接（耗时操作）
                var conn = interface.Driver.mysql(self.allocator, self.db_config) catch |err| {
                    return err;
                };

                // 重新获取锁
                self.state_mutex.lock();

                if (self.closed) {
                    conn.deinit();
                    self.state_mutex.unlock();
                    return error.PoolClosed;
                }

                // 再次检查容量
                if (self.all_connections.items.len < self.config.max_size) {
                    const pooled = self.allocator.create(PooledConnection) catch |err| {
                        conn.deinit();
                        self.state_mutex.unlock();
                        return err;
                    };
                    pooled.* = PooledConnection.init(conn, self.next_id);
                    self.next_id += 1;
                    pooled.in_use = true;
                    pooled.borrowed = true;

                    self.all_connections.append(self.allocator, pooled) catch |err| {
                        conn.deinit();
                        self.allocator.destroy(pooled);
                        self.state_mutex.unlock();
                        return err;
                    };

                    self.state_mutex.unlock();
                    return pooled;
                } else {
                    // 竞争失败，池已满。销毁刚创建的连接。
                    conn.deinit();
                    // 继续向下执行 wait
                }
            }

            // Wait for signal
            const now = std.time.milliTimestamp();
            if (now >= deadline) {
                self.state_mutex.unlock();
                return error.AcquireTimeout;
            }

            const wait_time_ns = @as(u64, @intCast(deadline - now)) * std.time.ns_per_ms;
            // wait releases state_mutex
            self.condition.timedWait(&self.state_mutex, wait_time_ns) catch {};
            self.state_mutex.unlock();
        }
    }

    /// 归还连接
    pub fn release(self: *ConnectionPool, conn: *PooledConnection) void {
        // 1. 先清理连接状态（不持池锁）
        // 使用连接自己的锁来保护状态变更
        {
            conn.mutex.lock();
            defer conn.mutex.unlock();

            if (conn.in_transaction) {
                conn.conn.rollback() catch {};
                conn.in_transaction = false;
                conn.transaction_start = null;
            }

            conn.in_use = false;
            conn.borrowed = false;
            conn.last_used = std.time.milliTimestamp();
        }

        // 2. 再归还到池中（持池锁）
        // 如果连接已损坏，销毁它
        if (conn.broken) {
            conn.conn.deinit();
            // 从 all_connections 移除

            self.state_mutex.lock();
            for (self.all_connections.items, 0..) |p, i| {
                if (p == conn) {
                    _ = self.all_connections.swapRemove(i);
                    break;
                }
            }
            self.state_mutex.unlock();

            self.allocator.destroy(conn);
            self.condition.signal(); // 通知可能在等待容量释放的线程
            return;
        }

        self.idle_mutex.lock();
        self.idle_connections.append(self.allocator, conn) catch {
            self.idle_mutex.unlock();

            // 如果归还失败（OOM），只能销毁连接了
            self.state_mutex.lock();
            for (self.all_connections.items, 0..) |p, i| {
                if (p == conn) {
                    _ = self.all_connections.swapRemove(i);
                    break;
                }
            }
            self.state_mutex.unlock();

            conn.conn.deinit();
            self.allocator.destroy(conn);
            return;
        };
        self.idle_mutex.unlock();

        self.condition.signal();
    }

    /// 清理不健康的连接 (已在 keepalive 中处理，此处保留空实现或用于手动触发)
    fn cleanupUnhealthyConnections(self: *ConnectionPool) !void {
        _ = self;
    }

    /// 获取池统计信息
    pub fn getStats(self: *ConnectionPool) PoolStats {
        self.state_mutex.lock();
        const total = self.all_connections.items.len;
        self.state_mutex.unlock();

        self.idle_mutex.lock();
        const idle = self.idle_connections.items.len;
        self.idle_mutex.unlock();

        const active = if (total >= idle) total - idle else 0;

        const stats = PoolStats{
            .total = total,
            .active = active,
            .idle = idle,
            .in_transaction = 0,
        };

        // in_transaction 统计不再准确，或者需要遍历 all_connections（O(N)）
        // 为了性能，这里不再遍历

        return stats;
    }
};
pub const Transaction = struct {
    pool: *ConnectionPool,
    conn: *PooledConnection,
    committed: bool = false,
    rolled_back: bool = false,

    pub fn init(pool: *ConnectionPool) !Transaction {
        const conn = try pool.acquire();

        conn.mutex.lock();
        conn.in_transaction = true;
        conn.transaction_start = std.time.milliTimestamp();
        conn.mutex.unlock();

        try conn.conn.beginTransaction();

        return Transaction{
            .pool = pool,
            .conn = conn,
            .committed = false,
            .rolled_back = false,
        };
    }

    pub fn deinit(self: *Transaction) void {
        if (!self.committed and !self.rolled_back) {
            self.rollback() catch {};
        }

        self.pool.release(self.conn);
    }

    pub fn commit(self: *Transaction) !void {
        if (self.committed or self.rolled_back) {
            return error.TransactionAlreadyFinished;
        }

        try self.conn.conn.commit();
        self.committed = true;

        self.conn.mutex.lock();
        self.conn.in_transaction = false;
        self.conn.transaction_start = null;
        self.conn.mutex.unlock();
    }

    pub fn rollback(self: *Transaction) !void {
        if (self.committed or self.rolled_back) {
            return error.TransactionAlreadyFinished;
        }

        try self.conn.conn.rollback();
        self.rolled_back = true;

        self.conn.mutex.lock();
        self.conn.in_transaction = false;
        self.conn.transaction_start = null;
        self.conn.mutex.unlock();
    }

    pub fn query(self: *Transaction, sql: []const u8) !interface.ResultSet {
        if (self.committed or self.rolled_back) {
            return error.TransactionAlreadyFinished;
        }

        return self.conn.conn.query(sql);
    }

    pub fn exec(self: *Transaction, sql: []const u8) !u64 {
        if (self.committed or self.rolled_back) {
            return error.TransactionAlreadyFinished;
        }

        return self.conn.conn.exec(sql);
    }

    /// 别名：与 Database 接口兼容
    pub fn rawExec(self: *Transaction, sql: []const u8) !u64 {
        return self.exec(sql);
    }

    /// 别名：与 Database 接口兼容
    pub fn rawQuery(self: *Transaction, sql: []const u8) !interface.ResultSet {
        return self.query(sql);
    }
};

// ============================================================================
// 关联查询构建器
// ============================================================================

/// 关联类型
pub const RelationType = enum {
    has_one,
    has_many,
    belongs_to,
};

/// 关联查询构建器
/// 用于处理 hasOne, hasMany, belongsTo 关联
pub fn RelationQuery(comptime T: type) type {
    return struct {
        const Self = @This();
        const Model = define(T);

        db: *Database,
        foreign_key: []const u8,
        foreign_value: u64,
        relation_type: RelationType,
        conditions: std.ArrayListUnmanaged(Condition),
        order_items: std.ArrayListUnmanaged(OrderItem),
        limit_val: ?u64,

        const Condition = struct {
            sql: []const u8,
            owns_sql: bool,
        };

        const OrderItem = struct {
            field: []const u8,
            dir: query_mod.OrderDir,
        };

        pub fn init(db: *Database, foreign_key: []const u8, foreign_value: u64, relation_type: RelationType) Self {
            return Self{
                .db = db,
                .foreign_key = foreign_key,
                .foreign_value = foreign_value,
                .relation_type = relation_type,
                .conditions = .{},
                .order_items = .{},
                .limit_val = null,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.conditions.items) |cond| {
                if (cond.owns_sql) {
                    self.db.allocator.free(cond.sql);
                }
            }
            self.conditions.deinit(self.db.allocator);
            self.order_items.deinit(self.db.allocator);
        }

        /// 添加额外条件
        pub fn where(self: *Self, field: []const u8, op: []const u8, value: anytype) *Self {
            const sql = formatWhere(self.db.allocator, field, op, value) catch return self;
            self.conditions.append(self.db.allocator, .{ .sql = sql, .owns_sql = true }) catch {};
            return self;
        }

        /// 排序
        pub fn orderBy(self: *Self, field: []const u8, dir: query_mod.OrderDir) *Self {
            self.order_items.append(self.db.allocator, .{ .field = field, .dir = dir }) catch {};
            return self;
        }

        /// 限制数量
        pub fn limit(self: *Self, n: u64) *Self {
            self.limit_val = n;
            return self;
        }

        /// 获取关联数据
        pub fn get(self: *Self) ![]T {
            defer self.deinit();

            var sql_buf = std.ArrayListUnmanaged(u8){};
            defer sql_buf.deinit(self.db.allocator);

            try sql_buf.appendSlice(self.db.allocator, "SELECT * FROM ");
            try sql_buf.appendSlice(self.db.allocator, Model.tableName());
            try sql_buf.appendSlice(self.db.allocator, " WHERE ");
            try sql_buf.appendSlice(self.db.allocator, self.foreign_key);
            try sql_buf.appendSlice(self.db.allocator, " = ");

            var id_buf: [32]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_buf, "{d}", .{self.foreign_value}) catch "0";
            try sql_buf.appendSlice(self.db.allocator, id_str);

            // 添加额外条件
            for (self.conditions.items) |cond| {
                try sql_buf.appendSlice(self.db.allocator, " AND ");
                try sql_buf.appendSlice(self.db.allocator, cond.sql);
            }

            // 排序
            if (self.order_items.items.len > 0) {
                try sql_buf.appendSlice(self.db.allocator, " ORDER BY ");
                for (self.order_items.items, 0..) |item, i| {
                    if (i > 0) try sql_buf.appendSlice(self.db.allocator, ", ");
                    try sql_buf.appendSlice(self.db.allocator, item.field);
                    try sql_buf.appendSlice(self.db.allocator, if (item.dir == .desc) " DESC" else " ASC");
                }
            }

            // 限制
            if (self.limit_val) |lim| {
                try sql_buf.appendSlice(self.db.allocator, " LIMIT ");
                var lim_buf: [32]u8 = undefined;
                const lim_str = std.fmt.bufPrint(&lim_buf, "{d}", .{lim}) catch "1";
                try sql_buf.appendSlice(self.db.allocator, lim_str);
            } else if (self.relation_type == .has_one or self.relation_type == .belongs_to) {
                try sql_buf.appendSlice(self.db.allocator, " LIMIT 1");
            }

            const sql = try sql_buf.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql);

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            return mapResults(T, self.db.allocator, &result);
        }

        /// 获取第一条关联记录
        pub fn first(self: *Self) !?T {
            _ = self.limit(1);
            const results = try self.get();
            if (results.len == 0) return null;
            defer self.db.allocator.free(results);
            return results[0];
        }

        /// 获取关联数量
        pub fn count(self: *Self) !u64 {
            var sql_buf = std.ArrayListUnmanaged(u8){};
            defer sql_buf.deinit(self.db.allocator);

            try sql_buf.appendSlice(self.db.allocator, "SELECT COUNT(*) as cnt FROM ");
            try sql_buf.appendSlice(self.db.allocator, Model.tableName());
            try sql_buf.appendSlice(self.db.allocator, " WHERE ");
            try sql_buf.appendSlice(self.db.allocator, self.foreign_key);
            try sql_buf.appendSlice(self.db.allocator, " = ");

            var id_buf: [32]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_buf, "{d}", .{self.foreign_value}) catch "0";
            try sql_buf.appendSlice(self.db.allocator, id_str);

            // 添加额外条件
            for (self.conditions.items) |cond| {
                try sql_buf.appendSlice(self.db.allocator, " AND ");
                try sql_buf.appendSlice(self.db.allocator, cond.sql);
            }

            const sql = try sql_buf.toOwnedSlice(self.db.allocator);
            defer self.db.allocator.free(sql);

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            if (result.next()) |row| {
                if (row.getString("cnt")) |cnt_str| {
                    return std.fmt.parseInt(u64, cnt_str, 10) catch 0;
                }
            }
            return 0;
        }

        /// 检查是否存在关联
        pub fn exists(self: *Self) !bool {
            const cnt = try self.count();
            self.deinit();
            return cnt > 0;
        }

        /// 获取并返回 List 包装器
        pub fn collect(self: *Self) !Model.List {
            const data = try self.get();
            return Model.List{ .allocator = self.db.allocator, .data = data };
        }
    };
}

/// 预加载查询构建器 (With)
/// 用于预加载关联数据，避免 N+1 查询问题
pub fn WithQuery(comptime T: type, comptime Related: type) type {
    return struct {
        const Self = @This();
        const MainModel = define(T);
        const RelatedModel = define(Related);

        db: *Database,
        foreign_key: []const u8,
        conditions: std.ArrayListUnmanaged(Condition),
        order_items: std.ArrayListUnmanaged(OrderItem),
        limit_val: ?u64,

        const Condition = struct {
            sql: []const u8,
            owns_sql: bool,
        };

        const OrderItem = struct {
            field: []const u8,
            dir: query_mod.OrderDir,
        };

        /// 预加载结果
        pub const WithResult = struct {
            main: T,
            related: []Related,
        };

        pub fn init(db: *Database, foreign_key: []const u8) Self {
            return Self{
                .db = db,
                .foreign_key = foreign_key,
                .conditions = .{},
                .order_items = .{},
                .limit_val = null,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.conditions.items) |cond| {
                if (cond.owns_sql) {
                    self.db.allocator.free(cond.sql);
                }
            }
            self.conditions.deinit(self.db.allocator);
            self.order_items.deinit(self.db.allocator);
        }

        /// 添加主模型条件
        pub fn where(self: *Self, field: []const u8, op: []const u8, value: anytype) *Self {
            const sql = formatWhere(self.db.allocator, field, op, value) catch return self;
            self.conditions.append(self.db.allocator, .{ .sql = sql, .owns_sql = true }) catch {};
            return self;
        }

        /// 排序
        pub fn orderBy(self: *Self, field: []const u8, dir: query_mod.OrderDir) *Self {
            self.order_items.append(self.db.allocator, .{ .field = field, .dir = dir }) catch {};
            return self;
        }

        /// 限制数量
        pub fn limit(self: *Self, n: u64) *Self {
            self.limit_val = n;
            return self;
        }

        /// 获取主模型及其关联数据
        pub fn get(self: *Self) ![]WithResult {
            defer self.deinit();

            // 1. 先获取主模型
            var main_query = MainModel.Query();
            defer main_query.deinit();

            for (self.conditions.items) |cond| {
                _ = main_query.whereRaw(cond.sql);
            }
            for (self.order_items.items) |item| {
                _ = main_query.orderBy(item.field, item.dir);
            }
            if (self.limit_val) |lim| {
                _ = main_query.limit(lim);
            }

            const mains = try main_query.get();
            if (mains.len == 0) {
                return &[_]WithResult{};
            }

            // 2. 收集主键 ID
            var ids = std.ArrayList(u64).init(self.db.allocator);
            defer ids.deinit();

            const pk = MainModel.primaryKey();
            for (mains) |main| {
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, field.name, pk)) {
                        try ids.append(@field(main, field.name));
                        break;
                    }
                }
            }

            // 3. 批量查询关联数据 (避免 N+1)
            var related_query = RelatedModel.Query();
            defer related_query.deinit();
            _ = related_query.whereIn(self.foreign_key, ids.items);

            const all_related = try related_query.get();
            defer self.db.allocator.free(all_related);

            // 4. 组装结果
            var results = std.ArrayList(WithResult).init(self.db.allocator);
            errdefer results.deinit();

            for (mains) |main| {
                var main_id: u64 = 0;
                inline for (std.meta.fields(T)) |field| {
                    if (std.mem.eql(u8, field.name, pk)) {
                        main_id = @field(main, field.name);
                        break;
                    }
                }

                // 收集该主模型的关联
                var related_list = std.ArrayList(Related).init(self.db.allocator);
                for (all_related) |rel| {
                    var rel_fk: u64 = 0;
                    inline for (std.meta.fields(Related)) |field| {
                        if (std.mem.eql(u8, field.name, self.foreign_key)) {
                            const val = @field(rel, field.name);
                            if (@TypeOf(val) == u64) {
                                rel_fk = val;
                            } else if (@TypeOf(val) == ?u64) {
                                rel_fk = val orelse 0;
                            } else if (@TypeOf(val) == u32) {
                                rel_fk = val;
                            } else if (@TypeOf(val) == ?u32) {
                                rel_fk = val orelse 0;
                            }
                            break;
                        }
                    }
                    if (rel_fk == main_id) {
                        try related_list.append(rel);
                    }
                }

                try results.append(.{
                    .main = main,
                    .related = try related_list.toOwnedSlice(),
                });
            }

            return results.toOwnedSlice();
        }

        /// 释放 WithResult 数组
        pub fn freeResults(allocator: Allocator, results: []WithResult) void {
            for (results) |result| {
                for (result.related) |*rel| {
                    var r = rel.*;
                    RelatedModel.freeModel(allocator, &r);
                }
                allocator.free(result.related);
                var m = result.main;
                MainModel.freeModel(allocator, &m);
            }
            allocator.free(results);
        }
    };
}

// ============================================================================
// 数据库迁移器
// ============================================================================

/// 迁移器 - 支持多模型批量操作
/// 使用示例:
/// ```zig
/// const Migrator = orm.Migrator;
///
/// // 创建所有表
/// try Migrator.createAll(&db, .{
///     orm_models.Admin,
///     orm_models.Article,
///     orm_models.Category,
/// });
///
/// // 删除所有表
/// try Migrator.dropAll(&db, .{
///     orm_models.Category,
///     orm_models.Article,
///     orm_models.Admin,
/// });
///
/// // 打印所有建表语句
/// Migrator.printSql(.mysql, .{
///     orm_models.Admin,
///     orm_models.Article,
/// });
/// ```
pub const Migrator = struct {
    /// 批量创建表
    pub fn createAll(db: *Database, comptime models: anytype) !void {
        inline for (models) |Model| {
            try Model.createTable(db);
        }
    }

    /// 批量删除表
    pub fn dropAll(db: *Database, comptime models: anytype) !void {
        inline for (models) |Model| {
            try Model.dropTable(db);
        }
    }

    /// 刷新表（删除后重建）
    pub fn refreshAll(db: *Database, comptime drop_order: anytype, comptime create_order: anytype) !void {
        inline for (drop_order) |Model| {
            try Model.dropTable(db);
        }
        inline for (create_order) |Model| {
            try Model.createTable(db);
        }
    }

    /// 打印所有建表语句（调试用）
    pub fn printSql(comptime dialect: Dialect, comptime models: anytype) void {
        std.debug.print("\n========== Migration SQL ({s}) ==========\n\n", .{@tagName(dialect)});
        inline for (models) |Model| {
            std.debug.print("-- {s}\n{s}\n\n", .{ Model.tableName(), Model.createTableSql(dialect) });
        }
        std.debug.print("==========================================\n", .{});
    }

    /// 打印所有删表语句
    pub fn printDropSql(comptime models: anytype) void {
        std.debug.print("\n========== Drop SQL ==========\n\n", .{});
        inline for (models) |Model| {
            std.debug.print("{s}\n", .{Model.dropTableSql()});
        }
        std.debug.print("==============================\n", .{});
    }

    /// 获取建表 SQL 数组（运行时）
    pub fn getCreateSqlList(comptime dialect: Dialect, comptime models: anytype, allocator: Allocator) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();

        inline for (models) |Model| {
            try list.append(Model.createTableSql(dialect));
        }

        return list.toOwnedSlice();
    }
};
