//! 领域实体入口 - 统一导出所有业务实体
//!
//! 遏循领域驱动设计，这些实体包含业务规则和状态

const std = @import("std");

// 导入当前存在的领域实体
pub const Admin = @import("admin.model.zig").Admin;
pub const Setting = @import("setting.model.zig").Setting;
pub const Upload = @import("upload.model.zig").Upload;
pub const Task = @import("task.model.zig").Task;
pub const Role = @import("role.model.zig").Role;
pub const Dict = @import("dict.model.zig").Dict;
pub const Position = @import("position.model.zig").Position;
pub const Menu = @import("menu.model.zig").Menu;
pub const User = @import("user.model.zig").User;

// ecom-admin-dashboard 对接模型（sys/biz/op 新表）
pub const integration = @import("integration_models.zig");
pub const SysDept = integration.SysDept;
pub const SysPosition = integration.SysPosition;
pub const SysRole = integration.SysRole;
pub const SysMenu = integration.SysMenu;
pub const SysAdmin = integration.SysAdmin;
pub const SysConfig = integration.SysConfig;
pub const SysDict = integration.SysDict;
pub const SysDictItem = integration.SysDictItem;
pub const BizMember = integration.BizMember;
pub const OpTask = integration.OpTask;
pub const sys_dept = integration.sys_dept;
pub const sys_position = integration.sys_position;
pub const sys_role = integration.sys_role;
pub const sys_menu = integration.sys_menu;
pub const sys_admin = integration.sys_admin;
pub const sys_config = integration.sys_config;
pub const sys_dict = integration.sys_dict;
pub const sys_dict_item = integration.sys_dict_item;
pub const biz_member = integration.biz_member;
pub const op_task = integration.op_task;

/// 实体类型枚举，用于泛型操作
pub const EntityType = enum {
    admin,
    setting,
    upload,
    task,
    role,
    dict,
    position,
    menu,
    user,
};

/// 通用实体接口
pub const EntityInterface = struct {
    /// 获取实体表名
    pub fn getTableName(entity_type: EntityType) []const u8 {
        return switch (entity_type) {
            .admin => "admins",
            .setting => "settings",
            .upload => "uploads",
            .task => "tasks",
            .role => "roles",
            .dict => "dicts",
            .position => "positions",
            .menu => "menus",
            .user => "users",
        };
    }
};
