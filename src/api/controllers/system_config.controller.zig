const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");

const Self = @This();

allocator: Allocator,

const OrmConfig = sql.defineWithConfig(models.SysConfig, .{ .table_name = "sys_config", .primary_key = "id" });

/// 初始化配置扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmConfig.hasDb()) OrmConfig.use(global.get_db());
    return .{ .allocator = allocator };
}

/// 配置刷新缓存接口。
pub const refresh_cache = refreshCacheImpl;

/// 配置导出接口。
pub const config_export = exportImpl;

/// 配置导入接口。
pub const config_import = importImpl;

/// 配置备份接口。
pub const config_backup = backupImpl;

/// 返回配置缓存刷新结果。
fn refreshCacheImpl(self: *Self, req: zap.Request) !void {
    _ = self;

    var q = OrmConfig.Query();
    defer q.deinit();
    const total = q.count() catch |err| return base.send_error(req, err);

    base.send_ok(req, .{
        .refreshed = true,
        .refreshed_count = total,
        .refreshed_at = std.time.timestamp(),
    });
}

/// 导出配置列表。
fn exportImpl(self: *Self, req: zap.Request) !void {
    var q = OrmConfig.Query();
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmConfig.freeModels(rows);

    var items = std.ArrayListUnmanaged(models.SysConfig){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .list = items.items, .total = items.items.len });
}

/// 导入配置列表并按 config_key 覆盖。
fn importImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");
    const items_val = parsed.value.object.get("items") orelse return base.send_failed(req, "缺少 items 参数");
    if (items_val != .array) return base.send_failed(req, "items 参数格式错误");

    var imported: usize = 0;
    for (items_val.array.items) |item_val| {
        if (item_val != .object) continue;

        const obj = item_val.object;
        const dto = models.SysConfig{
            .id = parseOptionalI32(obj.get("id")),
            .config_name = parseString(obj.get("config_name")),
            .config_key = parseString(obj.get("config_key")),
            .config_group = if (parseString(obj.get("config_group")).len > 0) parseString(obj.get("config_group")) else "basic",
            .config_type = if (parseString(obj.get("config_type")).len > 0) parseString(obj.get("config_type")) else "text",
            .config_value = parseString(obj.get("config_value")),
            .description = parseString(obj.get("description")),
            .sort = parseI32Default(obj.get("sort"), 0),
            .status = parseI32Default(obj.get("status"), 1),
            .created_at = parseOptionalI64(obj.get("created_at")),
            .updated_at = parseOptionalI64(obj.get("updated_at")),
        };

        if (dto.config_key.len == 0) continue;

        var exist_q = OrmConfig.WhereEq("config_key", dto.config_key);
        defer exist_q.deinit();
        const existed = exist_q.first() catch null;

        if (existed) |old| {
            const old_id = old.id orelse 0;
            if (old_id > 0) {
                _ = OrmConfig.Update(old_id, dto) catch |err| return base.send_error(req, err);
                imported += 1;
            }
        } else {
            var created = OrmConfig.Create(dto) catch |err| return base.send_error(req, err);
            OrmConfig.freeModel(&created);
            imported += 1;
        }
    }

    base.send_ok(req, .{ .imported = imported });
}

/// 备份当前配置快照。
fn backupImpl(self: *Self, req: zap.Request) !void {
    var q = OrmConfig.Query();
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmConfig.freeModels(rows);

    var items = std.ArrayListUnmanaged(models.SysConfig){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, row) catch {};
    }

    base.send_ok(req, .{ .snapshot_time = std.time.timestamp(), .list = items.items });
}

/// 解析字符串字段。
fn parseString(value: ?std.json.Value) []const u8 {
    if (value) |v| {
        if (v == .string) return v.string;
    }
    return "";
}

/// 解析可选 i32 字段。
fn parseOptionalI32(value: ?std.json.Value) ?i32 {
    if (value) |v| {
        if (v == .integer) return @as(i32, @intCast(v.integer));
    }
    return null;
}

/// 解析带默认值的 i32 字段。
fn parseI32Default(value: ?std.json.Value, default_value: i32) i32 {
    if (value) |v| {
        if (v == .integer) return @as(i32, @intCast(v.integer));
    }
    return default_value;
}

/// 解析可选 i64 字段。
fn parseOptionalI64(value: ?std.json.Value) ?i64 {
    if (value) |v| {
        if (v == .integer) return @as(i64, @intCast(v.integer));
    }
    return null;
}
