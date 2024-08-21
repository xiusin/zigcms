const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn split(allocator: Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    var parts = std.ArrayList([]const u8).init(allocator);
    var iter = std.mem.split(u8, str, delimiter);
    while (iter.next()) |part| {
        try parts.append(part);
    }
    return try parts.toOwnedSlice();
}

pub inline fn to_number(str: []const u8) !usize {
    return try std.fmt.parseInt(usize, str, 10);
}

pub fn to_bool(str: ?[]const u8) bool {
    if (str == null) return false;
    if (str.len == 0 or eql(str, "false") or eql(str, "0") or eql(str, " ")) {
        return false;
    }
    return true;
}

pub inline fn eql(str1: []const u8, str2: []const u8) bool {
    return std.mem.eql(u8, str1, str2);
}

pub inline fn join(allocator: Allocator, separator: []const u8, parts: []const []const u8) ![]const u8 {
    return try std.mem.join(allocator, separator, parts);
}

/// 字符串替换
pub inline fn str_replace(allocator: Allocator, search: []const u8, replace: []const u8, subject: []const u8) []const u8 {
    return std.mem.replaceOwned(u8, allocator, subject, search, replace) catch unreachable;
}

pub fn ucwords() void {}

/// 首字母大写
pub fn ucfrist(str: []const u8) []const u8 {
    if (str.len > 0) {
        str[0] = std.ascii.toUpper(str[0]);
    }
    return str;
}

/// 首字母小写
pub fn lcfrist(str: []u8) []const u8 {
    if (str.len > 0) {
        str[0] = std.ascii.toLower(str[0]);
    }
    return str;
}

pub inline fn repeat(substr: []const u8, count: usize) []const u8 {
    return substr ** count;
}

pub fn md5(allocator: Allocator, str: []const u8) ![]const u8 {
    const Md5 = std.crypto.hash.Md5;
    var out: [Md5.digest_length]u8 = undefined;
    Md5.hash(str, &out, .{});
    var buffer: [Md5.digest_length * 2]u8 = undefined;
    var index: usize = 0;
    for (out) |byte| {
        var box: [2]u8 = undefined;
        const hex_byte = try std.fmt.bufPrint(box[0..], "{x}", .{byte});
        if (hex_byte.len == 1) {
            buffer[index] = 0;
            buffer[index + 1] = hex_byte[0];
        } else {
            buffer[index] = hex_byte[0];
            buffer[index + 1] = hex_byte[1];
        }
        index += 2;
    }

    return try allocator.dupe(u8, buffer[0..]);
}

/// 去除字符串首尾指定字符串
pub inline fn trim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trim(u8, str, chars); // inline 函数的不会被返回优化
}

/// 打乱字符串
pub fn shuffle(allocator: Allocator, str: []const u8) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();

    var arr = std.ArrayList([]u8).init(allocator);
    defer arr.deinit();

    var len: usize = 0;
    while (iter.nextCodepointSlice()) |chars| {
        try arr.append(@constCast(chars));
        len += 1;
    }

    var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    for (0..len) |value| {
        const seed = rng.random().uintLessThan(usize, len);
        if (value != seed) {
            const tmp = arr.items[value];
            arr.items[value] = arr.items[seed];
            arr.items[seed] = tmp;
        }
    }

    var result = try std.ArrayList(u8).initCapacity(allocator, str.len);
    defer result.deinit();

    for (arr.items) |value| {
        try result.appendSlice(value[0..]);
    }
    arr.clearAndFree();

    return result.toOwnedSlice();
}

/// 去除左边字符
pub inline fn ltrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimLeft(u8, str, chars);
}

/// 去除右边字符
pub inline fn rtrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimRight(u8, str, chars);
}

/// 全小写转换
pub inline fn strtolower(str: []const u8) []const u8 {
    var output = [_]u8{0} ** str.len;
    return std.ascii.lowerString(output[0..], str);
}

/// 全大写转换
pub inline fn strtoupper(str: []const u8) []const u8 {
    var output = [_]u8{0} ** str.len;
    return std.ascii.upperString(output[0..], str);
}

/// 判断是否包含某个子串
pub inline fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack[0..], needle[0..]) != null;
}

/// 判断是否以某个字符串开始
pub inline fn starts_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

/// 判断是否以某个字符串结束
pub fn ends_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.endsWith(u8, haystack, needle);
}

/// 判断是否包含某个字符串
pub fn includes(haystacks: [][]const u8, needle: []const u8) bool {
    for (haystacks) |haystack| {
        if (std.mem.eql(u8, haystack, needle)) {
            return true;
        }
    }
    return false;
}

/// strpos 判断字符串位置
pub inline fn strpos(haystack: []const u8, needle: []const u8) usize {
    return std.mem.indexOfAny(u8, haystack, needle) orelse return -1;
}

/// strrev 翻转字符串
pub inline fn strrev(str: []const u8) ![]const u8 {
    return std.mem.reverse(u8, str);
}

/// strlen 字节长度
pub inline fn strlen(str: []const u8) usize {
    return str.len;
}

/// mb_strlen 多字节字符串长度
pub inline fn mb_strlen(str: []const u8) !usize {
    return try std.unicode.utf8CountCodepoints(str);
}

/// substr_count 判断子串个数
pub inline fn substr_count(str: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, str, needle);
}

/// sprinf 返回格式化字符串
pub inline fn sprinf(format: []const u8, args: anytype) ![]const u8 {
    var buf: [409600]u8 = undefined;
    return try std.fmt.bufPrint(buf[0..], format, args);
}

// pub inline fn substr(str: []const u8, start: usize, end: usize) ![]const u8 {
//     const view = try std.unicode.Utf8View.init(str);
//     var iter = view.iterator();

//     var i: usize = 0;
//     while (iter.nextCodepointSlice()) |char| {}
// }
