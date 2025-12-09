//! 实体元数据模块
//!
//! 提供编译期实体字段分析，解决 Go 程序员在 Zig 中的泛型 CRUD 痛点。
//!
//! ## 核心问题
//!
//! Go 中可以轻松做到：
//! ```go
//! db.Model(&user).Updates(map[string]interface{}{"name": "hello", "age": 18})
//! ```
//!
//! Zig 没有运行时反射，但可以用 comptime 元编程实现类似效果。

const std = @import("std");

/// 实体元信息
pub fn EntityMeta(comptime T: type) type {
    return struct {
        const Self = @This();
        const fields = std.meta.fields(T);

        /// 字段数量（不含 id）
        pub const field_count = countNonIdFields();

        /// 所有字段名（不含 id）
        pub const field_names = getFieldNames();

        /// 表名（从类型名推导）
        pub const table_name = getTableName();

        fn countNonIdFields() usize {
            var count: usize = 0;
            for (fields) |field| {
                if (!std.mem.eql(u8, field.name, "id")) {
                    count += 1;
                }
            }
            return count;
        }

        fn getFieldNames() [field_count][]const u8 {
            var names: [field_count][]const u8 = undefined;
            var i: usize = 0;
            for (fields) |field| {
                if (!std.mem.eql(u8, field.name, "id")) {
                    names[i] = field.name;
                    i += 1;
                }
            }
            return names;
        }

        fn getTableName() []const u8 {
            const full_name = @typeName(T);
            var last_dot: usize = 0;
            for (full_name, 0..) |c, i| {
                if (c == '.') last_dot = i + 1;
            }
            return full_name[last_dot..];
        }

        /// 生成参数占位符元组类型
        pub fn ParamTuple() type {
            comptime {
                const Type = std.builtin.Type;
                var tuple_fields: [field_count]Type.StructField = undefined;

                var i: usize = 0;
                for (fields) |field| {
                    if (!std.mem.eql(u8, field.name, "id")) {
                        tuple_fields[i] = .{
                            .name = std.fmt.comptimePrint("{d}", .{i}),
                            .type = field.type,
                            .default_value_ptr = null,
                            .is_comptime = false,
                            .alignment = @alignOf(field.type),
                        };
                        i += 1;
                    }
                }

                return @Type(.{
                    .@"struct" = .{
                        .layout = .auto,
                        .is_tuple = true,
                        .fields = &tuple_fields,
                        .decls = &.{},
                    },
                });
            }
        }

        /// 从实体提取参数元组（用于 INSERT/UPDATE）
        pub fn toParams(e: T) ParamTuple() {
            var result: ParamTuple() = undefined;
            inline for (field_names, 0..) |name, idx| {
                @field(result, std.fmt.comptimePrint("{d}", .{idx})) = @field(e, name);
            }
            return result;
        }

        /// 生成 INSERT SQL（编译期）
        pub fn insertSQL(comptime schema: []const u8) [:0]const u8 {
            return comptime blk: {
                var sql: [:0]const u8 = "INSERT INTO " ++ schema ++ "." ++ lowerName(table_name) ++ " (";

                for (field_names, 0..) |name, i| {
                    if (i > 0) sql = sql ++ ", ";
                    sql = sql ++ name;
                }

                sql = sql ++ ") VALUES (";

                for (0..field_count) |i| {
                    if (i > 0) sql = sql ++ ", ";
                    sql = sql ++ "$" ++ std.fmt.comptimePrint("{d}", .{i + 1});
                }

                sql = sql ++ ") RETURNING id";
                break :blk sql;
            };
        }

        /// 生成 UPDATE SQL（编译期）
        pub fn updateSQL(comptime schema: []const u8) [:0]const u8 {
            return comptime blk: {
                var sql: [:0]const u8 = "UPDATE " ++ schema ++ "." ++ lowerName(table_name) ++ " SET ";

                for (field_names, 0..) |name, i| {
                    if (i > 0) sql = sql ++ ", ";
                    sql = sql ++ name ++ " = $" ++ std.fmt.comptimePrint("{d}", .{i + 1});
                }

                sql = sql ++ " WHERE id = $" ++ std.fmt.comptimePrint("{d}", .{field_count + 1});
                break :blk sql;
            };
        }

        /// 生成 SELECT SQL（编译期）
        pub fn selectSQL(comptime schema: []const u8) [:0]const u8 {
            return comptime "SELECT * FROM " ++ schema ++ "." ++ lowerName(table_name);
        }

        /// 生成 DELETE SQL（编译期）
        pub fn deleteSQL(comptime schema: []const u8) [:0]const u8 {
            return comptime "DELETE FROM " ++ schema ++ "." ++ lowerName(table_name) ++ " WHERE id = $1";
        }

        fn lowerName(comptime name: []const u8) []const u8 {
            comptime {
                var lower: [name.len]u8 = undefined;
                for (name, 0..) |c, i| {
                    lower[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                }
                return &lower;
            }
        }

        /// 检查实体是否有 id 字段
        pub fn hasId() bool {
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, "id")) return true;
            }
            return false;
        }

        /// 获取实体的 id 值
        pub fn getId(entity: T) ?i32 {
            if (@hasField(T, "id")) {
                const id_field = @field(entity, "id");
                return switch (@typeInfo(@TypeOf(id_field))) {
                    .optional => id_field,
                    else => id_field,
                };
            }
            return null;
        }

        /// 设置实体的时间戳
        pub fn setTimestamps(entity: *T, is_create: bool) void {
            const now = std.time.microTimestamp();
            if (@hasField(T, "update_time")) {
                @field(entity, "update_time") = now;
            }
            if (is_create and @hasField(T, "create_time")) {
                if (@field(entity, "create_time") == null) {
                    @field(entity, "create_time") = now;
                }
            }
        }
    };
}

test "EntityMeta basic" {
    const TestModel = struct {
        id: ?i32 = null,
        name: []const u8 = "",
        age: i32 = 0,
        create_time: ?i64 = null,
        update_time: ?i64 = null,
    };

    const Meta = EntityMeta(TestModel);

    try std.testing.expectEqual(@as(usize, 4), Meta.field_count);
    try std.testing.expectEqualStrings("name", Meta.field_names[0]);
    try std.testing.expectEqualStrings("TestModel", Meta.table_name);
}

test "EntityMeta SQL generation" {
    const User = struct {
        id: ?i32 = null,
        name: []const u8 = "",
        email: []const u8 = "",
    };

    const Meta = EntityMeta(User);

    const insert = Meta.insertSQL("public");
    try std.testing.expectEqualStrings(
        "INSERT INTO public.user (name, email) VALUES ($1, $2) RETURNING id",
        insert,
    );

    const update = Meta.updateSQL("public");
    try std.testing.expectEqualStrings(
        "UPDATE public.user SET name = $1, email = $2 WHERE id = $3",
        update,
    );
}

test "EntityMeta toParams" {
    const User = struct {
        id: ?i32 = null,
        name: []const u8,
        age: i32,
    };

    const user = User{ .id = 1, .name = "test", .age = 25 };
    const Meta = EntityMeta(User);
    const params = Meta.toParams(user);

    try std.testing.expectEqualStrings("test", params[0]);
    try std.testing.expectEqual(@as(i32, 25), params[1]);
}
