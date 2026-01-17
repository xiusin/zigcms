//! JSON 字段支持模块
//!
//! 提供完整的 JSON 字段支持：
//! - JsonField 类型 - 用于模型定义
//! - 自动序列化和反序列化
//! - JSON 查询支持（PostgreSQL JSONB）
//! - 复杂结构体嵌套支持
//!
//! ## 使用示例
//!
//! ```zig
//! const json = @import("services").sql.json;
//!
//! // 定义带 JSON 字段的模型
//! const UserProfile = struct {
//!     id: u64,
//!     name: []const u8,
//!     metadata: json.JsonField(Metadata),
//! };
//!
//! const Metadata = struct {
//!     avatar: []const u8,
//!     bio: ?[]const u8,
//!     socials: []SocialLink,
//! };
//!
//! const SocialLink = struct {
//!     platform: []const u8,
//!     url: []const u8,
//! };
//!
//! // 使用
//! const user = try User.find(1);
//! if (user.metadata.get()) |meta| {
//!     std.debug.print("Avatar: {s}\n", .{meta.avatar});
//!     std.debug.print("Bio: {s}\n", .{meta.bio});
//! }
//!
//! // JSON 查询（PostgreSQL）
//! const users = try User.query()
//!     .whereJson("metadata", "->", "avatar", "=", "https://...")
//!     .get();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// JSON 字段类型
// ============================================================================

/// JSON 字段封装类型
///
/// 自动处理序列化和反序列化，存储为 JSON 字符串
pub fn JsonField(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 内部存储的 JSON 字符串（数据库存储格式）
        json_data: ?[]const u8,
        /// 指向外部分配器的引用（用于解析）
        allocator: ?*Allocator,
        /// 缓存的解析结果
        cached: ?T,
        /// 是否已修改
        dirty: bool,

        /// 创建空的 JSON 字段
        pub fn empty() Self {
            return Self{
                .json_data = null,
                .allocator = null,
                .cached = null,
                .dirty = false,
            };
        }

        /// 从值创建 JSON 字段
        pub fn from(value: T, allocator: *Allocator) !Self {
            const json_str = try serialize(T, allocator, value);
            return Self{
                .json_data = json_str,
                .allocator = allocator,
                .cached = value,
                .dirty = false,
            };
        }

        /// 从 JSON 字符串创建（数据库加载时使用）
        pub fn fromJson(json_str: []const u8, allocator: *Allocator) !Self {
            const value = try deserialize(T, allocator, json_str);
            return Self{
                .json_data = json_str,
                .allocator = allocator,
                .cached = value,
                .dirty = false,
            };
        }

        /// 获取解析后的值
        pub fn get(self: *Self) ?T {
            return self.cached;
        }

        /// 获取解析后的值的常量引用
        pub fn getConst(self: *const Self) ?T {
            return self.cached;
        }

        /// 设置新值
        pub fn set(self: *Self, value: T) void {
            self.cached = value;
            self.dirty = true;
        }

        /// 检查是否为空
        pub fn isNull(self: *const Self) bool {
            return self.json_data == null;
        }

        /// 获取 JSON 字符串（用于数据库存储）
        /// 如果有缓存且被修改，重新序列化
        pub fn toSqlString(self: *Self, allocator: Allocator) ![]const u8 {
            if (self.dirty) {
                if (self.cached) |value| {
                    const json_str = try serialize(T, allocator, value);
                    if (self.json_data) |old| {
                        allocator.free(old);
                    }
                    self.json_data = json_str;
                    self.dirty = false;
                }
            }
            return self.json_data orelse "null";
        }

        /// 释放资源
        pub fn deinit(self: *Self) void {
            // 释放 JSON 字符串
            if (self.json_data) |data| {
                if (self.allocator) |alloc| {
                    alloc.free(data);
                }
            }
            // 释放缓存的值
            if (self.cached) |value| {
                freeValue(T, self.allocator orelse undefined, value);
            }
            self.json_data = null;
            self.cached = null;
            self.allocator = null;
        }
    };
}

/// JSON 数组字段类型
pub fn JsonArray(comptime T: type) type {
    return struct {
        const Self = @This();

        json_data: ?[]const u8,
        allocator: ?*Allocator,
        cached: ?[]T,
        dirty: bool,

        pub fn empty() Self {
            return Self{
                .json_data = null,
                .allocator = null,
                .cached = null,
                .dirty = false,
            };
        }

        pub fn from(values: []const T, allocator: *Allocator) !Self {
            const json_str = try serializeSlice(T, allocator, values);
            return Self{
                .json_data = json_str,
                .allocator = allocator,
                .cached = values,
                .dirty = false,
            };
        }

        pub fn fromJson(json_str: []const u8, allocator: *Allocator) !Self {
            const values = try deserializeSlice(T, allocator, json_str);
            return Self{
                .json_data = json_str,
                .allocator = allocator,
                .cached = values,
                .dirty = false,
            };
        }

        pub fn get(self: *Self) ?[]T {
            return self.cached;
        }

        pub fn set(self: *Self, values: []const T) void {
            self.cached = values;
            self.dirty = true;
        }

        pub fn isNull(self: *const Self) bool {
            return self.json_data == null;
        }

        pub fn toSqlString(self: *Self, allocator: Allocator) ![]const u8 {
            if (self.dirty) {
                if (self.cached) |values| {
                    const json_str = try serializeSlice(T, allocator, values);
                    if (self.json_data) |old| {
                        allocator.free(old);
                    }
                    self.json_data = json_str;
                    self.dirty = false;
                }
            }
            return self.json_data orelse "[]";
        }

        pub fn deinit(self: *Self) void {
            if (self.json_data) |data| {
                if (self.allocator) |alloc| {
                    alloc.free(data);
                }
            }
            if (self.cached) |values| {
                for (values) |value| {
                    freeValue(T, self.allocator orelse undefined, value);
                }
                if (self.allocator) |alloc| {
                    alloc.free(values);
                }
            }
            self.json_data = null;
            self.cached = null;
            self.allocator = null;
        }
    };
}

// ============================================================================
// 序列化/反序列化
// ============================================================================

/// 序列化 T 为 JSON 字节数组
pub fn serialize(comptime T: type, allocator: Allocator, value: anytype) ![]u8 {
    _ = T; // 用于类型推断
    var list = std.ArrayList(u8).initCapacity(allocator, 512);
    errdefer list.deinit();
    try std.json.stringify(list.writer(), value, .{});
    return list.toOwnedSlice();
}

/// 反序列化 JSON 字节数组为 T
pub fn deserialize(comptime T: type, allocator: Allocator, data: []const u8) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, data, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// 序列化数组为 JSON 字节数组
pub fn serializeSlice(comptime T: type, allocator: Allocator, slice: []const T) ![]u8 {
    var list = std.ArrayList(u8).initCapacity(allocator, 1024);
    errdefer list.deinit();
    try list.append('[');
    for (slice, 0..) |item, i| {
        if (i > 0) try list.append(',');
        try std.json.stringify(list.writer(), item, .{});
    }
    try list.append(']');
    return list.toOwnedSlice();
}

/// 反序列化 JSON 字节数组为 T 数组
pub fn deserializeSlice(comptime T: type, allocator: Allocator, data: []const u8) ![]T {
    const Value = std.json.Value;
    const parsed = try std.json.parseFromSlice(Value, allocator, data, .{});
    defer parsed.deinit();

    if (parsed.value != .array) {
        return error.InvalidJsonArray;
    }

    const json_array = parsed.value.array;
    var result = std.ArrayList(T).init(allocator);
    errdefer {
        for (result.items) |item| {
            freeValue(T, allocator, item);
        }
        result.deinit();
    }

    for (json_array.items) |json_value| {
        const item = try jsonValueToType(T, allocator, json_value);
        try result.append(item);
    }

    return result.toOwnedSlice();
}

// ============================================================================
// 内存管理
// ============================================================================

/// 释放 JSON 值占用的内存
pub fn freeValue(comptime T: type, allocator: Allocator, value: T) void {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |s| {
            inline for (s.fields) |field| {
                freeFieldValue(field.type, allocator, @field(value, field.name));
            }
        },
        .Array => |a| {
            for (value) |item| {
                freeFieldValue(a.child, allocator, item);
            }
        },
        .Pointer => |p| {
            if (p.size == .Slice) {
                allocator.free(value);
            }
        },
        .Optional => |o| {
            if (value) |v| {
                freeFieldValue(o.child, allocator, v);
            }
        },
        else => {},
    }
}

/// 释放字段值
fn freeFieldValue(comptime T: type, allocator: Allocator, value: T) void {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |s| {
            inline for (s.fields) |field| {
                freeFieldValue(field.type, allocator, @field(value, field.name));
            }
        },
        .Array => |a| {
            for (value) |item| {
                freeFieldValue(a.child, allocator, item);
            }
        },
        .Pointer => |p| {
            if (p.size == .Slice) {
                allocator.free(value);
            }
        },
        .Optional => |o| {
            if (value) |v| {
                freeFieldValue(o.child, allocator, v);
            }
        },
        else => {},
    }
}

/// 将 JSON 值转换为指定类型
fn jsonValueToType(comptime T: type, allocator: Allocator, value: std.json.Value) !T {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => {
            if (value != .object) return error.InvalidJsonType;
            var result: T = undefined;
            const fields = info.Struct.fields;
            inline for (fields) |field| {
                const field_value = value.object.get(field.name) orelse .null;
                @field(result, field.name) = try jsonValueToType(field.type, allocator, field_value);
            }
            return result;
        },
        .Int, .Float => {
            if (value == .integer) return @as(T, @intCast(value.integer));
            if (value == .float) return @as(T, @floatCast(value.float));
            if (value == .null) return if (info == .Int) @as(T, 0) else @as(T, 0.0);
            return error.InvalidJsonType;
        },
        .Bool => {
            if (value == .bool) return value.bool;
            return false;
        },
        .Pointer => |p| {
            if (p.size == .Slice and p.child == u8) {
                if (value == .string) {
                    return try allocator.dupe(u8, value.string);
                }
                if (value == .null) {
                    return if (p.is_const) "" else try allocator.dupe(u8, "");
                }
                return error.InvalidJsonType;
            }
            // 支持固定数组
            if (p.size == .One and info == .Array) {
                if (value == .string) {
                    const slice = try allocator.dupe(u8, value.string);
                    const arr = try allocator.create([info.array.len]u8);
                    @memcpy(arr.*[0..], slice[0..info.array.len]);
                    allocator.free(slice);
                    return arr.*;
                }
            }
            return error.UnsupportedPointerType;
        },
        .Optional => |o| {
            if (value == .null) return null;
            return try jsonValueToType(o.child, allocator, value);
        },
        .Array => |a| {
            if (value != .array) return error.InvalidJsonType;
            var result: [a.len]a.child = undefined;
            const json_array = value.array;
            if (json_array.items.len != a.len) return error.ArrayLengthMismatch;
            for (json_array.items, 0..) |json_val, i| {
                result[i] = try jsonValueToType(a.child, allocator, json_val);
            }
            return result;
        },
        .Union => |u| {
            if (value != .object) return error.InvalidJsonType;
            // 尝试匹配字段名
            const field_name = value.object.keys()[0];
            inline for (u.fields, 0..) |f, i| {
                if (std.mem.eql(u8, f.name, field_name)) {
                    _ = value.object.get(field_name) orelse .null; // 验证字段存在
                    return @as(T, @enumFromInt(i));
                }
            }
            return error.InvalidUnionTag;
        },
        else => return error.UnsupportedType,
    }
}

// ============================================================================
// JSON 查询构建器（用于 PostgreSQL JSONB）
// ============================================================================

/// JSON 操作符
pub const JsonOperator = enum {
    /// -> 返回 JSON 对象
    extract_object,
    /// ->> 返回 JSON 字符串
    extract_text,
    /// #> 路径提取
    path_extract,
    /// #>> 路径文本提取
    path_text,
    /// @> 包含
    contains,
    /// <@ 被包含
    contained_by,
    /// ? 存在键
    exists_key,
    /// ?| 存在任一键
    exists_any_key,
    /// ?& 存在所有键
    exists_all_keys,
};

/// JSON 查询条件
pub const JsonCondition = struct {
    field: []const u8,
    json_field: []const u8,
    op: JsonOperator,
    path: ?[]const u8 = null,
    value: ?[]const u8 = null,
};

/// 生成 JSON 查询 SQL
pub fn buildJsonSql(allocator: Allocator, condition: JsonCondition) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    // 构建 JSON 路径表达式
    const json_expr = blk: {
        if (condition.path) |path| {
            // 使用 #> 或 #>> 运算符
            const op_str = if (condition.op == .path_extract) "#>" else "#>>";
            break :blk try std.fmt.allocPrint(allocator, "({s} {s} '{s}')", .{
                condition.field, op_str, path,
            });
        } else {
            // 使用 -> 或 ->> 运算符
            const op_str = if (condition.op == .extract_object) "->" else "->>";
            break :blk try std.fmt.allocPrint(allocator, "({s} {s} '{s}')", .{
                condition.field, op_str, condition.json_field,
            });
        }
    };
    defer allocator.free(json_expr);

    // 构建完整条件
    if (condition.value) |val| {
        const cmp_op = if (condition.op == .extract_text) "=" else "::text =";
        try std.fmt.listPrint(&result, "{} {} '{}'", .{ json_expr, cmp_op, val });
    } else {
        // 只检查 JSON 结构
        try result.appendSlice(json_expr);
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 检查类型是否为 JsonField
pub fn isJsonField(comptime T: type) bool {
    // 检查是否是 JsonField 封装类型
    const info = @typeInfo(T);
    if (info != .Struct) return false;
    // 通过结构特征判断
    return @hasDecl(T, "json_data") and @hasDecl(T, "toSqlString");
}

/// 检查类型是否为 JsonArray
pub fn isJsonArray(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .Struct) return false;
    return @hasDecl(T, "json_data") and @hasDecl(T, "toSqlString") and @hasDecl(T, "get");
}

/// 从字段类型提取 JsonField 的内部类型
pub fn extractJsonFieldType(comptime FieldType: type) type {
    // 通过反射获取 JsonField 的内部类型
    if (@typeInfo(FieldType) == .Struct) {
        // 尝试从别名获取类型
        return struct {};
    }
    return FieldType;
}

// ============================================================================
// 测试
// ============================================================================

test "JsonField - 基本序列化" {
    const TestStruct = struct {
        name: []const u8,
        age: u32,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const value = TestStruct{ .name = "张三", .age = 25 };
    const json_str = try serialize(TestStruct, allocator, value);
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "张三") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "25") != null);
}

test "JsonField - 反序列化" {
    const TestStruct = struct {
        name: []const u8,
        age: u32,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const json_str = "{\"name\":\"李四\",\"age\":30}";
    const value = try deserialize(TestStruct, allocator, json_str);

    try std.testing.expectEqualStrings("李四", value.name);
    try std.testing.expectEqual(@as(u32, 30), value.age);
}

test "JsonField - 嵌套结构体" {
    const Address = struct {
        city: []const u8,
        zip_code: []const u8,
    };

    const Person = struct {
        name: []const u8,
        address: Address,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const person = Person{
        .name = "王五",
        .address = .{
            .city = "北京",
            .zip_code = "100000",
        },
    };

    const json_str = try serialize(Person, allocator, person);
    defer allocator.free(json_str);

    const parsed = try deserialize(Person, allocator, json_str);
    try std.testing.expectEqualStrings("北京", parsed.address.city);
}

test "JsonField - 数组序列化" {
    const Numbers = struct {
        values: []u32,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const numbers = Numbers{ .values = &.{ 1, 2, 3, 4, 5 } };
    const json_str = try serialize(Numbers, allocator, numbers);
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "1") != null);
}

test "JsonField - 可选字段" {
    const OptionalStruct = struct {
        name: []const u8,
        nickname: ?[]const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 测试有值
    const with_value = OptionalStruct{ .name = "赵六", .nickname = "小六" };
    const json1 = try serialize(OptionalStruct, allocator, with_value);
    defer allocator.free(json1);

    const parsed1 = try deserialize(OptionalStruct, allocator, json1);
    try std.testing.expect(parsed1.nickname != null);
    try std.testing.expectEqualStrings("小六", parsed1.nickname.?);

    // 测试 null
    const without_value = OptionalStruct{ .name = "钱七", .nickname = null };
    const json2 = try serialize(OptionalStruct, allocator, without_value);
    defer allocator.free(json2);

    const parsed2 = try deserialize(OptionalStruct, allocator, json2);
    try std.testing.expect(parsed2.nickname == null);
}

test "JsonArray - 数组类型" {
    const Tags = struct {
        tags: [][]const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const tags = Tags{ .tags = &.{ "zig", "orm", "json" } };
    const json_str = try serialize(Tags, allocator, tags);
    defer allocator.free(json_str);

    const parsed = try deserialize(Tags, allocator, json_str);
    try std.testing.expectEqual(@as(usize, 3), parsed.tags.len);
}
