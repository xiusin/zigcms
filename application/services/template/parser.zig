const std = @import("std");

const lexer = @import("lexer.zig");

const ast = @import("ast.zig");

pub fn parse(allocator: std.mem.Allocator, lex: *lexer.Lexer, stop_on: ?lexer.TokenType) !std.ArrayList(ast.Node) {
    var nodes = std.ArrayList(ast.Node).init(allocator);
    while (try lex.next()) |token| {
        switch (token.type) {
            .text => {
                try nodes.append(.{ .text = try allocator.dupe(u8, token.lexeme) });
            },
            .variable_start => {
                const expr = try parseExpression(allocator, lex);
                const next_token = try lex.next() orelse return error.UnexpectedEof;
                if (next_token.type == .pipe) {
                    const filter_token = try lex.next() orelse return error.UnexpectedEof;
                    if (filter_token.type != .identifier) return error.ExpectedIdentifier;
                    const filtered_ptr = try allocator.create(ast.Filtered);
                    const expr_ptr = try allocator.create(ast.Expression);
                    expr_ptr.* = expr;
                    filtered_ptr.* = .{ .expr = expr_ptr, .filter = try allocator.dupe(u8, filter_token.lexeme) };
                    const end_token = try lex.next() orelse return error.UnexpectedEof;
                    if (end_token.type != .variable_end) return error.ExpectedVariableEnd;
                    try nodes.append(.{ .variable = ast.Expression{ .filtered = filtered_ptr } });
                } else if (next_token.type == .variable_end) {
                    try nodes.append(.{ .variable = expr });
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
                        const tag_end = try lex.next() orelse return error.UnexpectedEof;
                        if (tag_end.type != .tag_end) return error.ExpectedTagEnd;
                        const body = try parse(allocator, lex, .endfor_kw);
                        try nodes.append(.{ .for_loop = .{
                            .item_var = try allocator.dupe(u8, item_token.lexeme),
                            .iterable_var = try allocator.dupe(u8, iterable_token.lexeme),
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
                        const body = try parse(allocator, lex, .endif_kw);
                        try nodes.append(.{ .if_stmt = .{
                            .condition = condition,
                            .body = body,
                            .else_body = std.ArrayList(ast.Node).init(allocator),
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

fn parsePrimary(allocator: std.mem.Allocator, lex: *lexer.Lexer) !ast.Expression {
    const token = try lex.next() orelse return error.UnexpectedEof;
    switch (token.type) {
        .identifier => {
            const peeked = try lex.peek();
            if (peeked != null and peeked.?.type == .operator and peeked.?.lexeme[0] == '(') {
                _ = try lex.next(); // consume (
                var args = std.ArrayList(*ast.Expression).init(allocator);
                while (true) {
                    const arg = try parseExpression(allocator, lex);
                    const arg_ptr = try allocator.create(ast.Expression);
                    arg_ptr.* = arg;
                    try args.append(arg_ptr);
                    const sep = try lex.next() orelse return error.UnexpectedEof;
                    if (sep.type == .operator and sep.lexeme[0] == ')') break;
                    if (!(sep.type == .operator and sep.lexeme[0] == ',')) return error.ExpectedComma;
                }
                return ast.Expression{ .function_call = try allocator.create(FunctionCall) };
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

fn parseExpression(allocator: std.mem.Allocator, lex: *lexer.Lexer) !ast.Expression {
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
            fc.args.deinit();
            allocator.destroy(fc);
        },
        .filtered => |f| {
            freeExpression(allocator, f.expr.*);
            allocator.destroy(f.expr);
            allocator.free(f.filter);
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

                f.body.deinit();
            },

            .if_stmt => |i| {
                allocator.free(i.condition.var_path);
                if (i.condition.op) |op| allocator.free(op);
                if (i.condition.literal) |lit| {
                    if (lit == .string) allocator.free(lit.string);
                }
                freeAst(allocator, i.body);
                i.body.deinit();
                freeAst(allocator, i.else_body);
                i.else_body.deinit();
            },

            .set => |s| {
                allocator.free(s.var_name);

                allocator.free(s.value);
            },
        }
    }

    nodes.deinit();
}
