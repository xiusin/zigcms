pub const Identity = struct { id: i32 = 0 };
pub const Page = struct { page: u32 = 0, limit: u32 = 20 };

pub const User = @import("user.dto.zig");
pub const Menu = @import("menu.dto.zig");
