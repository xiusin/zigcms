const std = @import("std");
const regex = @import("regex");
const logger = std.log.scoped(.regex);
pub fn start() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var re = regex.Regex.compile(gpa.allocator(), "([0-9]+)") catch unreachable;
    defer re.deinit();

    var result = try re.captures("1231456");
    if (result != null) {
       defer result.?.deinit();
       logger.info("regex success: {s}",.{ result.?.sliceAt(0).? });
    }
}
