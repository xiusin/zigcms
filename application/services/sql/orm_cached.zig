//! 缓存 ORM - 在原有 ORM 基础上增加缓存功能
//!
//! 该模块提供：
//! - 带有缓存功能的模型定义
//! - 自动缓存查询结果
//! - 自动清理关联缓存

const std = @import("std");
const orm = @import("orm.zig");
const CacheService = @import("../cache/cache.zig").CacheService;

/// 带有缓存功能的模型定义
pub fn defineCached(comptime T: type) type {
    const OrmModel = orm.define(T);
    return struct {
        const Self = @This();
        pub const Model = OrmModel.Model;

        /// 全局数据库连接，需要在使用前设置
        var global_db: ?*orm.Database = null;
        var global_cache: ?*CacheService = null;

        /// 设置全局数据库连接
        pub fn use(db: *orm.Database) void {
            global_db = db;
        }

        /// 设置全局缓存服务
        pub fn setCache(cache: *CacheService) void {
            global_cache = cache;
        }

        /// 使用指定数据库连接执行操作（用于事务等场景）
        pub fn withDB(db: *orm.Database) type {
            return struct {
                pub fn query() orm.Query(T) {
                    return Self.Query(db);
                }

                pub fn find(id: anytype) !?T {
                    return Self.FindWithDB(db, id);
                }

                pub fn findById(id: anytype) !?T {
                    return Self.FindWithDB(db, id);
                }

                pub fn all() ![]T {
                    return Self.AllWithDB(db);
                }

                pub fn get() ![]T {
                    return Self.GetWithDB(db);
                }

                pub fn first() !?T {
                    return Self.FirstWithDB(db);
                }

                pub fn firstOrError(error_val: anyerror) !T {
                    return Self.FirstOrErrorWithDB(db, error_val);
                }

                pub fn count() !u64 {
                    return Self.CountWithDB(db);
                }

                pub fn create(data: T) !T {
                    return Self.CreateWithDB(db, data);
                }

                pub fn update(id: anytype, updates: anytype) !u64 {
                    return Self.UpdateWithDB(db, id, updates);
                }

                pub fn destroy(id: anytype) !u64 {
                    return Self.DestroyWithDB(db, id);
                }

                pub fn updateWhere(condition: anytype, updates: anytype) !u64 {
                    return Self.UpdateWhereWithDB(db, condition, updates);
                }

                pub fn deleteWhere(field: []const u8, op: []const u8, value: anytype) !u64 {
                    return Self.DeleteWhereWithDB(db, field, op, value);
                }
            };
        }

        /// 生成缓存键
        fn generateCacheKey(suffix: []const u8) ![]const u8 {
            return std.fmt.alloc(std.heap.page_allocator, "model_{s}_{s}", .{
                @typeName(T),
                suffix,
            });
        }

        /// 清理与模型相关的缓存
        fn clearModelCache() !void {
            if (global_cache) |cache| {
                const table_cache_prefix = try generateCacheKey("table_");
                defer std.heap.page_allocator.free(table_cache_prefix);

                try cache.delByPrefix(table_cache_prefix);

                // 清理所有模型相关的查询缓存
                const query_cache_prefix = try generateCacheKey("query_");
                defer std.heap.page_allocator.free(query_cache_prefix);

                try cache.delByPrefix(query_cache_prefix);
            }
        }

        // 带缓存的查询方法
        pub fn all() ![]T {
            if (global_db == null) return error.NoGlobalDatabaseSet;
            if (global_cache == null) return Self.AllWithDB(global_db.?);

            const cache_key = try generateCacheKey("all");
            defer std.heap.page_allocator.free(cache_key);

            // 试图从缓存获取
            if (try global_cache.?.get(cache_key)) |cached_data| {
                // 这里需要解析缓存的数据
                // 实际实现中需要正确的序列化/反序列化逻辑
                _ = cached_data;
                return Self.AllWithDB(global_db.?);
            }

            // 没有缓存，查询数据库
            const results = try Self.AllWithDB(global_db.?);

            // TODO: 实现序列化并存入缓存
            // _ = global_cache.?.set(cache_key, serialized_results, 300); // 5分钟缓存

            return results;
        }

        pub fn find(id: anytype) !?T {
            if (global_db == null) return error.NoGlobalDatabaseSet;
            if (global_cache == null) return Self.FindWithDB(global_db.?);

            const cache_key = try std.fmt.alloc(std.heap.page_allocator, "model_{s}_find_{any}", .{
                @typeName(T),
                id,
            });
            defer std.heap.page_allocator.free(cache_key);

            // 试图从缓存获取
            if (try global_cache.?.get(cache_key)) |cached_data| {
                // 解析缓存的数据
                _ = cached_data;
                return Self.FindWithDB(global_db.?);
            }

            // 没有缓存，查询数据库
            if (try Self.FindWithDB(global_db.?)) |item| {
                // TODO: 实现序列化并存入缓存
                // _ = global_cache.?.set(cache_key, serialized_item, 300); // 5分钟缓存
                return item;
            }

            return null;
        }

        pub fn count() !u64 {
            if (global_db == null) return error.NoGlobalDatabaseSet;
            if (global_cache == null) return Self.CountWithDB(global_db.?);

            const cache_key = try generateCacheKey("count");
            defer std.heap.page_allocator.free(cache_key);

            // 试图从缓存获取
            if (try global_cache.?.get(cache_key)) |cached_count_str| {
                return std.fmt.parseInt(u64, cached_count_str, 10) catch {
                    // 解析失败，直接查询数据库
                    return Self.CountWithDB(global_db.?);
                };
            }

            // 没有缓存，查询数据库
            const db_count = try Self.CountWithDB(global_db.?);

            // 将数量转换为字符串并存入缓存
            const count_str = try std.fmt.alloc(std.heap.page_allocator, "{}", .{db_count});
            defer std.heap.page_allocator.free(count_str);

            try global_cache.?.set(cache_key, count_str, 300); // 5分钟缓存

            return db_count;
        }

        // 重新定义 CRUD 操作以在变更时清理缓存
        pub fn create(data: T) !T {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            const result = try Self.CreateWithDB(global_db.?, data);

            // 创建新记录后清理缓存
            try clearModelCache();

            return result;
        }

        pub fn update(id: anytype, updates: anytype) !u64 {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            const affected = try Self.UpdateWithDB(global_db.?, id, updates);

            if (affected > 0) {
                // 更新记录后清理缓存
                try clearModelCache();
            }

            return affected;
        }

        pub fn destroy(id: anytype) !u64 {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            // 删除前先获取记录的 ID 以便精准清理缓存
            const cache_key = try std.fmt.alloc(std.heap.page_allocator, "model_{s}_find_{any}", .{
                @typeName(T),
                id,
            });
            defer std.heap.page_allocator.free(cache_key);

            const affected = try Self.DestroyWithDB(global_db.?, id);

            if (affected > 0) {
                // 删除记录后清理缓存
                try clearModelCache();

                // 也清理特定的查找缓存
                if (global_cache) |cache| {
                    try cache.del(cache_key);
                }
            }

            return affected;
        }

        pub fn updateWhere(condition: anytype, updates: anytype) !u64 {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            const affected = try Self.UpdateWhereWithDB(global_db.?, condition, updates);

            if (affected > 0) {
                // 批量更新后清理缓存
                try clearModelCache();
            }

            return affected;
        }

        pub fn deleteWhere(field: []const u8, op: []const u8, value: anytype) !u64 {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            const affected = try Self.DeleteWhereWithDB(global_db.?, field, op, value);

            if (affected > 0) {
                // 批量删除后清理缓存
                try clearModelCache();
            }

            return affected;
        }

        // 其他带缓存的方法
        pub fn first() !?T {
            if (global_db == null) return error.NoGlobalDatabaseSet;
            if (global_cache == null) return Self.FirstWithDB(global_db.?);

            // 对于first方法，我们可以缓存查询结果
            // 生成一个基于查询条件的缓存键
            const cache_key = try generateCacheKey("first");
            defer std.heap.page_allocator.free(cache_key);

            if (try global_cache.?.get(cache_key)) |cached_data| {
                _ = cached_data;
                return Self.FirstWithDB(global_db.?);
            }

            if (try Self.FirstWithDB(global_db.?)) |item| {
                // TODO: 实现序列化并存入缓存
                return item;
            }

            return null;
        }

        pub fn get() ![]T {
            if (global_db == null) return error.NoGlobalDatabaseSet;

            // 对于复杂查询，不缓存，直接执行
            return Self.GetWithDB(global_db.?);
        }

        // 带数据库参数的内部方法
        fn FindWithDB(db: *orm.Database, id: anytype) !?T {
            var query = Self.Query(db);
            defer query.deinit();
            return query.whereEq("id", id).first();
        }

        fn AllWithDB(db: *orm.Database) ![]T {
            var query = Self.Query(db);
            defer query.deinit();
            return query.get();
        }

        fn GetWithDB(db: *orm.Database) ![]T {
            var query = Self.Query(db);
            defer query.deinit();
            return query.get();
        }

        fn FirstWithDB(db: *orm.Database) !?T {
            var query = Self.Query(db);
            defer query.deinit();
            return query.first();
        }

        fn CountWithDB(db: *orm.Database) !u64 {
            var query = Self.Query(db);
            defer query.deinit();
            return query.count();
        }

        fn CreateWithDB(db: *orm.Database, data: T) !T {
            return Self.Create(db, data);
        }

        fn UpdateWithDB(db: *orm.Database, id: anytype, updates: anytype) !u64 {
            return Self.Update(db, id, updates);
        }

        fn DestroyWithDB(db: *orm.Database, id: anytype) !u64 {
            return Self.Destroy(db, id);
        }

        fn UpdateWhereWithDB(db: *orm.Database, condition: anytype, updates: anytype) !u64 {
            var query = Self.Query(db);
            defer query.deinit();
            const field_names = getFieldNames(@TypeOf(condition));
            if (field_names.len > 0) {
                return query.whereEq(field_names[0], @field(condition, field_names[0])).update(updates);
            }
            return 0;
        }

        fn DeleteWhereWithDB(db: *orm.Database, field: []const u8, op: []const u8, value: anytype) !u64 {
            var query = Self.Query(db);
            defer query.deinit();
            return query.where(field, op, value).delete();
        }

        // 辅助函数获取字段名称（简化版）
        fn getFieldNames(comptime StructType: type) []const []const u8 {
            const fields = @typeInfo(StructType).Struct.fields;
            comptime var names: [fields.len][]const u8 = undefined;
            inline for (fields, 0..) |field, i| {
                names[i] = field.name;
            }
            return &names;
        }
    };
}
