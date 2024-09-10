pub const Role = struct {
    id: ?i32 = null,
    role_name: []const u8 = "",
    remark: []const u8 = "",
    sort: i32 = 0,
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
};
