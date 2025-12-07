//! 改进版泛型 CRUD 控制器（使用 SQL ORM）
//!
//! 解决原 generic.controller.zig 的痛点：
//! 1. 不再需要手动 struct_2_tuple 转换
//! 2. 自动处理 id 字段和时间戳
//! 3. 使用 ORM QueryBuilder，类型安全
//! 4. 更简洁的代码，接近 Laravel Eloquent 的使用体验
//!
//! ## Laravel Eloquent vs Zig ORM 对比
//!
//! Laravel 风格：
//! ```php
//! User::create($data);
//! User::find($id);
//! User::where('id', $id)->update($data);
//! User::destroy($id);
//! ```
//!
//! Zig ORM 风格：
//! ```zig
//! User.Create(data);
//! User.Find(id);
//! User.Update(id, data);
//! User.Destroy(id);
//! ```

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../modules/strings.zig");
const sql = @import("../services/sql/orm.zig");
const mw = @import("../middlewares/middlewares.zig");
const services = @import("../services/services.zig");

fn lowerStr(comptime s: []const u8) []const u8 {
    comptime {
        var lower: [s.len]u8 = undefined;
        for (s, 0..) |c, i| {
            lower[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
        return &lower;
    }
}

/// 泛型 CRUD 控制器（使用 SQL ORM）
///
/// 使用示例：
/// ```zig
/// const ArticleController = Crud(models.Article, "zigcms");
/// var ctrl = ArticleController.init(allocator);
///
/// // 路由注册
/// router.get("/api/articles", ctrl.list);
/// router.get("/api/article", ctrl.get);
/// router.post("/api/article/save", ctrl.save);
/// router.post("/api/article/delete", ctrl.delete);
/// ```
pub fn Crud(comptime T: type, comptime schema: []const u8) type {
    // 使用 SQL ORM 定义模型
    const OrmModel = sql.defineWithConfig(T, .{
        .table_name = schema ++ "." ++ lowerStr(@typeName(T)),
        .primary_key = "id",
    });

    return struct {
        const Self = @This();
        const MW = mw.Controller(Self);
        const TABLE_NAME = schema ++ "." ++ lowerStr(@typeName(T));

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

        /// 分页列表（需要认证）
        pub const list = MW.requireAuth(listImpl);

        /// 获取单条（需要认证）
        pub const get = MW.requireAuth(getImpl);

        /// 保存（需要认证）
        pub const save = MW.requireAuth(saveImpl);

        /// 删除（需要认证）
        pub const delete = MW.requireAuth(deleteImpl);

        /// 单字段修改（需要认证）
        pub const modify = MW.requireAuth(modifyImpl);

        /// 下拉选择（需要认证）
        pub const select = MW.requireAuth(selectImpl);

        // ====================================================================
        // 实现方法（使用 ORM）
        // ====================================================================

        fn listImpl(self: *Self, req: zap.Request) !void {
            req.parseQuery();

            var dto = dtos.Page{};
            var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
            defer params.deinit();

            for (params.items) |value| {
                if (strings.eql(value.key, "page")) {
                    dto.page = @intCast(strings.to_int(value.value) catch 1);
                } else if (strings.eql(value.key, "limit")) {
                    dto.limit = @intCast(strings.to_int(value.value) catch 10);
                } else if (strings.starts_with(value.key, "sort[")) {
                    dto.field = base.get_sort_field(value.key) orelse "id";
                    dto.sort = value.value;
                }
            }

            if (dto.field.len == 0) {
                dto.field = "id";
                dto.sort = "desc";
            }

            // 使用 ORM 统计总数
            const total = OrmModel.Count() catch |e| return base.send_error(req, e);

            // 使用 ORM QueryBuilder 分页查询
            const order_dir: sql.OrderDir = if (strings.eql(dto.sort, "asc")) .asc else .desc;
            var q = OrmModel.OrderBy(dto.field, order_dir);
            defer q.deinit();
            _ = q.page(dto.page, dto.limit);

            const items_slice = q.get() catch |e| return base.send_error(req, e);
            defer OrmModel.freeModels(self.allocator, items_slice);

            var items = std.ArrayListUnmanaged(T){};
            defer items.deinit(self.allocator);
            for (items_slice) |item| {
                items.append(self.allocator, item) catch {};
            }

            base.send_layui_table_response(req, items.items, total, .{});
        }

        fn getImpl(self: *Self, req: zap.Request) !void {
            req.parseQuery();
            const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id");
            const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

            // 使用 ORM 查询
            const item_opt = OrmModel.Find(id) catch |e| return base.send_error(req, e);
            if (item_opt == null) {
                return base.send_failed(req, "记录不存在");
            }

            var item = item_opt.?;
            defer OrmModel.freeModel(self.allocator, &item);

            return base.send_ok(req, item);
        }

        fn saveImpl(self: *Self, req: zap.Request) !void {
            req.parseBody() catch return base.send_failed(req, "解析请求体失败");

            const body = req.body orelse return base.send_failed(req, "请求体为空");
            const dto = services.json.JSON.decode(T, self.allocator, body) catch return base.send_failed(req, "JSON 解析失败");

            // 设置时间戳
            if (@hasField(T, "update_time")) {
                // @field(dto, "update_time") = std.time.microTimestamp();
            }
            if (@hasField(T, "create_time")) {
                if (@field(dto, "create_time") == null) {
                    // @field(dto, "create_time") = std.time.microTimestamp();
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

        fn deleteImpl(self: *Self, req: zap.Request) !void {
            var ids = std.ArrayListUnmanaged(i32){};
            defer ids.deinit(self.allocator);

            // POST 批量删除
            if (strings.eql(req.method orelse "", "POST")) {
                req.parseBody() catch {};
                if (req.body != null) {
                    var params = req.parametersToOwnedStrList(self.allocator) catch return;
                    defer params.deinit();

                    for (params.items) |item| {
                        if (strings.eql("id", item.key)) {
                            const parts = strings.split(self.allocator, item.value, ",") catch return;
                            defer self.allocator.free(parts);
                            for (parts) |v| {
                                const id: i32 = @intCast(strings.to_int(v) catch continue);
                                ids.append(self.allocator, id) catch {};
                            }
                        }
                    }
                }
            }

            // GET 单个删除
            req.parseQuery();
            if (req.getParamSlice("id")) |id_str| {
                const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));
                ids.append(self.allocator, id) catch {};
            }

            if (ids.items.len == 0) return base.send_failed(req, "缺少 id 参数");

            // 使用 ORM 删除
            var count: usize = 0;
            for (ids.items) |id| {
                const affected = OrmModel.Destroy(id) catch continue;
                if (affected > 0) count += 1;
            }

            return base.send_ok(req, count);
        }

        fn modifyImpl(self: *Self, req: zap.Request) !void {
            req.parseBody() catch return base.send_failed(req, "解析失败");
            if (req.body == null) return base.send_failed(req, "请求体为空");

            var params = req.parametersToOwnedStrList(self.allocator) catch return;
            defer params.deinit();

            var id: i32 = 0;
            var field: []const u8 = "";
            var value: []const u8 = "";

            for (params.items) |item| {
                if (strings.eql("id", item.key)) {
                    id = @intCast(strings.to_int(item.value) catch 0);
                } else if (strings.eql("field", item.key)) {
                    field = item.value;
                } else if (strings.eql("value", item.key)) {
                    value = item.value;
                }
            }

            if (id == 0 or field.len == 0) return base.send_failed(req, "参数不完整");

            // 验证字段（运行时检查）
            var field_valid = false;
            inline for (std.meta.fields(T)) |f| {
                if (std.mem.eql(u8, f.name, field)) {
                    field_valid = true;
                    break;
                }
            }
            if (!field_valid) return base.send_failed(req, "字段不存在");

            // 使用原生 SQL 更新单字段
            const sql_str = strings.sprinf(
                "UPDATE " ++ TABLE_NAME ++ " SET {s} = '{s}', update_time = {d} WHERE id = {d}",
                .{ field, value, std.time.microTimestamp(), id },
            ) catch return base.send_failed(req, "SQL 构建失败");
            defer self.allocator.free(sql_str);

            _ = global.get_db().rawExec(sql_str) catch |e| return base.send_error(req, e);

            return base.send_ok(req, "更新成功");
        }

        fn selectImpl(self: *Self, req: zap.Request) !void {
            // 使用 ORM 获取所有记录
            const items_slice = OrmModel.All() catch return;
            defer OrmModel.freeModels(self.allocator, items_slice);

            var items = std.ArrayListUnmanaged(T){};
            defer items.deinit(self.allocator);

            for (items_slice) |item| {
                items.append(self.allocator, item) catch {};
            }

            base.send_ok(req, items.items);
        }
    };
}
