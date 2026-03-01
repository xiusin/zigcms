//! 模型事件（Model Events）功能
//!
//! 提供类似 Laravel 的模型事件钩子，在模型生命周期的关键点执行自定义逻辑。
//!
//! ## 使用示例
//!
//! ```zig
//! // 1. 模型定义（添加事件钩子）
//! pub const User = struct {
//!     id: ?i32 = null,
//!     name: []const u8 = "",
//!     email: []const u8 = "",
//!     
//!     // 定义事件钩子
//!     pub const events = .{
//!         // 创建前
//!         .creating = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Creating user: {s}\n", .{model.name});
//!             }
//!         },
//!         // 创建后
//!         .created = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Created user: {d}\n", .{model.id.?});
//!             }
//!         },
//!         // 更新前
//!         .updating = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Updating user: {d}\n", .{model.id.?});
//!             }
//!         },
//!         // 更新后
//!         .updated = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Updated user: {d}\n", .{model.id.?});
//!             }
//!         },
//!         // 删除前
//!         .deleting = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Deleting user: {d}\n", .{model.id.?});
//!             }
//!         },
//!         // 删除后
//!         .deleted = struct {
//!             pub fn handle(model: *User) !void {
//!                 std.debug.print("Deleted user: {d}\n", .{model.id.?});
//!             }
//!         },
//!     };
//! };
//! ```

const std = @import("std");

/// 模型事件类型
pub const EventType = enum {
    creating,   // 创建前
    created,    // 创建后
    updating,   // 更新前
    updated,    // 更新后
    deleting,   // 删除前
    deleted,    // 删除后
    saving,     // 保存前（创建或更新）
    saved,      // 保存后（创建或更新）
};

/// 检查模型是否定义了事件
pub fn hasEvents(comptime T: type) bool {
    return @hasDecl(T, "events");
}

/// 检查模型是否定义了特定事件
pub fn hasEvent(comptime T: type, comptime event: EventType) bool {
    if (!hasEvents(T)) return false;
    const events_value = T.events;
    const event_name = @tagName(event);
    return @hasField(@TypeOf(events_value), event_name);
}

/// 触发模型事件
pub fn fireEvent(comptime T: type, comptime event: EventType, model: *T) !void {
    if (!hasEvent(T, event)) return;
    
    const events_value = T.events;
    const event_name = @tagName(event);
    const event_handler = @field(events_value, event_name);
    
    try event_handler.handle(model);
}
