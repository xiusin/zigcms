//! 全局 Io 实例
//!
//! Zig 0.17 的 `std.Io` 接口需要显式传递 Io 实例。
//! 本模块提供进程级唯一的 Io 实例（Threaded 后端），供文件系统与 HTTP 客户端使用。
//!
//! ## 使用示例
//! ```zig
//! const core_io = @import("../../core/io.zig");
//! const io = core_io.getIo();
//! try std.Io.Dir.createDirPath(std.Io.Dir.cwd(), io, "uploads/a/b");
//! ```

const std = @import("std");

var g_threaded: ?std.Io.Threaded = null;
var g_io: ?std.Io = null;
var g_initialized = std.atomic.Value(bool).init(false);

/// 获取全局 Io 实例（线程安全，延迟初始化）
///
/// 初始化是一次性的：写入方通过原子交换保证只有第一个线程执行初始化，
/// 其余线程自旋等待，初始化完成后所有读取都是无锁的。
pub fn getIo() std.Io {
    if (g_io) |io| return io;
    if (g_initialized.cmpxchgStrong(false, true, .acquire, .monotonic) == null) {
        const threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
        g_threaded = threaded;
        g_io = g_threaded.?.io();
    }
    while (g_io == null) std.Thread.yield() catch {};
    return g_io.?;
}
