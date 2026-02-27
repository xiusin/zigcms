const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmDict = sql.defineWithConfig(models.SysDict, .{
    .table_name = "zigcms.sys_dict",
    .primary_key = "id",
});

const OrmDictItem = sql.defineWithConfig(models.SysDictItem, .{
    .table_name = "zigcms.sys_dict_item",
    .primary_key = "id",
});

/// 初始化字典项扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmDict.hasDb()) {
        OrmDict.use(global.get_db());
    }
    if (!OrmDictItem.hasDb()) {
        OrmDictItem.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 字典项列表接口。
pub const items = itemsImpl;

/// 字典项保存接口。
pub const save = saveImpl;

/// 字典项删除接口。
pub const delete = deleteImpl;

/// 字典项单字段更新接口。
pub const set = setImpl;

/// 获取字典项列表。
fn itemsImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var dict_id: ?i32 = null;
    if (req.getParamSlice("dict_id")) |id_str| {
        dict_id = std.fmt.parseInt(i32, id_str, 10) catch null;
    }

    if (dict_id == null) {
        if (req.getParamSlice("dict_code")) |code| {
            var q = OrmDict.WhereEq("dict_code", code);
            defer q.deinit();
            const dict = q.first() catch null;
            if (dict) |d| {
                dict_id = d.id orelse 0;
            }
        }
    }

    const target_dict_id = dict_id orelse return base.send_ok(req, .{ .list = &.{} });

    var q = OrmDictItem.WhereEq("dict_id", target_dict_id);
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmDictItem.freeModels(self.allocator, rows);

    var list = std.ArrayListUnmanaged(models.SysDictItem){};
    defer list.deinit(self.allocator);
    for (rows) |row| {
        list.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = list.items });
}

/// 保存字典项。
fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = @import("../../application/services/json/json.zig").JSON.decode(models.SysDictItem, self.allocator, body) catch {
        return base.send_failed(req, "解析数据失败");
    };

    if (dto.dict_id <= 0) {
        return base.send_failed(req, "dict_id 无效");
    }

    if (dto.id) |id| {
        if (id > 0) {
            _ = OrmDictItem.Update(id, dto) catch |err| return base.send_error(req, err);
            return base.send_ok(req, dto);
        }
    }

    var created = OrmDictItem.Create(dto) catch |err| return base.send_error(req, err);
    defer OrmDictItem.freeModel(self.allocator, &created);

    base.send_ok(req, created);
}

/// 删除字典项。
fn deleteImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id = std.fmt.parseInt(i32, id_str, 10) catch return base.send_failed(req, "id 格式错误");

    _ = OrmDictItem.Destroy(id) catch |err| return base.send_error(req, err);
    base.send_ok(req, "删除成功");
}

/// 更新字典项单字段。
fn setImpl(self: *Self, req: zap.Request) !void {
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

    const id: i32 = @intCast(id_val.integer);
    const field = field_val.string;

    var model = (OrmDictItem.Find(id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "记录不存在");
    };
    defer OrmDictItem.freeModel(self.allocator, &model);

    if (std.mem.eql(u8, field, "status")) {
        if (value_val != .integer) return base.send_failed(req, "status 类型错误");
        model.status = @intCast(value_val.integer);
    } else if (std.mem.eql(u8, field, "sort")) {
        if (value_val != .integer) return base.send_failed(req, "sort 类型错误");
        model.sort = @intCast(value_val.integer);
    } else if (std.mem.eql(u8, field, "item_name")) {
        if (value_val != .string) return base.send_failed(req, "item_name 类型错误");
        model.item_name = value_val.string;
    } else if (std.mem.eql(u8, field, "item_value")) {
        if (value_val != .string) return base.send_failed(req, "item_value 类型错误");
        model.item_value = value_val.string;
    } else {
        return base.send_failed(req, "不支持的字段");
    }

    _ = OrmDictItem.Update(id, model) catch |err| return base.send_error(req, err);
    base.send_ok(req, "更新成功");
}
