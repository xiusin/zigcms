const std = @import("std");
const logger = std.log.scoped(.main);
const webui = @import("./modules/webui.zig");
const regex = @import("./modules//regex.zig");

var called: u64 = 1;

pub fn main() !void {
    // webui.start();
    try regex.start();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var h = std.StringHashMap([]const u8).init(allocator);
    defer h.deinit();

    try h.put("name", "xiusin");
    try h.put("address", "河南省郑州市");
    logger.debug("hashmap capacity: {any}", .{h.capacity()});
    h.putAssumeCapacity("reason", "假设容量足够的情况下put数据, 当容量不满足的时候会panic, 自行决定是否需要此方法");
    h.clearAndFree(); // 清理并释放内存，不会销毁对象
    if (h.contains("name")) { // 此时不存在name
        logger.debug("{s}", .{h.get("name").?});
    }

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    logger.debug("随机seed数字: {d}", .{seed});
    _ = @as(u64, @intCast(std.time.microTimestamp())); // 时间戳也行

    // 初始化随机种子
    var prng = std.Random.DefaultPrng.init(seed);
    const randNumber = prng.random().intRangeAtMost(u16, 1, 100);
    logger.debug("随机数字为: {d}", .{randNumber});

    // 利用加密库生成随机数
    const randomFloat = std.crypto.random.float(f32);
    logger.debug("std.crypto.random.float = {d}", .{randomFloat});

    var buf: [100]u8 = undefined; // 初始化buf缓存容器
    const fmtNumber = try std.fmt.bufPrint(buf[0..], "{d}", .{randNumber});

    try h.put("name", try std.mem.concat(allocator, u8, &[_][]const u8{ "xiusin", " rand number -> ", fmtNumber }));

    if (!h.contains("name")) {
        logger.err("map不存在key为name", .{});
    }

    var iter = h.keyIterator(); // 获取迭代器

    var keys = std.ArrayList([]const u8).init(allocator);
    var values = std.ArrayList([]const u8).init(allocator);
    while (iter.next()) |key| {
        try keys.append(key.*);
        try values.append(h.get(key.*).?);
        logger.debug("key = {s}, value = {s}", .{ key.*, h.get(key.*).? });
    }

    // 追加多个数据 []const []const u8 ?
    keys.appendSlice(&[_][]const u8{"hello"}) catch unreachable;
    values.appendSlice(&[_][]const u8{"world"}) catch unreachable;

    for (keys.items, 0..) |key, i| {
        logger.debug("keys[{d}] = {s}, values[{d}] = {s}", .{ i, key, i, values.items[i] });
    }

    // 单次调用， 初始化单例
    var once_fn = std.once(once_call);
    once_fn.call();
    once_fn.call();

    // 异步功能目前不支持
    // const result = async async_fn();
    // _ = result; // autofix
    // logger.debug("async result = {d}", .{await result});

}

fn async_fn() u64 {
    return 18;
}

fn once_call() void {
    called += 1;
    logger.debug("once called times = {d}", .{called});
}

