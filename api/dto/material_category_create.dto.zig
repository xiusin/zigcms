//! 素材分类创建数据传输对象
//!
//! 用于创建素材分类实体的数据结构

const std = @import("std");

/// 素材分类创建 DTO
pub const MaterialCategoryCreateDto = struct {
    /// 分类名称
    name: []const u8,
    /// 分类编码（唯一标识）
    code: []const u8 = "",
    /// 父分类ID（0=顶级分类）
    parent_id: i32 = 0,
    /// 分类描述
    description: []const u8 = "",
    /// 分类图标
    icon: []const u8 = "",
    /// 允许的文件类型（JSON格式，如 ["jpg","png","gif"]）
    allowed_types: []const u8 = "[]",
    /// 最大文件大小（字节）
    max_size: i32 = 10485760, // 10MB
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// 备注
    remark: []const u8 = "",
};
