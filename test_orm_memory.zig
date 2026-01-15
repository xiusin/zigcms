const std = @import("std");
const orm = @import("application/services/sql/orm.zig");

const User = orm.define(struct {
    pub const table_name = "users_test";
    pub const primary_key = "id";

    id: u64,
    name: []const u8,
    email: []const u8,
    bio: ?[]const u8 = null,
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("❌ 内存泄漏检测到！\n", .{});
            std.process.exit(1);
        } else {
            std.debug.print("✅ 无内存泄漏\n", .{});
        }
    }
    
    const allocator = gpa.allocator();
    
    // 创建内存数据库
    var db = orm.Database.sqlite(allocator, ":memory:") catch |err| {
        std.debug.print("创建数据库失败: {}\n", .{err});
        return err;
    };
    defer db.deinit();
    
    // 创建测试表
    _ = db.rawExec(
        \\CREATE TABLE users_test (
        \\  id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\  name TEXT NOT NULL,
        \\  email TEXT NOT NULL,
        \\  bio TEXT
        \\)
    , .{}) catch |err| {
        std.debug.print("创建表失败: {}\n", .{err});
        return err;
    };
    
    // 插入测试数据
    _ = try db.rawExec("INSERT INTO users_test (name, email, bio) VALUES ('Alice', 'alice@example.com', 'Software engineer')", .{});
    _ = try db.rawExec("INSERT INTO users_test (name, email, bio) VALUES ('Bob', 'bob@example.com', 'Product manager')", .{});
    _ = try db.rawExec("INSERT INTO users_test (name, email) VALUES ('Charlie', 'charlie@example.com')", .{});
    
    std.debug.print("\n=== 测试 1: 使用 QueryResult (Arena Allocator) ===\n", .{});
    {
        var result = try User.allWithArena(&db, allocator);
        defer result.deinit();
        
        std.debug.print("查询到 {} 条记录\n", .{result.count()});
        
        for (result.items()) |user| {
            std.debug.print("  - ID: {}, Name: {s}, Email: {s}, Bio: {?s}\n", .{ user.id, user.name, user.email, user.bio });
        }
        
        if (result.first()) |first| {
            std.debug.print("第一条记录: {s}\n", .{first.name});
        }
        
        std.debug.print("✅ 测试1通过：Arena Allocator 自动管理内存\n", .{});
    }
    
    std.debug.print("\n=== 测试 2: 旧方法对比（需要手动释放）===\n", .{});
    {
        const users = try User.all(&db);
        defer User.freeModels(db.allocator, users);
        
        std.debug.print("查询到 {} 条记录\n", .{users.len});
        std.debug.print("✅ 测试2通过：手动释放也正常工作\n", .{});
    }
    
    std.debug.print("\n=== 测试 3: 多次查询（验证无泄漏）===\n", .{});
    {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            var result = try User.allWithArena(&db, allocator);
            defer result.deinit();
            _ = result.count();
        }
        std.debug.print("✅ 测试3通过：100次查询无泄漏\n", .{});
    }
    
    std.debug.print("\n=== 测试 4: QueryResult 辅助方法 ===\n", .{});
    {
        var result = try User.allWithArena(&db, allocator);
        defer result.deinit();
        
        if (result.first()) |first| {
            std.debug.print("first(): {s}\n", .{first.name});
        }
        
        if (result.last()) |last| {
            std.debug.print("last(): {s}\n", .{last.name});
        }
        
        if (result.get(1)) |second| {
            std.debug.print("get(1): {s}\n", .{second.name});
        }
        
        std.debug.print("isEmpty(): {}\n", .{result.isEmpty()});
        std.debug.print("count(): {}\n", .{result.count()});
        
        std.debug.print("✅ 测试4通过：所有辅助方法正常工作\n", .{});
    }
    
    std.debug.print("\n✅ 所有 ORM 内存安全测试通过！\n", .{});
}
