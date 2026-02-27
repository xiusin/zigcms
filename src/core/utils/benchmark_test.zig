const std = @import("std");
const benchmark = @import("benchmark.zig");

test "BenchmarkTimer basic" {
    var timer = benchmark.BenchmarkTimer.start(std.testing.allocator);

    var sum: usize = 0;
    for (0..1000) |i| {
        sum += i;
    }

    timer.lap();

    try std.testing.expect(timer.laps() == 1);
    try std.testing.expect(timer.avgNs() > 0);
    try std.testing.expect(sum == 499500);
}

test "BenchmarkRunner compare" {
    var runner = benchmark.BenchmarkRunner.init(std.testing.allocator);
    defer runner.deinit();

    try runner.compare(
        "simple_add",
        struct {
            fn run() anyerror!void {
                var sum: usize = 0;
                for (0..100) |i| sum += i;
                std.debug.assert(sum == 4950);
            }
        }.run,
        "formula",
        struct {
            fn run() anyerror!void {
                var sum: usize = 0;
                sum = 100 * 99 / 2;
                std.debug.assert(sum == 4950);
            }
        }.run,
        1000,
    );
}
