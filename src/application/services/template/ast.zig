const std = @import("std");
const core_meta = @import("../../../core/meta.zig");
const core_io = @import("../../../core/io.zig");

/// 宏定义类型
pub const Macro = struct {
    params: std.ArrayList([]const u8),
    body: std.ArrayList(Node),
};

pub const NodeType = enum {
    text,
    variable,
    for_loop,
    if_stmt,
    set,
    extends,
    block,
    include,
    macro,
    import,
    parent,
};

pub const Condition = struct {
    var_path: []const u8,
    op: ?[]const u8 = null,
    literal: ?std.json.Value = null,
};

/// range(start, end) 字面量区间（两端都包含）
pub const Range = struct {
    start: i64,
    end: i64,
};

pub const Variable = struct {
    path: []const u8,
    filter: ?[]const u8 = null,
};

pub const Filtered = struct {
    expr: *const Expression,
    filter: []const u8,
};

pub const FunctionCall = struct {
    name: []const u8,
    args: std.ArrayList(*const Expression),
};

pub const Expression = union(enum) {
    literal: std.json.Value,
    variable: []const u8,
    function_call: *FunctionCall,
    filtered: *Filtered,
    binary: *BinaryExpression,
};

pub const BinaryExpression = struct {
    left: *const Expression,
    op: []const u8,
    right: *const Expression,
};

pub const Node = union(NodeType) {
    text: []const u8,
    variable: Expression,
    for_loop: struct {
        item_var: []const u8,
        key_var: ?[]const u8 = null,
        iterable_var: []const u8 = "",
        iterable_filter: ?[]const u8 = null,
        iterable_range: ?Range = null,
        body: std.ArrayList(Node),
    },
    if_stmt: struct {
        condition: Condition,
        body: std.ArrayList(Node),
        elif_conditions: std.ArrayList(Condition),
        elif_bodies: std.ArrayList(std.ArrayList(Node)),
        else_body: std.ArrayList(Node),
    },
    set: struct {
        var_name: []const u8,
        value: Expression,
    },
    extends: struct {
        template_name: []const u8,
    },
    block: struct {
        name: []const u8,
        body: std.ArrayList(Node),
    },
    include: struct {
        template_name: []const u8,
        /// `with <dotted-path>`：局部上下文变量路径（null 表示共享外层上下文）
        with_path: ?[]const u8 = null,
        /// `only`：仅使用 with 变量，不合并外层上下文
        only: bool = false,
    },
    macro: struct {
        name: []const u8,
        params: std.ArrayList([]const u8),
        body: std.ArrayList(Node),
    },
    import: struct {
        template_name: []const u8,
        macro_names: std.ArrayList([]const u8),
    },
    parent: struct {},
};
