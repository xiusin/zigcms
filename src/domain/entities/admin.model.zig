pub const Admin = struct {
    pub const ignore_fields = [_][]const u8{"token"};
    id: ?i32 = null,
    username: []const u8 = "",
    phone: []const u8 = "",
    email: []const u8 = "",
    password: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
};
