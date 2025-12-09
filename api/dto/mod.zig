// DTO 命名空间 - 按功能分组
const std = @import("std");

// 用户相关 DTO
pub const user = struct {
    pub const Register = @import("user.dto.zig").Register;
    pub const Login = @import("user.dto.zig").Login;
};

// 菜单相关 DTO
pub const menu = struct {
    pub const Save = @import("menu.dto.zig").Save;
    pub const List = @import("menu.dto.zig").List;
};

// 通用 DTO
pub const common = struct {
    pub const Identity = struct { id: i32 = 0 };
    pub const Page = struct { page: u32 = 0, limit: u32 = 20, field: []const u8 = "", sort: []const u8 = "" };
    pub const Modify = struct { id: u32 = 0, field: []const u8 = "", value: ?[]const u8 = "" };
};
