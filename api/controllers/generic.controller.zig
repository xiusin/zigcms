const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../../shared/utils/strings.zig");
const sql = @import("../../application/services/sql/orm.zig");
const mw = @import("../middleware/middlewares.zig");
const services = @import("../../application/services/services.zig");

/// 泛型 CRUD 控制器（使用 ORM）
///
/// 使用示例：
/// ```zig
/// const ArticleController = Generic(models.Article);
/// var ctrl = ArticleController.init(allocator);
/// ```
pub fn Generic(comptime T: type) type {
    // 动态定义 ORM 模型
    const OrmModel = sql.define(T);

    return struct {
        const Self = @This();
        const MW = mw.Controller(Self);

        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            // 确保模型使用全局数据库连接
            if (!OrmModel.hasDb()) {
                OrmModel.use(global.get_db());
            }
            return .{ .allocator = allocator };
        }

        // ====================================================================
        // 公开 API（使用中间件包装）
        // ====================================================================

        /// 列表查询（需要认证）
        pub const list = MW.requireAuth(listImpl);

        /// 获取单条记录（需要认证）
        pub const get = MW.requireAuth(getImpl);

        /// 删除记录（需要认证）
        pub const delete = MW.requireAuth(deleteImpl);

        /// 保存/更新记录（需要认证）
        pub const save = MW.requireAuth(saveImpl);

        /// 修改单字段（需要认证）
        pub const modify = MW.requireAuth(modifyImpl);

        /// 下拉选择（需要认证）
        pub const select = MW.requireAuth(selectImpl);

        // ====================================================================
        // 实现方法（使用 ORM）
        // ====================================================================

        fn listImpl(self: *Self, req: zap.Request) void {
            var dto = dtos.Page{};
            req.parseQuery();

            var params = req.parametersToOwnedStrList(self.allocator, true) catch unreachable;
            defer params.deinit();

            for (params.items) |value| {
                if (strings.eql(value.key.str, "page")) {
                    dto.page = @as(u32, @intCast(strings.to_int(value.value.str) catch return base.send_failed(req, "page参数错误")));
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

            // 使用 ORM 统计总数
            const total = OrmModel.Count() catch |e| return base.send_error(req, e);

            // 使用 ORM QueryBuilder 分页查询
            const order_dir: sql.mysql.OrderDir = if (strings.eql(dto.sort, "asc")) .asc else .desc;
            var q = OrmModel.OrderBy(dto.field, order_dir);
            defer q.deinit();
            _ = q.page(dto.page, dto.limit);

            const items_slice = q.get() catch |e| return base.send_error(req, e);
            defer OrmModel.freeModels(self.allocator, items_slice);

            // 转换为 ArrayList 用于响应
            var items = std.ArrayList(T).init(self.allocator);
            defer items.deinit();
            for (items_slice) |item| {
                items.append(item) catch {};
            }

            base.send_layui_table_response(req, items, total, .{});
        }

        fn getImpl(self: *Self, req: zap.Request) void {
            req.parseQuery();
            const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
            if (id_str.len == 0) return base.send_failed(req, "id 不能为空");

            const id = strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误");

            // 使用 ORM 查询
            const item_opt = OrmModel.Find(@as(i32, @intCast(id))) catch |e| return base.send_error(req, e);
            if (item_opt == null) {
                return base.send_failed(req, "记录不存在");
            }

            var item = item_opt.?;
            defer OrmModel.freeModel(self.allocator, &item);

            return base.send_ok(req, item);
        }

        fn deleteImpl(self: *Self, req: zap.Request) void {
            var ids = std.ArrayList(i32).init(self.allocator);
            defer ids.deinit();

            if (strings.eql(req.method.?, "POST")) {
                req.parseBody() catch {};
                if (req.body) |_| {
                    var params = req.parametersToOwnedStrList(self.allocator, true) catch return;
                    defer params.deinit();

                    for (params.items) |item| {
                        if (strings.eql("id", item.key.str)) {
                            const items_str = strings.split(self.allocator, item.value.str, ",") catch return;
                            defer self.allocator.free(items_str);
                            for (items_str) |value| {
                                const id: i32 = @intCast(strings.to_int(value) catch continue);
                                ids.append(id) catch {};
                            }
                        }
                    }
                }
            }
            req.parseQuery();

            if (req.getParamSlice("id")) |id| {
                const id_num: i32 = @intCast(strings.to_int(id) catch return base.send_failed(req, "id 格式错误"));
                ids.append(id_num) catch {};
            }

            if (ids.items.len == 0) return base.send_failed(req, "缺少参数");

            // 使用 ORM 删除
            var count: usize = 0;
            for (ids.items) |id| {
                const affected = OrmModel.Destroy(id) catch continue;
                if (affected > 0) count += 1;
            }

            return base.send_ok(req, count);
        }

        fn saveImpl(self: *Self, req: zap.Request) void {
            req.parseBody() catch return base.send_failed(req, "解析请求体失败");

            const body = req.body orelse return base.send_failed(req, "请求体为空");
            var dto = std.json.parseFromSliceLeaky(T, self.allocator, body, .{
                .ignore_unknown_fields = true,
            }) catch return base.send_failed(req, "JSON 解析失败");

            // 设置时间戳
            if (@hasField(T, "update_time")) {
                @field(dto, "update_time") = std.time.microTimestamp();
            }
            if (@hasField(T, "create_time")) {
                if (@field(dto, "create_time") == null) {
                    @field(dto, "create_time") = std.time.microTimestamp();
                }
            }

            // 判断是更新还是插入
            if (@hasField(T, "id")) {
                const id_val = @field(dto, "id");
                if (id_val != null and id_val.? > 0) {
                    // UPDATE - 使用 ORM
                    const affected = OrmModel.Update(id_val.?, dto) catch |e| return base.send_error(req, e);
                    if (affected == 0) {
                        return base.send_failed(req, "更新失败");
                    }
                    return base.send_ok(req, dto);
                }
            }

            // INSERT - 使用 ORM
            var new_item = OrmModel.Create(dto) catch |e| return base.send_error(req, e);
            defer OrmModel.freeModel(self.allocator, &new_item);

            return base.send_ok(req, new_item);
        }

        fn modifyImpl(self: *Self, req: zap.Request) void {
            var modify_dto = dtos.Modify{};
            req.parseBody() catch |e| return base.send_error(req, e);
            if (req.body == null) return base.send_failed(req, "缺少必要参数");

            var params = req.parametersToOwnedStrList(self.allocator, true) catch return base.send_failed(req, "解析参数错误");
            defer params.deinit();

            for (params.items) |item| {
                if (strings.eql("id", item.key.str)) {
                    modify_dto.id = @as(u32, @intCast(strings.to_int(item.value.str) catch return base.send_failed(req, "无法解析ID参数")));
                } else if (strings.eql("field", item.key.str)) {
                    modify_dto.field = item.value.str;
                } else if (strings.eql("value", item.key.str)) {
                    modify_dto.value.? = item.value.str;
                }
            }

            if (modify_dto.id == 0 or modify_dto.field.len == 0 or modify_dto.value == null) {
                return base.send_failed(req, "缺少必要参数");
            }

            // 验证字段安全性
            var field_valid = false;
            inline for (std.meta.fields(T)) |f| {
                if (std.mem.eql(u8, f.name, modify_dto.field)) {
                    field_valid = true;
                    break;
                }
            }
            if (!field_valid) return base.send_failed(req, "非法字段");

            const sql_str = strings.sprinf("UPDATE {s} SET {s}='{s}', update_time={d} WHERE id={d}", .{
                base.get_table_name(T),
                modify_dto.field,
                modify_dto.value.?,
                std.time.microTimestamp(),
                modify_dto.id,
            }) catch return base.send_failed(req, "SQL 构建失败");
            defer self.allocator.free(sql_str);

            _ = global.get_db().rawExec(sql_str) catch |e| return base.send_error(req, e);

            return base.send_ok(req, "更新成功");
        }

        fn selectImpl(self: *Self, req: zap.Request) void {
            _ = req;

            // 使用 ORM 获取所有记录
            const items_slice = OrmModel.All() catch |e| {
                _ = e;
                return;
            };
            defer OrmModel.freeModels(self.allocator, items_slice);

            var items = std.ArrayList(struct { id: ?i32, value: []const u8 }).init(self.allocator);
            defer items.deinit();

            for (items_slice) |item| {
                if (@hasField(T, "id") and @hasField(T, "name")) {
                    items.append(.{
                        .id = @field(item, "id"),
                        .value = @field(item, "name"),
                    }) catch {};
                }
            }

            // 响应需要手动处理，因为这里没有 req
        }
    };
}
