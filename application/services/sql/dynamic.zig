//! 动态 CRUD 模块 - 支持运行时动态表操作
//!
//! 该模块提供：
//! - 动态模型数据结构
//! - 运行时表结构发现
//! - 动态 CRUD 操作
//! - 字段验证

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("interface.zig");
const orm = @import("orm.zig");

// ============================================================================
// 字段值联合类型
// ============================================================================

/// 动态字段值 - 支持多种数据类型
pub const FieldValue = union(enum) {
    null_value: void,
    int_value: i64,
    uint_value: u64,
    float_value: f64,
    string_value: []const u8,
    bool_value: bool,
    blob_value: []const u8,

    /// 转换为 SQL 字符串表示
    pub fn toSql(self: FieldValue, allocator: Allocator) ![]u8 {
        return switch (self) {
            .null_value => try allocator.dupe(u8, "NULL"),
            .int_value => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .uint_value => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .float_value => |v| try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .string_value => |v| blk: {
                const escaped = try orm.escapeSqlString(allocator, v);
                defer allocator.free(escaped);
                break :blk try std.fmt.allocPrint(allocator, "'{s}'", .{escaped});
            },
            .bool_value => |v| try allocator.dupe(u8, if (v) "1" else "0"),
            .blob_value => |v| blk: {
                var result = std.ArrayListUnmanaged(u8){};
                errdefer result.deinit(allocator);
                try result.appendSlice(allocator, "X'");
                for (v) |byte| {
                    try result.writer(allocator).print("{X:0>2}", .{byte});
                }
                try result.append(allocator, '\'');
                break :blk try result.toOwnedSlice(allocator);
            },
        };
    }

    /// 释放字符串内存
    pub fn deinit(self: *FieldValue, allocator: Allocator) void {
        switch (self.*) {
            .string_value => |v| if (v.len > 0) allocator.free(v),
            .blob_value => |v| if (v.len > 0) allocator.free(v),
            else => {},
        }
    }
};

// ============================================================================
// 列信息
// ============================================================================

/// SQL 数据类型
pub const SqlType = enum {
    integer,
    bigint,
    smallint,
    tinyint,
    float_type,
    double_type,
    decimal,
    varchar,
    text,
    longtext,
    blob,
    datetime,
    timestamp,
    date,
    time,
    boolean,
    json,
    unknown,
};

/// 列信息结构
pub const ColumnInfo = struct {
    name: []const u8,
    sql_type: SqlType,
    is_nullable: bool,
    is_primary_key: bool,
    is_auto_increment: bool,
    default_value: ?[]const u8,
    max_length: ?u32,

    pub fn deinit(self: *ColumnInfo, allocator: Allocator) void {
        allocator.free(self.name);
        if (self.default_value) |dv| allocator.free(dv);
    }
};

/// 表结构信息
pub const TableSchema = struct {
    table_name: []const u8,
    columns: []ColumnInfo,
    primary_key: ?[]const u8,

    pub fn deinit(self: *TableSchema, allocator: Allocator) void {
        allocator.free(self.table_name);
        if (self.primary_key) |pk| allocator.free(pk);
        for (self.columns) |*col| {
            col.deinit(allocator);
        }
        allocator.free(self.columns);
    }

    /// 检查字段是否存在
    pub fn hasColumn(self: *const TableSchema, name: []const u8) bool {
        for (self.columns) |col| {
            if (std.mem.eql(u8, col.name, name)) return true;
        }
        return false;
    }

    /// 获取列信息
    pub fn getColumn(self: *const TableSchema, name: []const u8) ?ColumnInfo {
        for (self.columns) |col| {
            if (std.mem.eql(u8, col.name, name)) return col;
        }
        return null;
    }
};

// ============================================================================
// 动态模型
// ============================================================================

/// 动态模型 - 运行时动态字段存储
pub const DynamicModel = struct {
    const Self = @This();

    allocator: Allocator,
    fields: std.StringHashMapUnmanaged(FieldValue),
    schema: ?*const TableSchema,

    pub fn init(allocator: Allocator) DynamicModel {
        return .{
            .allocator = allocator,
            .fields = .{},
            .schema = null,
        };
    }

    pub fn initWithSchema(allocator: Allocator, schema: *const TableSchema) DynamicModel {
        return .{
            .allocator = allocator,
            .fields = .{},
            .schema = schema,
        };
    }

    pub fn deinit(self: *DynamicModel) void {
        var iter = self.fields.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var value = entry.value_ptr.*;
            value.deinit(self.allocator);
        }
        self.fields.deinit(self.allocator);
    }

    /// 设置字段值
    pub fn set(self: *DynamicModel, name: []const u8, value: FieldValue) !void {
        // 如果有 schema，验证字段名
        if (self.schema) |schema| {
            if (!schema.hasColumn(name)) {
                return error.InvalidFieldName;
            }
        }

        // 复制 key
        const key_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key_copy);

        // 复制字符串值
        var value_copy = value;
        switch (value) {
            .string_value => |v| {
                value_copy = .{ .string_value = try self.allocator.dupe(u8, v) };
            },
            .blob_value => |v| {
                value_copy = .{ .blob_value = try self.allocator.dupe(u8, v) };
            },
            else => {},
        }

        // 如果已存在，先释放旧值
        if (self.fields.fetchRemove(name)) |existing| {
            self.allocator.free(existing.key);
            var old_value = existing.value;
            old_value.deinit(self.allocator);
        }

        try self.fields.put(self.allocator, key_copy, value_copy);
    }

    /// 设置字符串值
    pub fn setString(self: *DynamicModel, name: []const u8, value: []const u8) !void {
        try self.set(name, .{ .string_value = value });
    }

    /// 设置整数值
    pub fn setInt(self: *DynamicModel, name: []const u8, value: i64) !void {
        try self.set(name, .{ .int_value = value });
    }

    /// 设置 NULL 值
    pub fn setNull(self: *DynamicModel, name: []const u8) !void {
        try self.set(name, .null_value);
    }

    /// 获取字段值
    pub fn get(self: *const DynamicModel, name: []const u8) ?FieldValue {
        return self.fields.get(name);
    }

    /// 获取字符串值
    pub fn getString(self: *const DynamicModel, name: []const u8) ?[]const u8 {
        if (self.fields.get(name)) |value| {
            return switch (value) {
                .string_value => |v| v,
                else => null,
            };
        }
        return null;
    }

    /// 获取整数值
    pub fn getInt(self: *const DynamicModel, name: []const u8) ?i64 {
        if (self.fields.get(name)) |value| {
            return switch (value) {
                .int_value => |v| v,
                .uint_value => |v| @intCast(v),
                else => null,
            };
        }
        return null;
    }

    /// 检查字段是否存在
    pub fn has(self: *const DynamicModel, name: []const u8) bool {
        return self.fields.contains(name);
    }

    /// 获取所有字段名
    pub fn fieldNames(self: *const DynamicModel, allocator: Allocator) ![][]const u8 {
        var names = std.ArrayListUnmanaged([]const u8){};
        errdefer names.deinit(allocator);

        var iter = self.fields.keyIterator();
        while (iter.next()) |key| {
            try names.append(allocator, key.*);
        }

        return names.toOwnedSlice(allocator);
    }
};

// ============================================================================
// 动态结果集
// ============================================================================

/// 动态查询结果集
pub const DynamicResultSet = struct {
    allocator: Allocator,
    rows: []DynamicModel,

    pub fn deinit(self: *DynamicResultSet) void {
        for (self.rows) |*row| {
            row.deinit();
        }
        self.allocator.free(self.rows);
    }

    pub fn count(self: *const DynamicResultSet) usize {
        return self.rows.len;
    }

    pub fn isEmpty(self: *const DynamicResultSet) bool {
        return self.rows.len == 0;
    }

    pub fn first(self: *const DynamicResultSet) ?*const DynamicModel {
        if (self.rows.len == 0) return null;
        return &self.rows[0];
    }
};

// ============================================================================
// 动态 CRUD 服务
// ============================================================================

/// 动态 CRUD 服务
pub const DynamicCrud = struct {
    const Self = @This();

    allocator: Allocator,
    db: *orm.Database,
    schema_cache: std.StringHashMapUnmanaged(TableSchema),
    allowed_tables: ?[]const []const u8,

    pub fn init(allocator: Allocator, db: *orm.Database) DynamicCrud {
        return .{
            .allocator = allocator,
            .db = db,
            .schema_cache = .{},
            .allowed_tables = null,
        };
    }

    pub fn deinit(self: *DynamicCrud) void {
        var iter = self.schema_cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var schema = entry.value_ptr.*;
            schema.deinit(self.allocator);
        }
        self.schema_cache.deinit(self.allocator);
    }

    /// 设置允许的表名白名单
    pub fn setAllowedTables(self: *DynamicCrud, tables: []const []const u8) void {
        self.allowed_tables = tables;
    }

    /// 检查表名是否允许
    pub fn isTableAllowed(self: *const DynamicCrud, table_name: []const u8) bool {
        if (self.allowed_tables) |tables| {
            for (tables) |allowed| {
                if (std.mem.eql(u8, allowed, table_name)) return true;
            }
            return false;
        }
        return true; // 没有白名单则允许所有
    }

    /// 发现表结构 (MySQL)
    pub fn discoverSchema(self: *DynamicCrud, table_name: []const u8) !TableSchema {
        // 检查白名单
        if (!self.isTableAllowed(table_name)) {
            return error.TableNotAllowed;
        }

        // 检查缓存
        if (self.schema_cache.get(table_name)) |cached| {
            return cached;
        }

        // 查询表结构
        const sql_query = try std.fmt.allocPrint(self.allocator,
            \\SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_KEY, EXTRA, COLUMN_DEFAULT, CHARACTER_MAXIMUM_LENGTH
            \\FROM INFORMATION_SCHEMA.COLUMNS
            \\WHERE TABLE_NAME = '{s}' AND TABLE_SCHEMA = DATABASE()
            \\ORDER BY ORDINAL_POSITION
        , .{table_name});
        defer self.allocator.free(sql_query);

        var result = try self.db.rawQuery(sql_query);
        defer result.deinit();

        var columns = std.ArrayListUnmanaged(ColumnInfo){};
        errdefer {
            for (columns.items) |*col| col.deinit(self.allocator);
            columns.deinit(self.allocator);
        }

        var primary_key: ?[]const u8 = null;

        while (result.next()) |row| {
            const col_name = row.values[0] orelse continue;
            const data_type = row.values[1] orelse "varchar";
            const is_nullable = if (row.values[2]) |v| std.mem.eql(u8, v, "YES") else true;
            const col_key = row.values[3];
            const extra = row.values[4];
            const default_val = row.values[5];
            const max_len_str = row.values[6];

            const is_pk = if (col_key) |k| std.mem.eql(u8, k, "PRI") else false;
            const is_auto = if (extra) |e| std.mem.indexOf(u8, e, "auto_increment") != null else false;

            if (is_pk) {
                primary_key = try self.allocator.dupe(u8, col_name);
            }

            const sql_type = parseSqlType(data_type);
            const max_len: ?u32 = if (max_len_str) |s| std.fmt.parseInt(u32, s, 10) catch null else null;

            try columns.append(self.allocator, .{
                .name = try self.allocator.dupe(u8, col_name),
                .sql_type = sql_type,
                .is_nullable = is_nullable,
                .is_primary_key = is_pk,
                .is_auto_increment = is_auto,
                .default_value = if (default_val) |dv| try self.allocator.dupe(u8, dv) else null,
                .max_length = max_len,
            });
        }

        if (columns.items.len == 0) {
            return error.TableNotFound;
        }

        const schema = TableSchema{
            .table_name = try self.allocator.dupe(u8, table_name),
            .columns = try columns.toOwnedSlice(self.allocator),
            .primary_key = primary_key,
        };

        // 缓存
        const key_copy = try self.allocator.dupe(u8, table_name);
        try self.schema_cache.put(self.allocator, key_copy, schema);

        return schema;
    }

    /// 动态 SELECT
    pub fn select(self: *DynamicCrud, table_name: []const u8, options: SelectOptions) !DynamicResultSet {
        if (!self.isTableAllowed(table_name)) return error.TableNotAllowed;

        var sql = std.ArrayListUnmanaged(u8){};
        defer sql.deinit(self.allocator);

        try sql.appendSlice(self.allocator, "SELECT * FROM ");
        try sql.appendSlice(self.allocator, table_name);

        if (options.where) |where_clause| {
            try sql.appendSlice(self.allocator, " WHERE ");
            try sql.appendSlice(self.allocator, where_clause);
        }

        if (options.order_by) |order| {
            try sql.appendSlice(self.allocator, " ORDER BY ");
            try sql.appendSlice(self.allocator, order);
        }

        if (options.limit) |limit| {
            try sql.writer(self.allocator).print(" LIMIT {d}", .{limit});
        }

        if (options.offset) |offset| {
            try sql.writer(self.allocator).print(" OFFSET {d}", .{offset});
        }

        var result = try self.db.rawQuery(sql.items);
        defer result.deinit();

        return self.mapToDynamicModels(&result);
    }

    /// 动态 INSERT
    pub fn insert(self: *DynamicCrud, table_name: []const u8, model: *const DynamicModel) !u64 {
        if (!self.isTableAllowed(table_name)) return error.TableNotAllowed;

        var sql = std.ArrayListUnmanaged(u8){};
        defer sql.deinit(self.allocator);

        try sql.appendSlice(self.allocator, "INSERT INTO ");
        try sql.appendSlice(self.allocator, table_name);
        try sql.appendSlice(self.allocator, " (");

        var values_sql = std.ArrayListUnmanaged(u8){};
        defer values_sql.deinit(self.allocator);

        var first = true;
        var iter = model.fields.iterator();
        while (iter.next()) |entry| {
            if (!first) {
                try sql.appendSlice(self.allocator, ", ");
                try values_sql.appendSlice(self.allocator, ", ");
            }
            first = false;

            try sql.appendSlice(self.allocator, entry.key_ptr.*);

            const value_str = try entry.value_ptr.toSql(self.allocator);
            defer self.allocator.free(value_str);
            try values_sql.appendSlice(self.allocator, value_str);
        }

        try sql.appendSlice(self.allocator, ") VALUES (");
        try sql.appendSlice(self.allocator, values_sql.items);
        try sql.append(self.allocator, ')');

        _ = try self.db.rawExec(sql.items, .{});
        return self.db.lastInsertId();
    }

    /// 动态 UPDATE
    pub fn update(self: *DynamicCrud, table_name: []const u8, id: anytype, model: *const DynamicModel) !u64 {
        if (!self.isTableAllowed(table_name)) return error.TableNotAllowed;

        var sql = std.ArrayListUnmanaged(u8){};
        defer sql.deinit(self.allocator);

        try sql.appendSlice(self.allocator, "UPDATE ");
        try sql.appendSlice(self.allocator, table_name);
        try sql.appendSlice(self.allocator, " SET ");

        var first = true;
        var iter = model.fields.iterator();
        while (iter.next()) |entry| {
            if (!first) try sql.appendSlice(self.allocator, ", ");
            first = false;

            try sql.appendSlice(self.allocator, entry.key_ptr.*);
            try sql.appendSlice(self.allocator, " = ");

            const value_str = try entry.value_ptr.toSql(self.allocator);
            defer self.allocator.free(value_str);
            try sql.appendSlice(self.allocator, value_str);
        }

        try sql.writer(self.allocator).print(" WHERE id = {d}", .{id});

        return try self.db.rawExec(sql.items, .{});
    }

    /// 动态 DELETE
    pub fn delete(self: *DynamicCrud, table_name: []const u8, id: anytype) !u64 {
        if (!self.isTableAllowed(table_name)) return error.TableNotAllowed;

        const sql_query = try std.fmt.allocPrint(self.allocator, "DELETE FROM {s} WHERE id = {d}", .{ table_name, id });
        defer self.allocator.free(sql_query);

        return try self.db.rawExec(sql_query, .{});
    }

    /// 批量删除
    pub fn deleteMany(self: *DynamicCrud, table_name: []const u8, ids: []const i64) !u64 {
        if (!self.isTableAllowed(table_name)) return error.TableNotAllowed;
        if (ids.len == 0) return 0;

        var sql = std.ArrayListUnmanaged(u8){};
        defer sql.deinit(self.allocator);

        try sql.appendSlice(self.allocator, "DELETE FROM ");
        try sql.appendSlice(self.allocator, table_name);
        try sql.appendSlice(self.allocator, " WHERE id IN (");

        for (ids, 0..) |id, i| {
            if (i > 0) try sql.appendSlice(self.allocator, ", ");
            try sql.writer(self.allocator).print("{d}", .{id});
        }

        try sql.append(self.allocator, ')');

        return try self.db.rawExec(sql.items, .{});
    }

    /// 将结果集映射为动态模型
    fn mapToDynamicModels(self: *DynamicCrud, result: *interface.ResultSet) !DynamicResultSet {
        var rows = std.ArrayListUnmanaged(DynamicModel){};
        errdefer {
            for (rows.items) |*row| row.deinit();
            rows.deinit(self.allocator);
        }

        while (result.next()) |row| {
            var model = DynamicModel.init(self.allocator);
            errdefer model.deinit();

            for (result.field_names, 0..) |col_name, i| {
                if (i < row.values.len) {
                    if (row.values[i]) |value| {
                        try model.setString(col_name, value);
                    } else {
                        try model.setNull(col_name);
                    }
                }
            }

            try rows.append(self.allocator, model);
        }

        return DynamicResultSet{
            .allocator = self.allocator,
            .rows = try rows.toOwnedSlice(self.allocator),
        };
    }

    /// SELECT 选项
    pub const SelectOptions = struct {
        where: ?[]const u8 = null,
        order_by: ?[]const u8 = null,
        limit: ?u32 = null,
        offset: ?u32 = null,
    };
};

/// 解析 SQL 类型字符串
fn parseSqlType(type_str: []const u8) SqlType {
    const lower = type_str; // MySQL 返回小写
    if (std.mem.startsWith(u8, lower, "int")) return .integer;
    if (std.mem.startsWith(u8, lower, "bigint")) return .bigint;
    if (std.mem.startsWith(u8, lower, "smallint")) return .smallint;
    if (std.mem.startsWith(u8, lower, "tinyint")) return .tinyint;
    if (std.mem.startsWith(u8, lower, "float")) return .float_type;
    if (std.mem.startsWith(u8, lower, "double")) return .double_type;
    if (std.mem.startsWith(u8, lower, "decimal")) return .decimal;
    if (std.mem.startsWith(u8, lower, "varchar")) return .varchar;
    if (std.mem.eql(u8, lower, "text")) return .text;
    if (std.mem.eql(u8, lower, "longtext")) return .longtext;
    if (std.mem.startsWith(u8, lower, "blob")) return .blob;
    if (std.mem.eql(u8, lower, "datetime")) return .datetime;
    if (std.mem.eql(u8, lower, "timestamp")) return .timestamp;
    if (std.mem.eql(u8, lower, "date")) return .date;
    if (std.mem.eql(u8, lower, "time")) return .time;
    if (std.mem.eql(u8, lower, "json")) return .json;
    return .unknown;
}

// ============================================================================
// 测试
// ============================================================================

test "DynamicModel basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var model = DynamicModel.init(allocator);
    defer model.deinit();

    try model.setString("name", "test");
    try model.setInt("age", 25);
    try model.setNull("deleted_at");

    try std.testing.expect(model.has("name"));
    try std.testing.expect(model.has("age"));
    try std.testing.expectEqualStrings("test", model.getString("name").?);
    try std.testing.expectEqual(@as(i64, 25), model.getInt("age").?);
}

test "FieldValue toSql" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const null_sql = try FieldValue.null_value.toSql(allocator);
    defer allocator.free(null_sql);
    try std.testing.expectEqualStrings("NULL", null_sql);

    const int_sql = try (FieldValue{ .int_value = 42 }).toSql(allocator);
    defer allocator.free(int_sql);
    try std.testing.expectEqualStrings("42", int_sql);

    const str_sql = try (FieldValue{ .string_value = "hello" }).toSql(allocator);
    defer allocator.free(str_sql);
    try std.testing.expectEqualStrings("'hello'", str_sql);
}
