/// 系统字典控制器
const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

pub const Dict = struct {
    const Self = @This();

    allocator: Allocator,

    const OrmDict = sql.defineWithConfig(models.SysDict, .{
        .table_name = "zigcms.sys_dict",
        .primary_key = "id",
    });

    const OrmDictItem = sql.defineWithConfig(models.SysDictItem, .{
        .table_name = "zigcms.sys_dict_item",
        .primary_key = "id",
    });

    /// 初始化字典控制器
    pub fn init(allocator: Allocator) Self {
        const db = global.get_db();
        if (!OrmDict.hasDb()) OrmDict.use(db);
        if (!OrmDictItem.hasDb()) OrmDictItem.use(db);
        return .{ .allocator = allocator };
    }

    // ==================== 公开路由处理器 ====================
    pub const list = listImpl;
    pub const save = saveImpl;
    pub const delete = deleteImpl;
    pub const set = setImpl;
    pub const items = itemsImpl;
    pub const itemSave = itemSaveImpl;
    pub const itemDelete = itemDeleteImpl;
    pub const itemSet = itemSetImpl;

    // ==================== 字典 CRUD ====================

    /// 获取字典列表
    fn listImpl(self: *Self, req: zap.Request) !void {
        req.parseQuery();

        var page: i32 = 1;
        var page_size: i32 = 10;
        var keyword: ?[]const u8 = null;
        var category: ?[]const u8 = null;

        if (req.getParamSlice("page")) |page_str| {
            page = std.fmt.parseInt(i32, page_str, 10) catch 1;
        }
        if (req.getParamSlice("pageSize")) |page_size_str| {
            page_size = std.fmt.parseInt(i32, page_size_str, 10) catch 10;
        }
        if (req.getParamSlice("page_size")) |page_size_str| {
            page_size = std.fmt.parseInt(i32, page_size_str, 10) catch page_size;
        }
        if (req.getParamSlice("keyword")) |kw| {
            if (kw.len > 0) keyword = kw;
        }
        if (req.getParamSlice("category")) |cat| {
            if (cat.len > 0) category = cat;
        }

        // 查询总数
        var cq = OrmDict.Query();
        defer cq.deinit();
        if (category) |cat| {
            _ = cq.whereEq("category_code", cat);
        }
        if (keyword) |kw| {
            const pattern = std.fmt.allocPrint(self.allocator, "%{s}%", .{kw}) catch return base.send_failed(req, "关键词处理失败");
            defer self.allocator.free(pattern);
            var nested = cq.newNested();
            defer nested.deinit();
            _ = nested.whereLike("dict_name", pattern);
            _ = nested.orWhere("dict_code", "LIKE", pattern);
            _ = cq.whereNested(&nested);
        }
        const total = cq.count() catch 0;

        // 查询列表
        var q = OrmDict.Query();
        defer q.deinit();
        if (category) |cat| {
            _ = q.whereEq("category_code", cat);
        }
        if (keyword) |kw| {
            const pattern = std.fmt.allocPrint(self.allocator, "%{s}%", .{kw}) catch return base.send_failed(req, "关键词处理失败");
            defer self.allocator.free(pattern);
            var nested = q.newNested();
            defer nested.deinit();
            _ = nested.whereLike("dict_name", pattern);
            _ = nested.orWhere("dict_code", "LIKE", pattern);
            _ = q.whereNested(&nested);
        }
        _ = q.orderBy("id", sql.OrderDir.desc);
        _ = q.page(@intCast(page), @intCast(page_size));

        const rows = q.get() catch |err| return base.send_error(req, err);
        defer OrmDict.freeModels(rows);

        // 构建带分类名称的响应列表
        const DictWithCategory = @import("../dto/dict_with_category.dto.zig").DictWithCategory;
        var list_arr = std.ArrayListUnmanaged(DictWithCategory){};
        defer list_arr.deinit(self.allocator);

        for (rows) |row| {
            const category_name = row.category_code;

            list_arr.append(self.allocator, .{
                .id = row.id,
                .category_code = row.category_code,
                .category_name = category_name,
                .dict_name = row.dict_name,
                .dict_code = row.dict_code,
                .remark = row.remark,
                .status = row.status,
                .created_at = row.created_at,
                .updated_at = row.updated_at,
            }) catch {};
        }

        base.send_ok(req, .{
            .list = list_arr.items,
            .total = total,
            .page = page,
            .page_size = page_size,
            .pageSize = page_size,
        });
    }

    /// 保存字典（新增/编辑）
    fn saveImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch return base.send_failed(req, "解析请求体失败");
        const body = req.body orelse return base.send_failed(req, "请求体为空");

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            return base.send_failed(req, "JSON 格式错误");
        };
        defer parsed.deinit();

        if (parsed.value != .object) return base.send_failed(req, "参数格式错误");
        const obj = parsed.value.object;

        // 提取字段
        const id_val = if (obj.get("id")) |v| switch (v) {
            .integer => |i| @as(?i32, @intCast(i)),
            else => null,
        } else null;
        const category_code = if (obj.get("category_code")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const dict_name = if (obj.get("dict_name")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const dict_code = if (obj.get("dict_code")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const remark = if (obj.get("remark")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const status: i32 = if (obj.get("status")) |v| switch (v) {
            .integer => |i| @intCast(i),
            .bool => |b| if (b) @as(i32, 1) else @as(i32, 0),
            else => 1,
        } else 1;

        if (category_code.len == 0 or dict_name.len == 0 or dict_code.len == 0) {
            return base.send_failed(req, "分类、名称和编码不能为空");
        }

        {
            var name_q = OrmDict.WhereEq("dict_name", dict_name);
            defer name_q.deinit();
            if (id_val) |id| {
                if (id > 0) {
                    _ = name_q.whereNe("id", id);
                }
            }
            const name_count = name_q.count() catch |err| return base.send_error(req, err);
            if (name_count > 0) {
                return base.send_failed(req, "字典名称已存在");
            }
        }

        {
            var code_q = OrmDict.WhereEq("dict_code", dict_code);
            defer code_q.deinit();
            if (id_val) |id| {
                if (id > 0) {
                    _ = code_q.whereNe("id", id);
                }
            }
            const code_count = code_q.count() catch |err| return base.send_error(req, err);
            if (code_count > 0) {
                return base.send_failed(req, "字典编码已存在");
            }
        }

        if (id_val) |id| {
            if (id > 0) {
                // 更新
                var model = (OrmDict.Find(id) catch |err| return base.send_error(req, err)) orelse {
                    return base.send_failed(req, "字典不存在");
                };
                defer OrmDict.freeModel(&model);

                model.category_code = category_code;
                model.dict_name = dict_name;
                model.dict_code = dict_code;
                model.remark = remark;
                model.status = status;

                _ = OrmDict.Update(id, model) catch |err| return base.send_error(req, err);
                return base.send_ok(req, .{ .message = "更新成功" });
            }
        }

        // 新增
        const dict = models.SysDict{
            .category_code = category_code,
            .dict_name = dict_name,
            .dict_code = dict_code,
            .remark = remark,
            .status = status,
        };
        var created = OrmDict.Create(dict) catch |err| return base.send_error(req, err);
        defer OrmDict.freeModel(&created);

        base.send_ok(req, .{ .id = created.id, .message = "添加成功" });
    }

    /// 删除字典
    fn deleteImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch {
            req.parseQuery();
        };

        var id: ?i32 = null;
        var force_delete = false;

        // 支持 POST body 或 GET query 传 id
        if (req.body) |body| {
            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
            if (parsed) |*p| {
                defer p.deinit();
                if (p.value == .object) {
                    if (p.value.object.get("id")) |v| {
                        if (v == .integer) id = @intCast(v.integer);
                    }
                    if (p.value.object.get("force")) |v| {
                        switch (v) {
                            .bool => force_delete = v.bool,
                            .integer => force_delete = v.integer == 1,
                            .string => |s| {
                                force_delete = std.mem.eql(u8, s, "1") or std.ascii.eqlIgnoreCase(s, "true");
                            },
                            else => {},
                        }
                    }
                }
            }
        }

        if (id == null) {
            req.parseQuery();
            if (req.getParamSlice("id")) |id_str| {
                id = std.fmt.parseInt(i32, id_str, 10) catch null;
            }
        }

        if (!force_delete) {
            if (req.getParamSlice("force")) |force_str| {
                force_delete = std.mem.eql(u8, force_str, "1") or std.ascii.eqlIgnoreCase(force_str, "true");
            }
        }

        const dict_id = id orelse return base.send_failed(req, "缺少 id 参数");
        if (dict_id <= 0) return base.send_failed(req, "id 格式错误");

        var dict = (OrmDict.Find(dict_id) catch |err| return base.send_error(req, err)) orelse {
            return base.send_failed(req, "字典不存在");
        };
        defer OrmDict.freeModel(&dict);

        var item_q = OrmDictItem.WhereEq("dict_id", dict_id);
        defer item_q.deinit();
        const item_count = item_q.count() catch |err| return base.send_error(req, err);
        if (item_count > 0 and !force_delete) {
            return base.send_failed(req, "该字典下存在字典项，请先清理字典项或传 force=1 强制删除");
        }

        if (item_count > 0 and force_delete) {
            var delete_items_q = OrmDictItem.WhereEq("dict_id", dict_id);
            defer delete_items_q.deinit();
            _ = delete_items_q.delete() catch |err| return base.send_error(req, err);
        }

        // 删除字典
        _ = OrmDict.Destroy(dict_id) catch |err| return base.send_error(req, err);

        base.send_ok(req, .{ .message = "删除成功" });
    }

    /// 设置字典单字段（如 status 切换）
    fn setImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch return base.send_failed(req, "解析请求体失败");
        const body = req.body orelse return base.send_failed(req, "请求体为空");

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            return base.send_failed(req, "JSON 格式错误");
        };
        defer parsed.deinit();

        if (parsed.value != .object) return base.send_failed(req, "参数格式错误");

        const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id");
        const field_val = parsed.value.object.get("field") orelse return base.send_failed(req, "缺少 field");
        const value_val = parsed.value.object.get("value") orelse return base.send_failed(req, "缺少 value");

        if (id_val != .integer or field_val != .string) {
            return base.send_failed(req, "参数类型错误");
        }

        const dict_id: i32 = @intCast(id_val.integer);
        const field = field_val.string;

        var model = (OrmDict.Find(dict_id) catch |err| return base.send_error(req, err)) orelse {
            return base.send_failed(req, "记录不存在");
        };
        defer OrmDict.freeModel(&model);

        if (std.mem.eql(u8, field, "status")) {
            if (value_val != .integer) return base.send_failed(req, "status 类型错误");
            model.status = @intCast(value_val.integer);
        } else {
            return base.send_failed(req, "不支持的字段");
        }

        _ = OrmDict.Update(dict_id, model) catch |err| return base.send_error(req, err);
        base.send_ok(req, .{ .message = "更新成功" });
    }

    // ==================== 字典项 CRUD ====================

    /// 获取字典项列表
    fn itemsImpl(self: *Self, req: zap.Request) !void {
        req.parseQuery();

        var dict_id: ?i32 = null;
        var keyword: ?[]const u8 = null;
        if (req.getParamSlice("dict_id")) |id_str| {
            dict_id = std.fmt.parseInt(i32, id_str, 10) catch null;
        }
        if (req.getParamSlice("keyword")) |kw| {
            if (kw.len > 0) keyword = kw;
        }

        // 也支持通过 dict_code 查找
        if (dict_id == null) {
            if (req.getParamSlice("dict_code")) |code| {
                var dq = OrmDict.WhereEq("dict_code", code);
                defer dq.deinit();
                const dict = dq.first() catch null;
                if (dict) |d| {
                    dict_id = d.id orelse 0;
                }
            }
        }

        const target_id = dict_id orelse return base.send_ok(req, .{ .list = &.{} });

        var q = OrmDictItem.WhereEq("dict_id", target_id);
        defer q.deinit();
        if (keyword) |kw| {
            const pattern = std.fmt.allocPrint(self.allocator, "%{s}%", .{kw}) catch return base.send_failed(req, "关键词处理失败");
            defer self.allocator.free(pattern);
            var nested = q.newNested();
            defer nested.deinit();
            _ = nested.whereLike("item_name", pattern);
            _ = nested.orWhere("item_value", "LIKE", pattern);
            _ = q.whereNested(&nested);
        }
        _ = q.orderBy("sort", .asc);

        const rows = q.get() catch |err| return base.send_error(req, err);
        defer OrmDictItem.freeModels(rows);

        var list_arr = std.ArrayListUnmanaged(models.SysDictItem){};
        defer list_arr.deinit(self.allocator);
        for (rows) |row| {
            list_arr.append(self.allocator, row) catch {};
        }

        base.send_ok(req, .{ .list = list_arr.items });
    }

    /// 保存字典项
    fn itemSaveImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch return base.send_failed(req, "解析请求体失败");
        const body = req.body orelse return base.send_failed(req, "请求体为空");

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            return base.send_failed(req, "JSON 格式错误");
        };
        defer parsed.deinit();

        if (parsed.value != .object) return base.send_failed(req, "参数格式错误");
        const obj = parsed.value.object;

        const id_val = if (obj.get("id")) |v| switch (v) {
            .integer => |i| @as(?i32, @intCast(i)),
            else => null,
        } else null;
        const dict_id_raw = if (obj.get("dict_id")) |v| switch (v) {
            .integer => |i| @as(i32, @intCast(i)),
            else => @as(i32, 0),
        } else @as(i32, 0);
        const item_name = if (obj.get("item_name")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const item_value = if (obj.get("item_value")) |v| switch (v) {
            .string => |s| s,
            else => "",
        } else "";
        const sort: i32 = if (obj.get("sort")) |v| switch (v) {
            .integer => |i| @intCast(i),
            else => 0,
        } else 0;
        const status: i32 = if (obj.get("status")) |v| switch (v) {
            .integer => |i| @intCast(i),
            .bool => |b| if (b) @as(i32, 1) else @as(i32, 0),
            else => 1,
        } else 1;

        if (dict_id_raw <= 0) return base.send_failed(req, "dict_id 无效");
        if (item_name.len == 0 or item_value.len == 0) {
            return base.send_failed(req, "名称和值不能为空");
        }

        if (id_val) |item_id| {
            if (item_id > 0) {
                // 更新
                var model = (OrmDictItem.Find(item_id) catch |err| return base.send_error(req, err)) orelse {
                    return base.send_failed(req, "字典项不存在");
                };
                defer OrmDictItem.freeModel(&model);

                model.item_name = item_name;
                model.item_value = item_value;
                model.sort = sort;
                model.status = status;

                _ = OrmDictItem.Update(item_id, model) catch |err| return base.send_error(req, err);
                return base.send_ok(req, .{ .message = "更新成功" });
            }
        }

        // 新增
        const item = models.SysDictItem{
            .dict_id = dict_id_raw,
            .item_name = item_name,
            .item_value = item_value,
            .sort = sort,
            .status = status,
        };
        var created = OrmDictItem.Create(item) catch |err| return base.send_error(req, err);
        defer OrmDictItem.freeModel(&created);

        base.send_ok(req, .{ .id = created.id, .message = "添加成功" });
    }

    /// 删除字典项
    fn itemDeleteImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch {
            req.parseQuery();
        };

        var id: ?i32 = null;

        if (req.body) |body_data| {
            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body_data, .{}) catch null;
            if (parsed) |*p| {
                defer p.deinit();
                if (p.value == .object) {
                    if (p.value.object.get("id")) |v| {
                        if (v == .integer) id = @intCast(v.integer);
                    }
                }
            }
        }

        if (id == null) {
            req.parseQuery();
            if (req.getParamSlice("id")) |id_str| {
                id = std.fmt.parseInt(i32, id_str, 10) catch null;
            }
        }

        const item_id = id orelse return base.send_failed(req, "缺少 id 参数");
        _ = OrmDictItem.Destroy(item_id) catch |err| return base.send_error(req, err);
        base.send_ok(req, .{ .message = "删除成功" });
    }

    /// 设置字典项单字段
    fn itemSetImpl(self: *Self, req: zap.Request) !void {
        req.parseBody() catch return base.send_failed(req, "解析请求体失败");
        const body = req.body orelse return base.send_failed(req, "请求体为空");

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
            return base.send_failed(req, "JSON 格式错误");
        };
        defer parsed.deinit();

        if (parsed.value != .object) return base.send_failed(req, "参数格式错误");

        const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id");
        const field_val = parsed.value.object.get("field") orelse return base.send_failed(req, "缺少 field");
        const value_val = parsed.value.object.get("value") orelse return base.send_failed(req, "缺少 value");

        if (id_val != .integer or field_val != .string) {
            return base.send_failed(req, "参数类型错误");
        }

        const item_id: i32 = @intCast(id_val.integer);
        const field = field_val.string;

        var model = (OrmDictItem.Find(item_id) catch |err| return base.send_error(req, err)) orelse {
            return base.send_failed(req, "记录不存在");
        };
        defer OrmDictItem.freeModel(&model);

        if (std.mem.eql(u8, field, "status")) {
            if (value_val != .integer) return base.send_failed(req, "status 类型错误");
            model.status = @intCast(value_val.integer);
        } else if (std.mem.eql(u8, field, "sort")) {
            if (value_val != .integer) return base.send_failed(req, "sort 类型错误");
            model.sort = @intCast(value_val.integer);
        } else {
            return base.send_failed(req, "不支持的字段");
        }

        _ = OrmDictItem.Update(item_id, model) catch |err| return base.send_error(req, err);
        base.send_ok(req, .{ .message = "更新成功" });
    }
};
