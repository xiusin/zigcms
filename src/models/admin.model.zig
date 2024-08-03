pub const Admin = struct {
    pub const ingore_fields = [_][]const u8{"token"};
    id: ?i32 = null,
    username: []const u8 = "",
    phone: []const u8 = "",
    email: []const u8 = "",
    password: []const u8 = "",
    created_at: i64 = 0,
};
