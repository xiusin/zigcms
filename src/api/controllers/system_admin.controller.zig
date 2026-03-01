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

const OrmAdminRoleAudit = sql.defineWithConfig(models.SysAdminRoleAudit, .{
    .table_name = "sys_admin_role_audit",
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
    if (!OrmAdminRoleAudit.hasDb()) {
        OrmAdminRoleAudit.use(global.get_db());
    }
    return .{ .allocator = allocator };
}

/// 从请求头解析操作人信息。
fn parseOperator(req: zap.Request) struct { operator_id: i32, operator_name: []const u8 } {
    const uid_raw = req.getHeader("x-user-id") orelse req.getHeader("x-admin-id") orelse "";
    const uname = req.getHeader("x-username") orelse req.getHeader("x-admin-name") orelse "system";
    const uid = std.fmt.parseInt(i32, uid_raw, 10) catch 0;
    return .{ .operator_id = uid, .operator_name = uname };
}

/// 将角色ID列表序列化为逗号分隔字符串。
fn joinRoleIds(allocator: Allocator, role_ids: []const i32) ![]u8 {
    if (role_ids.len == 0) return allocator.dupe(u8, "");
    var buf = std.ArrayListUnmanaged(u8){};
    errdefer buf.deinit(allocator);
    for (role_ids, 0..) |rid, idx| {
        if (idx > 0) try buf.append(allocator, ',');
        const seg = try std.fmt.allocPrint(allocator, "{d}", .{rid});
        defer allocator.free(seg);
        try buf.appendSlice(allocator, seg);
    }
    return try buf.toOwnedSlice(allocator);
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

/// 查询参数结构体
const ListQueryParams = struct {
    page: i32 = 1,
    limit: i32 = 10,
    keyword: []const u8 = "",
    status: ?i32 = null,
    dept_id: ?i32 = null,
    role_id: ?i32 = null,
    sort_field: []const u8 = "",
    sort_value: []const u8 = "",
};

/// 从 HTTP 请求中解析查询参数
fn parseListQueryParams(allocator: Allocator, req: zap.Request) !ListQueryParams {
    var params = ListQueryParams{};

    // 解析 query 参数
    req.parseQuery();
    var query_params = req.parametersToOwnedStrList(allocator) catch |err| {
        return err;
    };
    defer query_params.deinit();

    for (query_params.items) |param| {
        try applyQueryParam(&params, param.key, param.value);
    }

    // 解析 JSON body 参数（覆盖 query 参数）
    req.parseBody() catch {};
    if (req.body) |body| {
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch null;
        defer if (parsed) |*p| p.deinit();
        if (parsed) |p| {
            if (p.value == .object) {
                try applyJsonParams(&params, p.value.object);
            }
        }
    }

    // 参数校验和默认值
    if (params.page < 1) params.page = 1;
    if (params.limit < 1) params.limit = 10;
    if (params.limit > 200) params.limit = 200;

    return params;
}

/// 应用单个 query 参数
fn applyQueryParam(params: *ListQueryParams, key: []const u8, value: []const u8) !void {
    if (std.mem.eql(u8, key, "page")) {
        params.page = @as(i32, @intCast(strings.to_int(value) catch 1));
    } else if (std.mem.eql(u8, key, "limit") or std.mem.eql(u8, key, "pageSize")) {
        params.limit = @as(i32, @intCast(strings.to_int(value) catch 10));
    } else if (std.mem.eql(u8, key, "keyword")) {
        params.keyword = value;
    } else if (std.mem.eql(u8, key, "status") and value.len > 0) {
        params.status = @as(i32, @intCast(strings.to_int(value) catch 0));
    } else if (std.mem.eql(u8, key, "dept_id") and value.len > 0) {
        params.dept_id = @as(i32, @intCast(strings.to_int(value) catch 0));
    } else if (std.mem.eql(u8, key, "role_id") and value.len > 0) {
        params.role_id = @as(i32, @intCast(strings.to_int(value) catch 0));
    }
}

/// 应用 JSON body 参数
fn applyJsonParams(params: *ListQueryParams, obj: std.json.ObjectMap) !void {
    if (obj.get("page")) |v| switch (v) {
        .integer => params.page = @intCast(v.integer),
        else => {},
    };
    if (obj.get("pageSize")) |v| switch (v) {
        .integer => params.limit = @intCast(v.integer),
        else => {},
    };
    if (obj.get("limit")) |v| switch (v) {
        .integer => params.limit = @intCast(v.integer),
        else => {},
    };
    if (obj.get("keyword")) |v| switch (v) {
        .string => params.keyword = v.string,
        else => {},
    };
    if (obj.get("status")) |v| switch (v) {
        .integer => params.status = @intCast(v.integer),
        .string => {
            if (v.string.len > 0) params.status = @intCast(strings.to_int(v.string) catch 0);
        },
        else => {},
    };
    if (obj.get("dept_id")) |v| switch (v) {
        .integer => params.dept_id = @intCast(v.integer),
        .string => {
            if (v.string.len > 0) params.dept_id = @intCast(strings.to_int(v.string) catch 0);
        },
        else => {},
    };
    if (obj.get("role_id")) |v| switch (v) {
        .integer => params.role_id = @intCast(v.integer),
        .string => {
            if (v.string.len > 0) params.role_id = @intCast(strings.to_int(v.string) catch 0);
        },
        else => {},
    };
    if (obj.get("sort")) |v| switch (v) {
        .object => {
            if (v.object.get("field")) |sf| switch (sf) {
                .string => params.sort_field = sf.string,
                else => {},
            };
            if (v.object.get("value")) |sv| switch (sv) {
                .string => params.sort_value = sv.string,
                else => {},
            };
        },
        else => {},
    };
}

/// 管理员行数据结构体
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

/// 查询结果结构体
const AdminListResult = struct {
    rows: []const AdminRow,
    total: u64,
    arena: std.heap.ArenaAllocator,
};

/// 构建管理员查询条件
fn buildAdminQuery(params: ListQueryParams) !sql.ModelQuery(models.SysAdmin) {
    var q = OrmAdmin.Query();
    errdefer q.deinit();

    if (params.status) |v| _ = q.whereEq("status", v);
    if (params.dept_id) |v| _ = q.whereEq("dept_id", v);

    if (params.keyword.len > 0) {
        if (params.keyword.len > 64) return error.KeywordTooLong;
        if (std.mem.indexOfScalar(u8, params.keyword, '\'') != null) return error.InvalidKeyword;
        const like = try std.fmt.allocPrint(global.get_allocator(), "%{s}%", .{params.keyword});
        defer global.get_allocator().free(like);
        const keyword_clause = try std.fmt.allocPrint(global.get_allocator(), "(username LIKE '{s}' OR nickname LIKE '{s}' OR mobile LIKE '{s}')", .{ like, like, like });
        defer global.get_allocator().free(keyword_clause);
        _ = q.whereRaw(keyword_clause, {});
    }

    // 排序
    if (params.sort_field.len > 0 and (std.mem.eql(u8, params.sort_value, "asc") or std.mem.eql(u8, params.sort_value, "ASC"))) {
        _ = q.orderBy(params.sort_field, .asc);
    } else if (params.sort_field.len > 0 and (std.mem.eql(u8, params.sort_value, "desc") or std.mem.eql(u8, params.sort_value, "DESC"))) {
        _ = q.orderBy(params.sort_field, .desc);
    } else {
        _ = q.orderBy("id", .desc);
    }

    return q;
}

/// 获取角色过滤后的管理员 ID 列表
fn getRoleFilteredAdminIds(allocator: Allocator, role_id: i32) ![]i32 {
    var rel_q = OrmAdminRole.WhereEq("role_id", role_id);
    defer rel_q.deinit();
    const rels = rel_q.get() catch |err| return err;
    defer OrmAdminRole.freeModels(rels);

    var admin_ids = std.ArrayListUnmanaged(i32){};
    errdefer admin_ids.deinit(allocator);
    for (rels) |rel| {
        admin_ids.append(allocator, rel.admin_id) catch {};
    }

    return try admin_ids.toOwnedSlice(allocator);
}

/// 获取管理员的角色关联
fn fetchAdminRoles(allocator: Allocator, admins: []const models.SysAdmin) ![]const SysAdminRole {
    var admin_ids = std.ArrayListUnmanaged(i32){};
    errdefer admin_ids.deinit(allocator);
    for (admins) |admin| {
        if (admin.id) |id| admin_ids.append(allocator, id) catch {};
    }

    if (admin_ids.items.len == 0) {
        return &.{};
    }

    var rel_q = OrmAdminRole.Query();
    defer rel_q.deinit();
    const rel_in_clause = try buildInClause(allocator, "admin_id", admin_ids.items);
    defer allocator.free(rel_in_clause);
    _ = rel_q.whereRaw(rel_in_clause, {});

    const rel_rows = rel_q.get() catch |err| return err;
    defer OrmAdminRole.freeModels(rel_rows);

    var result = std.ArrayListUnmanaged(SysAdminRole){};
    errdefer result.deinit(allocator);
    for (rel_rows) |rel| {
        result.append(allocator, rel) catch {};
    }

    return try result.toOwnedSlice(allocator);
}

/// 根据 ID 列表获取角色
fn fetchRolesByIds(allocator: Allocator, admin_roles: []const SysAdminRole) ![]const models.SysRole {
    var role_ids = std.ArrayListUnmanaged(i32){};
    errdefer role_ids.deinit(allocator);
    for (admin_roles) |rel| {
        role_ids.append(allocator, rel.role_id) catch {};
    }

    if (role_ids.items.len == 0) {
        return &.{};
    }

    var role_q = OrmRole.Query();
    defer role_q.deinit();
    const role_in_clause = try buildInClause(allocator, "id", role_ids.items);
    defer allocator.free(role_in_clause);
    _ = role_q.whereRaw(role_in_clause, {});

    const role_result = try role_q.getWithArena(allocator);
    return role_result.items();
}

/// 构建单个管理员的行数据
fn buildAdminRowData(
    allocator: Allocator,
    admin_id: i32,
    admin_roles: []const SysAdminRole,
    roles: []const models.SysRole,
) !struct {
    role_ids: []const i32,
    role_names: []const []const u8,
    role_name: []const u8,
    role_text: []const u8,
} {
    // 1. 收集角色 ID
    var role_ids_buf = std.ArrayListUnmanaged(i32){};
    errdefer role_ids_buf.deinit(allocator);

    for (admin_roles) |rel| {
        if (rel.admin_id != admin_id) continue;
        var exists = false;
        for (role_ids_buf.items) |saved_id| {
            if (saved_id == rel.role_id) {
                exists = true;
                break;
            }
        }
        if (!exists) try role_ids_buf.append(allocator, rel.role_id);
    }

    const normalized_role_ids = try normalizeRoleIds(allocator, role_ids_buf.items);

    // 2. 收集角色名称
    const role_names = try allocator.alloc([]const u8, normalized_role_ids.len);
    var role_name: []const u8 = "";
    var role_text_builder = std.ArrayListUnmanaged(u8){};
    errdefer role_text_builder.deinit(allocator);

    for (normalized_role_ids, 0..) |sorted_role_id, idx| {
        role_names[idx] = "";
        for (roles) |role| {
            if ((role.id orelse 0) == sorted_role_id) {
                const role_name_owned = try allocator.dupe(u8, role.role_name);
                role_names[idx] = role_name_owned;
                if (role_name.len == 0) role_name = role_name_owned;
                if (role_text_builder.items.len > 0) {
                    try role_text_builder.appendSlice(allocator, ",");
                }
                try role_text_builder.appendSlice(allocator, role_name_owned);
                break;
            }
        }
    }

    const role_text = try role_text_builder.toOwnedSlice(allocator);

    return .{
        .role_ids = normalized_role_ids,
        .role_names = role_names,
        .role_name = role_name,
        .role_text = role_text,
    };
}

/// 组装管理员行数据
fn assembleAdminRows(
    allocator: Allocator,
    admins: []const models.SysAdmin,
    admin_roles: []const SysAdminRole,
    roles: []const models.SysRole,
) ![]const AdminRow {
    var rows = std.ArrayListUnmanaged(AdminRow){};
    errdefer rows.deinit(allocator);

    for (admins) |admin| {
        const aid = admin.id orelse 0;
        const row_data = try buildAdminRowData(allocator, aid, admin_roles, roles);

        const row = AdminRow{
            .id = admin.id,
            .username = try allocator.dupe(u8, admin.username),
            .nickname = try allocator.dupe(u8, admin.nickname),
            .mobile = try allocator.dupe(u8, admin.mobile),
            .email = try allocator.dupe(u8, admin.email),
            .avatar = try allocator.dupe(u8, admin.avatar),
            .gender = admin.gender,
            .status = admin.status,
            .dept_id = admin.dept_id,
            .last_login = admin.last_login,
            .role_ids = row_data.role_ids,
            .role_names = row_data.role_names,
            .role_name = row_data.role_name,
            .role_text = row_data.role_text,
        };

        try rows.append(allocator, row);
    }

    return try rows.toOwnedSlice(allocator);
}

/// 获取管理员及其角色数据
fn fetchAdminsWithRoles(allocator: Allocator, params: ListQueryParams) !AdminListResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    // 1. 构建查询
    var q = try buildAdminQuery(params);
    defer q.deinit();

    // 2. 角色过滤
    if (params.role_id) |rid| {
        const admin_ids = try getRoleFilteredAdminIds(allocator, rid);
        defer allocator.free(admin_ids);

        if (admin_ids.len == 0) {
            return AdminListResult{
                .rows = &.{},
                .total = 0,
                .arena = arena,
            };
        }

        const in_clause = try buildInClause(allocator, "id", admin_ids);
        defer allocator.free(in_clause);
        _ = q.whereRaw(in_clause, {});
    }

    // 3. 查询管理员列表
    const total = q.count() catch |err| return err;
    _ = q.page(@intCast(params.page), @intCast(params.limit));
    const admins = q.get() catch |err| return err;
    defer OrmAdmin.freeModels(admins);

    // 4. 查询角色关联
    const admin_roles = try fetchAdminRoles(arena.allocator(), admins);

    // 5. 查询角色详情
    const roles = try fetchRolesByIds(arena.allocator(), admin_roles);

    // 6. 组装数据
    const rows = try assembleAdminRows(arena.allocator(), admins, admin_roles, roles);

    return AdminListResult{
        .rows = rows,
        .total = total,
        .arena = arena,
    };
}

/// 返回管理员分页列表，并附带角色名称与角色ID集合。
fn listWithRolesImpl(self: *Self, req: zap.Request) !void {
    // 1. 解析参数
    const params = parseListQueryParams(self.allocator, req) catch |err| {
        return base.send_error(req, err);
    };

    // 2. 构建查询并获取数据
    const result = fetchAdminsWithRoles(self.allocator, params) catch |err| {
        switch (err) {
            error.KeywordTooLong => return base.send_failed(req, "keyword 长度不能超过 64"),
            error.InvalidKeyword => return base.send_failed(req, "keyword 包含非法字符"),
            else => return base.send_error(req, err),
        }
    };

    // 3. 返回响应
    base.send_layui_table_response(req, result.rows, result.total, .{});
}

/// 重置管理员密码接口。
pub const reset_password = resetPasswordImpl;

/// 分配管理员角色接口。
pub const assign_roles = assignRolesImpl;

/// 管理员保存接口。
pub const save = saveAdminImpl;

/// 管理员详情接口。
pub const get = getAdminImpl;

/// 管理员状态设置接口。
pub const set = setAdminImpl;

/// 管理员删除接口。
pub const delete = deleteAdminImpl;

/// 管理员下拉接口。
pub const select = selectAdminImpl;

/// 用户信息接口。
pub const user_info = userInfoImpl;

/// 组织架构管理员列表增强接口。
pub const list_with_roles = listWithRolesImpl;

/// 管理员保存（新增/编辑）。
fn saveAdminImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();
    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");

    const obj = parsed.value.object;
    var id: i32 = 0;
    if (obj.get("id")) |id_val| {
        if (id_val == .integer) id = @intCast(id_val.integer);
    }

    var role_id_present = false;
    var role_ids_buf = std.ArrayListUnmanaged(i32){};
    defer role_ids_buf.deinit(self.allocator);

    // 优先使用 role_ids 数组
    if (obj.get("role_ids")) |role_ids_val| {
        if (role_ids_val == .array) {
            role_id_present = true;
            for (role_ids_val.array.items) |role_id_item| {
                if (role_id_item == .integer) {
                    const rid: i32 = @intCast(role_id_item.integer);
                    if (rid > 0) role_ids_buf.append(self.allocator, rid) catch {};
                }
            }
        } else {
            return base.send_failed(req, "role_ids 参数格式错误");
        }
    }

    // 如果没有 role_ids，则使用 role_id
    if (!role_id_present) {
        if (obj.get("role_id")) |role_val| {
            role_id_present = true;
            if (role_val == .integer) {
                const rid: i32 = @intCast(role_val.integer);
                if (rid > 0) role_ids_buf.append(self.allocator, rid) catch {};
            } else if (role_val != .null) {
                return base.send_failed(req, "role_id 参数格式错误");
            }
        }
    }

    var normalized_role_ids: []i32 = &.{};
    var normalized_role_ids_owner: ?[]i32 = null;
    defer if (normalized_role_ids_owner) |owned| self.allocator.free(owned);

    if (role_id_present) {
        const normalized = normalizeRoleIds(self.allocator, role_ids_buf.items) catch |err| return base.send_error(req, err);
        normalized_role_ids_owner = normalized;
        normalized_role_ids = normalized;
    }

    var dynamic_hash: ?[]const u8 = null;
    defer if (dynamic_hash) |hash| self.allocator.free(hash);

    var model = models.SysAdmin{};
    var admin_id: i32 = 0;

    if (id > 0) {
        // 验证管理员是否存在
        const current_opt = OrmAdmin.Find(id) catch |err| return base.send_error(req, err);
        if (current_opt == null) return base.send_failed(req, "管理员不存在");
        var current = current_opt.?;
        defer OrmAdmin.freeModel(&current);

        // 验证用户名唯一性
        if (obj.get("username")) |v| {
            if (v == .string) {
                const username = std.mem.trim(u8, v.string, " \t\r\n");
                if (username.len == 0) return base.send_failed(req, "用户名不能为空");
                const unique = ensureUsernameUnique(self, username, id) catch |err| return base.send_error(req, err);
                if (!unique) return base.send_failed(req, "用户名已存在");
            }
        }

        // 处理密码字段
        if (obj.get("password")) |pwd_val| {
            if (pwd_val == .string and pwd_val.string.len > 0) {
                var confirm_ok = true;
                if (obj.get("confirm_password")) |confirm_val| {
                    if (confirm_val == .string) {
                        confirm_ok = std.mem.eql(u8, pwd_val.string, confirm_val.string);
                    }
                }
                if (!confirm_ok) return base.send_failed(req, "两次密码输入不一致");

                const pwd_hash = strings.md5(self.allocator, pwd_val.string) catch return base.send_failed(req, "密码加密失败");
                dynamic_hash = pwd_hash;
            }
        }

        // 使用真正的动态匿名结构体 .{} 更新（Zig 编译时特性）
        // 只包含需要更新的字段，null 值会被自动跳过
        _ = OrmAdmin.UpdateWith(id, .{
            .username = if (obj.get("username")) |v| if (v == .string) v.string else null else null,
            .nickname = if (obj.get("nickname")) |v| if (v == .string) v.string else null else null,
            .password_hash = dynamic_hash,
            .mobile = if (obj.get("mobile")) |v| if (v == .string) v.string else null else null,
            .email = if (obj.get("email")) |v| if (v == .string) v.string else null else null,
            .avatar = if (obj.get("avatar")) |v| if (v == .string) v.string else null else null,
            .gender = if (obj.get("gender")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
            .dept_id = if (obj.get("dept_id")) |v| if (v == .null) null else if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
            .position_id = if (obj.get("position_id")) |v| if (v == .null) null else if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
            .status = if (obj.get("status")) |v| if (v == .integer) @as(?i32, @intCast(v.integer)) else null else null,
            .remark = if (obj.get("remark")) |v| if (v == .string) v.string else null else null,
        }) catch |err| return base.send_error(req, err);
        admin_id = id;
    } else {
        const username_val = obj.get("username") orelse return base.send_failed(req, "缺少 username 参数");
        const nickname_val = obj.get("nickname") orelse return base.send_failed(req, "缺少 nickname 参数");
        const password_val = obj.get("password") orelse return base.send_failed(req, "缺少 password 参数");
        const confirm_val = obj.get("confirm_password") orelse return base.send_failed(req, "缺少 confirm_password 参数");
        if (username_val != .string or nickname_val != .string or password_val != .string or confirm_val != .string) {
            return base.send_failed(req, "参数格式错误");
        }

        const username = std.mem.trim(u8, username_val.string, " \t\r\n");
        if (username.len == 0) return base.send_failed(req, "用户名不能为空");
        if (!std.mem.eql(u8, password_val.string, confirm_val.string)) return base.send_failed(req, "两次密码输入不一致");

        const unique = ensureUsernameUnique(self, username, 0) catch |err| return base.send_error(req, err);
        if (!unique) return base.send_failed(req, "用户名已存在");

        const pwd_hash = strings.md5(self.allocator, password_val.string) catch return base.send_failed(req, "密码加密失败");
        dynamic_hash = pwd_hash;

        model = .{
            .username = username,
            .nickname = nickname_val.string,
            .password_hash = pwd_hash,
            .mobile = if (obj.get("mobile")) |v| if (v == .string) v.string else "" else "",
            .email = if (obj.get("email")) |v| if (v == .string) v.string else "" else "",
            .avatar = if (obj.get("avatar")) |v| if (v == .string) v.string else "" else "",
            .gender = if (obj.get("gender")) |v| if (v == .integer) @intCast(v.integer) else 0 else 0,
            .dept_id = if (obj.get("dept_id")) |v| if (v == .integer) @intCast(v.integer) else null else null,
            .status = if (obj.get("status")) |v| if (v == .integer) @intCast(v.integer) else 1 else 1,
            .remark = if (obj.get("remark")) |v| if (v == .string) v.string else "" else "",
        };

        var created = OrmAdmin.Create(model) catch |err| return base.send_error(req, err);
        defer OrmAdmin.freeModel(&created);
        admin_id = created.id orelse 0;
        if (admin_id <= 0) return base.send_failed(req, "管理员创建失败");
    }

    if (role_id_present) {
        for (normalized_role_ids) |rid| {
            ensureRoleEnabled(rid) catch |err| switch (err) {
                error.InvalidRole => {
                    std.log.err("角色不存在: role_id={d}", .{rid});
                    return base.send_failed(req, "角色不存在");
                },
                error.RoleDisabled => {
                    std.log.err("角色已禁用: role_id={d}", .{rid});
                    return base.send_failed(req, "角色已禁用");
                },
                else => {
                    std.log.err("角色验证失败: role_id={d}, error={}", .{ rid, err });
                    return base.send_error(req, err);
                },
            };
        }

        try replaceAdminRoles(admin_id, normalized_role_ids);
    }

    return base.send_ok(req, .{ .id = admin_id });
}

/// 管理员详情读取。
fn getAdminImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    const id = parseIdFromReq(req) orelse return base.send_failed(req, "缺少 id 参数");
    const admin_opt = OrmAdmin.Find(id) catch |err| return base.send_error(req, err);
    if (admin_opt == null) return base.send_failed(req, "管理员不存在");

    var admin = admin_opt.?;
    defer OrmAdmin.freeModel(&admin);
    return base.send_ok(req, admin);
}

/// 管理员单字段设置。
fn setAdminImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, body, .{}) catch {
        return base.send_failed(req, "请求体格式错误");
    };
    defer parsed.deinit();
    if (parsed.value != .object) return base.send_failed(req, "请求体格式错误");

    const id_val = parsed.value.object.get("id") orelse return base.send_failed(req, "缺少 id 参数");
    const field_val = parsed.value.object.get("field") orelse return base.send_failed(req, "缺少 field 参数");
    const value_val = parsed.value.object.get("value") orelse return base.send_failed(req, "缺少 value 参数");
    if (id_val != .integer or field_val != .string or value_val != .integer) return base.send_failed(req, "参数格式错误");
    if (!std.mem.eql(u8, field_val.string, "status")) return base.send_failed(req, "仅支持更新 status 字段");

    const target_id: i32 = @intCast(id_val.integer);
    _ = OrmAdmin.Update(target_id, .{ .status = @as(i32, @intCast(value_val.integer)) }) catch |err| return base.send_error(req, err);
    return base.send_ok(req, "更新成功");
}

/// 删除管理员并清理角色关系。
fn deleteAdminImpl(self: *Self, req: zap.Request) !void {
    _ = self;
    const id = parseIdFromReq(req) orelse return base.send_failed(req, "缺少 id 参数");

    var delete_rel_q = OrmAdminRole.WhereEq("admin_id", id);
    defer delete_rel_q.deinit();
    _ = delete_rel_q.delete() catch |err| return base.send_error(req, err);

    _ = OrmAdmin.Destroy(id) catch |err| return base.send_error(req, err);
    return base.send_ok(req, "删除成功");
}

/// 管理员下拉列表。
fn selectAdminImpl(self: *Self, req: zap.Request) !void {
    var q = OrmAdmin.Query();
    defer q.deinit();
    _ = q.whereEq("status", @as(i32, 1));
    _ = q.orderBy("id", .desc);
    _ = q.limit(100);

    const rows = q.get() catch |err| return base.send_error(req, err);
    defer OrmAdmin.freeModels(rows);

    const Item = struct {
        id: i32,
        username: []const u8,
        nickname: []const u8,
    };

    var items = std.ArrayListUnmanaged(Item){};
    defer items.deinit(self.allocator);
    for (rows) |row| {
        items.append(self.allocator, .{
            .id = row.id orelse 0,
            .username = row.username,
            .nickname = row.nickname,
        }) catch {};
    }
    return base.send_ok(req, items.items);
}

/// 校验用户名是否唯一（可排除当前管理员）。
fn ensureUsernameUnique(self: *Self, username: []const u8, exclude_id: i32) !bool {
    _ = self;
    var q = OrmAdmin.WhereEq("username", username);
    defer q.deinit();
    const rows = q.get() catch |err| return err;
    defer OrmAdmin.freeModels(rows);

    for (rows) |row| {
        if ((row.id orelse 0) != exclude_id) return false;
    }
    return true;
}

/// 校验角色是否存在且启用。
fn ensureRoleEnabled(role_id: i32) !void {
    const role_opt = OrmRole.Find(role_id) catch |err| return err;
    if (role_opt == null) return error.InvalidRole;

    var role = role_opt.?;
    defer OrmRole.freeModel(&role);
    if (role.status != 1) return error.RoleDisabled;
}

/// 覆盖管理员角色关联。
fn replaceAdminRoles(admin_id: i32, role_ids: []const i32) !void {
    var delete_q = OrmAdminRole.WhereEq("admin_id", admin_id);
    defer delete_q.deinit();
    _ = delete_q.delete() catch |err| return err;

    for (role_ids) |rid| {
        var created = OrmAdminRole.Create(.{
            .admin_id = admin_id,
            .role_id = rid,
        }) catch |err| return err;
        OrmAdminRole.freeModel(&created);
    }
}

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
    const operator = parseOperator(req);
    const request_ip = req.getHeader("x-forwarded-for") orelse "";

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

    var valid_role_ids = std.ArrayListUnmanaged(i32){};
    defer valid_role_ids.deinit(self.allocator);
    for (new_norm) |role_id_num| {
        const role_opt = OrmRole.Find(role_id_num) catch |err| return base.send_error(req, err);
        if (role_opt == null) return base.send_failed(req, "存在无效角色ID");
        valid_role_ids.append(self.allocator, role_id_num) catch {};
        OrmRole.freeModel(@constCast(&role_opt.?));
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

    for (valid_role_ids.items) |role_id_num| {
        var created = OrmAdminRole.Create(.{
            .admin_id = admin_id,
            .role_id = role_id_num,
        }) catch |err| return base.send_error(req, err);
        OrmAdminRole.freeModel(&created);
    }

    const old_role_ids_text = joinRoleIds(self.allocator, old_norm) catch return base.send_failed(req, "角色审计数据构建失败");
    defer self.allocator.free(old_role_ids_text);
    const new_role_ids_text = joinRoleIds(self.allocator, valid_role_ids.items) catch return base.send_failed(req, "角色审计数据构建失败");
    defer self.allocator.free(new_role_ids_text);

    // 避免空 slice 被绑定为 NULL，确保写入非空字符串
    const old_role_ids_value = if (old_role_ids_text.len == 0) "[]" else old_role_ids_text;
    const new_role_ids_value = if (new_role_ids_text.len == 0) "[]" else new_role_ids_text;

    if (OrmAdminRoleAudit.Create(.{
        .admin_id = admin_id,
        .operator_id = operator.operator_id,
        .operator_name = operator.operator_name,
        .old_role_ids = old_role_ids_value,
        .new_role_ids = new_role_ids_value,
        .request_ip = request_ip,
    })) |audit_record| {
        var audit_mut = audit_record;
        OrmAdminRoleAudit.freeModel(&audit_mut);
    } else |err| {
        std.log.err("写入管理员角色审计失败 admin_id={d} err={}", .{ admin_id, err });
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
