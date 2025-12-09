const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const services = @import("../../application/services/services.zig");
const Allocator = std.mem.Allocator;
const strings = @import("../modules/strings.zig");

const Self = @This();

// ORM 模型别名
const Task = orm_models.Task;

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn get(self: *Self, req: zap.Request) void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return;
    if (id_str.len == 0) return;

    const id = strings.to_int(id_str) catch return base.send_failed(req, "缺少必要参数");

    // 使用 ORM 查询
    const item_opt = Task.Find(@as(i32, @intCast(id))) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "记录不存在");
    }

    var item = item_opt.?;
    defer Task.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}
