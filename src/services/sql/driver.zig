//! MySQL 驱动 - 基于 libmysqlclient 的真正数据库连接
//!
//! 通过 Zig 的 C 互操作调用 MySQL C API，实现真正的数据库连接。
//!
//! ## 依赖
//!
//! macOS: `brew install mysql-client`
//! Ubuntu: `sudo apt install libmysqlclient-dev`
//!
//! ## 使用示例
//!
//! ```zig
//! const driver = @import("services").sql.driver;
//!
//! // 连接数据库
//! var conn = try driver.Connection.init(allocator, .{
//!     .host = "localhost",
//!     .port = 3306,
//!     .user = "root",
//!     .password = "password",
//!     .database = "mydb",
//! });
//! defer conn.deinit();
//!
//! // 执行查询
//! var result = try conn.query("SELECT * FROM users WHERE id = ?", .{1});
//! defer result.deinit();
//!
//! // 遍历结果
//! while (try result.next()) |row| {
//!     const id = row.getInt("id");
//!     const name = row.getString("name");
//!     std.debug.print("User: {d} - {s}\n", .{id, name});
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const mysql_core = @import("query.zig");

// ============================================================================
// C API 绑定
// ============================================================================

/// MySQL C API 类型定义
const c = struct {
    // MySQL 句柄类型（opaque）
    pub const MYSQL = opaque {};
    pub const MYSQL_RES = opaque {};
    pub const MYSQL_ROW = [*c][*c]u8;
    pub const MYSQL_FIELD = extern struct {
        name: [*c]u8,
        org_name: [*c]u8,
        table: [*c]u8,
        org_table: [*c]u8,
        db: [*c]u8,
        catalog: [*c]u8,
        def: [*c]u8,
        length: c_ulong,
        max_length: c_ulong,
        name_length: c_uint,
        org_name_length: c_uint,
        table_length: c_uint,
        org_table_length: c_uint,
        db_length: c_uint,
        catalog_length: c_uint,
        def_length: c_uint,
        flags: c_uint,
        decimals: c_uint,
        charsetnr: c_uint,
        type: c_uint,
    };

    // MySQL 常量
    pub const CLIENT_MULTI_STATEMENTS: c_ulong = 65536;
    pub const CLIENT_MULTI_RESULTS: c_ulong = 131072;

    // SSL 模式选项
    pub const MYSQL_OPT_SSL_MODE: c_uint = 42; // MySQL 8.x
    pub const SSL_MODE_DISABLED: c_uint = 1;

    // mysql_options 函数
    pub extern fn mysql_options(mysql: *MYSQL, option: c_uint, arg: ?*const anyopaque) c_int;

    // C API 函数声明（移除不兼容的可选类型）
    pub extern fn mysql_init(mysql: ?*MYSQL) ?*MYSQL;
    pub extern fn mysql_real_connect(
        mysql: *MYSQL,
        host: [*c]const u8,
        user: [*c]const u8,
        passwd: [*c]const u8,
        db: [*c]const u8,
        port: c_uint,
        unix_socket: [*c]const u8,
        clientflag: c_ulong,
    ) ?*MYSQL;
    pub extern fn mysql_close(sock: *MYSQL) void;
    pub extern fn mysql_query(mysql: *MYSQL, q: [*c]const u8) c_int;
    pub extern fn mysql_real_query(mysql: *MYSQL, q: [*c]const u8, length: c_ulong) c_int;
    pub extern fn mysql_store_result(mysql: *MYSQL) ?*MYSQL_RES;
    pub extern fn mysql_use_result(mysql: *MYSQL) ?*MYSQL_RES;
    pub extern fn mysql_free_result(result: *MYSQL_RES) void;
    pub extern fn mysql_fetch_row(result: *MYSQL_RES) MYSQL_ROW; // 返回null用 == 0检测
    pub extern fn mysql_fetch_lengths(result: *MYSQL_RES) [*c]c_ulong;
    pub extern fn mysql_num_rows(res: *MYSQL_RES) u64;
    pub extern fn mysql_num_fields(res: *MYSQL_RES) c_uint;
    pub extern fn mysql_fetch_fields(res: *MYSQL_RES) [*c]MYSQL_FIELD;
    pub extern fn mysql_fetch_field_direct(res: *MYSQL_RES, fieldnr: c_uint) *MYSQL_FIELD;
    pub extern fn mysql_affected_rows(mysql: *MYSQL) u64;
    pub extern fn mysql_insert_id(mysql: *MYSQL) u64;
    pub extern fn mysql_error(mysql: *MYSQL) [*c]const u8;
    pub extern fn mysql_errno(mysql: *MYSQL) c_uint;
    pub extern fn mysql_real_escape_string(
        mysql: *MYSQL,
        to: [*c]u8,
        from: [*c]const u8,
        length: c_ulong,
    ) c_ulong;
    pub extern fn mysql_set_character_set(mysql: *MYSQL, csname: [*c]const u8) c_int;
    pub extern fn mysql_autocommit(mysql: *MYSQL, auto_mode: c_int) c_int;
    pub extern fn mysql_commit(mysql: *MYSQL) c_int;
    pub extern fn mysql_rollback(mysql: *MYSQL) c_int;
    pub extern fn mysql_ping(mysql: *MYSQL) c_int;
    pub extern fn mysql_stat(mysql: *MYSQL) [*c]const u8;
    pub extern fn mysql_get_server_info(mysql: *MYSQL) [*c]const u8;
    pub extern fn mysql_get_client_info() [*c]const u8;

    // 预处理语句
    pub const MYSQL_STMT = opaque {};
    pub const MYSQL_BIND = extern struct {
        length: *c_ulong,
        is_null: *c_int,
        buffer: ?*anyopaque,
        error_ptr: ?*c_int,
        row_ptr: ?[*c]u8,
        store_param_func: ?*anyopaque,
        fetch_result: ?*anyopaque,
        skip_result: ?*anyopaque,
        buffer_length: c_ulong,
        offset: c_ulong,
        length_value: c_ulong,
        param_number: c_uint,
        pack_length: c_uint,
        buffer_type: c_uint,
        error_value: c_int,
        is_unsigned: c_int,
        long_data_used: c_int,
        is_null_value: c_int,
        extension: ?*anyopaque,
    };

    pub extern fn mysql_stmt_init(mysql: *MYSQL) ?*MYSQL_STMT;
    pub extern fn mysql_stmt_prepare(stmt: *MYSQL_STMT, query: [*c]const u8, length: c_ulong) c_int;
    pub extern fn mysql_stmt_execute(stmt: *MYSQL_STMT) c_int;
    pub extern fn mysql_stmt_bind_param(stmt: *MYSQL_STMT, bnd: [*c]MYSQL_BIND) c_int;
    pub extern fn mysql_stmt_bind_result(stmt: *MYSQL_STMT, bnd: [*c]MYSQL_BIND) c_int;
    pub extern fn mysql_stmt_fetch(stmt: *MYSQL_STMT) c_int;
    pub extern fn mysql_stmt_store_result(stmt: *MYSQL_STMT) c_int;
    pub extern fn mysql_stmt_close(stmt: *MYSQL_STMT) c_int;
    pub extern fn mysql_stmt_error(stmt: *MYSQL_STMT) [*c]const u8;
    pub extern fn mysql_stmt_errno(stmt: *MYSQL_STMT) c_uint;
    pub extern fn mysql_stmt_affected_rows(stmt: *MYSQL_STMT) u64;
    pub extern fn mysql_stmt_insert_id(stmt: *MYSQL_STMT) u64;
    pub extern fn mysql_stmt_param_count(stmt: *MYSQL_STMT) c_ulong;
    pub extern fn mysql_stmt_result_metadata(stmt: *MYSQL_STMT) ?*MYSQL_RES;
};

// ============================================================================
// 错误处理
// ============================================================================

pub const MySQLError = error{
    ConnectionFailed,
    QueryFailed,
    PrepareStatementFailed,
    ExecuteFailed,
    BindFailed,
    FetchFailed,
    CharsetFailed,
    TransactionFailed,
    OutOfMemory,
    InvalidParameter,
    ConnectionLost,
    ServerGone,
};

/// 错误信息
pub const ErrorInfo = struct {
    code: u32,
    message: []const u8,
};

// ============================================================================
// 连接配置
// ============================================================================

pub const ConnectionConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 3306,
    user: []const u8 = "root",
    password: []const u8 = "",
    database: []const u8 = "",
    charset: []const u8 = "utf8mb4",
    connect_timeout: u32 = 10,
    read_timeout: u32 = 30,
    write_timeout: u32 = 30,
    auto_reconnect: bool = true,
    multi_statements: bool = false,
};

// ============================================================================
// 查询结果
// ============================================================================

/// 数据行
pub const Row = struct {
    allocator: Allocator,
    data: std.StringHashMapUnmanaged([]const u8),
    field_names: []const []const u8,

    pub fn deinit(self: *const Row) void {
        // StringHashMapUnmanaged.deinit 需要 allocator
        var data_copy = self.data;
        data_copy.deinit(self.allocator);
    }

    /// 获取字符串值
    pub fn getString(self: *const Row, field: []const u8) ?[]const u8 {
        return self.data.get(field);
    }

    /// 获取整数值
    pub fn getInt(self: *const Row, field: []const u8) ?i64 {
        const str = self.data.get(field) orelse return null;
        return std.fmt.parseInt(i64, str, 10) catch null;
    }

    /// 获取浮点值
    pub fn getFloat(self: *const Row, field: []const u8) ?f64 {
        const str = self.data.get(field) orelse return null;
        return std.fmt.parseFloat(f64, str) catch null;
    }

    /// 获取布尔值
    pub fn getBool(self: *const Row, field: []const u8) ?bool {
        const str = self.data.get(field) orelse return null;
        if (std.mem.eql(u8, str, "1") or std.mem.eql(u8, str, "true")) return true;
        if (std.mem.eql(u8, str, "0") or std.mem.eql(u8, str, "false")) return false;
        return null;
    }

    /// 检查是否为NULL
    pub fn isNull(self: *const Row, field: []const u8) bool {
        return self.data.get(field) == null;
    }
};

/// 查询结果集
pub const ResultSet = struct {
    allocator: Allocator,
    mysql: *c.MYSQL,
    result: ?*c.MYSQL_RES,
    field_count: u32,
    field_names: [][]const u8,
    affected_rows: u64,
    insert_id: u64,

    pub fn deinit(self: *ResultSet) void {
        if (self.result) |res| {
            c.mysql_free_result(res);
        }
        if (self.field_names.len > 0) {
            self.allocator.free(self.field_names);
        }
    }

    /// 获取下一行
    pub fn next(self: *ResultSet) !?Row {
        const res = self.result orelse return null;

        const row_data = c.mysql_fetch_row(res);
        // 检查是否为NULL（C返回的空指针）
        if (@intFromPtr(row_data) == 0) return null;

        const lengths = c.mysql_fetch_lengths(res);
        // 检查 lengths 是否为 null
        if (@intFromPtr(lengths) == 0) return null;

        var row = Row{
            .allocator = self.allocator,
            .data = .{},
            .field_names = self.field_names,
        };

        for (0..self.field_count) |i| {
            const field_name = self.field_names[i];
            // 安全获取 cell 指针
            const cell_ptr_raw = row_data[i];
            if (@intFromPtr(cell_ptr_raw) != 0) {
                const cell_ptr: [*c]u8 = cell_ptr_raw;
                const len: usize = @intCast(lengths[i]);
                if (len > 0) {
                    const value = cell_ptr[0..len];
                    try row.data.put(self.allocator, field_name, value);
                } else {
                    // 空字符串
                    try row.data.put(self.allocator, field_name, "");
                }
            }
        }

        return row;
    }

    /// 获取所有行
    pub fn fetchAll(self: *ResultSet) ![]Row {
        var rows = std.ArrayList(Row).init(self.allocator);
        errdefer rows.deinit();

        while (try self.next()) |row| {
            try rows.append(row);
        }

        return rows.toOwnedSlice();
    }

    /// 获取单行
    pub fn fetchOne(self: *ResultSet) !?Row {
        return self.next();
    }

    /// 行数
    pub fn rowCount(self: *ResultSet) u64 {
        if (self.result) |res| {
            return c.mysql_num_rows(res);
        }
        return 0;
    }
};

// ============================================================================
// 数据库连接
// ============================================================================

/// MySQL 连接
pub const Connection = struct {
    allocator: Allocator,
    mysql: *c.MYSQL,
    config: ConnectionConfig,
    in_transaction: bool = false,
    last_error: ?ErrorInfo = null,

    /// 初始化连接
    pub fn init(allocator: Allocator, config: ConnectionConfig) !Connection {
        const mysql = c.mysql_init(null) orelse return MySQLError.OutOfMemory;
        errdefer c.mysql_close(mysql);

        // 禁用 SSL（解决远程连接证书验证问题）
        const ssl_mode: c_uint = c.SSL_MODE_DISABLED;
        _ = c.mysql_options(mysql, c.MYSQL_OPT_SSL_MODE, &ssl_mode);

        // 连接标志
        var flags: c_ulong = 0;
        if (config.multi_statements) {
            flags |= c.CLIENT_MULTI_STATEMENTS | c.CLIENT_MULTI_RESULTS;
        }

        // 转换字符串为C字符串
        var host_buf: [256]u8 = undefined;
        var user_buf: [64]u8 = undefined;
        var pass_buf: [256]u8 = undefined;
        var db_buf: [64]u8 = undefined;

        const host_c = toCString(config.host, &host_buf);
        const user_c = toCString(config.user, &user_buf);
        const pass_c = toCString(config.password, &pass_buf);
        const db_c: [*c]const u8 = if (config.database.len > 0) toCString(config.database, &db_buf) else @ptrFromInt(0);

        // 连接
        const result = c.mysql_real_connect(
            mysql,
            host_c,
            user_c,
            pass_c,
            db_c,
            config.port,
            @ptrFromInt(0), // unix_socket = NULL
            flags,
        );

        if (result == null) {
            return MySQLError.ConnectionFailed;
        }

        // 设置字符集
        var charset_buf: [32]u8 = undefined;
        const charset_c = toCString(config.charset, &charset_buf);
        if (c.mysql_set_character_set(mysql, charset_c) != 0) {
            return MySQLError.CharsetFailed;
        }

        return Connection{
            .allocator = allocator,
            .mysql = mysql,
            .config = config,
        };
    }

    /// 关闭连接
    pub fn deinit(self: *Connection) void {
        c.mysql_close(self.mysql);
    }

    /// 执行查询
    pub fn query(self: *Connection, sql: []const u8) !ResultSet {
        // 执行查询
        if (c.mysql_real_query(self.mysql, sql.ptr, @intCast(sql.len)) != 0) {
            self.updateError();
            return MySQLError.QueryFailed;
        }

        // 获取结果
        const result = c.mysql_store_result(self.mysql);
        const affected = c.mysql_affected_rows(self.mysql);
        const insert_id = c.mysql_insert_id(self.mysql);

        // 获取字段信息
        var field_names: [][]const u8 = &.{};
        var field_count: u32 = 0;

        if (result) |res| {
            field_count = c.mysql_num_fields(res);
            if (field_count > 0) {
                field_names = try self.allocator.alloc([]const u8, field_count);
                for (0..field_count) |i| {
                    const field = c.mysql_fetch_field_direct(res, @intCast(i));
                    if (@intFromPtr(field) != 0) {
                        const name_c = field.name;
                        if (@intFromPtr(name_c) != 0) {
                            // 使用 std.mem.span 获取 C 字符串长度
                            field_names[i] = std.mem.span(name_c);
                        } else {
                            field_names[i] = "";
                        }
                    } else {
                        field_names[i] = "";
                    }
                }
            }
        }

        return ResultSet{
            .allocator = self.allocator,
            .mysql = self.mysql,
            .result = result,
            .field_count = field_count,
            .field_names = field_names,
            .affected_rows = affected,
            .insert_id = insert_id,
        };
    }

    /// 执行（无结果集）
    pub fn exec(self: *Connection, sql: []const u8) !u64 {
        if (c.mysql_real_query(self.mysql, sql.ptr, @intCast(sql.len)) != 0) {
            self.updateError();
            return MySQLError.QueryFailed;
        }

        // 消费可能的结果集
        if (c.mysql_store_result(self.mysql)) |res| {
            c.mysql_free_result(res);
        }

        return c.mysql_affected_rows(self.mysql);
    }

    /// 执行带参数的查询（使用预处理语句）
    pub fn queryWithParams(self: *Connection, sql: []const u8, params: []const mysql_core.Value) !ResultSet {
        // 构建完整SQL（简单实现，生产环境应使用真正的预处理语句）
        const full_sql = try self.buildSql(sql, params);
        defer self.allocator.free(full_sql);
        return self.query(full_sql);
    }

    /// 执行带参数的命令
    pub fn execWithParams(self: *Connection, sql: []const u8, params: []const mysql_core.Value) !u64 {
        const full_sql = try self.buildSql(sql, params);
        defer self.allocator.free(full_sql);
        return self.exec(full_sql);
    }

    /// 转义字符串
    pub fn escape(self: *Connection, str: []const u8) ![]u8 {
        const buf = try self.allocator.alloc(u8, str.len * 2 + 1);
        const len = c.mysql_real_escape_string(self.mysql, buf.ptr, str.ptr, @intCast(str.len));
        return buf[0..len];
    }

    /// 开始事务
    pub fn beginTransaction(self: *Connection) !void {
        _ = try self.exec("START TRANSACTION");
        self.in_transaction = true;
    }

    /// 提交事务
    pub fn commit(self: *Connection) !void {
        if (c.mysql_commit(self.mysql) != 0) {
            self.updateError();
            return MySQLError.TransactionFailed;
        }
        self.in_transaction = false;
    }

    /// 回滚事务
    pub fn rollback(self: *Connection) !void {
        if (c.mysql_rollback(self.mysql) != 0) {
            self.updateError();
            return MySQLError.TransactionFailed;
        }
        self.in_transaction = false;
    }

    /// Ping 检测连接
    pub fn ping(self: *Connection) bool {
        return c.mysql_ping(self.mysql) == 0;
    }

    /// 获取服务器信息
    pub fn serverInfo(self: *Connection) []const u8 {
        const info = c.mysql_get_server_info(self.mysql);
        return std.mem.span(info);
    }

    /// 获取服务器状态
    pub fn serverStatus(self: *Connection) []const u8 {
        const stat = c.mysql_stat(self.mysql);
        return std.mem.span(stat);
    }

    /// 获取最后一次错误
    pub fn lastError(self: *Connection) ?ErrorInfo {
        return self.last_error;
    }

    /// 获取最后插入的ID
    pub fn lastInsertId(self: *Connection) u64 {
        return c.mysql_insert_id(self.mysql);
    }

    // 内部函数

    fn updateError(self: *Connection) void {
        const code = c.mysql_errno(self.mysql);
        const msg = c.mysql_error(self.mysql);
        self.last_error = .{
            .code = code,
            .message = std.mem.span(msg),
        };
    }

    fn buildSql(self: *Connection, template: []const u8, params: []const mysql_core.Value) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        var param_idx: usize = 0;
        for (template) |char| {
            if (char == '?' and param_idx < params.len) {
                const val_sql = try params[param_idx].toSql(self.allocator);
                defer self.allocator.free(val_sql);
                try result.appendSlice(self.allocator, val_sql);
                param_idx += 1;
            } else {
                try result.append(self.allocator, char);
            }
        }

        return result.toOwnedSlice(self.allocator);
    }
};

/// 转换Zig字符串为C字符串
fn toCString(str: []const u8, buf: []u8) [*c]const u8 {
    if (str.len >= buf.len) {
        @memcpy(buf[0 .. buf.len - 1], str[0 .. buf.len - 1]);
        buf[buf.len - 1] = 0;
    } else {
        @memcpy(buf[0..str.len], str);
        buf[str.len] = 0;
    }
    return buf.ptr;
}

/// 获取客户端版本
pub fn clientVersion() []const u8 {
    const info = c.mysql_get_client_info();
    return std.mem.span(info);
}

// ============================================================================
// 便捷函数
// ============================================================================

/// 快速连接
pub fn connect(allocator: Allocator, host: []const u8, user: []const u8, password: []const u8, database: []const u8) !Connection {
    return Connection.init(allocator, .{
        .host = host,
        .user = user,
        .password = password,
        .database = database,
    });
}

/// 快速查询
pub fn quickQuery(conn: *Connection, comptime sql: []const u8, args: anytype) !ResultSet {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info == .@"struct" and args_type_info.@"struct".is_tuple) {
        var params: [args_type_info.@"struct".fields.len]mysql_core.Value = undefined;
        inline for (args_type_info.@"struct".fields, 0..) |field, i| {
            params[i] = mysql_core.Value.from(@field(args, field.name));
        }
        return conn.queryWithParams(sql, &params);
    } else {
        return conn.query(sql);
    }
}

// ============================================================================
// 测试
// ============================================================================

test "ConnectionConfig: 默认值" {
    const config = ConnectionConfig{};
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(u16, 3306), config.port);
    try std.testing.expectEqualStrings("utf8mb4", config.charset);
}

test "toCString: 转换" {
    var buf: [32]u8 = undefined;
    const result = toCString("hello", &buf);
    try std.testing.expectEqualStrings("hello", std.mem.span(result));
}

test "Row: 基本操作" {
    const allocator = std.testing.allocator;

    var row = Row{
        .allocator = allocator,
        .data = .{},
        .field_names = &.{},
    };
    defer row.deinit();

    try row.data.put(allocator, "id", "42");
    try row.data.put(allocator, "name", "test");
    try row.data.put(allocator, "active", "1");

    try std.testing.expectEqual(@as(?i64, 42), row.getInt("id"));
    try std.testing.expectEqualStrings("test", row.getString("name").?);
    try std.testing.expectEqual(@as(?bool, true), row.getBool("active"));
}
