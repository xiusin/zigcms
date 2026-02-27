//! 部门管理模型
//!
//! 企业组织架构中的部门实体

/// 部门实体
pub const Department = struct {
    /// 部门ID
    id: ?i32 = null,
    /// 部门名称
    name: []const u8 = "",
    /// 部门编码
    code: []const u8 = "",
    /// 父部门ID（0表示顶级部门）
    parent_id: i32 = 0,
    /// 部门负责人ID
    leader_id: ?i32 = null,
    /// 联系电话
    phone: []const u8 = "",
    /// 联系邮箱
    email: []const u8 = "",
    /// 排序
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};
