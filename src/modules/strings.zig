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

pub inline fn join(allocator: Allocator, separator: []const u8, parts: [][]const u8) ![]const u8 {
    return try std.mem.join(allocator, separator, parts);
}

pub inline fn strtolower(str: []const u8) ![]const u8 {
    const output: []u8 = undefined;
    return try std.ascii.lowerString(output, str);
}

pub inline fn strtoupper(str: []const u8) ![]const u8 {
    const output: []u8 = undefined;
    return try std.ascii.upperString(output, str);
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

pub fn includes(haystacks: [][]const u8, needle: []const u8) bool {
    for (haystacks) |haystack| {
        if (std.mem.eql(u8, haystack, needle)) {
            return true;
        }
    }
    return false;
}

pub inline fn strpos(haystack: []const u8, needle: []const u8) usize {
    return std.mem.indexOfAny(u8, haystack, needle) orelse return -1;
}

pub inline fn strrev(str: []const u8) ![]const u8 {
    return std.mem.reverse(u8, str);
}

pub inline fn strlen(str: []const u8) usize {
    return str.len;
}

pub inline fn mb_strlen(str: []const u8) !usize {
    return try std.unicode.utf8CountCodepoints(str);
}

pub inline fn substr_count(str: []const u8, needle: []const u8) usize {
    return std.mem.count(u8, str, needle);
}

pub inline fn substr(str: []const u8, start: usize, end: usize) ![]const u8 {
    const view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();

    var i: usize = 0;
    while (iter.nextCodepointSlice()) |char| {}
}
