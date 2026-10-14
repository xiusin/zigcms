const std = @import("std");
const core_io = @import("../io.zig");
const regex = @import("regex");
const logger = std.log.scoped(.regex);
pub fn start() !void {
    const allocator = std.heap.page_allocator;
    var re = try regex.Regex.compile(allocator, "([0-9]+)");
    defer re.deinit();

    var result = try re.captures("1231456");
    if (result != null) {
        defer result.?.deinit();
        logger.info("regex success: {s}", .{result.?.sliceAt(0).?});
    }
}
