//! 角色实体模型

const std = @import("std");

/// 角色实体
pub const Role = struct {
    id: ?i32 = null,
    code: []const u8 = "",
    name: []const u8 = "",
    description: []const u8 = "",
    status: i32 = 1,
    sort_order: i32 = 0,
    created_at: []const u8 = "",
    updated_at: []const u8 = "",
    
    /// 权限列表（关联数据）
    permissions: ?[]Permission = null,
    
    /// 验证角色代码
    pub fn validateCode(code: []const u8) !void {
        if (code.len == 0) {
            return error.RoleCodeEmpty;
        }
        if (code.len > 50) {
            return error.RoleCodeTooLong;
        }
        // 只允许字母、数字和下划线
        for (code) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                return error.RoleCodeInvalid;
            }
        }
    }
    
    /// 验证角色名称
    pub fn validateName(name: []const u8) !void {
        if (name.len == 0) {
            return error.RoleNameEmpty;
        }
        if (name.len > 100) {
            return error.RoleNameTooLong;
        }
    }
    
    /// 检查角色是否启用
    pub fn isActive(self: *const Role) bool {
        return self.status == 1;
    }
    
    /// 检查是否是超级管理员
    pub fn isSuperAdmin(self: *const Role) bool {
        return std.mem.eql(u8, self.code, "super_admin");
    }
};

/// 权限实体
pub const Permission = struct {
    id: ?i32 = null,
    code: []const u8 = "",
    name: []const u8 = "",
    description: []const u8 = "",
    resource: []const u8 = "",
    action: []const u8 = "",
    category: []const u8 = "general",
    status: i32 = 1,
    created_at: []const u8 = "",
    updated_at: []const u8 = "",
    
    /// 验证权限代码
    pub fn validateCode(code: []const u8) !void {
        if (code.len == 0) {
            return error.PermissionCodeEmpty;
        }
        if (code.len > 100) {
            return error.PermissionCodeTooLong;
        }
        // 权限代码格式: resource:action 或 category:resource:action
        if (std.mem.indexOf(u8, code, ":") == null) {
            return error.PermissionCodeInvalid;
        }
    }
    
    /// 检查权限是否启用
    pub fn isActive(self: *const Permission) bool {
        return self.status == 1;
    }
};

/// 角色权限关联
pub const RolePermission = struct {
    id: ?i32 = null,
    role_id: i32 = 0,
    permission_id: i32 = 0,
    created_at: []const u8 = "",
};

/// 用户角色关联
pub const UserRole = struct {
    id: ?i32 = null,
    user_id: i32 = 0,
    role_id: i32 = 0,
    created_at: []const u8 = "",
};

/// 用户权限缓存
pub const UserPermissionCache = struct {
    user_id: i32 = 0,
    permissions: []const u8 = "", // JSON 格式
    updated_at: []const u8 = "",
};
