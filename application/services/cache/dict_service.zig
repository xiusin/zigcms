//! 字典管理服务
//!
//! 该服务提供：
//! - 字典数据的CRUD操作
//! - 缓存支持
//! - 字典类型的分类管理
//! - 字典项的查询和筛选

const std = @import("std");
const CacheService = @import("cache.zig").CacheService;
const Dict = @import("../../../domain/entities/dict.model.zig").Dict;
const sql = @import("../sql/orm.zig");
const models = @import("../../../domain/entities/models.zig");

// 定义 Dict ORM 模型
const DictOrm = sql.defineWithConfig(models.Dict, .{
    .table_name = "sys_dict",
    .primary_key = "id",
});

pub const DictService = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    db: *sql.Database,
    cache: *CacheService,

    pub fn init(allocator: std.mem.Allocator, db: *sql.Database, cache: *CacheService) DictService {
        // 设置数据库连接
        if (!DictOrm.hasDb()) {
            DictOrm.use(db);
        }

        return .{
            .allocator = allocator,
            .db = db,
            .cache = cache,
        };
    }

    /// 获取字典类型列表
    pub fn getDictTypes(self: *Self) ![]Dict {
        // TODO: 实现去重查询（DISTINCT dict_type）
        const results = try DictOrm.all(self.db);
        return results;
    }

    /// 根据字典类型获取字典项列表
    pub fn getDictByType(self: *Self, dict_type: []const u8) ![]Dict {
        const cache_key = try std.fmt.allocPrint(self.allocator, "dict:type:{s}", .{dict_type});
        defer self.allocator.free(cache_key);

        // 尝试从缓存获取
        if (try self.cache.get(cache_key)) |_| {
            // TODO: 反序列化缓存数据
        }

        // 从数据库查询 - 使用 where 条件
        var query = DictOrm.query(self.db);
        defer query.deinit();

        const results = try query
            .whereEq("dict_type", dict_type)
            .whereEq("status", 1)
            .orderBy("sort", .asc)
            .get();

        return results;
    }

    /// 根据类型和值获取字典项
    pub fn getDictByTypeAndValue(self: *Self, dict_type: []const u8, dict_value: []const u8) !?Dict {
        var query = DictOrm.query(self.db);
        defer query.deinit();

        const results = try query
            .whereEq("dict_type", dict_type)
            .whereEq("dict_value", dict_value)
            .whereEq("status", 1)
            .limit(1)
            .get();

        if (results.len > 0) {
            return results[0];
        }
        return null;
    }

    /// 根据类型和标签获取字典项
    pub fn getDictByTypeAndLabel(self: *Self, dict_type: []const u8, dict_label: []const u8) !?Dict {
        var query = DictOrm.query(self.db);
        defer query.deinit();

        const results = try query
            .whereEq("dict_type", dict_type)
            .whereEq("dict_label", dict_label)
            .whereEq("status", 1)
            .limit(1)
            .get();

        if (results.len > 0) {
            return results[0];
        }
        return null;
    }

    /// 获取字典项详情
    pub fn getDictById(self: *Self, id: i32) !?Dict {
        _ = self;
        return try DictOrm.find(id);
    }

    /// 创建字典项
    pub fn createDict(self: *Self, dict: Dict) !Dict {
        const result = try DictOrm.create(dict);

        // 清理相关缓存
        try self.clearDictCache(dict.dict_type);

        return result;
    }

    /// 更新字典项
    pub fn updateDict(self: *Self, id: i32, dict: Dict) !u64 {
        const affected = try DictOrm.updateById(id, dict);

        // 清理相关缓存
        try self.clearDictCache(dict.dict_type);

        return affected;
    }

    /// 删除字典项
    pub fn deleteDict(self: *Self, id: i32) !u64 {
        // 先获取字典项信息以清理缓存
        const dict_opt = try self.getDictById(id);

        const affected = try DictOrm.destroy(id);

        // 清理相关缓存
        if (dict_opt) |dict| {
            try self.clearDictCache(dict.dict_type);
        }

        return affected;
    }

    /// 搜索字典项
    pub fn searchDict(self: *Self, dict_type: ?[]const u8, keyword: ?[]const u8) ![]Dict {
        var query = DictOrm.query(self.db);
        defer query.deinit();

        _ = query.whereEq("status", 1);

        if (dict_type) |dt| {
            _ = query.whereEq("dict_type", dt);
        }

        if (keyword) |kw| {
            const like_pattern = try std.fmt.allocPrint(self.allocator, "%{s}%", .{kw});
            defer self.allocator.free(like_pattern);

            _ = query.where("dict_label", "LIKE", like_pattern);
        }

        return try query
            .orderBy("dict_type", .asc)
            .orderBy("sort", .asc)
            .get();
    }

    /// 统计字典项数量
    pub fn countDictByType(self: *Self, dict_type: []const u8) !u64 {
        var query = DictOrm.query(self.db);
        defer query.deinit();

        return try query
            .whereEq("dict_type", dict_type)
            .whereEq("status", 1)
            .count();
    }

    /// 刷新字典缓存
    pub fn refreshDictCache(self: *Self) !void {
        // 清理所有字典缓存
        try self.cache.delByPrefix("dict:");
        std.log.info("字典缓存已刷新", .{});
    }

    /// 获取字典项标签
    pub fn getDictLabel(self: *Self, dict_type: []const u8, dict_value: []const u8) !?[]const u8 {
        const dict_opt = try self.getDictByTypeAndValue(dict_type, dict_value);
        if (dict_opt) |dict| {
            return dict.dict_label;
        }
        return null;
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

    /// 清理特定类型的字典缓存
    fn clearDictCache(self: *Self, dict_type: []const u8) !void {
        // 清理类型列表缓存
        try self.cache.del("dict:types");

        // 清理特定类型的缓存
        const type_key = try std.fmt.allocPrint(self.allocator, "dict:type:{s}", .{dict_type});
        defer self.allocator.free(type_key);
        try self.cache.del(type_key);
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

test "DictService basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;
    std.debug.print("DictService test would require database setup\n", .{});
}
