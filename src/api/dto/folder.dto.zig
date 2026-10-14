//! 文件夹数据传输对象

const std = @import("std");
const core_io = @import("../../core/io.zig");

/// 文件夹 DTO
pub const FolderDto = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    parent_id: ?i32 = null,
    path: []const u8 = "",
    created_at: []const u8 = "",
    updated_at: []const u8 = "",
};
