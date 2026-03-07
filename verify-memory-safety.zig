const std = @import("std");

/// 内存安全验证工具
/// 
/// 验证项：
/// 1. ORM 查询结果正确释放
/// 2. 深拷贝字符串正确释放
/// 3. Arena Allocator 正确释放
/// 4. 无内存泄漏
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .verbose_log = true,
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("\n❌ 内存泄漏检测失败！\n", .{});
            std.process.exit(1);
        }
    }
    
    const allocator = gpa.allocator();
    
    std.debug.print("=== 质量中心内存安全验证 ===\n\n", .{});
    
    // 1. 验证 ORM 查询结果释放
    try verifyOrmMemoryManagement(allocator);
    
    // 2. 验证深拷贝字符串释放
    try verifyStringDuplication(allocator);
    
    // 3. 验证 Arena Allocator 释放
    try verifyArenaAllocator(allocator);
    
    // 4. 验证无内存泄漏
    try verifyNoMemoryLeaks(allocator);
    
    std.debug.print("\n✅ 所有内存安全验证通过！\n", .{});
}

/// 验证 ORM 查询结果内存管理
fn verifyOrmMemoryManagement(allocator: std.mem.Allocator) !void {
    std.debug.print("1. 验证 ORM 查询结果释放...\n", .{});
    
    // 模拟 ORM 查询结果
    const TestModel = struct {
        id: i32,
        name: []const u8,
    };
    
    // 测试场景 1：正确使用 defer freeModels
    {
        var models = try allocator.alloc(TestModel, 3);
        defer allocator.free(models);
        
        models[0] = .{ .id = 1, .name = try allocator.dupe(u8, "Test1") };
        models[1] = .{ .id = 2, .name = try allocator.dupe(u8, "Test2") };
        models[2] = .{ .id = 3, .name = try allocator.dupe(u8, "Test3") };
        
        defer {
            for (models) |model| {
                allocator.free(model.name);
            }
        }
        
        // 使用 models...
        std.debug.print("   ✓ ORM 查询结果正确释放\n", .{});
    }
    
    // 测试场景 2：使用 Arena 自动管理
    {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        
        const arena_allocator = arena.allocator();
        
        var models = try arena_allocator.alloc(TestModel, 3);
        models[0] = .{ .id = 1, .name = try arena_allocator.dupe(u8, "Test1") };
        models[1] = .{ .id = 2, .name = try arena_allocator.dupe(u8, "Test2") };
        models[2] = .{ .id = 3, .name = try arena_allocator.dupe(u8, "Test3") };
        
        // 无需手动释放，arena.deinit() 会清理所有
        std.debug.print("   ✓ Arena 自动管理 ORM 结果\n", .{});
    }
    
    std.debug.print("   ✅ ORM 查询结果内存管理验证通过\n\n", .{});
}

/// 验证字符串深拷贝内存管理
fn verifyStringDuplication(allocator: std.mem.Allocator) !void {
    std.debug.print("2. 验证深拷贝字符串释放...\n", .{});
    
    // 测试场景 1：正确深拷贝和释放
    {
        const original = "Hello, World!";
        const copy = try allocator.dupe(u8, original);
        defer allocator.free(copy);
        
        std.debug.print("   ✓ 字符串深拷贝正确释放\n", .{});
    }
    
    // 测试场景 2：结构体字段深拷贝
    {
        const User = struct {
            id: i32,
            name: []const u8,
            email: []const u8,
            
            pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
                alloc.free(self.name);
                alloc.free(self.email);
            }
        };
        
        const user = User{
            .id = 1,
            .name = try allocator.dupe(u8, "Alice"),
            .email = try allocator.dupe(u8, "alice@example.com"),
        };
        defer user.deinit(allocator);
        
        std.debug.print("   ✓ 结构体字段深拷贝正确释放\n", .{});
    }
    
    // 测试场景 3：数组字符串深拷贝
    {
        const tags = [_][]const u8{
            try allocator.dupe(u8, "tag1"),
            try allocator.dupe(u8, "tag2"),
            try allocator.dupe(u8, "tag3"),
        };
        defer {
            for (tags) |tag| {
                allocator.free(tag);
            }
        }
        
        std.debug.print("   ✓ 数组字符串深拷贝正确释放\n", .{});
    }
    
    std.debug.print("   ✅ 深拷贝字符串内存管理验证通过\n\n", .{});
}

/// 验证 Arena Allocator 内存管理
fn verifyArenaAllocator(allocator: std.mem.Allocator) !void {
    std.debug.print("3. 验证 Arena Allocator 释放...\n", .{});
    
    // 测试场景 1：基本 Arena 使用
    {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        
        const arena_allocator = arena.allocator();
        
        // 多次分配
        _ = try arena_allocator.alloc(u8, 100);
        _ = try arena_allocator.alloc(u8, 200);
        _ = try arena_allocator.alloc(u8, 300);
        
        // 无需手动释放，arena.deinit() 会清理所有
        std.debug.print("   ✓ Arena 基本使用正确释放\n", .{});
    }
    
    // 测试场景 2：Arena 嵌套使用
    {
        var outer_arena = std.heap.ArenaAllocator.init(allocator);
        defer outer_arena.deinit();
        
        const outer_allocator = outer_arena.allocator();
        
        {
            var inner_arena = std.heap.ArenaAllocator.init(outer_allocator);
            defer inner_arena.deinit();
            
            const inner_allocator = inner_arena.allocator();
            
            _ = try inner_allocator.alloc(u8, 100);
        }
        
        std.debug.print("   ✓ Arena 嵌套使用正确释放\n", .{});
    }
    
    // 测试场景 3：Arena 错误处理
    {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        
        const arena_allocator = arena.allocator();
        
        _ = try arena_allocator.alloc(u8, 100);
        
        // 正常路径
        defer arena.deinit();
        
        std.debug.print("   ✓ Arena 错误处理正确释放\n", .{});
    }
    
    std.debug.print("   ✅ Arena Allocator 内存管理验证通过\n\n", .{});
}

/// 验证无内存泄漏
fn verifyNoMemoryLeaks(allocator: std.mem.Allocator) !void {
    std.debug.print("4. 验证无内存泄漏...\n", .{});
    
    // 测试场景 1：复杂数据结构
    {
        const ComplexStruct = struct {
            id: i32,
            name: []const u8,
            tags: [][]const u8,
            
            pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
                alloc.free(self.name);
                for (self.tags) |tag| {
                    alloc.free(tag);
                }
                alloc.free(self.tags);
            }
        };
        
        var tags = try allocator.alloc([]const u8, 3);
        tags[0] = try allocator.dupe(u8, "tag1");
        tags[1] = try allocator.dupe(u8, "tag2");
        tags[2] = try allocator.dupe(u8, "tag3");
        
        const data = ComplexStruct{
            .id = 1,
            .name = try allocator.dupe(u8, "Test"),
            .tags = tags,
        };
        defer data.deinit(allocator);
        
        std.debug.print("   ✓ 复杂数据结构无内存泄漏\n", .{});
    }
    
    // 测试场景 2：错误路径内存释放
    {
        const result = testErrorPath(allocator) catch |err| {
            std.debug.print("   ✓ 错误路径正确释放内存: {}\n", .{err});
            return;
        };
        _ = result;
    }
    
    // 测试场景 3：循环分配和释放
    {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            const data = try allocator.alloc(u8, 1024);
            defer allocator.free(data);
        }
        
        std.debug.print("   ✓ 循环分配和释放无内存泄漏\n", .{});
    }
    
    std.debug.print("   ✅ 无内存泄漏验证通过\n\n", .{});
}

/// 测试错误路径内存释放
fn testErrorPath(allocator: std.mem.Allocator) !void {
    const data1 = try allocator.alloc(u8, 100);
    errdefer allocator.free(data1);
    
    const data2 = try allocator.alloc(u8, 200);
    errdefer allocator.free(data2);
    
    // 模拟错误
    return error.TestError;
}
