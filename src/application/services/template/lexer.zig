const std = @import("std");

pub const TokenType = enum {
    text,
    variable_start, // {{
    variable_end, // }}
    tag_start, // {%
    tag_end, // %}
    identifier,
    string,
    number,
    operator,
    for_kw,
    if_kw,
    else_kw,
    elif_kw,
    set_kw,
    in_kw,
    endfor_kw,
    endif_kw,
    extends_kw,
    block_kw,
    endblock_kw,
    include_kw,
    macro_kw,
    endmacro_kw,
    from_kw,
    import_kw,
    parent_kw,
    pipe, // |
    eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
};

pub const LexerState = enum {
    text,
    expression,
};

pub const Lexer = struct {
    source: []const u8,
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,
    state: LexerState = .text,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source };
    }
    pub fn next(self: *Lexer) !?Token {
        if (self.state == .text) {
            while (self.current < self.source.len and std.ascii.isWhitespace(self.source[self.current])) {
                if (self.source[self.current] == '\n') self.line += 1;
                self.current += 1;
            }
            if (self.current >= self.source.len) return Token{ .type = .eof, .lexeme = "", .line = self.line };

            self.start = self.current;

            // check for {{
            if (self.current + 1 < self.source.len and self.source[self.current] == '{' and self.source[self.current + 1] == '{') {
                self.current += 2;
                self.state = .expression;
                return Token{ .type = .variable_start, .lexeme = "{{", .line = self.line };
            }
            if (self.current + 1 < self.source.len and self.source[self.current] == '{' and self.source[self.current + 1] == '%') {
                self.current += 2;
                self.state = .expression;
                return Token{ .type = .tag_start, .lexeme = "{%", .line = self.line };
            }

            // collect text until special
            while (self.current < self.source.len) {
                if (self.current + 1 < self.source.len and ((self.source[self.current] == '{' and (self.source[self.current + 1] == '{' or self.source[self.current + 1] == '%')) or (self.source[self.current] == '}' and (self.source[self.current + 1] == '}' or self.source[self.current + 1] == '%')))) {
                    break;
                }
                if (self.source[self.current] == '\n') self.line += 1;
                self.current += 1;
            }
            if (self.current > self.start) {
                return Token{ .type = .text, .lexeme = self.source[self.start..self.current], .line = self.line };
            }
        } else {
            // expression state
            while (self.current < self.source.len and std.ascii.isWhitespace(self.source[self.current])) {
                if (self.source[self.current] == '\n') self.line += 1;
                self.current += 1;
            }
            if (self.current >= self.source.len) return Token{ .type = .eof, .lexeme = "", .line = self.line };

            self.start = self.current;

            // check for }}
            if (self.current + 1 < self.source.len and self.source[self.current] == '}' and self.source[self.current + 1] == '}') {
                self.current += 2;
                self.state = .text;
                return Token{ .type = .variable_end, .lexeme = "}}", .line = self.line };
            }
            if (self.current + 1 < self.source.len and self.source[self.current] == '%' and self.source[self.current + 1] == '}') {
                self.current += 2;
                self.state = .text;
                return Token{ .type = .tag_end, .lexeme = "%}", .line = self.line };
            }

            // inside expressions (identifier, string, number, operator)
            const c = self.source[self.current];
            self.current += 1;
            if (std.ascii.isAlphabetic(c) or c == '_') {
                while (self.current < self.source.len and (std.ascii.isAlphanumeric(self.source[self.current]) or self.source[self.current] == '_')) {
                    self.current += 1;
                }
                const lexeme = self.source[self.start..self.current];
                // keywords
                if (std.mem.eql(u8, lexeme, "for")) return Token{ .type = .for_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "if")) return Token{ .type = .if_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "else")) return Token{ .type = .else_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "elif")) return Token{ .type = .elif_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "set")) return Token{ .type = .set_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "in")) return Token{ .type = .in_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "endfor")) return Token{ .type = .endfor_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "endif")) return Token{ .type = .endif_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "extends")) return Token{ .type = .extends_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "block")) return Token{ .type = .block_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "endblock")) return Token{ .type = .endblock_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "include")) return Token{ .type = .include_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "macro")) return Token{ .type = .macro_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "endmacro")) return Token{ .type = .endmacro_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "from")) return Token{ .type = .from_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "import")) return Token{ .type = .import_kw, .lexeme = lexeme, .line = self.line };
                if (std.mem.eql(u8, lexeme, "parent")) return Token{ .type = .parent_kw, .lexeme = lexeme, .line = self.line };
                return Token{ .type = .identifier, .lexeme = lexeme, .line = self.line };
            } else if (std.ascii.isDigit(c)) {
                while (self.current < self.source.len and std.ascii.isDigit(self.source[self.current])) {
                    self.current += 1;
                }
                return Token{ .type = .number, .lexeme = self.source[self.start..self.current], .line = self.line };
            } else if (c == '"') {
                while (self.current < self.source.len and self.source[self.current] != '"') {
                    if (self.source[self.current] == '\n') self.line += 1;
                    self.current += 1;
                }
                if (self.current >= self.source.len) return error.UnterminatedString;
                self.current += 1;
                return Token{ .type = .string, .lexeme = self.source[self.start + 1 .. self.current - 1], .line = self.line };
            } else {
                if (c == '=') {
                    if (self.current < self.source.len and self.source[self.current] == '=') {
                        self.current += 1;
                        return Token{ .type = .operator, .lexeme = "==", .line = self.line };
                    } else {
                        return Token{ .type = .operator, .lexeme = "=", .line = self.line };
                    }
                } else if (c == '!') {
                    if (self.current < self.source.len and self.source[self.current] == '=') {
                        self.current += 1;
                        return Token{ .type = .operator, .lexeme = "!=", .line = self.line };
                    } else {
                        return Token{ .type = .operator, .lexeme = "!", .line = self.line };
                    }
                } else if (c == '<') {
                    if (self.current < self.source.len and self.source[self.current] == '=') {
                        self.current += 1;
                        return Token{ .type = .operator, .lexeme = "<=", .line = self.line };
                    } else {
                        return Token{ .type = .operator, .lexeme = "<", .line = self.line };
                    }
                } else if (c == '>') {
                    if (self.current < self.source.len and self.source[self.current] == '=') {
                        self.current += 1;
                        return Token{ .type = .operator, .lexeme = ">=", .line = self.line };
                    } else {
                        return Token{ .type = .operator, .lexeme = ">", .line = self.line };
                    }
                } else if (c == '|') {
                    return Token{ .type = .pipe, .lexeme = "|", .line = self.line };
                } else {
                    return Token{ .type = .operator, .lexeme = self.source[self.start..self.current], .line = self.line };
                }
            }
        }

        return Token{ .type = .eof, .lexeme = "", .line = self.line };
    }

    pub fn peek(self: *Lexer) !?Token {
        const saved_start = self.start;
        const saved_current = self.current;
        const saved_line = self.line;
        const saved_state = self.state;
        const tok = try self.next();
        self.start = saved_start;
        self.current = saved_current;
        self.line = saved_line;
        self.state = saved_state;
        return tok;
    }
};
