const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const global = @import("../../core/primitives/global.zig");
const strings = @import("../../core/utils/strings.zig");

const Self = @This();

allocator: Allocator,

const OrmAdmin = sql.defineWithConfig(models.SysAdmin, .{
    .table_name = "sys_admin",
    .primary_key = "id",
});

const SysAdminRole = struct {
    id: ?i32 = null,
    admin_id: i32,
    role_id: i32,
    created_at: ?i64 = null,
};

const OrmAdminRole = sql.defineWithConfig(SysAdminRole, .{
    .table_name = "sys_admin_role",
    .primary_key = "id",
});

const OrmRole = sql.defineWithConfig(models.SysRole, .{
    .table_name = "sys_role",
    .primary_key = "id",
});

/// 初始化管理员扩展控制器。
pub fn init(allocator: Allocator) Self {
    if (!OrmAdmin.hasDb()) {
        OrmAdmin.use(global.get_db());
    }
    if (!OrmAdminRole.hasDb()) {
        OrmAdminRole.use(global.get_db());
    }
    if (!OrmRole.hasDb()) {
        OrmRole.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 构造 IN 查询子句。
fn buildInClause(allocator: Allocator, field: []const u8, values: []const i32) ![]u8 {
    var sql_buf = std.ArrayListUnmanaged(u8){};
    errdefer sql_buf.deinit(allocator);
    try sql_buf.appendSlice(allocator, field);
    try sql_buf.appendSlice(allocator, " IN (");
    for (values, 0..) |value, idx| {
        if (idx > 0) try sql_buf.appendSlice(allocator, ",");
        const seg = try std.fmt.allocPrint(allocator, "{d}", .{value});
        defer allocator.free(seg);
        try sql_buf.appendSlice(allocator, seg);
    }
    try sql_buf.appendSlice(allocator, ")");
    return try sql_buf.toOwnedSlice(allocator);
}

/// 归一化角色ID（升序、去重）。
fn normalizeRoleIds(allocator: Allocator, values: []const i32) ![]i32 {
    var normalized = std.ArrayListUnmanaged(i32){};
    errdefer normalized.deinit(allocator);

    for (values) |value| {
        normalized.append(allocator, value) catch {};
    }
    std.mem.sort(i32, normalized.items, {}, std.sort.asc(i32));

    var compact = std.ArrayListUnmanaged(i32){};
    errdefer compact.deinit(allocator);
    for (normalized.items) |value| {
        if (compact.items.len > 0 and compact.items[compact.items.len - 1] == value) continue;
        compact.append(allocator, value) catch {};
    }

    normalized.deinit(allocator);
    return try compact.toOwnedSlice(allocator);
}

/// 返回管理员分页列表，并附带角色名称与角色ID集合。
fn listWithRolesImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var keyword: []const u8 = "";
    var status: ?i32 = null;
    var dept_id: ?i32 = null;
    var role_id: ?i32 = null;

    var params = req.parametersToOwnedStrList(self.allocator) catch |err| {
        return base.send_error(req, err);
    };
    defer params.deinit();

    for (params.items) |param| {
        if (std.mem.eql(u8, param.key, "page")) {
            page = @as(i32, @intCast(strings.to_int(param.value) catch 1));
        } else if (std.mem.eql(u8, param.key, "limit") or std.mem.eql(u8, param.key, "pageSize")) {
            limit = @as(i32, @intCast(strings.to_int(param.value) catch 10));
        } else if (std.mem.eql(u8, param.key, "keyword")) {
            keyword = param.value;
        } else if (std.mem.eql(u8, param.key, "status") and param.value.len > 0) {
            status = @as(i32, @intCast(strings.to_int(param.value) catch 0));
        } else if (std.mem.eql(u8, param.key, "dept_id") and param.value.len > 0) {
            dept_id = @as(i32, @intCast(strings.to_int(param.value) catch 0));
        } else if (std.mem.eql(u8, param.key, "role_id") and param.value.len > 0) {
            role_id = @as(i32, @intCast(strings.to_int(param.value) catch 0));
        }
    }

    if (page < 1) page = 1;
    if (limit < 1) limit = 10;
    if (limit > 200) limit = 200;

    var q = OrmAdmin.Query();
    defer q.deinit();
    if (status) |v| _ = q.whereEq("status", v);
    if (dept_id) |v| _ = q.whereEq("dept_id", v);
    if (keyword.len > 0) {
        if (keyword.len > 64) return base.send_failed(req, "keyword 长度不能超过 64");
        if (std.mem.indexOfScalar(u8, keyword, '\'') != null) return base.send_failed(req, "keyword 包含非法字符");
        const like = std.fmt.allocPrint(self.allocator, "%{s}%", .{keyword}) catch return base.send_failed(req, "查询参数错误");
        defer self.allocator.free(like);
        const keyword_clause = std.fmt.allocPrint(self.allocator, "(username LIKE '{s}' OR nickname LIKE '{s}' OR mobile LIKE '{s}')", .{ like, like, like }) catch return base.send_failed(req, "查询参数错误");
        defer self.allocator.free(keyword_clause);
        _ = q.whereRaw(keyword_clause);
    }
    _ = q.orderBy("id", .desc);

    var role_filtered_admin_ids = std.ArrayListUnmanaged(i32){};
    defer role_filtered_admin_ids.deinit(self.allocator);
    if (role_id) |rid| {
        var rel_q = OrmAdminRole.WhereEq("role_id", rid);
        defer rel_q.deinit();
        const rels = rel_q.get() catch |err| return base.send_error(req, err);
        defer OrmAdminRole.freeModels(rels);
        for (rels) |rel| {
            role_filtered_admin_ids.append(self.allocator, rel.admin_id) catch {};
        }
        if (role_filtered_admin_ids.items.len == 0) {
            return base.send_layui_table_response(req, &.{}, 0, .{});
        }
        const in_clause = buildInClause(self.allocator, "id", role_filtered_admin_ids.items) catch return base.send_failed(req, "构建查询条件失败");
        defer self.allocator.free(in_clause);
        _ = q.whereRaw(in_clause);
    }

    const total = q.count() catch |err| return base.send_error(req, err);
    _ = q.page(@intCast(page), @intCast(limit));
    const admins = q.get() catch |err| return base.send_error(req, err);
    defer OrmAdmin.freeModels(admins);

    var admin_ids = std.ArrayListUnmanaged(i32){};
    defer admin_ids.deinit(self.allocator);
    for (admins) |admin| {
        if (admin.id) |id| admin_ids.append(self.allocator, id) catch {};
    }

    var all_rels = std.ArrayListUnmanaged(SysAdminRole){};
    defer all_rels.deinit(self.allocator);
    if (admin_ids.items.len > 0) {
        var rel_q = OrmAdminRole.Query();
        defer rel_q.deinit();
        const rel_in_clause = buildInClause(self.allocator, "admin_id", admin_ids.items) catch return base.send_failed(req, "构建查询条件失败");
        defer self.allocator.free(rel_in_clause);
        _ = rel_q.whereRaw(rel_in_clause);
        const rel_rows = rel_q.get() catch |err| return base.send_error(req, err);
        defer OrmAdminRole.freeModels(rel_rows);
        for (rel_rows) |rel| all_rels.append(self.allocator, rel) catch {};
    }

    var role_ids = std.ArrayListUnmanaged(i32){};
    defer role_ids.deinit(self.allocator);
    for (all_rels.items) |rel| {
        role_ids.append(self.allocator, rel.role_id) catch {};
    }

    var roles = std.ArrayListUnmanaged(models.SysRole){};
    defer roles.deinit(self.allocator);
    if (role_ids.items.len > 0) {
        var role_q = OrmRole.Query();
        defer role_q.deinit();
        const role_in_clause = buildInClause(self.allocator, "id", role_ids.items) catch return base.send_failed(req, "构建查询条件失败");
        defer self.allocator.free(role_in_clause);
        _ = role_q.whereRaw(role_in_clause);
        const role_rows = role_q.get() catch |err| return base.send_error(req, err);
        defer OrmRole.freeModels(role_rows);
        for (role_rows) |role| roles.append(self.allocator, role) catch {};
    }

    const AdminRow = struct {
        id: ?i32,
        username: []const u8,
        nickname: []const u8,
        mobile: []const u8,
        email: []const u8,
        avatar: []const u8,
        gender: i32,
        status: i32,
        dept_id: ?i32,
        last_login: ?i64,
        role_ids: []const i32,
        role_names: []const []const u8,
        role_name: []const u8,
        role_text: []const u8,
    };

    var rows = std.ArrayListUnmanaged(AdminRow){};
    defer rows.deinit(self.allocator);
    var role_ids_owners = std.ArrayListUnmanaged([]i32){};
    var role_names_owners = std.ArrayListUnmanaged([][]const u8){};
    var role_text_owners = std.ArrayListUnmanaged([]u8){};
    defer {
        for (role_ids_owners.items) |owner| self.allocator.free(owner);
        role_ids_owners.deinit(self.allocator);
        for (role_names_owners.items) |owner| self.allocator.free(owner);
        role_names_owners.deinit(self.allocator);
        for (role_text_owners.items) |owner| self.allocator.free(owner);
        role_text_owners.deinit(self.allocator);
    }

    for (admins) |admin| {
        const aid = admin.id orelse 0;
        var curr_role_ids_buf = std.ArrayListUnmanaged(i32){};
        defer curr_role_ids_buf.deinit(self.allocator);

        var role_name: []const u8 = "";
        for (all_rels.items) |rel| {
            if (rel.admin_id != aid) continue;
            var exists = false;
            for (curr_role_ids_buf.items) |saved_id| {
                if (saved_id == rel.role_id) {
                    exists = true;
                    break;
                }
            }
            if (!exists) curr_role_ids_buf.append(self.allocator, rel.role_id) catch {};
        }

        const normalized_role_ids = normalizeRoleIds(self.allocator, curr_role_ids_buf.items) catch return base.send_failed(req, "角色数据处理失败");
        role_ids_owners.append(self.allocator, normalized_role_ids) catch {};

        const owned_role_names = try self.allocator.alloc([]const u8, normalized_role_ids.len);
        role_names_owners.append(self.allocator, owned_role_names) catch {};

        var role_text_builder = std.ArrayListUnmanaged(u8){};
        defer role_text_builder.deinit(self.allocator);
        for (normalized_role_ids, 0..) |sorted_role_id, idx| {
            owned_role_names[idx] = "";
            for (roles.items) |role| {
                if ((role.id orelse 0) == sorted_role_id) {
                    owned_role_names[idx] = role.role_name;
                    if (role_name.len == 0) role_name = role.role_name;
                    if (role_text_builder.items.len > 0) {
                        role_text_builder.appendSlice(self.allocator, ",") catch {};
                    }
                    role_text_builder.appendSlice(self.allocator, role.role_name) catch {};
                    break;
                }
            }
        }

        const role_text_owned = role_text_builder.toOwnedSlice(self.allocator) catch "";
        if (role_text_owned.len > 0) {
            role_text_owners.append(self.allocator, @constCast(role_text_owned)) catch {};
        }

        rows.append(self.allocator, .{
            .id = admin.id,
            .username = admin.username,
            .nickname = admin.nickname,
            .mobile = admin.mobile,
            .email = admin.email,
            .avatar = admin.avatar,
            .gender = admin.gender,
            .status = admin.status,
            .dept_id = admin.dept_id,
            .last_login = admin.last_login,
            .role_ids = normalized_role_ids,
            .role_names = owned_role_names,
            .role_name = role_name,
            .role_text = role_text_owned,
        }) catch {};
    }

    base.send_layui_table_response(req, rows.items, total, .{});
}

/// 重置管理员密码接口。
pub const reset_password = resetPasswordImpl;

/// 分配管理员角色接口。
pub const assign_roles = assignRolesImpl;

/// 用户信息接口。
pub const user_info = userInfoImpl;

/// 组织架构管理员列表增强接口。
pub const list_with_roles = listWithRolesImpl;

/// 重置管理员密码为默认值。
fn resetPasswordImpl(self: *Self, req: zap.Request) !void {
    var target_admin_id = parseIdFromReq(req) orelse return base.send_failed(req, "缺少 id 参数");
    var target_hash: []const u8 = "e10adc3949ba59abbe56e057f20f883e";
    var dynamic_hash: ?[]const u8 = null;
    defer if (dynamic_hash) |h| self.allocator.free(h);

    req.parseBody() catch {};
    if (req.body) |body| {
        var parsed_opt = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch null;
        if (parsed_opt) |*parsed| {
            defer parsed.deinit();
            if (parsed.value == .object) {
                if (parsed.value.object.get("id")) |id_val| {
                    if (id_val == .integer) {
                        target_admin_id = @intCast(id_val.integer);
                    }
                }
                if (parsed.value.object.get("password")) |pwd_val| {
                    if (pwd_val == .string and pwd_val.string.len > 0) {
                        const pwd_hash = strings.md5(self.allocator, pwd_val.string) catch return base.send_failed(req, "密码加密失败");
                        dynamic_hash = pwd_hash;
                        target_hash = pwd_hash;
                    }
                }
            }
        } else {
            var fallback = std.json.parseFromSlice(std.json.Value, global.get_allocator(), body, .{}) catch null;
            if (fallback) |*v| {
                defer v.deinit();
                if (v.value == .object) {
                    if (v.value.object.get("id")) |id_val| {
                        if (id_val == .integer) {
                            target_admin_id = @intCast(id_val.integer);
                        }
                    }
                    if (v.value.object.get("password")) |pwd_val| {
                        if (pwd_val == .string and pwd_val.string.len > 0) {
                            const pwd_hash = strings.md5(self.allocator, pwd_val.string) catch return base.send_failed(req, "密码加密失败");
                            dynamic_hash = pwd_hash;
                            target_hash = pwd_hash;
                        }
                    }
                }
            }
        }
    }

    _ = OrmAdmin.Update(target_admin_id, .{
        .password_hash = target_hash,
    }) catch |err| return base.send_error(req, err);

    base.send_ok(req, "密码重置成功");
}

/// 覆盖管理员角色关系。
fn assignRolesImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        return base.send_failed(req, "请求体格式错误");
    }

    const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id 参数");
    const role_ids_val = parsed.value.object.get("role_ids") orelse return base.send_failed(req, "缺少 role_ids 参数");

    if (id_val != .integer or role_ids_val != .array) {
        return base.send_failed(req, "参数格式错误");
    }

    const admin_id: i32 = @intCast(id_val.integer);

    var old_q = OrmAdminRole.WhereEq("admin_id", admin_id);
    defer old_q.deinit();
    const old_rows = old_q.get() catch |err| return base.send_error(req, err);
    defer OrmAdminRole.freeModels(old_rows);

    var old_ids = std.ArrayListUnmanaged(i32){};
    defer old_ids.deinit(self.allocator);
    for (old_rows) |row| old_ids.append(self.allocator, row.role_id) catch {};

    var new_ids = std.ArrayListUnmanaged(i32){};
    defer new_ids.deinit(self.allocator);
    for (role_ids_val.array.items) |role_id_item| {
        if (role_id_item == .integer) new_ids.append(self.allocator, @as(i32, @intCast(role_id_item.integer))) catch {};
    }

    const old_norm = normalizeRoleIds(self.allocator, old_ids.items) catch return base.send_failed(req, "角色数据处理失败");
    defer self.allocator.free(old_norm);
    const new_norm = normalizeRoleIds(self.allocator, new_ids.items) catch return base.send_failed(req, "角色数据处理失败");
    defer self.allocator.free(new_norm);
    if (std.mem.eql(i32, old_norm, new_norm)) {
        return base.send_ok(req, "角色未变更");
    }

    for (new_norm) |role_id_num| {
        const role_opt = OrmRole.Find(role_id_num) catch |err| return base.send_error(req, err);
        if (role_opt == null) return base.send_failed(req, "存在无效角色ID");
        var role_mut = role_opt.?;
        if (role_mut.status != 1) {
            OrmRole.freeModel(&role_mut);
            return base.send_failed(req, "存在禁用角色，无法分配");
        }
        OrmRole.freeModel(&role_mut);
    }

    const db = global.get_db();
    var tx_started = true;
    db.beginTransaction() catch |err| switch (err) {
        error.UseTransactionObject => tx_started = false,
        else => return base.send_error(req, err),
    };
    errdefer if (tx_started) db.rollback() catch {};

    var delete_q = OrmAdminRole.WhereEq("admin_id", admin_id);
    defer delete_q.deinit();
    _ = delete_q.delete() catch |err| return base.send_error(req, err);

    for (new_norm) |role_id_num| {
        _ = OrmAdminRole.Create(.{
            .admin_id = admin_id,
            .role_id = role_id_num,
        }) catch |err| return base.send_error(req, err);
    }

    if (tx_started) {
        db.commit() catch |err| return base.send_error(req, err);
    }

    base.send_ok(req, "角色分配成功");
}

/// 返回当前用户基础信息（联调兼容）。
fn userInfoImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    req.parseQuery();
    const id: i32 = if (req.getParamSlice("id")) |id_str|
        @intCast(strings.to_int(id_str) catch 1)
    else
        1;

    const user_opt = OrmAdmin.Find(id) catch |err| return base.send_error(req, err);
    if (user_opt) |user| {
        var user_mut = user;
        defer OrmAdmin.freeModel(&user_mut);
        return base.send_ok(req, .{
            .id = user_mut.id orelse id,
            .username = user_mut.username,
            .nickname = user_mut.nickname,
            .email = user_mut.email,
            .mobile = user_mut.mobile,
            .avatar = user_mut.avatar,
            .status = user_mut.status,
        });
    }

    base.send_ok(req, .{
        .id = id,
        .username = "admin",
        .nickname = "系统管理员",
        .email = "admin@zigcms.local",
        .mobile = "",
        .avatar = "",
        .status = 1,
    });
}

/// 兼容 query/body 的 id 读取。
fn parseIdFromReq(req: zap.Request) ?i32 {
    req.parseQuery();
    if (req.getParamSlice("id")) |id_str| {
        if (std.fmt.parseInt(i32, id_str, 10)) |id| {
            return id;
        } else |_| {}
    }

    req.parseBody() catch return null;
    const body = req.body orelse return null;
    var parsed = std.json.parseFromSlice(std.json.Value, global.get_allocator(), body, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value != .object) return null;
    const id_val = parsed.value.object.get("id") orelse return null;
    if (id_val != .integer) return null;
    return @intCast(id_val.integer);
}

test "buildInClause 生成 IN 查询片段" {
    const allocator = std.testing.allocator;
    const sql_clause = try buildInClause(allocator, "id", &.{ 1, 2, 3 });
    defer allocator.free(sql_clause);
    try std.testing.expectEqualStrings("id IN (1,2,3)", sql_clause);
}

test "normalizeRoleIds 稳定升序去重" {
    const allocator = std.testing.allocator;
    const normalized = try normalizeRoleIds(allocator, &.{ 3, 1, 2, 2, 3, 1 });
    defer allocator.free(normalized);
    try std.testing.expectEqualSlices(i32, &.{ 1, 2, 3 }, normalized);
}

test "normalizeRoleIds 空数组" {
    const allocator = std.testing.allocator;
    const normalized = try normalizeRoleIds(allocator, &.{});
    defer allocator.free(normalized);
    try std.testing.expectEqual(@as(usize, 0), normalized.len);
}
