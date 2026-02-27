//! CMS 模型定义
//!
//! 模型是 CMS 的核心，定义了内容的结构和行为。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 模型类型
pub const ModelType = enum(i32) {
    single_page = 1, // 单页：如关于我们、联系方式
    list = 2, // 列表：如文章、新闻、产品
    cover = 3, // 封面：如栏目首页

    pub fn name(self: ModelType) []const u8 {
        return switch (self) {
            .single_page => "单页",
            .list => "列表",
            .cover => "封面",
        };
    }

    pub fn fromInt(value: i32) ModelType {
        return switch (value) {
            1 => .single_page,
            3 => .cover,
            else => .list,
        };
    }
};

/// 内容模型
pub const Model = struct {
    const Self = @This();

    id: ?i32 = null,
    name: []const u8 = "",
    table_name: []const u8 = "",
    description: []const u8 = "",
    model_type: ModelType = .list,
    status: bool = true,
    sort: i32 = 0,
    icon: []const u8 = "",
    is_system: bool = false,

    // 模板配置
    list_template: []const u8 = "",
    detail_template: []const u8 = "",
    form_template: []const u8 = "",

    // 列表配置
    list_fields: []const u8 = "[]", // JSON: 列表显示字段
    search_fields: []const u8 = "[]", // JSON: 可搜索字段
    order_field: []const u8 = "sort",
    order_direction: []const u8 = "asc",

    // 元数据
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: bool = false,

    /// 获取完整表名
    pub fn getFullTableName(self: *const Self, prefix: []const u8) ![]u8 {
        var buf: [256]u8 = undefined;
        const len = std.fmt.bufPrint(&buf, "{s}{s}", .{ prefix, self.table_name }) catch return error.BufferTooSmall;
        return buf[0..len.len];
    }

    /// 是否为列表类型
    pub fn isList(self: *const Self) bool {
        return self.model_type == .list;
    }

    /// 是否为单页类型
    pub fn isSinglePage(self: *const Self) bool {
        return self.model_type == .single_page;
    }
};

/// 模型创建参数
pub const CreateParams = struct {
    name: []const u8,
    table_name: []const u8,
    description: []const u8 = "",
    model_type: ModelType = .list,
    icon: []const u8 = "",
    list_template: []const u8 = "",
    detail_template: []const u8 = "",
    form_template: []const u8 = "",
    remark: []const u8 = "",
};

/// 模型更新参数
pub const UpdateParams = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    model_type: ?ModelType = null,
    status: ?bool = null,
    sort: ?i32 = null,
    icon: ?[]const u8 = null,
    list_template: ?[]const u8 = null,
    detail_template: ?[]const u8 = null,
    form_template: ?[]const u8 = null,
    list_fields: ?[]const u8 = null,
    search_fields: ?[]const u8 = null,
    order_field: ?[]const u8 = null,
    order_direction: ?[]const u8 = null,
    remark: ?[]const u8 = null,
};
