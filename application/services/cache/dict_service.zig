//! 字典管理服务
//!
//! 该服务提供：
//! - 字典数据的CRUD操作
//! - 缓存支持
//! - 字典类型的分类管理
//! - 字典项的查询和筛选

const std = @import("std");
const sql = @import("../../services/sql/orm.zig");
const CacheService = @import("../cache/cache.zig").CacheService;
const CachedQuery = @import("../cache/query_cached.zig").CachedQuery;
const Dict = @import("../../domain/entities/dict.model.zig").Dict;

pub const DictService = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    db: *sql.Database,
    cache: *CacheService,
    
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database, cache: *CacheService) DictService {
        return .{
            .allocator = allocator,
            .db = db,
            .cache = cache,
        };
    }
    
    /// 获取字典类型列表
    pub fn getDictTypes(self: *Self) ![]Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        // 使用缓存，缓存5分钟
        _ = query.withTTL(300);
        
        // 按类型分组获取
        const results = try query
            .select(&.{ "DISTINCT dict_type, dict_desc" })
            .orderBy("dict_type", .asc)
            .get();
            
        return results;
    }
    
    /// 根据字典类型获取字典项列表
    pub fn getDictByType(self: *Self, dict_type: []const u8) ![]Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        // 使用缓存，缓存5分钟
        _ = query.withTTL(300);
        
        const results = try query
            .whereEq("dict_type", dict_type)
            .whereEq("status", 1) // 只获取启用的项
            .orderBy("sort", .asc)
            .orderBy("create_time", .asc)
            .get();
            
        return results;
    }
    
    /// 根据字典类型和值获取字典项
    pub fn getDictByTypeAndValue(self: *Self, dict_type: []const u8, dict_value: []const u8) !?Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        // 为单个字典项使用较短的缓存时间
        _ = query.withTTL(120);
        
        const result = try query
            .whereEq("dict_type", dict_type)
            .whereEq("dict_value", dict_value)
            .whereEq("status", 1)
            .first();
            
        return result;
    }
    
    /// 根据字典类型和标签获取字典项
    pub fn getDictByTypeAndLabel(self: *Self, dict_type: []const u8, dict_label: []const u8) !?Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        _ = query.withTTL(120);
        
        const result = try query
            .whereEq("dict_type", dict_type)
            .whereEq("dict_label", dict_label)
            .whereEq("status", 1)
            .first();
            
        return result;
    }
    
    /// 创建字典项
    pub fn createDict(self: *Self, dict: Dict) !Dict {
        // 插入前执行业务逻辑
        var new_dict = dict;
        
        // 设置时间戳
        new_dict.create_time = std.time.timestamp();
        new_dict.update_time = std.time.timestamp();
        
        // 插入数据库
        const created = try sql.Dict.create(self.db, new_dict);
        
        // 清理相关缓存
        try self.clearDictTypeCache(dict.dict_type);
        
        return created;
    }
    
    /// 更新字典项
    pub fn updateDict(self: *Self, id: i32, updates: Dict) !u64 {
        // 获取原字典项以获取类型
        const existing_dict = try sql.Dict.findById(self.db, id);
        
        // 执行更新
        const affected = try sql.Dict.updateWhere(self.db, 
            .{ .id = id }, 
            .{
                .dict_label = updates.dict_label,
                .dict_value = updates.dict_value,
                .dict_desc = updates.dict_desc,
                .sort = updates.sort,
                .status = updates.status,
                .remark = updates.remark,
                .update_time = std.time.timestamp(),
            }
        );
        
        if (affected > 0) {
            // 如果字典类型发生了改变，清理旧的和新的缓存
            if (existing_dict) |existing| {
                if (!std.mem.eql(u8, existing.dict_type, updates.dict_type)) {
                    try self.clearDictTypeCache(existing.dict_type);
                }
            }
            try self.clearDictTypeCache(updates.dict_type);
        }
        
        return affected;
    }
    
    /// 删除字典项
    pub fn deleteDict(self: *Self, id: i32) !u64 {
        // 获取字典项以获取类型
        const dict_to_delete = try sql.Dict.findById(self.db, id);
        
        // 执行删除
        const affected = try sql.Dict.destroy(self.db, id);
        
        if (affected > 0 and dict_to_delete) |dict| {
            // 清理相关缓存
            try self.clearDictTypeCache(dict.dict_type);
        }
        
        return affected;
    }
    
    /// 批量删除字典项
    pub fn deleteDictsByType(self: *Self, dict_type: []const u8) !u64 {
        // 执行批量删除
        const affected = try sql.Dict.deleteWhere(self.db, "dict_type", "=", dict_type);
        
        // 清理相关缓存
        try self.clearDictTypeCache(dict_type);
        
        return affected;
    }
    
    /// 按状态获取字典项
    pub fn getDictByTypeAndStatus(self: *Self, dict_type: []const u8, status: i32) ![]Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        _ = query.withTTL(300);
        
        const results = try query
            .whereEq("dict_type", dict_type)
            .whereEq("status", status)
            .orderBy("sort", .asc)
            .get();
            
        return results;
    }
    
    /// 搜索字典项（模糊匹配）
    pub fn searchDict(self: *Self, dict_type: ?[]const u8, keyword: ?[]const u8) ![]Dict {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        _ = query.withTTL(300);
        
        if (dict_type) |typ| {
            _ = query.whereEq("dict_type", typ);
        }
        
        if (keyword) |kw| {
            _ = query.whereLike("dict_label", "%" ++ kw ++ "%")
                   .orWhereLike("dict_value", "%" ++ kw ++ "%")
                   .orWhereLike("dict_desc", "%" ++ kw ++ "%");
        }
        
        _ = query.whereEq("status", 1);
        _ = query.orderBy("dict_type", .asc);
        _ = query.orderBy("sort", .asc);
        
        const results = try query.get();
        return results;
    }
    
    /// 统计字典项数量
    pub fn countDictByType(self: *Self, dict_type: []const u8) !u64 {
        var query = self.createQuery();
        defer query.query_builder.deinit();
        
        _ = query.withTTL(300);
        
        const count = try query
            .whereEq("dict_type", dict_type)
            .whereEq("status", 1)
            .count();
            
        return count;
    }
    
    /// 创建缓存查询器
    fn createQuery(self: *Self) CachedQuery(sql.Dict) {
        const query_builder = sql.Dict.query(self.db);
        return CachedQuery(sql.Dict).init(query_builder, self.cache);
    }
    
    /// 清理字典类型的缓存
    fn clearDictTypeCache(self: *Self, dict_type: []const u8) !void {
        // 生成基于字典类型的缓存键前缀
        const cache_prefix = try std.fmt.alloc(self.allocator, "query_Dict_{}_{}", .{
            dict_type, "*"
        }) catch try std.fmt.alloc(self.allocator, "table_Dict_*");
        
        // 删除相关的缓存
        try self.cache.delByPrefix("table_Dict_");
        try self.cache.delByPrefix("query_Dict_");
        
        // 释放分配的内存
        if (std.mem.indexOf(u8, cache_prefix, "*")) |_| {
            self.allocator.free(cache_prefix);
        }
    }
    
    /// 获取字典项标签
    pub fn getDictLabel(self: *Self, dict_type: []const u8, dict_value: []const u8) !?[]const u8 {
        const dict_opt = try self.getDictByTypeAndValue(dict_type, dict_value);
        
        if (dict_opt) |dict| {
            return dict.dict_label;
        }
        
        return null;
    }
    
    /// 获取字典项值
    pub fn getDictValue(self: *Self, dict_type: []const u8, dict_label: []const u8) !?[]const u8 {
        const dict_opt = try self.getDictByTypeAndLabel(dict_type, dict_label);
        
        if (dict_opt) |dict| {
            return dict.dict_value;
        }
        
        return null;
    }
    
    /// 刷新字典缓存（清除所有字典相关缓存并重新加载）
    pub fn refreshDictCache(self: *Self) !void {
        // 清除所有字典相关缓存
        try self.clearDictTypeCache("");
        
        // 预加载常用字典
        const dict_types = try self.getDictTypes();
        defer self.allocator.free(dict_types);
        
        for (dict_types) |dict_type| {
            _ = try self.getDictByType(dict_type.dict_type);
        }
    }
    
    /// 验证字典值是否存在
    pub fn validateDictValue(self: *Self, dict_type: []const u8, dict_value: []const u8) !bool {
        const dict_opt = try self.getDictByTypeAndValue(dict_type, dict_value);
        return dict_opt != null;
    }
    
    /// 验证字典标签是否存在
    pub fn validateDictLabel(self: *Self, dict_type: []const u8, dict_label: []const u8) !bool {
        const dict_opt = try self.getDictByTypeAndLabel(dict_type, dict_label);
        return dict_opt != null;
    }
};

test "DictService basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 这里需要创建数据库和缓存实例
    // 由于完整测试较为复杂，这只是一个概念证明
    std.debug.print("DictService test would require database setup\n", .{});
}