//! CMS 文档管理实体
//!
//! 用于管理内容文档

/// 文档实体
pub const Document = struct {
    /// 文档ID
    id: ?i32 = null,
    /// 所属模型ID
    model_id: i32 = 0,
    /// 所属栏目ID
    category_id: i32 = 0,
    /// 文档标题
    title: []const u8 = "",
    /// 副标题
    sub_title: []const u8 = "",
    /// 关键词
    keywords: []const u8 = "",
    /// 描述
    description: []const u8 = "",
    /// 缩略图
    thumb: []const u8 = "",
    /// 作者
    author: []const u8 = "",
    /// 来源
    source: []const u8 = "",
    /// 内容
    content: []const u8 = "",
    /// 附件（JSON数组）
    attachments: []const u8 = "[]",
    /// 扩展字段（JSON对象，存储自定义字段值）
    extra_fields: []const u8 = "{}",
    /// 浏览次数
    view_count: i32 = 0,
    /// 点赞数
    like_count: i32 = 0,
    /// 评论数
    comment_count: i32 = 0,
    /// 排序
    sort: i32 = 0,
    /// 状态（0草稿 1已发布 2待审核 3已下架）
    status: i32 = 0,
    /// 是否推荐（0否 1是）
    is_recommend: i32 = 0,
    /// 是否置顶（0否 1是）
    is_top: i32 = 0,
    /// 是否热门（0否 1是）
    is_hot: i32 = 0,
    /// 发布时间
    publish_time: ?i64 = null,
    /// 创建人ID
    creator_id: i32 = 0,
    /// 更新人ID
    updater_id: i32 = 0,
    /// URL别名（用于伪静态）
    url_alias: []const u8 = "",
    /// 外部链接
    external_link: []const u8 = "",
    /// 模板
    template: []const u8 = "",
    /// 备注
    remark: []const u8 = "",
    /// 创建时间
    create_time: ?i64 = null,
    /// 更新时间
    update_time: ?i64 = null,
    /// 软删除标记
    is_delete: i32 = 0,
};

/// 文档状态枚举
pub const DocumentStatus = enum(i32) {
    draft = 0, // 草稿
    published = 1, // 已发布
    pending = 2, // 待审核
    offline = 3, // 已下架

    pub fn name(self: DocumentStatus) []const u8 {
        return switch (self) {
            .draft => "草稿",
            .published => "已发布",
            .pending => "待审核",
            .offline => "已下架",
        };
    }
};
