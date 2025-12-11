//! 职位管理模型
//!
//! 企业职位/岗位信息实体

/// 职位实体
pub const Position = struct {
    /// 职位ID
    id: ?i32 = null,
    /// 职位名称
    name: []const u8 = "",
    /// 职位编码
    code: []const u8 = "",
    /// 所属部门ID
    department_id: ?i32 = null,
    /// 职级（1-10）
    level: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 职位描述
    description: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};
