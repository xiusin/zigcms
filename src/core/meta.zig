//! 编译时反射工具
//!
//! Zig 0.17 的 `@typeInfo` 将字段拆分为 `field_names` / `field_types` 两个平行数组。
//! 本模块将它们重新组装为 `{ name, type }` 字段数组，便于按字段名/类型遍历。
//!
//! ## 使用示例
//! ```zig
//! const meta = @import("../core/meta.zig");
//! inline for (meta.fields(MyStruct)) |field| {
//!     _ = @field(instance, field.name);
//! }
//! ```

const std = @import("std");

/// 兼容旧 `std.meta.Fields` 用法的字段描述
pub const Field = struct {
    name: [:0]const u8,
    type: type,
    default_value_ptr: ?*const anyopaque = null,
};

/// `T` 的字段数组类型
pub fn Fields(comptime T: type) type {
    const info = @typeInfo(T).@"struct";
    return [info.field_names.len]Field;
}

/// 获取 `T` 的全部字段（name + type + default），须在编译期调用
pub fn fields(comptime T: type) Fields(T) {
    const info = @typeInfo(T).@"struct";
    var result: Fields(T) = undefined;
    inline for (info.field_names, info.field_types, info.field_attrs, 0..) |n, t, a, i| {
        result[i] = .{ .name = n, .type = t, .default_value_ptr = a.default_value_ptr };
    }
    return result;
}
