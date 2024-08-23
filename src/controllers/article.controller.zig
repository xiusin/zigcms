const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/models.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../modules/strings.zig");

const Self = @This();

const table = "article";

allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn list(self: *Self, req: zap.Request) void {
    var dto = dtos.Page{};

    req.parseQuery();

    var items = req.parametersToOwnedStrList(self.allocator, true) catch unreachable;
    defer items.deinit();

    for (items.items) |value| {
        if (strings.eql(value.key.str, "page")) {
            dto.page = std.fmt.parseInt(
                u32,
                value.value.str,
                10,
            ) catch return base.send_failed(req, "page参数类型错误");
        }

        if (strings.eql(value.key.str, "limit")) {
            dto.limit = std.fmt.parseInt(
                u32,
                value.value.str,
                10,
            ) catch return base.send_failed(req, "limit参数类型错误");
        }

        if (strings.starts_with(value.key.str, "sort[")) {
            dto.field = base.get_sort_field(value.key.str).?;
            dto.sort = value.value.str;
        }
    }
    if (dto.field.len == 0) {
        dto.field = "id";
        dto.sort = "desc";
    }

    var pool = global.get_pg_pool();

    var row = (global.get_pg_pool().rowOpts("SELECT COUNT(*) AS total FROM zigcms." ++ table, .{}, .{}) catch |e| return base.send_error(req, e)) orelse return base.send_ok(req, "数据异常");
    defer row.deinit() catch {};
    const total = row.to(struct { total: i64 = 0 }, .{}) catch |e| return base.send_error(req, e);
    const query = std.mem.join(self.allocator, "", &[_][]const u8{
        "SELECT * FROM zigcms." ++ table,
        " ORDER BY ",
        dto.field,
        " ",
        dto.sort,
        " OFFSET $1 LIMIT $2",
    }) catch unreachable;
    defer self.allocator.free(query);

    var result = pool.queryOpts(query, .{ (dto.page - 1) * dto.limit, dto.limit }, .{
        .column_names = true,
    }) catch |e| return base.send_error(req, e);

    defer result.deinit();

    var articles = std.ArrayList(models.Article).init(self.allocator);
    defer articles.deinit();
    {
        const mapper = result.mapper(models.Article, .{ .allocator = self.allocator });
        while (mapper.next() catch |e| return base.send_error(req, e)) |article| {
            articles.append(article) catch {};
        }
    }
    base.send_layui_table_response(req, articles, @as(u64, @intCast(total.total)), .{});
}

pub fn get(_: *Self, req: zap.Request) void {
    req.parseQuery();
    const id = req.getParamSlice("id") orelse return base.send_failed(req, "缺少ID参数");
    if (id.len == 0) return base.send_failed(req, "缺少ID参数");
    var pool = global.get_pg_pool();
    var row = (pool.rowOpts("SELECT * FROM zigcms." ++ table ++ " WHERE id = $1", .{id}, .{
        .column_names = true,
    }) catch |e| return base.send_error(req, e)) orelse return base.send_failed(req, "文章不存在");

    defer row.deinit() catch {};
    const article = row.to(models.Article, .{ .map = .name }) catch |e| return base.send_error(req, e);
    return base.send_ok(req, article);
}

pub fn modify(self: *Self, req: zap.Request) void {
    var dto = dtos.Modify{};
    req.parseBody() catch |e| return base.send_error(req, e);
    if (req.body == null) return base.send_failed(req, "缺少必要参数");
    var params = req.parametersToOwnedStrList(self.allocator, true) catch return base.send_failed(req, "解析参数错误");
    defer params.deinit();

    for (params.items) |item| {
        if (strings.eql("id", item.key.str)) {
            dto.id = @as(u32, @intCast(strings.to_int(item.value.str) catch return base.send_failed(req, "无法解析ID参数")));
        } else if (strings.eql("field", item.key.str)) {
            dto.field = item.value.str;
        } else if (strings.eql("value", item.key.str)) {
            dto.value.? = item.value.str;
        }
    }

    if (dto.id == 0 or dto.field.len == 0 or dto.value == null) {
        return base.send_failed(req, "缺少必要参数");
    }

    const sql = strings.join(self.allocator, " ", &[_][]const u8{
        "UPDATE zigcms." ++ table ++ " SET ",
        dto.field,
        "=$2 WHERE id = $1",
    }) catch return;
    defer self.allocator.free(sql);
    _ = (global.get_pg_pool().exec(sql, .{
        dto.id,
        dto.value.?,
    }) catch |e| return base.send_error(
        req,
        e,
    )) orelse return base.send_failed(req, "更新失败");
    return base.send_ok(req, "更新成功");
}

pub fn delete(self: *Self, req: zap.Request) void {
    var ids = std.ArrayList(usize).init(self.allocator);
    defer ids.deinit();

    if (strings.eql(req.method.?, "POST")) {
        req.parseBody() catch {};
        if (req.body) |_| {
            var params = req.parametersToOwnedStrList(
                self.allocator,
                true,
            ) catch return;

            defer params.deinit();
            for (params.items) |item| {
                if (strings.eql("id", item.key.str)) {
                    const items = strings.split(self.allocator, item.value.str, ",") catch return;
                    defer self.allocator.free(items);
                    for (items) |value| {
                        ids.append(strings.to_int(value) catch |e| return base.send_error(
                            req,
                            e,
                        )) catch unreachable;
                    }
                }
            }
        }
    }
    req.parseQuery();
    if (req.getParamSlice("id")) |id| {
        const id_num = strings.to_int(id) catch return base.send_failed(req, "缺少参数");
        ids.append(id_num) catch unreachable;
    }

    if (ids.capacity == 0) return base.send_failed(req, "缺少ID参数");
    var pool = global.get_pg_pool();
    const sql = "DELETE FROM zigcms." ++ table ++ " WHERE id = $1";
    for (ids.items) |id| {
        _ = pool.exec(sql, .{id}) catch |e| return base.send_error(
            req,
            e,
        );
    }
    return base.send_ok(req, "删除成功");
}

pub fn save(self: *Self, req: zap.Request) void {
    req.parseBody() catch |e| return base.send_error(req, e);
    var dto: models.Article = undefined;
    if (req.body) |body| {
        dto = std.json.parseFromSliceLeaky(models.Article, self.allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return base.send_failed(req, "参数类型错误");
    } else {
        return base.send_failed(req, "缺少必要参数");
    }

    if (dto.create_time == null) {
        dto.create_time = std.time.milliTimestamp();
    }

    dto.update_time = std.time.milliTimestamp();

    var row: ?i64 = 0;
    var pool = global.get_pg_pool();

    const update = .{
        dto.title,
        dto.keyword,
        dto.description,
        dto.content,
        dto.image_url,
        dto.video_url,
        dto.category_id,
        dto.article_type,
        dto.comment_switch,
        dto.recomment_type,
        dto.tags,
        dto.status,
        dto.sort,
        dto.view_count,
        dto.create_time,
        dto.update_time,
        dto.is_delete,
    };

    if (dto.id) |id| {
        const sql = base.build_update_sql(
            models.Article,
            self.allocator,
        ) catch return base.send_failed(req, "保存失败");
        defer self.allocator.free(sql);

        row = pool.exec(sql, update ++ .{id}) catch |e| return base.send_error(req, e);
    } else {
        const sql = base.build_insert_sql(
            models.Article,
            self.allocator,
        ) catch return base.send_failed(req, "保存失败");
        defer self.allocator.free(sql);

        row = pool.exec(sql, update) catch |e| return base.send_error(req, e);
    }

    if (row == null or row == 0) {
        return base.send_failed(req, "保存失败");
    }
    return base.send_ok(req, .{});
}
