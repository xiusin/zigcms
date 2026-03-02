/// 系统字典模型
const std = @import("std");

/// 字典主表
pub const SysDict = struct {
    id: ?i32 = null,
    category_code: []const u8 = "",      // 分类编码
    category_name: []const u8 = "",      // 分类名称
    dict_name: []const u8 = "",          // 字典名称
    dict_code: []const u8 = "",          // 字典编码
    remark: []const u8 = "",             // 备注
    status: i32 = 1,                     // 状态 1启用 0禁用
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

/// 字典项表
pub const SysDictItem = struct {
    id: ?i32 = null,
    dict_id: i32 = 0,                    // 字典ID
    item_name: []const u8 = "",          // 字典项名称
    item_value: []const u8 = "",         // 字典项值
    sort: i32 = 0,                       // 排序
    status: i32 = 1,                     // 状态 1启用 0禁用
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};
