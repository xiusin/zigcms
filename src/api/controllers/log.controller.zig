const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");

const Self = @This();
allocator: Allocator,

const LogItem = struct {
    id: i32,
    user_text: []const u8,
    company_name: []const u8,
    company_type: []const u8,
    opt_menu: []const u8,
    opt_target: []const u8,
    opt_action: []const u8,
    opt_info: []const u8,
    ip: []const u8,
    opt_time: []const u8,
    browser: []const u8,
    os: []const u8,
    device_type: []const u8,
    request_params: []const u8,
    response_data: []const u8,
};

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub const list = listImpl;
pub const statistics = statisticsImpl;
pub const clean = cleanImpl;
pub const archive = archiveImpl;
pub const export_logs = exportImpl;

fn listImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    var rows = [_]LogItem{
        .{ .id = 1, .user_text = "admin", .company_name = "ZigCMS", .company_type = "平台", .opt_menu = "系统管理", .opt_target = "管理员", .opt_action = "编辑", .opt_info = "修改管理员资料", .ip = "127.0.0.1", .opt_time = "2026-02-27 13:00:00", .browser = "Chrome", .os = "macOS", .device_type = "Desktop", .request_params = "{}", .response_data = "{\"code\":200}" },
        .{ .id = 2, .user_text = "admin", .company_name = "ZigCMS", .company_type = "平台", .opt_menu = "系统管理", .opt_target = "菜单", .opt_action = "新增", .opt_info = "新增菜单项", .ip = "127.0.0.1", .opt_time = "2026-02-27 13:05:00", .browser = "Chrome", .os = "macOS", .device_type = "Desktop", .request_params = "{}", .response_data = "{\"code\":200}" },
    };

    base.send_layui_table_response(req, &rows, rows.len, .{});
}

fn statisticsImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    const trend = [_]struct { date: []const u8, count: i32 }{
        .{ .date = "02-21", .count = 10 },
        .{ .date = "02-22", .count = 12 },
        .{ .date = "02-23", .count = 9 },
        .{ .date = "02-24", .count = 15 },
        .{ .date = "02-25", .count = 8 },
        .{ .date = "02-26", .count = 18 },
        .{ .date = "02-27", .count = 20 },
    };
    base.send_ok(req, .{
        .total = 84,
        .today = 20,
        .activeUsers = 3,
        .errors = 0,
        .actionDistribution = .{
            .login = 10,
            .create = 20,
            .update = 30,
            .delete = 5,
            .query = 19,
        },
        .trendData = trend,
    });
}

fn cleanImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    base.send_ok(req, .{ .count = 0 });
}

fn archiveImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    base.send_ok(req, .{ .url = "/downloads/log-archive.xlsx" });
}

fn exportImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    base.send_ok(req, .{ .url = "/downloads/log-export.xlsx" });
}
