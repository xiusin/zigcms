//! CMS 字段数据传输对象

const std = @import("std");

/// 字段创建 DTO
pub const CmsFieldCreateDto = struct {
    pub const validation = .{
        .field_name = "required|alpha_num|min:2|max:50",
        .field_label = "required|min:2|max:50",
    };

    model_id: i32,
    field_name: []const u8,
    field_label: []const u8,
    field_type: []const u8 = "text",
    db_type: []const u8 = "VARCHAR(255)",
    default_value: []const u8 = "",
    is_required: i32 = 0,
    is_list_show: i32 = 1,
    is_search: i32 = 0,
    is_sort: i32 = 0,
    is_unique: i32 = 0,
    validation_rules: []const u8 = "{}",
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
};

/// 字段更新 DTO
pub const CmsFieldUpdateDto = struct {
    pub const validation = .{
        .field_label = "required|min:2|max:50",
    };

    id: i32,
    model_id: i32,
    field_name: []const u8,
    field_label: []const u8,
    field_type: []const u8 = "text",
    db_type: []const u8 = "VARCHAR(255)",
    default_value: []const u8 = "",
    is_required: i32 = 0,
    is_list_show: i32 = 1,
    is_search: i32 = 0,
    is_sort: i32 = 0,
    is_unique: i32 = 0,
    validation_rules: []const u8 = "{}",
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
};

/// 字段排序 DTO
pub const CmsFieldSortDto = struct {
    id: i32,
    sort: i32,
};

/// 批量排序 DTO
pub const CmsFieldBatchSortDto = struct {
    items: []CmsFieldSortDto,
};
