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

pub fn join(allocator: Allocator, separator: []const u8, parts: [][]const u8) ![]const u8 {
    return try std.mem.join(allocator, separator, parts);
}

pub fn strToLower(str: []const u8) ![]const u8 {
    const output: []u8 = undefined;
    return try std.ascii.lowerString(output, str);
}

pub fn strtoupper(str: []const u8) ![]const u8 {
    const output: []u8 = undefined;
    return try std.ascii.upperString(output, str);
}

pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack[0..], needle[0..]) != null;
}

pub fn startsWith(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

pub fn endsWith(haystack: []const u8, needle: []const u8) bool {
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
