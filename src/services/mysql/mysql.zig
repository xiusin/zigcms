//! MySQL ORM 模块
//!
//! 提供类似 GORM 的 MySQL 数据库操作，支持：
//! - 安全的参数绑定（防SQL注入）
//! - 链式查询构建
//! - 模型映射
//! - 事务管理
//! - 连接池
//!
//! ## 使用示例
//!
//! ```zig
//! const mysql = @import("services").mysql;
//!
//! // 连接数据库
//! var db = try mysql.open(.{
//!     .host = "localhost",
//!     .port = 3306,
//!     .user = "root",
//!     .password = "password",
//!     .database = "myapp",
//! });
//! defer db.close();
//!
//! // 查询
//! const users = try db.query(User)
//!     .where("age > ?", .{18})
//!     .orderBy("created_at", .desc)
//!     .limit(10)
//!     .findAll();
//!
//! // 插入
//! try db.insert(&user);
//!
//! // 更新
//! try db.model(User).where("id = ?", .{1}).update(.{ .name = "新名字" });
//!
//! // 删除
//! try db.model(User).where("id = ?", .{1}).delete();
//!
//! // 事务
//! try db.transaction(struct {
//!     fn run(tx: *mysql.Tx) !void {
//!         try tx.exec("UPDATE accounts SET balance = balance - ? WHERE id = ?", .{100, 1});
//!         try tx.exec("UPDATE accounts SET balance = balance + ? WHERE id = ?", .{100, 2});
//!     }
//! }.run);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// 配置
// ============================================================================

/// 数据库连接配置
pub const Config = struct {
    /// 主机地址
    host: []const u8 = "localhost",
    /// 端口
    port: u16 = 3306,
    /// 用户名
    user: []const u8 = "root",
    /// 密码
    password: []const u8 = "",
    /// 数据库名
    database: []const u8 = "",
    /// 字符集
    charset: []const u8 = "utf8mb4",
    /// 连接超时（秒）
    connect_timeout: u32 = 10,
    /// 读取超时（秒）
    read_timeout: u32 = 30,
    /// 写入超时（秒）
    write_timeout: u32 = 30,
    /// 最大连接数
    max_connections: u32 = 10,
    /// 最小空闲连接数
    min_idle: u32 = 2,
    /// 连接最大空闲时间（秒）
    max_idle_time: u32 = 300,
    /// 是否自动重连
    auto_reconnect: bool = true,
    /// 是否启用日志
    enable_log: bool = false,
};

// ============================================================================
// SQL 值类型
// ============================================================================

/// SQL 值（用于参数绑定）
pub const Value = union(enum) {
    null_val,
    bool_val: bool,
    int_val: i64,
    uint_val: u64,
    float_val: f64,
    string_val: []const u8,
    bytes_val: []const u8,
    timestamp_val: i64,

    /// 从任意类型创建值
    pub fn from(val: anytype) Value {
        const T = @TypeOf(val);
        const info = @typeInfo(T);

        return switch (info) {
            .null => .null_val,
            .bool => .{ .bool_val = val },
            .int => |i| if (i.signedness == .signed)
                .{ .int_val = @intCast(val) }
            else
                .{ .uint_val = @intCast(val) },
            .float => .{ .float_val = @floatCast(val) },
            .pointer => |p| blk: {
                // 检查是否是 []const u8 或 []u8
                if (p.size == .slice) {
                    if (p.child == u8) {
                        break :blk .{ .string_val = val };
                    }
                }
                // 检查是否是 *const [N]u8（字符串字面量）
                if (p.size == .one) {
                    const child_info = @typeInfo(p.child);
                    if (child_info == .array and child_info.array.child == u8) {
                        break :blk .{ .string_val = val };
                    }
                }
                break :blk .null_val;
            },
            .optional => if (val) |v| from(v) else .null_val,
            else => .null_val,
        };
    }

    /// 转换为 SQL 字符串
    pub fn toSql(self: Value, allocator: Allocator) ![]const u8 {
        return switch (self) {
            .null_val => try allocator.dupe(u8, "NULL"),
            .bool_val => |v| try allocator.dupe(u8, if (v) "1" else "0"),
            .int_val => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .uint_val => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .float_val => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .string_val => |v| try escapeString(allocator, v),
            .bytes_val => |v| try escapeBytes(allocator, v),
            .timestamp_val => |v| try std.fmt.allocPrint(allocator, "FROM_UNIXTIME({d})", .{v}),
        };
    }
};

/// 转义字符串（防SQL注入）
pub fn escapeString(allocator: Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    try result.append(allocator, '\'');
    for (input) |c| {
        switch (c) {
            '\'' => try result.appendSlice(allocator, "''"),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\x00' => try result.appendSlice(allocator, "\\0"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\x1a' => try result.appendSlice(allocator, "\\Z"),
            else => try result.append(allocator, c),
        }
    }
    try result.append(allocator, '\'');

    return result.toOwnedSlice(allocator);
}

/// 转义二进制数据
pub fn escapeBytes(allocator: Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "X'");
    for (input) |byte| {
        const hex = "0123456789ABCDEF";
        try result.append(allocator, hex[byte >> 4]);
        try result.append(allocator, hex[byte & 0x0F]);
    }
    try result.append(allocator, '\'');

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// 查询构建器
// ============================================================================

/// 排序方向
pub const OrderDir = enum {
    asc,
    desc,

    pub fn toSql(self: OrderDir) []const u8 {
        return switch (self) {
            .asc => "ASC",
            .desc => "DESC",
        };
    }
};

/// 连接类型
pub const JoinType = enum {
    inner,
    left,
    right,
    full,

    pub fn toSql(self: JoinType) []const u8 {
        return switch (self) {
            .inner => "INNER JOIN",
            .left => "LEFT JOIN",
            .right => "RIGHT JOIN",
            .full => "FULL OUTER JOIN",
        };
    }
};

/// WHERE 条件
pub const Condition = struct {
    sql: []const u8,
    values: []const Value,
    logic: enum { and_op, or_op } = .and_op,
};

/// 预处理语句（占位符绑定）
pub const PreparedStatement = struct {
    allocator: Allocator,
    sql: []const u8,
    params: []const Value,

    /// 释放资源
    pub fn deinit(self: *PreparedStatement) void {
        self.allocator.free(self.sql);
        self.allocator.free(self.params);
    }

    /// 获取绑定参数数量
    pub fn paramCount(self: *const PreparedStatement) usize {
        return self.params.len;
    }

    /// 调试输出（显示SQL和参数）
    pub fn debug(self: *const PreparedStatement, allocator: Allocator) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        try result.appendSlice(allocator, "SQL: ");
        try result.appendSlice(allocator, self.sql);
        try result.appendSlice(allocator, "\nParams: [");

        for (self.params, 0..) |param, i| {
            if (i > 0) try result.appendSlice(allocator, ", ");
            const val_str = try param.toSql(allocator);
            defer allocator.free(val_str);
            try result.appendSlice(allocator, val_str);
        }

        try result.appendSlice(allocator, "]");
        return result.toOwnedSlice(allocator);
    }

    /// 转换为可执行SQL（将占位符替换为实际值）
    pub fn toExecutableSql(self: *const PreparedStatement, allocator: Allocator) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        var param_idx: usize = 0;
        for (self.sql) |c| {
            if (c == '?' and param_idx < self.params.len) {
                const val_str = try self.params[param_idx].toSql(allocator);
                defer allocator.free(val_str);
                try result.appendSlice(allocator, val_str);
                param_idx += 1;
            } else {
                try result.append(allocator, c);
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

/// 排序项
pub const OrderItem = struct {
    field: []const u8,
    dir: OrderDir,
};

/// 连接项
pub const JoinItem = struct {
    join_type: JoinType,
    table: []const u8,
    on: []const u8,
};

/// 查询构建器
pub fn QueryBuilder(comptime T: type) type {
    _ = T; // 类型参数用于模型推断
    return struct {
        const Self = @This();

        allocator: Allocator,
        table_name: []const u8,
        select_fields: []const []const u8,
        conditions: std.ArrayListUnmanaged(Condition),
        order_items: std.ArrayListUnmanaged(OrderItem),
        group_fields: std.ArrayListUnmanaged([]const u8),
        having: ?[]const u8,
        join_items: std.ArrayListUnmanaged(JoinItem),
        limit_val: ?u64,
        offset_val: ?u64,
        distinct_flag: bool,

        /// 初始化
        pub fn init(allocator: Allocator, table_name: []const u8) Self {
            return Self{
                .allocator = allocator,
                .table_name = table_name,
                .select_fields = &.{},
                .conditions = .{},
                .order_items = .{},
                .group_fields = .{},
                .having = null,
                .join_items = .{},
                .limit_val = null,
                .offset_val = null,
                .distinct_flag = false,
            };
        }

        /// 释放资源
        pub fn deinit(self: *Self) void {
            // 释放条件中分配的values
            for (self.conditions.items) |cond| {
                if (cond.values.len > 0) {
                    self.allocator.free(cond.values);
                }
            }
            self.conditions.deinit(self.allocator);
            self.order_items.deinit(self.allocator);
            self.group_fields.deinit(self.allocator);
            self.join_items.deinit(self.allocator);
        }

        /// 选择字段
        pub fn selectFields(self: *Self, fields: []const []const u8) *Self {
            self.select_fields = fields;
            return self;
        }

        /// DISTINCT
        pub fn distinct(self: *Self) *Self {
            self.distinct_flag = true;
            return self;
        }

        /// WHERE 条件
        pub fn where(self: *Self, sql: []const u8, args: anytype) *Self {
            const values = argsToValues(self.allocator, args) catch return self;
            self.conditions.append(self.allocator, .{ .sql = sql, .values = values, .logic = .and_op }) catch {};
            return self;
        }

        /// OR WHERE
        pub fn orWhere(self: *Self, sql: []const u8, args: anytype) *Self {
            const values = argsToValues(self.allocator, args) catch return self;
            self.conditions.append(self.allocator, .{ .sql = sql, .values = values, .logic = .or_op }) catch {};
            return self;
        }

        /// WHERE NULL
        pub fn whereNull(self: *Self, field: []const u8) *Self {
            const sql = std.fmt.allocPrint(self.allocator, "{s} IS NULL", .{field}) catch return self;
            self.conditions.append(self.allocator, .{ .sql = sql, .values = &.{}, .logic = .and_op }) catch {};
            return self;
        }

        /// WHERE NOT NULL
        pub fn whereNotNull(self: *Self, field: []const u8) *Self {
            const sql = std.fmt.allocPrint(self.allocator, "{s} IS NOT NULL", .{field}) catch return self;
            self.conditions.append(self.allocator, .{ .sql = sql, .values = &.{}, .logic = .and_op }) catch {};
            return self;
        }

        /// ORDER BY
        pub fn orderBy(self: *Self, field: []const u8, dir: OrderDir) *Self {
            self.order_items.append(self.allocator, .{ .field = field, .dir = dir }) catch {};
            return self;
        }

        /// GROUP BY
        pub fn groupBy(self: *Self, fields: []const []const u8) *Self {
            for (fields) |f| {
                self.group_fields.append(self.allocator, f) catch {};
            }
            return self;
        }

        /// HAVING
        pub fn havingClause(self: *Self, sql: []const u8) *Self {
            self.having = sql;
            return self;
        }

        /// JOIN
        pub fn join(self: *Self, join_type: JoinType, table: []const u8, on: []const u8) *Self {
            self.join_items.append(self.allocator, .{ .join_type = join_type, .table = table, .on = on }) catch {};
            return self;
        }

        /// INNER JOIN
        pub fn innerJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            return self.join(.inner, table, on);
        }

        /// LEFT JOIN
        pub fn leftJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            return self.join(.left, table, on);
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

        /// 构建 SELECT SQL
        pub fn buildSelect(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "SELECT ");

            if (self.distinct_flag) {
                try sql.appendSlice(self.allocator, "DISTINCT ");
            }

            if (self.select_fields.len == 0) {
                try sql.appendSlice(self.allocator, "*");
            } else {
                for (self.select_fields, 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                }
            }

            try sql.appendSlice(self.allocator, " FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            // JOINs
            for (self.join_items.items) |j| {
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.join_type.toSql());
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.table);
                try sql.appendSlice(self.allocator, " ON ");
                try sql.appendSlice(self.allocator, j.on);
            }

            // WHERE
            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try self.appendWithValues(&sql, cond.sql, cond.values);
                }
            }

            // GROUP BY
            if (self.group_fields.items.len > 0) {
                try sql.appendSlice(self.allocator, " GROUP BY ");
                for (self.group_fields.items, 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                }
            }

            // HAVING
            if (self.having) |h| {
                try sql.appendSlice(self.allocator, " HAVING ");
                try sql.appendSlice(self.allocator, h);
            }

            // ORDER BY
            if (self.order_items.items.len > 0) {
                try sql.appendSlice(self.allocator, " ORDER BY ");
                for (self.order_items.items, 0..) |o, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, o.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, o.dir.toSql());
                }
            }

            // LIMIT
            if (self.limit_val) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            // OFFSET
            if (self.offset_val) |off| {
                try sql.writer(self.allocator).print(" OFFSET {d}", .{off});
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建 COUNT SQL
        pub fn buildCount(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "SELECT COUNT(*) FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try self.appendWithValues(&sql, cond.sql, cond.values);
                }
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建 DELETE SQL
        pub fn buildDelete(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "DELETE FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try self.appendWithValues(&sql, cond.sql, cond.values);
                }
            }

            if (self.limit_val) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建预处理 SELECT 语句（保留占位符）
        pub fn buildPreparedSelect(self: *Self) !PreparedStatement {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            var params = std.ArrayListUnmanaged(Value){};
            errdefer params.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "SELECT ");

            if (self.distinct_flag) {
                try sql.appendSlice(self.allocator, "DISTINCT ");
            }

            if (self.select_fields.len == 0) {
                try sql.appendSlice(self.allocator, "*");
            } else {
                for (self.select_fields, 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                }
            }

            try sql.appendSlice(self.allocator, " FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            // JOINs
            for (self.join_items.items) |j| {
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.join_type.toSql());
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.table);
                try sql.appendSlice(self.allocator, " ON ");
                try sql.appendSlice(self.allocator, j.on);
            }

            // WHERE（保留占位符）
            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, cond.sql);
                    // 收集参数
                    for (cond.values) |v| {
                        try params.append(self.allocator, v);
                    }
                }
            }

            // GROUP BY
            if (self.group_fields.items.len > 0) {
                try sql.appendSlice(self.allocator, " GROUP BY ");
                for (self.group_fields.items, 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                }
            }

            // HAVING
            if (self.having) |h| {
                try sql.appendSlice(self.allocator, " HAVING ");
                try sql.appendSlice(self.allocator, h);
            }

            // ORDER BY
            if (self.order_items.items.len > 0) {
                try sql.appendSlice(self.allocator, " ORDER BY ");
                for (self.order_items.items, 0..) |o, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, o.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, o.dir.toSql());
                }
            }

            // LIMIT
            if (self.limit_val) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            // OFFSET
            if (self.offset_val) |off| {
                try sql.writer(self.allocator).print(" OFFSET {d}", .{off});
            }

            return PreparedStatement{
                .allocator = self.allocator,
                .sql = try sql.toOwnedSlice(self.allocator),
                .params = try params.toOwnedSlice(self.allocator),
            };
        }

        /// 构建预处理 DELETE 语句
        pub fn buildPreparedDelete(self: *Self) !PreparedStatement {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            var params = std.ArrayListUnmanaged(Value){};
            errdefer params.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "DELETE FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, cond.sql);
                    for (cond.values) |v| {
                        try params.append(self.allocator, v);
                    }
                }
            }

            if (self.limit_val) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            return PreparedStatement{
                .allocator = self.allocator,
                .sql = try sql.toOwnedSlice(self.allocator),
                .params = try params.toOwnedSlice(self.allocator),
            };
        }

        /// 构建预处理 COUNT 语句
        pub fn buildPreparedCount(self: *Self) !PreparedStatement {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            var params = std.ArrayListUnmanaged(Value){};
            errdefer params.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "SELECT COUNT(*) FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.conditions.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, cond.sql);
                    for (cond.values) |v| {
                        try params.append(self.allocator, v);
                    }
                }
            }

            return PreparedStatement{
                .allocator = self.allocator,
                .sql = try sql.toOwnedSlice(self.allocator),
                .params = try params.toOwnedSlice(self.allocator),
            };
        }

        /// 附加带参数的SQL
        fn appendWithValues(self: *Self, sql: *std.ArrayListUnmanaged(u8), template: []const u8, values: []const Value) !void {
            var value_idx: usize = 0;
            for (template) |c| {
                if (c == '?' and value_idx < values.len) {
                    const val_sql = try values[value_idx].toSql(self.allocator);
                    defer self.allocator.free(val_sql);
                    try sql.appendSlice(self.allocator, val_sql);
                    value_idx += 1;
                } else {
                    try sql.append(self.allocator, c);
                }
            }
        }
    };
}

/// 将参数元组转换为Value切片
fn argsToValues(allocator: Allocator, args: anytype) ![]const Value {
    const ArgsType = @TypeOf(args);
    const args_info = @typeInfo(ArgsType);

    if (args_info != .@"struct" or !args_info.@"struct".is_tuple) {
        return &.{};
    }

    const fields = args_info.@"struct".fields;
    if (fields.len == 0) return &.{};

    var values = try allocator.alloc(Value, fields.len);
    inline for (fields, 0..) |field, i| {
        values[i] = Value.from(@field(args, field.name));
    }

    return values;
}

// ============================================================================
// 模型定义
// ============================================================================

/// 模型特性
pub fn Model(comptime T: type) type {
    return struct {
        /// 获取表名
        pub fn tableName() []const u8 {
            if (@hasDecl(T, "table_name")) {
                return T.table_name;
            }
            // 默认使用类型名的小写复数形式
            return @typeName(T);
        }

        /// 获取主键字段名
        pub fn primaryKey() []const u8 {
            if (@hasDecl(T, "primary_key")) {
                return T.primary_key;
            }
            return "id";
        }

        /// 获取所有字段名
        pub fn fieldNames() []const []const u8 {
            const info = @typeInfo(T);
            if (info != .@"struct") return &.{};

            comptime var names: [info.@"struct".fields.len][]const u8 = undefined;
            inline for (info.@"struct".fields, 0..) |field, i| {
                names[i] = field.name;
            }
            return &names;
        }
    };
}

// ============================================================================
// 数据库连接
// ============================================================================

/// 行结果
pub const Row = struct {
    allocator: Allocator,
    columns: [][]const u8,
    values: [][]const u8,

    /// 获取列值
    pub fn get(self: *const Row, column: []const u8) ?[]const u8 {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col, column)) {
                return self.values[i];
            }
        }
        return null;
    }

    /// 获取整数值
    pub fn getInt(self: *const Row, column: []const u8) ?i64 {
        const val = self.get(column) orelse return null;
        return std.fmt.parseInt(i64, val, 10) catch null;
    }

    /// 获取浮点值
    pub fn getFloat(self: *const Row, column: []const u8) ?f64 {
        const val = self.get(column) orelse return null;
        return std.fmt.parseFloat(f64, val) catch null;
    }

    /// 释放资源
    pub fn deinit(self: *Row) void {
        for (self.columns) |col| {
            self.allocator.free(col);
        }
        for (self.values) |val| {
            self.allocator.free(val);
        }
        self.allocator.free(self.columns);
        self.allocator.free(self.values);
    }
};

/// 查询结果集
pub const Result = struct {
    allocator: Allocator,
    rows: []Row,
    affected_rows: u64,
    last_insert_id: u64,

    /// 获取第一行
    pub fn first(self: *const Result) ?*const Row {
        if (self.rows.len == 0) return null;
        return &self.rows[0];
    }

    /// 迭代所有行
    pub fn iter(self: *const Result) []const Row {
        return self.rows;
    }

    /// 释放资源
    pub fn deinit(self: *Result) void {
        for (self.rows) |*row| {
            @constCast(row).deinit();
        }
        self.allocator.free(self.rows);
    }
};

/// 数据库连接
pub const DB = struct {
    const Self = @This();

    allocator: Allocator,
    config: Config,
    connected: bool,
    // 实际连接由底层驱动管理
    // 这里使用模拟实现

    /// 打开连接
    pub fn open(allocator: Allocator, config: Config) !*Self {
        const db = try allocator.create(Self);
        db.* = .{
            .allocator = allocator,
            .config = config,
            .connected = true,
        };
        return db;
    }

    /// 关闭连接
    pub fn close(self: *Self) void {
        self.connected = false;
        self.allocator.destroy(self);
    }

    /// 执行原始 SQL
    pub fn exec(self: *Self, sql: []const u8, args: anytype) !Result {
        _ = args;
        if (!self.connected) return error.NotConnected;

        // 模拟实现
        if (self.config.enable_log) {
            std.debug.print("[SQL] {s}\n", .{sql});
        }

        return Result{
            .allocator = self.allocator,
            .rows = &.{},
            .affected_rows = 0,
            .last_insert_id = 0,
        };
    }

    /// 执行原始 SQL 查询
    pub fn rawQuery(self: *Self, sql: []const u8) !Result {
        return self.exec(sql, .{});
    }

    /// 创建查询构建器
    pub fn query(self: *Self, comptime T: type) QueryBuilder(T) {
        return QueryBuilder(T).init(self.allocator, Model(T).tableName());
    }

    /// 创建模型查询
    pub fn model(self: *Self, comptime T: type) QueryBuilder(T) {
        return self.query(T);
    }

    /// 插入记录
    pub fn insert(self: *Self, comptime T: type, record: *const T) !u64 {
        var sql = std.ArrayList(u8).init(self.allocator);
        defer sql.deinit();

        try sql.appendSlice("INSERT INTO ");
        try sql.appendSlice(Model(T).tableName());
        try sql.appendSlice(" (");

        const info = @typeInfo(T);
        if (info != .@"struct") return error.InvalidType;

        // 字段名
        var first = true;
        inline for (info.@"struct".fields) |field| {
            if (!first) try sql.appendSlice(", ");
            first = false;
            try sql.appendSlice(field.name);
        }

        try sql.appendSlice(") VALUES (");

        // 值
        first = true;
        inline for (info.@"struct".fields) |field| {
            if (!first) try sql.appendSlice(", ");
            first = false;

            const value = @field(record.*, field.name);
            const val = Value.from(value);
            const val_sql = try val.toSql(self.allocator);
            defer self.allocator.free(val_sql);
            try sql.appendSlice(val_sql);
        }

        try sql.appendSlice(")");

        const result = try self.exec(sql.items, .{});
        return result.last_insert_id;
    }

    /// 批量插入
    pub fn insertBatch(self: *Self, comptime T: type, records: []const T) !u64 {
        var count: u64 = 0;
        for (records) |*record| {
            _ = try self.insert(T, record);
            count += 1;
        }
        return count;
    }

    /// 事务
    pub fn transaction(self: *Self, comptime func: fn (*Tx) anyerror!void) !void {
        var tx = Tx{ .db = self, .active = true };

        _ = try self.exec("START TRANSACTION", .{});

        func(&tx) catch |err| {
            _ = self.exec("ROLLBACK", .{}) catch {};
            tx.active = false;
            return err;
        };

        _ = try self.exec("COMMIT", .{});
        tx.active = false;
    }

    /// Ping 检查连接
    pub fn ping(self: *Self) !void {
        if (!self.connected) return error.NotConnected;
        _ = try self.exec("SELECT 1", .{});
    }
};

/// 事务
pub const Tx = struct {
    db: *DB,
    active: bool,

    /// 执行 SQL
    pub fn exec(self: *Tx, sql: []const u8, args: anytype) !Result {
        if (!self.active) return error.TransactionNotActive;
        return self.db.exec(sql, args);
    }

    /// 查询
    pub fn query(self: *Tx, comptime T: type) QueryBuilder(T) {
        return self.db.query(T);
    }

    /// 回滚
    pub fn rollback(self: *Tx) !void {
        if (!self.active) return error.TransactionNotActive;
        _ = try self.db.exec("ROLLBACK", .{});
        self.active = false;
    }

    /// 提交
    pub fn commit(self: *Tx) !void {
        if (!self.active) return error.TransactionNotActive;
        _ = try self.db.exec("COMMIT", .{});
        self.active = false;
    }
};

// ============================================================================
// 便捷函数
// ============================================================================

/// 打开数据库连接
pub fn open(allocator: Allocator, config: Config) !*DB {
    return DB.open(allocator, config);
}

/// 格式化 SQL（带参数绑定）
pub fn format(allocator: Allocator, sql: []const u8, args: anytype) ![]const u8 {
    const values = try argsToValues(allocator, args);
    defer allocator.free(values);

    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var value_idx: usize = 0;
    for (sql) |c| {
        if (c == '?' and value_idx < values.len) {
            const val_sql = try values[value_idx].toSql(allocator);
            defer allocator.free(val_sql);
            try result.appendSlice(allocator, val_sql);
            value_idx += 1;
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// 测试
// ============================================================================

test "escapeString: SQL注入防护" {
    const allocator = std.testing.allocator;

    // 正常字符串
    const s1 = try escapeString(allocator, "hello");
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("'hello'", s1);

    // 包含引号
    const s2 = try escapeString(allocator, "it's");
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("'it''s'", s2);

    // SQL注入尝试
    const s3 = try escapeString(allocator, "'; DROP TABLE users; --");
    defer allocator.free(s3);
    try std.testing.expectEqualStrings("'''; DROP TABLE users; --'", s3);

    // 包含反斜杠
    const s4 = try escapeString(allocator, "path\\to\\file");
    defer allocator.free(s4);
    try std.testing.expectEqualStrings("'path\\\\to\\\\file'", s4);
}

test "escapeBytes: 二进制转义" {
    const allocator = std.testing.allocator;

    const bytes = try escapeBytes(allocator, &[_]u8{ 0x00, 0xFF, 0xAB });
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("X'00FFAB'", bytes);
}

test "Value: 类型转换" {
    const allocator = std.testing.allocator;

    // 整数
    const v1 = Value.from(@as(i32, 42));
    const s1 = try v1.toSql(allocator);
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("42", s1);

    // 字符串
    const v2 = Value.from("hello");
    const s2 = try v2.toSql(allocator);
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("'hello'", s2);

    // 布尔
    const v3 = Value.from(true);
    const s3 = try v3.toSql(allocator);
    defer allocator.free(s3);
    try std.testing.expectEqualStrings("1", s3);

    // null
    const v4 = Value.from(@as(?i32, null));
    const s4 = try v4.toSql(allocator);
    defer allocator.free(s4);
    try std.testing.expectEqualStrings("NULL", s4);
}

test "format: 参数绑定" {
    const allocator = std.testing.allocator;

    const sql1 = try format(allocator, "SELECT * FROM users WHERE id = ?", .{@as(i64, 42)});
    defer allocator.free(sql1);
    try std.testing.expectEqualStrings("SELECT * FROM users WHERE id = 42", sql1);

    const sql2 = try format(allocator, "SELECT * FROM users WHERE name = ? AND age > ?", .{ @as([]const u8, "张三"), @as(i64, 18) });
    defer allocator.free(sql2);
    try std.testing.expectEqualStrings("SELECT * FROM users WHERE name = '张三' AND age > 18", sql2);

    // SQL注入防护
    const sql3 = try format(allocator, "SELECT * FROM users WHERE name = ?", .{@as([]const u8, "'; DROP TABLE users; --")});
    defer allocator.free(sql3);
    try std.testing.expect(std.mem.indexOf(u8, sql3, "DROP TABLE") != null);
    try std.testing.expect(std.mem.startsWith(u8, sql3, "SELECT * FROM users WHERE name = '''"));
}

test "QueryBuilder: SELECT 构建" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: u64,
        name: []const u8,
        age: u32,

        pub const table_name = "users";
    };

    var builder = QueryBuilder(User).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("age > ?", .{@as(i32, 18)})
        .where("status = ?", .{@as(i32, 1)})
        .orderBy("created_at", .desc)
        .limit(10)
        .offset(20);

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SELECT *") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "FROM users") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "ORDER BY created_at DESC") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "LIMIT 10") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "OFFSET 20") != null);
}

test "QueryBuilder: COUNT 构建" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("status = ?", .{@as(i32, 1)});

    const sql = try builder.buildCount();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SELECT COUNT(*)") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "FROM users") != null);
}

test "QueryBuilder: DELETE 构建" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("id = ?", .{@as(i32, 1)});

    const sql = try builder.buildDelete();
    defer allocator.free(sql);

    try std.testing.expectEqualStrings("DELETE FROM users WHERE id = 1", sql);
}

test "QueryBuilder: JOIN 构建" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .leftJoin("orders", "users.id = orders.user_id")
        .where("users.status = ?", .{@as(i32, 1)});

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "LEFT JOIN orders ON users.id = orders.user_id") != null);
}

test "QueryBuilder: 分页" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.page(3, 20); // 第3页，每页20条

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "LIMIT 20") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "OFFSET 40") != null);
}

test "DB: 基本操作" {
    const allocator = std.testing.allocator;

    var db = try DB.open(allocator, .{
        .host = "localhost",
        .database = "test",
    });
    defer db.close();

    try std.testing.expect(db.connected);
}

test "Config: 默认值" {
    const config = Config{};
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(u16, 3306), config.port);
    try std.testing.expectEqualStrings("utf8mb4", config.charset);
    try std.testing.expectEqual(@as(u32, 10), config.max_connections);
}

test "OrderDir: SQL输出" {
    try std.testing.expectEqualStrings("ASC", OrderDir.asc.toSql());
    try std.testing.expectEqualStrings("DESC", OrderDir.desc.toSql());
}

test "JoinType: SQL输出" {
    try std.testing.expectEqualStrings("INNER JOIN", JoinType.inner.toSql());
    try std.testing.expectEqualStrings("LEFT JOIN", JoinType.left.toSql());
    try std.testing.expectEqualStrings("RIGHT JOIN", JoinType.right.toSql());
}

// ============================================================================
// PreparedStatement 测试
// ============================================================================

test "PreparedStatement: 基本构建" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("age > ?", .{@as(i64, 18)})
        .where("status = ?", .{@as(i64, 1)});

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    // SQL 保留占位符
    try std.testing.expectEqualStrings("SELECT * FROM users WHERE age > ? AND status = ?", stmt.sql);
    // 参数数量正确
    try std.testing.expectEqual(@as(usize, 2), stmt.paramCount());
}

test "PreparedStatement: 参数值验证" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("name = ?", .{@as([]const u8, "张三")})
        .where("age >= ?", .{@as(i64, 18)})
        .where("active = ?", .{true});

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    try std.testing.expectEqual(@as(usize, 3), stmt.paramCount());

    // 验证第一个参数是字符串
    try std.testing.expectEqual(Value.string_val, std.meta.activeTag(stmt.params[0]));
    try std.testing.expectEqualStrings("张三", stmt.params[0].string_val);

    // 验证第二个参数是整数
    try std.testing.expectEqual(Value.int_val, std.meta.activeTag(stmt.params[1]));
    try std.testing.expectEqual(@as(i64, 18), stmt.params[1].int_val);

    // 验证第三个参数是布尔
    try std.testing.expectEqual(Value.bool_val, std.meta.activeTag(stmt.params[2]));
    try std.testing.expect(stmt.params[2].bool_val);
}

test "PreparedStatement: toExecutableSql" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("name = ?", .{@as([]const u8, "李四")})
        .where("age = ?", .{@as(i64, 25)});

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    // 转换为可执行SQL
    const exec_sql = try stmt.toExecutableSql(allocator);
    defer allocator.free(exec_sql);

    try std.testing.expectEqualStrings("SELECT * FROM users WHERE name = '李四' AND age = 25", exec_sql);
}

test "PreparedStatement: debug输出" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("id = ?", .{@as(i64, 42)});

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    const debug_str = try stmt.debug(allocator);
    defer allocator.free(debug_str);

    try std.testing.expect(std.mem.indexOf(u8, debug_str, "SQL:") != null);
    try std.testing.expect(std.mem.indexOf(u8, debug_str, "Params:") != null);
    try std.testing.expect(std.mem.indexOf(u8, debug_str, "42") != null);
}

test "PreparedStatement: SQL注入防护" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    // 尝试SQL注入
    const malicious_input = "'; DROP TABLE users; --";
    _ = builder.where("name = ?", .{@as([]const u8, malicious_input)});

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    // SQL中的占位符是安全的
    try std.testing.expectEqualStrings("SELECT * FROM users WHERE name = ?", stmt.sql);

    // 恶意输入被保留为参数，在执行时由数据库驱动安全处理
    try std.testing.expectEqualStrings(malicious_input, stmt.params[0].string_val);

    // 转换为可执行SQL时会转义
    const exec_sql = try stmt.toExecutableSql(allocator);
    defer allocator.free(exec_sql);

    // 确保恶意内容被正确转义
    try std.testing.expect(std.mem.indexOf(u8, exec_sql, "''") != null); // 引号被转义
}

test "PreparedStatement: DELETE" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("id = ?", .{@as(i64, 123)});

    var stmt = try builder.buildPreparedDelete();
    defer stmt.deinit();

    try std.testing.expectEqualStrings("DELETE FROM users WHERE id = ?", stmt.sql);
    try std.testing.expectEqual(@as(usize, 1), stmt.paramCount());
    try std.testing.expectEqual(@as(i64, 123), stmt.params[0].int_val);
}

test "PreparedStatement: COUNT" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("status = ?", .{@as(i64, 1)});

    var stmt = try builder.buildPreparedCount();
    defer stmt.deinit();

    try std.testing.expectEqualStrings("SELECT COUNT(*) FROM users WHERE status = ?", stmt.sql);
    try std.testing.expectEqual(@as(usize, 1), stmt.paramCount());
}

test "PreparedStatement: 复杂查询" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "orders");
    defer builder.deinit();

    _ = builder
        .where("user_id = ?", .{@as(i64, 1)})
        .where("amount > ?", .{@as(i64, 100)})
        .orWhere("status = ?", .{@as([]const u8, "pending")})
        .leftJoin("users", "orders.user_id = users.id")
        .orderBy("created_at", .desc)
        .limit(10)
        .offset(20);

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    // 验证SQL结构
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "SELECT * FROM orders") != null);
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "LEFT JOIN users") != null);
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "WHERE user_id = ? AND amount > ? OR status = ?") != null);
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "ORDER BY created_at DESC") != null);
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "LIMIT 10") != null);
    try std.testing.expect(std.mem.indexOf(u8, stmt.sql, "OFFSET 20") != null);

    // 验证参数
    try std.testing.expectEqual(@as(usize, 3), stmt.paramCount());
    try std.testing.expectEqual(@as(i64, 1), stmt.params[0].int_val);
    try std.testing.expectEqual(@as(i64, 100), stmt.params[1].int_val);
    try std.testing.expectEqualStrings("pending", stmt.params[2].string_val);
}

test "PreparedStatement: 无参数查询" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    var stmt = try builder.buildPreparedSelect();
    defer stmt.deinit();

    try std.testing.expectEqualStrings("SELECT * FROM users", stmt.sql);
    try std.testing.expectEqual(@as(usize, 0), stmt.paramCount());
}

test "Value: 所有类型转换" {
    const allocator = std.testing.allocator;

    // i64
    const v1 = Value.from(@as(i64, -100));
    const s1 = try v1.toSql(allocator);
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("-100", s1);

    // u64
    const v2 = Value.from(@as(u64, 999));
    const s2 = try v2.toSql(allocator);
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("999", s2);

    // f64
    const v3 = Value.from(@as(f64, 3.14));
    const s3 = try v3.toSql(allocator);
    defer allocator.free(s3);
    try std.testing.expect(std.mem.indexOf(u8, s3, "3.14") != null);

    // bool true
    const v4 = Value.from(true);
    const s4 = try v4.toSql(allocator);
    defer allocator.free(s4);
    try std.testing.expectEqualStrings("1", s4);

    // bool false
    const v5 = Value.from(false);
    const s5 = try v5.toSql(allocator);
    defer allocator.free(s5);
    try std.testing.expectEqualStrings("0", s5);

    // optional null
    const v6 = Value.from(@as(?i32, null));
    const s6 = try v6.toSql(allocator);
    defer allocator.free(s6);
    try std.testing.expectEqualStrings("NULL", s6);

    // optional with value
    const v7 = Value.from(@as(?i32, 42));
    const s7 = try v7.toSql(allocator);
    defer allocator.free(s7);
    try std.testing.expectEqualStrings("42", s7);
}

test "escapeString: 特殊字符转义" {
    const allocator = std.testing.allocator;

    // 换行符
    const s1 = try escapeString(allocator, "line1\nline2");
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("'line1\\nline2'", s1);

    // 回车符
    const s2 = try escapeString(allocator, "line1\rline2");
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("'line1\\rline2'", s2);

    // NULL字符
    const s3 = try escapeString(allocator, "before\x00after");
    defer allocator.free(s3);
    try std.testing.expectEqualStrings("'before\\0after'", s3);

    // 组合
    const s4 = try escapeString(allocator, "a'b\\c\nd");
    defer allocator.free(s4);
    try std.testing.expectEqualStrings("'a''b\\\\c\\nd'", s4);
}

test "QueryBuilder: OR条件" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("status = ?", .{@as(i64, 1)})
        .orWhere("role = ?", .{@as([]const u8, "admin")});

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "status = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, " OR ") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "role = 'admin'") != null);
}

test "QueryBuilder: GROUP BY" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "orders");
    defer builder.deinit();

    _ = builder.groupBy(&.{"user_id"});

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "GROUP BY user_id") != null);
}

test "QueryBuilder: DISTINCT" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.distinct();

    const sql = try builder.buildSelect();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SELECT DISTINCT *") != null);
}
