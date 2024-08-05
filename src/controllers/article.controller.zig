const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/models.zig");
const dtos = @import("../dto/dtos.zig");

pub const Article = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn list(self: *Self, req: zap.Request) void {
        var dto = dtos.Page{};

        req.parseQuery();
        if (req.getParamSlice("page")) |page| {
            dto.page = std.fmt.parseInt(
                u32,
                page,
                10,
            ) catch return base.send_failed(self.allocator, req, "page参数类型错误");
        }

        if (req.getParamSlice("limit")) |limit| {
            dto.limit = std.fmt.parseInt(
                u32,
                limit,
                10,
            ) catch return base.send_failed(self.allocator, req, "limit参数类型错误");
        }

        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);

        const query = "SELECT * FROM zigcms.article ORDER BY id DESC OFFSET $1 LIMIT $2";
        var result = pool.queryOpts(query, .{ (dto.page - 1) * dto.limit, dto.limit }, .{
            .column_names = true,
        }) catch |e| return base.send_error(req, e);

        defer result.deinit();

        const mapper = result.mapper(models.Article, .{ .allocator = self.allocator });
        var articles = std.ArrayList(models.Article).init(self.allocator);
        defer articles.deinit();
        while (mapper.next() catch |e| return base.send_error(req, e)) |article| {
            articles.append(article) catch {};
        }
        base.send_list_ok(self.allocator, req, articles, 100);
    }

    pub fn get(self: *Self, req: zap.Request) void {
        req.parseQuery();
        const id = req.getParamSlice("id") orelse return base.send_failed(self.allocator, req, "缺少ID参数");
        if (id.len == 0) return base.send_failed(self.allocator, req, "缺少ID参数");
        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
        var row = pool.rowOpts("SELECT * FROM zigcms.article WHERE id = $1", .{id}, .{
            .column_names = true,
        }) catch |e| return base.send_error(req, e);
        if (row == null) {
            return base.send_failed(self.allocator, req, "文章不存在");
        }

        defer row.?.deinit() catch {};
        const article = row.?.to(models.Article, .{ .map = .name }) catch |e| return base.send_error(req, e);
        return base.send_ok(self.allocator, req, article);
    }

    pub fn delete(self: *Self, req: zap.Request) void {
        req.parseQuery();
        const id = req.getParamSlice("id") orelse return base.send_failed(self.allocator, req, "缺少ID参数");
        if (id.len == 0) return base.send_failed(self.allocator, req, "缺少ID参数");
        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
        const row_num = (pool.exec("DELETE FROM zigcms.article WHERE id = $1", .{
            id,
        }) catch |e| return base.send_error(
            req,
            e,
        )) orelse return base.send_ok(self.allocator, req, "删除失败");
        if (row_num == 0) {
            return base.send_failed(self.allocator, req, "文章不存在");
        }
        return base.send_ok(self.allocator, req, "删除成功");
    }

    pub fn save(self: *Self, req: zap.Request) void {
        req.parseBody() catch |e| return base.send_error(req, e);
        var dto: models.Article = undefined;
        if (req.body) |body| {
            std.log.debug("body = {s}", .{body});
            dto = std.json.parseFromSliceLeaky(models.Article, self.allocator, body, .{
                .ignore_unknown_fields = true,
            }) catch return base.send_failed(self.allocator, req, "解析参数错误");
        }
        dto.update_time = std.time.microTimestamp();

        var row: ?i64 = 0;
        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
        if (dto.id) |id| {
            dto.create_time = std.time.microTimestamp();
            const sql = base.build_update_sql(
                models.Article,
                self.allocator,
            ) catch return base.send_failed(self.allocator, req, "保存失败");
            defer self.allocator.free(sql);

            row = pool.exec(sql, .{
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
                id,
            }) catch |e| return base.send_error(req, e);
        } else {
            const sql = base.build_insert_sql(
                models.Article,
                self.allocator,
            ) catch return base.send_failed(self.allocator, req, "保存失败");
            defer self.allocator.free(sql);

            row = pool.exec(sql, .{
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
            }) catch |e| return base.send_error(req, e);
        }

        if (row == null or row == 0) {
            return base.send_failed(self.allocator, req, "保存失败");
        }
        return base.send_ok(self.allocator, req, .{});
    }
};
