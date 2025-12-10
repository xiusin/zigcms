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
        };
    }
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
        };
    }
};
