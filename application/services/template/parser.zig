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
                        if (arg_token.type == .string) {
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
                        const var_token = try lex.next() orelse return error.UnexpectedEof;
                        if (var_token.type != .identifier) return error.ExpectedIdentifier;
                        var condition = ast.Condition{ .var_path = try allocator.dupe(u8, var_token.lexeme) };
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
                        
                        // 解析 if 主体
                        const body = try parse(allocator, lex, null);
                        
                        // 解析 elif 和 else 分支
                        var elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0);
                        var elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0);
                        var else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
                        
                        // 检查是否有 elif 或 else
                        while (true) {
                            // 检查下一个 token 是否是 elif, else 或 endif
                            const saved_start = lex.start;
                            const saved_current = lex.current;
                            const saved_line = lex.line;
                            const saved_state = lex.state;
                            
                            const next_tag = try lex.peek() orelse {
                                lex.start = saved_start;
                                lex.current = saved_current;
                                lex.line = saved_line;
                                lex.state = saved_state;
                                break;
                            };
                            
                            if (next_tag.type == .tag_start) {
                                // 跳过 tag_start
                                _ = try lex.next();
                                const keyword = try lex.next() orelse {
                                    lex.start = saved_start;
                                    lex.current = saved_current;
                                    lex.line = saved_line;
                                    lex.state = saved_state;
                                    break;
                                };
                                
                                if (keyword.type == .elif_kw) {
                                    // 解析 elif 条件
                                    const elif_var_token = try lex.next() orelse return error.UnexpectedEof;
                                    if (elif_var_token.type != .identifier) return error.ExpectedIdentifier;
                                    var elif_condition = ast.Condition{ .var_path = try allocator.dupe(u8, elif_var_token.lexeme) };
                                    
                                    const elif_next = try lex.next() orelse return error.UnexpectedEof;
                                    if (elif_next.type == .operator) {
                                        elif_condition.op = try allocator.dupe(u8, elif_next.lexeme);
                                        const elif_lit = try lex.next() orelse return error.UnexpectedEof;
                                        elif_condition.literal = try parseLiteral(allocator, elif_lit);
                                        const elif_end = try lex.next() orelse return error.UnexpectedEof;
                                        if (elif_end.type != .tag_end) return error.ExpectedTagEnd;
                                    } else if (elif_next.type == .tag_end) {
                                        // no op
                                    } else {
                                        return error.ExpectedOperatorOrTagEnd;
                                    }
                                    
                                    try elif_conditions.append(allocator, elif_condition);
                                    
                                    // 解析 elif 主体
                                    const elif_body = try parse(allocator, lex, null);
                                    try elif_bodies.append(allocator, elif_body);
                                } else if (keyword.type == .else_kw) {
                                    // 解析 else 分支
                                    const else_end = try lex.next() orelse return error.UnexpectedEof;
                                    if (else_end.type != .tag_end) return error.ExpectedTagEnd;
                                    
                                    else_body = try parse(allocator, lex, null);
                                    break;
                                } else if (keyword.type == .endif_kw) {
                                    // 恢复状态，让外层处理 endif
                                    lex.start = saved_start;
                                    lex.current = saved_current;
                                    lex.line = saved_line;
                                    lex.state = saved_state;
                                    break;
                                } else {
                                    // 其他关键字，恢复状态并退出
                                    lex.start = saved_start;
                                    lex.current = saved_current;
                                    lex.line = saved_line;
                                    lex.state = saved_state;
                                    break;
                                }
                            } else {
                                // 不是 tag_start，恢复状态并退出
                                lex.start = saved_start;
                                lex.current = saved_current;
                                lex.line = saved_line;
                                lex.state = saved_state;
                                break;
                            }
                        }
                        
                        // 解析 endif
                        _ = try parse(allocator, lex, .endif_kw);
                        
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
                return ast.Expression{ .variable = try allocator.dupe(u8, token.lexeme) };
            }
        },
        .string => return ast.Expression{ .literal = std.json.Value{ .string = try allocator.dupe(u8, token.lexeme[1 .. token.lexeme.len - 1]) } },
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
    return parsePrimary(allocator, lex);
}

fn freeExpression(allocator: std.mem.Allocator, expr: ast.Expression) void {
    switch (expr) {
        .literal => |lit| if (lit == .string) allocator.free(lit.string),
        .variable => |v| allocator.free(v),
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
