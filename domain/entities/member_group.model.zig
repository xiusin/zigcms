//! 会员分组模型
//!
//! 系统会员分组实体，用于会员等级和权限管理

/// 会员分组实体
pub const MemberGroup = struct {
    /// 分组ID
    id: ?i32 = null,
    /// 分组名称
    name: []const u8 = "",
    /// 分组编码（唯一标识）
    code: []const u8 = "",
    /// 分组描述
    description: []const u8 = "",
    /// 分组图标
    icon: []const u8 = "",
    /// 权限列表（JSON格式）
    permissions: []const u8 = "[]",
    /// 积分要求
    points_required: i32 = 0,
    /// 折扣率（0-100，100为不打折）
    discount_rate: i32 = 100,
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否默认分组
    is_default: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};
