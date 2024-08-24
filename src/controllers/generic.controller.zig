const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
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

        pub fn list(self: *Self, req: zap.Request) void {
            var dto = dtos.Page{};
            req.parseQuery();

            var params = req.parametersToOwnedStrList(self.allocator, true) catch unreachable;
            defer params.deinit();

            for (params.items) |value| {
                if (strings.eql(value.key.str, "page")) {
                    dto.limit = @as(u32, @intCast(strings.to_int(value.key.str) catch return base.send_failed(req, "page参数错误")));
                }

                if (strings.eql(value.key.str, "limit")) {
                    dto.limit = @as(u32, @intCast(strings.to_int(value.value.str) catch return base.send_failed(req, "limit参数失败")));
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

            var row = (global.get_pg_pool().row(
                strings.sprinf("SELECT COUNT(*) AS total FROM {s}", .{
                    base.get_table_name(T),
                }) catch unreachable,
                .{},
            ) catch |e| return base.send_error(req, e)) orelse return base.send_ok(req, "数据异常");

            defer row.deinit() catch {};
            const total = row.to(struct { total: i64 = 0 }, .{}) catch |e| return base.send_error(req, e);
            const query = strings.sprinf("SELECT * FROM {s} ORDER BY {s} {s} OFFSET $1 LIMIT $2", .{
                base.get_table_name(T),
                dto.field,
                dto.sort,
            }) catch unreachable;

            defer self.allocator.free(query);

            var result = global.get_pg_pool().queryOpts(query, .{ (dto.page - 1) * dto.limit, dto.limit }, .{
                .column_names = true,
            }) catch |e| return base.send_error(req, e);

            defer result.deinit();

            var items = std.ArrayList(T).init(self.allocator);
            defer items.deinit();
            {
                const mapper = result.mapper(T, .{ .allocator = self.allocator });
                while (mapper.next() catch |e| return base.send_error(req, e)) |item| {
                    items.append(item) catch {};
                }
            }
            base.send_layui_table_response(req, items, @as(u64, @intCast(total.total)), .{});
        }

        pub fn get(_: *Self, req: zap.Request) void {
            req.parseQuery();
            const id_ = req.getParamSlice("id") orelse return;
            if (id_.len == 0) return;
            var pool = global.get_pg_pool();
            const id = strings.to_int(id_) catch return base.send_failed(req, "缺少必要参数");

            const query = strings.sprinf(
                "SELECT * FROM {s} WHERE id = $1",
                .{base.get_table_name(T)},
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
                const id_num = strings.to_int(id) catch return;
                ids.append(id_num) catch unreachable;
            }

            if (ids.capacity == 0) return base.send_failed(req, "缺少参数");

            const sql = strings.sprinf("DELETE FROM {s} WHERE id = $1", .{
                base.get_table_name(T),
            }) catch return;

            for (ids.items) |id| {
                _ = global.get_pg_pool().exec(sql, .{id}) catch |e| return base.send_error(
                    req,
                    e,
                );
            }
            return base.send_ok(req, "删除成功");
        }

        pub fn save(self: *Self, req: zap.Request) void {
            req.parseBody() catch unreachable;
            var dto: T = undefined;
            if (req.body) |body| {
                std.log.debug("body = {s}", .{body});
                dto = std.json.parseFromSliceLeaky(T, self.allocator, body, .{
                    .ignore_unknown_fields = true,
                }) catch return base.send_failed(req, "解析参数错误");
            }
            dto.update_time = std.time.microTimestamp();
            if (dto.create_time == null) dto.create_time = std.time.microTimestamp();

            var row: ?i64 = 0;
            var pool = global.get_pg_pool();

            var update = std.mem.zeroes(global.struct_2_tuple(T));

            inline for (@typeInfo(T).Struct.fields, 0..) |field, index| {
                if (index >= 1 and !std.mem.eql(u8, field.name, "id")) { // 绕过编译期
                    @field(update, std.fmt.comptimePrint("{d}", .{index - 1})) = @field(dto, field.name);
                }
            }

            pretty.print(self.allocator, .{update}, .{}) catch unreachable;

            if (dto.id) |id| {
                const sql = base.build_update_sql(T, self.allocator) catch return base.send_failed(req, "保存失败");
                defer self.allocator.free(sql);

                row = pool.exec(sql, update ++ .{id}) catch |e| return base.send_error(req, e);
            } else {
                const sql = base.build_insert_sql(T, self.allocator) catch return base.send_failed(req, "保存失败");
                defer self.allocator.free(sql);
                row = pool.exec(sql, update) catch |e| return base.send_error(req, e);
            }

            if (row == null or row == 0) {
                return base.send_failed(req, "保存失败");
            }
            return base.send_ok(req, dto);
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

            const sql = strings.sprinf("UPDATE {s} SET {s}=$2, update_time = $3 WHERE id = $1", .{
                base.get_table_name(T),
                dto.field,
            }) catch unreachable;

            defer self.allocator.free(sql);
            _ = (global.get_pg_pool().exec(sql, .{
                dto.id,
                dto.value.?,
                std.time.milliTimestamp(),
            }) catch |e| return base.send_error(
                req,
                e,
            )) orelse return base.send_failed(req, "更新失败");
            return base.send_ok(req, "更新成功");
        }
    };
}
