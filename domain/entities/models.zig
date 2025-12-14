//! 领域实体入口 - 统一导出所有业务实体
//!
//! 遏循领域驱动设计，这些实体包含业务规则和状态

const std = @import("std");

// 导入所有领域实体
pub const Admin = @import("admin.model.zig").Admin;
pub const Setting = @import("setting.model.zig").Setting;
pub const Article = @import("article.model.zig").Article;
pub const Banner = @import("banner.model.zig").Banner;
pub const Upload = @import("upload.model.zig").Upload;
pub const Category = @import("category.model.zig").Category;
pub const Task = @import("task.model.zig").Task;
pub const Role = @import("role.model.zig").Role;
pub const Dict = @import("dict.model.zig").Dict;
pub const Department = @import("department.model.zig").Department;
pub const Employee = @import("employee.model.zig").Employee;
pub const Position = @import("position.model.zig").Position;
pub const CmsModel = @import("cms_model.model.zig").CmsModel;
pub const CmsField = @import("cms_field.model.zig").CmsField;
pub const Document = @import("document.model.zig").Document;
pub const MaterialCategory = @import("material_category.model.zig").MaterialCategory;
pub const Material = @import("material.model.zig").Material;
pub const FriendLink = @import("friend_link.model.zig").FriendLink;
pub const MemberGroup = @import("member_group.model.zig").MemberGroup;
pub const Member = @import("member.model.zig").Member;

/// 实体类型枚举，用于泛型操作
pub const EntityType = enum {
    admin,
    setting,
    article,
    banner,
    upload,
    category,
    task,
    role,
    dict,
    department,
    employee,
    position,
    cms_model,
    cms_field,
    document,
    material_category,
    material,
    friend_link,
    member_group,
    member,
};

/// 通用实体接口
pub const EntityInterface = struct {
    /// 获取实体表名
    pub fn getTableName(entity_type: EntityType) []const u8 {
        return switch (entity_type) {
            .admin => "admins",
            .setting => "settings",
            .article => "articles",
            .banner => "banners",
            .upload => "uploads",
            .category => "categories",
            .task => "tasks",
            .role => "roles",
            .dict => "dicts",
            .department => "departments",
            .employee => "employees",
            .position => "positions",
            .cms_model => "cms_models",
            .cms_field => "cms_fields",
            .document => "documents",
            .material_category => "material_categories",
            .material => "materials",
            .friend_link => "friend_links",
            .member_group => "member_groups",
            .member => "members",
        };
    }
};
