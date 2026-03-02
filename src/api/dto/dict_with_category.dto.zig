/// 带分类名称的字典 DTO
const std = @import("std");

/// 字典列表响应（包含分类名称）
pub const DictWithCategory = struct {
    id: ?i32 = null,
    category_code: []const u8 = "",
    category_name: []const u8 = "",
    dict_name: []const u8 = "",
    dict_code: []const u8 = "",
    remark: []const u8 = "",
    status: i32 = 1,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};
