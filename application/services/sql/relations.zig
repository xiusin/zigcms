//! ORM 关系定义
//!
//! 提供 Laravel Eloquent 风格的模型关联关系支持。
//!
//! ## 关系类型
//! - hasMany: 一对多（如部门有多个员工）
//! - belongsTo: 多对一（如员工属于部门）
//! - hasOne: 一对一（如员工有一个用户账号）
//!
//! ## 使用示例
//! ```zig
//! const relations = @import("relations.zig");
//!
//! // 获取部门的所有员工
//! const employees = try relations.hasMany(
//!     orm.Employee,
//!     department.id,
//!     "department_id",
//! );
//!
//! // 获取员工所属部门
//! const dept = try relations.belongsTo(
//!     orm.Department,
//!     employee.department_id,
//! );
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 关系类型枚举
pub const RelationType = enum {
    has_one,
    has_many,
    belongs_to,
    many_to_many,
};

/// 关系定义
pub fn Relation(comptime ParentModel: type, comptime RelatedModel: type) type {
    return struct {
        const Self = @This();

        /// 一对多关系
        /// 例：Department.hasMany(Employee, "department_id")
        /// 返回该部门下的所有员工
        pub fn hasMany(parent_id: i32, comptime foreign_key: []const u8) ![]RelatedModel.Model {
            var q = RelatedModel.Where(foreign_key, .eq, parent_id);
            defer q.deinit();
            return q.get();
        }

        /// 一对多关系（带条件）
        pub fn hasManyWhere(
            parent_id: i32,
            comptime foreign_key: []const u8,
            comptime extra_field: []const u8,
            extra_value: anytype,
        ) ![]RelatedModel.Model {
            var q = RelatedModel.Where(foreign_key, .eq, parent_id);
            defer q.deinit();
            _ = q.andWhere(extra_field, .eq, extra_value);
            return q.get();
        }

        /// 多对一关系
        /// 例：Employee.belongsTo(Department)
        /// 返回员工所属的部门
        pub fn belongsTo(foreign_key_value: ?i32) !?RelatedModel.Model {
            if (foreign_key_value == null or foreign_key_value.? == 0) {
                return null;
            }
            return RelatedModel.Find(foreign_key_value.?);
        }

        /// 一对一关系
        /// 例：Employee.hasOne(User, "employee_id")
        pub fn hasOne(parent_id: i32, comptime foreign_key: []const u8) !?RelatedModel.Model {
            var q = RelatedModel.Where(foreign_key, .eq, parent_id);
            defer q.deinit();
            return q.first();
        }

        /// 预加载（获取父模型时同时加载关联）
        /// 注意：Zig 不支持动态字段，返回关联数据作为独立结构
        pub const WithRelation = struct {
            parent: ParentModel.Model,
            related: []RelatedModel.Model,
        };

        /// 带关联加载多条记录
        pub fn withMany(
            parents: []ParentModel.Model,
            allocator: Allocator,
            comptime parent_key: []const u8,
            comptime foreign_key: []const u8,
        ) ![]WithRelation {
            var results = std.ArrayList(WithRelation).init(allocator);
            errdefer results.deinit();

            for (parents) |parent| {
                const parent_id = @field(parent, parent_key) orelse continue;
                const related = try Self.hasMany(parent_id, foreign_key);
                try results.append(.{
                    .parent = parent,
                    .related = related,
                });
            }

            return results.toOwnedSlice();
        }
    };
}

/// 快捷方法：一对多查询
pub fn hasMany(
    comptime RelatedModel: type,
    parent_id: i32,
    comptime foreign_key: []const u8,
) ![]RelatedModel.Model {
    var q = RelatedModel.Where(foreign_key, .eq, parent_id);
    defer q.deinit();
    return q.get();
}

/// 快捷方法：一对多查询（带额外条件）
pub fn hasManyActive(
    comptime RelatedModel: type,
    parent_id: i32,
    comptime foreign_key: []const u8,
) ![]RelatedModel.Model {
    var q = RelatedModel.Where(foreign_key, .eq, parent_id);
    defer q.deinit();
    _ = q.andWhere("status", .eq, @as(i32, 1));
    _ = q.andWhere("is_delete", .eq, @as(i32, 0));
    return q.get();
}

/// 快捷方法：多对一查询
pub fn belongsTo(
    comptime RelatedModel: type,
    foreign_key_value: ?i32,
) !?RelatedModel.Model {
    if (foreign_key_value == null or foreign_key_value.? == 0) {
        return null;
    }
    return RelatedModel.Find(foreign_key_value.?);
}

/// 快捷方法：一对一查询
pub fn hasOne(
    comptime RelatedModel: type,
    parent_id: i32,
    comptime foreign_key: []const u8,
) !?RelatedModel.Model {
    var q = RelatedModel.Where(foreign_key, .eq, parent_id);
    defer q.deinit();
    return q.first();
}

/// 批量预加载（减少 N+1 查询）
pub fn eagerLoad(
    comptime RelatedModel: type,
    parent_ids: []const i32,
    allocator: Allocator,
    comptime foreign_key: []const u8,
) !std.AutoHashMap(i32, []RelatedModel.Model) {
    var result = std.AutoHashMap(i32, []RelatedModel.Model).init(allocator);
    errdefer result.deinit();

    // 一次查询获取所有关联数据
    var q = RelatedModel.WhereIn(foreign_key, parent_ids);
    defer q.deinit();
    const all_related = try q.get();

    // 按 foreign_key 分组
    var grouped = std.AutoHashMap(i32, std.ArrayList(RelatedModel.Model)).init(allocator);
    defer {
        var it = grouped.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        grouped.deinit();
    }

    for (all_related) |item| {
        const fk_value = @field(item, foreign_key);
        const entry = try grouped.getOrPut(fk_value);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(RelatedModel.Model).init(allocator);
        }
        try entry.value_ptr.append(item);
    }

    // 转换为最终结果
    var it = grouped.iterator();
    while (it.next()) |entry| {
        try result.put(entry.key_ptr.*, try entry.value_ptr.toOwnedSlice());
    }

    return result;
}
