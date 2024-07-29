const std = @import("std");
const zap = @import("zap");
const pretty = @import("pretty");
const jwt = @import("jwt");

const global = @import("../global/global.zig");
const base = @import("base.fn.zig");
const dtos = @import("../dto/dtos.zig");
const models = @import("../models/models.zig");

pub const Login = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn register(self: *Self, req: zap.Request) void {
        req.parseBody() catch |e| return base.send_error(self.allocator, req, e);

        var dto: dtos.User.Register = undefined;
        if (req.body) |body| {
            dto = std.json.parseFromSliceLeaky(dtos.User.Register, self.allocator, body, .{}) catch |e| return base.send_error(self.allocator, req, e);
        }

        if (dto.password.len == 0 or dto.username.len == 0) {
            return base.send_error(self.allocator, req, error.ParamMiss);
        }

        var pool = global.get_pg_pool() catch |e| return base.send_error(self.allocator, req, e);
        var row = (pool.row(
            "SELECT COUNT(*) AS num FROM zigcms.admin WHERE username = $1",
            .{dto.username},
        ) catch |e| return base.send_error(self.allocator, req, e)) orelse unreachable;

        defer row.deinit() catch {};
        if (row.get(i64, 0) > 0) {
            return base.send_failed(self.allocator, req, "用户已存在");
        }

        const result = global.sql_exec(
            "INSERT INTO zigcms.admin (username, password, created_at) VALUES ($1, $2, $3);",
            .{ dto.username, dto.password, std.time.microTimestamp() },
        ) catch |e| return base.send_error(self.allocator, req, e);
        if (result > 0) {
            return base.send_ok(self.allocator, req, dto);
        }
        return base.send_ok(self.allocator, req, .{});
    }

    pub fn login(self: *Self, req: zap.Request) void {
        req.parseBody() catch |e| return base.send_error(self.allocator, req, e);
        var dto: dtos.User.Login = undefined;
        if (req.body) |body| {
            dto = std.json.parseFromSliceLeaky(dtos.User.Login, self.allocator, body, .{
                .ignore_unknown_fields = true,
            }) catch |e| return base.send_error(self.allocator, req, e);
        }

        if (dto.password.len == 0 or dto.username.len == 0) {
            return base.send_failed(self.allocator, req, "缺少必要参数");
        }

        var pool = global.get_pg_pool() catch |e| return base.send_error(self.allocator, req, e);
        var row = (pool.rowOpts("SELECT * FROM zigcms.admin WHERE username = $1", .{dto.username}, .{
            .column_names = true,
        }) catch |e| return base.send_error(self.allocator, req, e)) orelse unreachable;

        defer row.deinit() catch {};
        var user = row.to(models.Admin, .{ .map = .name }) catch |e| return base.send_error(self.allocator, req, e);

        if (user.id == 0) {
            return base.send_failed(self.allocator, req, "用户不存在");
        }
        if (!std.mem.eql(u8, user.password, dto.password)) {
            return base.send_failed(self.allocator, req, "密码错误, 请重试");
        }
        user.password = ""; // TODO 如何像go一样忽略某个参数
        const payload = .{ .sub = user.id, .name = user.username, .iat = std.time.timestamp() + 3600 * 24 };
        const token = jwt.encode(self.allocator, .HS256, payload, .{
            .key = "secret",
        }) catch |e| return base.send_error(self.allocator, req, e);
        defer self.allocator.free(token);
        user.token = token;
        base.send_ok(self.allocator, req, user);
    }
};
