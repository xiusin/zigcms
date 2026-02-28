const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../core/utils/strings.zig");

const Self = @This();
allocator: Allocator,

const SysConfig = struct {
    id: ?i32 = null,
    config_name: []const u8 = "",
    config_key: []const u8 = "",
    config_group: []const u8 = "basic",
    config_type: []const u8 = "text",
    config_value: []const u8 = "",
    description: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

const OrmConfig = sql.defineWithConfig(SysConfig, .{
    .table_name = "sys_config",
    .primary_key = "id",
});

const VersionPayload = struct {
    id: ?i32 = null,
    version: []const u8 = "",
    version_type: i32 = 1,
    force_update: i32 = 0,
    min_version: []const u8 = "",
    title: []const u8 = "",
    content: []const u8 = "",
    download_url: []const u8 = "",
    file_size: []const u8 = "",
    md5: []const u8 = "",
    remark: []const u8 = "",
    status: i32 = 1,
    release_time: []const u8 = "",
};

pub fn init(allocator: Allocator) Self {
    if (!OrmConfig.hasDb()) OrmConfig.use(global.get_db());
    return .{ .allocator = allocator };
}

pub const list = listImpl;
pub const save = saveImpl;
pub const delete = deleteImpl;
pub const set = setImpl;

fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    var page: i32 = 1;
    var limit: i32 = 10;
    if (req.getParamSlice("page")) |s| page = @intCast(strings.to_int(s) catch 1);
    if (req.getParamSlice("page_size")) |s| limit = @intCast(strings.to_int(s) catch 10);

    var q = OrmConfig.WhereEq("config_group", "version");
    defer q.deinit();
    _ = q.orderBy("sort", .desc);

    const total = q.count() catch |e| return base.send_error(req, e);
    _ = q.page(@intCast(page), @intCast(limit));

    const rows = q.get() catch |e| return base.send_error(req, e);
    defer OrmConfig.freeModels(rows);

    var items = std.ArrayListUnmanaged(VersionPayload){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        const parsed = json_mod.JSON.decode(VersionPayload, self.allocator, row.config_value) catch VersionPayload{};
        items.append(self.allocator, .{
            .id = row.id,
            .version = parsed.version,
            .version_type = parsed.version_type,
            .force_update = parsed.force_update,
            .min_version = parsed.min_version,
            .title = if (parsed.title.len > 0) parsed.title else row.config_name,
            .content = parsed.content,
            .download_url = parsed.download_url,
            .file_size = parsed.file_size,
            .md5 = parsed.md5,
            .remark = if (parsed.remark.len > 0) parsed.remark else row.description,
            .status = row.status,
            .release_time = parsed.release_time,
        }) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");
    const dto = json_mod.JSON.decode(VersionPayload, self.allocator, body) catch return base.send_failed(req, "参数格式错误");

    var payload = dto;
    if (payload.release_time.len == 0) {
        payload.release_time = "";
    }

    const config_value = json_mod.JSON.encode(self.allocator, payload) catch return base.send_failed(req, "序列化失败");
    defer self.allocator.free(config_value);

    if (dto.id) |id| {
        if (id > 0) {
            _ = OrmConfig.Update(id, .{
                .config_name = dto.title,
                .config_group = "version",
                .config_type = "json",
                .config_value = config_value,
                .description = dto.remark,
                .sort = std.time.timestamp(),
                .status = dto.status,
                .updated_at = std.time.microTimestamp(),
            }) catch |e| return base.send_error(req, e);
            return base.send_ok(req, "保存成功");
        }
    }

    const key = try std.fmt.allocPrint(self.allocator, "version:{d}", .{std.time.microTimestamp()});
    defer self.allocator.free(key);

    _ = OrmConfig.Create(.{
        .config_name = dto.title,
        .config_key = key,
        .config_group = "version",
        .config_type = "json",
        .config_value = config_value,
        .description = dto.remark,
        .sort = std.time.timestamp(),
        .status = dto.status,
    }) catch |e| return base.send_error(req, e);

    base.send_ok(req, "保存成功");
}

fn deleteImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id = strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误");
    _ = OrmConfig.Destroy(id) catch |e| return base.send_error(req, e);
    base.send_ok(req, "删除成功");
}

fn setImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const SetDto = struct { id: i32, field: []const u8, value: i32 };
    const dto = json_mod.JSON.decode(SetDto, global.get_allocator(), body) catch return base.send_failed(req, "参数格式错误");
    if (!std.mem.eql(u8, dto.field, "status")) return base.send_failed(req, "仅支持 status 字段");

    _ = OrmConfig.Update(dto.id, .{ .status = dto.value, .updated_at = std.time.microTimestamp() }) catch |e| return base.send_error(req, e);
    base.send_ok(req, "更新成功");
}
