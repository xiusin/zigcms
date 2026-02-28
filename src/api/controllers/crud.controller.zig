const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const json_mod = @import("../../application/services/json/json.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../core/primitives/global.zig");
const strings = @import("../../core/utils/strings.zig");
const role_ext = @import("system_role.controller.zig");

/// 生成通用 CRUD 控制器。
pub fn Crud(comptime T: type, comptime schema: []const u8) type {
    const table_name = comptime buildTableName(T, schema);
    const OrmModel = sql.defineWithConfig(T, .{
        .table_name = table_name,
        .primary_key = "id",
    });

    return struct {
        const Self = @This();

        allocator: Allocator,

        /// 初始化通用控制器。
        pub fn init(allocator: Allocator) Self {
            if (!OrmModel.hasDb()) {
                OrmModel.use(global.get_db());
            }
            return .{ .allocator = allocator };
        }

        /// 分页查询处理器。
        pub const list = listImpl;

        /// 获取详情处理器。
        pub const get = getImpl;

        /// 保存数据处理器。
        pub const save = saveImpl;

        /// 删除数据处理器。
        pub const delete = deleteImpl;

        /// 单字段更新处理器。
        pub const modify = modifyImpl;

        /// 下拉列表处理器。
        pub const select = selectImpl;

        /// 分页查询。
        fn listImpl(self: *Self, req: zap.Request) !void {
            req.parseQuery();
            if (std.mem.eql(u8, table_name, "sys_role")) {
                const version = role_ext.getRoleCacheVersion(self.allocator);
                const need_free_version = !std.mem.eql(u8, version, "0");
                defer if (need_free_version) self.allocator.free(version);
                const etag = std.fmt.allocPrint(self.allocator, "\"{s}\"", .{version}) catch return base.send_failed(req, "缓存标签构建失败");
                defer self.allocator.free(etag);
                if (req.getHeader("if-none-match")) |if_none_match| {
                    if (std.mem.eql(u8, std.mem.trim(u8, if_none_match, " \t\r\n"), etag)) {
                        req.setStatus(.not_modified);
                        return;
                    }
                }
                req.setHeader("ETag", etag) catch {};
                req.setHeader("Cache-Control", "private, max-age=60") catch {};
            }

            var page: i32 = 1;
            var limit: i32 = 10;
            var sort_field: []const u8 = "id";
            var sort_dir: []const u8 = "desc";

            var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
                return base.send_error(req, err);
            };
            defer params.deinit();

            for (params.items) |param| {
                if (strings.eql(param.key, "page")) {
                    page = @intCast(strings.to_int(param.value) catch 1);
                } else if (strings.eql(param.key, "limit")) {
                    limit = @intCast(strings.to_int(param.value) catch 10);
                } else if (strings.starts_with(param.key, "sort[")) {
                    sort_field = base.get_sort_field(param.key) orelse "id";
                    sort_dir = param.value;
                }
            }

            var q = OrmModel.Query();
            defer q.deinit();

            const total = q.count() catch |err| return base.send_error(req, err);
            _ = q.orderBy(sort_field, if (strings.eql(sort_dir, "asc")) sql.OrderDir.asc else sql.OrderDir.desc);
            _ = q.page(@intCast(page), @intCast(limit));

            const rows = q.get() catch |err| return base.send_error(req, err);
            defer OrmModel.freeModels(rows);

            var items = std.ArrayListUnmanaged(T){};
            defer items.deinit(self.allocator);
            for (rows) |row| {
                items.append(self.allocator, row) catch {};
            }

            base.send_layui_table_response(req, items.items, total, .{});
        }

        /// 获取详情。
        fn getImpl(self: *Self, req: zap.Request) !void {
            _ = self;
            req.parseQuery();
            const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
            const id: usize = strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误");

            const data_opt = OrmModel.Find(id) catch |err| return base.send_error(req, err);
            if (data_opt == null) {
                return base.send_failed(req, "记录不存在");
            }

            var data = data_opt.?;
            defer OrmModel.freeModel(&data);
            base.send_ok(req, data);
        }

        /// 保存数据。
        fn saveImpl(self: *Self, req: zap.Request) !void {
            req.parseBody() catch return base.send_failed(req, "解析请求体失败");
            const body = req.body orelse return base.send_failed(req, "请求体为空");

            var dto = json_mod.JSON.decode(T, self.allocator, body) catch {
                return base.send_failed(req, "解析数据失败");
            };
            defer json_mod.JSON.free(T, self.allocator, &dto);

            if (extractId(T, dto)) |id| {
                if (id > 0) {
                    _ = OrmModel.Update(id, dto) catch |err| return base.send_error(req, err);
                    if (std.mem.eql(u8, table_name, "sys_role")) {
                        role_ext.bumpRoleCacheVersion(self.allocator);
                    }
                    return base.send_ok(req, dto);
                }
            }

            var created = OrmModel.Create(dto) catch |err| return base.send_error(req, err);
            defer OrmModel.freeModel(&created);
            if (std.mem.eql(u8, table_name, "sys_role")) {
                role_ext.bumpRoleCacheVersion(self.allocator);
            }
            base.send_ok(req, created);
        }

        /// 删除数据。
        fn deleteImpl(self: *Self, req: zap.Request) !void {
            req.parseQuery();
            const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
            const id: usize = strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误");

            _ = OrmModel.Destroy(id) catch |err| return base.send_error(req, err);
            if (std.mem.eql(u8, table_name, "sys_role")) {
                role_ext.bumpRoleCacheVersion(self.allocator);
            }
            base.send_ok(req, "删除成功");
        }

        /// 单字段更新。
        fn modifyImpl(self: *Self, req: zap.Request) !void {
            req.parseBody() catch return base.send_failed(req, "解析请求体失败");
            const body = req.body orelse return base.send_failed(req, "请求体为空");

            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
                return base.send_failed(req, "解析数据失败");
            };
            defer parsed.deinit();

            if (parsed.value != .object) {
                return base.send_failed(req, "参数格式错误");
            }

            const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id 参数");
            const field_val = parsed.value.object.get("field") orelse return base.send_failed(req, "缺少 field 参数");
            const value_val = parsed.value.object.get("value") orelse return base.send_failed(req, "缺少 value 参数");

            if (id_val != .integer or field_val != .string) {
                return base.send_failed(req, "参数格式错误");
            }

            const id = id_val.integer;
            const field_name = field_val.string;

            var model = (OrmModel.Find(id) catch |err| return base.send_error(req, err)) orelse {
                return base.send_failed(req, "记录不存在");
            };
            defer OrmModel.freeModel(&model);

            if (!setFieldValue(T, &model, field_name, value_val)) {
                return base.send_failed(req, "字段不存在或类型不匹配");
            }

            _ = OrmModel.Update(id, model) catch |err| return base.send_error(req, err);
            if (std.mem.eql(u8, table_name, "sys_role")) {
                role_ext.bumpRoleCacheVersion(self.allocator);
            }
            base.send_ok(req, "更新成功");
        }

        /// 下拉列表。
        fn selectImpl(self: *Self, req: zap.Request) !void {
            var q = OrmModel.Query();
            defer q.deinit();
            _ = q.limit(100);

            const rows = q.get() catch |err| return base.send_error(req, err);
            defer OrmModel.freeModels(rows);

            var items = std.ArrayListUnmanaged(T){};
            defer items.deinit(self.allocator);
            for (rows) |row| {
                items.append(self.allocator, row) catch {};
            }

            base.send_ok(req, items.items);
        }
    };
}

/// 计算模型表名。
fn buildTableName(comptime T: type, comptime schema: []const u8) []const u8 {
    const name = comptime shortTypeName(@typeName(T));
    const snake = comptime camelToSnake(name);
    return comptime std.fmt.comptimePrint("{s}.{s}", .{ schema, snake });
}

/// 截取类型短名。
fn shortTypeName(comptime full_name: []const u8) []const u8 {
    if (std.mem.lastIndexOf(u8, full_name, ".")) |idx| {
        return full_name[idx + 1 ..];
    }
    return full_name;
}

/// 将类型名转换为蛇形。
fn camelToSnake(comptime name: []const u8) []const u8 {
    var buf: [128]u8 = undefined;
    var out_idx: usize = 0;

    inline for (name, 0..) |ch, idx| {
        const is_upper = ch >= 'A' and ch <= 'Z';
        if (is_upper and idx != 0) {
            buf[out_idx] = '_';
            out_idx += 1;
        }
        buf[out_idx] = if (is_upper) ch + 32 else ch;
        out_idx += 1;
    }

    return buf[0..out_idx];
}

/// 提取结构体 ID。
fn extractId(comptime T: type, data: T) ?i64 {
    if (!@hasField(T, "id")) return null;

    const field_info = @typeInfo(@TypeOf(@field(data, "id")));
    return switch (field_info) {
        .optional => blk: {
            const value = @field(data, "id");
            if (value) |v| break :blk @as(i64, @intCast(v));
            break :blk null;
        },
        .int, .comptime_int => @as(i64, @intCast(@field(data, "id"))),
        else => null,
    };
}

/// 写入字段值。
fn setFieldValue(comptime T: type, model: *T, field_name: []const u8, value: std.json.Value) bool {
    inline for (std.meta.fields(T)) |f| {
        if (std.mem.eql(u8, f.name, field_name)) {
            return assignFieldValue(f.type, &@field(model.*, f.name), value);
        }
    }
    return false;
}

/// 按字段类型赋值。
fn assignFieldValue(comptime FieldType: type, target: *FieldType, value: std.json.Value) bool {
    const info = @typeInfo(FieldType);
    switch (info) {
        .optional => |opt| {
            if (value == .null) {
                target.* = null;
                return true;
            }
            var tmp: opt.child = undefined;
            if (!assignFieldValue(opt.child, &tmp, value)) return false;
            target.* = tmp;
            return true;
        },
        .int, .comptime_int => {
            if (value != .integer) return false;
            target.* = @intCast(value.integer);
            return true;
        },
        .float, .comptime_float => {
            if (value == .float) {
                target.* = @floatCast(value.float);
                return true;
            }
            if (value == .integer) {
                target.* = @floatFromInt(value.integer);
                return true;
            }
            return false;
        },
        .bool => {
            if (value != .bool) return false;
            target.* = value.bool;
            return true;
        },
        .pointer => |ptr| {
            if (ptr.size != .slice or ptr.child != u8) return false;
            if (value != .string) return false;
            target.* = value.string;
            return true;
        },
        else => return false,
    }
}
