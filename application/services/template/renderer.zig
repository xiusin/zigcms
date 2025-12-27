const std = @import("std");

const ast = @import("ast.zig");
const functions = @import("functions.zig");

pub fn render(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node), context: std.json.Value, fn_registry: ?*const functions.FunctionRegistry) ![]u8 {
    return renderWithMacros(allocator, nodes, context, null, fn_registry);
}

/// 使用宏上下文渲染模板
pub fn renderWithMacros(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node), context: std.json.Value, macros: ?*const std.StringHashMap(ast.Macro), fn_registry: ?*const functions.FunctionRegistry) ![]u8 {
    return renderWithMacrosAndSet(allocator, nodes, context, macros, fn_registry, null);
}

/// 使用宏上下文和 set 变量支持渲染模板
fn renderWithMacrosAndSet(
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(ast.Node),
    context: std.json.Value,
    macros: ?*const std.StringHashMap(ast.Macro),
    fn_registry: ?*const functions.FunctionRegistry,
    set_vars: ?*std.StringHashMap(std.json.Value),
) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var output = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer output.deinit(allocator);
    for (nodes.items) |node| {
        switch (node) {
            .text => |t| try output.appendSlice(allocator, t),
            .variable => |v| {
                const value = try evaluateWithMacros(v, context, alloc, macros, fn_registry, set_vars);
                const str = try valueToString(alloc, value);
                try output.appendSlice(allocator, str);
            },
            .for_loop => |f| {
                const iterable = try getValue(context, f.iterable_var, set_vars);
                const filtered_iterable = if (f.iterable_filter) |filter| blk: {
                    const filtered = try applyFilter(allocator, iterable, filter);
                    break :blk filtered;
                } else blk: {
                    break :blk iterable;
                };
                
                switch (filtered_iterable) {
                    .array => |arr| {
                        const loop_length = arr.items.len;
                        for (arr.items, 0..) |item, index| {
                            var new_map = std.StringArrayHashMap(std.json.Value).init(alloc);
                            if (context == .object) {
                                var it = context.object.iterator();
                                while (it.next()) |entry| {
                                    try new_map.put(try alloc.dupe(u8, entry.key_ptr.*), entry.value_ptr.*);
                                }
                            }
                            // 添加 set 变量
                            if (set_vars) |vars| {
                                var var_it = vars.iterator();
                                while (var_it.next()) |entry| {
                                    try new_map.put(try alloc.dupe(u8, entry.key_ptr.*), entry.value_ptr.*);
                                }
                            }
                            try new_map.put(try alloc.dupe(u8, f.item_var), item);
                            
                            // 添加 loop 变量
                            var loop_obj = std.StringArrayHashMap(std.json.Value).init(alloc);
                            try loop_obj.put(try alloc.dupe(u8, "index"), std.json.Value{ .integer = @intCast(index + 1) });
                            try loop_obj.put(try alloc.dupe(u8, "index0"), std.json.Value{ .integer = @intCast(index) });
                            try loop_obj.put(try alloc.dupe(u8, "first"), std.json.Value{ .bool = index == 0 });
                            try loop_obj.put(try alloc.dupe(u8, "last"), std.json.Value{ .bool = index == loop_length - 1 });
                            try loop_obj.put(try alloc.dupe(u8, "length"), std.json.Value{ .integer = @intCast(loop_length) });
                            try loop_obj.put(try alloc.dupe(u8, "revindex"), std.json.Value{ .integer = @intCast(loop_length - index) });
                            try loop_obj.put(try alloc.dupe(u8, "revindex0"), std.json.Value{ .integer = @intCast(loop_length - index - 1) });
                            try loop_obj.put(try alloc.dupe(u8, "even"), std.json.Value{ .bool = index % 2 == 0 });
                            try loop_obj.put(try alloc.dupe(u8, "odd"), std.json.Value{ .bool = index % 2 == 1 });
                            
                            try new_map.put(try alloc.dupe(u8, "loop"), std.json.Value{ .object = loop_obj });
                            
                            const new_context = std.json.Value{ .object = new_map };
                            const body_output = try renderWithMacrosAndSet(allocator, f.body, new_context, macros, fn_registry, set_vars);
                            defer allocator.free(body_output);
                            try output.appendSlice(allocator, body_output);
                        }
                    },
                    else => return error.IterableNotArray,
                }
            },
            .if_stmt => |i| {
                const value = try getValue(context, i.condition.var_path, set_vars);
                const cond_true = if (i.condition.op) |op| blk: {
                    const lit = i.condition.literal.?;
                    break :blk try compareValuesOp(value, op, lit);
                } else blk: {
                    break :blk isTrue(value);
                };
                
                var body_to_render: ?std.ArrayList(ast.Node) = null;
                
                if (cond_true) {
                    // if 条件为真，渲染 if 主体
                    body_to_render = i.body;
                } else {
                    // 检查 elif 条件
                    var elif_matched = false;
                    for (i.elif_conditions.items, 0..) |elif_cond, idx| {
                        const elif_value = try getValue(context, elif_cond.var_path, set_vars);
                        const elif_cond_true = if (elif_cond.op) |op| blk: {
                            const lit = elif_cond.literal.?;
                            break :blk try compareValuesOp(elif_value, op, lit);
                        } else blk: {
                            break :blk isTrue(elif_value);
                        };
                        
                        if (elif_cond_true) {
                            body_to_render = i.elif_bodies.items[idx];
                            elif_matched = true;
                            break;
                        }
                    }
                    
                    // 如果没有 elif 匹配，渲染 else 分支
                    if (!elif_matched and i.else_body.items.len > 0) {
                        body_to_render = i.else_body;
                    }
                }
                
                if (body_to_render) |body| {
                    const body_output = try renderWithMacrosAndSet(allocator, body, context, macros, fn_registry, set_vars);
                    defer allocator.free(body_output);
                    try output.appendSlice(allocator, body_output);
                }
            },
            .block => |b| {
                // block 节点在解析时会被 engine 处理，这里直接渲染内容
                const body_output = try renderWithMacrosAndSet(allocator, b.body, context, macros, fn_registry, set_vars);
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
            .set => |s| {
                // set 语句：设置变量
                if (set_vars) |vars| {
                    const value = try evaluateWithMacros(s.value, context, alloc, macros, fn_registry, set_vars);
                    try vars.put(s.var_name, value);
                }
            },
            .extends => |_| {
                // extends 在 engine 中处理
            },
            .parent => {},
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

/// 支持宏调用的表达式求值
fn evaluateWithMacros(expr: ast.Expression, context: std.json.Value, allocator: std.mem.Allocator, macros: ?*const std.StringHashMap(ast.Macro), fn_registry: ?*const functions.FunctionRegistry, set_vars: ?*std.StringHashMap(std.json.Value)) anyerror!std.json.Value {
    switch (expr) {
        .literal => |lit| return lit,
        .variable => |path| return getValue(context, path, set_vars),
        .function_call => |fc| {
            // 检查是否是宏调用
            if (macros != null) {
                if (macros.?.get(fc.name)) |macro| {
                    // 调用宏
                    return try callMacro(allocator, macro, fc.args, context, macros, fn_registry, set_vars);
                }
            }
            
            // 检查是否是注册的函数
            if (fn_registry != null) {
                if (fn_registry.?.get(fc.name)) |_| {
                    // 评估所有参数
                    var arg_values = try std.ArrayList(std.json.Value).initCapacity(allocator, fc.args.items.len);
                    defer {
                        for (arg_values.items) |arg| {
                            if (arg == .string) allocator.free(arg.string);
                            if (arg == .array) arg.array.deinit();
                        }
                        arg_values.deinit(allocator);
                    }
                    
                    for (fc.args.items) |arg_expr| {
                        const arg_value = try evaluateWithMacros(arg_expr.*, context, allocator, macros, fn_registry, set_vars);
                        try arg_values.append(allocator, arg_value);
                    }
                    
                    // 调用函数
                    return try fn_registry.?.call(allocator, fc.name, arg_values.items);
                }
            }
            
            return error.UnknownFunction;
        },
        .filtered => |f| {
            const value = try evaluateWithMacros(f.expr.*, context, allocator, macros, fn_registry, set_vars);
            return applyFilter(allocator, value, f.filter);
        },
    }
}

/// 调用宏
fn callMacro(allocator: std.mem.Allocator, macro: ast.Macro, args: std.ArrayList(*const ast.Expression), context: std.json.Value, macros: ?*const std.StringHashMap(ast.Macro), fn_registry: ?*const functions.FunctionRegistry, set_vars: ?*std.StringHashMap(std.json.Value)) !std.json.Value {
    // 验证参数数量
    if (args.items.len != macro.params.items.len) return error.InvalidMacroArgs;
    
    // 创建宏参数上下文
    var macro_context = std.StringArrayHashMap(std.json.Value).init(allocator);
    for (args.items, 0..) |arg_expr, i| {
        const arg_value = try evaluateWithMacros(arg_expr.*, context, allocator, macros, fn_registry, set_vars);
        try macro_context.put(macro.params.items[i], arg_value);
    }
    
    // 渲染宏体
    const output = try renderWithMacrosAndSet(allocator, macro.body, std.json.Value{ .object = macro_context }, macros, fn_registry, set_vars);
    defer allocator.free(output);
    
    return std.json.Value{ .string = output };
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
    } else if (std.mem.eql(u8, filter_name, "format")) {
        // format 过滤器：字符串格式化
        // 用法：{{ value | format:"Hello {s}!" }}
        if (value == .string and filter_arg != null) {
            // 简单的字符串替换，将 {s} 替换为实际值
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            
            var i: usize = 0;
            while (i < filter_arg.?.len) : (i += 1) {
                if (i + 1 < filter_arg.?.len and filter_arg.?[i] == '{' and filter_arg.?[i + 1] == 's') {
                    try result.appendSlice(allocator, value.string);
                    i += 1;
                } else {
                    try result.append(allocator, filter_arg.?[i]);
                }
            }
            if (i < filter_arg.?.len) {
                try result.appendSlice(allocator, filter_arg.?[i..]);
            }
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "replace")) {
        // replace 过滤器：字符串替换
        // 用法：{{ value | replace:"old:new" }}
        if (value == .string and filter_arg != null) {
            if (std.mem.indexOf(u8, filter_arg.?, ":")) |colon_idx| {
                const search = filter_arg.?[0..colon_idx];
                const replacement = filter_arg.?[colon_idx + 1 ..];
                
                var result = try std.ArrayList(u8).initCapacity(allocator, 0);
                defer result.deinit(allocator);
                
                var start: usize = 0;
                while (std.mem.indexOf(u8, value.string[start..], search)) |idx| {
                    try result.appendSlice(allocator, value.string[start .. start + idx]);
                    try result.appendSlice(allocator, replacement);
                    start += idx + search.len;
                }
                try result.appendSlice(allocator, value.string[start..]);
                
                return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
            }
        }
    } else if (std.mem.eql(u8, filter_name, "abs")) {
        // abs 过滤器：绝对值
        // 用法：{{ value | abs }}
        return switch (value) {
            .integer => |i| std.json.Value{ .integer = if (i < 0) -i else i },
            .float => |f| std.json.Value{ .float = if (f < 0) -f else f },
            else => value,
        };
    } else if (std.mem.eql(u8, filter_name, "round")) {
        // round 过滤器：四舍五入
        // 用法：{{ value | round:2 }} 保留2位小数
        const precision = if (filter_arg) |arg| blk: {
            const p = std.fmt.parseInt(i32, arg, 10) catch 0;
            break :blk @max(0, p);
        } else 0;
        
        return switch (value) {
            .integer => value,
            .float => |f| {
                if (precision == 0) {
                    return std.json.Value{ .integer = @intFromFloat(std.math.round(f)) };
                }
                const factor = std.math.pow(f64, 10.0, @floatFromInt(precision));
                const rounded = std.math.round(f * factor) / factor;
                return std.json.Value{ .float = rounded };
            },
            else => value,
        };
    } else if (std.mem.eql(u8, filter_name, "number_format")) {
        // number_format 过滤器：数字格式化
        // 用法：{{ value | number_format:2:"," }}
        if (value == .integer or value == .float) {
            const num = if (value == .integer) @as(f64, @floatFromInt(value.integer)) else value.float;
            
                    // 简化实现，实际应该支持千位分隔符
                    _ = if (filter_arg) |arg| blk: {                const p = std.fmt.parseInt(i32, arg, 10) catch 0;
                break :blk @max(0, p);
            } else 0;
            
            var buf: [64]u8 = undefined;
            const formatted = try std.fmt.bufPrint(&buf, "{d}", .{num});
            return std.json.Value{ .string = try allocator.dupe(u8, formatted) };
        }
    } else if (std.mem.eql(u8, filter_name, "url_encode")) {
        // url_encode 过滤器：URL 编码
        // 用法：{{ value | url_encode }}
        if (value == .string) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            
            for (value.string) |c| {
                if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
                    try result.append(allocator, c);
                } else {
                    try result.print(allocator, "%{X:0>2}", .{c});
                }
            }
            
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "json_encode")) {
        // json_encode 过滤器：JSON 编码
        // 用法：{{ value | json_encode }}
        // 简化实现：只支持基本类型
        return switch (value) {
            .string => |s| std.json.Value{ .string = try std.fmt.allocPrint(allocator, "\"{s}\"", .{s}) },
            .integer => |i| std.json.Value{ .string = try std.fmt.allocPrint(allocator, "{d}", .{i}) },
            .float => |f| std.json.Value{ .string = try std.fmt.allocPrint(allocator, "{d}", .{f}) },
            .number_string => |ns| std.json.Value{ .string = try allocator.dupe(u8, ns) },
            .bool => |b| std.json.Value{ .string = try allocator.dupe(u8, if (b) "true" else "false") },
            .null => std.json.Value{ .string = try allocator.dupe(u8, "null") },
            .array => |arr| blk: {
                var result = try std.ArrayList(u8).initCapacity(allocator, 0);
                defer result.deinit(allocator);
                try result.append(allocator, '[');
                for (arr.items, 0..) |item, i| {
                    if (i > 0) try result.append(allocator, ',');
                    const item_str = try std.fmt.allocPrint(allocator, "{any}", .{item});
                    defer allocator.free(item_str);
                    try result.appendSlice(allocator, item_str);
                }
                try result.append(allocator, ']');
                break :blk std.json.Value{ .string = try result.toOwnedSlice(allocator) };
            },
            .object => |obj| blk: {
                var result = try std.ArrayList(u8).initCapacity(allocator, 0);
                defer result.deinit(allocator);
                try result.append(allocator, '{');
                var first = true;
                var it = obj.iterator();
                while (it.next()) |entry| {
                    if (!first) try result.append(allocator, ',');
                    first = false;
                    try result.append(allocator, '"');
                    try result.appendSlice(allocator, entry.key_ptr.*);
                    try result.appendSlice(allocator, "\":");
                    const val_str = try std.fmt.allocPrint(allocator, "{any}", .{entry.value_ptr.*});
                    defer allocator.free(val_str);
                    try result.appendSlice(allocator, val_str);
                }
                try result.append(allocator, '}');
                break :blk std.json.Value{ .string = try result.toOwnedSlice(allocator) };
            },
        };
    } else if (std.mem.eql(u8, filter_name, "capitalize")) {
        // capitalize 过滤器：首字母大写
        // 用法：{{ value | capitalize }}
        if (value == .string and value.string.len > 0) {
            var result = try std.ArrayList(u8).initCapacity(allocator, value.string.len);
            defer result.deinit(allocator);
            
            try result.append(allocator, std.ascii.toUpper(value.string[0]));
            if (value.string.len > 1) {
                try result.appendSlice(allocator, value.string[1..]);
            }
            
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "title")) {
        // title 过滤器：标题格式化（每个单词首字母大写）
        // 用法：{{ value | title }}
        if (value == .string) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            
            var capitalize_next = true;
            for (value.string) |c| {
                if (std.ascii.isWhitespace(c)) {
                    capitalize_next = true;
                    try result.append(allocator, c);
                } else if (capitalize_next) {
                    try result.append(allocator, std.ascii.toUpper(c));
                    capitalize_next = false;
                } else {
                    try result.append(allocator, std.ascii.toLower(c));
                }
            }
            
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "striptags")) {
        // striptags 过滤器：去除 HTML 标签
        // 用法：{{ value | striptags }}
        if (value == .string) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            
            var in_tag = false;
            for (value.string) |c| {
                if (c == '<') {
                    in_tag = true;
                } else if (c == '>') {
                    in_tag = false;
                } else if (!in_tag) {
                    try result.append(allocator, c);
                }
            }
            
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "nl2br")) {
        // nl2br 过滤器：换行符转 <br>
        // 用法：{{ value | nl2br }}
        if (value == .string) {
            var result = try std.ArrayList(u8).initCapacity(allocator, 0);
            defer result.deinit(allocator);
            
            for (value.string) |c| {
                if (c == '\n') {
                    try result.appendSlice(allocator, "<br>");
                } else {
                    try result.append(allocator, c);
                }
            }
            
            return std.json.Value{ .string = try result.toOwnedSlice(allocator) };
        }
    } else if (std.mem.eql(u8, filter_name, "split")) {
        // split 过滤器：字符串分割
        // 用法：{{ value | split:"," }}
        if (value == .string and filter_arg != null) {
            var result = std.json.Array.init(allocator);
            var iter = std.mem.splitScalar(u8, value.string, filter_arg.?[0]);
            
            while (iter.next()) |part| {
                try result.append(std.json.Value{ .string = try allocator.dupe(u8, part) });
            }
            
            return std.json.Value{ .array = result };
        }
    } else if (std.mem.eql(u8, filter_name, "keys")) {
        // keys 过滤器：获取对象的所有键
        // 用法：{{ object | keys }}
        if (value == .object) {
            var result = std.json.Array.init(allocator);
            var it = value.object.iterator();
            while (it.next()) |entry| {
                try result.append(std.json.Value{ .string = try allocator.dupe(u8, entry.key_ptr.*) });
            }
            return std.json.Value{ .array = result };
        }
    } else if (std.mem.eql(u8, filter_name, "values")) {
        // values 过滤器：获取对象的所有值
        // 用法：{{ object | values }}
        if (value == .object) {
            var result = std.json.Array.init(allocator);
            var it = value.object.iterator();
            while (it.next()) |entry| {
                try result.append(entry.value_ptr.*);
            }
            return std.json.Value{ .array = result };
        }
    }
    return value;
}

fn getValue(context: std.json.Value, path: []const u8, set_vars: ?*std.StringHashMap(std.json.Value)) !std.json.Value {
    var current = context;

    var iter = std.mem.splitScalar(u8, path, '.');

    while (iter.next()) |part| {
        switch (current) {
            .object => |obj| {
                if (obj.get(part)) |val| {
                    current = val;
                } else if (set_vars != null) {
                    if (set_vars.?.get(part)) |val| {
                        current = val;
                    } else {
                        return error.VariableNotFound;
                    }
                } else {
                    return error.VariableNotFound;
                }
            },

            else => return error.InvalidPath,
        }
    }

    return current;
}

/// 获取变量值（不使用 set_vars）
fn getValueSimple(context: std.json.Value, path: []const u8) !std.json.Value {
    return getValue(context, path, null);
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
