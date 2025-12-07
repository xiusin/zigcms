//! ORM 模型定义
//!
//! 使用 sql ORM 的 define 函数定义模型，提供 Laravel Eloquent 风格的 API。
//!
//! ## 使用示例
//!
//! ```zig
//! const orm_models = @import("models/orm_models.zig");
//!
//! // 初始化（设置默认数据库连接）
//! orm_models.init(&db);
//!
//! // 使用模型
//! const user = try orm_models.Admin.Find(1);
//! const articles = try orm_models.Article.Where("status", "=", 1).get();
//! ```

const std = @import("std");
const sql = @import("../services/sql/orm.zig");

// 导入原始模型结构体
const admin_model = @import("admin.model.zig");
const article_model = @import("article.model.zig");
const banner_model = @import("banner.model.zig");
const category_model = @import("category.model.zig");
const menu_model = @import("menu.model.zig");
const role_model = @import("role.model.zig");
const setting_model = @import("setting.model.zig");
const task_model = @import("task.model.zig");
const upload_model = @import("upload.model.zig");

// ============================================================================
// ORM 模型定义
// ============================================================================

/// 管理员模型
pub const Admin = sql.define(struct {
    pub const table_name = "zigcms.admin";
    pub const primary_key = "id";

    id: ?i32 = null,
    username: []const u8 = "",
    phone: []const u8 = "",
    email: []const u8 = "",
    password: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 文章模型
pub const Article = sql.define(struct {
    pub const table_name = "zigcms.article";
    pub const primary_key = "id";

    id: ?i32 = null,
    title: []const u8 = "",
    keyword: []const u8 = "",
    description: ?[]const u8 = "",
    content: ?[]const u8 = "",
    image_url: []const u8 = "",
    video_url: []const u8 = "",
    category_id: i32 = 0,
    article_type: []const u8 = "",
    comment_switch: i32 = 0,
    recomment_type: i32 = 0,
    tags: []const u8 = "",
    status: i32 = 0,
    sort: i32 = 0,
    view_count: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// Banner 模型
pub const Banner = sql.define(struct {
    pub const table_name = "zigcms.banner";
    pub const primary_key = "id";

    id: ?i32 = null,
    title: []const u8 = "",
    image_url: []const u8 = "",
    link_url: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 分类模型
pub const Category = sql.define(struct {
    pub const table_name = "zigcms.category";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    parent_id: i32 = 0,
    sort: i32 = 0,
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 菜单模型
pub const Menu = sql.define(struct {
    pub const table_name = "zigcms.menu";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    parent_id: i32 = 0,
    url: []const u8 = "",
    icon: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 角色模型
pub const Role = sql.define(struct {
    pub const table_name = "zigcms.role";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    description: []const u8 = "",
    permissions: []const u8 = "",
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 设置模型
pub const Setting = sql.define(struct {
    pub const table_name = "zigcms.setting";
    pub const primary_key = "key";

    key: []const u8 = "",
    value: []const u8 = "",
});

/// 任务模型
pub const Task = sql.define(struct {
    pub const table_name = "zigcms.task";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    cron: []const u8 = "",
    command: []const u8 = "",
    status: i32 = 0,
    last_run: ?i64 = null,
    next_run: ?i64 = null,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
});

/// 上传文件模型
pub const Upload = sql.define(struct {
    pub const table_name = "zigcms.upload";
    pub const primary_key = "id";

    id: ?i32 = null,
    original_name: []const u8 = "",
    path: []const u8 = "",
    md5: []const u8 = "",
    ext: []const u8 = "",
    size: i32 = 0,
    upload_type: i32 = 0,
    url: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

// ============================================================================
// 初始化函数
// ============================================================================

/// 初始化所有 ORM 模型（设置默认数据库连接）
pub fn init(db: *sql.Database) void {
    Admin.use(db);
    Article.use(db);
    Banner.use(db);
    Category.use(db);
    Menu.use(db);
    Role.use(db);
    Setting.use(db);
    Task.use(db);
    Upload.use(db);
}

/// 获取 Database 类型（便于外部使用）
pub const Database = sql.Database;
