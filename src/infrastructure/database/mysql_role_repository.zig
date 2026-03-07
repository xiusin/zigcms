//! MySQL 角色仓储实现

const std = @import("std");
const Allocator = std.mem.Allocator;
const Role = @import("../../domain/entities/role.model.zig").Role;
const Permission = @import("../../domain/entities/role.model.zig").Permission;
const RoleRepository = @import("../../domain/repositories/role_repository.zig").RoleRepository;

// 假设 ORM 定义（需要根据实际 ORM 调整）
const OrmRole = struct {
    pub fn Query() QueryBuilder {
        return QueryBuilder{};
    }
    pub fn Create(role: Role) !Role {
        _ = role;
        return error.NotImplemented;
    }
    pub fn UpdateWith(id: i32, data: anytype) !void {
        _ = id;
        _ = data;
        return error.NotImplemented;
    }
    pub fn Delete(id: i32) !void {
        _ = id;
        return error.NotImplemented;
    }
    pub fn freeModels(models: []Role) void {
        _ = models;
    }
};

const OrmPermission = struct {
    pub fn Query() PermissionQueryBuilder {
        return PermissionQueryBuilder{};
    }
    pub fn freeModels(models: []Permission) void {
        _ = models;
    }
};

const QueryBuilder = struct {
    pub fn where(self: *QueryBuilder, field: []const u8, op: []const u8, value: anytype) *QueryBuilder {
        _ = self;
        _ = field;
        _ = op;
        _ = value;
        return self;
    }
    pub fn with(self: *QueryBuilder, relations: []const []const u8) *QueryBuilder {
        _ = self;
        _ = relations;
        return self;
    }
    pub fn get(self: *QueryBuilder) ![]Role {
        _ = self;
        return error.NotImplemented;
    }
    pub fn getWithArena(self: *QueryBuilder, allocator: Allocator) !struct {
        pub fn items(self: @This()) []Role {
            _ = self;
            return &[_]Role{};
        }
        pub fn deinit(self: *@This()) void {
            _ = self;
        }
    } {
        _ = self;
        _ = allocator;
        return error.NotImplemented;
    }
    pub fn deinit(self: *QueryBuilder) void {
        _ = self;
    }
};

const PermissionQueryBuilder = struct {
    pub fn whereIn(self: *PermissionQueryBuilder, field: []const u8, values: []const i32) *PermissionQueryBuilder {
        _ = self;
        _ = field;
        _ = values;
        return self;
    }
    pub fn where(self: *PermissionQueryBuilder, field: []const u8, op: []const u8, value: anytype) *PermissionQueryBuilder {
        _ = self;
        _ = field;
        _ = op;
        _ = value;
        return self;
    }
    pub fn get(self: *PermissionQueryBuilder) ![]Permission {
        _ = self;
        return error.NotImplemented;
    }
    pub fn getWithArena(self: *PermissionQueryBuilder, allocator: Allocator) !struct {
        pub fn items(self: @This()) []Permission {
            _ = self;
            return &[_]Permission{};
        }
        pub fn deinit(self: *@This()) void {
            _ = self;
        }
    } {
        _ = self;
        _ = allocator;
        return error.NotImplemented;
    }
    pub fn deinit(self: *PermissionQueryBuilder) void {
        _ = self;
    }
};

/// MySQL 角色仓储实现
pub const MysqlRoleRepository = struct {
    allocator: Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }
    
    /// 根据ID查找角色
    pub fn findById(self: *Self, id: i32) !?Role {
        var q = OrmRole.Query();
        defer q.deinit();
        
        _ = q.where("id", "=", id)
             .with(&.{"permissions"}); // 预加载权限
        
        const roles = try q.get();
        defer OrmRole.freeModels(roles);
        
        if (roles.len == 0) return null;
        
        // 深拷贝角色数据
        return try self.deepCopyRole(roles[0]);
    }
    
    /// 根据代码查找角色
    pub fn findByCode(self: *Self, code: []const u8) !?Role {
        var q = OrmRole.Query();
        defer q.deinit();
        
        _ = q.where("code", "=", code)
             .with(&.{"permissions"}); // 预加载权限
        
        const roles = try q.get();
        defer OrmRole.freeModels(roles);
        
        if (roles.len == 0) return null;
        
        return try self.deepCopyRole(roles[0]);
    }
    
    /// 根据用户ID查找角色列表
    pub fn findByUserId(self: *Self, user_id: i32) ![]Role {
        // 使用 Arena 分配器简化内存管理
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();
        
        // 1. 查询用户角色关联
        var user_role_q = OrmRole.Query();
        defer user_role_q.deinit();
        
        _ = user_role_q.where("user_id", "=", user_id);
        var user_role_result = try user_role_q.getWithArena(arena_allocator);
        const user_roles = user_role_result.items();
        
        if (user_roles.len == 0) {
            return &[_]Role{};
        }
        
        // 2. 收集角色ID
        var role_ids = std.ArrayList(i32).init(arena_allocator);
        for (user_roles) |ur| {
            if (ur.id) |rid| {
                try role_ids.append(rid);
            }
        }
        
        // 3. 批量查询角色
        var role_q = OrmRole.Query();
        defer role_q.deinit();
        
        _ = role_q.where("id", "IN", role_ids.items)
             .with(&.{"permissions"}); // 预加载权限
        
        var role_result = try role_q.getWithArena(arena_allocator);
        const roles = role_result.items();
        
        // 4. 深拷贝角色列表
        var result = std.ArrayList(Role).init(self.allocator);
        errdefer result.deinit();
        
        for (roles) |role| {
            const copied = try self.deepCopyRole(role);
            try result.append(copied);
        }
        
        return try result.toOwnedSlice();
    }
    
    /// 查找所有角色
    pub fn findAll(self: *Self) ![]Role {
        var q = OrmRole.Query();
        defer q.deinit();
        
        _ = q.where("status", "=", 1); // 只查询启用的角色
        
        const roles = try q.get();
        defer OrmRole.freeModels(roles);
        
        // 深拷贝角色列表
        var result = std.ArrayList(Role).init(self.allocator);
        errdefer result.deinit();
        
        for (roles) |role| {
            const copied = try self.deepCopyRole(role);
            try result.append(copied);
        }
        
        return try result.toOwnedSlice();
    }
    
    /// 保存角色
    pub fn save(self: *Self, role: *Role) !void {
        _ = self;
        
        // 验证角色数据
        try Role.validateCode(role.code);
        try Role.validateName(role.name);
        
        if (role.id) |id| {
            // 更新
            _ = try OrmRole.UpdateWith(id, .{
                .code = role.code,
                .name = role.name,
                .description = role.description,
                .status = role.status,
                .sort_order = role.sort_order,
            });
        } else {
            // 创建
            const created = try OrmRole.Create(role.*);
            role.id = created.id;
        }
    }
    
    /// 删除角色
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        try OrmRole.Delete(id);
    }
    
    /// 获取角色的权限列表
    pub fn getRolePermissions(self: *Self, role_id: i32) ![]Permission {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();
        
        // 1. 查询角色权限关联
        var rp_q = OrmPermission.Query();
        defer rp_q.deinit();
        
        _ = rp_q.where("role_id", "=", role_id);
        var rp_result = try rp_q.getWithArena(arena_allocator);
        const role_perms = rp_result.items();
        
        if (role_perms.len == 0) {
            return &[_]Permission{};
        }
        
        // 2. 收集权限ID
        var perm_ids = std.ArrayList(i32).init(arena_allocator);
        for (role_perms) |rp| {
            if (rp.id) |pid| {
                try perm_ids.append(pid);
            }
        }
        
        // 3. 批量查询权限
        var perm_q = OrmPermission.Query();
        defer perm_q.deinit();
        
        _ = perm_q.whereIn("id", perm_ids.items)
             .where("status", "=", 1); // 只查询启用的权限
        
        var perm_result = try perm_q.getWithArena(arena_allocator);
        const permissions = perm_result.items();
        
        // 4. 深拷贝权限列表
        var result = std.ArrayList(Permission).init(self.allocator);
        errdefer result.deinit();
        
        for (permissions) |perm| {
            const copied = try self.deepCopyPermission(perm);
            try result.append(copied);
        }
        
        return try result.toOwnedSlice();
    }
    
    /// 深拷贝角色（包含权限）
    fn deepCopyRole(self: *Self, role: Role) !Role {
        var copied = Role{
            .id = role.id,
            .code = try self.allocator.dupe(u8, role.code),
            .name = try self.allocator.dupe(u8, role.name),
            .description = try self.allocator.dupe(u8, role.description),
            .status = role.status,
            .sort_order = role.sort_order,
            .created_at = try self.allocator.dupe(u8, role.created_at),
            .updated_at = try self.allocator.dupe(u8, role.updated_at),
            .permissions = null,
        };
        
        // 深拷贝权限列表
        if (role.permissions) |perms| {
            var perm_list = std.ArrayList(Permission).init(self.allocator);
            errdefer perm_list.deinit();
            
            for (perms) |perm| {
                const copied_perm = try self.deepCopyPermission(perm);
                try perm_list.append(copied_perm);
            }
            
            copied.permissions = try perm_list.toOwnedSlice();
        }
        
        return copied;
    }
    
    /// 深拷贝权限
    fn deepCopyPermission(self: *Self, perm: Permission) !Permission {
        return Permission{
            .id = perm.id,
            .code = try self.allocator.dupe(u8, perm.code),
            .name = try self.allocator.dupe(u8, perm.name),
            .description = try self.allocator.dupe(u8, perm.description),
            .resource = try self.allocator.dupe(u8, perm.resource),
            .action = try self.allocator.dupe(u8, perm.action),
            .category = try self.allocator.dupe(u8, perm.category),
            .status = perm.status,
            .created_at = try self.allocator.dupe(u8, perm.created_at),
            .updated_at = try self.allocator.dupe(u8, perm.updated_at),
        };
    }
    
    /// 释放角色内存
    pub fn freeRole(self: *Self, role: *Role) void {
        self.allocator.free(role.code);
        self.allocator.free(role.name);
        self.allocator.free(role.description);
        self.allocator.free(role.created_at);
        self.allocator.free(role.updated_at);
        
        if (role.permissions) |perms| {
            for (perms) |*perm| {
                self.freePermission(perm);
            }
            self.allocator.free(perms);
        }
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
    
    /// 创建仓储接口
    pub fn interface(self: *Self) RoleRepository {
        return RoleRepository{
            .ptr = self,
            .vtable = &.{
                .findById = findByIdImpl,
                .findByCode = findByCodeImpl,
                .findByUserId = findByUserIdImpl,
                .findAll = findAllImpl,
                .save = saveImpl,
                .delete = deleteImpl,
                .getRolePermissions = getRolePermissionsImpl,
            },
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
