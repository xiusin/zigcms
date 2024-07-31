pub const Admin = struct {
    pub const ingore_fields = [_][]const u8{"token"};
    id: i32 = 0,
    username: []const u8 = "",
    password: []const u8 = "",
    created_at: i64 = 0,
};
