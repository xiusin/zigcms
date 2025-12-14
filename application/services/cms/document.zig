//! CMS 文档管理
//!
//! 文档是内容的载体，存储实际的内容数据。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 文档状态
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

    pub fn fromInt(value: i32) DocumentStatus {
        return switch (value) {
            1 => .published,
            2 => .pending,
            3 => .offline,
            else => .draft,
        };
    }

    pub fn canView(self: DocumentStatus) bool {
        return self == .published;
    }
};

/// 文档实体
pub const Document = struct {
    const Self = @This();

    id: ?i32 = null,
    model_id: i32 = 0,
    category_id: i32 = 0,

    // 基础字段
    title: []const u8 = "",
    sub_title: []const u8 = "",
    keywords: []const u8 = "",
    description: []const u8 = "",
    thumb: []const u8 = "",
    author: []const u8 = "",
    source: []const u8 = "",
    content: []const u8 = "",

    // 附件和扩展字段
    attachments: []const u8 = "[]", // JSON: 附件列表
    extra_fields: []const u8 = "{}", // JSON: 自定义字段值

    // 统计
    view_count: i32 = 0,
    like_count: i32 = 0,
    comment_count: i32 = 0,

    // 状态和属性
    sort: i32 = 0,
    status: DocumentStatus = .draft,
    is_recommend: bool = false,
    is_top: bool = false,
    is_hot: bool = false,

    // 时间
    publish_time: ?i64 = null,
    create_time: ?i64 = null,
    update_time: ?i64 = null,

    // 用户
    creator_id: i32 = 0,
    updater_id: i32 = 0,

    // URL 和模板
    url_alias: []const u8 = "",
    external_link: []const u8 = "",
    template: []const u8 = "",

    // 元数据
    remark: []const u8 = "",
    is_delete: bool = false,

    /// 是否已发布
    pub fn isPublished(self: *const Self) bool {
        return self.status == .published;
    }

    /// 是否可编辑
    pub fn canEdit(self: *const Self) bool {
        return self.status != .published;
    }

    /// 获取摘要
    pub fn getSummary(self: *const Self, max_len: usize) []const u8 {
        if (self.description.len > 0) {
            return if (self.description.len > max_len)
                self.description[0..max_len]
            else
                self.description;
        }
        // 从内容中提取摘要
        if (self.content.len > max_len) {
            return self.content[0..max_len];
        }
        return self.content;
    }

    /// 增加浏览次数
    pub fn incrementViews(self: *Self) void {
        self.view_count += 1;
    }
};

/// 文档创建参数
pub const CreateParams = struct {
    model_id: i32,
    category_id: i32 = 0,
    title: []const u8,
    sub_title: []const u8 = "",
    keywords: []const u8 = "",
    description: []const u8 = "",
    thumb: []const u8 = "",
    author: []const u8 = "",
    source: []const u8 = "",
    content: []const u8 = "",
    attachments: []const u8 = "[]",
    extra_fields: []const u8 = "{}",
    sort: i32 = 0,
    status: DocumentStatus = .draft,
    is_recommend: bool = false,
    is_top: bool = false,
    is_hot: bool = false,
    url_alias: []const u8 = "",
    external_link: []const u8 = "",
    template: []const u8 = "",
    remark: []const u8 = "",
    creator_id: i32 = 0,
};

/// 文档查询参数
pub const QueryParams = struct {
    model_id: ?i32 = null,
    category_id: ?i32 = null,
    status: ?DocumentStatus = null,
    keyword: ?[]const u8 = null,
    is_recommend: ?bool = null,
    is_top: ?bool = null,
    is_hot: ?bool = null,
    creator_id: ?i32 = null,
    start_time: ?i64 = null,
    end_time: ?i64 = null,
    page: i32 = 1,
    limit: i32 = 10,
    order_field: []const u8 = "id",
    order_dir: []const u8 = "desc",
};

/// 文档列表结果
pub fn DocumentList(comptime T: type) type {
    return struct {
        items: []T,
        total: u64,
        page: i32,
        limit: i32,

        pub fn hasMore(self: *const @This()) bool {
            const total_pages = @divFloor(self.total + @as(u64, @intCast(self.limit)) - 1, @as(u64, @intCast(self.limit)));
            return @as(u64, @intCast(self.page)) < total_pages;
        }

        pub fn isEmpty(self: *const @This()) bool {
            return self.items.len == 0;
        }
    };
}
