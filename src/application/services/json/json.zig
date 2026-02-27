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
//! var user = try JSON.decode(User, allocator, json_str);
//! defer JSON.free(User, allocator, &user);
//!
//! // 序列化为 JSON
//! const output = try JSON.encode(allocator, user);
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
    pub fn decode(self: RawMessage, comptime T: type, allocator: Allocator) !T {
        if (self.data.len == 0) return JsonError.InvalidJson;
        return JSON.decode(T, allocator, self.data);
    }

    /// 解析为动态 Value
    pub fn parse(self: RawMessage, allocator: Allocator) !Value {
        if (self.data.len == 0) return Value{ .null = {} };
        return JSON.parseValue(allocator, self.data);
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
// 解析缓存 - 类似 Go encoding/json 的缓存机制
// ============================================================================
//
// Go 的 encoding/json 缓存的是**类型元数据**（字段映射、编解码器函数），不是字符串内容。
// 在 Zig 中，由于是编译时元编程，类型信息在编译时就已确定，无需运行时缓存。
//
// 我们真正需要池化的是：
// 1. 解析器对象 - 避免重复分配 Parser 结构
// 2. 序列化缓冲区 - 复用输出缓冲区
// 3. 临时工作内存 - 解析过程中的临时分配
//
// Zig 的编译时泛型（TypedParser/TypedStringify）相当于 Go 的类型元数据缓存。

/// 字段名缓存（仅缓存常量字段名，有大小限制）
/// 这类似于 Go 缓存字段名的做法，但 Zig 中字段名是编译时常量，通常不需要
pub const FieldNameCache = struct {
    const Self = @This();
    const MaxEntries = 256; // 限制最大缓存条目

    allocator: Allocator,
    names: std.StringHashMap(void),
    count: usize = 0,
    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .names = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.names.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.names.deinit();
    }

    /// 缓存字段名（有大小限制，超过则不缓存）
    pub fn cache(self: *Self, name: []const u8) ![]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        // 已存在则直接返回
        if (self.names.getKey(name)) |existing| {
            return existing;
        }

        // 超过限制则不缓存，直接返回原值（调用者需自行管理）
        if (self.count >= MaxEntries) {
            return name;
        }

        const owned = try self.allocator.dupe(u8, name);
        try self.names.put(owned, {});
        self.count += 1;
        return owned;
    }
};

/// 解析器对象池
/// 复用解析器实例，减少内存分配开销
pub const ParserPool = struct {
    const Self = @This();
    const MaxPoolSize = 32;

    allocator: Allocator,
    parsers: std.ArrayListUnmanaged(*Parser),
    mutex: std.Thread.Mutex = .{},
    options: ParseOptions,

    /// 创建解析器池
    pub fn init(allocator: Allocator, options: ParseOptions) Self {
        return .{
            .allocator = allocator,
            .parsers = std.ArrayListUnmanaged(*Parser){},
            .options = options,
        };
    }

    /// 释放解析器池
    pub fn deinit(self: *Self) void {
        for (self.parsers.items) |parser| {
            self.allocator.destroy(parser);
        }
        self.parsers.deinit(self.allocator);
    }

    /// 获取解析器
    pub fn acquire(self: *Self, input: []const u8) !*Parser {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.parsers.items.len > 0) {
            const parser = self.parsers.items[self.parsers.items.len - 1];
            self.parsers.items.len -= 1;
            parser.input = input;
            parser.pos = 0;
            parser.depth = 0;
            return parser;
        }

        const parser = try self.allocator.create(Parser);
        parser.* = Parser.init(self.allocator, input, self.options);
        return parser;
    }

    /// 归还解析器
    pub fn release(self: *Self, parser: *Parser) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.parsers.items.len < MaxPoolSize) {
            self.parsers.append(self.allocator, parser) catch {
                self.allocator.destroy(parser);
            };
        } else {
            self.allocator.destroy(parser);
        }
    }
};

/// 序列化缓冲区池
pub const BufferPool = struct {
    const Self = @This();
    const MaxPoolSize = 16;
    const DefaultBufferSize = 4096;

    allocator: Allocator,
    buffers: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u8)),
    mutex: std.Thread.Mutex = .{},

    /// 创建缓冲区池
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .buffers = std.ArrayListUnmanaged(std.ArrayListUnmanaged(u8)){},
        };
    }

    /// 释放缓冲区池
    pub fn deinit(self: *Self) void {
        for (self.buffers.items) |*buf| {
            buf.deinit(self.allocator);
        }
        self.buffers.deinit(self.allocator);
    }

    /// 获取缓冲区
    pub fn acquire(self: *Self) !std.ArrayListUnmanaged(u8) {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.buffers.items.len > 0) {
            const buf = self.buffers.items[self.buffers.items.len - 1];
            self.buffers.items.len -= 1;
            return buf;
        }

        var buf = std.ArrayListUnmanaged(u8){};
        try buf.ensureTotalCapacity(self.allocator, DefaultBufferSize);
        return buf;
    }

    /// 归还缓冲区
    pub fn release(self: *Self, buf: *std.ArrayListUnmanaged(u8)) void {
        buf.clearRetainingCapacity();

        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.buffers.items.len < MaxPoolSize) {
            self.buffers.append(self.allocator, buf.*) catch {
                buf.deinit(self.allocator);
            };
        } else {
            buf.deinit(self.allocator);
        }
    }
};

/// 高性能 JSON 编解码器
/// 集成对象池和缓冲区复用，减少内存分配
///
/// 设计说明：
/// - Go 的 encoding/json 缓存的是类型元数据，Zig 通过编译时泛型实现
/// - 这里的池化针对的是解析器和缓冲区，不是数据内容
/// - 对于大 JSON，每次解析都是独立的，不会缓存内容
pub const Codec = struct {
    const Self = @This();

    allocator: Allocator,
    parser_pool: ParserPool,
    buffer_pool: BufferPool,
    parse_options: ParseOptions,
    stringify_options: StringifyOptions,

    /// 配置选项
    pub const Config = struct {
        /// 解析选项
        parse_options: ParseOptions = .{},
        /// 序列化选项
        stringify_options: StringifyOptions = .{},
    };

    /// 创建编解码器
    pub fn init(allocator: Allocator, config: Config) !Self {
        return .{
            .allocator = allocator,
            .parser_pool = ParserPool.init(allocator, config.parse_options),
            .buffer_pool = BufferPool.init(allocator),
            .parse_options = config.parse_options,
            .stringify_options = config.stringify_options,
        };
    }

    /// 释放编解码器
    pub fn deinit(self: *Self) void {
        self.parser_pool.deinit();
        self.buffer_pool.deinit();
    }

    /// 解析 JSON 为动态值（使用对象池）
    pub fn parse(self: *Self, input: []const u8) !Value {
        const parser = try self.parser_pool.acquire(input);
        defer self.parser_pool.release(parser);
        return parser.parse();
    }

    /// 反序列化 JSON 为指定类型
    pub fn decode(self: *Self, comptime T: type, input: []const u8) !T {
        var value = try self.parse(input);
        defer value.deinit(self.allocator);
        return try JSON.valueToType(T, self.allocator, value);
    }

    /// 序列化为 JSON（使用缓冲区池）
    pub fn encode(self: *Self, value: anytype) ![]const u8 {
        const buffer = try self.buffer_pool.acquire();

        var stringify = Stringify{
            .allocator = self.allocator,
            .buffer = buffer,
            .options = self.stringify_options,
            .depth = 0,
        };

        const result = stringify.stringify(value) catch |err| {
            self.buffer_pool.release(&stringify.buffer);
            return err;
        };

        // 注意：成功时不归还缓冲区，因为结果使用了该内存
        return result;
    }

    /// 批量解析（适用于 JSON Lines 格式）
    pub fn parseLines(self: *Self, comptime T: type, input: []const u8) ![]T {
        var results = std.ArrayListUnmanaged(T){};
        errdefer {
            for (results.items) |*item| {
                JSON.free(T, self.allocator, item);
            }
            results.deinit(self.allocator);
        }

        var start: usize = 0;
        for (input, 0..) |c, i| {
            if (c == '\n' or i == input.len - 1) {
                const end = if (c == '\n') i else i + 1;
                const line = std.mem.trim(u8, input[start..end], " \t\r");
                if (line.len > 0) {
                    const item = try self.decode(T, line);
                    try results.append(self.allocator, item);
                }
                start = i + 1;
            }
        }

        return try results.toOwnedSlice(self.allocator);
    }
};

/// 全局默认编解码器（可选使用）
var global_codec: ?*Codec = null;
var global_codec_mutex: std.Thread.Mutex = .{};

/// 初始化全局编解码器
pub fn initGlobalCodec(allocator: Allocator, config: Codec.Config) !void {
    global_codec_mutex.lock();
    defer global_codec_mutex.unlock();

    if (global_codec != null) return;

    global_codec = try allocator.create(Codec);
    global_codec.?.* = try Codec.init(allocator, config);
}

/// 释放全局编解码器
pub fn deinitGlobalCodec(allocator: Allocator) void {
    global_codec_mutex.lock();
    defer global_codec_mutex.unlock();

    if (global_codec) |codec| {
        codec.deinit();
        allocator.destroy(codec);
        global_codec = null;
    }
}

/// 获取全局编解码器
pub fn getGlobalCodec() ?*Codec {
    return global_codec;
}

// ============================================================================
// 编译时优化 - 类似 Sonic 的 JIT 编译思路
// ============================================================================

/// 生成编译时优化的结构体解析器
/// 在编译时生成特定类型的解析代码，避免运行时反射
pub fn TypedParser(comptime T: type) type {
    return struct {
        const Self = @This();
        const fields = std.meta.fields(T);

        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// 编译时生成的快速解析
        pub fn parse(self: *Self, input: []const u8) !T {
            var parser = Parser.init(self.allocator, input, .{});
            const value = try parser.parse();
            defer {
                var v = value;
                v.deinit(self.allocator);
            }

            if (value != .object) return JsonError.TypeMismatch;
            return try self.parseObject(value.object);
        }

        fn parseObject(self: *Self, obj: std.StringHashMap(Value)) !T {
            var result: T = undefined;

            // 编译时展开的字段解析
            inline for (fields) |field| {
                const json_name = comptime getFieldJsonName(field.name);

                if (obj.get(json_name)) |field_value| {
                    @field(result, field.name) = try parseField(field.type, self.allocator, field_value);
                } else {
                    // 处理默认值
                    if (field.default_value_ptr) |default_ptr| {
                        const default = @as(*const field.type, @ptrCast(@alignCast(default_ptr))).*;
                        @field(result, field.name) = default;
                    } else if (@typeInfo(field.type) == .optional) {
                        @field(result, field.name) = null;
                    } else {
                        return JsonError.MissingField;
                    }
                }
            }

            return result;
        }

        fn getFieldJsonName(comptime field_name: []const u8) []const u8 {
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

        fn parseField(comptime F: type, allocator: Allocator, value: Value) !F {
            return JSON.valueToType(F, allocator, value);
        }
    };
}

/// 生成编译时优化的序列化器
pub fn TypedStringify(comptime T: type) type {
    return struct {
        const Self = @This();
        const fields = std.meta.fields(T);

        allocator: Allocator,
        buffer: std.ArrayListUnmanaged(u8),

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .buffer = std.ArrayListUnmanaged(u8){},
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
        }

        /// 编译时优化的序列化
        pub fn stringify(self: *Self, value: T) ![]const u8 {
            try self.buffer.append(self.allocator, '{');

            var first = true;
            inline for (fields) |field| {
                const field_value = @field(value, field.name);

                // 跳过 null 可选值
                if (@typeInfo(field.type) == .optional) {
                    if (field_value == null) continue;
                }

                if (!first) try self.buffer.append(self.allocator, ',');
                first = false;

                // 写入字段名
                const json_name = comptime getFieldJsonName(field.name);
                try self.writeString(json_name);
                try self.buffer.append(self.allocator, ':');

                // 写入字段值
                try self.writeValue(field_value);
            }

            try self.buffer.append(self.allocator, '}');
            return self.buffer.toOwnedSlice(self.allocator);
        }

        fn getFieldJsonName(comptime field_name: []const u8) []const u8 {
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

        fn writeString(self: *Self, str: []const u8) !void {
            try self.buffer.append(self.allocator, '"');
            for (str) |c| {
                switch (c) {
                    '"' => try self.buffer.appendSlice(self.allocator, "\\\""),
                    '\\' => try self.buffer.appendSlice(self.allocator, "\\\\"),
                    '\n' => try self.buffer.appendSlice(self.allocator, "\\n"),
                    '\r' => try self.buffer.appendSlice(self.allocator, "\\r"),
                    '\t' => try self.buffer.appendSlice(self.allocator, "\\t"),
                    else => try self.buffer.append(self.allocator, c),
                }
            }
            try self.buffer.append(self.allocator, '"');
        }

        fn writeValue(self: *Self, value: anytype) !void {
            const VT = @TypeOf(value);
            const info = @typeInfo(VT);

            switch (info) {
                .bool => {
                    if (value) {
                        try self.buffer.appendSlice(self.allocator, "true");
                    } else {
                        try self.buffer.appendSlice(self.allocator, "false");
                    }
                },
                .int, .comptime_int => {
                    var buf: [32]u8 = undefined;
                    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch |err| {
                        return err;
                    };
                    try self.buffer.appendSlice(self.allocator, str);
                },
                .float, .comptime_float => {
                    var buf: [64]u8 = undefined;
                    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch |err| {
                        return err;
                    };
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
                    if (ptr.size == .slice and ptr.child == u8) {
                        try self.writeString(value);
                    } else {
                        try self.buffer.appendSlice(self.allocator, "null");
                    }
                },
                else => try self.buffer.appendSlice(self.allocator, "null"),
            }
        }
    };
}

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

            const value = self.parseValue() catch |err| {
                self.allocator.free(key);
                return err;
            };
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
                    // 检查是否为 opaque 或函数类型，这些无法解引用
                    const child_info = @typeInfo(ptr.child);
                    if (child_info == .@"opaque" or child_info == .@"fn") {
                        try self.buffer.appendSlice(self.allocator, "null");
                    } else {
                        try self.writeValue(value.*);
                    }
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
                        const hex = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch |err| {
                            return err;
                        };
                        try self.buffer.appendSlice(self.allocator, hex);
                    } else if (c >= 0x80 and self.options.escape_non_ascii) {
                        var buf: [6]u8 = undefined;
                        const hex = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch |err| {
                            return err;
                        };
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

            // 处理 omit_null 选项（在编译时检查类型）
            const is_optional = @typeInfo(field.type) == .optional;
            const should_skip = if (is_optional)
                (if (self.options.omit_null) field_value == null else false)
            else
                false;

            if (!should_skip) {
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
pub const JSON = struct {
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
    pub fn decode(comptime T: type, allocator: Allocator, input: []const u8) !T {
        return decodeWithOptions(T, allocator, input, .{});
    }

    /// 带选项的反序列化
    pub fn decodeWithOptions(comptime T: type, allocator: Allocator, input: []const u8, options: ParseOptions) !T {
        var value = try parseValueWithOptions(allocator, input, options);
        defer value.deinit(allocator);
        return try valueToType(T, allocator, value);
    }

    /// 将值序列化为 JSON 字符串（类似 Go 的 json.Marshal）
    pub fn encode(allocator: Allocator, value: anytype) ![]const u8 {
        return encodeWithOptions(allocator, value, .{});
    }

    /// 带选项的序列化
    pub fn encodeWithOptions(allocator: Allocator, value: anytype, options: StringifyOptions) ![]const u8 {
        var stringify = Stringify.init(allocator, options);
        defer stringify.deinit();
        return stringify.stringify(value);
    }

    /// 格式化 JSON 输出
    pub fn encodeIndent(allocator: Allocator, value: anytype) ![]const u8 {
        return encodeWithOptions(allocator, value, .{ .pretty = true });
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
    var null_val = try JSON.parseValue(allocator, "null");
    try std.testing.expect(null_val.isNull());

    // bool
    var true_val = try JSON.parseValue(allocator, "true");
    try std.testing.expectEqual(true, true_val.getBool().?);

    var false_val = try JSON.parseValue(allocator, "false");
    try std.testing.expectEqual(false, false_val.getBool().?);

    // number
    var num_val = try JSON.parseValue(allocator, "42");
    try std.testing.expectEqual(@as(f64, 42), num_val.getNumber().?);

    var float_val = try JSON.parseValue(allocator, "3.14");
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), float_val.getNumber().?, 0.001);

    // string
    var str_val = try JSON.parseValue(allocator, "\"hello\"");
    defer str_val.deinit(allocator);
    try std.testing.expectEqualStrings("hello", str_val.getString().?);
}

test "Json: 解析数组" {
    const allocator = std.testing.allocator;

    var arr_val = try JSON.parseValue(allocator, "[1, 2, 3]");
    defer arr_val.deinit(allocator);

    const arr = arr_val.getArray().?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
    try std.testing.expectEqual(@as(f64, 1), arr[0].getNumber().?);
    try std.testing.expectEqual(@as(f64, 2), arr[1].getNumber().?);
    try std.testing.expectEqual(@as(f64, 3), arr[2].getNumber().?);
}

test "Json: 解析对象" {
    const allocator = std.testing.allocator;

    var obj_val = try JSON.parseValue(allocator, "{\"name\":\"张三\",\"age\":25}");
    defer obj_val.deinit(allocator);

    try std.testing.expectEqualStrings("张三", obj_val.get("name").?.getString().?);
    try std.testing.expectEqual(@as(f64, 25), obj_val.get("age").?.getNumber().?);
}

test "Json: 解析转义字符" {
    const allocator = std.testing.allocator;

    var str_val = try JSON.parseValue(allocator, "\"hello\\nworld\\t!\"");
    defer str_val.deinit(allocator);

    try std.testing.expectEqualStrings("hello\nworld\t!", str_val.getString().?);
}

test "Json: 序列化基本类型" {
    const allocator = std.testing.allocator;

    // bool
    const bool_str = try JSON.encode(allocator, true);
    defer allocator.free(bool_str);
    try std.testing.expectEqualStrings("true", bool_str);

    // number
    const num_str = try JSON.encode(allocator, @as(i32, 42));
    defer allocator.free(num_str);
    try std.testing.expectEqualStrings("42", num_str);

    // string
    const str_str = try JSON.encode(allocator, "hello");
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

    const json_str = try JSON.encode(allocator, user);
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
    var user = try JSON.decode(User, allocator, json_str);
    defer JSON.free(User, allocator, &user);

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

    const result = JSON.parseValueWithOptions(allocator, deep_json.items, .{ .max_depth = 128 });
    try std.testing.expectError(JsonError.TooDeep, result);
}

test "Json: 安全性 - 无效 JSON 拒绝" {
    const allocator = std.testing.allocator;

    // 未闭合的字符串
    try std.testing.expectError(JsonError.UnterminatedString, JSON.parseValue(allocator, "\"hello"));

    // 无效的 token
    try std.testing.expectError(JsonError.UnexpectedCharacter, JSON.parseValue(allocator, "undefined"));

    // 无效的数字（以点开头）
    try std.testing.expectError(JsonError.UnexpectedCharacter, JSON.parseValue(allocator, ".123"));
}

test "Json: 格式化输出" {
    const allocator = std.testing.allocator;

    const Data = struct {
        name: []const u8,
        value: i32,
    };

    const data = Data{ .name = "test", .value = 42 };
    const pretty_json = try JSON.encodeIndent(allocator, data);
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
    var config = try JSON.decode(Config, allocator, json_str);
    defer JSON.free(Config, allocator, &config);

    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(?i32, 8080), config.port);
    try std.testing.expectEqual(@as(?i32, null), config.timeout);
}

test "Json: Unicode 支持" {
    const allocator = std.testing.allocator;

    // 包含 Unicode 转义的 JSON
    var str_val = try JSON.parseValue(allocator, "\"\\u4e2d\\u6587\"");
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
    var msg = try JSON.decode(Message, allocator, json_str);
    defer JSON.free(Message, allocator, &msg);

    try std.testing.expectEqualStrings("user", msg.type);

    // 验证 RawMessage 保留了原始 JSON
    try std.testing.expect(!msg.payload.isEmpty());
    try std.testing.expect(std.mem.indexOf(u8, msg.payload.bytes(), "张三") != null);

    // 延迟解析 RawMessage
    const User = struct {
        id: i64,
        name: []const u8,
    };

    var user = try msg.payload.decode(User, allocator);
    defer JSON.free(User, allocator, &user);

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

    const json_str = try JSON.encode(allocator, msg);
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

    const json_str = try JSON.encode(allocator, event);
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
    var theme = try JSON.decode(Theme, allocator, json_str);
    defer JSON.free(Theme, allocator, &theme);

    try std.testing.expectEqualStrings("dark", theme.name);
    try std.testing.expectEqual(@as(u8, 0x1a), theme.primary.r);
    try std.testing.expectEqual(@as(u8, 0x2b), theme.primary.g);
    try std.testing.expectEqual(@as(u8, 0x3c), theme.primary.b);
}

test "元组序列化" {
    const allocator = std.testing.allocator;

    const point = .{ @as(i32, 10), @as(i32, 20), @as(i32, 30) };
    const json_str = try JSON.encode(allocator, point);
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

test "FieldNameCache: 字段名缓存" {
    const allocator = std.testing.allocator;

    var cache = FieldNameCache.init(allocator);
    defer cache.deinit();

    // 缓存字段名
    const s1 = try cache.cache("id");
    const s2 = try cache.cache("id");
    const s3 = try cache.cache("name");

    // 相同名称应该返回相同指针
    try std.testing.expectEqual(s1.ptr, s2.ptr);

    // 不同名称应该返回不同指针
    try std.testing.expect(s1.ptr != s3.ptr);

    // 验证内容
    try std.testing.expectEqualStrings("id", s1);
    try std.testing.expectEqualStrings("name", s3);
}

test "Codec: 高性能编解码器" {
    const allocator = std.testing.allocator;

    var codec = try Codec.init(allocator, .{});
    defer codec.deinit();

    const User = struct {
        id: i64,
        name: []const u8,
    };

    // 解析
    const json_str = "{\"id\":1,\"name\":\"张三\"}";
    var user = try codec.decode(User, json_str);
    defer JSON.free(User, allocator, &user);

    try std.testing.expectEqual(@as(i64, 1), user.id);
    try std.testing.expectEqualStrings("张三", user.name);

    // 序列化
    const output = try codec.encode(user);
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":1") != null);
}

test "Codec: 批量解析 JSON Lines" {
    const allocator = std.testing.allocator;

    var codec = try Codec.init(allocator, .{});
    defer codec.deinit();

    const Item = struct {
        id: i64,
        value: []const u8,
    };

    const input =
        \\{"id":1,"value":"a"}
        \\{"id":2,"value":"b"}
        \\{"id":3,"value":"c"}
    ;

    const items = try codec.parseLines(Item, input);
    defer {
        for (items) |*item| {
            JSON.free(Item, allocator, item);
        }
        allocator.free(items);
    }

    try std.testing.expectEqual(@as(usize, 3), items.len);
    try std.testing.expectEqual(@as(i64, 1), items[0].id);
    try std.testing.expectEqual(@as(i64, 2), items[1].id);
    try std.testing.expectEqual(@as(i64, 3), items[2].id);
}

test "TypedParser: 编译时优化解析" {
    const allocator = std.testing.allocator;

    const Config = struct {
        host: []const u8,
        port: i32,
        debug: bool = false,
    };

    var parser = TypedParser(Config).init(allocator);

    const json_str = "{\"host\":\"localhost\",\"port\":8080,\"debug\":true}";
    var config = try parser.parse(json_str);
    defer JSON.free(Config, allocator, &config);

    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(i32, 8080), config.port);
    try std.testing.expectEqual(true, config.debug);
}

test "TypedStringify: 编译时优化序列化" {
    const allocator = std.testing.allocator;

    const Config = struct {
        host: []const u8,
        port: i32,
        enabled: bool,
    };

    var stringify = TypedStringify(Config).init(allocator);
    defer stringify.deinit();

    const config = Config{
        .host = "localhost",
        .port = 3000,
        .enabled = true,
    };

    const json_str = try stringify.stringify(config);
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"host\":\"localhost\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"port\":3000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"enabled\":true") != null);
}

test "ParserPool: 解析器对象池" {
    const allocator = std.testing.allocator;

    var pool = ParserPool.init(allocator, .{});
    defer pool.deinit();

    // 获取多个解析器
    const p1 = try pool.acquire("{\"a\":1}");
    const p2 = try pool.acquire("{\"b\":2}");

    // 归还解析器
    pool.release(p1);
    pool.release(p2);

    // 再次获取应该复用
    const p3 = try pool.acquire("{\"c\":3}");
    defer pool.release(p3);

    // 验证解析器可用
    var value = try p3.parse();
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
}

test "BufferPool: 缓冲区对象池" {
    const allocator = std.testing.allocator;

    var pool = BufferPool.init(allocator);
    defer pool.deinit();

    // 获取缓冲区
    var buf1 = try pool.acquire();
    try buf1.appendSlice(allocator, "hello");

    // 归还缓冲区
    pool.release(&buf1);

    // 再次获取应该是空的（已清空）
    var buf2 = try pool.acquire();
    defer pool.release(&buf2);

    try std.testing.expectEqual(@as(usize, 0), buf2.items.len);
}

// ============================================================================
// Null 处理测试
// ============================================================================

test "Null: 解析 null 值" {
    const allocator = std.testing.allocator;

    // 直接解析 null
    var null_val = try JSON.parseValue(allocator, "null");
    try std.testing.expect(null_val.isNull());
    try std.testing.expect(null_val == .null);
}

test "Null: 对象中的 null 字段" {
    const allocator = std.testing.allocator;

    const json_str = "{\"name\":\"test\",\"value\":null,\"count\":0}";
    var obj = try JSON.parseValue(allocator, json_str);
    defer obj.deinit(allocator);

    try std.testing.expect(obj == .object);
    try std.testing.expect(obj.get("value").?.isNull());
    try std.testing.expectEqualStrings("test", obj.get("name").?.getString().?);
}

test "Null: 数组中的 null 元素" {
    const allocator = std.testing.allocator;

    const json_str = "[1, null, \"hello\", null, true]";
    var arr = try JSON.parseValue(allocator, json_str);
    defer arr.deinit(allocator);

    try std.testing.expect(arr == .array);
    const items = arr.getArray().?;
    try std.testing.expectEqual(@as(usize, 5), items.len);
    try std.testing.expect(items[1].isNull());
    try std.testing.expect(items[3].isNull());
    try std.testing.expectEqual(@as(f64, 1), items[0].getNumber().?);
}

test "Null: 反序列化到可选类型" {
    const allocator = std.testing.allocator;

    const User = struct {
        name: []const u8,
        email: ?[]const u8 = null,
        age: ?i32 = null,
        score: ?f64 = null,
    };

    // email 为 null
    const json1 = "{\"name\":\"张三\",\"email\":null,\"age\":25}";
    var user1 = try JSON.decode(User, allocator, json1);
    defer JSON.free(User, allocator, &user1);

    try std.testing.expectEqualStrings("张三", user1.name);
    try std.testing.expectEqual(@as(?[]const u8, null), user1.email);
    try std.testing.expectEqual(@as(?i32, 25), user1.age);
    try std.testing.expectEqual(@as(?f64, null), user1.score);

    // 字段完全缺失
    const json2 = "{\"name\":\"李四\"}";
    var user2 = try JSON.decode(User, allocator, json2);
    defer JSON.free(User, allocator, &user2);

    try std.testing.expectEqualStrings("李四", user2.name);
    try std.testing.expectEqual(@as(?[]const u8, null), user2.email);
    try std.testing.expectEqual(@as(?i32, null), user2.age);
}

test "Null: 序列化可选类型" {
    const allocator = std.testing.allocator;

    const Config = struct {
        host: []const u8,
        port: ?i32,
        timeout: ?i32,
    };

    const config = Config{
        .host = "localhost",
        .port = 8080,
        .timeout = null,
    };

    const json_str = try JSON.encode(allocator, config);
    defer allocator.free(json_str);

    // 验证包含 null
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"timeout\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"port\":8080") != null);
}

test "Null: 序列化时省略 null 字段" {
    const allocator = std.testing.allocator;

    const Config = struct {
        host: []const u8,
        port: ?i32,
        timeout: ?i32,
    };

    const config = Config{
        .host = "localhost",
        .port = 8080,
        .timeout = null,
    };

    const json_str = try JSON.encodeWithOptions(allocator, config, .{ .omit_null = true });
    defer allocator.free(json_str);

    // timeout 应该被省略
    try std.testing.expect(std.mem.indexOf(u8, json_str, "timeout") == null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"port\":8080") != null);
}

// ============================================================================
// 复杂嵌套结构测试
// ============================================================================

test "复杂嵌套: 多层对象" {
    const allocator = std.testing.allocator;

    const Address = struct {
        city: []const u8,
        zip: ?[]const u8 = null,
    };

    const Company = struct {
        name: []const u8,
        address: Address,
    };

    const Employee = struct {
        id: i64,
        name: []const u8,
        company: Company,
    };

    const json_str =
        \\{"id":1,"name":"张三","company":{"name":"科技公司","address":{"city":"北京","zip":"100000"}}}
    ;

    var emp = try JSON.decode(Employee, allocator, json_str);
    defer JSON.free(Employee, allocator, &emp);

    try std.testing.expectEqual(@as(i64, 1), emp.id);
    try std.testing.expectEqualStrings("张三", emp.name);
    try std.testing.expectEqualStrings("科技公司", emp.company.name);
    try std.testing.expectEqualStrings("北京", emp.company.address.city);
    try std.testing.expectEqualStrings("100000", emp.company.address.zip.?);
}

test "复杂嵌套: 嵌套数组" {
    const allocator = std.testing.allocator;

    const json_str = "[[1,2],[3,4],[5,6]]";
    var arr = try JSON.parseValue(allocator, json_str);
    defer arr.deinit(allocator);

    try std.testing.expect(arr == .array);
    const outer = arr.getArray().?;
    try std.testing.expectEqual(@as(usize, 3), outer.len);

    const inner0 = outer[0].getArray().?;
    try std.testing.expectEqual(@as(f64, 1), inner0[0].getNumber().?);
    try std.testing.expectEqual(@as(f64, 2), inner0[1].getNumber().?);
}

test "复杂嵌套: 对象数组" {
    const allocator = std.testing.allocator;

    const json_str =
        \\[{"id":1,"name":"a"},{"id":2,"name":"b"},{"id":3,"name":"c"}]
    ;

    var arr = try JSON.parseValue(allocator, json_str);
    defer arr.deinit(allocator);

    try std.testing.expect(arr == .array);
    const items = arr.getArray().?;
    try std.testing.expectEqual(@as(usize, 3), items.len);

    try std.testing.expectEqual(@as(f64, 1), items[0].get("id").?.getNumber().?);
    try std.testing.expectEqualStrings("a", items[0].get("name").?.getString().?);
}

// ============================================================================
// 异常情况和边界测试
// ============================================================================

test "异常: 空字符串" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.InvalidJson, JSON.parseValue(allocator, ""));
}

test "异常: 只有空白字符" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.InvalidJson, JSON.parseValue(allocator, "   \t\n  "));
}

test "异常: 未闭合的对象" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.UnexpectedToken, JSON.parseValue(allocator, "{\"key\":1"));
}

test "异常: 未闭合的数组" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.UnexpectedToken, JSON.parseValue(allocator, "[1,2,3"));
}

test "异常: 无效的数字格式" {
    const allocator = std.testing.allocator;

    // 以点开头
    try std.testing.expectError(JsonError.UnexpectedCharacter, JSON.parseValue(allocator, ".5"));

    // 多个负号
    try std.testing.expectError(JsonError.InvalidNumber, JSON.parseValue(allocator, "--5"));

    // 前导零后跟数字
    // 注意：这在某些解析器中可能是有效的，我们只检查基本格式
}

test "异常: 无效的转义序列" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.InvalidEscape, JSON.parseValue(allocator, "\"hello\\xworld\""));
}

test "异常: 无效的 Unicode 转义" {
    const allocator = std.testing.allocator;

    // 不完整的 Unicode 转义
    try std.testing.expectError(JsonError.InvalidUnicode, JSON.parseValue(allocator, "\"\\u12\""));

    // 无效的十六进制字符
    try std.testing.expectError(JsonError.InvalidUnicode, JSON.parseValue(allocator, "\"\\uGGGG\""));
}

test "异常: 对象键不是字符串" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.ObjectKeyNotString, JSON.parseValue(allocator, "{123:\"value\"}"));
}

test "异常: 缺少冒号" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.UnexpectedCharacter, JSON.parseValue(allocator, "{\"key\"\"value\"}"));
}

test "异常: 缺少逗号" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(JsonError.UnexpectedCharacter, JSON.parseValue(allocator, "{\"a\":1\"b\":2}"));
}

test "异常: 类型不匹配" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
        name: []const u8,
    };

    // id 应该是数字，但传入了字符串
    try std.testing.expectError(JsonError.TypeMismatch, JSON.decode(User, allocator, "{\"id\":\"not_a_number\",\"name\":\"test\"}"));

    // name 应该是字符串，但传入了数字
    try std.testing.expectError(JsonError.TypeMismatch, JSON.decode(User, allocator, "{\"id\":1,\"name\":123}"));
}

test "异常: 缺少必需字段" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
        name: []const u8,
    };

    // 缺少 name 字段
    try std.testing.expectError(JsonError.MissingField, JSON.decode(User, allocator, "{\"id\":1}"));
}

test "异常: 根级别不是对象" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
    };

    // 传入数组而不是对象
    try std.testing.expectError(JsonError.TypeMismatch, JSON.decode(User, allocator, "[1,2,3]"));

    // 传入基本类型
    try std.testing.expectError(JsonError.TypeMismatch, JSON.decode(User, allocator, "123"));
}

// ============================================================================
// 边界值测试
// ============================================================================

test "边界: 空对象" {
    const allocator = std.testing.allocator;

    var obj = try JSON.parseValue(allocator, "{}");
    defer obj.deinit(allocator);

    try std.testing.expect(obj == .object);
}

test "边界: 空数组" {
    const allocator = std.testing.allocator;

    var arr = try JSON.parseValue(allocator, "[]");
    defer arr.deinit(allocator);

    try std.testing.expect(arr == .array);
    try std.testing.expectEqual(@as(usize, 0), arr.getArray().?.len);
}

test "边界: 空字符串值" {
    const allocator = std.testing.allocator;

    var str = try JSON.parseValue(allocator, "\"\"");
    defer str.deinit(allocator);

    try std.testing.expect(str == .string);
    try std.testing.expectEqualStrings("", str.getString().?);
}

test "边界: 大整数" {
    const allocator = std.testing.allocator;

    // 大数值（注意：f64 精度有限，这里只测试解析成功）
    var num = try JSON.parseValue(allocator, "9007199254740992");
    try std.testing.expect(num.getNumber() != null);
}

test "边界: 科学计数法" {
    const allocator = std.testing.allocator;

    var num1 = try JSON.parseValue(allocator, "1.5e10");
    try std.testing.expectApproxEqAbs(@as(f64, 1.5e10), num1.getNumber().?, 1);

    var num2 = try JSON.parseValue(allocator, "1.5E-5");
    try std.testing.expectApproxEqAbs(@as(f64, 1.5e-5), num2.getNumber().?, 1e-10);

    var num3 = try JSON.parseValue(allocator, "-2.5e+3");
    try std.testing.expectApproxEqAbs(@as(f64, -2500), num3.getNumber().?, 0.001);
}

test "边界: 特殊字符字符串" {
    const allocator = std.testing.allocator;

    // 包含所有需要转义的字符
    var str = try JSON.parseValue(allocator, "\"line1\\nline2\\ttab\\r\\\"quote\\\\slash\"");
    defer str.deinit(allocator);

    try std.testing.expectEqualStrings("line1\nline2\ttab\r\"quote\\slash", str.getString().?);
}

test "边界: 深层嵌套（接近限制）" {
    const allocator = std.testing.allocator;

    // 创建 50 层嵌套（在默认 128 限制内）
    var json = std.ArrayListUnmanaged(u8){};
    defer json.deinit(allocator);

    for (0..50) |_| {
        try json.append(allocator, '[');
    }
    try json.appendSlice(allocator, "null");
    for (0..50) |_| {
        try json.append(allocator, ']');
    }

    var value = try JSON.parseValue(allocator, json.items);
    defer value.deinit(allocator);

    try std.testing.expect(value == .array);
}

test "边界: 带空白的 JSON" {
    const allocator = std.testing.allocator;

    const json_str =
        \\  {
        \\    "name"  :  "test"  ,
        \\    "value" :  123
        \\  }
    ;

    var obj = try JSON.parseValue(allocator, json_str);
    defer obj.deinit(allocator);

    try std.testing.expectEqualStrings("test", obj.get("name").?.getString().?);
    try std.testing.expectEqual(@as(f64, 123), obj.get("value").?.getNumber().?);
}

// ============================================================================
// RawMessage 边界测试
// ============================================================================

test "RawMessage: 嵌套 null 值" {
    const allocator = std.testing.allocator;

    const Message = struct {
        type: []const u8,
        data: RawMessage = .{},
    };

    const json_str = "{\"type\":\"empty\",\"data\":null}";
    var msg = try JSON.decode(Message, allocator, json_str);
    defer JSON.free(Message, allocator, &msg);

    try std.testing.expectEqualStrings("empty", msg.type);
    // RawMessage 应该包含 "null"
    try std.testing.expectEqualStrings("null", msg.data.bytes());
}

test "RawMessage: 空对象" {
    const allocator = std.testing.allocator;

    const Message = struct {
        type: []const u8,
        data: RawMessage = .{},
    };

    const json_str = "{\"type\":\"empty\",\"data\":{}}";
    var msg = try JSON.decode(Message, allocator, json_str);
    defer JSON.free(Message, allocator, &msg);

    try std.testing.expectEqualStrings("empty", msg.type);
    try std.testing.expectEqualStrings("{}", msg.data.bytes());
}

// ============================================================================
// 内存安全测试
// ============================================================================

test "内存安全: 错误时不泄漏内存" {
    const allocator = std.testing.allocator;

    const User = struct {
        id: i64,
        name: []const u8,
    };

    // 这些都应该返回错误，但不应该泄漏内存
    // 使用 expectError 确保错误被正确处理
    try std.testing.expectError(JsonError.MissingField, JSON.decode(User, allocator, "{\"id\":1}"));
    try std.testing.expectError(JsonError.TypeMismatch, JSON.decode(User, allocator, "{\"id\":\"wrong\",\"name\":\"test\"}"));
    try std.testing.expectError(JsonError.ObjectKeyNotString, JSON.parseValue(allocator, "{invalid}"));
    try std.testing.expectError(JsonError.UnexpectedToken, JSON.parseValue(allocator, "[1,2,"));
}

test "内存安全: 部分解析后的清理" {
    const allocator = std.testing.allocator;

    // 测试各种格式错误，确保不泄漏内存
    // 注意：具体错误类型取决于解析器在哪里失败
    _ = JSON.parseValue(allocator, "[1, 2, \"hello\", {\"key\":}]") catch {};
    _ = JSON.parseValue(allocator, "{\"a\":1,\"b\":2,\"c\":}") catch {};
}
