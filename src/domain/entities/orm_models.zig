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
const sql = @import("../../application/services/sql/orm.zig");

// 统一从领域实体入口导入，避免逐文件依赖缺失
const models = @import("mod.zig");

// ============================================================================
// ORM 模型定义
// ============================================================================

/// 管理员模型
pub const Admin = sql.define(struct {
    pub const table_name = "sys_admin";
    pub const primary_key = "id";

    id: ?i32 = null,
    username: []const u8 = "",
    nickname: []const u8 = "",
    password_hash: []const u8 = "",
    mobile: []const u8 = "",
    email: []const u8 = "",
    avatar: []const u8 = "",
    gender: i32 = 0,
    dept_id: i32 = 0,
    position_id: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
    last_login: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
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
    name: []const u8 = "",
    status: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// 分类模型
pub const Category = sql.define(struct {
    pub const table_name = "zigcms.category";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    code: []const u8 = "",
    parent_id: i32 = 0,
    category_type: []const u8 = "article",
    description: []const u8 = "",
    cover_image: []const u8 = "",
    icon: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    seo_title: []const u8 = "",
    seo_keywords: []const u8 = "",
    seo_description: []const u8 = "",
    views: i32 = 0,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
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
    code: []const u8 = "",
    description: []const u8 = "",
    permissions: []const u8 = "[]",
    data_scope: i32 = 1,
    sort: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// 部门模型
pub const Department = sql.define(struct {
    pub const table_name = "zigcms.department";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    code: []const u8 = "",
    parent_id: i32 = 0,
    leader_id: ?i32 = null,
    phone: []const u8 = "",
    email: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// 员工模型
pub const Employee = sql.define(struct {
    pub const table_name = "zigcms.employee";
    pub const primary_key = "id";

    id: ?i32 = null,
    employee_no: []const u8 = "",
    name: []const u8 = "",
    gender: i32 = 0,
    phone: []const u8 = "",
    email: []const u8 = "",
    id_card: []const u8 = "",
    department_id: ?i32 = null,
    position_id: ?i32 = null,
    role_id: ?i32 = null,
    leader_id: ?i32 = null,
    hire_date: ?i64 = null,
    avatar: []const u8 = "",
    status: i32 = 1,
    sort: i32 = 0,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// 职位模型（使用 sys_position 表）
pub const Position = sql.define(struct {
    pub const table_name = "sys_position";
    pub const primary_key = "id";

    id: ?i32 = null,
    dept_id: i32 = 0,
    position_name: []const u8 = "",
    position_code: []const u8 = "",
    description: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
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

/// CMS 模型管理
pub const CmsModel = sql.define(struct {
    pub const table_name = "zigcms.cms_model";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    table_name_field: []const u8 = "",
    description: []const u8 = "",
    model_type: i32 = 2,
    status: i32 = 1,
    sort: i32 = 0,
    icon: []const u8 = "",
    is_system: i32 = 0,
    list_template: []const u8 = "",
    detail_template: []const u8 = "",
    form_template: []const u8 = "",
    list_fields: []const u8 = "[]",
    search_fields: []const u8 = "[]",
    order_field: []const u8 = "sort",
    order_direction: []const u8 = "asc",
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// CMS 字段管理
pub const CmsField = sql.define(struct {
    pub const table_name = "zigcms.cms_field";
    pub const primary_key = "id";

    id: ?i32 = null,
    model_id: i32 = 0,
    field_name: []const u8 = "",
    field_label: []const u8 = "",
    field_type: []const u8 = "text",
    db_type: []const u8 = "VARCHAR(255)",
    default_value: []const u8 = "",
    is_required: i32 = 0,
    is_list_show: i32 = 1,
    is_search: i32 = 0,
    is_sort: i32 = 0,
    is_unique: i32 = 0,
    validation: []const u8 = "{}",
    options: []const u8 = "[]",
    placeholder: []const u8 = "",
    help_text: []const u8 = "",
    min_length: i32 = 0,
    max_length: i32 = 0,
    pattern: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    field_group: []const u8 = "基本信息",
    column_width: i32 = 0,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
});

/// 测试报告模型
pub const TestReport = sql.define(struct {
    pub const table_name = "test_reports";
    pub const primary_key = "id";

    id: ?i32 = null,
    name: []const u8 = "",
    test_type: []const u8 = "unit",
    status: []const u8 = "pending",
    total_cases: i32 = 0,
    passed_cases: i32 = 0,
    failed_cases: i32 = 0,
    skipped_cases: i32 = 0,
    pass_rate: i32 = 0,
    duration_ms: i32 = 0,
    error_message: []const u8 = "",
    stack_trace: []const u8 = "",
    test_target: []const u8 = "",
    triggered_by: []const u8 = "manual",
    environment: []const u8 = "{}",
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
});

/// Bug 分析模型
pub const BugAnalysis = sql.define(struct {
    pub const table_name = "bug_analyses";
    pub const primary_key = "id";

    id: ?i32 = null,
    title: []const u8 = "",
    description: []const u8 = "",
    bug_type: []const u8 = "unknown",
    severity: []const u8 = "medium",
    priority: []const u8 = "medium",
    status: []const u8 = "pending",
    issue_location: []const u8 = "unknown",
    file_path: []const u8 = "",
    line_number: i32 = 0,
    root_cause: []const u8 = "",
    suggested_fix: []const u8 = "",
    confidence_score: i32 = 0,
    auto_fix_attempted: i32 = 0,
    auto_fix_result: []const u8 = "{}",
    test_report_id: ?i32 = null,
    feedback_id: ?i32 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
});

/// 文档管理
pub const Document = sql.define(struct {
    pub const table_name = "zigcms.document";
    pub const primary_key = "id";

    id: ?i32 = null,
    model_id: i32 = 0,
    category_id: i32 = 0,
    title: []const u8 = "",
    sub_title: []const u8 = "",
    keywords: []const u8 = "",
    description: []const u8 = "",
    thumb: []const u8 = "",
    author: []const u8 = "",
    source: []const u8 = "",
    content: []const u8 = "",
    attachments: []const u8 = "[]",
    extra_fields: []const u8 = "{}",
    view_count: i32 = 0,
    like_count: i32 = 0,
    comment_count: i32 = 0,
    sort: i32 = 0,
    status: i32 = 0,
    is_recommend: i32 = 0,
    is_top: i32 = 0,
    is_hot: i32 = 0,
    publish_time: ?i64 = null,
    creator_id: i32 = 0,
    updater_id: i32 = 0,
    url_alias: []const u8 = "",
    external_link: []const u8 = "",
    template: []const u8 = "",
    remark: []const u8 = "",
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
    Menu.use(db);
    Role.use(db);
    Setting.use(db);
    Department.use(db);
    Position.use(db);
    TestReport.use(db);
    BugAnalysis.use(db);
}

/// 获取 Database 类型（便于外部使用）
pub const Database = sql.Database;

/// 获取 Migrator 类型
pub const Migrator = sql.Migrator;

/// 获取方言类型
pub const Dialect = sql.Dialect;

// ============================================================================
// 数据库迁移
// ============================================================================

/// 所有模型列表（用于批量操作）
pub const AllModels = .{
    Admin,
    Menu,
    Role,
    Setting,
    Task,
    Upload,
    Department,
    Employee,
    Position,
    TestReport,
    BugAnalysis,
};

/// 迁移所有表（创建表）
pub fn migrate(db: *sql.Database) !void {
    try Migrator.createAll(db, AllModels);
}

/// 回滚所有表（删除表，按依赖倒序）
pub fn rollback(db: *sql.Database) !void {
    try Migrator.dropAll(db, .{
        BugAnalysis,
        TestReport,
        Employee,
        Position,
        Department,
        Upload,
        Task,
        Setting,
        Role,
        Menu,
        Admin,
    });
}

/// 刷新所有表（删除后重建）
pub fn refresh(db: *sql.Database) !void {
    try rollback(db);
    try migrate(db);
}

/// 打印所有建表语句
pub fn printMigrationSql(comptime dialect: Dialect) void {
    Migrator.printSql(dialect, AllModels);
}

// ============================================================================
// 关系定义
// ============================================================================

const relations = @import("../../application/services/sql/relations.zig");

/// 模型关系定义
/// 定义各模型之间的关联关系，便于业务层调用
pub const Relations = struct {
    /// 部门关系
    pub const DepartmentRelations = struct {
        /// 获取部门下的所有员工
        pub fn employees(department_id: i32) ![]Employee.Model {
            return relations.hasMany(Employee, department_id, "department_id");
        }

        /// 获取部门下的有效员工
        pub fn activeEmployees(department_id: i32) ![]Employee.Model {
            return relations.hasManyActive(Employee, department_id, "department_id");
        }

        /// 获取部门下的所有职位
        pub fn positions(department_id: i32) ![]Position.Model {
            return relations.hasMany(Position, department_id, "department_id");
        }

        /// 获取子部门
        pub fn children(parent_id: i32) ![]Department.Model {
            return relations.hasMany(Department, parent_id, "parent_id");
        }

        /// 获取父部门
        pub fn parent(parent_id: ?i32) !?Department.Model {
            return relations.belongsTo(Department, parent_id);
        }

        /// 获取部门负责人（员工）
        pub fn leader(leader_id: ?i32) !?Employee.Model {
            return relations.belongsTo(Employee, leader_id);
        }
    };

    /// 员工关系
    pub const EmployeeRelations = struct {
        /// 获取员工所属部门
        pub fn department(department_id: ?i32) !?Department.Model {
            return relations.belongsTo(Department, department_id);
        }

        /// 获取员工职位
        pub fn position(position_id: ?i32) !?Position.Model {
            return relations.belongsTo(Position, position_id);
        }

        /// 获取员工角色
        pub fn role(role_id: ?i32) !?Role.Model {
            return relations.belongsTo(Role, role_id);
        }

        /// 获取员工的直属领导
        pub fn leader(leader_id: ?i32) !?Employee.Model {
            return relations.belongsTo(Employee, leader_id);
        }

        /// 获取员工的下属
        pub fn subordinates(employee_id: i32) ![]Employee.Model {
            return relations.hasMany(Employee, employee_id, "leader_id");
        }
    };

    /// 职位关系
    pub const PositionRelations = struct {
        /// 获取职位所属部门
        pub fn department(department_id: ?i32) !?Department.Model {
            return relations.belongsTo(Department, department_id);
        }

        /// 获取该职位的所有员工
        pub fn employees(position_id: i32) ![]Employee.Model {
            return relations.hasMany(Employee, position_id, "position_id");
        }
    };

    /// 角色关系
    pub const RoleRelations = struct {
        /// 获取该角色的所有员工
        pub fn employees(role_id: i32) ![]Employee.Model {
            return relations.hasMany(Employee, role_id, "role_id");
        }

        /// 获取角色的有效员工
        pub fn activeEmployees(role_id: i32) ![]Employee.Model {
            return relations.hasManyActive(Employee, role_id, "role_id");
        }
    };
};
