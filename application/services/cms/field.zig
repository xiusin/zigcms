//! CMS 字段定义
//!
//! 字段定义了模型的数据结构，支持多种字段类型。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 字段类型枚举
pub const FieldType = enum {
    text, // 单行文本
    textarea, // 多行文本
    richtext, // 富文本编辑器
    number, // 整数
    decimal, // 小数
    select, // 下拉选择
    radio, // 单选
    checkbox, // 多选
    switch_bool, // 开关
    date, // 日期
    datetime, // 日期时间
    time, // 时间
    image, // 单图
    images, // 多图
    file, // 单文件
    files, // 多文件
    color, // 颜色选择
    icon, // 图标选择
    cascader, // 级联选择
    tree_select, // 树形选择
    relation, // 关联模型
    json, // JSON 编辑器
    code, // 代码编辑器
    markdown, // Markdown 编辑器
    hidden, // 隐藏字段

    /// 获取显示名称
    pub fn displayName(self: FieldType) []const u8 {
        return switch (self) {
            .text => "单行文本",
            .textarea => "多行文本",
            .richtext => "富文本",
            .number => "整数",
            .decimal => "小数",
            .select => "下拉选择",
            .radio => "单选",
            .checkbox => "多选",
            .switch_bool => "开关",
            .date => "日期",
            .datetime => "日期时间",
            .time => "时间",
            .image => "图片",
            .images => "多图",
            .file => "文件",
            .files => "多文件",
            .color => "颜色",
            .icon => "图标",
            .cascader => "级联选择",
            .tree_select => "树形选择",
            .relation => "关联",
            .json => "JSON",
            .code => "代码",
            .markdown => "Markdown",
            .hidden => "隐藏",
        };
    }

    /// 获取数据库字段类型
    pub fn dbType(self: FieldType) []const u8 {
        return switch (self) {
            .text, .hidden => "VARCHAR(255)",
            .textarea, .richtext, .markdown, .checkbox, .images, .files, .json => "TEXT",
            .number, .relation => "INT",
            .decimal => "DECIMAL(10,2)",
            .select, .radio => "VARCHAR(100)",
            .switch_bool => "TINYINT(1)",
            .date => "DATE",
            .datetime => "DATETIME",
            .time => "TIME",
            .image, .file, .cascader, .tree_select => "VARCHAR(500)",
            .color => "VARCHAR(20)",
            .icon => "VARCHAR(50)",
            .code => "MEDIUMTEXT",
        };
    }

    /// 从字符串解析
    pub fn fromString(str: []const u8) FieldType {
        const map = std.StaticStringMap(FieldType).initComptime(.{
            .{ "text", .text },
            .{ "textarea", .textarea },
            .{ "richtext", .richtext },
            .{ "number", .number },
            .{ "decimal", .decimal },
            .{ "select", .select },
            .{ "radio", .radio },
            .{ "checkbox", .checkbox },
            .{ "switch", .switch_bool },
            .{ "date", .date },
            .{ "datetime", .datetime },
            .{ "time", .time },
            .{ "image", .image },
            .{ "images", .images },
            .{ "file", .file },
            .{ "files", .files },
            .{ "color", .color },
            .{ "icon", .icon },
            .{ "cascader", .cascader },
            .{ "tree_select", .tree_select },
            .{ "relation", .relation },
            .{ "json", .json },
            .{ "code", .code },
            .{ "markdown", .markdown },
            .{ "hidden", .hidden },
        });
        return map.get(str) orelse .text;
    }
};

/// 字段定义
pub const Field = struct {
    const Self = @This();

    id: ?i32 = null,
    model_id: i32 = 0,
    field_name: []const u8 = "",
    field_label: []const u8 = "",
    field_type: FieldType = .text,
    db_type: []const u8 = "VARCHAR(255)",
    default_value: []const u8 = "",

    // 验证配置
    is_required: bool = false,
    is_unique: bool = false,
    min_length: i32 = 0,
    max_length: i32 = 0,
    pattern: []const u8 = "", // 正则验证
    validation: []const u8 = "{}", // JSON: 自定义验证规则

    // 显示配置
    is_list_show: bool = true, // 列表显示
    is_search: bool = false, // 可搜索
    is_sort: bool = false, // 可排序
    placeholder: []const u8 = "",
    help_text: []const u8 = "",
    field_group: []const u8 = "基本信息",
    column_width: i32 = 0,

    // 选项配置（用于 select/radio/checkbox）
    options: []const u8 = "[]", // JSON: [{value, label}]

    // 元数据
    sort: i32 = 0,
    status: bool = true,
    remark: []const u8 = "",
    create_time: ?i64 = null,
    update_time: ?i64 = null,
    is_delete: bool = false,

    /// 生成 DDL 列定义
    pub fn toDdl(self: *const Self, allocator: Allocator) ![]u8 {
        var sql = std.ArrayList(u8).init(allocator);
        errdefer sql.deinit();

        try sql.appendSlice(self.field_name);
        try sql.append(' ');
        try sql.appendSlice(self.db_type);

        if (self.is_required) {
            try sql.appendSlice(" NOT NULL");
        }

        if (self.default_value.len > 0) {
            try sql.appendSlice(" DEFAULT '");
            try sql.appendSlice(self.default_value);
            try sql.append('\'');
        }

        return sql.toOwnedSlice();
    }

    /// 生成验证规则字符串
    pub fn toValidationRule(self: *const Self) []const u8 {
        // 返回类似 "required|min:3|max:100" 的规则字符串
        var rules = std.ArrayList(u8).init(std.heap.page_allocator);
        defer rules.deinit();

        if (self.is_required) {
            rules.appendSlice("required") catch {};
        }

        if (self.min_length > 0) {
            if (rules.items.len > 0) rules.append('|') catch {};
            rules.writer().print("min:{d}", .{self.min_length}) catch {};
        }

        if (self.max_length > 0) {
            if (rules.items.len > 0) rules.append('|') catch {};
            rules.writer().print("max:{d}", .{self.max_length}) catch {};
        }

        if (self.field_type == .text and self.pattern.len > 0) {
            if (rules.items.len > 0) rules.append('|') catch {};
            rules.appendSlice("regex:") catch {};
            rules.appendSlice(self.pattern) catch {};
        }

        return rules.items;
    }
};

/// 字段创建参数
pub const CreateParams = struct {
    model_id: i32,
    field_name: []const u8,
    field_label: []const u8,
    field_type: FieldType = .text,
    default_value: []const u8 = "",
    is_required: bool = false,
    is_unique: bool = false,
    is_list_show: bool = true,
    is_search: bool = false,
    is_sort: bool = false,
    min_length: i32 = 0,
    max_length: i32 = 0,
    pattern: []const u8 = "",
    placeholder: []const u8 = "",
    help_text: []const u8 = "",
    field_group: []const u8 = "基本信息",
    options: []const u8 = "[]",
    sort: i32 = 0,
    remark: []const u8 = "",
};
