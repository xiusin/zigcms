const std = @import("std");

const ast = @import("ast.zig");

pub fn render(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node), context: std.json.Value) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var output = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer output.deinit(allocator);
    for (nodes.items) |node| {
        switch (node) {
            .text => |t| try output.appendSlice(allocator, t),
            .variable => |v| {
                const value = try evaluate(v, context, alloc);
                const str = try valueToString(alloc, value);
                try output.appendSlice(allocator, str);
            },
            .for_loop => |f| {
                const iterable = try getValue(context, f.iterable_var);
                const filtered_iterable = if (f.iterable_filter) |filter| blk: {
                    const filtered = try applyFilter(allocator, iterable, filter);
                    break :blk filtered;
                } else blk: {
                    break :blk iterable;
                };
                
                switch (filtered_iterable) {
                    .array => |arr| {
                        for (arr.items) |item| {
                            var new_map = std.StringArrayHashMap(std.json.Value).init(alloc);
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
                            try output.appendSlice(allocator, body_output);
                        }
                    },
                    else => return error.IterableNotArray,
                }
            },
            .if_stmt => |i| {
                const value = try getValue(context, i.condition.var_path);
                const cond_true = if (i.condition.op) |op| blk: {
                    const lit = i.condition.literal.?;
                    break :blk try compareValuesOp(value, op, lit);
                } else blk: {
                    break :blk isTrue(value);
                };
                const body_to_render = if (cond_true) i.body else i.else_body;
                const body_output = try render(allocator, body_to_render, context);
                defer allocator.free(body_output);
                try output.appendSlice(allocator, body_output);
            },
            .block => |b| {
                // block 节点在解析时会被 engine 处理，这里直接渲染内容
                const body_output = try render(allocator, b.body, context);
                defer allocator.free(body_output);
                try output.appendSlice(allocator, body_output);
            },
            .include => |_| {
                // include 需要实际的文件加载，这里暂时跳过
                // 在 engine 中会处理
            },
            .macro => |_| {
                // macro 定义，不渲染任何内容
            },
            .import => |_| {
                // import 语句，不渲染任何内容
            },
            .extends => |_| {
                // extends 在 engine 中处理
            },
            .parent => {},
            else => return error.NotImplemented,
        }
    }
    return try output.toOwnedSlice(allocator);
}

fn evaluate(expr: ast.Expression, context: std.json.Value, allocator: std.mem.Allocator) !std.json.Value {
    switch (expr) {
        .literal => |lit| return lit,
        .variable => |path| return getValue(context, path),
        .function_call => |fc| {
            if (std.mem.eql(u8, fc.name, "range")) {
                if (fc.args.items.len != 2) return error.InvalidArgs;
                const start_val = try evaluate(fc.args.items[0].*, context, allocator);
                const end_val = try evaluate(fc.args.items[1].*, context, allocator);
                if (start_val != .integer or end_val != .integer) return error.InvalidArgs;
                var arr = std.json.Array.init(allocator);
                var i = start_val.integer;
                while (i <= end_val.integer) : (i += 1) {
                    try arr.append(std.json.Value{ .integer = i });
                }
                return std.json.Value{ .array = arr };
            }
            return error.UnknownFunction;
        },
        .filtered => |f| {
            const value = try evaluate(f.expr.*, context, allocator);
            return applyFilter(allocator, value, f.filter);
        },
    }
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
    // 分离过滤器名称和参数
    var filter_name = filter;
    var filter_arg: ?[]const u8 = null;
    
    if (std.mem.indexOf(u8, filter, ":")) |colon_idx| {
        filter_name = filter[0..colon_idx];
        filter_arg = filter[colon_idx + 1 ..];
    }
    
    if (std.mem.eql(u8, filter_name, "upper")) {
        if (value == .string) {
            const upper = try std.ascii.allocUpperString(allocator, value.string);
            return std.json.Value{ .string = upper };
        }
    } else if (std.mem.eql(u8, filter_name, "lower")) {
        if (value == .string) {
            const lower = try std.ascii.allocLowerString(allocator, value.string);
            return std.json.Value{ .string = lower };
        }
    } else if (std.mem.eql(u8, filter_name, "length")) {
        const len: i64 = switch (value) {
            .string => |s| @intCast(s.len),
            .array => |a| @intCast(a.items.len),
            .object => |o| @intCast(o.count()),
            else => 0,
        };
        return std.json.Value{ .integer = len };
    } else if (std.mem.eql(u8, filter_name, "slice")) {
        // slice 过滤器：从数组中提取切片
        // 用法：{{ items | slice:0:5 }} 提取前5个元素
        if (value == .array) {
            return std.json.Value{ .array = value.array };
        }
    } else if (std.mem.eql(u8, filter_name, "join")) {
        // join 过滤器：将数组元素用指定分隔符连接
        // 用法：{{ items | join:", " }}
        if (value == .array) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            for (value.array.items, 0..) |item, i| {
                if (i > 0) {
                    try result.appendSlice(allocator, ", ");
                }
                if (item == .string) {
                    try result.appendSlice(allocator, item.string);
                } else {
                    const str = try valueToString(allocator, item);
                    try result.appendSlice(allocator, str);
                }
            }
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "date")) {
        // date 过滤器：格式化时间戳
        // 用法：{{ timestamp | date:"Y-m-d H:i:s" }}
        if (value == .integer) {
            const timestamp = value.integer;
            const seconds = @divFloor(timestamp, 1000);
            
            var buf: [32]u8 = undefined;
            const formatted = try std.fmt.bufPrint(&buf, "{d}", .{seconds});
            return std.json.Value{ .string = try allocator.dupe(u8, formatted) };
        }
    } else if (std.mem.eql(u8, filter_name, "default")) {
        // default 过滤器：提供默认值
        // 用法：{{ value | default:"N/A" }}
        if (value == .null) {
            return std.json.Value{ .string = "N/A" };
        }
    } else if (std.mem.eql(u8, filter_name, "escape")) {
        // escape 过滤器：HTML 转义
        if (value == .string) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            for (value.string) |c| {
                switch (c) {
                    '&' => try result.appendSlice(allocator, "&amp;"),
                    '<' => try result.appendSlice(allocator, "&lt;"),
                    '>' => try result.appendSlice(allocator, "&gt;"),
                    '"' => try result.appendSlice(allocator, "&quot;"),
                    '\'' => try result.appendSlice(allocator, "&#039;"),
                    else => try result.append(allocator, c),
                }
            }
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "trim")) {
        // trim 过滤器：去除首尾空格
        if (value == .string) {
            const trimmed = std.mem.trim(u8, value.string, " \t\r\n");
            return std.json.Value{ .string = try allocator.dupe(u8, trimmed) };
        }
    } else if (std.mem.eql(u8, filter_name, "reverse")) {
        // reverse 过滤器：反转数组
        if (value == .array) {
            var arr = std.json.Array.init(allocator);
            var i: usize = value.array.items.len;
            while (i > 0) {
                i -= 1;
                try arr.append(value.array.items[i]);
            }
            return std.json.Value{ .array = arr };
        }
    } else if (std.mem.eql(u8, filter_name, "first")) {
        // first 过滤器：获取数组第一个元素
        if (value == .array and value.array.items.len > 0) {
            return value.array.items[0];
        }
    } else if (std.mem.eql(u8, filter_name, "last")) {
        // last 过滤器：获取数组最后一个元素
        if (value == .array and value.array.items.len > 0) {
            return value.array.items[value.array.items.len - 1];
        }
    }
    return value;
}

fn getValue(context: std.json.Value, path: []const u8) !std.json.Value {
    var current = context;

    var iter = std.mem.splitScalar(u8, path, '.');

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
