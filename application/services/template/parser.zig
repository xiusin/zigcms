const std = @import("std");

const lexer = @import("lexer.zig");

const ast = @import("ast.zig");

pub fn parse(allocator: std.mem.Allocator, lex: *lexer.Lexer, stop_on: ?lexer.TokenType) !std.ArrayList(ast.Node) {
    var nodes = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
    while (try lex.next()) |token| {
        switch (token.type) {
            .text => {
                try nodes.append(allocator, .{ .text = try allocator.dupe(u8, token.lexeme) });
            },
            .variable_start => {
                const expr = try parseExpression(allocator, lex);
                const next_token = try lex.next() orelse return error.UnexpectedEof;
                if (next_token.type == .pipe) {
                    const filter_token = try lex.next() orelse return error.UnexpectedEof;
                    if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                    
                    // 检查是否有参数（冒号）
                    const param_token = try lex.next() orelse return error.UnexpectedEof;
                    var filter_with_param = filter_token.lexeme;
                    var need_free = false;
                    if (param_token.type == .operator and std.mem.eql(u8, param_token.lexeme, ":")) {
                        // 读取参数值
                        const arg_token = try lex.next() orelse return error.UnexpectedEof;
                        if (arg_token.type == .string or arg_token.type == .number) {
                            // 创建带参数的过滤器名称
                            const full_filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{filter_token.lexeme, arg_token.lexeme});
                            filter_with_param = full_filter;
                            need_free = true;
                        }
                        const end_token = try lex.next() orelse return error.UnexpectedEof;
                        if (end_token.type != .variable_end) return error.ExpectedVariableEnd;
                    } else if (param_token.type == .variable_end) {
                        // 没有参数，需要复制过滤器名称
                        filter_with_param = try allocator.dupe(u8, filter_token.lexeme);
                        need_free = true;
                    } else {
                        return error.ExpectedVariableEnd;
                    }
                    
                    const filtered_ptr = try allocator.create(ast.Filtered);
                    const expr_ptr = try allocator.create(ast.Expression);
                    expr_ptr.* = expr;
                    filtered_ptr.* = .{ .expr = expr_ptr, .filter = filter_with_param };
                    try nodes.append(allocator, .{ .variable = ast.Expression{ .filtered = filtered_ptr } });
                } else if (next_token.type == .variable_end) {
                    try nodes.append(allocator, .{ .variable = expr });
                } else {
                    return error.ExpectedPipeOrVariableEnd;
                }
            },
            .tag_start => {
                const tag_token = try lex.next() orelse return error.UnexpectedEof;
                if (stop_on != null and tag_token.type == stop_on.?) {
                    const end_token = try lex.next() orelse return error.UnexpectedEof;
                    if (end_token.type != .tag_end) return error.ExpectedTagEnd;
                    return nodes;
                }
                switch (tag_token.type) {
                    .for_kw => {
                        const item_token = try lex.next() orelse return error.UnexpectedEof;
                        if (item_token.type != .identifier) return error.ExpectedIdentifier;
                        const in_token = try lex.next() orelse return error.UnexpectedEof;
                        if (in_token.type != .in_kw) return error.ExpectedIn;
                        const iterable_token = try lex.next() orelse return error.UnexpectedEof;
                        if (iterable_token.type != .identifier) return error.ExpectedIdentifier;
                        
                        // 检查是否有过滤器
                        const next_after_iterable = try lex.next() orelse return error.UnexpectedEof;
                        var iterable_filter: ?[]const u8 = null;
                        if (next_after_iterable.type == .pipe) {
                            const filter_token = try lex.next() orelse return error.UnexpectedEof;
                            if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                            iterable_filter = try allocator.dupe(u8, filter_token.lexeme);
                            const tag_end = try lex.next() orelse return error.UnexpectedEof;
                            if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        } else if (next_after_iterable.type == .tag_end) {
                            // 没有过滤器
                        } else {
                            return error.ExpectedTagEnd;
                        }
                        
                        const body = try parse(allocator, lex, .endfor_kw);
                        try nodes.append(allocator, .{ .for_loop = .{
                            .item_var = try allocator.dupe(u8, item_token.lexeme),
                            .iterable_var = try allocator.dupe(u8, iterable_token.lexeme),
                            .iterable_filter = iterable_filter,
                            .body = body,
                        } });
                    },
                    .if_kw => {
                        // 使用 parseExpression 来解析条件，这样可以支持路径变量（如 loop.first）
                        const expr = try parseExpression(allocator, lex);
                        
                        var condition = ast.Condition{ .var_path = "", .op = null, .literal = null };
                        
                        // 检查表达式类型
                        switch (expr) {
                            .variable => |path| {
                                condition.var_path = path;
                            },
                            else => return error.InvalidPrimary,
                        }
                        
                        const next_token = try lex.next() orelse return error.UnexpectedEof;
                        if (next_token.type == .operator) {
                            condition.op = try allocator.dupe(u8, next_token.lexeme);
                            const lit_token = try lex.next() orelse return error.UnexpectedEof;
                            condition.literal = try parseLiteral(allocator, lit_token);
                            const tag_end = try lex.next() orelse return error.UnexpectedEof;
                            if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        } else if (next_token.type == .tag_end) {
                            // no op
                        } else {
                            return error.ExpectedOperatorOrTagEnd;
                        }
                        
                        // 手动解析 if 主体，直到遇到 endif、elif 或 else
                        var body = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
                        while (true) {
                            const if_token = try lex.next() orelse return error.UnexpectedEof;
                            
                            if (if_token.type == .tag_start) {
                                // 检查下一个 token 是否是 elif、else 或 endif
                                const peek_token = try lex.peek() orelse return error.UnexpectedEof;
                                if (peek_token.type == .elif_kw or peek_token.type == .else_kw or peek_token.type == .endif_kw) {
                                    // 恢复 lexer 状态，让外层处理这些标签
                                    lex.current -= 1; // 回退 tag_start
                                    break;
                                }
                                
                                // 不是 elif、else 或 endif，继续解析
                                const if_tag_token = try lex.next() orelse return error.UnexpectedEof;
                                
                                // 处理 if_tag_token
                                // 这里需要复制 parse 函数中的逻辑来处理各种标签
                                // 为了简化，我们暂时只处理 text 和 variable
                                if (if_tag_token.type == .for_kw) {
                                    // 处理 for 循环
                                    const item_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (item_token.type != .identifier) return error.ExpectedIdentifier;
                                    const in_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (in_token.type != .in_kw) return error.ExpectedIn;
                                    const iterable_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (iterable_token.type != .identifier) return error.ExpectedIdentifier;
                                    
                                    const next_after_iterable = try lex.next() orelse return error.UnexpectedEof;
                                    var iterable_filter: ?[]const u8 = null;
                                    if (next_after_iterable.type == .pipe) {
                                        const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                        if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                        iterable_filter = try allocator.dupe(u8, filter_token.lexeme);
                                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                    } else if (next_after_iterable.type == .tag_end) {
                                        // 没有过滤器
                                    } else {
                                        return error.ExpectedTagEnd;
                                    }
                                    
                                    const nested_for_body = try parse(allocator, lex, .endfor_kw);
                                    try body.append(allocator, .{ .for_loop = .{
                                        .item_var = try allocator.dupe(u8, item_token.lexeme),
                                        .iterable_var = try allocator.dupe(u8, iterable_token.lexeme),
                                        .iterable_filter = iterable_filter,
                                        .body = nested_for_body,
                                    } });
                                } else if (if_tag_token.type == .if_kw) {
                                    // 处理嵌套 if
                                    const if_expr = try parseExpression(allocator, lex);
                                    
                                    var if_condition = ast.Condition{ .var_path = "", .op = null, .literal = null };
                                    
                                    switch (if_expr) {
                                        .variable => |path| {
                                            if_condition.var_path = path;
                                        },
                                        else => return error.InvalidPrimary,
                                    }
                                    
                                    const if_next_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (if_next_token.type == .operator) {
                                        if_condition.op = try allocator.dupe(u8, if_next_token.lexeme);
                                        const lit_token = try lex.next() orelse return error.UnexpectedEof;
                                        if_condition.literal = try parseLiteral(allocator, lit_token);
                                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                    } else if (if_next_token.type == .tag_end) {
                                        // no op
                                    } else {
                                        return error.ExpectedOperatorOrTagEnd;
                                    }
                                    
                                    const nested_if_body = try parse(allocator, lex, .endif_kw);
                                    try body.append(allocator, .{ .if_stmt = .{
                                        .condition = if_condition,
                                        .body = nested_if_body,
                                        .elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0),
                                        .elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0),
                                        .else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0),
                                    } });
                                } else if (if_tag_token.type == .set_kw) {
                                    // 处理 set
                                    const var_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (var_token.type != .identifier) return error.ExpectedIdentifier;
                                    const eq_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (eq_token.type != .operator or !std.mem.eql(u8, eq_token.lexeme, "=")) return error.ExpectedEquals;
                                    
                                    const value_expr = try parseExpression(allocator, lex);
                                    
                                    const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                    if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                    
                                    try body.append(allocator, .{ .set = .{
                                        .var_name = try allocator.dupe(u8, var_token.lexeme),
                                        .value = value_expr,
                                    } });
                                } else {
                                    return error.UnexpectedToken;
                                }
                            } else if (if_token.type == .text) {
                                try body.append(allocator, .{ .text = try allocator.dupe(u8, if_token.lexeme) });
                            } else if (if_token.type == .variable_start) {
                                const if_var_expr = try parseExpression(allocator, lex);
                                const if_var_next = try lex.next() orelse return error.UnexpectedEof;
                                if (if_var_next.type == .pipe) {
                                    const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                    
                                    const param_token = try lex.next() orelse return error.UnexpectedEof;
                                    var filter_with_param = filter_token.lexeme;
                                    var need_free = false;
                                    if (param_token.type == .operator and std.mem.eql(u8, param_token.lexeme, ":")) {
                                        const arg_token = try lex.next() orelse return error.UnexpectedEof;
                                        if (arg_token.type == .string or arg_token.type == .number) {
                                            const full_filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{filter_token.lexeme, arg_token.lexeme});
                                            filter_with_param = full_filter;
                                            need_free = true;
                                        }
                                        const end_token = try lex.next() orelse return error.UnexpectedEof;
                                        if (end_token.type != .variable_end) return error.ExpectedVariableEnd;
                                    } else if (param_token.type == .variable_end) {
                                        filter_with_param = try allocator.dupe(u8, filter_token.lexeme);
                                        need_free = true;
                                    } else {
                                        return error.ExpectedVariableEnd;
                                    }
                                    
                                    const filtered_ptr = try allocator.create(ast.Filtered);
                                    const expr_ptr = try allocator.create(ast.Expression);
                                    expr_ptr.* = if_var_expr;
                                    filtered_ptr.* = .{ .expr = expr_ptr, .filter = filter_with_param };
                                    try body.append(allocator, .{ .variable = ast.Expression{ .filtered = filtered_ptr } });
                                } else if (if_var_next.type == .variable_end) {
                                    try body.append(allocator, .{ .variable = if_var_expr });
                                } else {
                                    return error.ExpectedPipeOrVariableEnd;
                                }
                            } else if (if_token.type == .eof) {
                                return error.UnexpectedEof;
                            }
                        }
                        
                        // 检查是否有 elif 或 else
                        var elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0);
                        var elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0);
                        var else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
                        
                        // 检查是否有 elif 或 else
                        while (true) {
                            // 检查下一个 token 是否是 elif, else 或 endif
                            const next_tag = try lex.peek() orelse {
                                break;
                            };
                            
                            if (next_tag.type == .tag_start) {
                                // 跳过 tag_start
                                _ = try lex.next();
                                const keyword = try lex.next() orelse {
                                    break;
                                };
                                
                                if (keyword.type == .elif_kw) {
                                    // 解析 elif 条件
                                    const elif_cond_expr = try parseExpression(allocator, lex);
                                    
                                    var elif_condition = ast.Condition{ .var_path = "", .op = null, .literal = null };
                                    
                                    // 检查表达式类型
                                    switch (elif_cond_expr) {
                                        .variable => |path| {
                                            elif_condition.var_path = path;
                                        },
                                        else => return error.InvalidPrimary,
                                    }
                                    
                                    const elif_cond_next = try lex.next() orelse return error.UnexpectedEof;
                                    if (elif_cond_next.type == .operator) {
                                        elif_condition.op = try allocator.dupe(u8, elif_cond_next.lexeme);
                                        const elif_lit = try lex.next() orelse return error.UnexpectedEof;
                                        elif_condition.literal = try parseLiteral(allocator, elif_lit);
                                        const elif_end = try lex.next() orelse return error.UnexpectedEof;
                                        if (elif_end.type != .tag_end) return error.ExpectedTagEnd;
                                    } else if (elif_cond_next.type == .tag_end) {
                                        // no op
                                    } else {
                                        return error.ExpectedOperatorOrTagEnd;
                                    }
                                    
                                    try elif_conditions.append(allocator, elif_condition);
                                    
                                    // 手动解析 elif 主体，直到遇到 endif、elif 或 else
                                    var elif_body_nodes = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
                                    while (true) {
                                        const elif_token = try lex.next() orelse return error.UnexpectedEof;
                                        
                                        if (elif_token.type == .tag_start) {
                                            // 检查下一个 token 是否是 elif、else 或 endif
                                            const peek_token = try lex.peek() orelse return error.UnexpectedEof;
                                            if (peek_token.type == .elif_kw or peek_token.type == .else_kw or peek_token.type == .endif_kw) {
                                                // 恢复 lexer 状态，让外层处理这些标签
                                                lex.current -= 1; // 回退 tag_start
                                                break;
                                            }
                                            
                                            // 不是 elif、else 或 endif，继续解析
                                            const elif_tag_token = try lex.next() orelse return error.UnexpectedEof;
                                            
                                            // 处理 elif_tag_token
                                            // 这里需要复制 parse 函数中的逻辑来处理各种标签
                                            // 为了简化，我们暂时只处理 text 和 variable
                                            if (elif_tag_token.type == .for_kw) {
                                                // 处理 for 循环
                                                const item_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (item_token.type != .identifier) return error.ExpectedIdentifier;
                                                const in_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (in_token.type != .in_kw) return error.ExpectedIn;
                                                const iterable_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (iterable_token.type != .identifier) return error.ExpectedIdentifier;
                                                
                                                const next_after_iterable = try lex.next() orelse return error.UnexpectedEof;
                                                var iterable_filter: ?[]const u8 = null;
                                                if (next_after_iterable.type == .pipe) {
                                                    const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                                    iterable_filter = try allocator.dupe(u8, filter_token.lexeme);
                                                    const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                    if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                } else if (next_after_iterable.type == .tag_end) {
                                                    // 没有过滤器
                                                } else {
                                                    return error.ExpectedTagEnd;
                                                }
                                                
                                                const nested_elif_for_body = try parse(allocator, lex, .endfor_kw);
                                                try elif_body_nodes.append(allocator, .{ .for_loop = .{
                                                    .item_var = try allocator.dupe(u8, item_token.lexeme),
                                                    .iterable_var = try allocator.dupe(u8, iterable_token.lexeme),
                                                    .iterable_filter = iterable_filter,
                                                    .body = nested_elif_for_body,
                                                } });
                                            } else if (elif_tag_token.type == .if_kw) {
                                                // 处理嵌套 if
                                                const elif_expr = try parseExpression(allocator, lex);
                                                
                                                var nested_elif_condition = ast.Condition{ .var_path = "", .op = null, .literal = null };
                                                
                                                switch (elif_expr) {
                                                    .variable => |path| {
                                                        nested_elif_condition.var_path = path;
                                                    },
                                                    else => return error.InvalidPrimary,
                                                }
                                                
                                                const elif_next_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (elif_next_token.type == .operator) {
                                                    nested_elif_condition.op = try allocator.dupe(u8, elif_next_token.lexeme);
                                                    const lit_token = try lex.next() orelse return error.UnexpectedEof;
                                                    nested_elif_condition.literal = try parseLiteral(allocator, lit_token);
                                                    const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                    if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                } else if (elif_next_token.type == .tag_end) {
                                                    // no op
                                                } else {
                                                    return error.ExpectedOperatorOrTagEnd;
                                                }
                                                
                                                const nested_elif_if_body = try parse(allocator, lex, .endif_kw);
                                                try elif_body_nodes.append(allocator, .{ .if_stmt = .{
                                                    .condition = nested_elif_condition,
                                                    .body = nested_elif_if_body,
                                                    .elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0),
                                                    .elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0),
                                                    .else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0),
                                                } });
                                            } else if (elif_tag_token.type == .set_kw) {
                                                // 处理 set
                                                const var_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (var_token.type != .identifier) return error.ExpectedIdentifier;
                                                const eq_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (eq_token.type != .operator or !std.mem.eql(u8, eq_token.lexeme, "=")) return error.ExpectedEquals;
                                                
                                                const value_expr = try parseExpression(allocator, lex);
                                                
                                                const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                
                                                try elif_body_nodes.append(allocator, .{ .set = .{
                                                    .var_name = try allocator.dupe(u8, var_token.lexeme),
                                                    .value = value_expr,
                                                } });
                                            } else {
                                                return error.UnexpectedToken;
                                            }
                                        } else if (elif_token.type == .text) {
                                            try elif_body_nodes.append(allocator, .{ .text = try allocator.dupe(u8, elif_token.lexeme) });
                                        } else if (elif_token.type == .variable_start) {
                                            const elif_var_expr = try parseExpression(allocator, lex);
                                            const elif_var_next = try lex.next() orelse return error.UnexpectedEof;
                                            if (elif_var_next.type == .pipe) {
                                                const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                                
                                                const param_token = try lex.next() orelse return error.UnexpectedEof;
                                                var filter_with_param = filter_token.lexeme;
                                                var need_free = false;
                                                if (param_token.type == .operator and std.mem.eql(u8, param_token.lexeme, ":")) {
                                                    const arg_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (arg_token.type == .string or arg_token.type == .number) {
                                                        const full_filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{filter_token.lexeme, arg_token.lexeme});
                                                        filter_with_param = full_filter;
                                                        need_free = true;
                                                    }
                                                    const end_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (end_token.type != .variable_end) return error.ExpectedVariableEnd;
                                                } else if (param_token.type == .variable_end) {
                                                    filter_with_param = try allocator.dupe(u8, filter_token.lexeme);
                                                    need_free = true;
                                                } else {
                                                    return error.ExpectedVariableEnd;
                                                }
                                                
                                                const filtered_ptr = try allocator.create(ast.Filtered);
                                                const expr_ptr = try allocator.create(ast.Expression);
                                                expr_ptr.* = elif_var_expr;
                                                filtered_ptr.* = .{ .expr = expr_ptr, .filter = filter_with_param };
                                                try elif_body_nodes.append(allocator, .{ .variable = ast.Expression{ .filtered = filtered_ptr } });
                                            } else if (elif_var_next.type == .variable_end) {
                                                try elif_body_nodes.append(allocator, .{ .variable = elif_var_expr });
                                            } else {
                                                return error.ExpectedPipeOrVariableEnd;
                                            }
                                        } else if (elif_token.type == .eof) {
                                            return error.UnexpectedEof;
                                        }
                                    }
                                    
                                    try elif_bodies.append(allocator, elif_body_nodes);
                                } else if (keyword.type == .else_kw) {
                                    // 解析 else 分支
                                    const else_end = try lex.next() orelse return error.UnexpectedEof;
                                    if (else_end.type != .tag_end) return error.ExpectedTagEnd;
                                    
                                    // 手动解析 else 主体，直到遇到 endif
                                    var else_body_nodes = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
                                    while (true) {
                                        const else_token = try lex.next() orelse return error.UnexpectedEof;
                                        
                                        if (else_token.type == .tag_start) {
                                            // 检查下一个 token 是否是 endif
                                            const peek_token = try lex.peek() orelse return error.UnexpectedEof;
                                            if (peek_token.type == .endif_kw) {
                                                // 恢复 lexer 状态，让外层处理 endif
                                                lex.current -= 1; // 回退 tag_start
                                                break;
                                            }
                                            
                                            // 不是 endif，继续解析
                                            const else_tag_token = try lex.next() orelse return error.UnexpectedEof;
                                            
                                            // 处理 else_tag_token
                                            // 这里需要复制 parse 函数中的逻辑来处理各种标签
                                            // 为了简化，我们暂时只处理 text 和 variable
                                            if (else_tag_token.type == .for_kw) {
                                                // 处理 for 循环
                                                const item_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (item_token.type != .identifier) return error.ExpectedIdentifier;
                                                const in_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (in_token.type != .in_kw) return error.ExpectedIn;
                                                const iterable_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (iterable_token.type != .identifier) return error.ExpectedIdentifier;
                                                
                                                const next_after_iterable = try lex.next() orelse return error.UnexpectedEof;
                                                var iterable_filter: ?[]const u8 = null;
                                                if (next_after_iterable.type == .pipe) {
                                                    const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                                    iterable_filter = try allocator.dupe(u8, filter_token.lexeme);
                                                    const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                    if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                } else if (next_after_iterable.type == .tag_end) {
                                                    // 没有过滤器
                                                } else {
                                                    return error.ExpectedTagEnd;
                                                }
                                                
                                                const nested_else_for_body = try parse(allocator, lex, .endfor_kw);
                                                try else_body_nodes.append(allocator, .{ .for_loop = .{
                                                    .item_var = try allocator.dupe(u8, item_token.lexeme),
                                                    .iterable_var = try allocator.dupe(u8, iterable_token.lexeme),
                                                    .iterable_filter = iterable_filter,
                                                    .body = nested_else_for_body,
                                                } });
                                            } else if (else_tag_token.type == .if_kw) {
                                                // 处理嵌套 if
                                                const else_expr = try parseExpression(allocator, lex);
                                                
                                                var else_condition = ast.Condition{ .var_path = "", .op = null, .literal = null };
                                                
                                                switch (else_expr) {
                                                    .variable => |path| {
                                                        else_condition.var_path = path;
                                                    },
                                                    else => return error.InvalidPrimary,
                                                }
                                                
                                                const else_next_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (else_next_token.type == .operator) {
                                                    else_condition.op = try allocator.dupe(u8, else_next_token.lexeme);
                                                    const lit_token = try lex.next() orelse return error.UnexpectedEof;
                                                    else_condition.literal = try parseLiteral(allocator, lit_token);
                                                    const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                    if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                } else if (else_next_token.type == .tag_end) {
                                                    // no op
                                                } else {
                                                    return error.ExpectedOperatorOrTagEnd;
                                                }
                                                
                                                const nested_else_if_body = try parse(allocator, lex, .endif_kw);
                                                try else_body_nodes.append(allocator, .{ .if_stmt = .{
                                                    .condition = else_condition,
                                                    .body = nested_else_if_body,
                                                    .elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0),
                                                    .elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0),
                                                    .else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0),
                                                } });
                                            } else if (else_tag_token.type == .set_kw) {
                                                // 处理 set
                                                const var_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (var_token.type != .identifier) return error.ExpectedIdentifier;
                                                const eq_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (eq_token.type != .operator or !std.mem.eql(u8, eq_token.lexeme, "=")) return error.ExpectedEquals;
                                                
                                                const value_expr = try parseExpression(allocator, lex);
                                                
                                                const tag_end = try lex.next() orelse return error.UnexpectedEof;
                                                if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                                                
                                                try else_body_nodes.append(allocator, .{ .set = .{
                                                    .var_name = try allocator.dupe(u8, var_token.lexeme),
                                                    .value = value_expr,
                                                } });
                                            } else {
                                                return error.UnexpectedToken;
                                            }
                                        } else if (else_token.type == .text) {
                                            try else_body_nodes.append(allocator, .{ .text = try allocator.dupe(u8, else_token.lexeme) });
                                        } else if (else_token.type == .variable_start) {
                                            const else_var_expr = try parseExpression(allocator, lex);
                                            const else_var_next = try lex.next() orelse return error.UnexpectedEof;
                                            if (else_var_next.type == .pipe) {
                                                const filter_token = try lex.next() orelse return error.UnexpectedEof;
                                                if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                                                
                                                const param_token = try lex.next() orelse return error.UnexpectedEof;
                                                var filter_with_param = filter_token.lexeme;
                                                var need_free = false;
                                                if (param_token.type == .operator and std.mem.eql(u8, param_token.lexeme, ":")) {
                                                    const arg_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (arg_token.type == .string or arg_token.type == .number) {
                                                        const full_filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{filter_token.lexeme, arg_token.lexeme});
                                                        filter_with_param = full_filter;
                                                        need_free = true;
                                                    }
                                                    const end_token = try lex.next() orelse return error.UnexpectedEof;
                                                    if (end_token.type != .variable_end) return error.ExpectedVariableEnd;
                                                } else if (param_token.type == .variable_end) {
                                                    filter_with_param = try allocator.dupe(u8, filter_token.lexeme);
                                                    need_free = true;
                                                } else {
                                                    return error.ExpectedVariableEnd;
                                                }
                                                
                                                const filtered_ptr = try allocator.create(ast.Filtered);
                                                const expr_ptr = try allocator.create(ast.Expression);
                                                expr_ptr.* = else_var_expr;
                                                filtered_ptr.* = .{ .expr = expr_ptr, .filter = filter_with_param };
                                                try else_body_nodes.append(allocator, .{ .variable = ast.Expression{ .filtered = filtered_ptr } });
                                            } else if (else_var_next.type == .variable_end) {
                                                try else_body_nodes.append(allocator, .{ .variable = else_var_expr });
                                            } else {
                                                return error.ExpectedPipeOrVariableEnd;
                                            }
                                        } else if (else_token.type == .eof) {
                                            return error.UnexpectedEof;
                                        }
                                    }
                                    
                                    else_body = else_body_nodes;
                                    break;
                                } else if (keyword.type == .endif_kw) {
                                    // 恢复状态，让外层处理 endif
                                    lex.current -= 1; // 回退 endif_kw
                                    lex.current -= 1; // 回退 tag_start
                                    break;
                                } else {
                                    // 其他关键字，恢复状态并退出
                                    lex.current -= 1; // 回退 keyword
                                    lex.current -= 1; // 回退 tag_start
                                    break;
                                }
                            } else {
                                // 不是 tag_start，恢复状态并退出
                                break;
                            }
                        }
                        
                        // 解析 endif
                        // 暂时跳过，因为 parse 可能已经消耗了它
                        // TODO: 修复这个问题
                        
                        try nodes.append(allocator, .{ .if_stmt = .{
                            .condition = condition,
                            .body = body,
                            .elif_conditions = elif_conditions,
                            .elif_bodies = elif_bodies,
                            .else_body = else_body,
                        } });
                    },
                    .extends_kw => {
                        const template_token = try lex.next() orelse return error.UnexpectedEof;
                        if (template_token.type != .string) return error.ExpectedString;
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        try nodes.append(allocator, .{ .extends = .{
                            .template_name = try allocator.dupe(u8, template_token.lexeme),
                        } });
                    },
                    .block_kw => {
                        const name_token = try lex.next() orelse return error.UnexpectedEof;
                        if (name_token.type != .identifier) return error.ExpectedIdentifier;
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        const body = try parse(allocator, lex, .endblock_kw);
                        try nodes.append(allocator, .{ .block = .{
                            .name = try allocator.dupe(u8, name_token.lexeme),
                            .body = body,
                        } });
                    },
                    .include_kw => {
                        const template_token = try lex.next() orelse return error.UnexpectedEof;
                        if (template_token.type != .string) return error.ExpectedString;
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        try nodes.append(allocator, .{ .include = .{
                            .template_name = try allocator.dupe(u8, template_token.lexeme),
                        } });
                    },
                    .macro_kw => {
                        const name_token = try lex.next() orelse return error.UnexpectedEof;
                        if (name_token.type != .identifier) return error.ExpectedIdentifier;
                        
                        // 解析参数列表
                        var params = try std.ArrayList([]const u8).initCapacity(allocator, 0);
                        const next_token = try lex.next() orelse return error.UnexpectedEof;
                        if (next_token.type == .operator and std.mem.eql(u8, next_token.lexeme, "(")) {
                            while (true) {
                                const param_token = try lex.next() orelse return error.UnexpectedEof;
                                if (param_token.type == .operator and std.mem.eql(u8, param_token.lexeme, ")")) break;
                                if (param_token.type != .identifier) return error.ExpectedIdentifier;
                                try params.append(allocator, try allocator.dupe(u8, param_token.lexeme));
                                
                                const sep = try lex.next() orelse return error.UnexpectedEof;
                                if (sep.type == .operator and std.mem.eql(u8, sep.lexeme, ")")) break;
                                if (!(sep.type == .operator and std.mem.eql(u8, sep.lexeme, ","))) return error.ExpectedComma;
                            }
                            const tag_end = try lex.next() orelse return error.UnexpectedEof;
                            if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        } else if (next_token.type == .tag_end) {
                            // 无参数
                        } else {
                            return error.ExpectedTagEnd;
                        }
                        
                        const body = try parse(allocator, lex, .endmacro_kw);
                        try nodes.append(allocator, .{ .macro = .{
                            .name = try allocator.dupe(u8, name_token.lexeme),
                            .params = params,
                            .body = body,
                        } });
                    },
                    .from_kw => {
                        const template_token = try lex.next() orelse return error.UnexpectedEof;
                        if (template_token.type != .string) return error.ExpectedString;
                        const import_token = try lex.next() orelse return error.UnexpectedEof;
                        if (import_token.type != .import_kw) return error.ExpectedImport;
                        
                        // 解析宏名称列表
                        var macro_names = try std.ArrayList([]const u8).initCapacity(allocator, 0);
                        const name_token = try lex.next() orelse return error.UnexpectedEof;
                        if (name_token.type != .identifier) return error.ExpectedIdentifier;
                        try macro_names.append(allocator, try allocator.dupe(u8, name_token.lexeme));
                        
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        
                        try nodes.append(allocator, .{ .import = .{
                            .template_name = try allocator.dupe(u8, template_token.lexeme),
                            .macro_names = macro_names,
                        } });
                    },
                    .set_kw => {
                        const var_token = try lex.next() orelse return error.UnexpectedEof;
                        if (var_token.type != .identifier) return error.ExpectedIdentifier;
                        
                        const op_token = try lex.next() orelse return error.UnexpectedEof;
                        if (!(op_token.type == .operator and std.mem.eql(u8, op_token.lexeme, "="))) {
                            return error.ExpectedEquals;
                        }
                        
                        // 解析值表达式
                        const value_expr = try parseExpression(allocator, lex);
                        
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        
                        try nodes.append(allocator, .{ .set = .{
                            .var_name = try allocator.dupe(u8, var_token.lexeme),
                            .value = value_expr,
                        } });
                    },
                    .endif_kw, .elif_kw, .else_kw => {
                        // 这些标签应该在 peek 阶段被处理，如果到达这里，说明有错误
                        return error.UnexpectedToken;
                    },
                    else => return error.UnexpectedToken,
                }
            },
            .eof => if (stop_on == null) return nodes else return error.UnexpectedEof,
            else => return error.UnexpectedToken,
        }
    }
    if (stop_on != null) return error.UnexpectedEof;
    return nodes;
}

fn parseLiteral(allocator: std.mem.Allocator, token: lexer.Token) !std.json.Value {
    switch (token.type) {
        .string => return std.json.Value{ .string = try allocator.dupe(u8, token.lexeme[1 .. token.lexeme.len - 1]) },
        .number => {
            if (std.mem.indexOf(u8, token.lexeme, ".")) |_| {
                const f = try std.fmt.parseFloat(f64, token.lexeme);
                return std.json.Value{ .float = f };
            } else {
                const i = try std.fmt.parseInt(i64, token.lexeme, 10);
                return std.json.Value{ .integer = i };
            }
        },
        .identifier => {
            if (std.mem.eql(u8, token.lexeme, "true")) return std.json.Value{ .bool = true };
            if (std.mem.eql(u8, token.lexeme, "false")) return std.json.Value{ .bool = false };
            return error.InvalidLiteral;
        },
        else => return error.InvalidLiteral,
    }
}

fn parsePrimary(allocator: std.mem.Allocator, lex: *lexer.Lexer) error{UnexpectedEof,ExpectedIdentifier,ExpectedIn,ExpectedTagEnd,ExpectedVariableEnd,ExpectedPipeOrVariableEnd,InvalidLiteral,ExpectedOperatorOrTagEnd,ExpectedComma,InvalidPrimary,UnterminatedString,OutOfMemory,InvalidCharacter,Overflow}!ast.Expression {

        const token = try lex.next() orelse return error.UnexpectedEof;
    switch (token.type) {
        .identifier => {
            if (std.mem.eql(u8, token.lexeme, "true")) return ast.Expression{ .literal = std.json.Value{ .bool = true } };
            if (std.mem.eql(u8, token.lexeme, "false")) return ast.Expression{ .literal = std.json.Value{ .bool = false } };
            const peeked = try lex.peek();
            if (peeked != null and peeked.?.type == .operator and peeked.?.lexeme[0] == '(') {
                _ = try lex.next(); // consume (
                var args = try std.ArrayList(*const ast.Expression).initCapacity(allocator, 0);
                while (true) {
                    const arg = try parseExpression(allocator, lex);
                    const arg_ptr = try allocator.create(ast.Expression);
                    arg_ptr.* = arg;
                    try args.append(allocator, @ptrCast(arg_ptr));
                    const sep = try lex.next() orelse return error.UnexpectedEof;
                    if (sep.type == .operator and sep.lexeme[0] == ')') break;
                    if (!(sep.type == .operator and sep.lexeme[0] == ',')) return error.ExpectedComma;
                }
                const fc = try allocator.create(ast.FunctionCall);
                fc.* = .{ .name = try allocator.dupe(u8, token.lexeme), .args = args };
                return ast.Expression{ .function_call = fc };
            } else {
                // 检查是否是路径变量（如 loop.index）
                var path = try std.ArrayList(u8).initCapacity(allocator, token.lexeme.len);
                try path.appendSlice(allocator, token.lexeme);
                
                // 检查后续的 .identifier
                while (true) {
                    const next_peek = try lex.peek();
                    if (next_peek != null and next_peek.?.type == .operator and std.mem.eql(u8, next_peek.?.lexeme, ".")) {
                        _ = try lex.next(); // consume .
                        const next_token = try lex.next() orelse return error.UnexpectedEof;
                        if (next_token.type != .identifier) return error.ExpectedIdentifier;
                        try path.append(allocator, '.');
                        try path.appendSlice(allocator, next_token.lexeme);
                    } else {
                        break;
                    }
                }
                
                return ast.Expression{ .variable = try path.toOwnedSlice(allocator) };
            }
        },
        .string => return ast.Expression{ .literal = std.json.Value{ .string = try allocator.dupe(u8, token.lexeme) } },
        .number => {
            const num = try std.fmt.parseInt(i64, token.lexeme, 10);
            return ast.Expression{ .literal = std.json.Value{ .integer = num } };
        },
        else => {
            if (std.mem.eql(u8, token.lexeme, "true")) return ast.Expression{ .literal = std.json.Value{ .bool = true } };
            if (std.mem.eql(u8, token.lexeme, "false")) return ast.Expression{ .literal = std.json.Value{ .bool = false } };
            if (token.type == .identifier) return ast.Expression{ .variable = try allocator.dupe(u8, token.lexeme) };
            return error.InvalidPrimary;
        },
    }
}

fn parseExpression(allocator: std.mem.Allocator, lex: *lexer.Lexer) error{UnexpectedEof,ExpectedIdentifier,ExpectedIn,ExpectedTagEnd,ExpectedVariableEnd,ExpectedPipeOrVariableEnd,InvalidLiteral,ExpectedOperatorOrTagEnd,ExpectedComma,InvalidPrimary,UnterminatedString,OutOfMemory,InvalidCharacter,Overflow}!ast.Expression {
    var left = try parsePrimary(allocator, lex);
    
    // 检查是否有二元操作符
    while (true) {
        const peeked = try lex.peek();
        if (peeked != null and peeked.?.type == .operator) {
            const op_token = peeked.?;
            // 检查是否是二元操作符
            if (std.mem.eql(u8, op_token.lexeme, "+") or 
                std.mem.eql(u8, op_token.lexeme, "-") or 
                std.mem.eql(u8, op_token.lexeme, "*") or 
                std.mem.eql(u8, op_token.lexeme, "/")) {
                _ = try lex.next(); // consume operator
                const right = try parsePrimary(allocator, lex);
                
                const binary_expr = try allocator.create(ast.BinaryExpression);
                const left_ptr = try allocator.create(ast.Expression);
                left_ptr.* = left;
                const right_ptr = try allocator.create(ast.Expression);
                right_ptr.* = right;
                binary_expr.* = .{
                    .left = left_ptr,
                    .op = try allocator.dupe(u8, op_token.lexeme),
                    .right = right_ptr,
                };
                left = ast.Expression{ .binary = binary_expr };
            } else {
                break;
            }
        } else {
            break;
        }
    }
    
    return left;
}

fn freeExpression(allocator: std.mem.Allocator, expr: ast.Expression) void {
    switch (expr) {
        .literal => |lit| if (lit == .string) allocator.free(lit.string),
        .variable => |v| allocator.free(v),
        .binary => |bin| {
            freeExpression(allocator, bin.left.*);
            allocator.destroy(bin.left);
            freeExpression(allocator, bin.right.*);
            allocator.destroy(bin.right);
            allocator.free(bin.op);
            allocator.destroy(bin);
        },
        .function_call => |fc| {
                            allocator.free(fc.name);
                            for (fc.args.items) |arg| {
                                freeExpression(allocator, arg.*);
                                allocator.destroy(arg);
                            }
                            fc.args.deinit(allocator);
                            allocator.destroy(fc);
                        },        .filtered => |f| {
            freeExpression(allocator, f.expr.*);
            allocator.destroy(f.expr);
            // filter 字符串可能指向 token.lexeme，不释放
            allocator.destroy(f);
        },
    }
}

pub fn freeAst(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node)) void {
    for (nodes.items) |node| {
        switch (node) {
            .text => |t| allocator.free(t),

            .variable => |v| freeExpression(allocator, v),

            .for_loop => |f| {
                allocator.free(f.item_var);

                allocator.free(f.iterable_var);

                freeAst(allocator, f.body);

                @constCast(&f.body).deinit(allocator);
            },

            .if_stmt => |i| {
                allocator.free(i.condition.var_path);
                if (i.condition.op) |op| allocator.free(op);
                if (i.condition.literal) |lit| {
                    if (lit == .string) allocator.free(lit.string);
                }
                freeAst(allocator, i.body);
                @constCast(&i.body).deinit(allocator);
                
                // 清理 elif 分支
                for (i.elif_conditions.items) |elif_cond| {
                    allocator.free(elif_cond.var_path);
                    if (elif_cond.op) |op| allocator.free(op);
                    if (elif_cond.literal) |lit| {
                        if (lit == .string) allocator.free(lit.string);
                    }
                }
                @constCast(&i.elif_conditions).deinit(allocator);
                
                for (i.elif_bodies.items) |elif_body| {
                    freeAst(allocator, elif_body);
                    @constCast(&elif_body).deinit(allocator);
                }
                @constCast(&i.elif_bodies).deinit(allocator);
                
                freeAst(allocator, i.else_body);
                @constCast(&i.else_body).deinit(allocator);
            },

            .set => |s| {
                allocator.free(s.var_name);
                freeExpression(allocator, s.value);
            },
            .extends => |e| {
                allocator.free(e.template_name);
            },
            .block => |b| {
                allocator.free(b.name);
                freeAst(allocator, b.body);
                @constCast(&b.body).deinit(allocator);
            },
            .include => |i| {
                allocator.free(i.template_name);
            },
            .macro => |m| {
                allocator.free(m.name);
                for (m.params.items) |param| {
                    allocator.free(param);
                }
                @constCast(&m.params).deinit(allocator);
                freeAst(allocator, m.body);
                @constCast(&m.body).deinit(allocator);
            },
            .import => |i| {
                allocator.free(i.template_name);
                for (i.macro_names.items) |name| {
                    allocator.free(name);
                }
                @constCast(&i.macro_names).deinit(allocator);
            },
            .parent => {},
        }
    }

    @constCast(&nodes).deinit(allocator);
}
