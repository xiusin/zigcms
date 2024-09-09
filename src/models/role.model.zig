pub const Role = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    image_url: []const u8 = "",
    status: i32 = 0,
    sort: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
};
