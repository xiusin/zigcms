//! 字典管理控制器
//!
//! 该控制器提供：
//! - 字典类型的管理
//! - 字典项目的CRUD操作
//! - 字典数据的查询和筛选
//! - 缓存管理功能

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const CachedSql = @import("../../application/services/sql/orm_cached.zig");
const global = @import("../../shared/primitives/global.zig");
const dtos = @import("../../api/dto/mod.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const dict_service_mod = @import("../../application/services/cache/dict_service.zig");

const Self = @This();

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

// 使用 ORM 定义 Dict 模型操作
const OrmDict = sql.defineWithConfig(models.Dict, .{
    .table_name = "dicts",
    .primary_key = "id",
});

/// 获取字典类型列表
pub fn getDictTypes(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const service_manager = global.getServiceManager();
    const dict_service = service_manager.getDictService();

    const dict_types = try dict_service.getDictTypes();
    defer self.allocator.free(dict_types);

    var items = std.ArrayListUnmanaged(models.Dict){};
    defer items.deinit(self.allocator);
    for (dict_types) |dict_type| {
        items.append(self.allocator, dict_type) catch {};
    }

    base.send_ok(req, items.items);
}

/// 根据字典类型查询字典项列表
pub fn getDictByType(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const dict_type_param = req.getParamSlice("dict_type") orelse return base.send_failed(req, "缺少字典类型参数");

    const service_manager = global.getServiceManager();
    const dict_service = service_manager.getDictService();

    const dicts = try dict_service.getDictByType(dict_type_param);
    defer self.allocator.free(dicts);

    var items = std.ArrayListUnmanaged(models.Dict){};
    defer items.deinit(self.allocator);
    for (dicts) |dict| {
        items.append(self.allocator, dict) catch {};
    }

    base.send_ok(req, items.items);
}

/// 创建字典项
pub fn saveDict(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");

    const body = req.body orelse return base.send_failed(req, "请求体为空");

    // 解析请求体
    var dict_data = json_mod.JSON.decode(models.Dict, self.allocator, body) catch |err| {
        std.log.err("解析字典数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };
    defer models.Dict.deinit(&dict_data, self.allocator);

    // 验证必要字段
    if (dict_data.dict_type.len == 0 or dict_data.dict_label.len == 0 or dict_data.dict_value.len == 0) {
        return base.send_failed(req, "字典类型、标签和值不能为空");
    }

    const service_manager = global.getServiceManager();
    const dict_service = service_manager.getDictService();

    // 检查是否重复
    const existing_by_value = try dict_service.getDictByTypeAndValue(dict_data.dict_type, dict_data.dict_value);
    if (existing_by_value != null) {
        return base.send_failed(req, "相同字典类型下已存在相同的字典值");
    }

    const existing_by_label = try dict_service.getDictByTypeAndLabel(dict_data.dict_type, dict_data.dict_label);
    if (existing_by_label != null) {
        return base.send_failed(req, "相同字典类型下已存在相同的字典标签");
    }

    var result: models.Dict = undefined;
    if (dict_data.id) |id| {
        // 更新操作
        if (id > 0) {
            const affected = try dict_service.updateDict(@intCast(id), dict_data);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }

            // 重新获取更新后的数据
            const updated_dict = try dict_service.getDictByTypeAndValue(dict_data.dict_type, dict_data.dict_value);
            if (updated_dict) |dict| {
                result = dict;
            } else {
                return base.send_failed(req, "获取更新后的数据失败");
            }
        } else {
            // 插入操作，尽管ID为0或负数
            result = try dict_service.createDict(dict_data);
        }
    } else {
        // 插入操作
        result = try dict_service.createDict(dict_data);
    }

    return base.send_ok(req, result);
}

/// 获取字典项详情
pub fn getDict(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少ID参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "ID格式错误"));

    // 直接从ORM获取，因为有ID
    const item_opt = OrmDict.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "字典项不存在");
    }

    var item = item_opt.?;
    defer OrmDict.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

/// 删除字典项
pub fn deleteDict(_: *Self, req: zap.Request) !void {
    req.parseQuery();

    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少ID参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "ID格式错误"));

    const service_manager = global.getServiceManager();
    const dict_svc = service_manager.getDictService();

    const affected = try dict_svc.deleteDict(id);
    if (affected == 0) {
        return base.send_failed(req, "删除失败");
    }

    return base.send_ok(req, affected);
}

/// 搜索字典项
pub fn searchDict(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var dict_type: ?[]const u8 = null;
    var keyword: ?[]const u8 = null;

    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "dict_type")) {
            dict_type = value.value;
        } else if (strings.eql(value.key, "keyword")) {
            keyword = value.value;
        }
    }

    const service_manager = global.getServiceManager();
    const dict_service = service_manager.getDictService();

    const results = try dict_service.searchDict(dict_type, keyword);
    defer self.allocator.free(results);

    var items = std.ArrayListUnmanaged(models.Dict){};
    defer items.deinit(self.allocator);
    for (results) |result| {
        items.append(self.allocator, result) catch {};
    }

    base.send_ok(req, items.items);
}

/// 统计字典项数量
pub fn countDict(_: *Self, req: zap.Request) !void {
    req.parseQuery();

    const dict_type_param = req.getParamSlice("dict_type") orelse return base.send_failed(req, "缺少字典类型参数");

    const service_manager = global.getServiceManager();
    const dict_svc = service_manager.getDictService();

    const count = try dict_svc.countDictByType(dict_type_param);

    base.send_ok(req, .{ .count = count });
}

/// 获取字典项标签
pub fn getDictLabel(_: *Self, req: zap.Request) !void {
    req.parseQuery();

    const dict_type = req.getParamSlice("dict_type") orelse return base.send_failed(req, "缺少字典类型参数");
    const dict_value = req.getParamSlice("dict_value") orelse return base.send_failed(req, "缺少字典值参数");

    const service_manager = global.getServiceManager();
    const dict_svc = service_manager.getDictService();

    if (try dict_svc.getDictLabel(dict_type, dict_value)) |label| {
        base.send_ok(req, .{ .label = label });
    } else {
        base.send_failed(req, "未找到对应的字典项");
    }
}

/// 验证字典值是否存在
pub fn validateDictValue(_: *Self, req: zap.Request) !void {
    req.parseQuery();

    const dict_type = req.getParamSlice("dict_type") orelse return base.send_failed(req, "缺少字典类型参数");
    const dict_value = req.getParamSlice("dict_value") orelse return base.send_failed(req, "缺少字典值参数");

    const service_manager = global.getServiceManager();
    const dict_svc = service_manager.getDictService();

    const exists = try dict_svc.validateDictValue(dict_type, dict_value);

    base.send_ok(req, .{ .exists = exists });
}

/// 刷新字典缓存
pub fn refreshCache(_: *Self, req: zap.Request) !void {
    const service_manager = global.getServiceManager();
    const dict_svc = service_manager.getDictService();

    try dict_svc.refreshDictCache();

    base.send_ok(req, .{ .message = "字典缓存已刷新" });
}

/// 获取缓存状态
pub fn getCacheStats(_: *Self, req: zap.Request) !void {
    const service_manager = global.getServiceManager();
    const stats = service_manager.getCacheStats();

    base.send_ok(req, .{ .cache_items = stats.count, .expired_items = stats.expired, .message = "缓存统计数据" });
}

/// 清理过期缓存
pub fn cleanupCache(_: *Self, req: zap.Request) !void {
    const service_manager = global.getServiceManager();

    try service_manager.cleanupExpiredCache();

    base.send_ok(req, .{ .message = "过期缓存已清理" });
}
