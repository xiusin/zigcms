//! ecom-admin-dashboard 对接模型
//!
//! 用于承载 sys/biz/op 新表结构，供通用 CRUD 控制器直接复用。

/// 系统部门模型
pub const SysDept = struct {
    id: ?i32 = null,
    parent_id: i32 = 0,
    dept_name: []const u8 = "",
    dept_code: []const u8 = "",
    leader: []const u8 = "",
    phone: []const u8 = "",
    email: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 会员标签模型
pub const BizMemberTag = struct {
    id: ?i32 = null,
    tag_name: []const u8 = "",
    color: []const u8 = "blue",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
};

/// 会员标签关联模型
pub const BizMemberTagRel = struct {
    id: ?i32 = null,
    member_id: i32 = 0,
    tag_id: i32 = 0,
    created_at: ?i64 = null,
};

/// 会员余额变更日志模型
pub const BizMemberBalanceLog = struct {
    id: ?i32 = null,
    member_id: i32 = 0,
    change_type: []const u8 = "add",
    amount: f64 = 0,
    payment_method: []const u8 = "",
    remark: []const u8 = "",
    operator_id: ?i32 = null,
    created_at: ?i64 = null,
};

/// 会员积分变更日志模型
pub const BizMemberPointLog = struct {
    id: ?i32 = null,
    member_id: i32 = 0,
    change_type: []const u8 = "add",
    points: i32 = 0,
    remark: []const u8 = "",
    operator_id: ?i32 = null,
    created_at: ?i64 = null,
};

/// 角色菜单关联模型
pub const SysRoleMenu = struct {
    id: ?i32 = null,
    role_id: i32 = 0,
    menu_id: i32 = 0,
    created_at: ?i64 = null,
};

/// 角色权限关联模型
pub const SysRolePermission = struct {
    id: ?i32 = null,
    role_id: i32 = 0,
    permission_id: i32 = 0,
    created_at: ?i64 = null,
};

/// 系统职位模型
pub const SysPosition = struct {
    id: ?i32 = null,
    dept_id: i32 = 0,
    position_name: []const u8 = "",
    position_code: []const u8 = "",
    description: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 系统角色模型
pub const SysRole = struct {
    pub const ignore_fields = [_][]const u8{"menus"};

    id: ?i32 = null,
    role_name: []const u8 = "",
    role_key: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    remark: []const u8 = "",
    data_scope: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    // 关联数据字段（可选）
    menus: ?[]SysMenu = null,

    // 定义关系
    pub const relations = .{
        .menus = .{
            .type = .many_to_many,
            .model = SysMenu,
            .through = "sys_role_menu",
            .foreign_key = "role_id",
            .related_key = "menu_id",
        },
    };
};

/// 系统菜单模型
pub const SysMenu = struct {
    id: ?i32 = null,
    pid: i32 = 0,
    menu_name: []const u8 = "",
    menu_type: i32 = 2,
    icon: []const u8 = "",
    path: []const u8 = "",
    component: []const u8 = "",
    perms: []const u8 = "",
    sort: i32 = 0,
    is_hide: i32 = 0,
    is_cache: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 系统管理员模型
pub const SysAdmin = struct {
    id: ?i32 = null,
    username: []const u8 = "",
    nickname: []const u8 = "",
    password_hash: []const u8 = "",
    mobile: []const u8 = "",
    email: []const u8 = "",
    avatar: []const u8 = "",
    gender: i32 = 0,
    dept_id: ?i32 = null,
    position_id: ?i32 = null,
    status: i32 = 1,
    remark: []const u8 = "",
    last_login: ?i64 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 系统配置模型
pub const SysConfig = struct {
    id: ?i32 = null,
    config_name: []const u8 = "",
    config_key: []const u8 = "",
    config_group: []const u8 = "basic",
    config_type: []const u8 = "text",
    config_value: []const u8 = "",
    description: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 系统字典模型
pub const SysDict = struct {
    id: ?i32 = null,
    category_code: []const u8 = "",
    dict_name: []const u8 = "",
    dict_code: []const u8 = "",
    remark: []const u8 = "",
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 系统字典项模型
pub const SysDictItem = struct {
    id: ?i32 = null,
    dict_id: i32 = 0,
    item_name: []const u8 = "",
    item_value: []const u8 = "",
    sort: i32 = 0,
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 业务会员模型
pub const BizMember = struct {
    id: ?i32 = null,
    user_id: ?i32 = null,
    username: []const u8 = "",
    nickname: []const u8 = "",
    mobile: []const u8 = "",
    email: []const u8 = "",
    avatar: []const u8 = "",
    gender: i32 = 0,
    level: i32 = 1,
    balance: f64 = 0,
    total_consume: f64 = 0,
    total_order: i32 = 0,
    points: i32 = 0,
    status: i32 = 1,
    source: []const u8 = "PC",
    last_login: ?i64 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 任务模型
pub const OpTask = struct {
    id: ?i32 = null,
    task_name: []const u8 = "",
    task_type: i32 = 1,
    group_name: []const u8 = "default",
    target: []const u8 = "",
    params_json: []const u8 = "{}",
    cron: []const u8 = "",
    delay_seconds: i32 = 0,
    timeout_seconds: i32 = 300,
    retry: i32 = 0,
    description: []const u8 = "",
    status: i32 = 1,
    last_run_time: ?i64 = null,
    next_run_time: ?i64 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 任务执行日志模型
pub const OpTaskLog = struct {
    id: ?i32 = null,
    task_id: i32 = 0,
    task_name: []const u8 = "",
    start_time: ?i64 = null,
    end_time: ?i64 = null,
    duration_ms: i32 = 0,
    status: []const u8 = "success",
    result: []const u8 = "",
    error_message: []const u8 = "",
    created_at: ?i64 = null,
};

/// 任务调度日志模型
pub const OpTaskScheduleLog = struct {
    id: ?i32 = null,
    task_id: i32 = 0,
    task_name: []const u8 = "",
    schedule_time: ?i64 = null,
    execute_time: ?i64 = null,
    status: []const u8 = "waiting",
    created_at: ?i64 = null,
};

/// 管理员角色分配审计日志模型
pub const SysAdminRoleAudit = struct {
    id: ?i32 = null,
    admin_id: i32 = 0,
    operator_id: i32 = 0,
    operator_name: []const u8 = "",
    old_role_ids: []const u8 = "",
    new_role_ids: []const u8 = "",
    request_ip: []const u8 = "",
    created_at: ?i64 = null,
};

/// 通用 CRUD 类型别名（用于自动推导表名）
pub const sys_dept = SysDept;
pub const sys_position = SysPosition;
pub const sys_role = SysRole;
pub const sys_menu = SysMenu;
pub const sys_admin = SysAdmin;
pub const sys_config = SysConfig;
pub const sys_dict = SysDict;
pub const sys_dict_item = SysDictItem;
pub const sys_role_menu = SysRoleMenu;
pub const sys_role_permission = SysRolePermission;
pub const biz_member = BizMember;
pub const biz_member_tag = BizMemberTag;
pub const biz_member_tag_rel = BizMemberTagRel;
pub const biz_member_balance_log = BizMemberBalanceLog;
pub const biz_member_point_log = BizMemberPointLog;
pub const op_task = OpTask;
pub const op_task_log = OpTaskLog;
pub const op_task_schedule_log = OpTaskScheduleLog;
pub const sys_admin_role_audit = SysAdminRoleAudit;
