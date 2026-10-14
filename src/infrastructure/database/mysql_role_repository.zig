//! MySQL 角色仓储实现
//!
//! 基于 sql ORM（defineWithConfig）实现领域层 RoleRepository 接口。
//! 表结构以现网可用路径为准：sys_role / sys_permission / sys_role_permission / sys_admin_role。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");
const models = @import("../../domain/entities/mod.zig");
const Role = @import("../../domain/entities/role.model.zig").Role;
const Permission = @import("../../domain/entities/role.model.zig").Permission;
const RoleRepository = @import("../../domain/repositories/role_repository.zig").RoleRepository;

// ============================================================================
// ORM 模型
// ============================================================================

/// 角色模型（sys_role，字段与现网 SysRole 一致）
const OrmRole = sql.defineWithConfig(models.SysRole, .{
    .table_name = "sys_role",
    .primary_key = "id",
});

/// 权限目录模型（sys_permission，v2 schema）
const SysPermissionRow = struct {
    id: ?i32 = null,
    perm_name: []const u8 = "",
    perm_code: []const u8 = "",
    menu_id: ?i32 = null,
    perm_type: i32 = 2,
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

const OrmPermission = sql.defineWithConfig(SysPermissionRow, .{
    .table_name = "sys_permission",
    .primary_key = "id",
});

/// 角色-权限关联（sys_role_permission）
const OrmRolePermission = sql.defineWithConfig(models.SysRolePermission, .{
    .table_name = "sys_role_permission",
    .primary_key = "id",
});

/// 管理员-角色关联（sys_admin_role）
const AdminRole = struct {
    id: ?i32 = null,
    admin_id: i32 = 0,
    role_id: i32 = 0,
    created_at: ?i64 = null,
};

const OrmAdminRole = sql.defineWithConfig(AdminRole, .{
    .table_name = "sys_admin_role",
    .primary_key = "id",
});

// ============================================================================
// 仓储实现
// ============================================================================

pub const MysqlRoleRepository = struct {
    allocator: Allocator,
    db: *sql.Database,

    const Self = @This();

    pub fn init(allocator: Allocator, db: *sql.Database) Self {
        if (!OrmRole.hasDb()) OrmRole.use(db);
        if (!OrmPermission.hasDb()) OrmPermission.use(db);
        if (!OrmRolePermission.hasDb()) OrmRolePermission.use(db);
        if (!OrmAdminRole.hasDb()) OrmAdminRole.use(db);
        return .{ .allocator = allocator, .db = db };
    }

    /// 根据 ID 查找角色（含权限）
    pub fn findById(self: *Self, id: i32) !?Role {
        var q = OrmRole.Query();
        _ = q.where("id", "=", id);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();

        if (result.items().len == 0) return null;
        return try self.toDomainRole(result.items()[0]);
    }

    /// 根据代码（role_key）查找角色（含权限）
    pub fn findByCode(self: *Self, code: []const u8) !?Role {
        var q = OrmRole.Query();
        _ = q.where("role_key", "=", code);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();

        if (result.items().len == 0) return null;
        return try self.toDomainRole(result.items()[0]);
    }

    /// 根据管理员 ID 查找角色列表（批量预加载权限，避免 N+1）
    pub fn findByUserId(self: *Self, user_id: i32) ![]Role {
        // 1. 查询管理员-角色关联，收集角色 ID
        var ar_q = OrmAdminRole.Query();
        _ = ar_q.where("admin_id", "=", user_id);
        var ar_result = try ar_q.getWithArena(self.allocator);
        defer ar_result.deinit();
        if (ar_result.items().len == 0) return &[_]Role{};

        var role_ids: std.ArrayList(i32) = .empty;
        defer role_ids.deinit(self.allocator);
        for (ar_result.items()) |ar| {
            try role_ids.append(self.allocator, ar.role_id);
        }

        // 2. 批量查询角色
        var role_q = OrmRole.Query();
        _ = role_q.whereIn("id", role_ids.items);
        var role_result = try role_q.getWithArena(self.allocator);
        defer role_result.deinit();
        if (role_result.items().len == 0) return &[_]Role{};

        // 3. 批量查询角色-权限关联
        var rp_q = OrmRolePermission.Query();
        _ = rp_q.whereIn("role_id", role_ids.items);
        var rp_result = try rp_q.getWithArena(self.allocator);
        defer rp_result.deinit();
        if (rp_result.items().len == 0) {
            // 无权限关联：仅返回角色本体
            var out0: std.ArrayList(Role) = .empty;
            errdefer out0.deinit(self.allocator);
            for (role_result.items()) |r| {
                try out0.append(self.allocator, try self.toDomainRole(r));
            }
            return try out0.toOwnedSlice(self.allocator);
        }

        // 4. 批量查询权限目录（arena 生命周期内仅作模板，不直接输出）
        var perm_ids: std.ArrayList(i32) = .empty;
        defer perm_ids.deinit(self.allocator);
        for (rp_result.items()) |rp| {
            try perm_ids.append(self.allocator, rp.permission_id);
        }

        var perm_q = OrmPermission.Query();
        _ = perm_q.whereIn("id", perm_ids.items)
            .where("status", "=", 1);
        var perm_result = try perm_q.getWithArena(self.allocator);
        defer perm_result.deinit();

        var perm_index = std.AutoHashMap(i32, usize).init(self.allocator);
        defer perm_index.deinit();
        for (perm_result.items(), 0..) |p, idx| {
            if (p.id) |pid| {
                try perm_index.put(pid, idx);
            }
        }

        // role_id → 权限模板下标列表（仅 usize，不持有字符串）
        var rp_index = std.AutoHashMap(i32, std.ArrayList(usize)).init(self.allocator);
        defer {
            var it = rp_index.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            rp_index.deinit();
        }
        for (rp_result.items()) |rp| {
            if (perm_index.get(rp.permission_id)) |idx| {
                const gop = try rp_index.getOrPut(rp.role_id);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .empty;
                }
                try gop.value_ptr.append(self.allocator, idx);
            }
        }

        // 5. 组装：每个角色的权限均为深拷贝（所有权归调用方）
        var out: std.ArrayList(Role) = .empty;
        errdefer out.deinit(self.allocator);
        for (role_result.items()) |r| {
            var domain_role = try self.toDomainRole(r);
            if (r.id) |rid| {
                if (rp_index.get(rid)) |idx_list| {
                    var perms = try self.allocator.alloc(Permission, idx_list.items.len);
                    for (idx_list.items, 0..) |idx, i| {
                        perms[i] = try self.toDomainPermission(perm_result.items()[idx]);
                    }
                    domain_role.permissions = perms;
                }
            }
            try out.append(self.allocator, domain_role);
        }
        return try out.toOwnedSlice(self.allocator);
    }

    /// 查找所有启用的角色
    pub fn findAll(self: *Self) ![]Role {
        var q = OrmRole.Query();
        _ = q.where("status", "=", 1);
        var result = try q.getWithArena(self.allocator);
        defer result.deinit();

        var out: std.ArrayList(Role) = .empty;
        errdefer out.deinit(self.allocator);
        for (result.items()) |r| {
            try out.append(self.allocator, try self.toDomainRole(r));
        }
        return try out.toOwnedSlice(self.allocator);
    }

    /// 保存角色（存在 id 则更新，否则创建）
    pub fn save(self: *Self, role: *Role) !void {
        _ = self;
        try Role.validateCode(role.code);
        try Role.validateName(role.name);

        if (role.id) |id| {
            _ = try OrmRole.UpdateWith(id, .{
                .role_name = role.name,
                .role_key = role.code,
                .remark = role.description,
                .status = role.status,
                .sort = role.sort_order,
            });
        } else {
            const created = try OrmRole.Create(.{
                .role_name = role.name,
                .role_key = role.code,
                .remark = role.description,
                .status = role.status,
                .sort = role.sort_order,
            });
            role.id = created.id orelse return error.MissingId;
        }
    }

    /// 删除角色
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        _ = try OrmRole.Destroy(id);
    }

    /// 获取角色的权限列表
    pub fn getRolePermissions(self: *Self, role_id: i32) ![]Permission {
        var rp_q = OrmRolePermission.Query();
        _ = rp_q.where("role_id", "=", role_id);
        var rp_result = try rp_q.getWithArena(self.allocator);
        defer rp_result.deinit();

        var perm_ids: std.ArrayList(i32) = .empty;
        defer perm_ids.deinit(self.allocator);
        for (rp_result.items()) |rp| {
            try perm_ids.append(self.allocator, rp.permission_id);
        }
        if (perm_ids.items.len == 0) return &[_]Permission{};

        var perm_q = OrmPermission.Query();
        _ = perm_q.whereIn("id", perm_ids.items)
            .where("status", "=", 1);
        var perm_result = try perm_q.getWithArena(self.allocator);
        defer perm_result.deinit();

        var out: std.ArrayList(Permission) = .empty;
        errdefer out.deinit(self.allocator);
        for (perm_result.items()) |p| {
            try out.append(self.allocator, try self.toDomainPermission(p));
        }
        return try out.toOwnedSlice(self.allocator);
    }

    // ========================================================================
    // 映射与内存管理（ORM 结果深拷贝为自包含领域对象）
    // ========================================================================

    fn toDomainRole(self: *Self, r: models.SysRole) !Role {
        var ts_buf: [2][32]u8 = undefined;
        return Role{
            .id = r.id,
            .code = try self.allocator.dupe(u8, r.role_key),
            .name = try self.allocator.dupe(u8, r.role_name),
            .description = try self.allocator.dupe(u8, r.remark),
            .status = r.status,
            .sort_order = r.sort,
            .created_at = try self.allocator.dupe(u8, i64ToStr(r.created_at, &ts_buf[0])),
            .updated_at = try self.allocator.dupe(u8, i64ToStr(r.updated_at, &ts_buf[1])),
            .permissions = null,
        };
    }

    fn toDomainPermission(self: *Self, p: SysPermissionRow) !Permission {
        var ts_buf: [2][32]u8 = undefined;
        return Permission{
            .id = p.id,
            .code = try self.allocator.dupe(u8, p.perm_code),
            .name = try self.allocator.dupe(u8, p.perm_name),
            .description = try self.allocator.dupe(u8, ""),
            .resource = try self.allocator.dupe(u8, ""),
            .action = try self.allocator.dupe(u8, ""),
            .category = try self.allocator.dupe(u8, "general"),
            .status = p.status,
            .created_at = try self.allocator.dupe(u8, i64ToStr(p.created_at, &ts_buf[0])),
            .updated_at = try self.allocator.dupe(u8, i64ToStr(p.updated_at, &ts_buf[1])),
        };
    }

    fn i64ToStr(v: ?i64, buf: *[32]u8) []const u8 {
        const value = v orelse return "";
        return std.fmt.bufPrint(buf, "{d}", .{value}) catch "";
    }

    /// 释放角色内存（与 deep copy 成对使用）
    pub fn freeRole(self: *Self, role: *Role) void {
        self.allocator.free(role.code);
        self.allocator.free(role.name);
        self.allocator.free(role.description);
        self.allocator.free(role.created_at);
        self.allocator.free(role.updated_at);

        if (role.permissions) |perms| {
            for (perms) |*perm| self.freePermission(perm);
            self.allocator.free(perms);
        }
        role.permissions = null;
    }

    /// 释放权限内存
    pub fn freePermission(self: *Self, perm: *Permission) void {
        self.allocator.free(perm.code);
        self.allocator.free(perm.name);
        self.allocator.free(perm.description);
        self.allocator.free(perm.resource);
        self.allocator.free(perm.action);
        self.allocator.free(perm.category);
        self.allocator.free(perm.created_at);
        self.allocator.free(perm.updated_at);
    }

    /// 领域接口 VTable（全部字段编译期已知，可安全取地址）
    pub fn vtable() RoleRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findByCode = findByCodeImpl,
            .findByUserId = findByUserIdImpl,
            .findAll = findAllImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .getRolePermissions = getRolePermissionsImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?Role {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findByCodeImpl(ptr: *anyopaque, code: []const u8) anyerror!?Role {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByCode(code);
    }

    fn findByUserIdImpl(ptr: *anyopaque, user_id: i32) anyerror![]Role {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByUserId(user_id);
    }

    fn findAllImpl(ptr: *anyopaque) anyerror![]Role {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findAll();
    }

    fn saveImpl(ptr: *anyopaque, role: *Role) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(role);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn getRolePermissionsImpl(ptr: *anyopaque, role_id: i32) anyerror![]Permission {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.getRolePermissions(role_id);
    }
};
