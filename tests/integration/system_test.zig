const std = @import("std");
const testing = std.testing;
const zigcms = @import("zigcms");

test "System Initialization" {
    const allocator = testing.allocator;

    // 初始化配置
    const config = zigcms.SystemConfig{};

    // 初始化系统
    try zigcms.initSystem(allocator, config);
    defer zigcms.deinitSystem();

    // 验证各层是否初始化成功
    // 这里主要验证是否没有 panic 或 error
}

test "Global Resources Management" {
    // 验证 shared 层资源
    // 由于 initSystem 已经初始化了 shared，这里我们主要测试访问

    // 我们不能再次调用 init，因为已经初始化过了
    // try zigcms.shared.init(testing.allocator);

    // 验证资源是否可用
    // 注意：这需要数据库连接成功，如果测试环境没有数据库可能会失败
    // var db = zigcms.shared.primitives.get_db();
    // testing.expect(db != null);
}
