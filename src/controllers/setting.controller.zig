const std = @import("std");
const zap = @import("zap");
const smtp = @import("smtp_client");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const orm_models = @import("../models/orm_models.zig");
const services = @import("../services/services.zig");

const Self = @This();

// ORM 模型别名
const Setting = orm_models.Setting;

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

/// 获取所有设置
pub fn get(self: Self, req: zap.Request) !void {
    // 使用 ORM 获取所有设置
    const settings_slice = Setting.All() catch |e| return base.send_error(req, e);
    defer Setting.freeModels(self.allocator, settings_slice);

    var config = std.StringHashMap([]const u8).init(self.allocator);
    defer config.deinit();

    for (settings_slice) |item| {
        config.put(item.key, item.value) catch {};
    }

    return base.send_ok(req, config);
}

/// 保存设置
pub fn save(self: Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    const body = req.body orelse return base.send_failed(req, "提交参数为空");

    var values = services.json.JSON.parseValue(self.allocator, body) catch |e| return base.send_error(req, e);
    defer values.deinit(self.allocator);

    if (values != .object) return base.send_failed(req, "参数格式错误");

    var iter = values.object.iterator();
    while (iter.next()) |entity| {
        // 先删除已存在的 key
        var del_q = Setting.WhereEq("key", entity.key_ptr.*);
        defer del_q.deinit();
        _ = del_q.delete() catch {};

        // 插入新值
        if (entity.value_ptr.getString()) |val| {
            _ = Setting.Create(.{
                .key = entity.key_ptr.*,
                .value = val,
            }) catch {};
        }
    }

    global.restore_setting() catch {};

    return base.send_ok(req, "保存成功");
}

pub fn send_mail(self: Self, req: zap.Request) !void {
    const config = smtp.Config{
        .port = 25,
        .encryption = .insecure,
        .host = "smtp.qq.com",
        .allocator = self.allocator,
        .username = "826466266@qq.com",
        .password = "aodpqtajdowwbfeg",
    };

    const from = "826466266@qq.com";
    const to = "chenchengbin92@qq.com";
    const subject = "Test";

    const content = "This is karl, I'm testing a SMTP client for Zig";

    const data = std.fmt.allocPrint(self.allocator, "From: Admin <{s}>\r\nTo: User <{s}>\r\nSubject: {s}\r\n\r\n{s}\r\n.\r\n", .{ from, to, subject, content }) catch return;
    defer self.allocator.free(data);
    smtp.send(.{ .from = .{ .address = from }, .to = &.{.{ .address = to }}, .data = data }, config) catch |e| return base.send_error(req, e);
}
