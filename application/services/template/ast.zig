const std = @import("std");

pub const NodeType = enum {
    text,
    variable,
    for_loop,
    if_stmt,
    set,
};

pub const Condition = struct {
    var_path: []const u8,
    op: ?[]const u8 = null,
    literal: ?std.json.Value = null,
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
};

pub const Node = union(NodeType) {
    text: []const u8,
    variable: Expression,
    for_loop: struct {
        item_var: []const u8,
        iterable_var: []const u8,
        body: std.ArrayList(Node),
    },
    if_stmt: struct {
        condition: Condition,
        body: std.ArrayList(Node),
        else_body: std.ArrayList(Node),
    },
    set: struct {
        var_name: []const u8,
        value: []const u8,
    },
};
