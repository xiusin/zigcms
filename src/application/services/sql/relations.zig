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

/// 预加载配置
pub const EagerLoadConfig = struct {
    /// WHERE 条件
    where_clauses: ?[]const WhereClause = null,
    /// ORDER BY
    order_by: ?[]const u8 = null,
    /// LIMIT
    limit: ?usize = null,
    
    pub const WhereClause = struct {
        field: []const u8,
        op: []const u8,
        value: []const u8,
    };
};

/// 关系定义
pub fn Relation(comptime T: type) type {
    _ = T; // 标记为已使用
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
        nested_relations: std.StringHashMap(std.ArrayList([]const u8)), // 嵌套关系
        relation_configs: std.StringHashMap(EagerLoadConfig), // 关系配置
        
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .relations = std.StringHashMap(void).init(allocator),
                .nested_relations = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
                .relation_configs = std.StringHashMap(EagerLoadConfig).init(allocator),
            };
        }
        
        pub fn deinit(self: *Self) void {
            // 清理嵌套关系
            var it = self.nested_relations.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            self.nested_relations.deinit();
            self.relations.deinit();
            self.relation_configs.deinit();
        }
        
        /// 添加预加载关系（支持嵌套：menus.permissions）
        pub fn add(self: *Self, relation: []const u8) !void {
            // 检查是否是嵌套关系
            if (std.mem.indexOf(u8, relation, ".")) |dot_pos| {
                // 嵌套关系：menus.permissions
                const parent = relation[0..dot_pos];
                const child = relation[dot_pos + 1 ..];
                
                // 添加父关系
                try self.relations.put(parent, {});
                
                // 添加子关系到嵌套映射
                var entry = try self.nested_relations.getOrPut(parent);
                if (!entry.found_existing) {
                    entry.value_ptr.* = std.ArrayList([]const u8){};
                }
                try entry.value_ptr.append(self.allocator, child);
            } else {
                // 普通关系
                try self.relations.put(relation, {});
            }
        }
        
        /// 添加带配置的预加载关系
        pub fn addWithConfig(self: *Self, relation: []const u8, config: EagerLoadConfig) !void {
            try self.add(relation);
            try self.relation_configs.put(relation, config);
        }
        
        /// 检查是否需要预加载
        pub fn has(self: *const Self, relation: []const u8) bool {
            return self.relations.contains(relation);
        }
        
        /// 获取关系配置
        pub fn getConfig(self: *const Self, relation: []const u8) ?EagerLoadConfig {
            return self.relation_configs.get(relation);
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
                    
                    // 加载嵌套关系
                    if (self.nested_relations.get(field.name)) |nested| {
                        try self.loadNestedRelations(db, models, field.name, nested.items);
                    }
                }
            }
        }
        
        /// 加载嵌套关系
        fn loadNestedRelations(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime parent_name: []const u8,
            child_relations: []const []const u8,
        ) !void {
            // 获取父关系的数据
            for (models) |model| {
                const parent_data = @field(model, parent_name);
                
                // 检查父数据类型
                const parent_type = @TypeOf(parent_data);
                const parent_info = @typeInfo(parent_type);
                
                if (parent_info == .optional) {
                    if (parent_data) |data| {
                        const data_info = @typeInfo(@TypeOf(data));
                        if (data_info == .pointer and data_info.pointer.size == .slice) {
                            // 父数据是切片（一对多/多对多）
                            const ChildModel = std.meta.Child(@TypeOf(data));
                            try self.loadNestedForSlice(ChildModel, db, data, child_relations);
                        } else {
                            // 父数据是单个对象（一对一）
                            const ChildModel = @TypeOf(data);
                            var slice = [_]ChildModel{data};
                            try self.loadNestedForSlice(ChildModel, db, &slice, child_relations);
                        }
                    }
                }
            }
        }
        
        /// 为切片数据加载嵌套关系
        fn loadNestedForSlice(
            self: *Self,
            comptime ChildModel: type,
            db: anytype,
            children: []ChildModel,
            child_relations: []const []const u8,
        ) !void {
            if (children.len == 0) return;
            
            // 为子模型创建 EagerLoader
            const ChildLoader = EagerLoader(ChildModel);
            var child_loader = ChildLoader.init(self.allocator);
            defer child_loader.deinit();
            
            // 添加子关系
            for (child_relations) |rel| {
                try child_loader.add(rel);
            }
            
            // 加载子关系
            try child_loader.load(db, children);
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
                else => {}, // 未知关系类型，跳过
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
            if (models.len == 0) return;
            
            const RelatedModel = relation.model;
            const through_table = relation.through;
            const foreign_key = relation.foreign_key;
            const related_key = relation.related_key;
            const local_key = if (@hasField(@TypeOf(relation), "local_key") and relation.local_key != null) relation.local_key.? else "id";
            
            // 1. 收集所有主键 ID
            var ids = std.ArrayListUnmanaged(i32){};
            defer ids.deinit(self.allocator);
            
            for (models) |model| {
                const id_field = @field(model, local_key);
                if (id_field) |id| {
                    try ids.append(self.allocator, id);
                }
            }
            
            if (ids.items.len == 0) return;
            
            // 2. 批量查询中间表
            const pivot_sql = try std.fmt.allocPrint(
                self.allocator,
                "SELECT {s}, {s} FROM {s} WHERE {s} IN (",
                .{ foreign_key, related_key, through_table, foreign_key }
            );
            defer self.allocator.free(pivot_sql);
            
            var pivot_query = std.ArrayListUnmanaged(u8){};
            defer pivot_query.deinit(self.allocator);
            
            try pivot_query.appendSlice(self.allocator, pivot_sql);
            for (ids.items, 0..) |id, i| {
                if (i > 0) try pivot_query.appendSlice(self.allocator, ", ");
                const id_str = try std.fmt.allocPrint(self.allocator, "{d}", .{id});
                defer self.allocator.free(id_str);
                try pivot_query.appendSlice(self.allocator, id_str);
            }
            try pivot_query.appendSlice(self.allocator, ")");
            
            var pivot_result = try db.rawQuery(pivot_query.items, .{});
            defer pivot_result.deinit();
            
            // 3. 收集关联模型 ID
            var related_ids = std.ArrayListUnmanaged(i32){};
            defer related_ids.deinit(self.allocator);
            
            var pivot_map = std.AutoHashMap(i32, std.ArrayListUnmanaged(i32)).init(self.allocator);
            defer {
                var it = pivot_map.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(self.allocator);
                }
                pivot_map.deinit();
            }
            
            while (pivot_result.next()) {
                const row = pivot_result.getCurrentRow() orelse continue;
                const fk = row.getInt(foreign_key) orelse continue;
                const rk = row.getInt(related_key) orelse continue;
                
                try related_ids.append(self.allocator, @intCast(rk));
                
                var entry = try pivot_map.getOrPut(@intCast(fk));
                if (!entry.found_existing) {
                    entry.value_ptr.* = std.ArrayListUnmanaged(i32){};
                }
                try entry.value_ptr.append(self.allocator, @intCast(rk));
            }
            
            if (related_ids.items.len == 0) return;
            
            // 4. 批量查询关联模型
            const OrmRelated = @import("orm.zig").defineWithConfig(RelatedModel, .{});
            var related_q = OrmRelated.query(db);
            defer related_q.deinit();
            
            _ = related_q.whereIn("id", related_ids.items);
            const related_models = try related_q.get();
            
            // 5. 构建关联模型映射
            var related_map = std.AutoHashMap(i32, RelatedModel).init(self.allocator);
            defer related_map.deinit();
            
            for (related_models) |rm| {
                const rm_id = @field(rm, "id") orelse continue;
                try related_map.put(rm_id, rm);
            }
            
            // 6. 组装数据到模型
            for (models) |*model| {
                const model_id = @field(model.*, local_key) orelse continue;
                
                if (pivot_map.get(model_id)) |rids| {
                    var related_list = std.ArrayListUnmanaged(RelatedModel){};
                    
                    for (rids.items) |rid| {
                        if (related_map.get(rid)) |rm| {
                            try related_list.append(self.allocator, rm);
                        }
                    }
                    
                    const related_slice = try related_list.toOwnedSlice(self.allocator);
                    @field(model.*, relation_name) = related_slice;
                }
            }
        }
        
        /// 加载一对多关系
        fn loadHasMany(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            if (models.len == 0) return;
            
            const RelatedModel = relation.model;
            const foreign_key = relation.foreign_key;
            const local_key = if (@hasField(@TypeOf(relation), "local_key") and relation.local_key != null) relation.local_key.? else "id";
            
            // 1. 收集所有主键 ID
            var ids = std.ArrayListUnmanaged(i32){};
            defer ids.deinit(self.allocator);
            
            for (models) |model| {
                const id_field = @field(model, local_key);
                if (id_field) |id| {
                    try ids.append(self.allocator, id);
                }
            }
            
            if (ids.items.len == 0) return;
            
            // 2. 批量查询关联模型
            const OrmRelated = @import("orm.zig").defineWithConfig(RelatedModel, .{});
            var related_q = OrmRelated.query(db);
            defer related_q.deinit();
            
            _ = related_q.whereIn(foreign_key, ids.items);
            const related_models = try related_q.get();
            
            // 3. 按外键分组
            var grouped = std.AutoHashMap(i32, std.ArrayListUnmanaged(RelatedModel)).init(self.allocator);
            defer {
                var it = grouped.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(self.allocator);
                }
                grouped.deinit();
            }
            
            for (related_models) |rm| {
                const fk = @field(rm, foreign_key) orelse continue;
                
                var entry = try grouped.getOrPut(fk);
                if (!entry.found_existing) {
                    entry.value_ptr.* = std.ArrayListUnmanaged(RelatedModel){};
                }
                try entry.value_ptr.append(self.allocator, rm);
            }
            
            // 4. 组装数据到模型
            for (models) |*model| {
                const model_id = @field(model.*, local_key) orelse continue;
                
                if (grouped.get(model_id)) |list| {
                    const slice = try list.toOwnedSlice(self.allocator);
                    @field(model.*, relation_name) = slice;
                }
            }
        }
        
        /// 加载一对一关系
        fn loadHasOne(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            if (models.len == 0) return;
            
            const RelatedModel = relation.model;
            const foreign_key = relation.foreign_key;
            const local_key = if (@hasField(@TypeOf(relation), "local_key") and relation.local_key != null) relation.local_key.? else "id";
            
            // 1. 收集所有主键 ID
            var ids = std.ArrayListUnmanaged(i32){};
            defer ids.deinit(self.allocator);
            
            for (models) |model| {
                const id_field = @field(model, local_key);
                if (id_field) |id| {
                    try ids.append(self.allocator, id);
                }
            }
            
            if (ids.items.len == 0) return;
            
            // 2. 批量查询关联模型
            const OrmRelated = @import("orm.zig").defineWithConfig(RelatedModel, .{});
            var related_q = OrmRelated.query(db);
            defer related_q.deinit();
            
            _ = related_q.whereIn(foreign_key, ids.items);
            const related_models = try related_q.get();
            
            // 3. 构建映射
            var related_map = std.AutoHashMap(i32, RelatedModel).init(self.allocator);
            defer related_map.deinit();
            
            for (related_models) |rm| {
                const fk = @field(rm, foreign_key) orelse continue;
                try related_map.put(fk, rm);
            }
            
            // 4. 组装数据到模型
            for (models) |*model| {
                const model_id = @field(model.*, local_key) orelse continue;
                
                if (related_map.get(model_id)) |rm| {
                    @field(model.*, relation_name) = rm;
                }
            }
        }
        
        /// 加载属于关系
        fn loadBelongsTo(
            self: *Self,
            db: anytype,
            models: []Model,
            comptime relation_name: []const u8,
            comptime relation: anytype,
        ) !void {
            if (models.len == 0) return;
            
            const RelatedModel = relation.model;
            const foreign_key = relation.foreign_key;
            const owner_key = if (@hasField(@TypeOf(relation), "local_key") and relation.local_key != null) relation.local_key.? else "id";
            
            // 1. 收集所有外键 ID
            var ids = std.ArrayListUnmanaged(i32){};
            defer ids.deinit(self.allocator);
            
            for (models) |model| {
                const fk_field = @field(model, foreign_key);
                if (fk_field) |fk| {
                    try ids.append(self.allocator, fk);
                }
            }
            
            if (ids.items.len == 0) return;
            
            // 2. 批量查询关联模型
            const OrmRelated = @import("orm.zig").defineWithConfig(RelatedModel, .{});
            var related_q = OrmRelated.query(db);
            defer related_q.deinit();
            
            _ = related_q.whereIn(owner_key, ids.items);
            const related_models = try related_q.get();
            
            // 3. 构建映射
            var related_map = std.AutoHashMap(i32, RelatedModel).init(self.allocator);
            defer related_map.deinit();
            
            for (related_models) |rm| {
                const id = @field(rm, owner_key) orelse continue;
                try related_map.put(id, rm);
            }
            
            // 4. 组装数据到模型
            for (models) |*model| {
                const fk = @field(model.*, foreign_key) orelse continue;
                
                if (related_map.get(fk)) |rm| {
                    @field(model.*, relation_name) = rm;
                }
            }
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
