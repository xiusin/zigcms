pub const Menu = struct {
    id: i32 = 0,
    name: []const u8 = "",
    parent_id: i32 = 0,
    url: []const u8 = "",
    icon: []const u8 = "",
    authority: []const u8 = "",
    listorder: i64 = 0,
    is_menu: i32 = 0,
    checked: i32 = 0,
    create_time: i64 = 0,
    update_time: i64 = 0,
};
