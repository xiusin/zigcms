pub const Identity = struct { id: i32 = 0 };
pub const Page = struct { page: u32 = 0, limit: u32 = 20, field: []const u8 = "", sort: []const u8 = "" };
pub const Modify = struct { id: u32 = 0, field: []const u8 = "", value: ?[]const u8 = "" };

pub const User = @import("user.dto.zig");
pub const Menu = @import("menu.dto.zig");
