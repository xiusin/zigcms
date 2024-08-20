pub const Category = struct {
    id: ?i32 = null,
    title: []const u8 = "",
    image: []const u8 = "",
    remark: []const u8 = "",
    status: i32 = 1,
    sort: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};
