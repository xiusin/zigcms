//! 上传元数据传输对象

const std = @import("std");

/// 上传元数据 DTO
pub const UploadMetaDto = struct {
    filename: []const u8 = "",
    content_type: []const u8 = "",
    size: i64 = 0,
    folder_id: ?i32 = null,
};
