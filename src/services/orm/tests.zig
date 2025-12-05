//! ORM 模块测试
//!
//! 无需连接数据库的单元测试，使用 Mock 验证逻辑正确性。

const std = @import("std");
const testing = std.testing;
const entity = @import("entity.zig");

/// 测试用实体
const TestUser = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    email: []const u8 = "",
    age: i32 = 0,
    status: i32 = 1,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};

/// 测试用文章实体（模拟真实场景）
const TestArticle = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    content: ?[]const u8 = null,
    category_id: i32 = 0,
    view_count: i32 = 0,
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};

// ============================================================================
// EntityMeta 测试
// ============================================================================

test "EntityMeta: 字段计数正确跳过 id" {
    const Meta = entity.EntityMeta(TestUser);
    // TestUser 有 7 个字段，跳过 id 后应该是 6 个
    try testing.expectEqual(@as(usize, 6), Meta.field_count);
}

test "EntityMeta: 字段名提取正确" {
    const Meta = entity.EntityMeta(TestUser);

    try testing.expectEqualStrings("name", Meta.field_names[0]);
    try testing.expectEqualStrings("email", Meta.field_names[1]);
    try testing.expectEqualStrings("age", Meta.field_names[2]);
    try testing.expectEqualStrings("status", Meta.field_names[3]);
    try testing.expectEqualStrings("create_time", Meta.field_names[4]);
    try testing.expectEqualStrings("update_time", Meta.field_names[5]);
}

test "EntityMeta: 表名从类型名推导" {
    const Meta = entity.EntityMeta(TestUser);
    try testing.expectEqualStrings("TestUser", Meta.table_name);
}

test "EntityMeta: INSERT SQL 生成正确" {
    const Meta = entity.EntityMeta(TestUser);
    const sql = Meta.insertSQL("public");

    // 验证 SQL 包含正确的表名和字段
    try testing.expect(std.mem.indexOf(u8, sql, "INSERT INTO public.testuser") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "name") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "email") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "$1") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "RETURNING id") != null);
    // 确保不包含 id 字段
    try testing.expect(std.mem.indexOf(u8, sql, "(id,") == null);
}

test "EntityMeta: UPDATE SQL 生成正确" {
    const Meta = entity.EntityMeta(TestUser);
    const sql = Meta.updateSQL("zigcms");

    try testing.expect(std.mem.indexOf(u8, sql, "UPDATE zigcms.testuser SET") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "name = $1") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE id = $7") != null); // 6 个字段 + 1
}

test "EntityMeta: SELECT SQL 生成正确" {
    const Meta = entity.EntityMeta(TestUser);
    const sql = Meta.selectSQL("app");

    try testing.expectEqualStrings("SELECT * FROM app.testuser", sql);
}

test "EntityMeta: DELETE SQL 生成正确" {
    const Meta = entity.EntityMeta(TestUser);
    const sql = Meta.deleteSQL("app");

    try testing.expectEqualStrings("DELETE FROM app.testuser WHERE id = $1", sql);
}

test "EntityMeta: toParams 正确提取字段值" {
    const Meta = entity.EntityMeta(TestUser);
    const user = TestUser{
        .id = 42,
        .name = "张三",
        .email = "zhangsan@example.com",
        .age = 25,
        .status = 1,
        .create_time = 1000,
        .update_time = 2000,
    };

    const params = Meta.toParams(user);

    // 验证参数顺序和值（跳过 id）
    try testing.expectEqualStrings("张三", params[0]);
    try testing.expectEqualStrings("zhangsan@example.com", params[1]);
    try testing.expectEqual(@as(i32, 25), params[2]);
    try testing.expectEqual(@as(i32, 1), params[3]);
    try testing.expectEqual(@as(?i64, 1000), params[4]);
    try testing.expectEqual(@as(?i64, 2000), params[5]);
}

test "EntityMeta: getId 正确获取实体 ID" {
    const Meta = entity.EntityMeta(TestUser);

    // 有 ID
    const user1 = TestUser{ .id = 123 };
    try testing.expectEqual(@as(?i32, 123), Meta.getId(user1));

    // 无 ID
    const user2 = TestUser{ .id = null };
    try testing.expectEqual(@as(?i32, null), Meta.getId(user2));
}

test "EntityMeta: setTimestamps 自动设置时间戳" {
    const Meta = entity.EntityMeta(TestUser);

    var user = TestUser{};
    try testing.expectEqual(@as(?i64, null), user.create_time);
    try testing.expectEqual(@as(?i64, null), user.update_time);

    // 创建时设置两个时间戳
    Meta.setTimestamps(&user, true);
    try testing.expect(user.create_time != null);
    try testing.expect(user.update_time != null);

    const old_create = user.create_time;

    // 更新时只设置 update_time，create_time 保持不变
    Meta.setTimestamps(&user, false);
    try testing.expectEqual(old_create, user.create_time);
    try testing.expect(user.update_time != null);
}

test "EntityMeta: 不同实体类型独立" {
    const UserMeta = entity.EntityMeta(TestUser);
    const ArticleMeta = entity.EntityMeta(TestArticle);

    try testing.expectEqual(@as(usize, 6), UserMeta.field_count);
    try testing.expectEqual(@as(usize, 7), ArticleMeta.field_count);

    try testing.expectEqualStrings("TestUser", UserMeta.table_name);
    try testing.expectEqualStrings("TestArticle", ArticleMeta.table_name);
}

// ============================================================================
// ParamTuple 类型测试
// ============================================================================

test "ParamTuple: 类型正确生成" {
    const Meta = entity.EntityMeta(TestUser);
    const Tuple = Meta.ParamTuple();

    // 验证元组类型的字段数量
    const fields = @typeInfo(Tuple).@"struct".fields;
    try testing.expectEqual(@as(usize, 6), fields.len);

    // 验证是元组
    try testing.expect(@typeInfo(Tuple).@"struct".is_tuple);
}

// ============================================================================
// 边界情况测试
// ============================================================================

test "EntityMeta: 只有 id 和一个字段的实体" {
    const MinimalEntity = struct {
        id: ?i32 = null,
        value: []const u8 = "",
    };

    const Meta = entity.EntityMeta(MinimalEntity);
    try testing.expectEqual(@as(usize, 1), Meta.field_count);
    try testing.expectEqualStrings("value", Meta.field_names[0]);
}

test "EntityMeta: 多种字段类型" {
    const ComplexEntity = struct {
        id: ?i32 = null,
        name: []const u8 = "",
        count: u64 = 0,
        price: f64 = 0.0,
        active: bool = false,
        data: ?[]const u8 = null,
    };

    const Meta = entity.EntityMeta(ComplexEntity);
    try testing.expectEqual(@as(usize, 5), Meta.field_count);

    const e = ComplexEntity{
        .id = 1,
        .name = "test",
        .count = 100,
        .price = 99.99,
        .active = true,
        .data = "blob",
    };

    const params = Meta.toParams(e);
    try testing.expectEqualStrings("test", params[0]);
    try testing.expectEqual(@as(u64, 100), params[1]);
    try testing.expectEqual(@as(f64, 99.99), params[2]);
    try testing.expectEqual(true, params[3]);
    try testing.expectEqualStrings("blob", params[4].?);
}

// ============================================================================
// SQL 注入防护验证（编译期生成，无注入风险）
// ============================================================================

test "SQL 生成: 编译期常量，无运行时拼接" {
    const Meta = entity.EntityMeta(TestUser);

    // 这些 SQL 在编译期生成，是常量
    const insert = Meta.insertSQL("schema");
    const update = Meta.updateSQL("schema");
    const select_ = Meta.selectSQL("schema");
    const delete = Meta.deleteSQL("schema");

    // 验证是编译期常量（指针相等）
    const insert2 = Meta.insertSQL("schema");
    try testing.expectEqual(insert.ptr, insert2.ptr);

    _ = update;
    _ = select_;
    _ = delete;
}
