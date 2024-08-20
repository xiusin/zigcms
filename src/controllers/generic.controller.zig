const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/models.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../modules/strings.zig");

pub fn Generic(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn tablename(_: *Self) []const u8 {
            return base.get_table_name(T);
        }

        pub fn list(self: *Self, req: zap.Request) void {
            var dto = dtos.Page{};

            req.parseQuery();
            if (req.getParamSlice("page")) |page| {
                dto.page = std.fmt.parseInt(
                    u32,
                    page,
                    10,
                ) catch return base.send_failed(req, "page参数类型错误");
            }

            if (req.getParamSlice("limit")) |limit| {
                dto.limit = std.fmt.parseInt(
                    u32,
                    limit,
                    10,
                ) catch return base.send_failed(req, "limit参数类型错误");
            }

            const query = strings.sprinf(
                "SELECT * FROM {s} ORDER BY id DESC OFFSET $1 LIMIT $2",
                .{self.tablename()},
            ) catch unreachable;

            var result = global.get_pg_pool().queryOpts(query, .{ (dto.page - 1) * dto.limit, dto.limit }, .{
                .column_names = true,
            }) catch |e| return base.send_error(req, e);

            defer result.deinit();

            const mapper = result.mapper(T, .{ .allocator = self.allocator });
            var articles = std.ArrayList(T).init(self.allocator);
            defer articles.deinit();
            while (mapper.next() catch |e| return base.send_error(req, e)) |article| {
                articles.append(article) catch {};
            }
            base.send_layui_table_response(req, articles, 100, .{});
        }

        pub fn get(self: *Self, req: zap.Request) void {
            req.parseQuery();
            const id_ = req.getParamSlice("id") orelse return;
            if (id_.len == 0) return;
            var pool = global.get_pg_pool();
            const id = strings.to_number(id_) catch return base.send_failed(req, "缺少必要参数");

            const query = strings.sprinf(
                "SELECT * FROM {s} WHERE id = $1",
                .{self.tablename()},
            ) catch unreachable;

            var row = (pool.rowOpts(
                query,
                .{id},
                .{ .column_names = true },
            ) catch |e| return base.send_error(req, e)) orelse return base.send_failed(req, "记录不存在");

            defer row.deinit() catch {};
            const item = row.to(T, .{ .map = .name }) catch |e| return base.send_error(req, e);
            return base.send_ok(req, item);
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
                const id_num = strings.to_number(id) catch return;
                ids.append(id_num) catch unreachable;
            }

            if (ids.capacity == 0) return base.send_failed(req, "缺少参数");

            const sql = strings.sprinf("DELETE FROM {s} WHERE id = $1", .{self.tablename()}) catch return;
            for (ids.items) |id| {
                _ = global.get_pg_pool().exec(sql, .{id}) catch |e| return base.send_error(
                    req,
                    e,
                );
            }
            return base.send_ok(req, "删除成功");
        }

        pub fn save(self: *Self, req: zap.Request) void {
            req.parseBody() catch |e| return base.send_error(req, e);
            var dto: T = undefined;
            if (req.body) |body| {
                std.log.debug("body = {s}", .{body});
                dto = std.json.parseFromSliceLeaky(T, self.allocator, body, .{
                    .ignore_unknown_fields = true,
                }) catch return base.send_failed(req, "解析参数错误");
            }
            dto.update_time = std.time.microTimestamp();

            var row: ?i64 = 0;
            var pool = global.get_pg_pool();

            // TODO 切换为动态元祖内容
            const update = .{
                dto.title,
            };

            if (dto.id) |id| {
                dto.create_time = std.time.microTimestamp();
                const sql = base.build_update_sql(
                    T,
                    self.allocator,
                ) catch return base.send_failed(req, "保存失败");
                defer self.allocator.free(sql);

                row = pool.exec(sql, update ++ .{id}) catch |e| return base.send_error(req, e);
            } else {
                const sql = base.build_insert_sql(
                    T,
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
    };
}
