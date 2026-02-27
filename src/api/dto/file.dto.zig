//! 文件数据传输对象

const std = @import("std");

/// 文件 DTO
pub const FileDto = struct {
    id: ?i32 = null,
    name: []const u8 = "",
    path: []const u8 = "",
    size: i64 = 0,
    mime_type: []const u8 = "",
    extension: []const u8 = "",
    folder_id: ?i32 = null,
    created_at: []const u8 = "",
    updated_at: []const u8 = "",
};
