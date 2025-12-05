//! 改进版泛型 CRUD 控制器
//!
//! 解决原 generic.controller.zig 的痛点：
//! 1. 不再需要手动 struct_2_tuple 转换
//! 2. 自动处理 id 字段和时间戳
//! 3. SQL 在编译期生成，类型安全
//! 4. 更简洁的代码，接近 Go 的使用体验
//!
//! ## Go vs Zig 对比
//!
//! Go GORM 风格：
//! ```go
//! db.Create(&user)
//! db.First(&user, id)
//! db.Model(&user).Updates(user)
//! db.Delete(&user, id)
//! ```
//!
//! Zig Crud 控制器：
//! ```zig
//! // 自动处理 JSON 解析、类型转换、SQL 生成
//! // 只需定义路由，控制器自动完成 CRUD
//! ```

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const dtos = @import("../dto/dtos.zig");
const strings = @import("../modules/strings.zig");
const orm = @import("../services/orm/orm.zig");
const mw = @import("../middlewares/middlewares.zig");

/// 泛型 CRUD 控制器
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
    return struct {
        const Self = @This();
        const Meta = orm.EntityMeta(T);
        const MW = mw.Controller(Self);

        allocator: Allocator,

        // 编译期生成的 SQL（零运行时开销）
        const INSERT_SQL = Meta.insertSQL(schema);
        const UPDATE_SQL = Meta.updateSQL(schema);
        const SELECT_SQL = Meta.selectSQL(schema);
        const DELETE_SQL = Meta.deleteSQL(schema);
        const TABLE_NAME = schema ++ "." ++ lowerStr(Meta.table_name);

        pub fn init(allocator: Allocator) Self {
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
        // 实现方法
        // ====================================================================

        fn listImpl(self: *Self, req: zap.Request) void {
            req.parseQuery();

            var dto = dtos.Page{};
            var params = req.parametersToOwnedStrList(self.allocator, true) catch unreachable;
            defer params.deinit();

            for (params.items) |value| {
                if (strings.eql(value.key.str, "page")) {
                    dto.page = @intCast(strings.to_int(value.value.str) catch 1);
                } else if (strings.eql(value.key.str, "limit")) {
                    dto.limit = @intCast(strings.to_int(value.value.str) catch 10);
                } else if (strings.starts_with(value.key.str, "sort[")) {
                    dto.field = base.get_sort_field(value.key.str) orelse "id";
                    dto.sort = value.value.str;
                }
            }

            if (dto.field.len == 0) {
                dto.field = "id";
                dto.sort = "desc";
            }

            var pool = global.get_pg_pool();

            // 查询总数
            const count_sql = "SELECT COUNT(*) AS total FROM " ++ TABLE_NAME;
            var count_row = (pool.row(count_sql, .{}) catch |e| return base.send_error(req, e)) orelse
                return base.send_failed(req, "查询失败");
            defer count_row.deinit() catch {};
            const total = (count_row.to(struct { total: i64 }, .{}) catch |e| return base.send_error(req, e)).total;

            // 查询数据
            const offset = (dto.page - 1) * dto.limit;
            const query = strings.sprinf(SELECT_SQL ++ " ORDER BY {s} {s} OFFSET $1 LIMIT $2", .{
                dto.field,
                dto.sort,
            }) catch unreachable;

            var result = pool.queryOpts(query, .{ offset, dto.limit }, .{ .column_names = true }) catch |e|
                return base.send_error(req, e);
            defer result.deinit();

            var items = std.ArrayList(T).init(self.allocator);
            defer items.deinit();
            {
                const mapper = result.mapper(T, .{ .allocator = self.allocator });
                while (mapper.next() catch |e| return base.send_error(req, e)) |item| {
                    items.append(item) catch {};
                }
            }

            base.send_layui_table_response(req, items, @intCast(total), .{});
        }

        fn getImpl(self: *Self, req: zap.Request) void {
            _ = self;
            req.parseQuery();
            const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id");
            const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

            const sql = SELECT_SQL ++ " WHERE id = $1";
            var pool = global.get_pg_pool();

            var row = (pool.rowOpts(sql, .{id}, .{ .column_names = true }) catch |e|
                return base.send_error(req, e)) orelse return base.send_failed(req, "记录不存在");
            defer row.deinit() catch {};

            const item = row.to(T, .{ .map = .name }) catch |e| return base.send_error(req, e);
            return base.send_ok(req, item);
        }

        fn saveImpl(self: *Self, req: zap.Request) void {
            req.parseBody() catch return base.send_failed(req, "解析请求体失败");

            const body = req.body orelse return base.send_failed(req, "请求体为空");
            var dto = std.json.parseFromSliceLeaky(T, self.allocator, body, .{
                .ignore_unknown_fields = true,
            }) catch return base.send_failed(req, "JSON 解析失败");

            // 自动设置时间戳
            Meta.setTimestamps(&dto, Meta.getId(dto) == null or Meta.getId(dto).? == 0);

            var pool = global.get_pg_pool();
            const params = Meta.toParams(dto);

            if (Meta.getId(dto)) |id| {
                if (id > 0) {
                    // UPDATE
                    const affected = pool.exec(UPDATE_SQL, params ++ .{id}) catch |e|
                        return base.send_error(req, e);
                    if (affected == null or affected.? == 0) {
                        return base.send_failed(req, "更新失败");
                    }
                    return base.send_ok(req, dto);
                }
            }

            // INSERT
            var row = (pool.rowOpts(INSERT_SQL, params, .{ .column_names = true }) catch |e|
                return base.send_error(req, e)) orelse return base.send_failed(req, "插入失败");
            defer row.deinit() catch {};

            const result = row.to(struct { id: i32 }, .{}) catch |e| return base.send_error(req, e);
            @field(dto, "id") = result.id;
            return base.send_ok(req, dto);
        }

        fn deleteImpl(self: *Self, req: zap.Request) void {
            var ids = std.ArrayList(i32).init(self.allocator);
            defer ids.deinit();

            // POST 批量删除
            if (strings.eql(req.method orelse "", "POST")) {
                req.parseBody() catch {};
                if (req.body != null) {
                    var params = req.parametersToOwnedStrList(self.allocator, true) catch return;
                    defer params.deinit();

                    for (params.items) |item| {
                        if (strings.eql("id", item.key.str)) {
                            const parts = strings.split(self.allocator, item.value.str, ",") catch return;
                            defer self.allocator.free(parts);
                            for (parts) |v| {
                                const id: i32 = @intCast(strings.to_int(v) catch continue);
                                ids.append(id) catch {};
                            }
                        }
                    }
                }
            }

            // GET 单个删除
            req.parseQuery();
            if (req.getParamSlice("id")) |id_str| {
                const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));
                ids.append(id) catch {};
            }

            if (ids.items.len == 0) return base.send_failed(req, "缺少 id 参数");

            var pool = global.get_pg_pool();
            var count: usize = 0;
            for (ids.items) |id| {
                const affected = pool.exec(DELETE_SQL, .{id}) catch continue;
                if (affected != null and affected.? > 0) count += 1;
            }

            return base.send_ok(req, count);
        }

        fn modifyImpl(self: *Self, req: zap.Request) void {
            req.parseBody() catch return base.send_failed(req, "解析失败");
            if (req.body == null) return base.send_failed(req, "请求体为空");

            var params = req.parametersToOwnedStrList(self.allocator, true) catch return;
            defer params.deinit();

            var id: i32 = 0;
            var field: []const u8 = "";
            var value: []const u8 = "";

            for (params.items) |item| {
                if (strings.eql("id", item.key.str)) {
                    id = @intCast(strings.to_int(item.value.str) catch 0);
                } else if (strings.eql("field", item.key.str)) {
                    field = item.value.str;
                } else if (strings.eql("value", item.key.str)) {
                    value = item.value.str;
                }
            }

            if (id == 0 or field.len == 0) return base.send_failed(req, "参数不完整");

            // 验证字段是否存在于模型中（编译期检查）
            const valid = comptime blk: {
                for (Meta.field_names) |name| {
                    if (std.mem.eql(u8, name, field)) break :blk true;
                }
                break :blk false;
            };

            // 注意：由于 field 是运行时值，这里无法进行编译期验证
            // 需要运行时检查
            var field_valid = false;
            inline for (Meta.field_names) |name| {
                if (std.mem.eql(u8, name, field)) {
                    field_valid = true;
                    break;
                }
            }
            if (!field_valid and !valid) return base.send_failed(req, "字段不存在");

            const sql = strings.sprinf(
                "UPDATE " ++ TABLE_NAME ++ " SET {s} = $1, update_time = $2 WHERE id = $3",
                .{field},
            ) catch return base.send_failed(req, "SQL 构建失败");
            defer self.allocator.free(sql);

            _ = global.get_pg_pool().exec(sql, .{ value, std.time.microTimestamp(), id }) catch |e|
                return base.send_error(req, e);

            return base.send_ok(req, "更新成功");
        }

        fn selectImpl(self: *Self, req: zap.Request) void {
            var pool = global.get_pg_pool();
            var result = pool.queryOpts(SELECT_SQL, .{}, .{ .column_names = true }) catch |e|
                return base.send_error(req, e);
            defer result.deinit();

            var items = std.ArrayList(T).init(self.allocator);
            defer items.deinit();

            const mapper = result.mapper(T, .{ .allocator = self.allocator });
            while (mapper.next() catch |e| return base.send_error(req, e)) |item| {
                items.append(item) catch {};
            }

            return base.send_ok(req, items);
        }

        fn lowerStr(comptime s: []const u8) []const u8 {
            comptime {
                var lower: [s.len]u8 = undefined;
                for (s, 0..) |c, i| {
                    lower[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
                }
                return &lower;
            }
        }
    };
}
