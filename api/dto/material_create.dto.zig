//! 素材创建数据传输对象
//!
//! 用于创建素材实体的数据结构

const std = @import("std");

/// 素材创建 DTO
pub const MaterialCreateDto = struct {
    /// 素材名称
    name: []const u8,
    /// 文件原名
    original_name: []const u8 = "",
    /// 文件路径
    file_path: []const u8 = "",
    /// 文件URL
    file_url: []const u8 = "",
    /// 文件大小（字节）
    file_size: i32 = 0,
    /// 文件类型（image/video/audio/document/other）
    file_type: []const u8 = "other",
    /// MIME类型
    mime_type: []const u8 = "",
    /// 文件扩展名
    extension: []const u8 = "",
    /// 素材分类ID
    category_id: i32 = 0,
    /// 素材标签（JSON格式）
    tags: []const u8 = "[]",
    /// 素材描述
    description: []const u8 = "",
    /// 缩略图路径
    thumb_path: []const u8 = "",
    /// 缩略图URL
    thumb_url: []const u8 = "",
    /// 图片宽度（仅图片）
    width: i32 = 0,
    /// 图片高度（仅图片）
    height: i32 = 0,
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 是否私有（0公开 1私有）
    is_private: i32 = 0,
    /// 备注
    remark: []const u8 = "",
};
