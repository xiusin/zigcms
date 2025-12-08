const std = @import("std");
const complete_test = @import("services/sql/complete_test.zig");

pub fn main() !void {
    try complete_test.main();
}
