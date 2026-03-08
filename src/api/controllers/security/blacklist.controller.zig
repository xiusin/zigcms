const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("../base.fn.zig");
const sql = @import("../../../application/services/sql/orm.zig");
const models = @import("../../../domain/entities/mod.zig");
const global = @import("../../../core/primitives/global.zig");

const Self = @This();
const store_allocator = std.heap.page_allocator;

allocator: Allocator,

const OrmMember = sql.defineWithConfig(models.BizMember, .{ .table_name = "biz_member", .primary_key = "id" });

const BlacklistRecord = struct {
    id: i32,
    user_id: i32,
    username: []const u8,
    avatar: []const u8,
    mobile: []const u8,
    block_type: i32,
    reason: []const u8,
    ip: []const u8,
    device_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    evidence: []const u8,
    remark: []const u8,
    status: i32,
    operator: []const u8,
    created_at: []const u8,
    updated_at: []const u8,
};

var records = std.ArrayListUnmanaged(BlacklistRecord){};
var next_id: i32 = 1;
var mu: std.Thread.Mutex = .{};

pub fn init(allocator: Allocator) Self {
    if (!OrmMember.hasDb()) OrmMember.use(global.get_db());
    return .{ .allocator = allocator };
}

pub const list = listImpl;
pub const save = saveImpl;
pub const set = setImpl;
pub const delete = deleteImpl;
pub const add = addImpl;
pub const import_data = importImpl;
pub const export_data = exportImpl;

fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    req.parseBody() catch {};

    var page: i32 = 1;
    var page_size: i32 = 10;
    var username: []const u8 = "";
    var block_type: ?i32 = null;
    var status: ?i32 = null;

    if (req.getParamSlice("page")) |v| page = std.fmt.parseInt(i32, v, 10) catch 1;
    if (req.getParamSlice("pageSize")) |v| page_size = std.fmt.parseInt(i32, v, 10) catch 10;
    if (req.getParamSlice("page_size")) |v| page_size = std.fmt.parseInt(i32, v, 10) catch page_size;
    if (req.getParamSlice("limit")) |v| page_size = std.fmt.parseInt(i32, v, 10) catch page_size;
    if (req.getParamSlice("username")) |v| username = v;
    if (req.getParamSlice("block_type")) |v| block_type = std.fmt.parseInt(i32, v, 10) catch null;
    if (req.getParamSlice("status")) |v| status = std.fmt.parseInt(i32, v, 10) catch null;

    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        defer if (parsed) |*p| p.deinit();
        if (parsed) |p| {
            if (p.value == .object) {
                const obj = p.value.object;
                if (obj.get("page")) |v| {
                    if (v == .integer) page = @intCast(v.integer);
                }
                if (obj.get("pageSize")) |v| {
                    if (v == .integer) page_size = @intCast(v.integer);
                }
                if (obj.get("page_size")) |v| {
                    if (v == .integer) page_size = @intCast(v.integer);
                }
                if (obj.get("limit")) |v| {
                    if (v == .integer) page_size = @intCast(v.integer);
                }
                if (obj.get("username")) |v| {
                    if (v == .string) username = v.string;
                }
                if (obj.get("block_type")) |v| switch (v) {
                    .integer => block_type = @intCast(v.integer),
                    .string => block_type = std.fmt.parseInt(i32, v.string, 10) catch null,
                    else => {},
                };
                if (obj.get("status")) |v| switch (v) {
                    .integer => status = @intCast(v.integer),
                    .string => status = std.fmt.parseInt(i32, v.string, 10) catch null,
                    else => {},
                };
            }
        }
    }

    mu.lock();
    defer mu.unlock();

    var filtered = std.ArrayListUnmanaged(BlacklistRecord){};
    defer filtered.deinit(self.allocator);

    for (records.items) |record| {
        if (username.len > 0 and std.mem.indexOf(u8, record.username, username) == null) continue;
        if (block_type) |v| if (record.block_type != v) continue;
        if (status) |v| if (record.status != v) continue;
        filtered.append(self.allocator, record) catch return base.send_failed(req, "内存不足");
    }

    const total = filtered.items.len;
    const page_index: usize = @intCast(if (page > 0) page - 1 else 0);
    const size: usize = @intCast(if (page_size > 0) page_size else 10);
    const start = @min(page_index * size, total);
    const end = @min(start + size, total);

    base.send_ok(req, .{
        .list = filtered.items[start..end],
        .total = total,
        .page = page,
        .pageSize = page_size,
        .page_size = page_size,
    });
}

fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 格式错误");
    };
    defer parsed.deinit();
    if (parsed.value != .object) return base.send_failed(req, "参数格式错误");

    const obj = parsed.value.object;
    const id = parseI32(obj.get("id"), 0);
    const user_id = parseI32(obj.get("user_id"), 0);
    const block_type = parseI32(obj.get("block_type"), 1);
    const reason = parseString(obj.get("reason"));
    const start_time = parseString(obj.get("start_time"));
    const end_time = parseString(obj.get("end_time"));
    const evidence = parseString(obj.get("evidence"));
    const remark = parseString(obj.get("remark"));

    if (user_id <= 0) return base.send_failed(req, "user_id 无效");
    if (reason.len == 0) return base.send_failed(req, "封禁原因不能为空");

    var member = (OrmMember.Find(user_id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "会员不存在");
    };
    defer OrmMember.freeModel(&member);

    mu.lock();
    defer mu.unlock();

    const now = try nowString();
    defer store_allocator.free(now);

    if (id > 0) {
        for (records.items) |*record| {
            if (record.id != id) continue;
            freeRecord(record.*);
            record.* = try buildRecord(id, user_id, member.username, member.avatar, member.mobile, block_type, reason, start_time, end_time, evidence, remark, 1, "admin", now);
            return base.send_ok(req, .{ .id = id, .message = "更新成功" });
        }
    }

    const new_id = next_id;
    next_id += 1;
    try records.append(store_allocator, try buildRecord(new_id, user_id, member.username, member.avatar, member.mobile, block_type, reason, start_time, end_time, evidence, remark, 1, "admin", now));
    base.send_ok(req, .{ .id = new_id, .message = "添加成功" });
}

fn setImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 格式错误");
    };
    defer parsed.deinit();
    if (parsed.value != .object) return base.send_failed(req, "参数格式错误");

    const obj = parsed.value.object;
    const id = parseI32(obj.get("id"), 0);
    const field = parseString(obj.get("field"));
    const value = parseI32(obj.get("value"), 0);

    if (id <= 0) return base.send_failed(req, "id 无效");
    if (!std.mem.eql(u8, field, "status")) return base.send_failed(req, "仅支持 status 字段");

    mu.lock();
    defer mu.unlock();

    for (records.items) |*record| {
        if (record.id != id) continue;
        record.status = value;
        const updated = try nowString();
        store_allocator.free(record.updated_at);
        record.updated_at = updated;
        return base.send_ok(req, .{ .id = id, .message = "更新成功" });
    }

    base.send_failed(req, "记录不存在");
}

fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch {};
    req.parseQuery();

    var id: i32 = 0;
    if (req.getParamSlice("id")) |id_str| id = std.fmt.parseInt(i32, id_str, 10) catch 0;
    if (id == 0) {
        if (req.body) |body| {
            var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
            defer if (parsed) |*p| p.deinit();
            if (parsed) |p| {
                if (p.value == .object) id = parseI32(p.value.object.get("id"), 0);
            }
        }
    }

    if (id <= 0) return base.send_failed(req, "id 无效");

    mu.lock();
    defer mu.unlock();

    for (records.items, 0..) |record, idx| {
        if (record.id != id) continue;
        freeRecord(record);
        _ = records.swapRemove(idx);
        return base.send_ok(req, .{ .id = id, .message = "删除成功" });
    }

    base.send_failed(req, "记录不存在");
}

fn addImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "JSON 格式错误");
    };
    defer parsed.deinit();
    if (parsed.value != .object) return base.send_failed(req, "参数格式错误");

    const obj = parsed.value.object;
    const member_id = parseI32(obj.get("member_id"), 0);
    const reason = parseString(obj.get("reason"));
    if (member_id <= 0) return base.send_failed(req, "member_id 无效");

    var member = (OrmMember.Find(member_id) catch |err| return base.send_error(req, err)) orelse {
        return base.send_failed(req, "会员不存在");
    };
    defer OrmMember.freeModel(&member);

    mu.lock();
    defer mu.unlock();

    for (records.items) |record| {
        if (record.user_id == member_id and record.status == 1) {
            return base.send_ok(req, .{ .id = record.id, .message = "已在黑名单中" });
        }
    }

    const now = try nowString();
    defer store_allocator.free(now);
    const new_id = next_id;
    next_id += 1;
    try records.append(store_allocator, try buildRecord(new_id, member_id, member.username, member.avatar, member.mobile, 1, reason, now, "", "", "会员管理手动拉黑", 1, "admin", now));
    base.send_ok(req, .{ .id = new_id, .message = "添加成功" });
}

fn importImpl(_: *Self, req: zap.Request) !void {
    base.send_ok(req, .{ .count = 0, .message = "导入成功" });
}

fn exportImpl(_: *Self, req: zap.Request) !void {
    base.send_ok(req, .{ .url = "/downloads/blacklist_export.xlsx" });
}

fn buildRecord(id: i32, user_id: i32, username: []const u8, avatar: []const u8, mobile: []const u8, block_type: i32, reason: []const u8, start_time: []const u8, end_time: []const u8, evidence: []const u8, remark: []const u8, status: i32, operator: []const u8, now: []const u8) !BlacklistRecord {
    return .{
        .id = id,
        .user_id = user_id,
        .username = try store_allocator.dupe(u8, username),
        .avatar = try store_allocator.dupe(u8, avatar),
        .mobile = try store_allocator.dupe(u8, mobile),
        .block_type = block_type,
        .reason = try store_allocator.dupe(u8, reason),
        .ip = try store_allocator.dupe(u8, ""),
        .device_id = try store_allocator.dupe(u8, ""),
        .start_time = try store_allocator.dupe(u8, start_time),
        .end_time = try store_allocator.dupe(u8, end_time),
        .evidence = try store_allocator.dupe(u8, evidence),
        .remark = try store_allocator.dupe(u8, remark),
        .status = status,
        .operator = try store_allocator.dupe(u8, operator),
        .created_at = try store_allocator.dupe(u8, now),
        .updated_at = try store_allocator.dupe(u8, now),
    };
}

fn freeRecord(record: BlacklistRecord) void {
    store_allocator.free(record.username);
    store_allocator.free(record.avatar);
    store_allocator.free(record.mobile);
    store_allocator.free(record.reason);
    store_allocator.free(record.ip);
    store_allocator.free(record.device_id);
    store_allocator.free(record.start_time);
    store_allocator.free(record.end_time);
    store_allocator.free(record.evidence);
    store_allocator.free(record.remark);
    store_allocator.free(record.operator);
    store_allocator.free(record.created_at);
    store_allocator.free(record.updated_at);
}

fn parseString(value: ?std.json.Value) []const u8 {
    if (value) |v| switch (v) {
        .string => |s| return s,
        else => {},
    };
    return "";
}

fn parseI32(value: ?std.json.Value, default_value: i32) i32 {
    if (value) |v| switch (v) {
        .integer => |i| return @intCast(i),
        .bool => |b| return if (b) 1 else 0,
        .string => |s| return std.fmt.parseInt(i32, s, 10) catch default_value,
        else => {},
    };
    return default_value;
}

fn nowString() ![]u8 {
    return std.fmt.allocPrint(store_allocator, "{d}", .{std.time.timestamp()});
}
