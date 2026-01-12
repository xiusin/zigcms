const std = @import("std");
const testing = std.testing;
const orm = @import("../application/services/sql/orm.zig");

const TestUser = orm.define(struct {
    pub const table_name = "test_users";
    pub const primary_key = "id";

    id: ?u64 = null,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
});

test "ORM - freeModel 正确释放模型内存" {
    const allocator = testing.allocator;

    var user = TestUser{
        .id = 1,
        .name = try allocator.dupe(u8, "Alice"),
        .email = try allocator.dupe(u8, "alice@example.com"),
        .age = 25,
    };

    TestUser.freeModel(allocator, &user);
}

test "ORM - freeModels 正确释放模型数组内存" {
    const allocator = testing.allocator;

    var users = try allocator.alloc(TestUser, 3);

    users[0] = TestUser{
        .id = 1,
        .name = try allocator.dupe(u8, "Alice"),
        .email = try allocator.dupe(u8, "alice@example.com"),
        .age = 25,
    };

    users[1] = TestUser{
        .id = 2,
        .name = try allocator.dupe(u8, "Bob"),
        .email = try allocator.dupe(u8, "bob@example.com"),
        .age = 30,
    };

    users[2] = TestUser{
        .id = 3,
        .name = try allocator.dupe(u8, "Charlie"),
        .email = try allocator.dupe(u8, "charlie@example.com"),
        .age = 35,
    };

    TestUser.freeModels(allocator, users);
}

test "ORM - List RAII 模式自动释放内存" {
    const allocator = testing.allocator;

    var users_data = try allocator.alloc(TestUser, 2);

    users_data[0] = TestUser{
        .id = 1,
        .name = try allocator.dupe(u8, "Alice"),
        .email = try allocator.dupe(u8, "alice@example.com"),
        .age = 25,
    };

    users_data[1] = TestUser{
        .id = 2,
        .name = try allocator.dupe(u8, "Bob"),
        .email = try allocator.dupe(u8, "bob@example.com"),
        .age = 30,
    };

    var list = TestUser.List{
        .allocator = allocator,
        .data = users_data,
    };
    defer list.deinit();

    try testing.expectEqual(@as(usize, 2), list.count());
    try testing.expect(list.isNotEmpty());

    const first = list.first();
    try testing.expect(first != null);
    if (first) |u| {
        try testing.expectEqualStrings("Alice", u.name);
    }
}

test "ORM - List 遍历测试" {
    const allocator = testing.allocator;

    var users_data = try allocator.alloc(TestUser, 3);

    users_data[0] = TestUser{
        .id = 1,
        .name = try allocator.dupe(u8, "Alice"),
        .email = try allocator.dupe(u8, "alice@example.com"),
        .age = 25,
    };

    users_data[1] = TestUser{
        .id = 2,
        .name = try allocator.dupe(u8, "Bob"),
        .email = try allocator.dupe(u8, "bob@example.com"),
        .age = 30,
    };

    users_data[2] = TestUser{
        .id = 3,
        .name = try allocator.dupe(u8, "Charlie"),
        .email = try allocator.dupe(u8, "charlie@example.com"),
        .age = 35,
    };

    var list = TestUser.List{
        .allocator = allocator,
        .data = users_data,
    };
    defer list.deinit();

    var count: usize = 0;
    for (list.items()) |user| {
        try testing.expect(user.id != null);
        try testing.expect(user.name.len > 0);
        count += 1;
    }
    try testing.expectEqual(@as(usize, 3), count);
}

test "ORM - 空字符串不会被释放" {
    const allocator = testing.allocator;

    var user = TestUser{
        .id = 1,
        .name = "",
        .email = "",
        .age = null,
    };

    TestUser.freeModel(allocator, &user);
}
