//! 缓存 ORM - 在原有 ORM 基础上增加缓存功能
//!
//! 该模块提供：
//! - 带有缓存功能的模型定义
//! - 自动缓存查询结果
//! - 自动清理关联缓存

const std = @import("std");
const orm = @import("orm.zig");
const CacheService = @import("../cache/cache.zig").CacheService;

/// 序列化配置
pub const SerializeOptions = struct {
    /// 缓存过期时间（秒）
    ttl: u64 = 300,
    /// 是否压缩（预留）
    compress: bool = false,
};

/// 序列化 T 为 JSON 字节数组
fn serialize(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var list = std.ArrayList(u8).initCapacity(allocator, 512);
    errdefer list.deinit();
    try std.json.stringify(list.writer(), value, .{});
    return list.toOwnedSlice();
}

/// 反序列化 JSON 字节数组为 T
fn deserialize(comptime T: type, allocator: std.mem.Allocator, data: []const u8) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, data, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// 序列化数组为 JSON 字节数组
fn serializeSlice(allocator: std.mem.Allocator, comptime T: type, slice: []const T) ![]u8 {
    var list = std.ArrayList(u8).initCapacity(allocator, 1024);
    errdefer list.deinit();
    try list.append('[');
    for (slice, 0..) |item, i| {
        if (i > 0) try list.append(',');
        try std.json.stringify(list.writer(), item, .{});
    }
    try list.append(']');
    return list.toOwnedSlice();
}

/// 反序列化 JSON 字节数组为 T 数组
fn deserializeSlice(comptime T: type, allocator: std.mem.Allocator, data: []const u8) ![]T {
    const Value = std.json.Value;
    const parsed = try std.json.parseFromSlice(Value, allocator, data, .{});
    defer parsed.deinit();

    if (parsed.value != .array) {
        return error.InvalidJsonArray;
    }

    const json_array = parsed.value.array;
    var result = std.ArrayList(T).init(allocator);
    errdefer {
        for (result.items) |item| {
            freeValue(T, allocator, item);
        }
        result.deinit();
    }

    for (json_array.items) |json_value| {
        const item = try jsonValueToType(T, allocator, json_value);
        try result.append(item);
    }

    return result.toOwnedSlice();
}

/// 释放 JSON 值占用的内存
fn freeValue(comptime T: type, allocator: std.mem.Allocator, value: T) void {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |s| {
            inline for (s.fields) |field| {
                freeFieldValue(field.type, allocator, @field(value, field.name));
            }
        },
        .Array => |a| {
            for (value) |item| {
                freeFieldValue(a.child, allocator, item);
            }
        },
        .Pointer => |p| {
            if (p.size == .Slice and p.child == u8) {
                allocator.free(value);
            }
        },
        else => {},
    }
}

/// 释放字段值
fn freeFieldValue(comptime T: type, allocator: std.mem.Allocator, value: T) void {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |s| {
            inline for (s.fields) |field| {
                freeFieldValue(field.type, allocator, @field(value, field.name));
            }
        },
        .Array => |a| {
            for (value) |item| {
                freeFieldValue(a.child, allocator, item);
            }
        },
        .Pointer => |p| {
            if (p.size == .Slice and p.child == u8) {
                allocator.free(value);
            }
        },
        else => {},
    }
}

/// 将 JSON 值转换为指定类型
fn jsonValueToType(comptime T: type, allocator: std.mem.Allocator, value: std.json.Value) !T {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => {
            if (value != .object) return error.InvalidJsonType;
            var result: T = undefined;
            const fields = info.Struct.fields;
            inline for (fields) |field| {
                const field_value = value.object.get(field.name) orelse .null;
                @field(result, field.name) = try jsonValueToType(field.type, allocator, field_value);
            }
            return result;
        },
        .Int, .Float => {
            if (value == .integer) return @as(T, @intCast(value.integer));
            if (value == .float) return @as(T, @floatCast(value.float));
            if (value == .null) return 0;
            return error.InvalidJsonType;
        },
        .Bool => {
            if (value == .bool) return value.bool;
            return false;
        },
        .Pointer => |p| {
            if (p.size == .Slice and p.child == u8) {
                if (value == .string) {
                    return try allocator.dupe(u8, value.string);
                }
                if (value == .null) return "";
                return error.InvalidJsonType;
            }
            return error.UnsupportedPointerType;
        },
        .Optional => |o| {
            if (value == .null) return null;
            return try jsonValueToType(o.child, allocator, value);
        },
        else => return error.UnsupportedType,
    }
}

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
                // 反序列化缓存的数据
                const results = deserializeSlice(T, std.heap.page_allocator, cached_data) catch {
                    // 反序列化失败，重新查询数据库
                    return Self.AllWithDB(global_db.?);
                };
                return results;
            }

            // 没有缓存，查询数据库
            const results = try Self.AllWithDB(global_db.?);

            // 序列化并存入缓存
            const serialized = serializeSlice(std.heap.page_allocator, T, results) catch {
                // 序列化失败，不缓存直接返回
                return results;
            };
            defer std.heap.page_allocator.free(serialized);

            // 异步设置缓存（忽略错误）
            global_cache.?.set(cache_key, serialized, 300) catch {};

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
                // 反序列化缓存的数据
                const item = deserialize(T, std.heap.page_allocator, cached_data) catch {
                    // 反序列化失败，重新查询数据库
                    return Self.FindWithDB(global_db.?);
                };
                return item;
            }

            // 没有缓存，查询数据库
            if (try Self.FindWithDB(global_db.?)) |item| {
                // 序列化并存入缓存
                const serialized = serialize(std.heap.page_allocator, item) catch {
                    // 序列化失败，直接返回
                    return item;
                };
                defer std.heap.page_allocator.free(serialized);

                // 异步设置缓存（忽略错误）
                global_cache.?.set(cache_key, serialized, 300) catch {};

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
                // 反序列化缓存的数据
                const item = deserialize(T, std.heap.page_allocator, cached_data) catch {
                    // 反序列化失败，重新查询数据库
                    return Self.FirstWithDB(global_db.?);
                };
                return item;
            }

            if (try Self.FirstWithDB(global_db.?)) |item| {
                // 序列化并存入缓存
                const serialized = serialize(std.heap.page_allocator, item) catch {
                    // 序列化失败，直接返回
                    return item;
                };
                defer std.heap.page_allocator.free(serialized);

                // 异步设置缓存（忽略错误）
                global_cache.?.set(cache_key, serialized, 300) catch {};

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
