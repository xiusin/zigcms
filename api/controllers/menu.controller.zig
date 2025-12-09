const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const dtos = @import("../dto/mod.zig");
const services = @import("../../application/services/services.zig");
const Allocator = std.mem.Allocator;

const Self = @This();

// ORM 模型别名
const Menu = orm_models.Menu;

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

/// 获取菜单列表
pub fn list(self: *Self, req: zap.Request) !void {
    // 使用 ORM 获取所有菜单
    const menus_slice = Menu.All() catch |e| return base.send_error(req, e);
    defer Menu.freeModels(self.allocator, menus_slice);

    var menus = std.ArrayListUnmanaged(Menu.Model){};
    defer menus.deinit(self.allocator);

    for (menus_slice) |menu| {
        std.log.debug("menu = {any}", .{menu});
        menus.append(self.allocator, menu) catch {};
    }

    base.send_ok(req, menus.items);
}

/// 保存菜单
pub fn save(self: *Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);

    const body = req.body orelse return base.send_failed(req, "请求体为空");
    const dto = services.json.JSON.decode(dtos.Menu.Save, self.allocator, body) catch |e| return base.send_error(req, e);

    // 设置时间戳
    const now = std.time.microTimestamp();

    // 使用 ORM 创建菜单
    var new_menu = Menu.Create(.{
        .name = dto.name,
        .parent_id = dto.parent_id orelse 0,
        .url = dto.url orelse "",
        .icon = dto.icon orelse "",
        .sort = dto.sort orelse 0,
        .status = dto.status orelse 1,
        .create_time = now,
        .update_time = now,
    }) catch |e| return base.send_error(req, e);
    defer Menu.freeModel(self.allocator, &new_menu);

    base.send_ok(req, new_menu);
}
