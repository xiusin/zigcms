//! 文档管理控制器
//!
//! 提供 CMS 文档的 CRUD 操作

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

const OrmDocument = orm_models.Document;
const OrmCmsModel = orm_models.CmsModel;

pub fn init(allocator: Allocator) Self {
    if (!OrmDocument.hasDb()) {
        OrmDocument.use(global.get_db());
    }
    if (!OrmCmsModel.hasDb()) {
        OrmCmsModel.use(global.get_db());
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
pub const publish = MW.requireAuth(publishImpl);
pub const unpublish = MW.requireAuth(unpublishImpl);
pub const batchDelete = MW.requireAuth(batchDeleteImpl);
pub const batchPublish = MW.requireAuth(batchPublishImpl);

// ============================================================================
// 实现方法
// ============================================================================

fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var model_id: i32 = 0;
    var category_id: i32 = 0;
    var status: i32 = -1;
    var keyword: []const u8 = "";
    var sort_field: []const u8 = "id";
    var sort_dir: []const u8 = "desc";

    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 10);
        } else if (strings.eql(value.key, "model_id")) {
            model_id = @intCast(strings.to_int(value.value) catch 0);
        } else if (strings.eql(value.key, "category_id")) {
            category_id = @intCast(strings.to_int(value.value) catch 0);
        } else if (strings.eql(value.key, "status")) {
            status = @intCast(strings.to_int(value.value) catch -1);
        } else if (strings.eql(value.key, "keyword")) {
            keyword = value.value;
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "id";
            sort_dir = value.value;
        }
    }

    var q = OrmDocument.Where("is_delete", .eq, @as(i32, 0));
    defer q.deinit();

    if (model_id > 0) {
        _ = q.where("model_id", .eq, model_id);
    }
    if (category_id > 0) {
        _ = q.where("category_id", .eq, category_id);
    }
    if (status >= 0) {
        _ = q.where("status", .eq, status);
    }
    if (keyword.len > 0) {
        _ = q.whereLike("title", strings.sprinf("%{s}%", .{keyword}) catch "%");
    }

    const total = q.count() catch |e| return base.send_error(req, e);

    const order_dir: orm_models.Database.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    _ = q.orderBy(sort_field, order_dir);
    _ = q.page(page, limit);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmDocument.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(OrmDocument.Model){};
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

    const item_opt = OrmDocument.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "文档不存在");
    }

    var item = item_opt.?;
    defer OrmDocument.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(OrmDocument.Model, self.allocator, body) catch |err| {
        std.log.err("解析文档数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    var v = validator.Validator.init(self.allocator);
    defer v.deinit();

    _ = v.required("title", dto.title)
        .minLength("title", dto.title, 2)
        .maxLength("title", dto.title, 200);

    if (v.fails()) {
        return base.send_failed(req, v.firstError() orelse "验证失败");
    }

    if (dto.model_id == 0) {
        return base.send_failed(req, "模型ID不能为空");
    }

    // 检查 URL 别名唯一性
    if (dto.url_alias.len > 0) {
        var check_q = OrmDocument.Where("url_alias", .eq, dto.url_alias);
        defer check_q.deinit();
        _ = check_q.where("is_delete", .eq, @as(i32, 0));
        if (dto.id) |id| {
            if (id > 0) {
                _ = check_q.where("id", .neq, id);
            }
        }
        const exists = check_q.first() catch null;
        if (exists != null) {
            return base.send_failed(req, "URL 别名已存在");
        }
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmDocument.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmDocument.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmDocument.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 软删除
    const sql_str = strings.sprinf(
        "UPDATE zigcms.document SET is_delete = 1, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "删除成功");
}

fn publishImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const now = std.time.microTimestamp();
    const sql_str = strings.sprinf(
        "UPDATE zigcms.document SET status = 1, publish_time = {d}, update_time = {d} WHERE id = {d}",
        .{ now, now, id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "发布成功");
}

fn unpublishImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const sql_str = strings.sprinf(
        "UPDATE zigcms.document SET status = 3, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "下架成功");
}

fn batchDeleteImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const IdsData = struct {
        ids: []i32,
    };

    const data = json_mod.JSON.decode(IdsData, self.allocator, body) catch {
        return base.send_failed(req, "解析数据失败");
    };

    if (data.ids.len == 0) {
        return base.send_failed(req, "请选择要删除的文档");
    }

    var ids_str = std.ArrayList(u8).init(self.allocator);
    defer ids_str.deinit();

    for (data.ids, 0..) |id, i| {
        if (i > 0) ids_str.appendSlice(", ") catch {};
        ids_str.writer().print("{d}", .{id}) catch {};
    }

    const sql_str = strings.sprinf(
        "UPDATE zigcms.document SET is_delete = 1, update_time = {d} WHERE id IN ({s})",
        .{ std.time.microTimestamp(), ids_str.items },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "批量删除成功");
}

fn batchPublishImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const BatchData = struct {
        ids: []i32,
        status: i32 = 1,
    };

    const data = json_mod.JSON.decode(BatchData, self.allocator, body) catch {
        return base.send_failed(req, "解析数据失败");
    };

    if (data.ids.len == 0) {
        return base.send_failed(req, "请选择要操作的文档");
    }

    var ids_str = std.ArrayList(u8).init(self.allocator);
    defer ids_str.deinit();

    for (data.ids, 0..) |id, i| {
        if (i > 0) ids_str.appendSlice(", ") catch {};
        ids_str.writer().print("{d}", .{id}) catch {};
    }

    const now = std.time.microTimestamp();
    const sql_str = if (data.status == 1)
        strings.sprinf(
            "UPDATE zigcms.document SET status = 1, publish_time = {d}, update_time = {d} WHERE id IN ({s})",
            .{ now, now, ids_str.items },
        ) catch return base.send_failed(req, "SQL 构建失败")
    else
        strings.sprinf(
            "UPDATE zigcms.document SET status = {d}, update_time = {d} WHERE id IN ({s})",
            .{ data.status, now, ids_str.items },
        ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str, .{}) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "批量操作成功");
}
