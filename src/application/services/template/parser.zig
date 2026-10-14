const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const ParseError = error{
    UnexpectedEof,
    UnexpectedToken,
    ExpectedIdentifier,
    ExpectedIn,
    ExpectedTagEnd,
    ExpectedVariableEnd,
    ExpectedPipeOrVariableEnd,
    ExpectedString,
    ExpectedEquals,
    ExpectedComma,
    ExpectedImport,
    InvalidLiteral,
    InvalidPrimary,
    InvalidIterable,
    UnterminatedString,
    OutOfMemory,
    InvalidCharacter,
    Overflow,
};

const ParseResult = struct {
    nodes: std.ArrayList(ast.Node),
    stop: ?lexer.TokenType,
};

/// 兼容旧签名：解析到 stop_on 指定的块级结束标签（含 %} 一起消耗），顶层传 null
pub fn parse(allocator: std.mem.Allocator, lex: *lexer.Lexer, stop_on: ?lexer.TokenType) ParseError!std.ArrayList(ast.Node) {
    if (stop_on) |t| {
        const r = try parseUntil(allocator, lex, &.{t});
        if (r.stop == null) return error.UnexpectedEof;
        try expectTagEnd(lex);
        return r.nodes;
    }
    const r = try parseUntil(allocator, lex, &.{});
    return r.nodes;
}

/// 解析节点序列，直到遇到 stop_types 中的块级结束标签（该标签连同 %} 被消耗后返回）。
/// 结束标签由当前层级自己消化，绝不回退 lexer 状态。
pub fn parseUntil(allocator: std.mem.Allocator, lex: *lexer.Lexer, stop_types: []const lexer.TokenType) ParseError!ParseResult {
    var nodes = try std.ArrayList(ast.Node).initCapacity(allocator, 0);
    while (try lex.next()) |token| {
        switch (token.type) {
            .text => try nodes.append(allocator, .{ .text = try allocator.dupe(u8, token.lexeme) }),
            .variable_start => try nodes.append(allocator, .{ .variable = try parseVariableExpr(allocator, lex) }),
            .tag_start => {
                const tag_token = try lex.next() orelse return error.UnexpectedEof;
                if (tag_token.type == .eof) return error.UnexpectedEof;
                if (isStop(tag_token.type, stop_types)) {
                    // 只停在关键字上：%} 由调用方按 stop 类型消化（elif 后还有条件）
                    return .{ .nodes = nodes, .stop = tag_token.type };
                }
                switch (tag_token.type) {
                    .for_kw => try nodes.append(allocator, try parseFor(allocator, lex)),
                    .if_kw => try nodes.append(allocator, try parseIfChain(allocator, lex)),
                    .set_kw => try nodes.append(allocator, try parseSet(allocator, lex)),
                    .extends_kw => {
                        const name = try expectString(lex);
                        try expectTagEnd(lex);
                        try nodes.append(allocator, .{ .extends = .{ .template_name = try allocator.dupe(u8, name) } });
                    },
                    .include_kw => {
                        const name = try expectString(lex);

                        // 可选：with <dotted-path> [only]
                        var with_path: ?[]const u8 = null;
                        var only = false;
                        var t = try nextTok(lex);
                        if (t.type == .identifier and std.mem.eql(u8, t.lexeme, "with")) {
                            const first = try nextTok(lex);
                            if (first.type != .identifier) return error.ExpectedIdentifier;
                            with_path = try parseDottedPath(allocator, lex, first);
                            t = try nextTok(lex);
                        }
                        if (t.type == .identifier and std.mem.eql(u8, t.lexeme, "only")) {
                            only = true;
                            t = try nextTok(lex);
                        }
                        if (t.type != .tag_end) return error.ExpectedTagEnd;

                        try nodes.append(allocator, .{ .include = .{
                            .template_name = try allocator.dupe(u8, name),
                            .with_path = with_path,
                            .only = only,
                        } });
                    },
                    .block_kw => {
                        const name_token = try nextTok(lex);
                        if (name_token.type != .identifier) return error.ExpectedIdentifier;
                        try expectTagEnd(lex);
                        const body = try parseUntil(allocator, lex, &.{.endblock_kw});
                        if (body.stop == null) return error.UnexpectedEof;
                        try expectTagEnd(lex);
                        try nodes.append(allocator, .{ .block = .{
                            .name = try allocator.dupe(u8, name_token.lexeme),
                            .body = body.nodes,
                        } });
                    },
                    .macro_kw => {
                        const name_token = try nextTok(lex);
                        if (name_token.type != .identifier) return error.ExpectedIdentifier;
                        const params = try parseMacroParams(allocator, lex);
                        try expectTagEnd(lex);
                        const body = try parseUntil(allocator, lex, &.{.endmacro_kw});
                        if (body.stop == null) return error.UnexpectedEof;
                        try expectTagEnd(lex);
                        try nodes.append(allocator, .{ .macro = .{
                            .name = try allocator.dupe(u8, name_token.lexeme),
                            .params = params,
                            .body = body.nodes,
                        } });
                    },
                    .from_kw => {
                        const template_token = try nextTok(lex);
                        if (template_token.type != .string) return error.ExpectedString;
                        const import_token = try nextTok(lex);
                        if (import_token.type != .import_kw) return error.ExpectedImport;
                        var macro_names = try std.ArrayList([]const u8).initCapacity(allocator, 0);

                        const first = try nextTok(lex);
                        if (first.type == .operator and std.mem.eql(u8, first.lexeme, "*")) {
                            // import *：全部宏
                            try macro_names.append(allocator, try allocator.dupe(u8, "*"));
                            try expectTagEnd(lex);
                        } else {
                            if (first.type != .identifier) return error.ExpectedIdentifier;
                            try macro_names.append(allocator, try allocator.dupe(u8, first.lexeme));
                            // 逗号分隔的多个宏名
                            while (true) {
                                const p = (try lex.peek()) orelse return error.UnexpectedEof;
                                if (!(p.type == .operator and std.mem.eql(u8, p.lexeme, ","))) break;
                                _ = try nextTok(lex);
                                const n = try nextTok(lex);
                                if (n.type != .identifier) return error.ExpectedIdentifier;
                                try macro_names.append(allocator, try allocator.dupe(u8, n.lexeme));
                            }
                            try expectTagEnd(lex);
                        }

                        try nodes.append(allocator, .{ .import = .{
                            .template_name = try allocator.dupe(u8, template_token.lexeme),
                            .macro_names = macro_names,
                        } });
                    },
                    .parent_kw => {
                        try expectTagEnd(lex);
                        try nodes.append(allocator, .{ .parent = .{} });
                    },
                    .endfor_kw, .endif_kw, .else_kw, .elif_kw, .endblock_kw, .endmacro_kw => {
                        // 悬空的块级结束标签（没有对应的开标签）
                        return error.UnexpectedToken;
                    },
                    else => return error.UnexpectedToken,
                }
            },
            .eof => {
                if (stop_types.len == 0) return .{ .nodes = nodes, .stop = null };
                return error.UnexpectedEof;
            },
            else => return error.UnexpectedToken,
        }
    }
    if (stop_types.len == 0) return .{ .nodes = nodes, .stop = null };
    return error.UnexpectedEof;
}

fn nextTok(lex: *lexer.Lexer) ParseError!lexer.Token {
    const tok = (try lex.next()) orelse return error.UnexpectedEof;
    if (tok.type == .eof) return error.UnexpectedEof;
    return tok;
}

fn isStop(t: lexer.TokenType, stops: []const lexer.TokenType) bool {
    for (stops) |s| {
        if (s == t) return true;
    }
    return false;
}

fn expectTagEnd(lex: *lexer.Lexer) ParseError!void {
    const t = try nextTok(lex);
    if (t.type != .tag_end) return error.ExpectedTagEnd;
}

fn expectString(lex: *lexer.Lexer) ParseError![]const u8 {
    const t = try nextTok(lex);
    if (t.type != .string) return error.ExpectedString;
    return t.lexeme;
}

/// 从 token 构造字面量（string token 的 lexeme 已由 lexer 去引号）
fn literalFromToken(allocator: std.mem.Allocator, token: lexer.Token) ParseError!std.json.Value {
    switch (token.type) {
        .string => return std.json.Value{ .string = try allocator.dupe(u8, token.lexeme) },
        .number => {
            if (std.mem.indexOf(u8, token.lexeme, ".")) |_| {
                return std.json.Value{ .float = try std.fmt.parseFloat(f64, token.lexeme) };
            }
            return std.json.Value{ .integer = try std.fmt.parseInt(i64, token.lexeme, 10) };
        },
        .identifier => {
            if (std.mem.eql(u8, token.lexeme, "true")) return std.json.Value{ .bool = true };
            if (std.mem.eql(u8, token.lexeme, "false")) return std.json.Value{ .bool = false };
            return error.InvalidLiteral;
        },
        else => return error.InvalidLiteral,
    }
}

/// 点路径（a.b.c）：首 token 必须是 identifier
fn parseDottedPath(allocator: std.mem.Allocator, lex: *lexer.Lexer, first: lexer.Token) ParseError![]const u8 {
    var path = try std.ArrayList(u8).initCapacity(allocator, first.lexeme.len);
    try path.appendSlice(allocator, first.lexeme);
    while (true) {
        const p = try lex.peek();
        if (p != null and p.?.type == .operator and std.mem.eql(u8, p.?.lexeme, ".")) {
            _ = try nextTok(lex);
            const part = try nextTok(lex);
            if (part.type != .identifier) return error.ExpectedIdentifier;
            try path.append(allocator, '.');
            try path.appendSlice(allocator, part.lexeme);
        } else break;
    }
    return path.toOwnedSlice(allocator);
}

/// 变量输出：expr ( '|' filter (':' arg)? )* '}}'
fn parseVariableExpr(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Expression {
    var expr = try parseExpr(allocator, lex);
    while (true) {
        const t = try nextTok(lex);
        if (t.type == .variable_end) return expr;
        if (t.type != .pipe) return error.ExpectedPipeOrVariableEnd;

        const fname = try nextTok(lex);
        if (fname.type != .identifier) return error.ExpectedIdentifier;
        var filter: []const u8 = undefined;
        const arg_peek = try lex.peek();
        if (arg_peek != null and arg_peek.?.type == .operator and std.mem.eql(u8, arg_peek.?.lexeme, ":")) {
            _ = try nextTok(lex);
            const arg = try nextTok(lex);
            if (arg.type != .string and arg.type != .number) return error.InvalidLiteral;
            filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ fname.lexeme, arg.lexeme });
        } else {
            filter = try allocator.dupe(u8, fname.lexeme);
        }

        const expr_ptr = try allocator.create(ast.Expression);
        expr_ptr.* = expr;
        const filtered_ptr = try allocator.create(ast.Filtered);
        filtered_ptr.* = .{ .expr = expr_ptr, .filter = filter };
        expr = ast.Expression{ .filtered = filtered_ptr };
    }
}

/// 条件：identifier 路径 [ 比较符 字面量 ]
fn parseCondition(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Condition {
    const first = try nextTok(lex);
    if (first.type != .identifier) return error.InvalidPrimary;
    const var_path = try parseDottedPath(allocator, lex, first);

    var cond = ast.Condition{ .var_path = var_path };
    const p = try lex.peek();
    if (p != null and p.?.type == .operator) {
        const comparison_ops = [_][]const u8{ "==", "!=", "<", ">", "<=", ">=" };
        var matched = false;
        for (comparison_ops) |o| {
            if (std.mem.eql(u8, p.?.lexeme, o)) {
                matched = true;
                break;
            }
        }
        if (matched) {
            _ = try nextTok(lex);
            cond.op = try allocator.dupe(u8, p.?.lexeme);
            const lit = try nextTok(lex);
            cond.literal = try literalFromToken(allocator, lit);
        }
    }
    return cond;
}

/// if/elif/else/endif 整条链由本函数消化，endif 连同 %} 一起吃掉
fn parseIfChain(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Node {
    const condition = try parseCondition(allocator, lex);
    try expectTagEnd(lex);

    const branch_stops = [_]lexer.TokenType{ .elif_kw, .else_kw, .endif_kw };
    const first = try parseUntil(allocator, lex, &branch_stops);
    if (first.stop == null) return error.UnexpectedEof;
    const body = first.nodes;

    var elif_conditions = try std.ArrayList(ast.Condition).initCapacity(allocator, 0);
    var elif_bodies = try std.ArrayList(std.ArrayList(ast.Node)).initCapacity(allocator, 0);
    var else_body = try std.ArrayList(ast.Node).initCapacity(allocator, 0);

    var next_stop = first.stop.?;
    while (true) {
        if (next_stop == .endif_kw) {
            try expectTagEnd(lex);
            break;
        } else if (next_stop == .else_kw) {
            try expectTagEnd(lex);
            const r = try parseUntil(allocator, lex, &.{.endif_kw});
            if (r.stop == null) return error.UnexpectedEof;
            else_body = r.nodes;
            next_stop = r.stop.?;
        } else { // elif_kw
            const elif_cond = try parseCondition(allocator, lex);
            try expectTagEnd(lex);
            const r = try parseUntil(allocator, lex, &branch_stops);
            if (r.stop == null) return error.UnexpectedEof;
            try elif_conditions.append(allocator, elif_cond);
            try elif_bodies.append(allocator, r.nodes);
            next_stop = r.stop.?;
        }
    }

    return ast.Node{ .if_stmt = .{
        .condition = condition,
        .body = body,
        .elif_conditions = elif_conditions,
        .elif_bodies = elif_bodies,
        .else_body = else_body,
    } };
}

/// for 循环：支持 `x in y`、`k, v in obj`、`i in range(a, b)`、`x in y | filter[:arg]`、点路径可迭代
fn parseFor(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Node {
    const first = try nextTok(lex);
    if (first.type != .identifier) return error.ExpectedIdentifier;

    var key_var: ?[]const u8 = null;
    var item_var: []const u8 = undefined;
    const comma_peek = try lex.peek();
    if (comma_peek != null and comma_peek.?.type == .operator and std.mem.eql(u8, comma_peek.?.lexeme, ",")) {
        _ = try nextTok(lex);
        const second = try nextTok(lex);
        if (second.type != .identifier) return error.ExpectedIdentifier;
        key_var = try allocator.dupe(u8, first.lexeme);
        item_var = try allocator.dupe(u8, second.lexeme);
    } else {
        item_var = try allocator.dupe(u8, first.lexeme);
    }

    const in_tok = try nextTok(lex);
    if (in_tok.type != .in_kw) return error.ExpectedIn;

    var iterable_var: []const u8 = "";
    var iterable_range: ?ast.Range = null;

    const iter_tok = try nextTok(lex);
    if (iter_tok.type != .identifier) return error.ExpectedIdentifier;

    const paren_peek = try lex.peek();
    if (paren_peek != null and paren_peek.?.type == .operator and std.mem.eql(u8, paren_peek.?.lexeme, "(")) {
        // range(start, end)，两端都包含
        _ = try nextTok(lex);
        if (!std.mem.eql(u8, iter_tok.lexeme, "range")) return error.InvalidIterable;
        const start_tok = try nextTok(lex);
        if (start_tok.type != .number) return error.InvalidIterable;
        const sep = try nextTok(lex);
        if (sep.type != .operator or !std.mem.eql(u8, sep.lexeme, ",")) return error.ExpectedComma;
        const end_tok = try nextTok(lex);
        if (end_tok.type != .number) return error.InvalidIterable;
        const close = try nextTok(lex);
        if (close.type != .operator or !std.mem.eql(u8, close.lexeme, ")")) return error.ExpectedTagEnd;
        iterable_range = .{
            .start = try std.fmt.parseInt(i64, start_tok.lexeme, 10),
            .end = try std.fmt.parseInt(i64, end_tok.lexeme, 10),
        };
    } else {
        iterable_var = try parseDottedPath(allocator, lex, iter_tok);
    }

    var iterable_filter: ?[]const u8 = null;
    const after_peek = try lex.peek();
    if (after_peek != null and after_peek.?.type == .pipe) {
        _ = try nextTok(lex);
        const fname = try nextTok(lex);
        if (fname.type != .identifier) return error.ExpectedIdentifier;
        const colon_peek = try lex.peek();
        if (colon_peek != null and colon_peek.?.type == .operator and std.mem.eql(u8, colon_peek.?.lexeme, ":")) {
            _ = try nextTok(lex);
            const arg = try nextTok(lex);
            if (arg.type != .string and arg.type != .number) return error.InvalidLiteral;
            iterable_filter = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ fname.lexeme, arg.lexeme });
        } else {
            iterable_filter = try allocator.dupe(u8, fname.lexeme);
        }
    }

    try expectTagEnd(lex);
    const body = try parseUntil(allocator, lex, &.{.endfor_kw});
    if (body.stop == null) return error.UnexpectedEof;
    try expectTagEnd(lex);

    return ast.Node{ .for_loop = .{
        .item_var = item_var,
        .key_var = key_var,
        .iterable_var = iterable_var,
        .iterable_filter = iterable_filter,
        .iterable_range = iterable_range,
        .body = body.nodes,
    } };
}

/// set var = expr %}
fn parseSet(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Node {
    const var_token = try nextTok(lex);
    if (var_token.type != .identifier) return error.ExpectedIdentifier;
    const op_token = try nextTok(lex);
    if (op_token.type != .operator or !std.mem.eql(u8, op_token.lexeme, "=")) return error.ExpectedEquals;
    const value_expr = try parseExpr(allocator, lex);
    try expectTagEnd(lex);
    return ast.Node{ .set = .{
        .var_name = try allocator.dupe(u8, var_token.lexeme),
        .value = value_expr,
    } };
}

/// 宏参数列表：可有可无的 (a, b, c)
fn parseMacroParams(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!std.ArrayList([]const u8) {
    var params = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    const first = try lex.peek();
    if (first != null and first.?.type == .operator and std.mem.eql(u8, first.?.lexeme, "(")) {
        _ = try nextTok(lex);
        while (true) {
            const param = try nextTok(lex);
            if (param.type == .operator and std.mem.eql(u8, param.lexeme, ")")) break;
            if (param.type != .identifier) return error.ExpectedIdentifier;
            try params.append(allocator, try allocator.dupe(u8, param.lexeme));
            const sep = try nextTok(lex);
            if (sep.type == .operator and std.mem.eql(u8, sep.lexeme, ")")) break;
            if (sep.type != .operator or !std.mem.eql(u8, sep.lexeme, ",")) return error.ExpectedComma;
        }
    }
    return params;
}

fn parsePrimary(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Expression {
    const token = try nextTok(lex);
    switch (token.type) {
        .identifier => {
            if (std.mem.eql(u8, token.lexeme, "true")) return ast.Expression{ .literal = std.json.Value{ .bool = true } };
            if (std.mem.eql(u8, token.lexeme, "false")) return ast.Expression{ .literal = std.json.Value{ .bool = false } };

            const p = try lex.peek();
            if (p != null and p.?.type == .operator and std.mem.eql(u8, p.?.lexeme, "(")) {
                // 函数调用（如 max(values)、cycle(values, 3)）
                _ = try nextTok(lex);
                var args = try std.ArrayList(*const ast.Expression).initCapacity(allocator, 0);
                const close_peek = try lex.peek();
                if (!(close_peek != null and close_peek.?.type == .operator and std.mem.eql(u8, close_peek.?.lexeme, ")"))) {
                    while (true) {
                        const arg = try parseExpr(allocator, lex);
                        const arg_ptr = try allocator.create(ast.Expression);
                        arg_ptr.* = arg;
                        try args.append(allocator, arg_ptr);
                        const sep = try nextTok(lex);
                        if (sep.type == .operator and std.mem.eql(u8, sep.lexeme, ")")) break;
                        if (sep.type != .operator or !std.mem.eql(u8, sep.lexeme, ",")) return error.ExpectedComma;
                    }
                } else {
                    _ = try nextTok(lex); // 空参数列表，吃掉 ')'
                }
                const fc = try allocator.create(ast.FunctionCall);
                fc.* = .{ .name = try allocator.dupe(u8, token.lexeme), .args = args };
                return ast.Expression{ .function_call = fc };
            }

            return ast.Expression{ .variable = try parseDottedPath(allocator, lex, token) };
        },
        .string => return ast.Expression{ .literal = std.json.Value{ .string = try allocator.dupe(u8, token.lexeme) } },
        .number => {
            if (std.mem.indexOf(u8, token.lexeme, ".")) |_| {
                return ast.Expression{ .literal = std.json.Value{ .float = try std.fmt.parseFloat(f64, token.lexeme) } };
            }
            return ast.Expression{ .literal = std.json.Value{ .integer = try std.fmt.parseInt(i64, token.lexeme, 10) } };
        },
        else => return error.InvalidPrimary,
    }
}

fn parseExpr(allocator: std.mem.Allocator, lex: *lexer.Lexer) ParseError!ast.Expression {
    var left = try parsePrimary(allocator, lex);
    while (true) {
        const p = try lex.peek();
        if (p == null or p.?.type != .operator) break;
        const arith_ops = [_][]const u8{ "+", "-", "*", "/" };
        var matched = false;
        for (arith_ops) |o| {
            if (std.mem.eql(u8, p.?.lexeme, o)) {
                matched = true;
                break;
            }
        }
        if (!matched) break;
        _ = try nextTok(lex);
        const right = try parsePrimary(allocator, lex);
        const left_ptr = try allocator.create(ast.Expression);
        left_ptr.* = left;
        const right_ptr = try allocator.create(ast.Expression);
        right_ptr.* = right;
        const binary_expr = try allocator.create(ast.BinaryExpression);
        binary_expr.* = .{
            .left = left_ptr,
            .op = try allocator.dupe(u8, p.?.lexeme),
            .right = right_ptr,
        };
        left = ast.Expression{ .binary = binary_expr };
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
        },
        .filtered => |f| {
            freeExpression(allocator, f.expr.*);
            allocator.destroy(f.expr);
            // filter 字符串由 parser dupe/allocPrint，这里释放
            allocator.free(f.filter);
            allocator.destroy(f);
        },
    }
}

/// 释放节点内容（不含列表本身的存储，由 freeAst 统一释放）
fn freeNodes(allocator: std.mem.Allocator, nodes: []const ast.Node) void {
    for (nodes) |node| {
        switch (node) {
            .text => |t| allocator.free(t),
            .variable => |v| freeExpression(allocator, v),
            .for_loop => |f| {
                allocator.free(f.item_var);
                if (f.key_var) |kv| allocator.free(kv);
                if (f.iterable_var.len > 0) allocator.free(f.iterable_var);
                if (f.iterable_filter) |fltr| allocator.free(fltr);
                freeAst(allocator, f.body);
            },
            .if_stmt => |i| {
                allocator.free(i.condition.var_path);
                if (i.condition.op) |op| allocator.free(op);
                if (i.condition.literal) |lit| {
                    if (lit == .string) allocator.free(lit.string);
                }
                freeAst(allocator, i.body);

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
                }
                @constCast(&i.elif_bodies).deinit(allocator);

                freeAst(allocator, i.else_body);
            },
            .set => |s| {
                allocator.free(s.var_name);
                freeExpression(allocator, s.value);
            },
            .extends => |e| allocator.free(e.template_name),
            .block => |b| {
                allocator.free(b.name);
                freeAst(allocator, b.body);
            },
            .include => |i| {
                allocator.free(i.template_name);
                if (i.with_path) |p| allocator.free(p);
            },
            .macro => |m| {
                allocator.free(m.name);
                for (m.params.items) |param| allocator.free(param);
                @constCast(&m.params).deinit(allocator);
                freeAst(allocator, m.body);
            },
            .import => |i| {
                allocator.free(i.template_name);
                for (i.macro_names.items) |name| allocator.free(name);
                @constCast(&i.macro_names).deinit(allocator);
            },
            .parent => {},
        }
    }
}

/// 释放整个 AST：节点内容 + 列表存储，每块内存恰好释放一次
pub fn freeAst(allocator: std.mem.Allocator, nodes: std.ArrayList(ast.Node)) void {
    freeNodes(allocator, nodes.items);
    @constCast(&nodes).deinit(allocator);
}
