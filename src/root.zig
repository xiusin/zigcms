const std = @import("std");
const testing = std.testing;
const GitApi = @import("modules/git.zig").GitApi;

const Person = struct {
    id: i32,
    name: []const u8,
    age: i32,
};

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "git test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var api = try GitApi.init(allocator, std.os.getenvW("GIT_TOKEN").?);
    defer api.deinit();

    const repos = try api.list_starred_repos();
    defer api.allocator.free(repos);
    for (repos) |value| {
        std.debug.print("repo name = {any}\n", .{value});
    }

    const readme = try api.get_repo_readme_html("xiusin", "web-redis-manager");
    defer api.allocator.free(readme);
    std.debug.print("{s}\n", .{readme});

    const trend_html = try api.get_trending_html("go", "daily");
    defer api.allocator.free(trend_html);
    std.debug.print("{s}\n", .{trend_html});

    const follow_users = try api.followers();
    defer api.allocator.free(follow_users);
    for (follow_users) |value| {
        std.debug.print("follow user name = {s}\n", .{value.login.?});
    }

    const following_users = try api.following();
    defer api.allocator.free(following_users);
    for (following_users) |value| {
        std.debug.print("following user name = {s}\n", .{value.login.?});
    }
}
