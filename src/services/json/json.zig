//! JSON 解析与序列化库
//!
//! 提供类似 Go 语言的 JSON 操作接口，支持：
//! - 结构体序列化/反序列化
//! - 安全的内存管理
//! - 自定义字段映射
//! - 空值处理
//! - RawMessage 延迟解析
//! - 自定义 Marshaler/Unmarshaler 接口
//!
//! 示例用法:
//! ```zig
//! const User = struct {
//!     id: i64,
//!     name: []const u8,
//!     email: ?[]const u8 = null,
//!     extra: RawMessage = .{}, // 延迟解析的原始 JSON
//! };
//!
//! // 解析 JSON
//! const json_str = "{\"id\":1,\"name\":\"张三\",\"extra\":{\"foo\":\"bar\"}}";
//! var user = try Json.unmarshal(User, allocator, json_str);
//! defer Json.free(User, allocator, &user);
//!
//! // 序列化为 JSON
//! const output = try Json.marshal(allocator, user);
//! defer allocator.free(output);
//!
//! // 自定义序列化
//! const CustomTime = struct {
//!     timestamp: i64,
//!
//!     pub fn jsonMarshal(self: @This(), allocator: Allocator) ![]const u8 {
//!         return std.fmt.allocPrint(allocator, "\"{d}\"", .{self.timestamp});
//!     }
//!
//!     pub fn jsonUnmarshal(allocator: Allocator, value: Value) !@This() {
//!         _ = allocator;
//!         if (value == .number) return .{ .timestamp = @intFromFloat(value.number) };
//!         return error.TypeMismatch;
//!     }
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// JSON 错误类型
pub const JsonError = error{
    /// 无效的 JSON 格式
    InvalidJson,
    /// 意外的字符
    UnexpectedCharacter,
    /// 意外的 Token
    UnexpectedToken,
    /// 字符串未闭合
    UnterminatedString,
    /// 无效的转义序列
    InvalidEscape,
    /// 无效的数字格式
    InvalidNumber,
    /// 无效的 Unicode 码点
    InvalidUnicode,
    /// 嵌套层级过深
    TooDeep,
    /// 缓冲区溢出
    BufferOverflow,
    /// 类型不匹配
    TypeMismatch,
    /// 缺少必需字段
    MissingField,
    /// 重复的键
    DuplicateKey,
    /// 对象键不是字符串
    ObjectKeyNotString,
    /// 数值溢出
    Overflow,
    /// 内存分配失败
    OutOfMemory,
};

// ============================================================================
// RawMessage - 延迟解析的原始 JSON（类似 Go 的 json.RawMessage）
// ============================================================================

/// RawMessage 用于延迟解析 JSON 或保留原始 JSON 字符串
/// 类似 Go 的 json.RawMessage
///
/// 使用场景：
/// - 部分解析 JSON，保留某些字段的原始形式
/// - 动态字段类型，根据其他字段决定如何解析
/// - 透传 JSON 数据
pub const RawMessage = struct {
    data: []const u8 = "",
    allocator: ?Allocator = null,

    /// 创建空的 RawMessage
    pub fn init() RawMessage {
        return .{};
    }

    /// 从字符串创建（不复制，调用者负责内存）
    pub fn fromSlice(data: []const u8) RawMessage {
        return .{ .data = data };
    }

    /// 从字符串创建（复制数据）
    pub fn fromSliceCopy(allocator: Allocator, data: []const u8) !RawMessage {
        const copied = try allocator.dupe(u8, data);
        return .{ .data = copied, .allocator = allocator };
    }

    /// 释放内存
    pub fn deinit(self: *RawMessage) void {
        if (self.allocator) |alloc| {
            if (self.data.len > 0) {
                alloc.free(self.data);
            }
        }
        self.data = "";
        self.allocator = null;
    }

    /// 解析为指定类型
    pub fn unmarshal(self: RawMessage, comptime T: type, allocator: Allocator) !T {
        if (self.data.len == 0) return JsonError.InvalidJson;
        return Json.unmarshal(T, allocator, self.data);
    }

    /// 解析为动态 Value
    pub fn parse(self: RawMessage, allocator: Allocator) !Value {
        if (self.data.len == 0) return Value{ .null = {} };
        return Json.parseValue(allocator, self.data);
    }

    /// 检查是否为空
    pub fn isEmpty(self: RawMessage) bool {
        return self.data.len == 0;
    }

    /// 获取原始字符串
    pub fn bytes(self: RawMessage) []const u8 {
        return self.data;
    }

    /// 自定义序列化（直接输出原始 JSON）
    pub fn jsonMarshal(self: RawMessage, allocator: Allocator) ![]const u8 {
        if (self.data.len == 0) {
            return try allocator.dupe(u8, "null");
        }
        return try allocator.dupe(u8, self.data);
    }

    /// 自定义反序列化（保留原始 JSON）
    pub fn jsonUnmarshalRaw(allocator: Allocator, raw_json: []const u8) !RawMessage {
        return try RawMessage.fromSliceCopy(allocator, raw_json);
    }
};

// ============================================================================
// Number - 高精度数值类型
// ============================================================================

/// Number 用于保留原始数值字符串，避免精度丢失
/// 适用于大整数（超过 i64 范围）或需要精确小数的场景
pub const Number = struct {
    raw: []const u8 = "",
    allocator: ?Allocator = null,

    /// 从字符串创建
    pub fn fromString(allocator: Allocator, s: []const u8) !Number {
        const copied = try allocator.dupe(u8, s);
        return .{ .raw = copied, .allocator = allocator };
    }

    /// 释放内存
    pub fn deinit(self: *Number) void {
        if (self.allocator) |alloc| {
            if (self.raw.len > 0) {
                alloc.free(self.raw);
            }
        }
        self.raw = "";
        self.allocator = null;
    }

    /// 转换为整数
    pub fn toInt(self: Number, comptime T: type) !T {
        return std.fmt.parseInt(T, self.raw, 10);
    }

    /// 转换为浮点数
    pub fn toFloat(self: Number, comptime T: type) !T {
        return std.fmt.parseFloat(T, self.raw);
    }

    /// 获取原始字符串
    pub fn string(self: Number) []const u8 {
        return self.raw;
    }

    /// 自定义序列化
    pub fn jsonMarshal(self: Number, allocator: Allocator) ![]const u8 {
        if (self.raw.len == 0) return try allocator.dupe(u8, "0");
        return try allocator.dupe(u8, self.raw);
    }
};

// ============================================================================
// 常用类型别名
// ============================================================================

/// 字符串到任意 JSON 值的映射
pub const Object = std.StringHashMap(Value);

/// JSON 数组
pub const Array = []Value;

/// JSON 值类型
pub const ValueType = enum {
    null,
    bool,
    number,
    string,
    array,
    object,
};

/// JSON 值（动态类型）
pub const Value = union(ValueType) {
    null: void,
    bool: bool,
    number: f64,
    string: []const u8,
    array: []Value,
    object: std.StringHashMap(Value),

    /// 释放值占用的内存
    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*item| {
                    var v = item.*;
                    v.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    var v = entry.value_ptr.*;
                    v.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }

    /// 获取布尔值
    pub fn getBool(self: Value) ?bool {
        return if (self == .bool) self.bool else null;
    }

    /// 获取数值
    pub fn getNumber(self: Value) ?f64 {
        return if (self == .number) self.number else null;
    }

    /// 获取字符串
    pub fn getString(self: Value) ?[]const u8 {
        return if (self == .string) self.string else null;
    }

    /// 获取数组
    pub fn getArray(self: Value) ?[]Value {
        return if (self == .array) self.array else null;
    }

    /// 获取整数（安全转换）
    pub fn getInt(self: Value, comptime T: type) ?T {
        if (self != .number) return null;
        const n = self.number;
        if (@floor(n) != n) return null;
        const min = @as(f64, @floatFromInt(std.math.minInt(T)));
        const max = @as(f64, @floatFromInt(std.math.maxInt(T)));
        if (n < min or n > max) return null;
        return @intFromFloat(n);
    }

    /// 获取对象字段
    pub fn get(self: Value, key: []const u8) ?Value {
        if (self != .object) return null;
        return self.object.get(key);
    }

    /// 检查是否为 null
    pub fn isNull(self: Value) bool {
        return self == .null;
    }
};

/// JSON 解析选项
pub const ParseOptions = struct {
    /// 最大嵌套深度（防止栈溢出攻击）
    max_depth: u32 = 128,
    /// 是否允许尾随逗号
    allow_trailing_comma: bool = false,
    /// 是否允许注释
    allow_comments: bool = false,
    /// 最大字符串长度（防止内存耗尽攻击）
    max_string_len: usize = 10 * 1024 * 1024, // 10MB
    /// 最大数组/对象元素数量
    max_elements: usize = 100_000,
};

/// JSON 序列化选项
pub const StringifyOptions = struct {
    /// 是否格式化输出
    pretty: bool = false,
    /// 缩进字符串
    indent: []const u8 = "  ",
    /// 是否转义非 ASCII 字符
    escape_non_ascii: bool = false,
    /// 是否省略 null 字段
    omit_null: bool = false,
    /// 是否排序键
    sort_keys: bool = false,
};

/// JSON 解析器
pub const Parser = struct {
    const Self = @This();

    allocator: Allocator,
    input: []const u8,
    pos: usize,
    options: ParseOptions,
    depth: u32,

    /// 创建解析器
    pub fn init(allocator: Allocator, input: []const u8, options: ParseOptions) Self {
        return .{
            .allocator = allocator,
            .input = input,
            .pos = 0,
            .options = options,
            .depth = 0,
        };
    }

    /// 解析 JSON 值
    pub fn parse(self: *Self) JsonError!Value {
        self.skipWhitespace();
        if (self.pos >= self.input.len) {
            return JsonError.InvalidJson;
        }
        return self.parseValue();
    }

    fn parseValue(self: *Self) JsonError!Value {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return JsonError.UnexpectedToken;
        }

        const c = self.input[self.pos];
        return switch (c) {
            'n' => self.parseNull(),
            't', 'f' => self.parseBool(),
            '"' => self.parseString(),
            '[' => self.parseArray(),
            '{' => self.parseObject(),
            '-', '0'...'9' => self.parseNumber(),
            else => JsonError.UnexpectedCharacter,
        };
    }

    fn parseNull(self: *Self) JsonError!Value {
        if (self.pos + 4 > self.input.len) return JsonError.UnexpectedToken;
        if (!std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "null")) {
            return JsonError.UnexpectedToken;
        }
        self.pos += 4;
        return Value{ .null = {} };
    }

    fn parseBool(self: *Self) JsonError!Value {
        if (self.input[self.pos] == 't') {
            if (self.pos + 4 > self.input.len) return JsonError.UnexpectedToken;
            if (!std.mem.eql(u8, self.input[self.pos .. self.pos + 4], "true")) {
                return JsonError.UnexpectedToken;
            }
            self.pos += 4;
            return Value{ .bool = true };
        } else {
            if (self.pos + 5 > self.input.len) return JsonError.UnexpectedToken;
            if (!std.mem.eql(u8, self.input[self.pos .. self.pos + 5], "false")) {
                return JsonError.UnexpectedToken;
            }
            self.pos += 5;
            return Value{ .bool = false };
        }
    }

    fn parseString(self: *Self) JsonError!Value {
        self.pos += 1; // 跳过开始的引号
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        while (self.pos < self.input.len) {
            if (result.items.len > self.options.max_string_len) {
                return JsonError.BufferOverflow;
            }

            const c = self.input[self.pos];
            if (c == '"') {
                self.pos += 1;
                const slice = result.toOwnedSlice(self.allocator) catch return JsonError.OutOfMemory;
                return Value{ .string = slice };
            } else if (c == '\\') {
                self.pos += 1;
                if (self.pos >= self.input.len) return JsonError.UnterminatedString;
                const escaped = self.input[self.pos];
                const unescaped: u8 = switch (escaped) {
                    '"' => '"',
                    '\\' => '\\',
                    '/' => '/',
                    'b' => 0x08,
                    'f' => 0x0C,
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    'u' => {
                        // Unicode 转义
                        if (self.pos + 5 > self.input.len) return JsonError.InvalidUnicode;
                        const hex = self.input[self.pos + 1 .. self.pos + 5];
                        const codepoint = std.fmt.parseInt(u21, hex, 16) catch return JsonError.InvalidUnicode;
                        self.pos += 4;
                        // UTF-8 编码
                        var buf: [4]u8 = undefined;
                        const len = std.unicode.utf8Encode(codepoint, &buf) catch return JsonError.InvalidUnicode;
                        result.appendSlice(self.allocator, buf[0..len]) catch return JsonError.OutOfMemory;
                        self.pos += 1;
                        continue;
                    },
                    else => return JsonError.InvalidEscape,
                };
                result.append(self.allocator, unescaped) catch return JsonError.OutOfMemory;
            } else if (c < 0x20) {
                return JsonError.UnexpectedCharacter;
            } else {
                result.append(self.allocator, c) catch return JsonError.OutOfMemory;
            }
            self.pos += 1;
        }
        return JsonError.UnterminatedString;
    }

    fn parseNumber(self: *Self) JsonError!Value {
        const start = self.pos;

        // 负号
        if (self.pos < self.input.len and self.input[self.pos] == '-') {
            self.pos += 1;
        }

        // 整数部分
        if (self.pos >= self.input.len) return JsonError.InvalidNumber;
        if (self.input[self.pos] == '0') {
            self.pos += 1;
        } else if (self.input[self.pos] >= '1' and self.input[self.pos] <= '9') {
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        } else {
            return JsonError.InvalidNumber;
        }

        // 小数部分
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            self.pos += 1;
            if (self.pos >= self.input.len or self.input[self.pos] < '0' or self.input[self.pos] > '9') {
                return JsonError.InvalidNumber;
            }
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        }

        // 指数部分
        if (self.pos < self.input.len and (self.input[self.pos] == 'e' or self.input[self.pos] == 'E')) {
            self.pos += 1;
            if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
                self.pos += 1;
            }
            if (self.pos >= self.input.len or self.input[self.pos] < '0' or self.input[self.pos] > '9') {
                return JsonError.InvalidNumber;
            }
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        }

        const num_str = self.input[start..self.pos];
        const num = std.fmt.parseFloat(f64, num_str) catch return JsonError.InvalidNumber;
        return Value{ .number = num };
    }

    fn parseArray(self: *Self) JsonError!Value {
        self.depth += 1;
        if (self.depth > self.options.max_depth) {
            return JsonError.TooDeep;
        }
        defer self.depth -= 1;

        self.pos += 1; // 跳过 '['
        self.skipWhitespace();

        var items = std.ArrayListUnmanaged(Value){};
        errdefer {
            for (items.items) |*item| {
                item.deinit(self.allocator);
            }
            items.deinit(self.allocator);
        }

        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            const slice = items.toOwnedSlice(self.allocator) catch return JsonError.OutOfMemory;
            return Value{ .array = slice };
        }

        while (true) {
            if (items.items.len >= self.options.max_elements) {
                return JsonError.BufferOverflow;
            }

            const value = try self.parseValue();
            items.append(self.allocator, value) catch return JsonError.OutOfMemory;

            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.UnexpectedToken;

            if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespace();
                if (self.options.allow_trailing_comma and self.pos < self.input.len and self.input[self.pos] == ']') {
                    self.pos += 1;
                    const slice = items.toOwnedSlice(self.allocator) catch return JsonError.OutOfMemory;
                    return Value{ .array = slice };
                }
            } else if (self.input[self.pos] == ']') {
                self.pos += 1;
                const slice = items.toOwnedSlice(self.allocator) catch return JsonError.OutOfMemory;
                return Value{ .array = slice };
            } else {
                return JsonError.UnexpectedCharacter;
            }
        }
    }

    fn parseObject(self: *Self) JsonError!Value {
        self.depth += 1;
        if (self.depth > self.options.max_depth) {
            return JsonError.TooDeep;
        }
        defer self.depth -= 1;

        self.pos += 1; // 跳过 '{'
        self.skipWhitespace();

        var map = std.StringHashMap(Value).init(self.allocator);
        errdefer {
            var iter = map.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                var v = entry.value_ptr.*;
                v.deinit(self.allocator);
            }
            map.deinit();
        }

        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return Value{ .object = map };
        }

        while (true) {
            if (map.count() >= self.options.max_elements) {
                return JsonError.BufferOverflow;
            }

            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != '"') {
                return JsonError.ObjectKeyNotString;
            }

            const key_value = try self.parseString();
            const key = self.allocator.dupe(u8, key_value.string) catch return JsonError.OutOfMemory;
            var key_val = key_value;
            key_val.deinit(self.allocator);

            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                self.allocator.free(key);
                return JsonError.UnexpectedCharacter;
            }
            self.pos += 1;

            const value = try self.parseValue();
            map.put(key, value) catch {
                self.allocator.free(key);
                return JsonError.OutOfMemory;
            };

            self.skipWhitespace();
            if (self.pos >= self.input.len) return JsonError.UnexpectedToken;

            if (self.input[self.pos] == ',') {
                self.pos += 1;
                self.skipWhitespace();
                if (self.options.allow_trailing_comma and self.pos < self.input.len and self.input[self.pos] == '}') {
                    self.pos += 1;
                    return Value{ .object = map };
                }
            } else if (self.input[self.pos] == '}') {
                self.pos += 1;
                return Value{ .object = map };
            } else {
                return JsonError.UnexpectedCharacter;
            }
        }
    }

    fn skipWhitespace(self: *Self) void {
        while (self.pos < self.input.len) {
            switch (self.input[self.pos]) {
                ' ', '\t', '\n', '\r' => self.pos += 1,
                '/' => {
                    if (!self.options.allow_comments) break;
                    if (self.pos + 1 >= self.input.len) break;
                    if (self.input[self.pos + 1] == '/') {
                        // 单行注释
                        self.pos += 2;
                        while (self.pos < self.input.len and self.input[self.pos] != '\n') {
                            self.pos += 1;
                        }
                    } else if (self.input[self.pos + 1] == '*') {
                        // 多行注释
                        self.pos += 2;
                        while (self.pos + 1 < self.input.len) {
                            if (self.input[self.pos] == '*' and self.input[self.pos + 1] == '/') {
                                self.pos += 2;
                                break;
                            }
                            self.pos += 1;
                        }
                    } else {
                        break;
                    }
                },
                else => break,
            }
        }
    }
};

/// JSON 序列化器
pub const Stringify = struct {
    const Self = @This();

    allocator: Allocator,
    buffer: std.ArrayListUnmanaged(u8),
    options: StringifyOptions,
    depth: u32,

    /// 创建序列化器
    pub fn init(allocator: Allocator, options: StringifyOptions) Self {
        return .{
            .allocator = allocator,
            .buffer = std.ArrayListUnmanaged(u8){},
            .options = options,
            .depth = 0,
        };
    }

    /// 释放序列化器资源
    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    /// 序列化值为 JSON 字符串
    pub fn stringify(self: *Self, value: anytype) ![]const u8 {
        try self.writeValue(value);
        return self.buffer.toOwnedSlice(self.allocator);
    }

    fn writeValue(self: *Self, value: anytype) !void {
        const T = @TypeOf(value);
        const info = @typeInfo(T);

        switch (info) {
            .null => try self.buffer.appendSlice(self.allocator, "null"),
            .void => try self.buffer.appendSlice(self.allocator, "null"),
            .bool => {
                if (value) {
                    try self.buffer.appendSlice(self.allocator, "true");
                } else {
                    try self.buffer.appendSlice(self.allocator, "false");
                }
            },
            .int, .comptime_int => {
                var buf: [32]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return error.BufferOverflow;
                try self.buffer.appendSlice(self.allocator, str);
            },
            .float, .comptime_float => {
                var buf: [64]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return error.BufferOverflow;
                try self.buffer.appendSlice(self.allocator, str);
            },
            .optional => {
                if (value) |v| {
                    try self.writeValue(v);
                } else {
                    try self.buffer.appendSlice(self.allocator, "null");
                }
            },
            .pointer => |ptr| {
                if (ptr.size == .slice) {
                    if (ptr.child == u8) {
                        // 字符串
                        try self.writeString(value);
                    } else {
                        // 数组
                        try self.writeArray(value);
                    }
                } else if (ptr.size == .one) {
                    try self.writeValue(value.*);
                } else {
                    try self.buffer.appendSlice(self.allocator, "null");
                }
            },
            .array => |arr| {
                if (arr.child == u8) {
                    try self.writeString(&value);
                } else {
                    try self.writeArray(&value);
                }
            },
            .@"struct" => |s| {
                // 检查是否有自定义 jsonMarshal 方法
                if (@hasDecl(T, "jsonMarshal")) {
                    const custom_json = try value.jsonMarshal(self.allocator);
                    defer self.allocator.free(custom_json);
                    try self.buffer.appendSlice(self.allocator, custom_json);
                } else if (s.is_tuple) {
                    // 元组序列化为数组
                    try self.writeTuple(value);
                } else {
                    try self.writeStruct(value);
                }
            },
            .@"enum" => {
                try self.writeString(@tagName(value));
            },
            .@"union" => |u| {
                if (u.tag_type) |_| {
                    inline for (u.fields) |field| {
                        if (std.mem.eql(u8, @tagName(value), field.name)) {
                            try self.writeValue(@field(value, field.name));
                            return;
                        }
                    }
                }
                try self.buffer.appendSlice(self.allocator, "null");
            },
            else => try self.buffer.appendSlice(self.allocator, "null"),
        }
    }

    fn writeString(self: *Self, str: []const u8) !void {
        try self.buffer.append(self.allocator, '"');
        for (str) |c| {
            switch (c) {
                '"' => try self.buffer.appendSlice(self.allocator, "\\\""),
                '\\' => try self.buffer.appendSlice(self.allocator, "\\\\"),
                '\n' => try self.buffer.appendSlice(self.allocator, "\\n"),
                '\r' => try self.buffer.appendSlice(self.allocator, "\\r"),
                '\t' => try self.buffer.appendSlice(self.allocator, "\\t"),
                0x08 => try self.buffer.appendSlice(self.allocator, "\\b"),
                0x0C => try self.buffer.appendSlice(self.allocator, "\\f"),
                else => {
                    if (c < 0x20) {
                        var buf: [6]u8 = undefined;
                        const hex = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch unreachable;
                        try self.buffer.appendSlice(self.allocator, hex);
                    } else if (c >= 0x80 and self.options.escape_non_ascii) {
                        var buf: [6]u8 = undefined;
                        const hex = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch unreachable;
                        try self.buffer.appendSlice(self.allocator, hex);
                    } else {
                        try self.buffer.append(self.allocator, c);
                    }
                },
            }
        }
        try self.buffer.append(self.allocator, '"');
    }

    fn writeArray(self: *Self, arr: anytype) !void {
        try self.buffer.append(self.allocator, '[');
        self.depth += 1;

        var first = true;
        for (arr) |item| {
            if (!first) {
                try self.buffer.append(self.allocator, ',');
            }
            first = false;

            if (self.options.pretty) {
                try self.buffer.append(self.allocator, '\n');
                try self.writeIndent();
            }

            try self.writeValue(item);
        }

        self.depth -= 1;
        if (self.options.pretty and arr.len > 0) {
            try self.buffer.append(self.allocator, '\n');
            try self.writeIndent();
        }
        try self.buffer.append(self.allocator, ']');
    }

    fn writeStruct(self: *Self, value: anytype) !void {
        const T = @TypeOf(value);
        const fields = std.meta.fields(T);

        try self.buffer.append(self.allocator, '{');
        self.depth += 1;

        var first = true;
        inline for (fields) |field| {
            const field_value = @field(value, field.name);

            // 处理 omit_null 选项
            if (self.options.omit_null) {
                const field_info = @typeInfo(field.type);
                if (field_info == .optional) {
                    if (field_value == null) continue;
                }
            }

            if (!first) {
                try self.buffer.append(self.allocator, ',');
            }
            first = false;

            if (self.options.pretty) {
                try self.buffer.append(self.allocator, '\n');
                try self.writeIndent();
            }

            // 获取字段名（支持 json 标签）
            const field_name = getJsonFieldName(T, field.name);
            try self.writeString(field_name);
            try self.buffer.append(self.allocator, ':');
            if (self.options.pretty) {
                try self.buffer.append(self.allocator, ' ');
            }
            try self.writeValue(field_value);
        }

        self.depth -= 1;
        if (self.options.pretty and fields.len > 0 and !first) {
            try self.buffer.append(self.allocator, '\n');
            try self.writeIndent();
        }
        try self.buffer.append(self.allocator, '}');
    }

    fn writeTuple(self: *Self, value: anytype) !void {
        const T = @TypeOf(value);
        const fields = std.meta.fields(T);

        try self.buffer.append(self.allocator, '[');
        self.depth += 1;

        var first = true;
        inline for (fields) |field| {
            if (!first) {
                try self.buffer.append(self.allocator, ',');
            }
            first = false;

            if (self.options.pretty) {
                try self.buffer.append(self.allocator, '\n');
                try self.writeIndent();
            }

            try self.writeValue(@field(value, field.name));
        }

        self.depth -= 1;
        if (self.options.pretty and fields.len > 0) {
            try self.buffer.append(self.allocator, '\n');
            try self.writeIndent();
        }
        try self.buffer.append(self.allocator, ']');
    }

    fn writeIndent(self: *Self) !void {
        for (0..self.depth) |_| {
            try self.buffer.appendSlice(self.allocator, self.options.indent);
        }
    }

    fn getJsonFieldName(comptime T: type, comptime field_name: []const u8) []const u8 {
        // 检查结构体是否有 json_field_names 声明
        if (@hasDecl(T, "json_field_names")) {
            const mappings = @field(T, "json_field_names");
            inline for (mappings) |mapping| {
                if (std.mem.eql(u8, mapping[0], field_name)) {
                    return mapping[1];
                }
            }
        }
        return field_name;
    }
};

/// JSON 主接口（类似 Go 的 encoding/json）
pub const Json = struct {
    /// 将 JSON 字符串解析为动态值
    pub fn parseValue(allocator: Allocator, input: []const u8) JsonError!Value {
        return parseValueWithOptions(allocator, input, .{});
    }

    /// 带选项的解析
    pub fn parseValueWithOptions(allocator: Allocator, input: []const u8, options: ParseOptions) JsonError!Value {
        var parser = Parser.init(allocator, input, options);
        return parser.parse();
    }

    /// 将 JSON 字符串解析为指定类型（类似 Go 的 json.Unmarshal）
    pub fn unmarshal(comptime T: type, allocator: Allocator, input: []const u8) !T {
        return unmarshalWithOptions(T, allocator, input, .{});
    }

    /// 带选项的反序列化
    pub fn unmarshalWithOptions(comptime T: type, allocator: Allocator, input: []const u8, options: ParseOptions) !T {
        var value = try parseValueWithOptions(allocator, input, options);
        defer value.deinit(allocator);
        return try valueToType(T, allocator, value);
    }

    /// 将值序列化为 JSON 字符串（类似 Go 的 json.Marshal）
    pub fn marshal(allocator: Allocator, value: anytype) ![]const u8 {
        return marshalWithOptions(allocator, value, .{});
    }

    /// 带选项的序列化
    pub fn marshalWithOptions(allocator: Allocator, value: anytype, options: StringifyOptions) ![]const u8 {
        var stringify = Stringify.init(allocator, options);
        defer stringify.deinit();
        return stringify.stringify(value);
    }

    /// 格式化 JSON 输出
    pub fn marshalIndent(allocator: Allocator, value: anytype) ![]const u8 {
        return marshalWithOptions(allocator, value, .{ .pretty = true });
    }

    /// 释放反序列化分配的内存
    pub fn free(comptime T: type, allocator: Allocator, value: *T) void {
        freeValue(T, allocator, value);
    }

    fn valueToType(comptime T: type, allocator: Allocator, value: Value) !T {
        const info = @typeInfo(T);

        switch (info) {
            .bool => {
                if (value == .bool) return value.bool;
                return JsonError.TypeMismatch;
            },
            .int => {
                if (value == .number) {
                    const n = value.number;
                    if (@floor(n) != n) return JsonError.TypeMismatch;
                    return @intFromFloat(n);
                }
                return JsonError.TypeMismatch;
            },
            .float => {
                if (value == .number) return @floatCast(value.number);
                return JsonError.TypeMismatch;
            },
            .optional => |opt| {
                if (value == .null) return null;
                return try valueToType(opt.child, allocator, value);
            },
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    // 字符串
                    if (value == .string) {
                        return allocator.dupe(u8, value.string) catch return JsonError.OutOfMemory;
                    }
                    return JsonError.TypeMismatch;
                }
                return JsonError.TypeMismatch;
            },
            .@"struct" => |s| {
                // 检查是否是 RawMessage 类型
                if (T == RawMessage) {
                    // 需要将 Value 转回 JSON 字符串
                    const raw_json = try valueToJson(allocator, value);
                    return RawMessage{ .data = raw_json, .allocator = allocator };
                }

                // 检查是否是 Number 类型
                if (T == Number) {
                    if (value == .number) {
                        var buf: [64]u8 = undefined;
                        const str = std.fmt.bufPrint(&buf, "{d}", .{value.number}) catch return JsonError.BufferOverflow;
                        return try Number.fromString(allocator, str);
                    }
                    return JsonError.TypeMismatch;
                }

                // 检查是否有自定义 jsonUnmarshal 方法
                if (@hasDecl(T, "jsonUnmarshal")) {
                    return try T.jsonUnmarshal(allocator, value);
                }

                // 处理元组
                if (s.is_tuple) {
                    if (value != .array) return JsonError.TypeMismatch;
                    return try parseTuple(T, allocator, value.array);
                }

                if (value != .object) return JsonError.TypeMismatch;
                return try parseStruct(T, allocator, value.object);
            },
            .@"enum" => |e| {
                if (value == .string) {
                    inline for (e.fields) |field| {
                        if (std.mem.eql(u8, value.string, field.name)) {
                            return @enumFromInt(field.value);
                        }
                    }
                }
                if (value == .number) {
                    const n: e.tag_type = @intFromFloat(value.number);
                    return @enumFromInt(n);
                }
                return JsonError.TypeMismatch;
            },
            else => return JsonError.TypeMismatch,
        }
    }

    fn parseStruct(comptime T: type, allocator: Allocator, obj: std.StringHashMap(Value)) !T {
        var result: T = undefined;
        const fields = std.meta.fields(T);

        inline for (fields) |field| {
            const json_name = Stringify.getJsonFieldName(T, field.name);

            if (obj.get(json_name)) |field_value| {
                @field(result, field.name) = try valueToType(field.type, allocator, field_value);
            } else {
                // 检查是否有默认值
                if (field.default_value_ptr) |default_ptr| {
                    const default = @as(*const field.type, @ptrCast(@alignCast(default_ptr))).*;
                    @field(result, field.name) = default;
                } else {
                    // 检查是否为可选类型
                    const field_info = @typeInfo(field.type);
                    if (field_info == .optional) {
                        @field(result, field.name) = null;
                    } else {
                        return JsonError.MissingField;
                    }
                }
            }
        }

        return result;
    }

    fn parseTuple(comptime T: type, allocator: Allocator, arr: []Value) !T {
        var result: T = undefined;
        const fields = std.meta.fields(T);

        if (arr.len < fields.len) return JsonError.MissingField;

        inline for (fields, 0..) |field, i| {
            @field(result, field.name) = try valueToType(field.type, allocator, arr[i]);
        }

        return result;
    }

    fn valueToJson(allocator: Allocator, value: Value) ![]const u8 {
        var stringify = Stringify.init(allocator, .{});
        defer stringify.deinit();

        try writeValueDynamic(&stringify, value);
        return stringify.buffer.toOwnedSlice(allocator);
    }

    fn writeValueDynamic(stringify: *Stringify, value: Value) !void {
        switch (value) {
            .null => try stringify.buffer.appendSlice(stringify.allocator, "null"),
            .bool => |b| {
                if (b) {
                    try stringify.buffer.appendSlice(stringify.allocator, "true");
                } else {
                    try stringify.buffer.appendSlice(stringify.allocator, "false");
                }
            },
            .number => |n| {
                var buf: [64]u8 = undefined;
                const str = std.fmt.bufPrint(&buf, "{d}", .{n}) catch return error.BufferOverflow;
                try stringify.buffer.appendSlice(stringify.allocator, str);
            },
            .string => |s| {
                try stringify.writeString(s);
            },
            .array => |arr| {
                try stringify.buffer.append(stringify.allocator, '[');
                for (arr, 0..) |item, i| {
                    if (i > 0) try stringify.buffer.append(stringify.allocator, ',');
                    try writeValueDynamic(stringify, item);
                }
                try stringify.buffer.append(stringify.allocator, ']');
            },
            .object => |obj| {
                try stringify.buffer.append(stringify.allocator, '{');
                var first = true;
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    if (!first) try stringify.buffer.append(stringify.allocator, ',');
                    first = false;
                    try stringify.writeString(entry.key_ptr.*);
                    try stringify.buffer.append(stringify.allocator, ':');
                    try writeValueDynamic(stringify, entry.value_ptr.*);
                }
                try stringify.buffer.append(stringify.allocator, '}');
            },
        }
    }

    fn freeValue(comptime T: type, allocator: Allocator, value: *T) void {
        const info = @typeInfo(T);

        switch (info) {
            .pointer => |ptr| {
                if (ptr.size == .slice and ptr.child == u8) {
                    allocator.free(value.*);
                }
            },
            .optional => |opt| {
                if (value.*) |*v| {
                    freeValue(opt.child, allocator, v);
                }
            },
            .@"struct" => {
                // 特殊处理 RawMessage 和 Number
                if (T == RawMessage) {
                    value.deinit();
                    return;
                }
                if (T == Number) {
                    value.deinit();
                    return;
                }

                // 检查是否有自定义 deinit 方法
                if (@hasDecl(T, "deinit")) {
                    value.deinit();
                    return;
                }

                const fields = std.meta.fields(T);
                inline for (fields) |field| {
                    freeValue(field.type, allocator, &@field(value.*, field.name));
                }
            },
            else => {},
        }
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Json: 解析基本类型" {
    const allocator = std.testing.allocator;

    // null
    var null_val = try Json.parseValue(allocator, "null");
    try std.testing.expect(null_val.isNull());

    // bool
    var true_val = try Json.parseValue(allocator, "true");
    try std.testing.expectEqual(true, true_val.getBool().?);

    var false_val = try Json.parseValue(allocator, "false");
    try std.testing.expectEqual(false, false_val.getBool().?);

    // number
    var num_val = try Json.parseValue(allocator, "42");
    try std.testing.expectEqual(@as(f64, 42), num_val.getNumber().?);

    var float_val = try Json.parseValue(allocator, "3.14");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), float_val.getNumber().?, 0.001);

    // string
    var str_val = try Json.parseValue(allocator, "\"hello\"");
    defer str_val.deinit(allocator);
    try std.testing.expectEqualStrings("hello", str_val.getString().?);
}

test "Json: 解析数组" {
    const allocator = std.testing.allocator;

    var arr_val = try Json.parseValue(allocator, "[1, 2, 3]");
    defer arr_val.deinit(allocator);

    const arr = arr_val.getArray().?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
    try std.testing.expectEqual(@as(f64, 1), arr[0].getNumber().?);
    try std.testing.expectEqual(@as(f64, 2), arr[1].getNumber().?);
    try std.testing.expectEqual(@as(f64, 3), arr[2].getNumber().?);
}

test "Json: 解析对象" {
    const allocator = std.testing.allocator;

    var obj_val = try Json.parseValue(allocator, "{\"name\":\"张三\",\"age\":25}");
    defer obj_val.deinit(allocator);

    try std.testing.expectEqualStrings("张三", obj_val.get("name").?.getString().?);
    try std.testing.expectEqual(@as(f64, 25), obj_val.get("age").?.getNumber().?);
}

test "Json: 解析转义字符" {
    const allocator = std.testing.allocator;

    var str_val = try Json.parseValue(allocator, "\"hello\\nworld\\t!\"");
    defer str_val.deinit(allocator);

    try std.testing.expectEqualStrings("hello\nworld\t!", str_val.getString().?);
}

test "Json: 序列化基本类型" {
    const allocator = std.testing.allocator;

    // bool
    const bool_str = try Json.marshal(allocator, true);
    defer allocator.free(bool_str);
    try std.testing.expectEqualStrings("true", bool_str);

    // number
    const num_str = try Json.marshal(allocator, @as(i32, 42));
    defer allocator.free(num_str);
    try std.testing.expectEqualStrings("42", num_str);

    // string
    const str_str = try Json.marshal(allocator, "hello");
    defer allocator.free(str_str);
    try std.testing.expectEqualStrings("\"hello\"", str_str);
}

test "Json: 序列化结构体" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
        name: []const u8,
        active: bool,
    };

    const user = User{
        .id = 1,
        .name = "张三",
        .active = true,
    };

    const json_str = try Json.marshal(allocator, user);
    defer allocator.free(json_str);

    // 验证输出包含必要的字段
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"name\":\"张三\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"active\":true") != null);
}

test "Json: 反序列化结构体" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
        name: []const u8,
        age: ?i32 = null,
    };

    const json_str = "{\"id\":1,\"name\":\"张三\",\"age\":25}";
    var user = try Json.unmarshal(User, allocator, json_str);
    defer Json.free(User, allocator, &user);

    try std.testing.expectEqual(@as(i64, 1), user.id);
    try std.testing.expectEqualStrings("张三", user.name);
    try std.testing.expectEqual(@as(?i32, 25), user.age);
}

test "Json: 安全性 - 嵌套深度限制" {
    const allocator = std.testing.allocator;

    // 创建深度嵌套的 JSON
    var deep_json = std.ArrayListUnmanaged(u8){};
    defer deep_json.deinit(allocator);

    for (0..200) |_| {
        try deep_json.append(allocator, '[');
    }
    try deep_json.appendSlice(allocator, "null");
    for (0..200) |_| {
        try deep_json.append(allocator, ']');
    }

    const result = Json.parseValueWithOptions(allocator, deep_json.items, .{ .max_depth = 128 });
    try std.testing.expectError(JsonError.TooDeep, result);
}

test "Json: 安全性 - 无效 JSON 拒绝" {
    const allocator = std.testing.allocator;

    // 未闭合的字符串
    try std.testing.expectError(JsonError.UnterminatedString, Json.parseValue(allocator, "\"hello"));

    // 无效的 token
    try std.testing.expectError(JsonError.UnexpectedCharacter, Json.parseValue(allocator, "undefined"));

    // 无效的数字（以点开头）
    try std.testing.expectError(JsonError.UnexpectedCharacter, Json.parseValue(allocator, ".123"));
}

test "Json: 格式化输出" {
    const allocator = std.testing.allocator;

    const Data = struct {
        name: []const u8,
        value: i32,
    };

    const data = Data{ .name = "test", .value = 42 };
    const pretty_json = try Json.marshalIndent(allocator, data);
    defer allocator.free(pretty_json);

    // 验证包含换行和缩进
    try std.testing.expect(std.mem.indexOf(u8, pretty_json, "\n") != null);
}

test "Json: 可选字段处理" {
    const allocator = std.testing.allocator;

    const Config = struct {
        host: []const u8,
        port: ?i32 = null,
        timeout: ?i32 = null,
    };

    // 部分字段缺失
    const json_str = "{\"host\":\"localhost\",\"port\":8080}";
    var config = try Json.unmarshal(Config, allocator, json_str);
    defer Json.free(Config, allocator, &config);

    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(?i32, 8080), config.port);
    try std.testing.expectEqual(@as(?i32, null), config.timeout);
}

test "Json: Unicode 支持" {
    const allocator = std.testing.allocator;

    // 包含 Unicode 转义的 JSON
    var str_val = try Json.parseValue(allocator, "\"\\u4e2d\\u6587\"");
    defer str_val.deinit(allocator);

    try std.testing.expectEqualStrings("中文", str_val.getString().?);
}

test "RawMessage: 基本功能" {
    const allocator = std.testing.allocator;

    // 创建带 RawMessage 字段的结构体
    const Message = struct {
        type: []const u8,
        payload: RawMessage = .{},
    };

    const json_str = "{\"type\":\"user\",\"payload\":{\"id\":1,\"name\":\"张三\"}}";
    var msg = try Json.unmarshal(Message, allocator, json_str);
    defer Json.free(Message, allocator, &msg);

    try std.testing.expectEqualStrings("user", msg.type);

    // 验证 RawMessage 保留了原始 JSON
    try std.testing.expect(!msg.payload.isEmpty());
    try std.testing.expect(std.mem.indexOf(u8, msg.payload.bytes(), "张三") != null);

    // 延迟解析 RawMessage
    const User = struct {
        id: i64,
        name: []const u8,
    };

    var user = try msg.payload.unmarshal(User, allocator);
    defer Json.free(User, allocator, &user);

    try std.testing.expectEqual(@as(i64, 1), user.id);
    try std.testing.expectEqualStrings("张三", user.name);
}

test "RawMessage: 序列化" {
    const allocator = std.testing.allocator;

    const Message = struct {
        type: []const u8,
        payload: RawMessage,
    };

    // 创建带原始 JSON 的消息
    const msg = Message{
        .type = "event",
        .payload = RawMessage.fromSlice("{\"foo\":\"bar\"}"),
    };

    const json_str = try Json.marshal(allocator, msg);
    defer allocator.free(json_str);

    // 验证 payload 被原样输出
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"payload\":{\"foo\":\"bar\"}") != null);
}

test "自定义序列化: jsonMarshal" {
    const allocator = std.testing.allocator;

    // 自定义时间类型
    const Timestamp = struct {
        epoch: i64,

        pub fn jsonMarshal(self: @This(), alloc: Allocator) ![]const u8 {
            return std.fmt.allocPrint(alloc, "{d}", .{self.epoch});
        }
    };

    const Event = struct {
        name: []const u8,
        time: Timestamp,
    };

    const event = Event{
        .name = "login",
        .time = .{ .epoch = 1702857600 },
    };

    const json_str = try Json.marshal(allocator, event);
    defer allocator.free(json_str);

    // 验证时间被序列化为数字
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"time\":1702857600") != null);
}

test "自定义反序列化: jsonUnmarshal" {
    const allocator = std.testing.allocator;

    // 自定义颜色类型
    const Color = struct {
        r: u8,
        g: u8,
        b: u8,

        pub fn jsonUnmarshal(_: Allocator, value: Value) !@This() {
            if (value == .string) {
                const s = value.string;
                if (s.len == 7 and s[0] == '#') {
                    return .{
                        .r = std.fmt.parseInt(u8, s[1..3], 16) catch return JsonError.TypeMismatch,
                        .g = std.fmt.parseInt(u8, s[3..5], 16) catch return JsonError.TypeMismatch,
                        .b = std.fmt.parseInt(u8, s[5..7], 16) catch return JsonError.TypeMismatch,
                    };
                }
            }
            return JsonError.TypeMismatch;
        }
    };

    const Theme = struct {
        name: []const u8,
        primary: Color,
    };

    const json_str = "{\"name\":\"dark\",\"primary\":\"#1a2b3c\"}";
    var theme = try Json.unmarshal(Theme, allocator, json_str);
    defer Json.free(Theme, allocator, &theme);

    try std.testing.expectEqualStrings("dark", theme.name);
    try std.testing.expectEqual(@as(u8, 0x1a), theme.primary.r);
    try std.testing.expectEqual(@as(u8, 0x2b), theme.primary.g);
    try std.testing.expectEqual(@as(u8, 0x3c), theme.primary.b);
}

test "元组序列化" {
    const allocator = std.testing.allocator;

    const point = .{ @as(i32, 10), @as(i32, 20), @as(i32, 30) };
    const json_str = try Json.marshal(allocator, point);
    defer allocator.free(json_str);

    try std.testing.expectEqualStrings("[10,20,30]", json_str);
}

test "Number: 高精度数值" {
    const allocator = std.testing.allocator;

    // 创建 Number
    var num = try Number.fromString(allocator, "12345678901234567890");
    defer num.deinit();

    try std.testing.expectEqualStrings("12345678901234567890", num.string());

    // 序列化
    const json_str = try num.jsonMarshal(allocator);
    defer allocator.free(json_str);

    try std.testing.expectEqualStrings("12345678901234567890", json_str);
}
