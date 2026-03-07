//! 角色仓储接口

const std = @import("std");
const Role = @import("../entities/role.model.zig").Role;
const Permission = @import("../entities/role.model.zig").Permission;

/// 角色仓储接口
pub const RoleRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    const Self = @This();
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?Role,
        findByCode: *const fn (*anyopaque, []const u8) anyerror!?Role,
        findByUserId: *const fn (*anyopaque, i32) anyerror![]Role,
        findAll: *const fn (*anyopaque) anyerror![]Role,
        save: *const fn (*anyopaque, *Role) anyerror!void,
        delete: *const fn (*anyopaque, i32) anyerror!void,
        getRolePermissions: *const fn (*anyopaque, i32) anyerror![]Permission,
    };
    
    /// 根据ID查找角色
    pub fn findById(self: *Self, id: i32) !?Role {
        return self.vtable.findById(self.ptr, id);
    }
    
    /// 根据代码查找角色
    pub fn findByCode(self: *Self, code: []const u8) !?Role {
        return self.vtable.findByCode(self.ptr, code);
    }
    
    /// 根据用户ID查找角色列表
    pub fn findByUserId(self: *Self, user_id: i32) ![]Role {
        return self.vtable.findByUserId(self.ptr, user_id);
    }
    
    /// 查找所有角色
    pub fn findAll(self: *Self) ![]Role {
        return self.vtable.findAll(self.ptr);
    }
    
    /// 保存角色
    pub fn save(self: *Self, role: *Role) !void {
        return self.vtable.save(self.ptr, role);
    }
    
    /// 删除角色
    pub fn delete(self: *Self, id: i32) !void {
        return self.vtable.delete(self.ptr, id);
    }
    
    /// 获取角色的权限列表
    pub fn getRolePermissions(self: *Self, role_id: i32) ![]Permission {
        return self.vtable.getRolePermissions(self.ptr, role_id);
    }
};

/// 创建角色仓储接口
pub fn create(ptr: anytype, comptime vtable_impl: anytype) RoleRepository {
    return .{
        .ptr = ptr,
        .vtable = &vtable_impl,
    };
}
