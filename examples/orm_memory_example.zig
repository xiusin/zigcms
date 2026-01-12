const std = @import("std");
const orm = @import("../application/services/sql/orm.zig");

const TestUser = orm.define(struct {
    pub const table_name = "test_users";
    pub const primary_key = "id";

    id: ?u64 = null,
    name: []const u8,
    email: []const u8,
    age: ?u32 = null,
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== ORM 内存管理测试 ===\n\n", .{});

    std.debug.print("1. 测试 freeModel:\n", .{});
    {
        var user = TestUser{
            .id = 1,
            .name = try allocator.dupe(u8, "Alice"),
            .email = try allocator.dupe(u8, "alice@example.com"),
            .age = 25,
        };
        TestUser.freeModel(allocator, &user);
        std.debug.print("   ✓ 成功释放单个模型内存\n", .{});
    }

    std.debug.print("\n2. 测试 freeModels:\n", .{});
    {
        var users = try allocator.alloc(TestUser, 2);

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

        TestUser.freeModels(allocator, users);
        std.debug.print("   ✓ 成功释放模型数组内存\n", .{});
    }

    std.debug.print("\n3. 测试 List RAII 模式:\n", .{});
    {
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

        std.debug.print("   ✓ List 数量: {d}\n", .{list.count()});

        if (list.first()) |first_user| {
            std.debug.print("   ✓ 第一个用户: {s}\n", .{first_user.name});
        }

        std.debug.print("   ✓ List 自动管理内存释放\n", .{});
    }

    std.debug.print("\n=== ORM 内存管理测试通过 ✓ ===\n\n", .{});
}
