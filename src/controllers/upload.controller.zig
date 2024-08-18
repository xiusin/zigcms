const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/models.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../modules/strings.zig");

const Self = @This();

allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn list(self: *Self, req: zap.Request) void {
    var dto = dtos.Page{};

    req.parseQuery();

    var params = req.parametersToOwnedStrList(self.allocator, true) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key.str, "page")) {
            dto.page = std.fmt.parseInt(
                u32,
                value.value.str,
                10,
            ) catch return base.send_failed(req, "page参数类型错误");
        } else if (strings.eql(value.key.str, "limit")) {
            dto.limit = std.fmt.parseInt(
                u32,
                value.value.str,
                10,
            ) catch return base.send_failed(req, "limit参数类型错误");
        } else if (strings.starts_with(value.key.str, "sort[")) {
            dto.field = base.get_sort_field(value.key.str).?;
            dto.sort = value.value.str;
        }
    }

    if (dto.page == 0) {
        dto.page = 1;
    }

    if (dto.limit == 0) {
        dto.limit = 15;
    }

    if (dto.field.len == 0) {
        dto.field = "id";
        dto.sort = "desc";
    }

    var pool = global.get_pg_pool();

    var row = (global.get_pg_pool().rowOpts("SELECT COUNT(*) AS total FROM zigcms.upload", .{}, .{}) catch |e| return base.send_error(req, e)) orelse return base.send_ok(req, "数据异常");
    defer row.deinit() catch {};
    const total = row.to(struct { total: i64 = 0 }, .{}) catch |e| return base.send_error(req, e);
    const query = std.mem.join(self.allocator, "", &[_][]const u8{
        "SELECT * FROM zigcms.upload ",
        "ORDER BY ",
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

    const mapper = result.mapper(models.Upload, .{});

    var items = std.ArrayList(models.Upload).init(self.allocator);
    defer items.deinit();
    while (mapper.next() catch |e| return base.send_error(req, e)) |item| {
        items.append(item) catch {};
    }
    base.send_response(req, items, @as(u64, @intCast(total.total)));
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
                    std.log.debug("ids = {any}", .{item.key.str});

                    const items = strings.split(self.allocator, item.value.str, ",") catch return;
                    defer self.allocator.free(items);
                    for (items) |value| {
                        ids.append(strings.to_number(value) catch |e| return base.send_error(
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
        const id_num = strings.to_number(id) catch return base.send_failed(req, "缺少参数");
        ids.append(id_num) catch unreachable;
    }

    if (ids.capacity == 0) return base.send_failed(req, "缺少ID参数");

    std.log.debug("ids = {any}", .{ids.items});

    const sql = "DELETE FROM zigcms.upload WHERE id = $1";
    for (ids.items) |id| {
        _ = global.get_pg_pool().exec(sql, .{id}) catch |e| return base.send_error(
            req,
            e,
        );
    }
    return base.send_ok(req, "删除成功");
}
