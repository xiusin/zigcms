//! CMS 模型数据传输对象

const std = @import("std");

/// 模型创建 DTO
pub const CmsModelCreateDto = struct {
    pub const validation = .{
        .name = "required|min:2|max:50",
        .table_name_field = "required|alpha_num|min:2|max:50",
    };

    name: []const u8,
    table_name_field: []const u8 = "",
    description: []const u8 = "",
    model_type: i32 = 2,
    status: i32 = 1,
    sort: i32 = 0,
    icon: []const u8 = "",
    list_template: []const u8 = "",
    detail_template: []const u8 = "",
    form_template: []const u8 = "",
    list_fields: []const u8 = "[]",
    search_fields: []const u8 = "[]",
    order_field: []const u8 = "sort",
    order_direction: []const u8 = "asc",
    remark: []const u8 = "",
};

/// 模型更新 DTO
pub const CmsModelUpdateDto = struct {
    pub const validation = .{
        .name = "required|min:2|max:50",
    };

    id: i32,
    name: []const u8,
    table_name_field: []const u8 = "",
    description: []const u8 = "",
    model_type: i32 = 2,
    status: i32 = 1,
    sort: i32 = 0,
    icon: []const u8 = "",
    list_template: []const u8 = "",
    detail_template: []const u8 = "",
    form_template: []const u8 = "",
    list_fields: []const u8 = "[]",
    search_fields: []const u8 = "[]",
    order_field: []const u8 = "sort",
    order_direction: []const u8 = "asc",
    remark: []const u8 = "",
};

/// 模型响应 DTO
pub const CmsModelResponseDto = struct {
    id: i32,
    name: []const u8,
    table_name_field: []const u8,
    description: []const u8,
    model_type: i32,
    status: i32,
    sort: i32,
    icon: []const u8,
    is_system: i32,
    list_template: []const u8,
    detail_template: []const u8,
    form_template: []const u8,
    list_fields: []const u8,
    search_fields: []const u8,
    order_field: []const u8,
    order_direction: []const u8,
    remark: []const u8,
    create_time: ?i64,
    update_time: ?i64,
};
