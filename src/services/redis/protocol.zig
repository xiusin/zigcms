//! RESP (Redis Serialization Protocol) 协议解析器
//!
//! Redis 使用 RESP 协议进行客户端-服务器通信。
//! 本模块实现了 RESP2 协议的编码和解码。
//!
//! ## RESP 协议格式
//! - 简单字符串: `+OK\r\n`
//! - 错误: `-ERR message\r\n`
//! - 整数: `:1000\r\n`
//! - 批量字符串: `$6\r\nfoobar\r\n`
//! - 数组: `*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n`
//!
//! ## Zig vs Go: 解析器实现对比
//!
//! Go 实现通常使用 bufio.Reader:
//! ```go
//! func (p *Protocol) ReadReply() ([]byte, error) {
//!     line, err := p.reader.ReadBytes('\n')
//!     // ...
//! }
//! ```
//!
//! Zig 实现更注重零拷贝和内存控制：
//! - 使用切片引用而非复制数据
//! - 显式的内存分配器参数
//! - 编译时类型检查

const std = @import("std");
const types = @import("types.zig");

const RedisError = types.RedisError;
const RedisValue = types.RedisValue;
const RespType = types.RespType;
const CRLF = types.CRLF;

/// RESP 协议解析器
///
/// ## 关于 Zig 的 struct 设计
///
/// 在 Go 中你可能这样设计：
/// ```go
/// type Protocol struct {
///     reader *bufio.Reader
///     writer *bufio.Writer
/// }
/// ```
///
/// Zig 中我们使用泛型来支持不同的流类型：
/// 这允许在测试时传入模拟的流，而不需要接口抽象
pub fn Protocol(comptime StreamType: type) type {
    return struct {
        const Self = @This();

        /// 读取错误类型
        pub const ReadError = RedisError || std.mem.Allocator.Error;

        /// 底层流
        stream: StreamType,
        /// 内存分配器
        /// 
        /// ## 为什么需要分配器参数？
        /// 
        /// Go 中内存分配是隐式的：`make([]byte, n)`
        /// Zig 要求显式传递分配器，好处：
        /// 1. 可以使用不同的分配策略（arena、固定缓冲区等）
        /// 2. 便于追踪内存使用
        /// 3. 测试时可以检测内存泄漏
        allocator: std.mem.Allocator,
        /// 读取缓冲区
        read_buffer: [4096]u8 = undefined,
        /// 缓冲区中的有效数据长度
        buffer_len: usize = 0,
        /// 当前读取位置
        buffer_pos: usize = 0,

        /// 初始化协议解析器
        pub fn init(stream: StreamType, allocator: std.mem.Allocator) Self {
            return Self{
                .stream = stream,
                .allocator = allocator,
            };
        }

        /// 读取一行数据（直到 CRLF）
        ///
        /// ## 错误处理对比
        ///
        /// Go:
        /// ```go
        /// line, err := reader.ReadBytes('\n')
        /// if err != nil {
        ///     return nil, err
        /// }
        /// ```
        ///
        /// Zig 使用 `!` 返回错误联合类型：
        /// - 成功: 返回切片
        /// - 失败: 返回错误
        ///
        /// 调用方必须处理错误：
        /// ```zig
        /// const line = try self.readLine(); // 错误会向上传播
        /// // 或者
        /// const line = self.readLine() catch |err| { ... };
        /// ```
        fn readLine(self: *Self) ![]const u8 {
            var line_buffer = std.ArrayListUnmanaged(u8){};
            errdefer line_buffer.deinit(self.allocator);

            while (true) {
                // 需要从流中读取更多数据
                if (self.buffer_pos >= self.buffer_len) {
                    const bytes_read = self.stream.read(&self.read_buffer) catch |err| {
                        return switch (err) {
                            error.ConnectionResetByPeer,
                            error.BrokenPipe,
                            => RedisError.ConnectionClosed,
                            else => RedisError.ReadFailed,
                        };
                    };
                    if (bytes_read == 0) {
                        return RedisError.ConnectionClosed;
                    }
                    self.buffer_len = bytes_read;
                    self.buffer_pos = 0;
                }

                // 在缓冲区中查找 CRLF
                const remaining = self.read_buffer[self.buffer_pos..self.buffer_len];
                if (std.mem.indexOf(u8, remaining, CRLF)) |crlf_pos| {
                    // 找到了 CRLF
                    const line_part = remaining[0..crlf_pos];
                    try line_buffer.appendSlice(self.allocator, line_part);
                    self.buffer_pos += crlf_pos + 2; // 跳过 CRLF
                    return line_buffer.toOwnedSlice(self.allocator);
                } else {
                    // 没找到 CRLF，将剩余数据加入缓冲区
                    try line_buffer.appendSlice(self.allocator, remaining);
                    self.buffer_pos = self.buffer_len;
                }
            }
        }

        /// 读取指定字节数的数据
        fn readExact(self: *Self, count: usize) ![]u8 {
            var result = try self.allocator.alloc(u8, count);
            errdefer self.allocator.free(result);

            var total_read: usize = 0;

            while (total_read < count) {
                // 先使用缓冲区中的数据
                if (self.buffer_pos < self.buffer_len) {
                    const remaining_buffer = self.read_buffer[self.buffer_pos..self.buffer_len];
                    const remaining_needed = count - total_read;
                    const to_copy = @min(remaining_buffer.len, remaining_needed);

                    @memcpy(result[total_read .. total_read + to_copy], remaining_buffer[0..to_copy]);
                    total_read += to_copy;
                    self.buffer_pos += to_copy;
                } else {
                    // 缓冲区空了，从流中读取
                    const bytes_read = self.stream.read(&self.read_buffer) catch |err| {
                        return switch (err) {
                            error.ConnectionResetByPeer,
                            error.BrokenPipe,
                            => RedisError.ConnectionClosed,
                            else => RedisError.ReadFailed,
                        };
                    };
                    if (bytes_read == 0) {
                        return RedisError.ConnectionClosed;
                    }
                    self.buffer_len = bytes_read;
                    self.buffer_pos = 0;
                }
            }

            return result;
        }

        /// 跳过 CRLF
        fn skipCRLF(self: *Self) !void {
            // 先尝试从缓冲区跳过
            if (self.buffer_pos + 2 <= self.buffer_len) {
                if (self.read_buffer[self.buffer_pos] == '\r' and
                    self.read_buffer[self.buffer_pos + 1] == '\n')
                {
                    self.buffer_pos += 2;
                    return;
                }
            }

            // 否则读取 2 字节并验证
            var crlf_buf: [2]u8 = undefined;
            var read_count: usize = 0;

            while (read_count < 2) {
                if (self.buffer_pos < self.buffer_len) {
                    crlf_buf[read_count] = self.read_buffer[self.buffer_pos];
                    self.buffer_pos += 1;
                    read_count += 1;
                } else {
                    const bytes_read = self.stream.read(&self.read_buffer) catch {
                        return RedisError.ReadFailed;
                    };
                    if (bytes_read == 0) {
                        return RedisError.ConnectionClosed;
                    }
                    self.buffer_len = bytes_read;
                    self.buffer_pos = 0;
                }
            }

            if (crlf_buf[0] != '\r' or crlf_buf[1] != '\n') {
                return RedisError.ProtocolError;
            }
        }

        /// 读取并解析 RESP 响应
        ///
        /// ## 递归下降解析
        ///
        /// RESP 协议是自描述的，可以递归解析：
        /// - 数组包含多个元素，每个元素可以是任意 RESP 类型
        /// - 这里使用递归实现，对于深度嵌套的响应要注意栈溢出
        ///
        /// ## 内存所有权
        ///
        /// 返回的 RedisValue 中的字符串由调用方负责释放
        /// 使用 `defer value.deinit(allocator)` 或在合适时机释放
        pub fn readReply(self: *Self) ReadError!RedisValue {
            const line = try self.readLine();
            defer self.allocator.free(line);

            if (line.len == 0) {
                return RedisError.ProtocolError;
            }

            const type_byte = line[0];
            const content = line[1..];

            // 解析类型前缀
            const resp_type = RespType.fromByte(type_byte) orelse {
                return RedisError.ProtocolError;
            };

            return switch (resp_type) {
                .simple_string => self.parseSimpleString(content),
                .err => self.parseError(content),
                .integer => self.parseInteger(content),
                .bulk_string => self.parseBulkString(content),
                .array => self.parseArray(content),
            };
        }

        /// 解析简单字符串
        fn parseSimpleString(self: *Self, content: []const u8) !RedisValue {
            // 复制字符串，因为调用方需要拥有这块内存
            const str = try self.allocator.dupe(u8, content);
            return RedisValue{ .string = str };
        }

        /// 解析错误
        fn parseError(self: *Self, content: []const u8) !RedisValue {
            const err_msg = try self.allocator.dupe(u8, content);
            return RedisValue{ .err = err_msg };
        }

        /// 解析整数
        ///
        /// ## 整数解析
        ///
        /// Go: `strconv.ParseInt(s, 10, 64)`
        /// Zig: `std.fmt.parseInt(i64, s, 10)`
        ///
        /// Zig 的解析函数返回错误联合类型，更安全
        fn parseInteger(_: *Self, content: []const u8) !RedisValue {
            const value = std.fmt.parseInt(i64, content, 10) catch {
                return RedisError.ProtocolError;
            };
            return RedisValue{ .integer = value };
        }

        /// 解析批量字符串
        ///
        /// 格式: `$<length>\r\n<data>\r\n`
        /// 特殊情况: `$-1\r\n` 表示 nil
        fn parseBulkString(self: *Self, length_str: []const u8) !RedisValue {
            const length = std.fmt.parseInt(i64, length_str, 10) catch {
                return RedisError.ProtocolError;
            };

            // $-1 表示 nil
            if (length < 0) {
                return RedisValue{ .nil = {} };
            }

            const len: usize = @intCast(length);

            // 读取指定长度的数据
            const data = try self.readExact(len);
            errdefer self.allocator.free(data);

            // 跳过结尾的 CRLF
            try self.skipCRLF();

            return RedisValue{ .string = data };
        }

        /// 解析数组
        ///
        /// 格式: `*<count>\r\n<element1><element2>...`
        /// 特殊情况: `*-1\r\n` 表示 nil 数组
        fn parseArray(self: *Self, count_str: []const u8) !RedisValue {
            const count = std.fmt.parseInt(i64, count_str, 10) catch {
                return RedisError.ProtocolError;
            };

            // *-1 表示 nil 数组
            if (count < 0) {
                return RedisValue{ .nil = {} };
            }

            const len: usize = @intCast(count);

            // 分配数组空间
            var elements = try self.allocator.alloc(RedisValue, len);
            errdefer {
                // 错误时清理已分配的元素
                for (elements) |elem| {
                    freeRedisValue(self.allocator, elem);
                }
                self.allocator.free(elements);
            }

            // 递归解析每个元素
            for (0..len) |i| {
                elements[i] = try self.readReply();
            }

            return RedisValue{ .array = elements };
        }

        /// 发送命令
        ///
        /// 使用 RESP 数组格式发送命令：
        /// `*<argc>\r\n$<len1>\r\n<arg1>\r\n$<len2>\r\n<arg2>\r\n...`
        pub fn sendCommand(self: *Self, args: []const []const u8) !void {
            // 构建命令
            var cmd_buffer = std.ArrayListUnmanaged(u8){};
            defer cmd_buffer.deinit(self.allocator);

            // 写入数组长度
            var writer = cmd_buffer.writer(self.allocator);
            try writer.print("*{d}\r\n", .{args.len});

            // 写入每个参数
            for (args) |arg| {
                try writer.print("${d}\r\n", .{arg.len});
                try cmd_buffer.appendSlice(self.allocator, arg);
                try cmd_buffer.appendSlice(self.allocator, CRLF);
            }

            // 发送到服务器
            _ = self.stream.write(cmd_buffer.items) catch {
                return RedisError.WriteFailed;
            };
        }
    };
}

/// 释放 RedisValue 占用的内存
///
/// ## 递归释放
///
/// 由于 RedisValue 可以包含嵌套数组，需要递归释放所有内存
/// 这相当于 Go 中的 GC 工作，但在 Zig 中需要手动处理
///
/// ## 使用示例
/// ```zig
/// const value = try protocol.readReply();
/// defer freeRedisValue(allocator, value);
/// // 使用 value...
/// ```
pub fn freeRedisValue(allocator: std.mem.Allocator, value: RedisValue) void {
    switch (value) {
        .string => |s| allocator.free(s),
        .err => |e| allocator.free(e),
        .array => |arr| {
            for (arr) |elem| {
                freeRedisValue(allocator, elem);
            }
            allocator.free(arr);
        },
        .nil, .integer => {},
    }
}

/// 用于测试的模拟流
const MockStream = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn read(self: *MockStream, buffer: []u8) !usize {
        if (self.pos >= self.data.len) {
            return 0;
        }
        const remaining = self.data[self.pos..];
        const to_read = @min(remaining.len, buffer.len);
        @memcpy(buffer[0..to_read], remaining[0..to_read]);
        self.pos += to_read;
        return to_read;
    }

    pub fn write(_: *MockStream, _: []const u8) !usize {
        return 0;
    }
};

// 测试
test "parse simple string" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = "+OK\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    try std.testing.expectEqualStrings("OK", value.asString().?);
}

test "parse integer" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = ":1000\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    try std.testing.expectEqual(@as(i64, 1000), value.asInt().?);
}

test "parse bulk string" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = "$6\r\nfoobar\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    try std.testing.expectEqualStrings("foobar", value.asString().?);
}

test "parse nil bulk string" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = "$-1\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    try std.testing.expect(value.isNil());
}

test "parse array" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = "*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    const arr = value.asArray().?;
    try std.testing.expectEqual(@as(usize, 2), arr.len);
    try std.testing.expectEqualStrings("foo", arr[0].asString().?);
    try std.testing.expectEqualStrings("bar", arr[1].asString().?);
}

test "parse error" {
    const allocator = std.testing.allocator;
    var stream = MockStream{ .data = "-ERR unknown command\r\n" };
    var protocol = Protocol(*MockStream).init(&stream, allocator);

    const value = try protocol.readReply();
    defer freeRedisValue(allocator, value);

    try std.testing.expect(value.isError());
    try std.testing.expectEqualStrings("ERR unknown command", value.err);
}
