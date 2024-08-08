const std = @import("std");
const testing = std.testing;

const Person = struct {
    id: i32,
    name: []const u8,
    age: i32,
};

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
