//! 模型字段绑定解析器
//!
//! 自动处理模型字段的序列化和反序列化：
//! - JsonField 自动序列化为 JSON 字符串
//! - JsonArray 自动序列化为 JSON 数组字符串
//! - 嵌套结构体自动处理
//!
//! ## 使用示例
//!
//! ```zig
//! const binding = @import("field_binding.zig");
//!
//! // 定义带 JSON 字段的模型
//! const UserProfile = struct {
//!     id: u64,
//!     name: []const u8,
//!     metadata: json.JsonField(Metadata),
//!     tags: json.JsonArray([]const u8),
//! };
//!
//! // 自动解析模型字段
//! const fields = try binding.extractFields(UserProfile, allocator);
//! defer fields.deinit();
//!
//! // 自动序列化用于 INSERT/UPDATE
//! const sql_fields = try binding.toInsertFields(UserProfile, allocator, &profile);
//! defer sql_fields.deinit();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = @import("json_field.zig");

// ============================================================================
// 字段信息
// ============================================================================

/// 字段类型
pub const FieldType = enum {
    string,
    int,
    float,
    bool,
    json_field,
    json_array,
    unknown,
};

/// 字段信息
pub const FieldInfo = struct {
    name: []const u8,
    field_type: FieldType,
    /// 对于 JSON 字段，存储内部类型名
    json_child_type: ?[]const u8 = null,
    /// 字段在结构体中的索引
    index: usize,
};

/// 模型字段集合
pub const ModelFields = struct {
    allocator: Allocator,
    fields: std.ArrayListUnmanaged(FieldInfo),

    pub fn init(allocator: Allocator) ModelFields {
        return .{
            .allocator = allocator,
            .fields = .{},
        };
    }

    pub fn deinit(self: *ModelFields) void {
        for (self.fields.items) |field| {
            self.allocator.free(field.name);
            if (field.json_child_type) |t| {
                self.allocator.free(t);
            }
        }
        self.fields.deinit(self.allocator);
    }

    pub fn append(self: *ModelFields, info: FieldInfo) !void {
        try self.fields.append(self.allocator, info);
    }

    pub fn count(self: *const ModelFields) usize {
        return self.fields.items.len;
    }

    pub fn items(self: *const ModelFields) []const FieldInfo {
        return self.fields.items;
    }
};

// ============================================================================
// 字段类型检测
// ============================================================================

/// 检测字段类型
pub fn detectFieldType(comptime T: type) FieldType {
    // 检查是否是 JsonField 类型
    if (comptime isJsonField(T)) {
        return .json_field;
    }

    // 检查是否是 JsonArray 类型
    if (comptime isJsonArray(T)) {
        return .json_array;
    }

    const info = @typeInfo(T);
    return switch (info) {
        .pointer => |p| if (p.size == .slice and p.child == u8) FieldType.string else FieldType.unknown,
        .int, .comptime_int => FieldType.int,
        .float, .comptime_float => FieldType.float,
        .bool => FieldType.bool,
        else => FieldType.unknown,
    };
}

/// 检查类型是否为 JsonField
fn isJsonField(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Struct) return false;
    // 检查是否有 JsonField 特征方法
    return @hasDecl(T, "toSqlString") and @hasDecl(T, "get");
}

/// 检查类型是否为 JsonArray
fn isJsonArray(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Struct) return false;
    // 检查是否有 JsonArray 特征
    return @hasDecl(T, "json_data") and @hasDecl(T, "get") and !@hasDecl(T, "toSqlString");
}

/// 获取 JsonField 的内部类型名
fn getJsonFieldChildTypeName(comptime T: type) ?[]const u8 {
    // 通过编译时反射获取类型信息
    // 由于无法直接获取泛型参数，使用类型名作为标识
    const type_name = @typeName(T);
    // 尝试从类型名提取内部类型
    // JsonField(Metadata) -> Metadata
    if (std.mem.indexOf(u8, type_name, "(")) |idx| {
        const start = idx + 1;
        const end = std.mem.lastIndexOf(u8, type_name, ")") orelse type_name.len;
        if (start < end) {
            return type_name[start..end];
        }
    }
    return null;
}

// ============================================================================
// 字段提取
// ============================================================================

/// 从模型类型提取所有字段信息
pub fn extractModelFields(comptime T: type, allocator: Allocator) !ModelFields {
    var fields = ModelFields.init(allocator);
    errdefer fields.deinit();

    const type_info = @typeInfo(T);
    if (type_info != .Struct) return fields;

    inline for (type_info.@"struct".fields, 0..) |field, idx| {
        const field_type = detectFieldType(field.type);

        const name = try allocator.dupe(u8, field.name);
        errdefer allocator.free(name);

        const info = FieldInfo{
            .name = name,
            .field_type = field_type,
            .json_child_type = if (field_type == .json_field or field_type == .json_array)
                getJsonFieldChildTypeName(field.type) else null,
            .index = idx,
        };

        try fields.append(info);
    }

    return fields;
}

// ============================================================================
// 序列化/反序列化
// ============================================================================

/// 将模型实例序列化为数据库字段映射
///
/// 返回的 Map 中：
/// - 普通字段：直接存储值
/// - JsonField：自动序列化为 JSON 字符串
pub fn serializeModel(
    comptime T: type,
    allocator: Allocator,
    model: *const T,
) !std.StringHashMapUnmanaged([]const u8) {
    var result = std.StringHashMapUnmanaged([]const u8).init(allocator);
    errdefer result.deinit();

    const type_info = @typeInfo(T);
    if (type_info != .Struct) return result;

    inline for (type_info.@"struct".fields) |field| {
        const field_type = detectFieldType(field.type);
        const value = @field(model, field.name);

        const sql_value = try serializeFieldValue(field.type, field_type, allocator, value);
        errdefer {
            if (sql_value.ptr != @as([*]const u8, @ptrFromInt(0))) {
                allocator.free(sql_value);
            }
        }

        const name = try allocator.dupe(u8, field.name);
        errdefer allocator.free(name);

        try result.put(allocator, name, sql_value);
    }

    return result;
}

/// 序列化单个字段值
fn serializeFieldValue(
    comptime T: type,
    field_type: FieldType,
    allocator: Allocator,
    value: T,
) ![]const u8 {
    return switch (field_type) {
        .string => try allocator.dupe(u8, value),
        .int => try std.fmt.allocPrint(allocator, "{d}", .{value}),
        .float => try std.fmt.allocPrint(allocator, "{d}", .{value}),
        .bool => try allocator.dupe(u8, if (value) "1" else "0"),
        .json_field => blk: {
            const jf = &@as(T, value);
            const sql_str = try jf.toSqlString(allocator);
            break :blk sql_str;
        },
        .json_array => blk: {
            const ja = &@as(T, value);
            const sql_str = try ja.toSqlString(allocator);
            break :blk sql_str;
        },
        .unknown => try allocator.dupe(u8, ""),
    };
}

/// 释放序列化结果
pub fn freeSerializedResult(
    allocator: Allocator,
    result: *std.StringHashMapUnmanaged([]const u8),
) void {
    var it = result.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    result.deinit(allocator);
}

// ============================================================================
// 构建 SQL
// ============================================================================

/// 构建 INSERT 语句的字段列表
pub fn buildInsertFields(comptime T: type, allocator: Allocator, model: *const T) !InsertFields {
    var fields = std.ArrayListUnmanaged([]const u8){};
    var values = std.ArrayListUnmanaged([]const u8){};
    errdefer fields.deinit(allocator);
    errdefer {
        for (values.items) |v| allocator.free(v);
        values.deinit(allocator);
    }

    const type_info = @typeInfo(T);
    if (type_info == .Struct) {
        inline for (type_info.@"struct".fields) |field| {
            const field_type = detectFieldType(field.type);
            const value = @field(model, field.name);

            const field_name = try allocator.dupe(u8, field.name);
            errdefer allocator.free(field_name);
            try fields.append(allocator, field_name);

            const sql_value = try serializeFieldValue(field.type, field_type, allocator, value);
            try values.append(allocator, sql_value);
        }
    }

    return .{
        .allocator = allocator,
        .fields = fields,
        .values = values,
    };
}

/// INSERT 字段和值
pub const InsertFields = struct {
    allocator: Allocator,
    fields: std.ArrayListUnmanaged([]const u8),
    values: std.ArrayListUnmanaged([]const u8),

    pub fn deinit(self: *InsertFields) void {
        for (self.fields.items) |f| self.allocator.free(f);
        for (self.values.items) |v| self.allocator.free(v);
        self.fields.deinit(self.allocator);
        self.values.deinit(self.allocator);
    }

    pub fn toSql(self: *const InsertFields) ![]const u8 {
        var sql = std.ArrayListUnmanaged(u8){};
        errdefer sql.deinit(self.allocator);

        try sql.appendSlice(self.allocator, "INSERT INTO table (");

        for (self.fields.items, 0..) |field, i| {
            if (i > 0) try sql.appendSlice(self.allocator, ", ");
            try sql.appendSlice(self.allocator, field);
        }

        try sql.appendSlice(self.allocator, ") VALUES (");

        for (self.values.items, 0..) |value, i| {
            if (i > 0) try sql.appendSlice(self.allocator, ", ");
            try sql.appendSlice(self.allocator, value);
        }

        try sql.appendSlice(self.allocator, ")");

        return sql.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// 从 ResultSet 加载
// ============================================================================

/// 从数据库结果创建模型实例
///
/// 自动处理：
/// - 普通字段直接赋值
/// - JsonField 自动从 JSON 字符串反序列化
pub fn loadModelFromResult(
    comptime T: type,
    allocator: Allocator,
    // field_names: []const []const u8, // 保留用于将来实现列名映射
    row_values: []const ?[]const u8,
) !T {
    var model: T = undefined;

    const type_info = @typeInfo(T);
    if (type_info != .Struct) return model;

    // 创建字段名到索引的映射
    var field_map: std.StringHashMapUnmanaged(usize) = .{};
    defer field_map.deinit(allocator);

    inline for (type_info.@"struct".fields, 0..) |field, idx| {
        field_map.put(allocator, field.name, idx) catch {};
    }

    // 填充字段值
    inline for (type_info.@"struct".fields) |field| {
        const field_type = detectFieldType(field.type);
        const field_idx = field_map.get(field.name) orelse @as(usize, 0);

        const db_value = if (field_idx < row_values.len) row_values[field_idx] else null;

        try setModelField(&model, field, field_type, allocator, db_value);
    }

    return model;
}

/// 设置模型字段值（处理类型转换和 JSON 反序列化）
fn setModelField(
    model: anytype,
    comptime field: std.builtin.Type.StructField,
    field_type: FieldType,
    allocator: Allocator,
    db_value: ?[]const u8,
) !void {
    switch (field_type) {
        .string => {
            @field(model, field.name) = if (db_value) |v| try allocator.dupe(u8, v) else "";
        },
        .int => {
            if (db_value) |v| {
                @field(model, field.name) = std.fmt.parseInt(field.type, v, 10) catch 0;
            } else {
                @field(model, field.name) = 0;
            }
        },
        .float => {
            if (db_value) |v| {
                @field(model, field.name) = std.fmt.parseFloat(field.type, v) catch 0.0;
            } else {
                @field(model, field.name) = 0.0;
            }
        },
        .bool => {
            @field(model, field.name) = if (db_value) |v| std.mem.eql(u8, v, "1") else false;
        },
        .json_field => {
            if (db_value) |v| {
                const owned = try allocator.dupe(u8, v);
                @field(model, field.name) = try json.JsonField(field.type).fromJson(owned, allocator);
            } else {
                @field(model, field.name) = json.JsonField(field.type).empty();
            }
        },
        .json_array => {
            if (db_value) |v| {
                const owned = try allocator.dupe(u8, v);
                @field(model, field.name) = try json.JsonArray(field.type).fromJson(owned, allocator);
            } else {
                @field(model, field.name) = json.JsonArray(field.type).empty();
            }
        },
        .unknown => {
            // 使用默认值
            @field(model, field.name) = undefined;
        },
    }
}

// ============================================================================
// 测试
// ============================================================================

test "FieldBinding - 检测字段类型" {
    // 基本类型
    try std.testing.expectEqual(FieldType.string, detectFieldType([]const u8));
    try std.testing.expectEqual(FieldType.int, detectFieldType(u32));
    try std.testing.expectEqual(FieldType.float, detectFieldType(f64));
    try std.testing.expectEqual(FieldType.bool, detectFieldType(bool));
}

test "FieldBinding - 提取模型字段" {
    const TestModel = struct {
        id: u64,
        name: []const u8,
        age: u32,
        active: bool,
    };

    const allocator = std.testing.allocator;
    const fields = try extractModelFields(TestModel, allocator);
    defer fields.deinit();

    try std.testing.expectEqual(@as(usize, 4), fields.count());
}

test "FieldBinding - 序列化模型" {
    const TestModel = struct {
        id: u64,
        name: []const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const model = TestModel{
        .id = 1,
        .name = "测试用户",
    };

    const serialized = try serializeModel(TestModel, allocator, &model);
    defer freeSerializedResult(allocator, &serialized);

    try std.testing.expect(serialized.contains("id"));
    try std.testing.expect(serialized.contains("name"));
}
