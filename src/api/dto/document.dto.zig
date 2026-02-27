//! 文档数据传输对象

const std = @import("std");

/// 文档创建 DTO
pub const DocumentCreateDto = struct {
    pub const validation = .{
        .title = "required|min:2|max:200",
    };

    model_id: i32,
    category_id: i32 = 0,
    title: []const u8,
    sub_title: []const u8 = "",
    keywords: []const u8 = "",
    description: []const u8 = "",
    thumb: []const u8 = "",
    author: []const u8 = "",
    source: []const u8 = "",
    content: []const u8 = "",
    attachments: []const u8 = "[]",
    extra_fields: []const u8 = "{}",
    sort: i32 = 0,
    status: i32 = 0,
    is_recommend: i32 = 0,
    is_top: i32 = 0,
    is_hot: i32 = 0,
    url_alias: []const u8 = "",
    external_link: []const u8 = "",
    template: []const u8 = "",
    remark: []const u8 = "",
};

/// 文档更新 DTO
pub const DocumentUpdateDto = struct {
    pub const validation = .{
        .title = "required|min:2|max:200",
    };

    id: i32,
    model_id: i32,
    category_id: i32 = 0,
    title: []const u8,
    sub_title: []const u8 = "",
    keywords: []const u8 = "",
    description: []const u8 = "",
    thumb: []const u8 = "",
    author: []const u8 = "",
    source: []const u8 = "",
    content: []const u8 = "",
    attachments: []const u8 = "[]",
    extra_fields: []const u8 = "{}",
    sort: i32 = 0,
    status: i32 = 0,
    is_recommend: i32 = 0,
    is_top: i32 = 0,
    is_hot: i32 = 0,
    url_alias: []const u8 = "",
    external_link: []const u8 = "",
    template: []const u8 = "",
    remark: []const u8 = "",
};

/// 批量操作 DTO
pub const DocumentBatchDto = struct {
    ids: []i32,
    status: i32 = 1,
};

/// 文档列表查询 DTO
pub const DocumentQueryDto = struct {
    page: i32 = 1,
    limit: i32 = 10,
    model_id: i32 = 0,
    category_id: i32 = 0,
    status: i32 = -1,
    keyword: []const u8 = "",
    sort_field: []const u8 = "id",
    sort_dir: []const u8 = "desc",
};
