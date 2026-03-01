//! 查询作用域（Query Scopes）功能
//!
//! 提供可复用的查询条件，类似 Laravel 的 Query Scopes。
//!
//! ## 使用示例
//!
//! ```zig
//! // 1. 模型定义（添加作用域）
//! pub const User = struct {
//!     id: ?i32 = null,
//!     name: []const u8 = "",
//!     status: i32 = 1,
//!     created_at: ?i64 = null,
//!     
//!     // 定义作用域
//!     pub const scopes = .{
//!         // 活跃用户
//!         .active = struct {
//!             pub fn apply(query: anytype) void {
//!                 _ = query.where("status", "=", 1);
//!             }
//!         },
//!         // 最近创建
//!         .recent = struct {
//!             pub fn apply(query: anytype) void {
//!                 _ = query.orderBy("created_at", .desc).limit(10);
//!             }
//!         },
//!         // 按角色筛选（带参数）
//!         .byRole = struct {
//!             pub fn apply(query: anytype, role_id: i32) void {
//!                 _ = query.where("role_id", "=", role_id);
//!             }
//!         },
//!     };
//! };
//!
//! // 2. 使用作用域
//! var q = OrmUser.Query();
//! _ = q.scope("active").scope("recent");
//! const users = try q.get();
//!
//! // 3. 带参数的作用域
//! var q = OrmUser.Query();
//! _ = q.scopeWith("byRole", .{1});
//! const users = try q.get();
//! ```

const std = @import("std");

/// 检查模型是否定义了作用域
pub fn hasScopes(comptime T: type) bool {
    return @hasDecl(T, "scopes");
}

/// 获取作用域定义
pub fn getScopes(comptime T: type) type {
    if (@hasDecl(T, "scopes")) {
        return @TypeOf(T.scopes);
    }
    return struct {};
}

/// 检查作用域是否存在
pub fn hasScopeNamed(comptime T: type, comptime name: []const u8) bool {
    if (!hasScopes(T)) return false;
    const ScopesType = getScopes(T);
    return @hasDecl(ScopesType, name);
}
