const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const datetime = @import("../../application/services/datetime/mod.zig");
const global = @import("../../core/primitives/global.zig");
const audit_mod = @import("../../infrastructure/security/audit_log.zig");

const Self = @This();
allocator: Allocator,

const AuditLog = audit_mod.AuditLog;
const OrmAuditLog = sql.defineWithConfig(AuditLog, .{ .table_name = "audit_logs", .primary_key = "id" });

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

fn parsePage(value: ?[]const u8, default_value: i32) i32 {
    return std.fmt.parseInt(i32, value orelse "", 10) catch default_value;
}

fn matchesKeyword(log: AuditLog, keyword: []const u8) bool {
    if (keyword.len == 0) return true;
    if (std.mem.indexOf(u8, log.username, keyword) != null) return true;
    if (std.mem.indexOf(u8, log.action, keyword) != null) return true;
    if (std.mem.indexOf(u8, log.resource_type, keyword) != null) return true;
    if (std.mem.indexOf(u8, log.resource_name, keyword) != null) return true;
    if (std.mem.indexOf(u8, log.description, keyword) != null) return true;
    if (std.mem.indexOf(u8, log.client_ip, keyword) != null) return true;
    return false;
}

fn buildLogItem(allocator: Allocator, log: AuditLog) !LogItem {
    const ts = log.created_at orelse 0;
    const dt = datetime.fromTimestamp(ts);
    var buf: [32]u8 = undefined;
    const formatted = dt.formatPhp("Y-m-d H:i:s", &buf);
    return .{
        .id = log.id orelse 0,
        .user_text = log.username,
        .company_name = "",
        .company_type = "",
        .opt_menu = log.resource_type,
        .opt_target = log.resource_name,
        .opt_action = log.action,
        .opt_info = log.description,
        .ip = log.client_ip,
        .opt_time = try allocator.dupe(u8, formatted),
        .browser = log.user_agent,
        .os = "",
        .device_type = "",
        .request_params = log.before_data,
        .response_data = log.after_data,
    };
}

pub fn init(allocator: Allocator) Self {
    if (!OrmAuditLog.hasDb()) OrmAuditLog.use(global.get_db());
    return .{ .allocator = allocator };
}

pub const list = listImpl;
pub const statistics = statisticsImpl;
pub const clean = cleanImpl;
pub const archive = archiveImpl;
pub const export_logs = exportImpl;

fn listImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    const page = parsePage(req.getParamSlice("page"), 1);
    const page_size = parsePage(req.getParamSlice("pageSize") orelse req.getParamSlice("page_size") orelse req.getParamSlice("limit"), 20);
    const keyword = req.getParamSlice("keyword") orelse req.getParamSlice("user_text") orelse "";
    const action_filter = req.getParamSlice("opt_action") orelse req.getParamSlice("action");
    const target_filter = req.getParamSlice("opt_target");
    const info_filter = req.getParamSlice("opt_info");
    const user_id_filter = std.fmt.parseInt(i32, req.getParamSlice("user_id") orelse "", 10) catch null;

    var q = OrmAuditLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    var items = std.ArrayListUnmanaged(LogItem){};
    defer items.deinit(allocator);

    const start_index: usize = @intCast(@max(page - 1, 0) * @max(page_size, 1));
    const page_len: usize = @intCast(@max(page_size, 1));
    var matched_total: usize = 0;

    for (rows) |row| {
        if (!matchesKeyword(row, keyword)) continue;
        if (user_id_filter) |user_id| {
            if (row.user_id != user_id) continue;
        }
        if (action_filter) |action| {
            if (!std.mem.eql(u8, row.action, action)) continue;
        }
        if (target_filter) |target| {
            if (std.mem.indexOf(u8, row.resource_name, target) == null) continue;
        }
        if (info_filter) |info| {
            if (std.mem.indexOf(u8, row.description, info) == null) continue;
        }
        if (matched_total >= start_index and items.items.len < page_len) {
            try items.append(allocator, try buildLogItem(allocator, row));
        }
        matched_total += 1;
    }

    base.send_layui_table_response(req, items.items, matched_total, .{});
}

fn statisticsImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var q = OrmAuditLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    var login_count: i32 = 0;
    var create_count: i32 = 0;
    var update_count: i32 = 0;
    var delete_count: i32 = 0;
    var query_count: i32 = 0;
    var error_count: i32 = 0;
    var today_count: i32 = 0;
    var unique_users = std.StringHashMap(void).init(allocator);

    const now = std.time.timestamp();
    const today_start = now - 86400;

    var trend = std.ArrayListUnmanaged(struct { date: []const u8, count: i32 }){};
    defer trend.deinit(allocator);
    try trend.append(allocator, .{ .date = "recent", .count = @intCast(rows.len) });

    for (rows) |row| {
        if (row.username.len > 0) try unique_users.put(row.username, {});
        if ((row.created_at orelse 0) >= today_start) today_count += 1;
        if (std.mem.eql(u8, row.result, "failed")) error_count += 1;

        if (std.mem.indexOf(u8, row.action, "登录") != null or std.mem.eql(u8, row.action, "login")) {
            login_count += 1;
        } else if (std.mem.indexOf(u8, row.action, "创建") != null or std.mem.indexOf(u8, row.action, "新增") != null) {
            create_count += 1;
        } else if (std.mem.indexOf(u8, row.action, "更新") != null or std.mem.indexOf(u8, row.action, "编辑") != null) {
            update_count += 1;
        } else if (std.mem.indexOf(u8, row.action, "删除") != null) {
            delete_count += 1;
        } else {
            query_count += 1;
        }
    }

    base.send_ok(req, .{
        .total = rows.len,
        .today = today_count,
        .activeUsers = unique_users.count(),
        .errors = error_count,
        .actionDistribution = .{
            .login = login_count,
            .create = create_count,
            .update = update_count,
            .delete = delete_count,
            .query = query_count,
        },
        .trendData = trend.items,
    });
}

fn cleanImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch {};
    req.parseQuery();

    var deleted: usize = 0;
    var delete_all = false;
    var clean_type: ?[]const u8 = null;
    var clean_days: ?i32 = null;
    var clean_date: ?[]const u8 = null;
    var ids = std.ArrayListUnmanaged(i32){};
    defer ids.deinit(self.allocator);

    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        defer if (parsed) |*p| p.deinit();
        if (parsed) |p| {
            if (p.value == .object) {
                if (p.value.object.get("all")) |all_val| {
                    if (all_val == .bool) delete_all = all_val.bool;
                }
                if (p.value.object.get("type")) |type_val| {
                    if (type_val == .string) clean_type = type_val.string;
                }
                if (p.value.object.get("days")) |days_val| {
                    if (days_val == .integer) clean_days = @intCast(days_val.integer);
                }
                if (p.value.object.get("date")) |date_val| {
                    if (date_val == .string) clean_date = date_val.string;
                }
                if (p.value.object.get("ids")) |ids_val| {
                    if (ids_val == .array) {
                        for (ids_val.array.items) |id_val| {
                            if (id_val == .integer) try ids.append(self.allocator, @intCast(id_val.integer));
                        }
                    }
                }
            }
        }
    }

    if (delete_all and ids.items.len == 0) {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var q = OrmAuditLog.Query();
        defer q.deinit();
        var result = try q.getWithArena(allocator);
        for (result.items()) |row| {
            if (row.id) |id| {
                _ = OrmAuditLog.Destroy(id) catch |err| return base.send_error(req, err);
                deleted += 1;
            }
        }
    } else if (ids.items.len > 0) {
        for (ids.items) |id| {
            _ = OrmAuditLog.Destroy(id) catch |err| return base.send_error(req, err);
            deleted += 1;
        }
    } else if (clean_type != null) {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var q = OrmAuditLog.Query();
        defer q.deinit();
        var result = try q.getWithArena(allocator);
        const now = std.time.timestamp();
        var cutoff: ?i64 = null;

        if (clean_type) |kind| {
            if (std.mem.eql(u8, kind, "days")) {
                cutoff = now - @as(i64, @intCast((clean_days orelse 0) * 86400));
            } else if (std.mem.eql(u8, kind, "date")) {
                if (clean_date) |date_text| {
                    const dt = datetime.parse(date_text, "Y-m-d") catch null;
                    if (dt) |date_dt| cutoff = date_dt.timestamp() + 86400 - 1;
                }
            }
        }

        if (cutoff) |limit_ts| {
            for (result.items()) |row| {
                if ((row.created_at orelse 0) <= limit_ts) {
                    if (row.id) |id| {
                        _ = OrmAuditLog.Destroy(id) catch |err| return base.send_error(req, err);
                        deleted += 1;
                    }
                }
            }
        }
    }

    base.send_ok(req, .{ .count = deleted });
}

fn archiveImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var q = OrmAuditLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    base.send_ok(req, .{
        .archived = rows.len,
        .snapshot_time = std.time.timestamp(),
        .list = rows,
        .url = "/downloads/log-archive.xlsx",
    });
}

fn exportImpl(self: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var q = OrmAuditLog.Query();
    defer q.deinit();
    _ = q.orderBy("id", .desc);
    var result = try q.getWithArena(allocator);
    const rows = result.items();

    var items = std.ArrayListUnmanaged(LogItem){};
    defer items.deinit(allocator);
    for (rows) |row| {
        try items.append(allocator, try buildLogItem(allocator, row));
    }

    base.send_ok(req, .{
        .list = items.items,
        .total = items.items.len,
        .exported = items.items.len,
        .url = "/downloads/log-export.xlsx",
    });
}
