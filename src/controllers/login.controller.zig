const std = @import("std");
const zap = @import("zap");
const global = @import("../global/global.zig");
const base = @import("base.fn.zig");
const pretty = @import("pretty");
const dto = @import("../dto/login.dto.zig");

const Allocator = std.mem.Allocator;

pub const Login = struct {
    const Self = @This();
    allocator: Allocator,
    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn register(self: *Self, req: zap.Request) void {
        req.parseBody() catch |e| return base.send_error(req, e);

        const params = req.parametersToOwnedList(self.allocator, false) catch unreachable;
        defer params.deinit();
        var registerDto: dto.Register = undefined;
        if (req.body) |body| {
            registerDto = std.json.parseFromSliceLeaky(dto.Register, self.allocator, body, .{}) catch |e| return base.send_error(req, e);
        }

        if (registerDto.password.len == 0 or registerDto.username.len == 0) {
            return base.send_error(req, error.ParamMiss);
        }

        const num = global.sql_get_count("SELECT COUNT(*) FROM zigcms.admin WHERE username = $1", .{registerDto.username});
        if (num > 0) {
            req.sendBody("已存在") catch return;
            return;
        }

        const result = global.sql_exec(
            "INSERT INTO zigcms.admin (username, password, created_at) VALUES ($1, $2, $3);",
            .{ registerDto.username, registerDto.password, std.time.timestamp() },
        ) catch |e| return base.send_error(req, e);

        std.log.debug("result = {d}", .{result});
        if (result > 0) {
            req.sendBody("新增成功") catch return;
            return;
        }

        req.sendJson("ok") catch return;
    }

    pub fn login(_: *Self, req: zap.Request) void {
        const pool = global.get_pg_pool() catch |e| return base.send_error(req, e);
        var conn = pool.acquire() catch |e| return base.send_error(req, e);
        defer conn.release();
        var result = conn.query("select 1", .{}) catch |e| return base.send_error(req, e);
        defer result.deinit();

        while (result.next() catch |e| return base.send_error(req, e)) |row| {
            const num = row.get(i32, 0);
            std.log.info("User {d}", .{num});
        }
        req.sendJson("hello world!") catch return;
    }
};
