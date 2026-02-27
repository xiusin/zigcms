//! CMS 模型管理实体
//!
//! 用于管理动态内容模型（类似 pinecms 的模型管理）

/// CMS 模型实体
pub const CmsModel = struct {
    /// 模型ID
    id: ?i32 = null,
    /// 模型名称
    name: []const u8 = "",
    /// 模型标识（英文，用于表名）
    table_name: []const u8 = "",
    /// 模型描述
    description: []const u8 = "",
    /// 模型类型（1单页 2列表 3封面）
    model_type: i32 = 2,
    /// 是否启用（0禁用 1启用）
    status: i32 = 1,
    /// 排序
    sort: i32 = 0,
    /// 图标
    icon: []const u8 = "",
    /// 是否系统内置（0否 1是）
    is_system: i32 = 0,
    /// 列表模板
    list_template: []const u8 = "",
    /// 详情模板
    detail_template: []const u8 = "",
    /// 表单模板
    form_template: []const u8 = "",
    /// 列表显示字段（JSON数组）
    list_fields: []const u8 = "[]",
    /// 搜索字段（JSON数组）
    search_fields: []const u8 = "[]",
    /// 排序字段
    order_field: []const u8 = "sort",
    /// 排序方向
    order_direction: []const u8 = "asc",
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};

/// 模型类型枚举
pub const ModelType = enum(i32) {
    single_page = 1, // 单页
    list = 2, // 列表
    cover = 3, // 封面

    pub fn name(self: ModelType) []const u8 {
        return switch (self) {
            .single_page => "单页",
            .list => "列表",
            .cover => "封面",
        };
    }
};
