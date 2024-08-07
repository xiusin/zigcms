const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/setting.model.zig");

const Self = @This();

allocator: std.mem.Allocator,
pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn get(self: Self, req: zap.Request) void {
    var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
    var result = pool.queryOpts("SELECT * FROM zigcms.setting", .{}, .{
        .column_names = true,
    }) catch |e| return base.send_error(req, e);

    defer result.deinit();
    const mapper = result.mapper(models.Setting, .{ .allocator = self.allocator });

    var config = std.StringHashMap([]const u8).init(self.allocator);
    defer config.deinit();

    while (mapper.next() catch |e| return base.send_error(req, e)) |item| {
        config.put(item.key, item.value) catch {};
    }
    return base.send_ok(req, config);
}

pub fn save(self: Self, req: zap.Request) void {
    req.parseBody() catch |e| return base.send_error(req, e);
    const body = req.body orelse return base.send_failed(req, "提交参数为空");

    var values = std.json.parseFromSliceLeaky(
        std.json.Value,
        self.allocator,
        body,
        .{},
    ) catch |e| return base.send_error(req, e);
    defer values.object.deinit();

    var iter = values.object.iterator();
    while (iter.next()) |entity| {
        _ = global.sql_exec("DELETE FROM zigcms.setting WHERE key = $1", .{entity.key_ptr.*}) catch {};
        _ = global.sql_exec("INSERT INTO zigcms.setting (key, value) VALUES ($1, $2)", .{ entity.key_ptr.*, entity.value_ptr.string }) catch {};
    }

    return base.send_ok(req, "保存成功");
}
