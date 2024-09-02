const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/models.zig");
const strings = @import("../modules/strings.zig");

const Self = @This();

const table = "zigcms.setting";

allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn get(_: Self, req: zap.Request) void {
    req.parseQuery();
    const id_ = req.getParamSlice("id") orelse return;
    if (id_.len == 0) return;
    var pool = global.get_pg_pool();
    const id = strings.to_int(id_) catch return base.send_failed(req, "缺少必要参数");

    const query = strings.sprinf("SELECT * FROM {s} WHERE id = $1", .{base.get_table_name(models.Task)}) catch unreachable;

    var row = (pool.rowOpts(query, .{id}, .{ .column_names = true }) catch |e|
        return base.send_error(req, e)) orelse
        return base.send_failed(req, "记录不存在");

    defer row.deinit() catch {};
    const item = row.to(models.Task, .{ .map = .name }) catch |e|
        return base.send_error(req, e);

    return base.send_ok(req, item);
}
