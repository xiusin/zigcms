//! 动态 CRUD 控制器
//!
//! 该控制器提供：
//! - 动态表的 CRUD 操作
//! - 运行时表结构发现
//! - 表名白名单安全控制

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const dynamic = @import("../../application/services/sql/dynamic.zig");
const orm = @import("../../application/services/sql/orm.zig");

const Self = @This();

allocator: Allocator,
crud: dynamic.DynamicCrud,

/// 允许的表名白名单
const ALLOWED_TABLES = [_][]const u8{
    "sys_dict",
    "sys_menu",
    "sys_role",
    "sys_user",
    "sys_department",
    "sys_position",
    "sys_setting",
    "sys_task",
};

pub fn init(allocator: Allocator) Self {
    var crud = dynamic.DynamicCrud.init(allocator, global.get_db());
    crud.setAllowedTables(&ALLOWED_TABLES);

    return .{
        .allocator = allocator,
        .crud = crud,
    };
}

pub fn deinit(self: *Self) void {
    self.crud.deinit();
}

/// 获取列表
/// GET /dynamic/:table/list?page=1&limit=10&order_by=id&order=desc
pub fn list(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    // 检查表名是否允许
    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    // 解析分页参数
    const page_str = req.getParamSlice("page") orelse "1";
    const limit_str = req.getParamSlice("limit") orelse "10";
    const order_by = req.getParamSlice("order_by");
    const order = req.getParamSlice("order") orelse "asc";

    const page = strings.to_int(page_str) catch 1;
    const limit = strings.to_int(limit_str) catch 10;
    const offset: u32 = @intCast((page - 1) * limit);

    // 构建排序
    var order_clause: ?[]u8 = null;
    defer if (order_clause) |oc| self.allocator.free(oc);

    if (order_by) |ob| {
        order_clause = std.fmt.allocPrint(self.allocator, "{s} {s}", .{ ob, order }) catch null;
    }

    // 执行查询
    var result = self.crud.select(table_name, .{
        .order_by = order_clause,
        .limit = @intCast(limit),
        .offset = offset,
    }) catch |err| {
        return base.send_error(req, err);
    };
    defer result.deinit();

    // 转换为 JSON 友好格式
    var items = std.ArrayListUnmanaged(std.json.Value){};
    defer {
        for (items.items) |*val| {
            if (val.* == .object) {
                val.object.deinit();
            }
        }
        items.deinit(self.allocator);
    }

    for (result.rows) |*row| {
        var obj = std.json.ObjectMap.init(self.allocator);

        var iter = row.fields.iterator();
        while (iter.next()) |entry| {
            const json_value = fieldValueToJson(entry.value_ptr.*);
            obj.put(entry.key_ptr.*, json_value) catch {};
        }

        items.append(self.allocator, .{ .object = obj }) catch {};
    }

    base.send_layui_table_response(req, items.items, result.count(), .{});
}

/// 获取单条记录
/// GET /dynamic/:table/get?id=1
pub fn get(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const id_str = req.getParamSlice("id") orelse {
        return base.send_failed(req, "缺少 ID 参数");
    };

    const id = strings.to_int(id_str) catch {
        return base.send_failed(req, "ID 格式错误");
    };

    // 查询单条记录
    const where_clause = std.fmt.allocPrint(self.allocator, "id = {d}", .{id}) catch {
        return base.send_failed(req, "内部错误");
    };
    defer self.allocator.free(where_clause);

    var result = self.crud.select(table_name, .{
        .where = where_clause,
        .limit = 1,
    }) catch |err| {
        return base.send_error(req, err);
    };
    defer result.deinit();

    if (result.isEmpty()) {
        return base.send_failed(req, "记录不存在");
    }

    // 转换第一条记录
    const row = &result.rows[0];
    var obj = std.json.ObjectMap.init(self.allocator);
    defer obj.deinit();

    var iter = row.fields.iterator();
    while (iter.next()) |entry| {
        const json_value = fieldValueToJson(entry.value_ptr.*);
        obj.put(entry.key_ptr.*, json_value) catch {};
    }

    base.send_ok(req, obj);
}

/// 保存记录（新增或更新）
/// POST /dynamic/:table/save
pub fn save(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    req.parseBody() catch {
        return base.send_failed(req, "解析请求体失败");
    };

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const body = req.body orelse {
        return base.send_failed(req, "请求体为空");
    };

    // 解析 JSON 到动态模型
    var model = dynamic.DynamicModel.init(self.allocator);
    defer model.deinit();

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 解析失败");
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        return base.send_failed(req, "请求体必须是 JSON 对象");
    }

    var id_value: ?i64 = null;

    var obj_iter = parsed.value.object.iterator();
    while (obj_iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        if (std.mem.eql(u8, key, "id")) {
            if (value == .integer) {
                id_value = value.integer;
            }
            continue; // 不设置 id 到模型中
        }

        switch (value) {
            .string => |s| model.setString(key, s) catch {},
            .integer => |i| model.setInt(key, i) catch {},
            .float => |f| model.set(key, .{ .float_value = f }) catch {},
            .bool => |b| model.set(key, .{ .bool_value = b }) catch {},
            .null => model.setNull(key) catch {},
            else => {},
        }
    }

    // 判断是新增还是更新
    if (id_value) |id| {
        if (id > 0) {
            // 更新
            const affected = self.crud.update(table_name, id, &model) catch |err| {
                return base.send_error(req, err);
            };
            base.send_ok(req, .{ .affected = affected, .id = id });
            return;
        }
    }

    // 新增
    const new_id = self.crud.insert(table_name, &model) catch |err| {
        return base.send_error(req, err);
    };
    base.send_ok(req, .{ .id = new_id });
}

/// 删除记录
/// POST /dynamic/:table/delete?id=1 或 ids=1,2,3
pub fn delete(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    // 支持单个 ID 或多个 ID
    if (req.getParamSlice("id")) |id_str| {
        const id = strings.to_int(id_str) catch {
            return base.send_failed(req, "ID 格式错误");
        };

        const affected = self.crud.delete(table_name, id) catch |err| {
            return base.send_error(req, err);
        };
        base.send_ok(req, .{ .affected = affected });
        return;
    }

    if (req.getParamSlice("ids")) |ids_str| {
        var ids = std.ArrayListUnmanaged(i64){};
        defer ids.deinit(self.allocator);

        var iter = std.mem.splitScalar(u8, ids_str, ',');
        while (iter.next()) |id_part| {
            const trimmed = std.mem.trim(u8, id_part, " ");
            if (strings.to_int(trimmed)) |id| {
                ids.append(self.allocator, id) catch {};
            } else |_| {}
        }

        if (ids.items.len == 0) {
            return base.send_failed(req, "没有有效的 ID");
        }

        const affected = self.crud.deleteMany(table_name, ids.items) catch |err| {
            return base.send_error(req, err);
        };
        base.send_ok(req, .{ .affected = affected });
        return;
    }

    base.send_failed(req, "缺少 id 或 ids 参数");
}

/// 获取表结构
/// GET /dynamic/:table/schema
pub fn schema(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const table_schema = self.crud.discoverSchema(table_name) catch |err| {
        return base.send_error(req, err);
    };

    // 转换为 JSON 友好格式
    var columns = std.ArrayListUnmanaged(struct {
        name: []const u8,
        type: []const u8,
        nullable: bool,
        primary_key: bool,
        auto_increment: bool,
    }){};
    defer columns.deinit(self.allocator);

    for (table_schema.columns) |col| {
        columns.append(self.allocator, .{
            .name = col.name,
            .type = @tagName(col.sql_type),
            .nullable = col.is_nullable,
            .primary_key = col.is_primary_key,
            .auto_increment = col.is_auto_increment,
        }) catch {};
    }

    base.send_ok(req, .{
        .table_name = table_schema.table_name,
        .primary_key = table_schema.primary_key,
        .columns = columns.items,
    });
}

/// 批量保存记录
/// POST /dynamic/:table/batch_save
pub fn batchSave(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    req.parseBody() catch {
        return base.send_failed(req, "解析请求体失败");
    };

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const body = req.body orelse {
        return base.send_failed(req, "请求体为空");
    };

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 解析失败");
    };
    defer parsed.deinit();

    if (parsed.value != .array) {
        return base.send_failed(req, "请求体必须是 JSON 数组");
    }

    var success_count: u64 = 0;
    var fail_count: u64 = 0;

    for (parsed.value.array.items) |item| {
        if (item != .object) {
            fail_count += 1;
            continue;
        }

        var model = dynamic.DynamicModel.init(self.allocator);
        defer model.deinit();

        var obj_iter = item.object.iterator();
        while (obj_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "id")) continue;

            switch (value) {
                .string => |s| model.setString(key, s) catch {},
                .integer => |i| model.setInt(key, i) catch {},
                .float => |f| model.set(key, .{ .float_value = f }) catch {},
                .bool => |b| model.set(key, .{ .bool_value = b }) catch {},
                .null => model.setNull(key) catch {},
                else => {},
            }
        }

        _ = self.crud.insert(table_name, &model) catch {
            fail_count += 1;
            continue;
        };
        success_count += 1;
    }

    base.send_ok(req, .{ .success = success_count, .failed = fail_count });
}

/// 条件查询
/// POST /dynamic/:table/query
pub fn query(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    req.parseBody() catch {
        return base.send_failed(req, "解析请求体失败");
    };

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const body = req.body orelse {
        return base.send_failed(req, "请求体为空");
    };

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 解析失败");
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        return base.send_failed(req, "请求体必须是 JSON 对象");
    }

    // 构建 WHERE 条件
    var where_parts = std.ArrayListUnmanaged([]u8){};
    defer {
        for (where_parts.items) |part| self.allocator.free(part);
        where_parts.deinit(self.allocator);
    }

    var obj_iter = parsed.value.object.iterator();
    while (obj_iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        // 跳过分页和排序参数
        if (std.mem.eql(u8, key, "page") or
            std.mem.eql(u8, key, "limit") or
            std.mem.eql(u8, key, "order_by") or
            std.mem.eql(u8, key, "order"))
        {
            continue;
        }

        const condition = switch (value) {
            .string => |s| blk: {
                const escaped = orm.escapeSqlString(self.allocator, s) catch continue;
                defer self.allocator.free(escaped);
                break :blk std.fmt.allocPrint(self.allocator, "{s} = '{s}'", .{ key, escaped }) catch continue;
            },
            .integer => |i| std.fmt.allocPrint(self.allocator, "{s} = {d}", .{ key, i }) catch continue,
            .null => std.fmt.allocPrint(self.allocator, "{s} IS NULL", .{key}) catch continue,
            else => continue,
        };

        where_parts.append(self.allocator, condition) catch {};
    }

    // 组合 WHERE 子句
    var where_clause: ?[]u8 = null;
    defer if (where_clause) |wc| self.allocator.free(wc);

    if (where_parts.items.len > 0) {
        where_clause = std.mem.join(self.allocator, " AND ", where_parts.items) catch null;
    }

    // 解析分页参数
    const page: i64 = if (parsed.value.object.get("page")) |p| switch (p) {
        .integer => |i| i,
        else => 1,
    } else 1;

    const limit: i64 = if (parsed.value.object.get("limit")) |l| switch (l) {
        .integer => |i| i,
        else => 10,
    } else 10;

    const offset: u32 = @intCast((page - 1) * limit);

    // 解析排序
    var order_clause: ?[]u8 = null;
    defer if (order_clause) |oc| self.allocator.free(oc);

    if (parsed.value.object.get("order_by")) |ob| {
        if (ob == .string) {
            const order_dir = if (parsed.value.object.get("order")) |o| switch (o) {
                .string => |s| s,
                else => "asc",
            } else "asc";
            order_clause = std.fmt.allocPrint(self.allocator, "{s} {s}", .{ ob.string, order_dir }) catch null;
        }
    }

    // 执行查询
    var result = self.crud.select(table_name, .{
        .where = where_clause,
        .order_by = order_clause,
        .limit = @intCast(limit),
        .offset = offset,
    }) catch |err| {
        return base.send_error(req, err);
    };
    defer result.deinit();

    // 转换结果
    var items = std.ArrayListUnmanaged(std.json.Value){};
    defer {
        for (items.items) |*val| {
            if (val.* == .object) {
                val.object.deinit();
            }
        }
        items.deinit(self.allocator);
    }

    for (result.rows) |*row| {
        var obj = std.json.ObjectMap.init(self.allocator);

        var iter = row.fields.iterator();
        while (iter.next()) |entry| {
            const json_value = fieldValueToJson(entry.value_ptr.*);
            obj.put(entry.key_ptr.*, json_value) catch {};
        }

        items.append(self.allocator, .{ .object = obj }) catch {};
    }

    base.send_layui_table_response(req, items.items, result.count(), .{});
}

/// 统计记录数
/// GET /dynamic/:table/count
pub fn count(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    // 构建 COUNT 查询
    const sql_query = std.fmt.allocPrint(self.allocator, "SELECT COUNT(*) as cnt FROM {s}", .{table_name}) catch {
        return base.send_failed(req, "内部错误");
    };
    defer self.allocator.free(sql_query);

    var result = self.crud.db.rawQuery(sql_query) catch |err| {
        return base.send_error(req, err);
    };
    defer result.deinit();

    var total: u64 = 0;
    if (result.next()) |row| {
        if (row.values.len > 0) {
            if (row.values[0]) |cnt_str| {
                total = std.fmt.parseInt(u64, cnt_str, 10) catch 0;
            }
        }
    }

    base.send_ok(req, .{ .count = total });
}

/// 检查记录是否存在
/// GET /dynamic/:table/exists?field=value
pub fn exists(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const field = req.getParamSlice("field") orelse {
        return base.send_failed(req, "缺少 field 参数");
    };

    const value = req.getParamSlice("value") orelse {
        return base.send_failed(req, "缺少 value 参数");
    };

    // 转义值
    const escaped = orm.escapeSqlString(self.allocator, value) catch {
        return base.send_failed(req, "内部错误");
    };
    defer self.allocator.free(escaped);

    const where_clause = std.fmt.allocPrint(self.allocator, "{s} = '{s}'", .{ field, escaped }) catch {
        return base.send_failed(req, "内部错误");
    };
    defer self.allocator.free(where_clause);

    var result = self.crud.select(table_name, .{
        .where = where_clause,
        .limit = 1,
    }) catch |err| {
        return base.send_error(req, err);
    };
    defer result.deinit();

    base.send_ok(req, .{ .exists = !result.isEmpty() });
}

/// 获取允许的表列表
/// GET /dynamic/tables
pub fn tables(_: *Self, req: zap.Request) !void {
    base.send_ok(req, .{ .tables = &ALLOWED_TABLES });
}

/// 批量更新
/// POST /dynamic/:table/batch_update
pub fn batchUpdate(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    req.parseBody() catch {
        return base.send_failed(req, "解析请求体失败");
    };

    const table_name = req.getParamSlice("table") orelse {
        return base.send_failed(req, "缺少表名参数");
    };

    if (!self.crud.isTableAllowed(table_name)) {
        return base.send_failed(req, "不允许访问该表");
    }

    const body = req.body orelse {
        return base.send_failed(req, "请求体为空");
    };

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 解析失败");
    };
    defer parsed.deinit();

    if (parsed.value != .array) {
        return base.send_failed(req, "请求体必须是 JSON 数组");
    }

    var success_count: u64 = 0;
    var fail_count: u64 = 0;

    for (parsed.value.array.items) |item| {
        if (item != .object) {
            fail_count += 1;
            continue;
        }

        // 获取 ID
        const id_value = item.object.get("id") orelse {
            fail_count += 1;
            continue;
        };

        const id: i64 = switch (id_value) {
            .integer => |i| i,
            else => {
                fail_count += 1;
                continue;
            },
        };

        var model = dynamic.DynamicModel.init(self.allocator);
        defer model.deinit();

        var obj_iter = item.object.iterator();
        while (obj_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            if (std.mem.eql(u8, key, "id")) continue;

            switch (value) {
                .string => |s| model.setString(key, s) catch {},
                .integer => |i| model.setInt(key, i) catch {},
                .float => |f| model.set(key, .{ .float_value = f }) catch {},
                .bool => |b| model.set(key, .{ .bool_value = b }) catch {},
                .null => model.setNull(key) catch {},
                else => {},
            }
        }

        _ = self.crud.update(table_name, id, &model) catch {
            fail_count += 1;
            continue;
        };
        success_count += 1;
    }

    base.send_ok(req, .{ .success = success_count, .failed = fail_count });
}

/// 将 FieldValue 转换为 JSON Value
fn fieldValueToJson(value: dynamic.FieldValue) std.json.Value {
    return switch (value) {
        .null_value => .null,
        .int_value => |v| .{ .integer = v },
        .uint_value => |v| .{ .integer = @intCast(v) },
        .float_value => |v| .{ .float = v },
        .string_value => |v| .{ .string = v },
        .bool_value => |v| .{ .bool = v },
        .blob_value => .null, // blob 不直接转 JSON
    };
}
