const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/menu.model.zig");
const dtos = @import("../dto/dtos.zig");

pub const Menu = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn list(self: *Self, req: zap.Request) void {
        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
        var result = pool.queryOpts("SELECT * FROM zigcms.menu", .{}, .{
            .column_names = true,
        }) catch |e| return base.send_error(req, e);

        defer result.deinit();
        const mapper = result.mapper(models.Menu, .{ .allocator = self.allocator });
        var menus = std.ArrayList(models.Menu).init(self.allocator);
        defer menus.deinit();
        while (mapper.next() catch |e| return base.send_error(req, e)) |menu| {
            std.log.debug("menu = {any}", .{menu});
            menus.append(menu) catch {};
        }
        base.send_ok(self.allocator, req, .{});
    }

    pub fn save(self: *Self, req: zap.Request) void {
        req.parseBody() catch |e| return base.send_error(req, e);
        var dto: dtos.Menu.Save = undefined;
        if (req.body) |body| {
            dto = std.json.parseFromSliceLeaky(dtos.Menu.Save, self.allocator, body, .{
                .ignore_unknown_fields = true,
            }) catch |e| return base.send_error(req, e);
            defer self.allocator.free(dto);
        }

        var pool = global.get_pg_pool() catch |e| return base.send_error(req, e);

        base.send_ok(self.allocator, req, .{});
    }
};
