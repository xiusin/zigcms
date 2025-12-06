//! 数据库驱动接口
//!
//! 提供统一的数据库驱动抽象，支持多种数据库后端：
//! - MySQL
//! - SQLite3
//! - PostgreSQL (未来)
//!
//! ## 使用示例
//!
//! ```zig
//! const db = @import("services").mysql;
//!
//! // 使用 SQLite（测试/开发）
//! var conn = try db.Driver.sqlite(allocator, ":memory:");
//! defer conn.deinit();
//!
//! // 使用 MySQL（生产）
//! var conn = try db.Driver.mysql(allocator, .{
//!     .host = "localhost",
//!     .database = "myapp",
//! });
//! defer conn.deinit();
//!
//! // 统一的操作接口
//! var result = try conn.query("SELECT * FROM users");
//! defer result.deinit();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// 驱动类型
// ============================================================================

/// 数据库驱动类型
pub const DriverType = enum {
    mysql,
    sqlite,
    postgresql, // 预留
    memory, // 内存模拟（纯测试）
};

// ============================================================================
// 统一接口
// ============================================================================

/// 查询结果行
pub const Row = struct {
    allocator: Allocator,
    columns: []const []const u8,
    values: []?[]const u8,

    /// 获取字符串值
    pub fn getString(self: *const Row, column: []const u8) ?[]const u8 {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col, column)) {
                return self.values[i];
            }
        }
        return null;
    }

    /// 获取整数值
    pub fn getInt(self: *const Row, column: []const u8) ?i64 {
        const val = self.getString(column) orelse return null;
        return std.fmt.parseInt(i64, val, 10) catch null;
    }

    /// 获取浮点值
    pub fn getFloat(self: *const Row, column: []const u8) ?f64 {
        const val = self.getString(column) orelse return null;
        return std.fmt.parseFloat(f64, val) catch null;
    }

    /// 获取布尔值
    pub fn getBool(self: *const Row, column: []const u8) ?bool {
        const val = self.getString(column) orelse return null;
        if (std.mem.eql(u8, val, "1") or std.mem.eql(u8, val, "true")) return true;
        if (std.mem.eql(u8, val, "0") or std.mem.eql(u8, val, "false")) return false;
        return null;
    }

    pub fn deinit(self: *Row) void {
        // 释放值字符串（如果是堆分配的）
        for (self.values) |val| {
            if (val) |v| {
                self.allocator.free(v);
            }
        }
        self.allocator.free(self.columns);
        self.allocator.free(self.values);
    }
};

/// 查询结果集
pub const ResultSet = struct {
    allocator: Allocator,
    driver_type: DriverType,
    rows: std.ArrayListUnmanaged(Row),
    field_names: []const []const u8,
    current_index: usize = 0,
    affected_rows: u64 = 0,
    last_insert_id: u64 = 0,

    pub fn init(allocator: Allocator, driver_type: DriverType) ResultSet {
        return .{
            .allocator = allocator,
            .driver_type = driver_type,
            .rows = .{},
            .field_names = &.{},
        };
    }

    pub fn deinit(self: *ResultSet) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit(self.allocator);
        if (self.field_names.len > 0) {
            // 释放field_names中的字符串（如果是SQLite分配的）
            if (self.driver_type == .sqlite) {
                for (self.field_names) |name| {
                    self.allocator.free(name);
                }
            }
            self.allocator.free(self.field_names);
        }
    }

    /// 获取下一行
    pub fn next(self: *ResultSet) ?*Row {
        if (self.current_index >= self.rows.items.len) return null;
        const row = &self.rows.items[self.current_index];
        self.current_index += 1;
        return row;
    }

    /// 重置迭代器
    pub fn reset(self: *ResultSet) void {
        self.current_index = 0;
    }

    /// 行数
    pub fn rowCount(self: *const ResultSet) usize {
        return self.rows.items.len;
    }
};

/// 数据库连接接口
pub const Connection = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    allocator: Allocator,
    driver_type: DriverType,

    pub const VTable = struct {
        query: *const fn (*anyopaque, Allocator, []const u8) anyerror!ResultSet,
        exec: *const fn (*anyopaque, []const u8) anyerror!u64,
        beginTransaction: *const fn (*anyopaque) anyerror!void,
        commit: *const fn (*anyopaque) anyerror!void,
        rollback: *const fn (*anyopaque) anyerror!void,
        lastInsertId: *const fn (*anyopaque) u64,
        deinit: *const fn (*anyopaque) void,
    };

    /// 执行查询
    pub fn query(self: *Connection, sql: []const u8) !ResultSet {
        return self.vtable.query(self.ptr, self.allocator, sql);
    }

    /// 执行命令
    pub fn exec(self: *Connection, sql: []const u8) !u64 {
        return self.vtable.exec(self.ptr, sql);
    }

    /// 开始事务
    pub fn beginTransaction(self: *Connection) !void {
        return self.vtable.beginTransaction(self.ptr);
    }

    /// 提交事务
    pub fn commit(self: *Connection) !void {
        return self.vtable.commit(self.ptr);
    }

    /// 回滚事务
    pub fn rollback(self: *Connection) !void {
        return self.vtable.rollback(self.ptr);
    }

    /// 获取最后插入ID
    pub fn lastInsertId(self: *Connection) u64 {
        return self.vtable.lastInsertId(self.ptr);
    }

    /// 关闭连接
    pub fn deinit(self: *Connection) void {
        self.vtable.deinit(self.ptr);
        // 释放驱动实例内存
        switch (self.driver_type) {
            .mysql => {
                const mysql_driver = @import("driver.zig");
                const typed_ptr: *mysql_driver.Connection = @ptrCast(@alignCast(self.ptr));
                self.allocator.destroy(typed_ptr);
            },
            .sqlite => {
                const typed_ptr: *SQLiteDriver = @ptrCast(@alignCast(self.ptr));
                self.allocator.destroy(typed_ptr);
            },
            .memory => {
                const typed_ptr: *MemoryDriver = @ptrCast(@alignCast(self.ptr));
                self.allocator.destroy(typed_ptr);
            },
            .postgresql => {},
        }
    }

    /// 获取驱动类型
    pub fn getDriverType(self: *const Connection) DriverType {
        return self.driver_type;
    }
};

// ============================================================================
// 驱动工厂
// ============================================================================

/// MySQL 配置
pub const MySQLConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 3306,
    user: []const u8 = "root",
    password: []const u8 = "",
    database: []const u8 = "",
    charset: []const u8 = "utf8mb4",
};

/// SQLite 配置
pub const SQLiteConfig = struct {
    path: []const u8 = ":memory:",
    flags: u32 = 0,
};

/// 驱动工厂
pub const Driver = struct {
    /// 创建 MySQL 连接
    pub fn mysql(allocator: Allocator, config: MySQLConfig) !Connection {
        const mysql_driver = @import("driver.zig");
        const conn = try mysql_driver.Connection.init(allocator, .{
            .host = config.host,
            .port = config.port,
            .user = config.user,
            .password = config.password,
            .database = config.database,
            .charset = config.charset,
        });

        const ptr = try allocator.create(mysql_driver.Connection);
        ptr.* = conn;

        return Connection{
            .ptr = ptr,
            .vtable = &mysql_vtable,
            .allocator = allocator,
            .driver_type = .mysql,
        };
    }

    /// 创建 SQLite 连接
    pub fn sqlite(allocator: Allocator, path: []const u8) !Connection {
        const sqlite_impl = try SQLiteDriver.init(allocator, path);

        const ptr = try allocator.create(SQLiteDriver);
        ptr.* = sqlite_impl;

        return Connection{
            .ptr = ptr,
            .vtable = &sqlite_vtable,
            .allocator = allocator,
            .driver_type = .sqlite,
        };
    }

    /// 创建内存模拟连接（纯测试用）
    pub fn memory(allocator: Allocator) !Connection {
        const mem_impl = try MemoryDriver.init(allocator);

        const ptr = try allocator.create(MemoryDriver);
        ptr.* = mem_impl;

        return Connection{
            .ptr = ptr,
            .vtable = &memory_vtable,
            .allocator = allocator,
            .driver_type = .memory,
        };
    }
};

// ============================================================================
// MySQL VTable
// ============================================================================

const mysql_vtable = Connection.VTable{
    .query = mysqlQuery,
    .exec = mysqlExec,
    .beginTransaction = mysqlBeginTransaction,
    .commit = mysqlCommit,
    .rollback = mysqlRollback,
    .lastInsertId = mysqlLastInsertId,
    .deinit = mysqlDeinit,
};

fn mysqlQuery(ptr: *anyopaque, allocator: Allocator, sql: []const u8) !ResultSet {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));

    var driver_result = try conn.query(sql);
    defer driver_result.deinit();

    var result = ResultSet.init(allocator, .mysql);
    result.affected_rows = driver_result.affected_rows;
    result.last_insert_id = driver_result.insert_id;

    // 复制字段名
    if (driver_result.field_names.len > 0) {
        result.field_names = try allocator.dupe([]const u8, driver_result.field_names);
    }

    // 复制行数据
    while (try driver_result.next()) |row| {
        const columns = try allocator.dupe([]const u8, row.field_names);
        var values = try allocator.alloc(?[]const u8, columns.len);

        for (columns, 0..) |col, i| {
            values[i] = row.getString(col);
        }

        try result.rows.append(allocator, .{
            .allocator = allocator,
            .columns = columns,
            .values = values,
        });
    }

    return result;
}

fn mysqlExec(ptr: *anyopaque, sql: []const u8) !u64 {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    return conn.exec(sql);
}

fn mysqlBeginTransaction(ptr: *anyopaque) !void {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    try conn.beginTransaction();
}

fn mysqlCommit(ptr: *anyopaque) !void {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    try conn.commit();
}

fn mysqlRollback(ptr: *anyopaque) !void {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    try conn.rollback();
}

fn mysqlLastInsertId(ptr: *anyopaque) u64 {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    return conn.lastInsertId();
}

fn mysqlDeinit(ptr: *anyopaque) void {
    const mysql_driver = @import("driver.zig");
    const conn: *mysql_driver.Connection = @ptrCast(@alignCast(ptr));
    conn.deinit();
}

// ============================================================================
// SQLite 驱动
// ============================================================================

/// SQLite C API 绑定
const sqlite3 = struct {
    pub const Database = opaque {};
    pub const Statement = opaque {};

    pub const SQLITE_OK = 0;
    pub const SQLITE_ROW = 100;
    pub const SQLITE_DONE = 101;
    pub const SQLITE_OPEN_READWRITE = 0x00000002;
    pub const SQLITE_OPEN_CREATE = 0x00000004;

    pub extern fn sqlite3_open(filename: [*c]const u8, ppDb: *?*Database) c_int;
    pub extern fn sqlite3_close(db: *Database) c_int;
    pub extern fn sqlite3_exec(
        db: *Database,
        sql: [*c]const u8,
        callback: ?*anyopaque, // 简化为anyopaque
        arg: ?*anyopaque,
        errmsg: ?*[*c]u8,
    ) c_int;
    pub extern fn sqlite3_prepare_v2(
        db: *Database,
        sql: [*c]const u8,
        nByte: c_int,
        ppStmt: *?*Statement,
        pzTail: ?*[*c]const u8,
    ) c_int;
    pub extern fn sqlite3_step(stmt: *Statement) c_int;
    pub extern fn sqlite3_finalize(stmt: *Statement) c_int;
    pub extern fn sqlite3_reset(stmt: *Statement) c_int;
    pub extern fn sqlite3_column_count(stmt: *Statement) c_int;
    pub extern fn sqlite3_column_name(stmt: *Statement, col: c_int) [*c]const u8;
    pub extern fn sqlite3_column_text(stmt: *Statement, col: c_int) [*c]const u8;
    pub extern fn sqlite3_column_int64(stmt: *Statement, col: c_int) i64;
    pub extern fn sqlite3_column_double(stmt: *Statement, col: c_int) f64;
    pub extern fn sqlite3_column_type(stmt: *Statement, col: c_int) c_int;
    pub extern fn sqlite3_changes(db: *Database) c_int;
    pub extern fn sqlite3_last_insert_rowid(db: *Database) i64;
    pub extern fn sqlite3_errmsg(db: *Database) [*c]const u8;
};

/// SQLite 驱动实现
const SQLiteDriver = struct {
    allocator: Allocator,
    db: *sqlite3.Database,
    last_insert_id: u64 = 0,

    pub fn init(allocator: Allocator, path: []const u8) !SQLiteDriver {
        var db: ?*sqlite3.Database = null;

        // 转换路径为C字符串
        var path_buf: [4096]u8 = undefined;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        const rc = sqlite3.sqlite3_open(&path_buf, &db);
        if (rc != sqlite3.SQLITE_OK or db == null) {
            return error.ConnectionFailed;
        }

        return SQLiteDriver{
            .allocator = allocator,
            .db = db.?,
        };
    }

    pub fn deinit(self: *SQLiteDriver) void {
        _ = sqlite3.sqlite3_close(self.db);
    }

    pub fn query(self: *SQLiteDriver, allocator: Allocator, sql: []const u8) !ResultSet {
        var result = ResultSet.init(allocator, .sqlite);

        // 准备语句
        var stmt: ?*sqlite3.Statement = null;
        var sql_buf: [8192]u8 = undefined;
        @memcpy(sql_buf[0..sql.len], sql);
        sql_buf[sql.len] = 0;

        const rc = sqlite3.sqlite3_prepare_v2(self.db, &sql_buf, @intCast(sql.len), &stmt, null);
        if (rc != sqlite3.SQLITE_OK or stmt == null) {
            return error.QueryFailed;
        }
        defer _ = sqlite3.sqlite3_finalize(stmt.?);

        // 获取列信息
        const col_count: usize = @intCast(sqlite3.sqlite3_column_count(stmt.?));
        if (col_count > 0) {
            const field_names_buf = try allocator.alloc([]const u8, col_count);
            for (0..col_count) |i| {
                const name = sqlite3.sqlite3_column_name(stmt.?, @intCast(i));
                // 复制列名到堆内存（SQLite的字符串在statement关闭后无效）
                field_names_buf[i] = try allocator.dupe(u8, std.mem.span(name));
            }
            result.field_names = field_names_buf;
        }

        // 读取行
        while (sqlite3.sqlite3_step(stmt.?) == sqlite3.SQLITE_ROW) {
            const columns = try allocator.dupe([]const u8, result.field_names);
            var values = try allocator.alloc(?[]const u8, col_count);

            for (0..col_count) |i| {
                const text = sqlite3.sqlite3_column_text(stmt.?, @intCast(i));
                if (@intFromPtr(text) != 0) {
                    // 复制值到堆内存
                    values[i] = try allocator.dupe(u8, std.mem.span(text));
                } else {
                    values[i] = null;
                }
            }

            try result.rows.append(allocator, .{
                .allocator = allocator,
                .columns = columns,
                .values = values,
            });
        }

        return result;
    }

    pub fn exec(self: *SQLiteDriver, sql: []const u8) !u64 {
        var sql_buf: [8192]u8 = undefined;
        @memcpy(sql_buf[0..sql.len], sql);
        sql_buf[sql.len] = 0;

        const rc = sqlite3.sqlite3_exec(self.db, &sql_buf, null, null, null);
        if (rc != sqlite3.SQLITE_OK) {
            return error.QueryFailed;
        }

        self.last_insert_id = @intCast(sqlite3.sqlite3_last_insert_rowid(self.db));
        return @intCast(sqlite3.sqlite3_changes(self.db));
    }

    pub fn beginTransaction(self: *SQLiteDriver) !void {
        _ = try self.exec("BEGIN TRANSACTION");
    }

    pub fn commit(self: *SQLiteDriver) !void {
        _ = try self.exec("COMMIT");
    }

    pub fn rollback(self: *SQLiteDriver) !void {
        _ = try self.exec("ROLLBACK");
    }

    pub fn lastInsertId(self: *SQLiteDriver) u64 {
        return self.last_insert_id;
    }
};

const sqlite_vtable = Connection.VTable{
    .query = sqliteQuery,
    .exec = sqliteExec,
    .beginTransaction = sqliteBeginTransaction,
    .commit = sqliteCommit,
    .rollback = sqliteRollback,
    .lastInsertId = sqliteLastInsertId,
    .deinit = sqliteDeinit,
};

fn sqliteQuery(ptr: *anyopaque, allocator: Allocator, sql: []const u8) !ResultSet {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    return driver.query(allocator, sql);
}

fn sqliteExec(ptr: *anyopaque, sql: []const u8) !u64 {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    return driver.exec(sql);
}

fn sqliteBeginTransaction(ptr: *anyopaque) !void {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    try driver.beginTransaction();
}

fn sqliteCommit(ptr: *anyopaque) !void {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    try driver.commit();
}

fn sqliteRollback(ptr: *anyopaque) !void {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    try driver.rollback();
}

fn sqliteLastInsertId(ptr: *anyopaque) u64 {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    return driver.lastInsertId();
}

fn sqliteDeinit(ptr: *anyopaque) void {
    const driver: *SQLiteDriver = @ptrCast(@alignCast(ptr));
    driver.deinit();
}

// ============================================================================
// 内存驱动（纯测试）
// ============================================================================

/// 内存驱动 - 用于无需数据库的单元测试
const MemoryDriver = struct {
    allocator: Allocator,
    tables: std.StringHashMapUnmanaged(Table),
    last_insert_id: u64 = 0,
    in_transaction: bool = false,

    const Table = struct {
        columns: []const []const u8,
        rows: std.ArrayList([]?[]const u8),
    };

    pub fn init(allocator: Allocator) !MemoryDriver {
        return MemoryDriver{
            .allocator = allocator,
            .tables = .{},
        };
    }

    pub fn deinit(self: *MemoryDriver) void {
        var it = self.tables.valueIterator();
        while (it.next()) |table| {
            table.rows.deinit();
        }
        self.tables.deinit(self.allocator);
    }

    pub fn query(self: *MemoryDriver, allocator: Allocator, sql: []const u8) !ResultSet {
        _ = self;
        _ = sql;
        return ResultSet.init(allocator, .memory);
    }

    pub fn exec(self: *MemoryDriver, sql: []const u8) !u64 {
        _ = sql;
        self.last_insert_id += 1;
        return 1;
    }

    pub fn beginTransaction(self: *MemoryDriver) !void {
        self.in_transaction = true;
    }

    pub fn commit(self: *MemoryDriver) !void {
        self.in_transaction = false;
    }

    pub fn rollback(self: *MemoryDriver) !void {
        self.in_transaction = false;
    }

    pub fn lastInsertId(self: *MemoryDriver) u64 {
        return self.last_insert_id;
    }
};

const memory_vtable = Connection.VTable{
    .query = memoryQuery,
    .exec = memoryExec,
    .beginTransaction = memoryBeginTransaction,
    .commit = memoryCommit,
    .rollback = memoryRollback,
    .lastInsertId = memoryLastInsertId,
    .deinit = memoryDeinit,
};

fn memoryQuery(ptr: *anyopaque, allocator: Allocator, sql: []const u8) !ResultSet {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    return driver.query(allocator, sql);
}

fn memoryExec(ptr: *anyopaque, sql: []const u8) !u64 {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    return driver.exec(sql);
}

fn memoryBeginTransaction(ptr: *anyopaque) !void {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    try driver.beginTransaction();
}

fn memoryCommit(ptr: *anyopaque) !void {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    try driver.commit();
}

fn memoryRollback(ptr: *anyopaque) !void {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    try driver.rollback();
}

fn memoryLastInsertId(ptr: *anyopaque) u64 {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    return driver.lastInsertId();
}

fn memoryDeinit(ptr: *anyopaque) void {
    const driver: *MemoryDriver = @ptrCast(@alignCast(ptr));
    driver.deinit();
}

// ============================================================================
// 测试
// ============================================================================

test "DriverType: 枚举" {
    try std.testing.expectEqual(DriverType.mysql, DriverType.mysql);
    try std.testing.expectEqual(DriverType.sqlite, DriverType.sqlite);
}

test "Row: 基本操作" {
    const allocator = std.testing.allocator;

    const columns = try allocator.dupe([]const u8, &.{ "id", "name", "active" });
    var values = try allocator.alloc(?[]const u8, 3);
    values[0] = "42";
    values[1] = "test";
    values[2] = "1";

    var row = Row{
        .allocator = allocator,
        .columns = columns,
        .values = values,
    };
    defer row.deinit();

    try std.testing.expectEqual(@as(?i64, 42), row.getInt("id"));
    try std.testing.expectEqualStrings("test", row.getString("name").?);
    try std.testing.expectEqual(@as(?bool, true), row.getBool("active"));
}

test "ResultSet: 迭代" {
    const allocator = std.testing.allocator;

    var result = ResultSet.init(allocator, .memory);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.rowCount());
    try std.testing.expect(result.next() == null);
}

test "MemoryDriver: 基本操作" {
    const allocator = std.testing.allocator;

    var conn = try Driver.memory(allocator);
    defer conn.deinit();

    try std.testing.expectEqual(DriverType.memory, conn.getDriverType());

    _ = try conn.exec("CREATE TABLE test (id INT)");
    try std.testing.expectEqual(@as(u64, 1), conn.lastInsertId());

    try conn.beginTransaction();
    try conn.commit();
}
