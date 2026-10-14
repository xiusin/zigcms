const crud = @import("crud.controller.zig");

/// 兼容旧引用的通用控制器。
pub fn Generic(comptime T: type, comptime schema: []const u8) type {
    return crud.Crud(T, schema);
}
