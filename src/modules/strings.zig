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

/// str_replace 字符串替换
pub fn str_replace(search: []const u8, replace: []const u8, subject: []const u8) []const u8 {
    var output: [40960000]u8 = undefined;
    const len = std.mem.replace(u8, subject, search, replace, output[0..]);
    return output[0..len];
}

pub fn ucwords() void {}

pub fn ucfrist() void {}

pub fn lcfrist() void {}

pub inline fn repeat(substr: []const u8, count: usize) []const u8 {
    return substr ** count;
}

pub fn md5(str: []const u8) []const u8 {
    const Md5 = std.crypto.hash.Md5;
    var out: [Md5.digest_length]u8 = undefined;
    var h = Md5.init(.{});
    h.update(str);
    h.final(out[0..]);
    return out[0..];
}

pub inline fn trim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trim(u8, str, chars);
}

pub fn shuffle(allocator: Allocator, str: []const u8) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();

    var arr = std.ArrayList([]u8).init(allocator);
    defer arr.deinit();

    while (iter.nextCodepointSlice()) |chars| {
        try arr.append(chars);
    }

    // 随机打乱
    // var rand = std.rand.DefaultPrng.init(std.time.milliTimestamp());
    // std.rand.shuffle(r: Random, comptime T: type, buf: []T)

    return arr.toOwnedSlice();
}

pub inline fn ltrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimLeft(u8, str, chars);
}

pub inline fn rtrim(str: []const u8, chars: []const u8) []const u8 {
    return std.mem.trimRight(u8, str, chars);
}

/// strtolower 全小写转换
pub inline fn strtolower(str: []const u8) ![]const u8 {
    var output: [40960000]u8 = undefined;
    return try std.ascii.lowerString(output[0..], str);
}

pub inline fn strtoupper(str: []const u8) ![]const u8 {
    const output: [40960000]u8 = undefined;
    return try std.ascii.upperString(output[0..], str);
}

pub inline fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack[0..], needle[0..]) != null;
}

pub inline fn starts_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

pub fn ends_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.endsWith(u8, haystack, needle);
}

/// includes 判断是否包含某个字符串
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
