pub const Upload = struct {
    id: ?i32 = null,
    original_name: []const u8 = "",
    path: []const u8 = "",
    md5: []const u8 = "",
    ext: []const u8 = "",
    size: i32 = 0,
    upload_type: []const u8 = "local",
    url: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: i32 = 0,
};
