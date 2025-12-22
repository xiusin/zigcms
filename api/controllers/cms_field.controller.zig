//! CMS 字段管理控制器
//!
//! 提供模型字段的 CRUD 操作

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

const OrmCmsField = orm_models.CmsField;

pub fn init(allocator: Allocator) Self {
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
pub const batchSort = MW.requireAuth(batchSortImpl);
pub const fieldTypes = MW.requireAuth(fieldTypesImpl);

// ============================================================================
// 实现方法
// ============================================================================

fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 50;
    var model_id: i32 = 0;
    var sort_field: []const u8 = "sort";
    var sort_dir: []const u8 = "asc";

    var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
        return base.send_error(req, err);
    };
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 50);
        } else if (strings.eql(value.key, "model_id")) {
            model_id = @intCast(strings.to_int(value.value) catch 0);
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "sort";
            sort_dir = value.value;
        }
    }

    var q = OrmCmsField.Where("is_delete", .eq, @as(i32, 0));
    defer q.deinit();

    if (model_id > 0) {
        _ = q.where("model_id", .eq, model_id);
    }

    const total = q.count() catch |e| return base.send_error(req, e);

    const order_dir: orm_models.Database.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    _ = q.orderBy(sort_field, order_dir);
    _ = q.page(page, limit);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmCmsField.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(OrmCmsField.Model){};
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

    const item_opt = OrmCmsField.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "字段不存在");
    }

    var item = item_opt.?;
    defer OrmCmsField.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(OrmCmsField.Model, self.allocator, body) catch |err| {
        std.log.err("解析字段数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    var v = validator.Validator.init(self.allocator);
    defer v.deinit();

    _ = v.required("field_name", dto.field_name)
        .required("field_label", dto.field_label)
        .alphaNum("field_name", dto.field_name)
        .minLength("field_name", dto.field_name, 2)
        .maxLength("field_name", dto.field_name, 50);

    if (v.fails()) {
        return base.send_failed(req, v.firstError() orelse "验证失败");
    }

    if (dto.model_id == 0) {
        return base.send_failed(req, "模型ID不能为空");
    }

    // 检查字段名唯一性（同一模型下）
    var check_q = OrmCmsField.Where("field_name", .eq, dto.field_name);
    defer check_q.deinit();
    _ = check_q.where("model_id", .eq, dto.model_id);
    _ = check_q.where("is_delete", .eq, @as(i32, 0));
    if (dto.id) |id| {
        if (id > 0) {
            _ = check_q.where("id", .neq, id);
        }
    }
    const exists = check_q.first() catch null;
    if (exists != null) {
        return base.send_failed(req, "该模型下字段名已存在");
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmCmsField.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmCmsField.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmCmsField.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 软删除
    const sql_str = strings.sprinf(
        "UPDATE zigcms.cms_field SET is_delete = 1, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "删除成功");
}

fn batchSortImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const SortItem = struct {
        id: i32,
        sort: i32,
    };

    const SortData = struct {
        items: []SortItem,
    };

    const data = json_mod.JSON.decode(SortData, self.allocator, body) catch {
        return base.send_failed(req, "解析数据失败");
    };

    for (data.items) |item| {
        const sql_str = strings.sprinf(
            "UPDATE zigcms.cms_field SET sort = {d}, update_time = {d} WHERE id = {d}",
            .{ item.sort, std.time.microTimestamp(), item.id },
        ) catch continue;
        defer self.allocator.free(sql_str);

        _ = global.get_db().rawExec(sql_str, .{}) catch {};
    }

    return base.send_ok(req, "排序更新成功");
}

fn fieldTypesImpl(_: *Self, req: zap.Request) !void {
    const field_types = [_]struct { value: []const u8, label: []const u8, db_type: []const u8 }{
        .{ .value = "text", .label = "单行文本", .db_type = "VARCHAR(255)" },
        .{ .value = "textarea", .label = "多行文本", .db_type = "TEXT" },
        .{ .value = "richtext", .label = "富文本", .db_type = "TEXT" },
        .{ .value = "number", .label = "数字", .db_type = "INT" },
        .{ .value = "decimal", .label = "小数", .db_type = "DECIMAL(10,2)" },
        .{ .value = "select", .label = "下拉选择", .db_type = "VARCHAR(100)" },
        .{ .value = "radio", .label = "单选", .db_type = "VARCHAR(100)" },
        .{ .value = "checkbox", .label = "多选", .db_type = "TEXT" },
        .{ .value = "switch", .label = "开关", .db_type = "TINYINT(1)" },
        .{ .value = "date", .label = "日期", .db_type = "DATE" },
        .{ .value = "datetime", .label = "日期时间", .db_type = "DATETIME" },
        .{ .value = "time", .label = "时间", .db_type = "TIME" },
        .{ .value = "image", .label = "图片", .db_type = "VARCHAR(500)" },
        .{ .value = "images", .label = "多图", .db_type = "TEXT" },
        .{ .value = "file", .label = "文件", .db_type = "VARCHAR(500)" },
        .{ .value = "files", .label = "多文件", .db_type = "TEXT" },
        .{ .value = "color", .label = "颜色选择", .db_type = "VARCHAR(20)" },
        .{ .value = "icon", .label = "图标选择", .db_type = "VARCHAR(50)" },
        .{ .value = "cascader", .label = "级联选择", .db_type = "VARCHAR(500)" },
        .{ .value = "relation", .label = "关联模型", .db_type = "INT" },
        .{ .value = "json", .label = "JSON", .db_type = "TEXT" },
        .{ .value = "code", .label = "代码", .db_type = "MEDIUMTEXT" },
        .{ .value = "markdown", .label = "Markdown", .db_type = "TEXT" },
        .{ .value = "hidden", .label = "隐藏", .db_type = "VARCHAR(255)" },
    };

    base.send_ok(req, field_types);
}
