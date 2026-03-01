//! ORM 关系预加载 - 自动解决 N+1 查询问题
//!
//! 使用示例：
//! ```zig
//! // 定义关系
//! pub const Role = struct {
//!     id: ?i32 = null,
//!     name: []const u8 = "",
//!     
//!     pub const relations = .{
//!         .menus = .{
//!             .type = .many_to_many,
//!             .model = Menu,
//!             .through = "role_menu",
//!             .foreign_key = "role_id",
//!             .related_key = "menu_id",
//!         },
//!     };
//! };
//!
//! // 使用预加载（自动解决 N+1）
//! var q = OrmRole.Query();
//! defer q.deinit();
//! 
//! _ = q.with(&.{"menus"});  // 预加载菜单
//! const roles = try q.get();
//! defer OrmRole.freeModels(roles);
//!
//! // 访问关联数据
//! for (roles) |role| {
//!     const menus = role.menus;  // 已预加载，无额外查询
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 关系类型
pub const RelationType = enum {
    has_one,        // 一对一
    has_many,       // 一对多
    belongs_to,     // 属于（反向一对多）
    many_to_many,   // 多对多
};

/// 关系定义
pub fn Relation(comptime T: type) type {
    return struct {
        type: RelationType,
        model: type,
        foreign_key: []const u8,
        local_key: ?[]const u8 = null,
        through: ?[]const u8 = null,      // 中间表（多对多）
        related_key: ?[]const u8 = null,  // 关联键（多对多）
    };
}

/// 预加载器
pub fn EagerLoader(comptime Model: type) type {
    return struct {
        const Self = @This();
        
        allocator: Allocator,
        relations: std.StringHashMap(void),
        
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .relations = std.StringHashMap(void).init(allocator),
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.relations.deinit();
        }
        
        /// 添加预加载关系
        pub fn add(self: *Self, relation: []const u8) !void {
            try self.relations.put(relation, {});
        }
        
        /// 检查是否需要预加载
        pub fn has(self: *const Self, relation: []const u8) bool {
            return self.relations.contains(relation);
        }
        
        /// 预加载所有关系
        pub fn load(self: *Self, db: anytype, models: []Model) !void {
            if (models.len == 0) return;
            
            // 检查模型是否定义了关系
            if (!@hasDecl(Model, "relations")) return;
            
            const relations = Model.relations;
            const relations_info = @typeInfo(@TypeOf(relations));
            
            if (relations_info != .@"struct") return;
            
            // 遍历所有定义的关系
            inline for (relations_info.@"struct".fields) |field| {
                if (self.has(field.name)) {
                    const relation = @field(relations, field.name);
                    try self.loadRelation(db, models, field.name, relation);
                }
            }
        }
        
        /// 加载单个关系
        fn loadRelation(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            switch (relation.type) {
                .many_to_many => try self.loadManyToMany(db, models, relation_name, relation),
                .has_many => try self.loadHasMany(db, models, relation_name, relation),
                .has_one => try self.loadHasOne(db, models, relation_name, relation),
                .belongs_to => try self.loadBelongsTo(db, models, relation_name, relation),
            }
        }
        
        /// 加载多对多关系
        fn loadManyToMany(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            _ = self;
            _ = db;
            _ = models;
            _ = relation_name;
            _ = relation;
            
            // TODO: 实现多对多预加载
            // 1. 收集所有主键 ID
            // 2. 批量查询中间表
            // 3. 批量查询关联模型
            // 4. 组装数据到模型
        }
        
        /// 加载一对多关系
        fn loadHasMany(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            _ = self;
            _ = db;
            _ = models;
            _ = relation_name;
            _ = relation;
            
            // TODO: 实现一对多预加载
        }
        
        /// 加载一对一关系
        fn loadHasOne(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            _ = self;
            _ = db;
            _ = models;
            _ = relation_name;
            _ = relation;
            
            // TODO: 实现一对一预加载
        }
        
        /// 加载属于关系
        fn loadBelongsTo(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            _ = self;
            _ = db;
            _ = models;
            _ = relation_name;
            _ = relation;
            
            // TODO: 实现属于关系预加载
        }
    };
}

/// 关系数据存储（用于模型）
pub fn RelationData(comptime T: type) type {
    return struct {
        loaded: bool = false,
        data: ?[]T = null,
        
        pub fn deinit(self: *@This(), allocator: Allocator) void {
            if (self.data) |d| {
                allocator.free(d);
            }
        }
    };
}
