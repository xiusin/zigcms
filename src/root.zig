const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

// zig jetbrans
// toolchain    /usr/local/Cellar/zig/0.13.0/bin
// std path     /usr/local/Cellar/zig/0.13.0/lib/zig/std
// zls path     /Users/xiusin/.bin/zls
