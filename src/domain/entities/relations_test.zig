//! ORM 关系预加载测试
//!
//! 验证关系预加载功能是否正常工作

const std = @import("std");
const testing = std.testing;

test "关系预加载 - 编译时验证" {
    // 验证关系定义的编译时类型检查
    const relations_mod = @import("../../../application/services/sql/relations.zig");
    
    // 验证 RelationType 枚举
    const rel_type: relations_mod.RelationType = .many_to_many;
    try testing.expect(rel_type == .many_to_many);
    
    // 验证 Relation 函数可以被调用
    const TestModel = struct {
        id: ?i32 = null,
        name: []const u8 = "",
    };
    
    const RelationDef = relations_mod.Relation(TestModel);
    _ = RelationDef;
    
    std.debug.print("\n✅ 关系预加载模块编译通过\n", .{});
}

test "EagerLoader - 基础功能" {
    const relations_mod = @import("../../../application/services/sql/relations.zig");
    
    const TestModel = struct {
        id: ?i32 = null,
        name: []const u8 = "",
    };
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 创建 EagerLoader
    const EagerLoader = relations_mod.EagerLoader(TestModel);
    var loader = EagerLoader.init(allocator);
    defer loader.deinit();
    
    // 添加关系
    try loader.add("menus");
    try loader.add("permissions");
    
    // 验证关系已添加
    try testing.expect(loader.relations.count() == 2);
    try testing.expect(loader.relations.contains("menus"));
    try testing.expect(loader.relations.contains("permissions"));
    
    std.debug.print("\n✅ EagerLoader 基础功能正常\n", .{});
}

test "关系定义 - SysRole" {
    const models = @import("../../../domain/entities/mod.zig");
    
    // 验证 SysRole 有 relations 定义
    try testing.expect(@hasDecl(models.SysRole, "relations"));
    
    // 验证 menus 字段存在
    try testing.expect(@hasField(models.SysRole, "menus"));
    
    // 验证 menus 字段是 optional
    const field_info = @typeInfo(models.SysRole).@"struct".fields;
    var found_menus = false;
    for (field_info) |field| {
        if (std.mem.eql(u8, field.name, "menus")) {
            found_menus = true;
            // 验证是 optional 类型
            const type_info = @typeInfo(field.type);
            try testing.expect(type_info == .optional);
        }
    }
    try testing.expect(found_menus);
    
    std.debug.print("\n✅ SysRole 关系定义正确\n", .{});
}
