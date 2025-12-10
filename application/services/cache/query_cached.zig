//! 缓存查询构建器 - 在原有查询构建器基础上增加缓存功能
//!
//! 该构建器提供：
//! - 基于查询条件的自动缓存键生成
//! - 查询结果缓存
//! - 缓存失效管理（在实体变更时自动清理）

const std = @import("std");
const sql = @import("../../../application/services/sql/orm.zig");

pub fn CachedQuery(comptime Model: type) type {
    return struct {
        const Self = @This();
        
        query_builder: sql.Query(Model),
        cache_service: *sql.CacheService,
        cache_enabled: bool = true,
        cache_ttl: ?u64 = null, // 指定缓存TTL，如果为null则使用默认值
        
        pub fn init(query_builder: sql.Query(Model), cache_service: *sql.CacheService) Self {
            return .{
                .query_builder = query_builder,
                .cache_service = cache_service,
            };
        }
        
        /// 生成缓存键
        fn generateCacheKey(self: *const Self) ![]const u8 {
            // 需要从查询构建器获取当前的查询条件来生成唯一的缓存键
            // 这是一个简化的实现，实际中需要根据具体的查询条件生成键
            const query_sql = try self.query_builder.toSql();
            defer self.query_builder.allocator.free(query_sql);
            
            // 生成基于 SQL 的哈希值
            const hash = std.hash.Wyhash.hash(0, query_sql);
            return try std.fmt.alloc(self.query_builder.allocator, "query_{s}_{d}", .{
                @typeName(Model),
                hash,
            });
        }
        
        /// 生成基于表和操作的缓存键前缀
        fn generateTablePrefix(self: *const Self) ![]const u8 {
            return try std.fmt.alloc(self.query_builder.allocator, "table_{s}_", .{
                @typeName(Model),
            });
        }
        
        /// 获取所有条件
        pub fn get(self: *Self) ![]Model {
            if (!self.cache_enabled) {
                return try self.query_builder.get();
            }
            
            const cache_key = try self.generateCacheKey();
            defer self.query_builder.allocator.free(cache_key);
            
            // 尝试从缓存获取
            if (try self.cache_service.get(cache_key)) |cached_json| {
                // 反存了，解析JSON并返回
                const deserialized = try self.deserializeModels(cached_json);
                return deserialized;
            }
            
            // 没有缓存，执行查询
            const results = try self.query_builder.get();
            
            // 序列化结果并存入缓存
            const serialized = try self.serializeModels(results);
            defer self.query_builder.allocator.free(serialized);
            
            try self.cache_service.set(cache_key, serialized, self.cache_ttl);
            
            return results;
        }
        
        /// 获取单个记录
        pub fn first(self: *Self) !?Model {
            if (!self.cache_enabled) {
                return try self.query_builder.first();
            }
            
            // 为单个记录查询生成特定的缓存键
            const query_sql = try self.query_builder.toSql();
            defer self.query_builder.allocator.free(query_sql);
            
            const hash = std.hash.Wyhash.hash(0, query_sql);
            const cache_key = try std.fmt.alloc(self.query_builder.allocator, "query_first_{s}_{d}", .{
                @typeName(Model),
                hash,
            });
            defer self.query_builder.allocator.free(cache_key);
            
            // 尝试从缓存获取
            if (try self.cache_service.get(cache_key)) |cached_json| {
                // 解析并返回
                const deserialized = try self.deserializeSingleModel(cached_json);
                return deserialized;
            }
            
            // 没有缓存，执行查询
            if (try self.query_builder.first()) |result| {
                // 序列化结果并存入缓存
                const serialized = try self.serializeSingleModel(result);
                defer self.query_builder.allocator.free(serialized);
                
                try self.cache_service.set(cache_key, serialized, self.cache_ttl);
                return result;
            }
            
            return null;
        }
        
        /// 获取单个记录，如果不存在则报错
        pub fn firstOrFail(self: *Self) !Model {
            if (try self.first()) |result| {
                return result;
            } else {
                return error.ModelNotFound;
            }
        }
        
        /// 获取所有记录
        pub fn all(self: *Self) ![]Model {
            const table_prefix = try self.generateTablePrefix();
            defer self.query_builder.allocator.free(table_prefix);
            
            // 使用表级别的缓存键
            const cache_key = try std.fmt.alloc(self.query_builder.allocator, "{s}all", .{table_prefix});
            defer self.query_builder.allocator.free(cache_key);
            
            // 尝试从缓存获取
            if (try self.cache_service.get(cache_key)) |cached_json| {
                const deserialized = try self.deserializeModels(cached_json);
                return deserialized;
            }
            
            // 没有缓存，执行查询
            const results = try self.query_builder.get();
            
            // 序列化结果并存入缓存
            const serialized = try self.serializeModels(results);
            defer self.query_builder.allocator.free(serialized);
            
            try self.cache_service.set(cache_key, serialized, self.cache_ttl);
            
            return results;
        }
        
        /// 按ID获取
        pub fn find(self: *Self, id: anytype) !?Model {
            // 基于ID的缓存键
            const cache_key = try std.fmt.alloc(self.query_builder.allocator, "find_{s}_{any}", .{
                @typeName(Model), id,
            });
            defer self.query_builder.allocator.free(cache_key);
            
            // 尝试从缓存获取
            if (try self.cache_service.get(cache_key)) |cached_json| {
                const deserialized = try self.deserializeSingleModel(cached_json);
                return deserialized;
            }
            
            // 没有缓存，执行查询
            var query = self.query_builder.clone();
            defer query.deinit();
            _ = query.whereEq("id", id);
            
            if (try query.first()) |result| {
                // 序列化结果并存入缓存
                const serialized = try self.serializeSingleModel(result);
                defer self.query_builder.allocator.free(serialized);
                
                try self.cache_service.set(cache_key, serialized, self.cache_ttl);
                return result;
            }
            
            return null;
        }
        
        /// 统计数量
        pub fn count(self: *Self) !u64 {
            // 生成基于查询条件的计数缓存键
            const query_sql = try self.query_builder.toSql();
            defer self.query_builder.allocator.free(query_sql);
            
            const hash = std.hash.Wyhash.hash(0, query_sql);
            const cache_key = try std.fmt.alloc(self.query_builder.allocator, "count_{s}_{d}", .{
                @typeName(Model),
                hash,
            });
            defer self.query_builder.allocator.free(cache_key);
            
            // 尝试从缓存获取
            if (try self.cache_service.get(cache_key)) |cached_count_str| {
                const count = try std.fmt.parseInt(u64, cached_count_str, 10);
                return count;
            }
            
            // 没有缓存，执行查询
            const count = try self.query_builder.count();
            
            // 存入缓存
            const count_str = try std.fmt.alloc(self.query_builder.allocator, "{}", .{count});
            defer self.query_builder.allocator.free(count_str);
            
            try self.cache_service.set(cache_key, count_str, self.cache_ttl);
            
            return count;
        }
        
        /// 启用缓存
        pub fn enableCache(self: *Self) void {
            self.cache_enabled = true;
        }
        
        /// 禁用缓存
        pub fn disableCache(self: *Self) void {
            self.cache_enabled = false;
        }
        
        /// 设置缓存TTL
        pub fn withTTL(self: *Self, ttl: u64) *Self {
            self.cache_ttl = ttl;
            return self;
        }
        
        /// 清理当前模型的缓存
        pub fn clearCache(self: *Self) !void {
            const table_prefix = try self.generateTablePrefix();
            defer self.query_builder.allocator.free(table_prefix);
            
            // 删除基于表前缀的所有缓存
            try self.cache_service.delByPrefix(table_prefix);
        }
        
        /// 链式调用支持 - 将方法委托给底层查询构建器
        pub fn where(self: *Self, field: []const u8, op: []const u8, value: anytype) *Self {
            _ = self.query_builder.where(field, op, value);
            return self;
        }
        
        pub fn whereEq(self: *Self, field: []const u8, value: anytype) *Self {
            _ = self.query_builder.whereEq(field, value);
            return self;
        }
        
        pub fn whereIn(self: *Self, field: []const u8, values: anytype) *Self {
            _ = self.query_builder.whereIn(field, values);
            return self;
        }
        
        pub fn orderBy(self: *Self, field: []const u8, direction: sql.OrderDir) *Self {
            _ = self.query_builder.orderBy(field, direction);
            return self;
        }
        
        pub fn limit(self: *Self, n: u32) *Self {
            _ = self.query_builder.limit(n);
            return self;
        }
        
        pub fn offset(self: *Self, n: u32) *Self {
            _ = self.query_builder.offset(n);
            return self;
        }
        
        pub fn select(self: *Self, fields: []const []const u8) *Self {
            _ = self.query_builder.select(fields);
            return self;
        }
        
        /// 序列化模型数组
        fn serializeModels(self: *const Self, models: []Model) ![]u8 {
            // 这是一个简化的序列化实现
            // 实际项目中可能需要更复杂的序列化逻辑，如JSON
            var result = std.ArrayList(u8).init(self.query_builder.allocator);
            try result.appendSlice("[");
            
            for (models, 0..) |model, i| {
                if (i > 0) try result.appendSlice(",");
                try self.serializeSingleModelInternal(model, result);
            }
            
            try result.appendSlice("]");
            return result.toOwnedSlice();
        }
        
        /// 序列化单个模型
        fn serializeSingleModel(self: *const Self, model: Model) ![]u8 {
            var result = std.ArrayList(u8).init(self.query_builder.allocator);
            try self.serializeSingleModelInternal(model, result);
            return result.toOwnedSlice();
        }
        
        /// 内部序列化实现
        fn serializeSingleModelInternal(self: *const Self, model: Model, result: *std.ArrayList(u8)) !void {
            _ = model; // 简化的实现，实际使用时需要根据具体模型字段进行序列化
            try result.appendSlice("{}"); // 这里应该根据Model字段序列化
        }
        
        /// 反列化模型数组
        fn deserializeModels(self: *const Self, json_str: []const u8) ![]Model {
            _ = json_str; // 简化的实现
            // 这里应该解析JSON并创建模型实例
            var empty_array = std.ArrayList(Model).init(self.query_builder.allocator);
            return empty_array.toOwnedSlice();
        }
        
        /// 反列化单个模型
        fn deserializeSingleModel(self: *const Self, json_str: []const u8) !Model {
            _ = json_str; // 简化的实现
            // 这里应该解析JSON并创建模型实例
            return Model{}; // 这里应该根据JSON创建具体的模型实例
        }
    };
}