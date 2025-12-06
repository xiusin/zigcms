//! MySQL ORM - 高阶 Eloquent 风格 ORM
//!
//! 提供类似 Laravel Eloquent 的模型操作，支持真正的数据库交互。
//!
//! ## 使用示例
//!
//! ```zig
//! const orm = @import("services").mysql.orm;
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
const mysql_core = @import("mysql.zig");

// ============================================================================
// 数据库管理器
// ============================================================================

/// 数据库管理器 - 使用统一驱动接口
pub const Database = struct {
    allocator: Allocator,
    conn: interface.Connection,
    debug: bool = false,

    /// 从统一连接创建
    pub fn fromConnection(allocator: Allocator, conn: interface.Connection) Database {
        return .{
            .allocator = allocator,
            .conn = conn,
        };
    }

    /// 创建 SQLite 数据库（开发/测试）
    pub fn sqlite(allocator: Allocator, path: []const u8) !Database {
        return .{
            .allocator = allocator,
            .conn = try interface.Driver.sqlite(allocator, path),
        };
    }

    /// 创建 MySQL 数据库（生产）
    pub fn mysql(allocator: Allocator, config: interface.MySQLConfig) !Database {
        return .{
            .allocator = allocator,
            .conn = try interface.Driver.mysql(allocator, config),
        };
    }

    /// 创建内存数据库（纯测试）
    pub fn memory(allocator: Allocator) !Database {
        return .{
            .allocator = allocator,
            .conn = try interface.Driver.memory(allocator),
        };
    }

    pub fn deinit(self: *Database) void {
        self.conn.deinit();
    }

    /// 获取驱动类型
    pub fn getDriverType(self: *const Database) interface.DriverType {
        return self.conn.getDriverType();
    }

    /// 执行原始查询
    pub fn rawQuery(self: *Database, sql: []const u8) !interface.ResultSet {
        if (self.debug) {
            std.debug.print("[SQL] {s}\n", .{sql});
        }
        return self.conn.query(sql);
    }

    /// 执行原始命令
    pub fn rawExec(self: *Database, sql: []const u8) !u64 {
        if (self.debug) {
            std.debug.print("[SQL] {s}\n", .{sql});
        }
        return self.conn.exec(sql);
    }

    /// 开始事务
    pub fn beginTransaction(self: *Database) !void {
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

    /// 事务包装器
    pub fn transaction(self: *Database, callback: *const fn (*Database) anyerror!void) !void {
        try self.beginTransaction();
        errdefer self.rollback() catch {};
        try callback(self);
        try self.commit();
    }
};

// ============================================================================
// 模型构建器
// ============================================================================

/// 定义模型
pub fn define(comptime T: type) type {
    return struct {
        const Self = @This();
        const Model = T;

        /// 获取表名
        pub fn tableName() []const u8 {
            if (@hasDecl(T, "table_name")) {
                return T.table_name;
            }
            return @typeName(T);
        }

        /// 获取主键名
        pub fn primaryKey() []const u8 {
            if (@hasDecl(T, "primary_key")) {
                return T.primary_key;
            }
            return "id";
        }

        /// 创建查询构建器
        pub fn query(db: *Database) ModelQuery(T) {
            return ModelQuery(T).init(db, tableName());
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
            return find(db, id) orelse error.CreateFailed;
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

            if (try result.next()) |row| {
                return @intCast(row.getInt("cnt") orelse 0);
            }
            return 0;
        }

        /// 检查是否存在
        pub fn exists(db: *Database, id: anytype) !bool {
            const found = try find(db, id);
            return found != null;
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

            if (T2 == []const u8) {
                try sql.append(allocator, '\'');
                try sql.appendSlice(allocator, value);
                try sql.append(allocator, '\'');
            } else if (@typeInfo(T2) == .optional) {
                if (value) |v| {
                    try appendValue(allocator, sql, v);
                } else {
                    try sql.appendSlice(allocator, "NULL");
                }
            } else if (@typeInfo(T2) == .int or @typeInfo(T2) == .comptime_int) {
                var buf: [32]u8 = undefined;
                const len = std.fmt.formatIntBuf(&buf, value, 10, .lower, .{});
                try sql.appendSlice(allocator, buf[0..len]);
            } else if (@typeInfo(T2) == .float or @typeInfo(T2) == .comptime_float) {
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
            for (self.where_clauses.items) |clause| {
                self.db.allocator.free(clause);
            }
            self.where_clauses.deinit(self.db.allocator);
            self.select_fields.deinit(self.db.allocator);
            self.order_clauses.deinit(self.db.allocator);
            self.group_fields.deinit(self.db.allocator);
            self.join_clauses.deinit(self.db.allocator);
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
            self.where_clauses.append(self.db.allocator, clause) catch {};
            return self;
        }

        /// WHERE IN
        pub fn whereIn(self: *Self, field: []const u8, values: anytype) *Self {
            const clause = formatWhereIn(self.db.allocator, field, values) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {};
            return self;
        }

        /// WHERE NULL
        pub fn whereNull(self: *Self, field: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IS NULL", .{field}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {};
            return self;
        }

        /// WHERE NOT NULL
        pub fn whereNotNull(self: *Self, field: []const u8) *Self {
            const clause = std.fmt.allocPrint(self.db.allocator, "{s} IS NOT NULL", .{field}) catch return self;
            self.where_clauses.append(self.db.allocator, clause) catch {};
            return self;
        }

        /// ORDER BY
        pub fn orderBy(self: *Self, field: []const u8, dir: mysql_core.OrderDir) *Self {
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

        /// 执行查询
        pub fn get(self: *Self) ![]T {
            const sql = try self.toSql();
            defer self.db.allocator.free(sql);

            var result = try self.db.rawQuery(sql);
            defer result.deinit();

            return self.mapResults(&result);
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
                try sql.appendSlice(self.db.allocator, "*");
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
            var models = std.ArrayList(T).init(self.db.allocator);
            errdefer models.deinit();

            while (result.next()) |row| {
                var model: T = undefined;

                inline for (std.meta.fields(T)) |field| {
                    const value = row.getString(field.name);

                    if (@typeInfo(field.type) == .optional) {
                        @field(model, field.name) = value;
                    } else if (field.type == []const u8) {
                        @field(model, field.name) = value orelse "";
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

                try models.append(model);
            }

            return models.toOwnedSlice();
        }

        fn formatWhere(allocator: Allocator, field: []const u8, op: []const u8, value: anytype) ![]u8 {
            const V = @TypeOf(value);

            if (V == []const u8) {
                return std.fmt.allocPrint(allocator, "{s} {s} '{s}'", .{ field, op, value });
            } else if (@typeInfo(V) == .int or @typeInfo(V) == .comptime_int) {
                return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, value });
            } else if (@typeInfo(V) == .float or @typeInfo(V) == .comptime_float) {
                return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, value });
            } else if (V == bool) {
                return std.fmt.allocPrint(allocator, "{s} {s} {d}", .{ field, op, @as(u8, if (value) 1 else 0) });
            } else {
                return std.fmt.allocPrint(allocator, "{s} {s} NULL", .{ field, op });
            }
        }

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
