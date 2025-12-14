//! CMS 字段管理实体
//!
//! 用于管理模型的自定义字段

/// CMS 字段实体
pub const CmsField = struct {
    /// 字段ID
    id: ?i32 = null,
    /// 所属模型ID
    model_id: i32 = 0,
    /// 字段名称（英文）
    field_name: []const u8 = "",
    /// 字段标签（显示名称）
    field_label: []const u8 = "",
    /// 字段类型
    field_type: []const u8 = "text",
    /// 数据库字段类型
    db_type: []const u8 = "VARCHAR(255)",
    /// 默认值
    default_value: []const u8 = "",
    /// 是否必填（0否 1是）
    is_required: i32 = 0,
    /// 是否在列表显示（0否 1是）
    is_list_show: i32 = 1,
    /// 是否可搜索（0否 1是）
    is_search: i32 = 0,
    /// 是否可排序（0否 1是）
    is_sort: i32 = 0,
    /// 是否唯一（0否 1是）
    is_unique: i32 = 0,
    /// 验证规则（JSON格式）
    validation: []const u8 = "{}",
    /// 字段选项（用于下拉框、单选等）
    options: []const u8 = "[]",
    /// 字段提示
    placeholder: []const u8 = "",
    /// 字段说明
    help_text: []const u8 = "",
    /// 最小长度
    min_length: i32 = 0,
    /// 最大长度
    max_length: i32 = 0,
    /// 正则验证
    pattern: []const u8 = "",
    /// 排序
    sort: i32 = 0,
    /// 是否启用（0禁用 1启用）
    status: i32 = 1,
    /// 字段分组
    field_group: []const u8 = "基本信息",
    /// 列宽（用于列表显示）
    column_width: i32 = 0,
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};

/// 字段类型枚举
pub const FieldType = enum {
    text, // 单行文本
    textarea, // 多行文本
    richtext, // 富文本编辑器
    number, // 数字
    decimal, // 小数
    select, // 下拉选择
    radio, // 单选
    checkbox, // 多选
    switch_type, // 开关
    date, // 日期
    datetime, // 日期时间
    time, // 时间
    image, // 图片
    images, // 多图
    file, // 文件
    files, // 多文件
    color, // 颜色选择器
    icon, // 图标选择器
    cascader, // 级联选择
    tree_select, // 树形选择
    relation, // 关联模型
    json, // JSON编辑器
    code, // 代码编辑器
    markdown, // Markdown编辑器
    hidden, // 隐藏字段

    pub fn name(self: FieldType) []const u8 {
        return switch (self) {
            .text => "单行文本",
            .textarea => "多行文本",
            .richtext => "富文本",
            .number => "数字",
            .decimal => "小数",
            .select => "下拉选择",
            .radio => "单选",
            .checkbox => "多选",
            .switch_type => "开关",
            .date => "日期",
            .datetime => "日期时间",
            .time => "时间",
            .image => "图片",
            .images => "多图",
            .file => "文件",
            .files => "多文件",
            .color => "颜色选择",
            .icon => "图标选择",
            .cascader => "级联选择",
            .tree_select => "树形选择",
            .relation => "关联模型",
            .json => "JSON",
            .code => "代码",
            .markdown => "Markdown",
            .hidden => "隐藏",
        };
    }

    pub fn dbType(self: FieldType) []const u8 {
        return switch (self) {
            .text => "VARCHAR(255)",
            .textarea, .richtext, .markdown => "TEXT",
            .number => "INT",
            .decimal => "DECIMAL(10,2)",
            .select, .radio => "VARCHAR(100)",
            .checkbox, .images, .files, .json => "TEXT",
            .switch_type => "TINYINT(1)",
            .date => "DATE",
            .datetime => "DATETIME",
            .time => "TIME",
            .image, .file => "VARCHAR(500)",
            .color => "VARCHAR(20)",
            .icon => "VARCHAR(50)",
            .cascader, .tree_select => "VARCHAR(500)",
            .relation => "INT",
            .code => "MEDIUMTEXT",
            .hidden => "VARCHAR(255)",
        };
    }
};
