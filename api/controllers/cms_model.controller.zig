//! CMS 模型管理控制器
//!
//! 提供内容模型的 CRUD 操作及字段管理

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");
const validator = @import("../../application/services/validator/validator.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

const OrmCmsModel = orm_models.CmsModel;
const OrmCmsField = orm_models.CmsField;

pub fn init(allocator: Allocator) Self {
    if (!OrmCmsModel.hasDb()) {
        OrmCmsModel.use(global.get_db());
    }
    if (!OrmCmsField.hasDb()) {
        OrmCmsField.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

pub const list = MW.requireAuth(listImpl);
pub const get = MW.requireAuth(getImpl);
pub const save = MW.requireAuth(saveImpl);
pub const delete = MW.requireAuth(deleteImpl);
pub const select = MW.requireAuth(selectImpl);
pub const fields = MW.requireAuth(fieldsImpl);

// ============================================================================
// 实现方法
// ============================================================================

fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var sort_field: []const u8 = "sort";
    var sort_dir: []const u8 = "asc";

    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 10);
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "sort";
            sort_dir = value.value;
        }
    }

    var q = OrmCmsModel.Where("is_delete", .eq, @as(i32, 0));
    defer q.deinit();

    const total = q.count() catch |e| return base.send_error(req, e);

    const order_dir: orm_models.Database.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    _ = q.orderBy(sort_field, order_dir);
    _ = q.page(page, limit);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmCmsModel.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(OrmCmsModel.Model){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

fn getImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const item_opt = OrmCmsModel.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "模型不存在");
    }

    var item = item_opt.?;
    defer OrmCmsModel.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(OrmCmsModel.Model, self.allocator, body) catch |err| {
        std.log.err("解析模型数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    var v = validator.Validator.init(self.allocator);
    defer v.deinit();

    _ = v.required("name", dto.name)
        .minLength("name", dto.name, 2)
        .maxLength("name", dto.name, 50);

    if (v.fails()) {
        return base.send_failed(req, v.firstError() orelse "验证失败");
    }

    // 检查表名唯一性
    if (dto.table_name_field.len > 0) {
        var check_q = OrmCmsModel.Where("table_name_field", .eq, dto.table_name_field);
        defer check_q.deinit();
        _ = check_q.where("is_delete", .eq, @as(i32, 0));
        if (dto.id) |id| {
            if (id > 0) {
                _ = check_q.where("id", .neq, id);
            }
        }
        const exists = check_q.first() catch null;
        if (exists != null) {
            return base.send_failed(req, "表名已存在");
        }
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmCmsModel.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmCmsModel.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmCmsModel.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 检查是否为系统模型
    const item_opt = OrmCmsModel.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt) |item| {
        if (item.is_system == 1) {
            return base.send_failed(req, "系统模型不可删除");
        }
    }

    // 软删除
    const sql_str = strings.sprinf(
        "UPDATE zigcms.cms_model SET is_delete = 1, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    // 同时软删除关联的字段
    const field_sql = strings.sprinf(
        "UPDATE zigcms.cms_field SET is_delete = 1, update_time = {d} WHERE model_id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(field_sql);

    _ = global.get_db().rawExec(field_sql, .{}) catch {};

    return base.send_ok(req, "删除成功");
}

fn selectImpl(self: *Self, req: zap.Request) !void {
    var q = OrmCmsModel.Where("status", .eq, @as(i32, 1));
    defer q.deinit();
    _ = q.where("is_delete", .eq, @as(i32, 0));
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmCmsModel.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(OrmCmsModel.Model){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}

fn fieldsImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const model_id_str = req.getParamSlice("model_id") orelse return base.send_failed(req, "缺少 model_id 参数");
    const model_id: i32 = @intCast(strings.to_int(model_id_str) catch return base.send_failed(req, "model_id 格式错误"));

    var q = OrmCmsField.Where("model_id", .eq, model_id);
    defer q.deinit();
    _ = q.where("is_delete", .eq, @as(i32, 0));
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmCmsField.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(OrmCmsField.Model){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}
