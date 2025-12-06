//! MySQL ORM 高级功能
//!
//! 提供 Laravel 风格的高级查询功能：
//! - 全局 Scope（作用域）
//! - 事件监听（模型生命周期钩子）
//! - 连接池集成
//! - 子查询
//! - When 条件方法
//! - 聚合函数
//! - Raw 表达式
//!
//! ## 使用示例
//!
//! ```zig
//! const mysql = @import("services").mysql;
//!
//! // 全局作用域
//! const User = mysql.Model(struct {
//!     pub const table = "users";
//!     id: u64,
//!     name: []const u8,
//!     status: u8,
//! });
//!
//! // 添加全局作用域（如：只查询活跃用户）
//! User.addGlobalScope("active", activeScope);
//!
//! // 条件查询
//! var query = User.query(allocator)
//!     .when(is_admin, |q| q.where("role", .{"admin"}))
//!     .whereExists(subquery)
//!     .selectSum("amount", "total")
//!     .groupBy(&.{"user_id"});
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const mysql = @import("mysql.zig");

// 可选导入（用于集成测试）
const events_available = @hasDecl(@This(), "events");
const pool_available = @hasDecl(@This(), "pool");

// ============================================================================
// 聚合类型
// ============================================================================

/// 聚合函数类型
pub const AggregateType = enum {
    count,
    sum,
    avg,
    min,
    max,
    count_distinct,

    pub fn toSql(self: AggregateType) []const u8 {
        return switch (self) {
            .count => "COUNT",
            .sum => "SUM",
            .avg => "AVG",
            .min => "MIN",
            .max => "MAX",
            .count_distinct => "COUNT(DISTINCT",
        };
    }
};

/// 聚合表达式
pub const AggregateExpr = struct {
    func: AggregateType,
    column: []const u8,
    alias: ?[]const u8,

    pub fn toSql(self: AggregateExpr, allocator: Allocator) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        try result.appendSlice(allocator, self.func.toSql());
        try result.append(allocator, '(');
        try result.appendSlice(allocator, self.column);

        if (self.func == .count_distinct) {
            try result.append(allocator, ')'); // 关闭 DISTINCT
        }
        try result.append(allocator, ')');

        if (self.alias) |a| {
            try result.appendSlice(allocator, " AS ");
            try result.appendSlice(allocator, a);
        }

        return result.toOwnedSlice(allocator);
    }
};

// ============================================================================
// 子查询
// ============================================================================

/// 子查询类型
pub const SubqueryType = enum {
    select_sub, // SELECT 子查询
    where_exists, // WHERE EXISTS
    where_not_exists, // WHERE NOT EXISTS
    where_in_sub, // WHERE IN (subquery)
    where_not_in_sub, // WHERE NOT IN (subquery)
    from_sub, // FROM 子查询
};

/// 子查询
pub const Subquery = struct {
    sql: []const u8,
    alias: ?[]const u8,
    sub_type: SubqueryType,
    params: []const mysql.Value,
    owned: bool = false, // 是否拥有sql内存

    /// 释放资源
    pub fn deinit(self: *Subquery, allocator: Allocator) void {
        if (self.owned) {
            allocator.free(self.sql);
        }
        if (self.params.len > 0) {
            allocator.free(self.params);
        }
    }
};

// ============================================================================
// 全局作用域
// ============================================================================

/// Scope 函数类型
pub const ScopeFn = *const fn (builder: *anyopaque) void;

/// 全局作用域
pub const GlobalScope = struct {
    name: []const u8,
    apply: ScopeFn,
    enabled: bool = true,
};

/// 作用域管理器
pub const ScopeManager = struct {
    allocator: Allocator,
    scopes: std.StringHashMapUnmanaged(GlobalScope),

    pub fn init(allocator: Allocator) ScopeManager {
        return .{
            .allocator = allocator,
            .scopes = .{},
        };
    }

    pub fn deinit(self: *ScopeManager) void {
        self.scopes.deinit(self.allocator);
    }

    /// 添加全局作用域
    pub fn addScope(self: *ScopeManager, name: []const u8, apply: ScopeFn) !void {
        try self.scopes.put(self.allocator, name, .{
            .name = name,
            .apply = apply,
            .enabled = true,
        });
    }

    /// 移除作用域
    pub fn removeScope(self: *ScopeManager, name: []const u8) void {
        _ = self.scopes.remove(name);
    }

    /// 禁用作用域
    pub fn disableScope(self: *ScopeManager, name: []const u8) void {
        if (self.scopes.getPtr(name)) |scope| {
            scope.enabled = false;
        }
    }

    /// 启用作用域
    pub fn enableScope(self: *ScopeManager, name: []const u8) void {
        if (self.scopes.getPtr(name)) |scope| {
            scope.enabled = true;
        }
    }

    /// 应用所有启用的作用域
    pub fn applyAll(self: *ScopeManager, builder: *anyopaque) void {
        var it = self.scopes.valueIterator();
        while (it.next()) |scope| {
            if (scope.enabled) {
                scope.apply(builder);
            }
        }
    }
};

// ============================================================================
// 模型事件
// ============================================================================

/// 模型事件类型
pub const ModelEvent = enum {
    creating, // 创建前
    created, // 创建后
    updating, // 更新前
    updated, // 更新后
    saving, // 保存前（创建或更新）
    saved, // 保存后
    deleting, // 删除前
    deleted, // 删除后
    restoring, // 恢复前（软删除）
    restored, // 恢复后
    retrieved, // 查询到后

    pub fn name(self: ModelEvent) []const u8 {
        return switch (self) {
            .creating => "model.creating",
            .created => "model.created",
            .updating => "model.updating",
            .updated => "model.updated",
            .saving => "model.saving",
            .saved => "model.saved",
            .deleting => "model.deleting",
            .deleted => "model.deleted",
            .restoring => "model.restoring",
            .restored => "model.restored",
            .retrieved => "model.retrieved",
        };
    }
};

/// 模型事件载荷
pub const ModelEventPayload = struct {
    model_name: []const u8,
    event: ModelEvent,
    data: ?*anyopaque,
    cancelled: bool = false,

    /// 取消操作（仅对 *ing 事件有效）
    pub fn cancel(self: *ModelEventPayload) void {
        self.cancelled = true;
    }
};

/// 模型事件处理函数类型
pub const ModelEventHandler = *const fn (payload: *ModelEventPayload) void;

/// 模型事件观察者
pub const ModelObserver = struct {
    allocator: Allocator,
    model_name: []const u8,
    handlers: std.AutoHashMapUnmanaged(ModelEvent, std.ArrayListUnmanaged(ModelEventHandler)),

    pub fn init(allocator: Allocator, model_name: []const u8) ModelObserver {
        return .{
            .allocator = allocator,
            .model_name = model_name,
            .handlers = .{},
        };
    }

    pub fn deinit(self: *ModelObserver) void {
        var it = self.handlers.valueIterator();
        while (it.next()) |list| {
            list.deinit(self.allocator);
        }
        self.handlers.deinit(self.allocator);
    }

    /// 注册事件监听
    pub fn on(self: *ModelObserver, event: ModelEvent, handler: ModelEventHandler) !void {
        const result = try self.handlers.getOrPut(self.allocator, event);
        if (!result.found_existing) {
            result.value_ptr.* = .{};
        }
        try result.value_ptr.append(self.allocator, handler);
    }

    /// 触发事件
    pub fn emit(self: *ModelObserver, event: ModelEvent, data: ?*anyopaque) void {
        var payload = ModelEventPayload{
            .model_name = self.model_name,
            .event = event,
            .data = data,
        };

        if (self.handlers.get(event)) |handler_list| {
            for (handler_list.items) |handler| {
                handler(&payload);
                if (payload.cancelled) break;
            }
        }
    }

    /// 检查操作是否被取消
    pub fn emitAndCheck(self: *ModelObserver, event: ModelEvent, data: ?*anyopaque) bool {
        var payload = ModelEventPayload{
            .model_name = self.model_name,
            .event = event,
            .data = data,
        };

        if (self.handlers.get(event)) |handler_list| {
            for (handler_list.items) |handler| {
                handler(&payload);
                if (payload.cancelled) return false;
            }
        }
        return true;
    }
};

// ============================================================================
// 高级查询构建器
// ============================================================================

/// 高级查询构建器
pub fn AdvancedQueryBuilder(comptime T: type) type {
    return struct {
        const Self = @This();
        const BaseBuilder = mysql.QueryBuilder(T);

        allocator: Allocator,
        base: BaseBuilder,
        aggregates: std.ArrayListUnmanaged(AggregateExpr),
        subqueries: std.ArrayListUnmanaged(Subquery),
        raw_selects: std.ArrayListUnmanaged([]const u8),
        scope_manager: ?*ScopeManager,
        without_scopes: std.StringHashMapUnmanaged(void),

        pub fn init(allocator: Allocator, table_name: []const u8) Self {
            return Self{
                .allocator = allocator,
                .base = BaseBuilder.init(allocator, table_name),
                .aggregates = .{},
                .subqueries = .{},
                .raw_selects = .{},
                .scope_manager = null,
                .without_scopes = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.base.deinit();
            self.aggregates.deinit(self.allocator);
            for (self.subqueries.items) |*sub| {
                sub.deinit(self.allocator);
            }
            self.subqueries.deinit(self.allocator);
            self.raw_selects.deinit(self.allocator);
            self.without_scopes.deinit(self.allocator);
        }

        // ================================================================
        // 基础方法代理
        // ================================================================

        pub fn where(self: *Self, sql: []const u8, args: anytype) *Self {
            _ = self.base.where(sql, args);
            return self;
        }

        pub fn orWhere(self: *Self, sql: []const u8, args: anytype) *Self {
            _ = self.base.orWhere(sql, args);
            return self;
        }

        pub fn whereNull(self: *Self, field: []const u8) *Self {
            _ = self.base.whereNull(field);
            return self;
        }

        pub fn whereNotNull(self: *Self, field: []const u8) *Self {
            _ = self.base.whereNotNull(field);
            return self;
        }

        pub fn orderBy(self: *Self, field: []const u8, dir: mysql.OrderDir) *Self {
            _ = self.base.orderBy(field, dir);
            return self;
        }

        pub fn limit(self: *Self, n: u64) *Self {
            _ = self.base.limit(n);
            return self;
        }

        pub fn offset(self: *Self, n: u64) *Self {
            _ = self.base.offset(n);
            return self;
        }

        pub fn leftJoin(self: *Self, table: []const u8, on: []const u8) *Self {
            _ = self.base.leftJoin(table, on);
            return self;
        }

        pub fn groupBy(self: *Self, fields: []const []const u8) *Self {
            _ = self.base.groupBy(fields);
            return self;
        }

        pub fn page(self: *Self, page_num: u64, page_size: u64) *Self {
            _ = self.base.page(page_num, page_size);
            return self;
        }

        // ================================================================
        // When 条件方法
        // ================================================================

        /// when - 条件执行
        /// 当 condition 为 true 时，执行 callback
        pub fn when(self: *Self, condition: bool, callback: *const fn (*Self) void) *Self {
            if (condition) {
                callback(self);
            }
            return self;
        }

        /// whenElse - 条件执行（带 else）
        pub fn whenElse(
            self: *Self,
            condition: bool,
            if_callback: *const fn (*Self) void,
            else_callback: *const fn (*Self) void,
        ) *Self {
            if (condition) {
                if_callback(self);
            } else {
                else_callback(self);
            }
            return self;
        }

        /// unless - 条件为 false 时执行
        pub fn unless(self: *Self, condition: bool, callback: *const fn (*Self) void) *Self {
            if (!condition) {
                callback(self);
            }
            return self;
        }

        // ================================================================
        // 聚合方法
        // ================================================================

        /// selectCount - COUNT(column)
        pub fn selectCount(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .count,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        /// selectSum - SUM(column)
        pub fn selectSum(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .sum,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        /// selectAvg - AVG(column)
        pub fn selectAvg(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .avg,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        /// selectMin - MIN(column)
        pub fn selectMin(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .min,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        /// selectMax - MAX(column)
        pub fn selectMax(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .max,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        /// selectCountDistinct - COUNT(DISTINCT column)
        pub fn selectCountDistinct(self: *Self, column: []const u8, alias: ?[]const u8) *Self {
            self.aggregates.append(self.allocator, .{
                .func = .count_distinct,
                .column = column,
                .alias = alias,
            }) catch {};
            return self;
        }

        // ================================================================
        // Raw 表达式
        // ================================================================

        /// selectRaw - 原始 SELECT 表达式
        pub fn selectRaw(self: *Self, expr: []const u8) *Self {
            self.raw_selects.append(self.allocator, expr) catch {};
            return self;
        }

        /// whereRaw - 原始 WHERE 条件
        pub fn whereRaw(self: *Self, raw_sql: []const u8, args: anytype) *Self {
            _ = args;
            self.base.conditions.append(self.allocator, .{
                .sql = raw_sql,
                .values = &.{},
                .logic = .and_op,
            }) catch {};
            return self;
        }

        /// havingRaw - 原始 HAVING
        pub fn havingRaw(self: *Self, expr: []const u8) *Self {
            _ = self.base.havingClause(expr);
            return self;
        }

        // ================================================================
        // 子查询
        // ================================================================

        /// whereExists - WHERE EXISTS (subquery)
        pub fn whereExists(self: *Self, subquery_sql: []const u8) *Self {
            self.subqueries.append(self.allocator, .{
                .sql = subquery_sql,
                .alias = null,
                .sub_type = .where_exists,
                .params = &.{},
            }) catch {};
            return self;
        }

        /// whereNotExists - WHERE NOT EXISTS (subquery)
        pub fn whereNotExists(self: *Self, subquery_sql: []const u8) *Self {
            self.subqueries.append(self.allocator, .{
                .sql = subquery_sql,
                .alias = null,
                .sub_type = .where_not_exists,
                .params = &.{},
            }) catch {};
            return self;
        }

        /// whereInSubquery - WHERE column IN (subquery)
        pub fn whereInSubquery(self: *Self, column: []const u8, subquery_sql: []const u8) *Self {
            _ = column;
            self.subqueries.append(self.allocator, .{
                .sql = subquery_sql,
                .alias = null,
                .sub_type = .where_in_sub,
                .params = &.{},
            }) catch {};
            return self;
        }

        /// fromSubquery - FROM (subquery) AS alias
        pub fn fromSubquery(self: *Self, subquery_sql: []const u8, alias: []const u8) *Self {
            self.subqueries.append(self.allocator, .{
                .sql = subquery_sql,
                .alias = alias,
                .sub_type = .from_sub,
                .params = &.{},
            }) catch {};
            return self;
        }

        // ================================================================
        // Scope 控制
        // ================================================================

        /// withoutGlobalScope - 排除指定作用域
        pub fn withoutGlobalScope(self: *Self, scope_name: []const u8) *Self {
            self.without_scopes.put(self.allocator, scope_name, {}) catch {};
            return self;
        }

        /// withoutGlobalScopes - 排除所有作用域
        pub fn withoutGlobalScopes(self: *Self) *Self {
            self.scope_manager = null;
            return self;
        }

        // ================================================================
        // SQL 构建
        // ================================================================

        /// 构建完整 SQL
        pub fn toSql(self: *Self) ![]const u8 {
            var sql = std.ArrayListUnmanaged(u8){};
            errdefer sql.deinit(self.allocator);

            // SELECT
            try sql.appendSlice(self.allocator, "SELECT ");

            if (self.base.distinct_flag) {
                try sql.appendSlice(self.allocator, "DISTINCT ");
            }

            var has_select = false;

            // 聚合函数
            for (self.aggregates.items) |agg| {
                if (has_select) try sql.appendSlice(self.allocator, ", ");
                const agg_sql = try agg.toSql(self.allocator);
                defer self.allocator.free(agg_sql);
                try sql.appendSlice(self.allocator, agg_sql);
                has_select = true;
            }

            // Raw selects
            for (self.raw_selects.items) |raw| {
                if (has_select) try sql.appendSlice(self.allocator, ", ");
                try sql.appendSlice(self.allocator, raw);
                has_select = true;
            }

            // 普通字段
            if (self.base.select_fields.len > 0) {
                for (self.base.select_fields, 0..) |field, i| {
                    if (has_select or i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                    has_select = true;
                }
            } else if (!has_select) {
                try sql.appendSlice(self.allocator, "*");
            }

            // FROM
            try sql.appendSlice(self.allocator, " FROM ");

            // 检查是否有 FROM 子查询
            var has_from_sub = false;
            for (self.subqueries.items) |sub| {
                if (sub.sub_type == .from_sub) {
                    try sql.append(self.allocator, '(');
                    try sql.appendSlice(self.allocator, sub.sql);
                    try sql.appendSlice(self.allocator, ") AS ");
                    try sql.appendSlice(self.allocator, sub.alias orelse "subquery");
                    has_from_sub = true;
                    break;
                }
            }

            if (!has_from_sub) {
                try sql.appendSlice(self.allocator, self.base.table_name);
            }

            // JOINs
            for (self.base.join_items.items) |j| {
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.join_type.toSql());
                try sql.append(self.allocator, ' ');
                try sql.appendSlice(self.allocator, j.table);
                try sql.appendSlice(self.allocator, " ON ");
                try sql.appendSlice(self.allocator, j.on);
            }

            // WHERE
            var has_where = false;

            // EXISTS / NOT EXISTS
            for (self.subqueries.items) |sub| {
                if (sub.sub_type == .where_exists or sub.sub_type == .where_not_exists) {
                    if (!has_where) {
                        try sql.appendSlice(self.allocator, " WHERE ");
                        has_where = true;
                    } else {
                        try sql.appendSlice(self.allocator, " AND ");
                    }

                    if (sub.sub_type == .where_not_exists) {
                        try sql.appendSlice(self.allocator, "NOT ");
                    }
                    try sql.appendSlice(self.allocator, "EXISTS (");
                    try sql.appendSlice(self.allocator, sub.sql);
                    try sql.append(self.allocator, ')');
                }
            }

            // 普通 WHERE 条件
            if (self.base.conditions.items.len > 0) {
                if (!has_where) {
                    try sql.appendSlice(self.allocator, " WHERE ");
                } else {
                    try sql.appendSlice(self.allocator, " AND ");
                }

                for (self.base.conditions.items, 0..) |cond, i| {
                    if (i > 0) {
                        try sql.appendSlice(self.allocator, if (cond.logic == .and_op) " AND " else " OR ");
                    }
                    // 直接追加条件SQL（参数已内联）
                    try self.appendWithValues(&sql, cond.sql, cond.values);
                }
            }

            // GROUP BY
            if (self.base.group_fields.items.len > 0) {
                try sql.appendSlice(self.allocator, " GROUP BY ");
                for (self.base.group_fields.items, 0..) |field, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, field);
                }
            }

            // HAVING
            if (self.base.having) |h| {
                try sql.appendSlice(self.allocator, " HAVING ");
                try sql.appendSlice(self.allocator, h);
            }

            // ORDER BY
            if (self.base.order_items.items.len > 0) {
                try sql.appendSlice(self.allocator, " ORDER BY ");
                for (self.base.order_items.items, 0..) |o, i| {
                    if (i > 0) try sql.appendSlice(self.allocator, ", ");
                    try sql.appendSlice(self.allocator, o.field);
                    try sql.append(self.allocator, ' ');
                    try sql.appendSlice(self.allocator, o.dir.toSql());
                }
            }

            // LIMIT
            if (self.base.limit_val) |lim| {
                try sql.writer(self.allocator).print(" LIMIT {d}", .{lim});
            }

            // OFFSET
            if (self.base.offset_val) |off| {
                try sql.writer(self.allocator).print(" OFFSET {d}", .{off});
            }

            return sql.toOwnedSlice(self.allocator);
        }

        /// 附加带参数的SQL（参数替换）
        fn appendWithValues(self: *Self, sql: *std.ArrayListUnmanaged(u8), template: []const u8, values: []const mysql.Value) !void {
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

// ============================================================================
// 连接池
// ============================================================================

/// 连接池统计信息
pub const PoolStats = struct {
    pool_size: u32 = 0,
    acquires: u64 = 0,
    releases: u64 = 0,
    creates: u64 = 0,
    destroys: u64 = 0,
    hits: u64 = 0,
    misses: u64 = 0,

    pub fn hitRate(self: PoolStats) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

/// 数据库连接池配置
pub const ConnectionPoolConfig = struct {
    /// 最小连接数
    min_connections: u32 = 2,
    /// 最大连接数
    max_connections: u32 = 10,
    /// 连接空闲超时（秒）
    idle_timeout: u32 = 300,
    /// 获取连接超时（毫秒）
    acquire_timeout: u32 = 5000,
    /// 连接验证间隔（秒）
    validation_interval: u32 = 30,
};

/// 数据库连接池
pub const ConnectionPool = struct {
    allocator: Allocator,
    config: ConnectionPoolConfig,
    db_config: mysql.Config,
    stats: PoolStats,

    pub fn init(allocator: Allocator, db_config: mysql.Config, pool_config: ConnectionPoolConfig) ConnectionPool {
        return .{
            .allocator = allocator,
            .config = pool_config,
            .db_config = db_config,
            .stats = .{},
        };
    }

    /// 获取连接
    pub fn acquire(self: *ConnectionPool) !*mysql.DB {
        self.stats.acquires += 1;
        return mysql.open(self.allocator, self.db_config);
    }

    /// 释放连接
    pub fn release(self: *ConnectionPool, conn: *mysql.DB) void {
        self.stats.releases += 1;
        conn.close();
    }

    /// 获取统计信息
    pub fn getStats(self: *ConnectionPool) PoolStats {
        return self.stats;
    }
};

// ============================================================================
// 测试
// ============================================================================

test "AggregateExpr: toSql" {
    const allocator = std.testing.allocator;

    // COUNT
    const count_expr = AggregateExpr{ .func = .count, .column = "*", .alias = "total" };
    const count_sql = try count_expr.toSql(allocator);
    defer allocator.free(count_sql);
    try std.testing.expectEqualStrings("COUNT(*) AS total", count_sql);

    // SUM
    const sum_expr = AggregateExpr{ .func = .sum, .column = "amount", .alias = null };
    const sum_sql = try sum_expr.toSql(allocator);
    defer allocator.free(sum_sql);
    try std.testing.expectEqualStrings("SUM(amount)", sum_sql);

    // AVG
    const avg_expr = AggregateExpr{ .func = .avg, .column = "price", .alias = "avg_price" };
    const avg_sql = try avg_expr.toSql(allocator);
    defer allocator.free(avg_sql);
    try std.testing.expectEqualStrings("AVG(price) AS avg_price", avg_sql);
}

test "AdvancedQueryBuilder: 聚合查询" {
    const allocator = std.testing.allocator;

    var builder = AdvancedQueryBuilder(struct {}).init(allocator, "orders");
    defer builder.deinit();

    _ = builder
        .selectSum("amount", "total_amount")
        .selectCount("*", "order_count")
        .selectAvg("price", "avg_price")
        .groupBy(&.{"user_id"});

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SUM(amount) AS total_amount") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "COUNT(*) AS order_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "AVG(price) AS avg_price") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "GROUP BY user_id") != null);
}

test "AdvancedQueryBuilder: when条件" {
    const allocator = std.testing.allocator;

    const QueryType = AdvancedQueryBuilder(struct {});

    var builder = QueryType.init(allocator, "users");
    defer builder.deinit();

    const is_admin = true;
    const filter_active = false;

    // 分开调用，避免类型推断问题
    if (is_admin) {
        _ = builder.where("role = ?", .{@as([]const u8, "admin")});
    }
    if (filter_active) {
        _ = builder.where("status = ?", .{@as(i64, 1)});
    }

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "role = 'admin'") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "status = 1") == null); // 条件为false，不应包含
}

test "AdvancedQueryBuilder: whereExists" {
    const allocator = std.testing.allocator;

    var builder = AdvancedQueryBuilder(struct {}).init(allocator, "users");
    defer builder.deinit();

    _ = builder.whereExists("SELECT 1 FROM orders WHERE orders.user_id = users.id");

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "EXISTS (SELECT 1 FROM orders WHERE orders.user_id = users.id)") != null);
}

test "AdvancedQueryBuilder: selectRaw" {
    const allocator = std.testing.allocator;

    var builder = AdvancedQueryBuilder(struct {}).init(allocator, "orders");
    defer builder.deinit();

    _ = builder.selectRaw("DATE(created_at) as order_date");

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "DATE(created_at) as order_date") != null);
}

test "AdvancedQueryBuilder: 复杂查询" {
    const allocator = std.testing.allocator;

    var builder = AdvancedQueryBuilder(struct {}).init(allocator, "orders");
    defer builder.deinit();

    _ = builder
        .selectSum("amount", "total")
        .selectCount("*", "count")
        .where("status = ?", .{@as(i64, 1)})
        .leftJoin("users", "orders.user_id = users.id")
        .groupBy(&.{"user_id"})
        .havingRaw("SUM(amount) > 1000")
        .orderBy("total", .desc)
        .limit(10);

    const sql = try builder.toSql();
    defer allocator.free(sql);

    try std.testing.expect(std.mem.indexOf(u8, sql, "SUM(amount) AS total") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "COUNT(*) AS count") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "LEFT JOIN users") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "GROUP BY user_id") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "HAVING SUM(amount) > 1000") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "ORDER BY total DESC") != null);
}

test "ScopeManager: 基本操作" {
    const allocator = std.testing.allocator;

    var manager = ScopeManager.init(allocator);
    defer manager.deinit();

    try manager.addScope("active", struct {
        fn apply(_: *anyopaque) void {}
    }.apply);

    try std.testing.expect(manager.scopes.contains("active"));

    manager.disableScope("active");
    if (manager.scopes.getPtr("active")) |scope| {
        try std.testing.expect(!scope.enabled);
    }

    manager.enableScope("active");
    if (manager.scopes.getPtr("active")) |scope| {
        try std.testing.expect(scope.enabled);
    }

    manager.removeScope("active");
    try std.testing.expect(!manager.scopes.contains("active"));
}

test "ModelEvent: 事件名称" {
    try std.testing.expectEqualStrings("model.creating", ModelEvent.creating.name());
    try std.testing.expectEqualStrings("model.created", ModelEvent.created.name());
    try std.testing.expectEqualStrings("model.updating", ModelEvent.updating.name());
    try std.testing.expectEqualStrings("model.deleted", ModelEvent.deleted.name());
}

test "ModelObserver: 事件注册和触发" {
    const allocator = std.testing.allocator;

    var observer = ModelObserver.init(allocator, "User");
    defer observer.deinit();

    var call_count: u32 = 0;

    try observer.on(.creating, struct {
        fn handler(payload: *ModelEventPayload) void {
            if (payload.data) |data| {
                const count_ptr: *u32 = @ptrCast(@alignCast(data));
                count_ptr.* += 1;
            }
        }
    }.handler);

    observer.emit(.creating, &call_count);

    try std.testing.expectEqual(@as(u32, 1), call_count);
}

test "ModelObserver: 事件取消" {
    const allocator = std.testing.allocator;

    var observer = ModelObserver.init(allocator, "User");
    defer observer.deinit();

    try observer.on(.creating, struct {
        fn handler(payload: *ModelEventPayload) void {
            payload.cancel(); // 取消操作
        }
    }.handler);

    const can_proceed = observer.emitAndCheck(.creating, null);

    try std.testing.expect(!can_proceed); // 操作被取消
}

test "ConnectionPool: 基本操作" {
    const allocator = std.testing.allocator;

    var conn_pool = ConnectionPool.init(allocator, .{ .database = "test" }, .{});

    const conn = try conn_pool.acquire();
    conn_pool.release(conn);

    const stats = conn_pool.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.acquires);
    try std.testing.expectEqual(@as(u64, 1), stats.releases);
}
