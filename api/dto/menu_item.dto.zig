//! 菜单项数据传输对象

const std = @import("std");

/// 菜单项 DTO
pub const MenuItemDto = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    path: []const u8 = "",
    icon: []const u8 = "",
    parent_id: i32 = 0,
    sort: i32 = 0,
    status: i32 = 1,
    menu_type: i32 = 0,
    permission: []const u8 = "",
};
