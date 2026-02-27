//! 角色管理模型
//!
//! 系统角色权限实体

/// 角色实体
pub const Role = struct {
    /// 角色ID
    id: ?i32 = null,
    /// 角色名称
    name: []const u8 = "",
    /// 角色编码
    code: []const u8 = "",
    /// 角色描述
    description: []const u8 = "",
    /// 权限列表（JSON格式）
    permissions: []const u8 = "[]",
    /// 数据权限范围（1全部 2自定义 3本部门 4本部门及以下 5仅本人）
    data_scope: i32 = 1,
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
