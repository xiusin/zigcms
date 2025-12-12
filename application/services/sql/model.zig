//! Eloquent 风格模型系统
//!
//! 提供类似 Laravel Eloquent 的模型定义和 ORM 功能：
//! - 模型继承与特性混入
//! - 自动表名推断
//! - 软删除
//! - 时间戳自动管理
//! - 访问器/修改器
//! - 关联关系
//!
//! ## 使用示例
//!
//! ```zig
//! const User = Model(struct {
//!     pub const table = "users";
//!     pub const primary_key = "id";
//!     pub const timestamps = true;
//!     pub const soft_deletes = true;
//!
//!     id: u64,
//!     name: []const u8,
//!     email: []const u8,
//!     age: ?u32 = null,
//!     created_at: ?i64 = null,
//!     updated_at: ?i64 = null,
//!     deleted_at: ?i64 = null,
//! });
//!
//! // 查询
//! const users = try User.where("age", ">", 18)
//!     .where("status", 1)
//!     .orderBy("created_at", .desc)
//!     .get();
//!
//! // 查找
//! const user = try User.find(1);
//! const admin = try User.where("role", "admin").first();
//!
//! // 创建
//! const new_user = try User.create(.{ .name = "张三", .email = "test@example.com" });
//!
//! // 更新
//! try User.where("id", 1).update(.{ .name = "新名字" });
//!
//! // 删除
//! try User.where("id", 1).delete();
//! try User.where("id", 1).forceDelete(); // 真删除
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const mysql = @import("query.zig");

// ============================================================================
// 模型配置
// ============================================================================

/// 模型选项
pub const ModelOptions = struct {
    /// 表名（默认自动推断）
    table: ?[]const u8 = null,
    /// 主键字段
    primary_key: []const u8 = "id",
    /// 是否启用时间戳
    timestamps: bool = true,
    /// 创建时间字段名
    created_at: []const u8 = "created_at",
    /// 更新时间字段名
    updated_at: []const u8 = "updated_at",
    /// 是否启用软删除
    soft_deletes: bool = false,
    /// 软删除字段名
    deleted_at: []const u8 = "deleted_at",
    /// 连接名（用于多数据库）
    connection: ?[]const u8 = null,
};

// ============================================================================
// 查询构建器
// ============================================================================

/// 操作符
pub const Op = enum {
    eq, // =
    ne, // != / <>
    gt, // >
    gte, // >=
    lt, // <
    lte, // <=
    like, // LIKE
    not_like, // NOT LIKE
    in_op, // IN
    not_in, // NOT IN
    between, // BETWEEN
    is_null, // IS NULL
    is_not_null, // IS NOT NULL

    pub fn toSql(self: Op) []const u8 {
        return switch (self) {
            .eq => "=",
            .ne => "<>",
            .gt => ">",
            .gte => ">=",
            .lt => "<",
            .lte => "<=",
            .like => "LIKE",
            .not_like => "NOT LIKE",
            .in_op => "IN",
            .not_in => "NOT IN",
            .between => "BETWEEN",
            .is_null => "IS NULL",
            .is_not_null => "IS NOT NULL",
        };
    }

    /// 从字符串解析操作符
    pub fn fromString(s: []const u8) Op {
        if (std.mem.eql(u8, s, "=")) return .eq;
        if (std.mem.eql(u8, s, "!=") or std.mem.eql(u8, s, "<>")) return .ne;
        if (std.mem.eql(u8, s, ">")) return .gt;
        if (std.mem.eql(u8, s, ">=")) return .gte;
        if (std.mem.eql(u8, s, "<")) return .lt;
        if (std.mem.eql(u8, s, "<=")) return .lte;
        if (std.ascii.eqlIgnoreCase(s, "like")) return .like;
        if (std.ascii.eqlIgnoreCase(s, "in")) return .in_op;
        return .eq;
    }
};

/// WHERE 子句
const WhereClause = struct {
    field: []const u8,
    op: Op,
    value: mysql.Value,
    logic: WhereLogic = .and_op,
    raw: ?[]const u8 = null, // 原始SQL
};

/// WHERE 逻辑
const WhereLogic = enum { and_op, or_op };

/// ORDER BY 子句
const OrderClause = struct {
    field: []const u8,
    dir: mysql.OrderDir,
};

/// JOIN 子句
const JoinClause = struct {
    join_type: mysql.JoinType,
    table: []const u8,
    first: []const u8,
    operator: []const u8,
    second: []const u8,
};

/// 查询构建器
pub fn QueryBuilder(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        table_name: []const u8,
        select_columns: std.ArrayListUnmanaged([]const u8),
        wheres: std.ArrayListUnmanaged(WhereClause),
        orders: std.ArrayListUnmanaged(OrderClause),
        joins: std.ArrayListUnmanaged(JoinClause),
        groups: std.ArrayListUnmanaged([]const u8),
        having_clause: ?[]const u8,
        limit_value: ?u64,
        offset_value: ?u64,
        distinct_flag: bool,
        with_trashed: bool, // 包含软删除的记录
        only_trashed: bool, // 只查询软删除的记录

        /// 创建新的查询构建器
        pub fn init(allocator: Allocator, table: []const u8) Self {
            return Self{
                .allocator = allocator,
                .table_name = table,
                .select_columns = .{},
                .wheres = .{},
                .orders = .{},
                .joins = .{},
                .groups = .{},
                .having_clause = null,
                .limit_value = null,
                .offset_value = null,
                .distinct_flag = false,
                .with_trashed = false,
                .only_trashed = false,
            };
        }

        /// 释放资源
        pub fn deinit(self: *Self) void {
            self.select_columns.deinit(self.allocator);
            self.wheres.deinit(self.allocator);
            self.orders.deinit(self.allocator);
            self.joins.deinit(self.allocator);
            self.groups.deinit(self.allocator);
            // 释放 having_clause（如果已分配）
            if (self.having_clause) |clause| {
                self.allocator.free(clause);
            }
        }

        // ====================================================================
        // SELECT
        // ====================================================================

        /// 选择列 - select("id", "name", "email")
        pub fn selectColumns(self: *Self, columns: []const []const u8) *Self {
            for (columns) |col| {
                self.select_columns.append(self.allocator, col) catch {};
            }
            return self;
        }

        /// 选择原始表达式
        pub fn selectRaw(self: *Self, expr: []const u8) *Self {
            self.select_columns.append(self.allocator, expr) catch {};
            return self;
        }

        /// DISTINCT
        pub fn distinct(self: *Self) *Self {
            self.distinct_flag = true;
            return self;
        }

        // ====================================================================
        // WHERE - Laravel 风格
        // ====================================================================

        /// where("field", value) - 等于
        /// where("field", "=", value) - 指定操作符
        pub fn where(self: *Self, field: []const u8, args: anytype) *Self {
            return self.whereWithLogic(field, args, .and_op);
        }

        /// orWhere("field", value)
        /// orWhere("field", "=", value)
        pub fn orWhere(self: *Self, field: []const u8, args: anytype) *Self {
            return self.whereWithLogic(field, args, .or_op);
        }

        fn whereWithLogic(self: *Self, field: []const u8, args: anytype, logic: WhereLogic) *Self {
            const ArgsType = @TypeOf(args);
            const args_info = @typeInfo(ArgsType);

            if (args_info == .@"struct" and args_info.@"struct".is_tuple) {
                const fields_info = args_info.@"struct".fields;

                if (fields_info.len == 1) {
                    // where("field", value)
                    const value = @field(args, fields_info[0].name);
                    self.wheres.append(self.allocator, .{
                        .field = field,
                        .op = .eq,
                        .value = mysql.Value.from(value),
                        .logic = logic,
                    }) catch {};
                } else if (fields_info.len == 2) {
                    // where("field", "op", value)
                    const first = @field(args, fields_info[0].name);
                    const second = @field(args, fields_info[1].name);

                    // 检查第一个参数是否是字符串类型
                    const FirstType = @TypeOf(first);
                    const is_string = comptime blk: {
                        const info = @typeInfo(FirstType);
                        if (info == .pointer) {
                            // []const u8 或 *const [N]u8
                            if (info.pointer.size == .slice and info.pointer.child == u8) {
                                break :blk true;
                            }
                            if (info.pointer.size == .one) {
                                const child = @typeInfo(info.pointer.child);
                                if (child == .array and child.array.child == u8) {
                                    break :blk true;
                                }
                            }
                        }
                        break :blk false;
                    };

                    if (is_string) {
                        // where("field", "op", value)
                        self.wheres.append(self.allocator, .{
                            .field = field,
                            .op = Op.fromString(first),
                            .value = mysql.Value.from(second),
                            .logic = logic,
                        }) catch {};
                    } else {
                        // 默认等于
                        self.wheres.append(self.allocator, .{
                            .field = field,
                            .op = .eq,
                            .value = mysql.Value.from(first),
                            .logic = logic,
                        }) catch {};
                    }
                }
            }
            return self;
        }

        /// whereRaw("YEAR(created_at) = ?", .{2024})
        pub fn whereRaw(self: *Self, raw_sql: []const u8, args: anytype) *Self {
            _ = args;
            self.wheres.append(self.allocator, .{
                .field = "",
                .op = .eq,
                .value = .null_val,
                .logic = .and_op,
                .raw = raw_sql,
            }) catch {};
            return self;
        }

        /// whereIn("status", &.{1, 2, 3})
        pub fn whereIn(self: *Self, field: []const u8, values: anytype) *Self {
            _ = values;
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .in_op,
                .value = .null_val, // TODO: 序列化数组
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// whereNotIn("status", &.{1, 2, 3})
        pub fn whereNotIn(self: *Self, field: []const u8, values: anytype) *Self {
            _ = values;
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .not_in,
                .value = .null_val,
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// whereNull("deleted_at")
        pub fn whereNull(self: *Self, field: []const u8) *Self {
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .is_null,
                .value = .null_val,
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// whereNotNull("email")
        pub fn whereNotNull(self: *Self, field: []const u8) *Self {
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .is_not_null,
                .value = .null_val,
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// whereBetween("age", 18, 30)
        pub fn whereBetween(self: *Self, field: []const u8, min: anytype, max: anytype) *Self {
            _ = min;
            _ = max;
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .between,
                .value = .null_val, // TODO
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// whereLike("name", "%张%")
        pub fn whereLike(self: *Self, field: []const u8, pattern: []const u8) *Self {
            self.wheres.append(self.allocator, .{
                .field = field,
                .op = .like,
                .value = .{ .string_val = pattern },
                .logic = .and_op,
            }) catch {};
            return self;
        }

        // ====================================================================
        // ORDER BY
        // ====================================================================

        /// orderBy("created_at", .desc)
        pub fn orderBy(self: *Self, field: []const u8, dir: mysql.OrderDir) *Self {
            self.orders.append(self.allocator, .{ .field = field, .dir = dir }) catch {};
            return self;
        }

        /// orderByDesc("created_at")
        pub fn orderByDesc(self: *Self, field: []const u8) *Self {
            return self.orderBy(field, .desc);
        }

        /// orderByAsc("name")
        pub fn orderByAsc(self: *Self, field: []const u8) *Self {
            return self.orderBy(field, .asc);
        }

        /// latest() - 按创建时间倒序
        pub fn latest(self: *Self) *Self {
            return self.orderByDesc("created_at");
        }

        /// oldest() - 按创建时间正序
        pub fn oldest(self: *Self) *Self {
            return self.orderByAsc("created_at");
        }

        // ====================================================================
        // JOIN
        // ====================================================================

        /// join("orders", "users.id", "=", "orders.user_id")
        pub fn join(self: *Self, table: []const u8, first: []const u8, operator: []const u8, second: []const u8) *Self {
            self.joins.append(self.allocator, .{
                .join_type = .inner,
                .table = table,
                .first = first,
                .operator = operator,
                .second = second,
            }) catch {};
            return self;
        }

        /// leftJoin("orders", "users.id", "=", "orders.user_id")
        pub fn leftJoin(self: *Self, table: []const u8, first: []const u8, operator: []const u8, second: []const u8) *Self {
            self.joins.append(self.allocator, .{
                .join_type = .left,
                .table = table,
                .first = first,
                .operator = operator,
                .second = second,
            }) catch {};
            return self;
        }

        /// rightJoin("orders", "users.id", "=", "orders.user_id")
        pub fn rightJoin(self: *Self, table: []const u8, first: []const u8, operator: []const u8, second: []const u8) *Self {
            self.joins.append(self.allocator, .{
                .join_type = .right,
                .table = table,
                .first = first,
                .operator = operator,
                .second = second,
            }) catch {};
            return self;
        }

        // ====================================================================
        // GROUP BY / HAVING
        // ====================================================================

        /// groupBy("status")
        pub fn groupBy(self: *Self, fields: []const []const u8) *Self {
            for (fields) |f| {
                self.groups.append(self.allocator, f) catch {};
            }
            return self;
        }

        /// having("COUNT(*) > ?", .{5})
        pub fn having(self: *Self, clause: []const u8) *Self {
            // 释放旧的 having_clause（如果存在）
            if (self.having_clause) |old_clause| {
                self.allocator.free(old_clause);
            }
            // 复制字符串以确保内存安全
            self.having_clause = self.allocator.dupe(u8, clause) catch {
                self.having_clause = null;
                return self;
            };
            return self;
        }

        // ====================================================================
        // LIMIT / OFFSET / PAGINATION
        // ====================================================================

        /// limit(10)
        pub fn limit(self: *Self, n: u64) *Self {
            self.limit_value = n;
            return self;
        }

        /// offset(20)
        pub fn offset(self: *Self, n: u64) *Self {
            self.offset_value = n;
            return self;
        }

        /// take(10) - limit 的别名
        pub fn take(self: *Self, n: u64) *Self {
            return self.limit(n);
        }

        /// skip(20) - offset 的别名
        pub fn skip(self: *Self, n: u64) *Self {
            return self.offset(n);
        }

        /// forPage(2, 15) - 分页
        pub fn forPage(self: *Self, page_num: u64, per_page: u64) *Self {
            self.limit_value = per_page;
            self.offset_value = (page_num - 1) * per_page;
            return self;
        }

        // ====================================================================
        // 软删除
        // ====================================================================

        /// withTrashed() - 包含软删除记录
        pub fn withTrashed(self: *Self) *Self {
            self.with_trashed = true;
            return self;
        }

        /// onlyTrashed() - 只查询软删除记录
        pub fn onlyTrashed(self: *Self) *Self {
            self.only_trashed = true;
            return self;
        }

        // ====================================================================
        // SQL 构建
        // ====================================================================

        /// 构建 SELECT SQL
        pub fn toSql(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            // SELECT
            try sql.appendSlice(self.allocator, "SELECT ");
            if (self.distinct_flag) {
                try sql.appendSlice(self.allocator, "DISTINCT ");
            }

            if (self.select_columns.items.len == 0) {
                try sql.appendSlice(self.allocator, "*");
            } else {
                for (self.select_columns.items, 0..) |col, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, col);
                }
            }

            // FROM
            try sql.appendSlice(self.allocator, " FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            // JOIN
            for (self.joins.items) |j| {
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.join_type.toSql());
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.table);
                try sql.appendSlice(self.allocator, " ON ");
                try sql.appendSlice(self.allocator, j.first);
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.operator);
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.second);
            }

            // WHERE
            if (self.wheres.items.len > 0 or self.only_trashed) {
                try sql.appendSlice(self.allocator, " WHERE ");

                var first_where = true;

                // 软删除条件
                if (self.only_trashed) {
                    try sql.appendSlice(self.allocator, "deleted_at IS NOT NULL");
                    first_where = false;
                } else if (!self.with_trashed) {
                    // 默认排除软删除
                    if (comptime hasField(T, "deleted_at")) {
                        try sql.appendSlice(self.allocator, "deleted_at IS NULL");
                        first_where = false;
                    }
                }

                for (self.wheres.items) |w| {
                    if (!first_where) {
                        try sql.appendSlice(self.allocator, if (w.logic == .and_op) " AND " else " OR ");
                    }
                    first_where = false;

                    if (w.raw) |raw| {
                        try sql.appendSlice(self.allocator, raw);
                    } else {
                        try sql.appendSlice(self.allocator, w.field);

                        if (w.op == .is_null or w.op == .is_not_null) {
                            try sql.append(self.allocator, ' ');
                            try sql.appendSlice(self.allocator, w.op.toSql());
                        } else {
                            try sql.append(self.allocator, ' ');
                            try sql.appendSlice(self.allocator, w.op.toSql());
                            try sql.append(self.allocator, ' ');

                            const val_sql = try w.value.toSql(self.allocator);
                            defer self.allocator.free(val_sql);
                            try sql.appendSlice(self.allocator, val_sql);
                        }
                    }
                }
            }

            // GROUP BY
            if (self.groups.items.len > 0) {
                try sql.appendSlice(self.allocator, " GROUP BY ");
                for (self.groups.items, 0..) |g, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, g);
                }
            }

            // HAVING
            if (self.having_clause) |h| {
                try sql.appendSlice(self.allocator, " HAVING ");
                try sql.appendSlice(self.allocator, h);
            }

            // ORDER BY
            if (self.orders.items.len > 0) {
                try sql.appendSlice(self.allocator, " ORDER BY ");
                for (self.orders.items, 0..) |o, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, o.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, o.dir.toSql());
                }
            }

            // LIMIT
            if (self.limit_value) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            // OFFSET
            if (self.offset_value) |off| {
                try sql.writer(self.allocator).print(" OFFSET {d}", .{off});
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建 COUNT SQL
        pub fn toCountSql(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "SELECT COUNT(*) FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.wheres.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.wheres.items, 0..) |w, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (w.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, w.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, w.op.toSql());

                    if (w.op != .is_null and w.op != .is_not_null) {
                        try sql.append(self.allocator, ' ');
                        const val_sql = try w.value.toSql(self.allocator);
                        defer self.allocator.free(val_sql);
                        try sql.appendSlice(self.allocator, val_sql);
                    }
                }
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建 DELETE SQL
        pub fn toDeleteSql(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "DELETE FROM ");
            try sql.appendSlice(self.allocator, self.table_name);

            if (self.wheres.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.wheres.items, 0..) |w, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (w.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, w.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, w.op.toSql());

                    if (w.op != .is_null and w.op != .is_not_null) {
                        try sql.append(self.allocator, ' ');
                        const val_sql = try w.value.toSql(self.allocator);
                        defer self.allocator.free(val_sql);
                        try sql.appendSlice(self.allocator, val_sql);
                    }
                }
            }

            if (self.limit_value) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 构建软删除 UPDATE SQL
        pub fn toSoftDeleteSql(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            try sql.appendSlice(self.allocator, "UPDATE ");
            try sql.appendSlice(self.allocator, self.table_name);
            try sql.appendSlice(self.allocator, " SET deleted_at = NOW()");

            if (self.wheres.items.len > 0) {
                try sql.appendSlice(self.allocator, " WHERE ");
                for (self.wheres.items, 0..) |w, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (w.logic == .and_op) " AND " else " OR ");
                    }
                    try sql.appendSlice(self.allocator, w.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, w.op.toSql());

                    if (w.op != .is_null and w.op != .is_not_null) {
                        try sql.append(self.allocator, ' ');
                        const val_sql = try w.value.toSql(self.allocator);
                        defer self.allocator.free(val_sql);
                        try sql.appendSlice(self.allocator, val_sql);
                    }
                }
            }

            return sql.toOwnedSlice(self.allocator);
        }
    };
}

/// 检查类型是否有指定字段
fn hasField(comptime T: type, comptime field_name: []const u8) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;

    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return true;
        }
    }
    return false;
}

// ============================================================================
// Eloquent 模型
// ============================================================================

/// 创建 Eloquent 模型
pub fn Model(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Entity = T;

        /// 获取表名
        pub fn tableName() []const u8 {
            if (@hasDecl(T, "table")) {
                return T.table;
            }
            // 默认表名（类型名小写 + s）
            return @typeName(T);
        }

        /// 获取主键
        pub fn primaryKey() []const u8 {
            if (@hasDecl(T, "primary_key")) {
                return T.primary_key;
            }
            return "id";
        }

        /// 是否启用时间戳
        pub fn hasTimestamps() bool {
            if (@hasDecl(T, "timestamps")) {
                return T.timestamps;
            }
            return true;
        }

        /// 是否启用软删除
        pub fn hasSoftDeletes() bool {
            if (@hasDecl(T, "soft_deletes")) {
                return T.soft_deletes;
            }
            return false;
        }

        /// 创建查询构建器
        pub fn query(allocator: Allocator) QueryBuilder(T) {
            return QueryBuilder(T).init(allocator, tableName());
        }

        /// 快捷 where
        pub fn where(allocator: Allocator, field: []const u8, args: anytype) QueryBuilder(T) {
            var builder = query(allocator);
            _ = builder.where(field, args);
            return builder;
        }

        /// 获取所有记录
        pub fn all(allocator: Allocator) ![]const u8 {
            var builder = query(allocator);
            defer builder.deinit();
            return builder.toSql();
        }

        /// 根据主键查找
        pub fn find(allocator: Allocator, id: anytype) ![]const u8 {
            var builder = query(allocator);
            defer builder.deinit();
            _ = builder.where(primaryKey(), .{id}).limit(1);
            return builder.toSql();
        }

        /// 获取第一条记录
        pub fn first(allocator: Allocator) ![]const u8 {
            var builder = query(allocator);
            defer builder.deinit();
            _ = builder.limit(1);
            return builder.toSql();
        }

        /// 统计数量
        pub fn count(allocator: Allocator) ![]const u8 {
            var builder = query(allocator);
            defer builder.deinit();
            return builder.toCountSql();
        }
    };
}

// ============================================================================
// 测试
// ============================================================================

test "Op: 操作符转换" {
    try std.testing.expectEqualStrings("=", Op.eq.toSql());
    try std.testing.expectEqualStrings("<>", Op.ne.toSql());
    try std.testing.expectEqualStrings(">", Op.gt.toSql());
    try std.testing.expectEqualStrings(">=", Op.gte.toSql());
    try std.testing.expectEqualStrings("LIKE", Op.like.toSql());
    try std.testing.expectEqualStrings("IS NULL", Op.is_null.toSql());
}

test "Op: 从字符串解析" {
    try std.testing.expectEqual(Op.eq, Op.fromString("="));
    try std.testing.expectEqual(Op.ne, Op.fromString("!="));
    try std.testing.expectEqual(Op.ne, Op.fromString("<>"));
    try std.testing.expectEqual(Op.gt, Op.fromString(">"));
    try std.testing.expectEqual(Op.gte, Op.fromString(">="));
    try std.testing.expectEqual(Op.like, Op.fromString("like"));
    try std.testing.expectEqual(Op.like, Op.fromString("LIKE"));
}

test "QueryBuilder: 基本 SELECT" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expectEqualStrings("SELECT * FROM users", sql);
}

test "QueryBuilder: WHERE 条件" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    // where("age", ">", 18)
    _ = builder.where("age", .{ ">", @as(i64, 18) });
    // where("status", 1)
    _ = builder.where("status", .{@as(i64, 1)});

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "WHERE") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "age > 18") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "status = 1") != null);
}

test "QueryBuilder: whereNull / whereNotNull" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.whereNull("deleted_at").whereNotNull("email");

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "deleted_at IS NULL") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "email IS NOT NULL") != null);
}

test "QueryBuilder: ORDER BY" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.orderByDesc("created_at").orderByAsc("name");

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "ORDER BY created_at DESC, name ASC") != null);
}

test "QueryBuilder: JOIN" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.leftJoin("orders", "users.id", "=", "orders.user_id");

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "LEFT JOIN orders ON users.id = orders.user_id") != null);
}

test "QueryBuilder: 分页" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.forPage(3, 20);

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "LIMIT 20") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "OFFSET 40") != null);
}

test "QueryBuilder: 链式调用" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder
        .where("status", .{@as(i64, 1)})
        .whereNotNull("email")
        .orderByDesc("created_at")
        .limit(10);

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "status = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "email IS NOT NULL") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "ORDER BY created_at DESC") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "LIMIT 10") != null);
}

test "Model: 表名和主键" {
    const User = Model(struct {
        pub const table = "users";
        pub const primary_key = "user_id";

        id: u64,
        name: []const u8,
    });

    try std.testing.expectEqualStrings("users", User.tableName());
    try std.testing.expectEqualStrings("user_id", User.primaryKey());
}

test "Model: 默认表名" {
    const Product = Model(struct {
        id: u64,
        name: []const u8,
    });

    // 默认使用类型名
    try std.testing.expect(Product.tableName().len > 0);
}

test "Model: 快捷方法" {
    const allocator = std.testing.allocator;

    const User = Model(struct {
        pub const table = "users";
        id: u64,
        name: []const u8,
    });

    // all()
    const all_sql = try User.all(allocator);
    defer allocator.free(all_sql);
    try std.testing.expectEqualStrings("SELECT * FROM users", all_sql);

    // find(1)
    const find_sql = try User.find(allocator, @as(i64, 1));
    defer allocator.free(find_sql);
    try std.testing.expect(std.mem.indexOf(u8, find_sql, "id = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, find_sql, "LIMIT 1") != null);

    // first()
    const first_sql = try User.first(allocator);
    defer allocator.free(first_sql);
    try std.testing.expect(std.mem.indexOf(u8, first_sql, "LIMIT 1") != null);

    // count()
    const count_sql = try User.count(allocator);
    defer allocator.free(count_sql);
    try std.testing.expect(std.mem.indexOf(u8, count_sql, "SELECT COUNT(*)") != null);
}

test "QueryBuilder: DELETE" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("id", .{@as(i64, 1)});

    const sql = try builder.toDeleteSql();
    defer allocator.free(sql);

    try std.testing.expectEqualStrings("DELETE FROM users WHERE id = 1", sql);
}

test "QueryBuilder: 软删除" {
    const allocator = std.testing.allocator;

    var builder = QueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.where("id", .{@as(i64, 1)});

    const sql = try builder.toSoftDeleteSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "UPDATE users SET deleted_at = NOW()") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "WHERE id = 1") != null);
}

test "hasField: 字段检查" {
    const TestStruct = struct {
        id: u64,
        name: []const u8,
        deleted_at: ?i64,
    };

    try std.testing.expect(hasField(TestStruct, "id"));
    try std.testing.expect(hasField(TestStruct, "name"));
    try std.testing.expect(hasField(TestStruct, "deleted_at"));
    try std.testing.expect(!hasField(TestStruct, "not_exists"));
}
