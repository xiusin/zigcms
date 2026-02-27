//! 分类创建数据传输对象
//!
//! 用于创建分类实体的数据结构

const std = @import("std");

/// 分类创建 DTO
pub const CategoryCreateDto = struct {
    /// 分类名称
    name: []const u8,
    /// 分类编码（唯一标识）
    code: []const u8 = "",
    /// 父分类ID（0=顶级分类）
    parent_id: i32 = 0,
    /// 分类类型（article=文章分类, product=产品分类, page=单页分类等）
    category_type: []const u8 = "article",
    /// 分类描述
    description: []const u8 = "",
    /// 封面图片
    cover_image: []const u8 = "",
    /// 分类图标
    icon: []const u8 = "",
    /// 排序权重
    sort: i32 = 0,
    /// 状态（0禁用 1启用）
    status: i32 = 1,
    /// SEO标题
    seo_title: []const u8 = "",
    /// SEO关键词
    seo_keywords: []const u8 = "",
    /// SEO描述
    seo_description: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
};
