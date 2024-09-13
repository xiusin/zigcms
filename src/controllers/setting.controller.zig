const std = @import("std");
const zap = @import("zap");
const smtp = @import("smtp_client");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../global/global.zig");
const models = @import("../models/setting.model.zig");

const Self = @This();

const table = "zigcms.setting";

allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn get(self: Self, req: zap.Request) void {
    var pool = global.get_pg_pool();
    var result = pool.queryOpts("SELECT * FROM " ++ table, .{}, .{
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
        const deleteSql = "DELETE FROM " ++ table ++ " WHERE key = $1";
        _ = global.sql_exec(deleteSql, .{entity.key_ptr.*}) catch {};

        const insertSql = "INSERT INTO " ++ table ++ " (key, value) VALUES ($1, $2)";
        _ = global.sql_exec(insertSql, .{
            entity.key_ptr.*,
            entity.value_ptr.string,
        }) catch {};
    }

    global.restore_setting() catch {};

    return base.send_ok(req, "保存成功");
}

pub fn send_mail(self: Self, _: zap.Request) void {
    const config = smtp.Config{
        .port = 25,
        .encryption = .none,
        .host = "localhost",
        .allocator = self.allocator,
        // .username = "username",
        // .password = "password",
    };

    try smtp.send(.{
        .from = "admin@localhost",
        .to = &.{"user@localhost"},
        .data = "From: Admin <admin@localhost>\r\nTo: User <user@localhost>\r\nSubject: Test\r\n\r\nThis is karl, I'm testing a SMTP client for Zig\r\n.\r\n",
    }, config);
}
