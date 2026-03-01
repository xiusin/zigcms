//! 软删除（Soft Deletes）功能
//!
//! 提供类似 Laravel 的软删除功能，删除时只标记 deleted_at 字段，不物理删除数据。
//!
//! ## 使用示例
//!
//! ```zig
//! // 1. 模型定义（添加 deleted_at 字段和 soft_deletes 标记）
//! pub const User = struct {
//!     id: ?i32 = null,
//!     name: []const u8 = "",
//!     deleted_at: ?i64 = null,  // 软删除标记字段
//!     
//!     pub const soft_deletes = true;  // 启用软删除
//! };
//!
//! // 2. 软删除（设置 deleted_at）
//! try OrmUser.Delete(1);  // 软删除
//!
//! // 3. 物理删除
//! try OrmUser.ForceDelete(1);  // 真正删除
//!
//! // 4. 恢复软删除
//! try OrmUser.Restore(1);  // 恢复
//!
//! // 5. 查询时自动过滤已删除
//! var q = OrmUser.Query();
//! const users = try q.get();  // 自动添加 WHERE deleted_at IS NULL
//!
//! // 6. 包含已删除
//! var q = OrmUser.Query();
//! _ = q.withTrashed();
//! const users = try q.get();  // 包含已删除的记录
//!
//! // 7. 只查询已删除
//! var q = OrmUser.Query();
//! _ = q.onlyTrashed();
//! const users = try q.get();  // 只返回已删除的记录
//! ```

const std = @import("std");

/// 检查模型是否启用软删除
pub fn hasSoftDeletes(comptime T: type) bool {
    return @hasDecl(T, "soft_deletes") and T.soft_deletes == true;
}

/// 检查模型是否有 deleted_at 字段
pub fn hasDeletedAtField(comptime T: type) bool {
    const fields = std.meta.fields(T);
    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, "deleted_at")) {
            return true;
        }
    }
    return false;
}

/// 获取软删除字段名（默认 deleted_at）
pub fn getDeletedAtColumn(comptime T: type) []const u8 {
    if (@hasDecl(T, "deleted_at_column")) {
        return T.deleted_at_column;
    }
    return "deleted_at";
}

/// 软删除模式
pub const SoftDeleteMode = enum {
    /// 默认：排除已删除
    exclude_trashed,
    /// 包含已删除
    with_trashed,
    /// 只查询已删除
    only_trashed,
};
