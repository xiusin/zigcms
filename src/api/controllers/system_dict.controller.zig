/// 系统字典控制器
const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const models = @import("../../domain/entities/sys_dict.model.zig");
const zigcms = @import("root");

pub const Dict = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Dict {
        return .{ .allocator = allocator };
    }
    
    /// 获取字典列表
    pub fn list(self: *Dict, req: zap.Request) !void {
        const page = req.getParamInt("page") orelse 1;
        const page_size = req.getParamInt("page_size") orelse 20;
        const keyword = req.getParam("keyword");
        const category = req.getParam("category");
        
        const service_mgr = zigcms.getServiceManager() orelse return error.ServiceManagerNotInitialized;
        const db = service_mgr.getDatabase();
        
        // 构建查询
        const OrmDict = @import("root").Orm(models.SysDict, "sys_dict");
        var q = OrmDict.Query();
        defer q.deinit();
        
        // 搜索条件
        if (keyword) |kw| {
            if (kw.len > 0) {
                var params = @import("root").ParamBuilder.init(self.allocator);
                defer params.deinit();
                
                const search_pattern = try std.fmt.allocPrint(self.allocator, "%{s}%", .{kw});
                defer self.allocator.free(search_pattern);
                
                try params.add(search_pattern);
                try params.add(search_pattern);
                
                _ = q.whereRaw("(dict_name LIKE ? OR dict_code LIKE ?)", params);
            }
        }
        
        // 分类筛选
        if (category) |cat| {
            if (cat.len > 0) {
                _ = q.where("category_code", "=", cat);
            }
        }
        
        // 排序
        _ = q.orderBy("id", "DESC");
        
        // 分页
        const offset = (page - 1) * page_size;
        _ = q.limit(page_size).offset(offset);
        
        // 执行查询
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        
        // 统计总数
        var count_q = OrmDict.Query();
        defer count_q.deinit();
        
        if (keyword) |kw| {
            if (kw.len > 0) {
                var params = @import("root").ParamBuilder.init(self.allocator);
                defer params.deinit();
                
                const search_pattern = try std.fmt.allocPrint(self.allocator, "%{s}%", .{kw});
                defer self.allocator.free(search_pattern);
                
                try params.add(search_pattern);
                try params.add(search_pattern);
                
                _ = count_q.whereRaw("(dict_name LIKE ? OR dict_code LIKE ?)", params);
            }
        }
        
        if (category) |cat| {
            if (cat.len > 0) {
                _ = count_q.where("category_code", "=", cat);
            }
        }
        
        const total = try count_q.count();
        
        // 返回结果
        try base.send_success(req, .{
            .list = result.items(),
            .total = total,
            .page = page,
            .page_size = page_size,
        });
        
        _ = db;
    }
    
    /// 保存字典（新增/编辑）
    pub fn save(self: *Dict, req: zap.Request) !void {
        const body = try req.parseJsonBody();
        const obj = body.object;
        
        const id = if (obj.get("id")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null;
        const category_code = if (obj.get("category_code")) |v| if (v == .string) v.string else "" else "";
        const dict_name = if (obj.get("dict_name")) |v| if (v == .string) v.string else "" else "";
        const dict_code = if (obj.get("dict_code")) |v| if (v == .string) v.string else "" else "";
        const remark = if (obj.get("remark")) |v| if (v == .string) v.string else "" else "";
        const status = if (obj.get("status")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else 1 else 1;
        
        // 验证必填字段
        if (category_code.len == 0 or dict_name.len == 0 or dict_code.len == 0) {
            return base.send_error(req, "分类、名称和编码不能为空", 400);
        }
        
        // 获取分类名称
        const category_name = try self.getCategoryName(category_code);
        defer self.allocator.free(category_name);
        
        const OrmDict = @import("root").Orm(models.SysDict, "sys_dict");
        
        if (id) |dict_id| {
            // 更新
            _ = try OrmDict.UpdateWith(dict_id, .{
                .category_code = category_code,
                .category_name = category_name,
                .dict_name = dict_name,
                .dict_code = dict_code,
                .remark = remark,
                .status = status,
                .updated_at = std.time.milliTimestamp(),
            });
            
            try base.send_success(req, .{ .message = "更新成功" });
        } else {
            // 新增
            const dict = models.SysDict{
                .category_code = category_code,
                .category_name = category_name,
                .dict_name = dict_name,
                .dict_code = dict_code,
                .remark = remark,
                .status = status,
                .created_at = std.time.milliTimestamp(),
            };
            
            const created = try OrmDict.Create(dict);
            try base.send_success(req, .{ .id = created.id });
        }
    }
    
    /// 删除字典
    pub fn delete(self: *Dict, req: zap.Request) !void {
        const id = req.getParamInt("id") orelse return base.send_error(req, "缺少ID参数", 400);
        
        const OrmDict = @import("root").Orm(models.SysDict, "sys_dict");
        try OrmDict.Delete(id);
        
        // 同时删除字典项
        const OrmDictItem = @import("root").Orm(models.SysDictItem, "sys_dict_item");
        var q = OrmDictItem.Query();
        defer q.deinit();
        
        _ = q.where("dict_id", "=", id);
        const dict_items = try q.get();
        defer OrmDictItem.freeModels(dict_items);
        
        for (dict_items) |item| {
            if (item.id) |item_id| {
                try OrmDictItem.Delete(item_id);
            }
        }
        
        try base.send_success(req, .{ .message = "删除成功" });
        
        _ = self;
    }
    
    /// 设置字段值
    pub fn set(self: *Dict, req: zap.Request) !void {
        const body = try req.parseJsonBody();
        const obj = body.object;
        
        const id = if (obj.get("id")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else return base.send_error(req, "缺少ID", 400) else return base.send_error(req, "缺少ID", 400);
        const field = if (obj.get("field")) |v| if (v == .string) v.string else return base.send_error(req, "缺少字段名", 400) else return base.send_error(req, "缺少字段名", 400);
        const value = if (obj.get("value")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else 0 else 0;
        
        const OrmDict = @import("root").Orm(models.SysDict, "sys_dict");
        
        if (std.mem.eql(u8, field, "status")) {
            _ = try OrmDict.UpdateWith(id, .{
                .status = value,
                .updated_at = std.time.milliTimestamp(),
            });
        }
        
        try base.send_success(req, .{ .message = "更新成功" });
        
        _ = self;
    }
    
    /// 获取字典项列表
    pub fn items(self: *Dict, req: zap.Request) !void {
        const dict_id = req.getParamInt("dict_id") orelse return base.send_error(req, "缺少字典ID", 400);
        
        const OrmDictItem = @import("root").Orm(models.SysDictItem, "sys_dict_item");
        var q = OrmDictItem.Query();
        defer q.deinit();
        
        _ = q.where("dict_id", "=", dict_id).orderBy("sort", "ASC").orderBy("id", "ASC");
        
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();
        
        try base.send_success(req, .{
            .list = result.items(),
        });
    }
    
    /// 保存字典项
    pub fn itemSave(self: *Dict, req: zap.Request) !void {
        const body = try req.parseJsonBody();
        const obj = body.object;
        
        const id = if (obj.get("id")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null;
        const dict_id = if (obj.get("dict_id")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else return base.send_error(req, "缺少字典ID", 400) else return base.send_error(req, "缺少字典ID", 400);
        const item_name = if (obj.get("item_name")) |v| if (v == .string) v.string else "" else "";
        const item_value = if (obj.get("item_value")) |v| if (v == .string) v.string else "" else "";
        const sort = if (obj.get("sort")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else 0 else 0;
        const status = if (obj.get("status")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else 1 else 1;
        
        if (item_name.len == 0 or item_value.len == 0) {
            return base.send_error(req, "名称和值不能为空", 400);
        }
        
        const OrmDictItem = @import("root").Orm(models.SysDictItem, "sys_dict_item");
        
        if (id) |item_id| {
            // 更新
            _ = try OrmDictItem.UpdateWith(item_id, .{
                .item_name = item_name,
                .item_value = item_value,
                .sort = sort,
                .status = status,
                .updated_at = std.time.milliTimestamp(),
            });
            
            try base.send_success(req, .{ .message = "更新成功" });
        } else {
            // 新增
            const item = models.SysDictItem{
                .dict_id = dict_id,
                .item_name = item_name,
                .item_value = item_value,
                .sort = sort,
                .status = status,
                .created_at = std.time.milliTimestamp(),
            };
            
            const created = try OrmDictItem.Create(item);
            try base.send_success(req, .{ .id = created.id });
        }
        
        _ = self;
    }
    
    /// 删除字典项
    pub fn itemDelete(self: *Dict, req: zap.Request) !void {
        const id = req.getParamInt("id") orelse return base.send_error(req, "缺少ID参数", 400);
        
        const OrmDictItem = @import("root").Orm(models.SysDictItem, "sys_dict_item");
        try OrmDictItem.Delete(id);
        
        try base.send_success(req, .{ .message = "删除成功" });
        
        _ = self;
    }
    
    /// 设置字典项字段值
    pub fn itemSet(self: *Dict, req: zap.Request) !void {
        const body = try req.parseJsonBody();
        const obj = body.object;
        
        const id = if (obj.get("id")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else return base.send_error(req, "缺少ID", 400) else return base.send_error(req, "缺少ID", 400);
        const field = if (obj.get("field")) |v| if (v == .string) v.string else return base.send_error(req, "缺少字段名", 400) else return base.send_error(req, "缺少字段名", 400);
        const value = if (obj.get("value")) |v| if (v == .integer) @as(i32, @intCast(v.integer)) else 0 else 0;
        
        const OrmDictItem = @import("root").Orm(models.SysDictItem, "sys_dict_item");
        
        if (std.mem.eql(u8, field, "status")) {
            _ = try OrmDictItem.UpdateWith(id, .{
                .status = value,
                .updated_at = std.time.milliTimestamp(),
            });
        }
        
        try base.send_success(req, .{ .message = "更新成功" });
        
        _ = self;
    }
    
    /// 获取分类名称
    fn getCategoryName(self: *Dict, code: []const u8) ![]const u8 {
        // 分类映射
        const categories = [_]struct { code: []const u8, name: []const u8 }{
            .{ .code = "system", .name = "系统配置" },
            .{ .code = "business", .name = "业务配置" },
            .{ .code = "user", .name = "用户相关" },
            .{ .code = "order", .name = "订单相关" },
        };
        
        for (categories) |cat| {
            if (std.mem.eql(u8, cat.code, code)) {
                return try self.allocator.dupe(u8, cat.name);
            }
        }
        
        return try self.allocator.dupe(u8, "其他");
    }
};
