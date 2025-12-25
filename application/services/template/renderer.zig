const std = @import("std");

const ast = @import("ast.zig");

pub fn render(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node), context: std.json.Value) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    for (nodes.items) |node| {
        switch (node) {
            .text => |t| try output.appendSlice(t),
            .variable => |v| {
                var value = try getValue(context, v.path);
                if (v.filter) |f| {
                    value = try applyFilter(alloc, value, f);
                }
                const str = try valueToString(alloc, value);
                try output.appendSlice(str);
            },
            .for_loop => |f| {
                const iterable = try getValue(context, f.iterable_var);
                switch (iterable) {
                    .array => |arr| {
                        for (arr.items) |item| {
                            var new_map = std.StringHashMap(std.json.Value).init(alloc);
                            if (context == .object) {
                                var it = context.object.iterator();
                                while (it.next()) |entry| {
                                    try new_map.put(try alloc.dupe(u8, entry.key_ptr.*), entry.value_ptr.*);
                                }
                            }
                            try new_map.put(try alloc.dupe(u8, f.item_var), item);
                            const new_context = std.json.Value{ .object = new_map };
                            const body_output = try render(allocator, f.body, new_context);
                            defer allocator.free(body_output);
                            try output.appendSlice(body_output);
                        }
                    },
                    else => return error.IterableNotArray,
                }
            },
            .if_stmt => |i| {
                const value = try getValue(context, i.condition.var_path);
                const cond_true = if (i.condition.op) |op| {
                    const lit = i.condition.literal.?;
                    try compareValuesOp(value, op, lit)
                } else {
                    isTrue(value)
                };
                const body_to_render = if (cond_true) i.body else i.else_body;
                const body_output = try render(allocator, body_to_render, context);
                defer allocator.free(body_output);
                try output.appendSlice(body_output);
            },
            else => return error.NotImplemented,
        }
    }
    return output.toOwnedSlice();
}

fn isTrue(value: std.json.Value) bool {
    switch (value) {
        .bool => |b| return b,
        .string => |s| return s.len > 0,
        .integer => |i| return i != 0,
        .float => |f| return f != 0.0,
        .array => |a| return a.items.len > 0,
        .object => |o| return o.count() > 0,
        else => return false,
    }
}

fn valuesEqual(a: std.json.Value, b: std.json.Value) bool {
    switch (a) {
        .string => |s| if (b == .string) return std.mem.eql(u8, s, b.string) else return false,
        .integer => |i| if (b == .integer) return i == b.integer else return false,
        .bool => |bl| if (b == .bool) return bl == b.bool else return false,
        else => return false,
    }
}

fn compareValues(a: std.json.Value, b: std.json.Value) i32 {
    const na = switch (a) {
        .integer => |i| @as(f64, @floatFromInt(i)),
        .float => |f| f,
        else => 0,
    };
    const nb = switch (b) {
        .integer => |i| @as(f64, @floatFromInt(i)),
        .float => |f| f,
        else => 0,
    };
    if (na < nb) return -1;
    if (na > nb) return 1;
    return 0;
}

fn compareValuesOp(left: std.json.Value, op: []const u8, right: std.json.Value) !bool {
    if (std.mem.eql(u8, op, "==")) return valuesEqual(left, right);
    if (std.mem.eql(u8, op, "!=")) return !valuesEqual(left, right);
    if (std.mem.eql(u8, op, "<")) return compareValues(left, right) < 0;
    if (std.mem.eql(u8, op, ">")) return compareValues(left, right) > 0;
    if (std.mem.eql(u8, op, "<=")) return compareValues(left, right) <= 0;
    if (std.mem.eql(u8, op, ">=")) return compareValues(left, right) >= 0;
    return error.UnsupportedOp;
}

fn applyFilter(allocator: std.mem.Allocator, value: std.json.Value, filter: []const u8) !std.json.Value {
    if (std.mem.eql(u8, filter, "upper")) {
        if (value == .string) {
            const upper = try std.ascii.allocUpperString(allocator, value.string);
            return std.json.Value{ .string = upper };
        }
    } else if (std.mem.eql(u8, filter, "lower")) {
        if (value == .string) {
            const lower = try std.ascii.allocLowerString(allocator, value.string);
            return std.json.Value{ .string = lower };
        }
    } else if (std.mem.eql(u8, filter, "length")) {
        const len: i64 = switch (value) {
            .string => |s| @intCast(s.len),
            .array => |a| @intCast(a.items.len),
            .object => |o| @intCast(o.count()),
            else => 0,
        };
        return std.json.Value{ .integer = len };
    }
    return value;
}

fn getValue(context: std.json.Value, path: []const u8) !std.json.Value {
    var current = context;

    var iter = std.mem.split(u8, path, ".");

    while (iter.next()) |part| {
        switch (current) {
            .object => |obj| {
                if (obj.get(part)) |val| {
                    current = val;
                } else {
                    return error.VariableNotFound;
                }
            },

            else => return error.InvalidPath,
        }
    }

    return current;
}

fn valueToString(allocator: std.mem.Allocator, value: std.json.Value) ![]u8 {
    switch (value) {
        .string => |s| return allocator.dupe(u8, s),

        .integer => |i| return std.fmt.allocPrint(allocator, "{}", .{i}),

        .float => |f| return std.fmt.allocPrint(allocator, "{}", .{f}),

        .bool => |b| return allocator.dupe(u8, if (b) "true" else "false"),

        else => return allocator.dupe(u8, "[object]"),
    }
}
