const std = @import("std");

pub const ResourceError = error{
    MemoryLimitExceeded,
    FileHandleLimitExceeded,
    ThreadLimitExceeded,
};

pub const ResourceTracker = struct {
    memory_used: std.atomic.Value(usize),
    max_memory: usize,
    file_handles: std.atomic.Value(u32),
    max_file_handles: u32,
    threads: std.atomic.Value(u32),
    max_threads: u32,
    mutex: std.Thread.Mutex,

    pub fn init(max_memory_mb: u32, max_file_handles: u32, max_threads: u32) ResourceTracker {
        return .{
            .memory_used = std.atomic.Value(usize).init(0),
            .max_memory = @as(usize, max_memory_mb) * 1024 * 1024,
            .file_handles = std.atomic.Value(u32).init(0),
            .max_file_handles = max_file_handles,
            .threads = std.atomic.Value(u32).init(0),
            .max_threads = max_threads,
            .mutex = .{},
        };
    }

    pub fn allocate(self: *ResourceTracker, size: usize) !void {
        const current = self.memory_used.fetchAdd(size, .monotonic);
        if (current + size > self.max_memory) {
            _ = self.memory_used.fetchSub(size, .monotonic);
            std.log.err("Memory limit exceeded: trying to allocate {d} bytes, current: {d}, max: {d}", .{
                size,
                current,
                self.max_memory,
            });
            return ResourceError.MemoryLimitExceeded;
        }
    }

    pub fn deallocate(self: *ResourceTracker, size: usize) void {
        _ = self.memory_used.fetchSub(size, .monotonic);
    }

    pub fn openFileHandle(self: *ResourceTracker) !void {
        const current = self.file_handles.fetchAdd(1, .monotonic);
        if (current + 1 > self.max_file_handles) {
            _ = self.file_handles.fetchSub(1, .monotonic);
            return ResourceError.FileHandleLimitExceeded;
        }
    }

    pub fn closeFileHandle(self: *ResourceTracker) void {
        _ = self.file_handles.fetchSub(1, .monotonic);
    }

    pub fn startThread(self: *ResourceTracker) !void {
        const current = self.threads.fetchAdd(1, .monotonic);
        if (current + 1 > self.max_threads) {
            _ = self.threads.fetchSub(1, .monotonic);
            return ResourceError.ThreadLimitExceeded;
        }
    }

    pub fn stopThread(self: *ResourceTracker) void {
        _ = self.threads.fetchSub(1, .monotonic);
    }

    pub fn getMemoryUsage(self: *const ResourceTracker) usize {
        return self.memory_used.load(.monotonic);
    }

    pub fn getFileHandleCount(self: *const ResourceTracker) u32 {
        return self.file_handles.load(.monotonic);
    }

    pub fn getThreadCount(self: *const ResourceTracker) u32 {
        return self.threads.load(.monotonic);
    }

    pub fn getStats(self: *const ResourceTracker) ResourceStats {
        return .{
            .memory_used = self.getMemoryUsage(),
            .memory_max = self.max_memory,
            .file_handles = self.getFileHandleCount(),
            .file_handles_max = self.max_file_handles,
            .threads = self.getThreadCount(),
            .threads_max = self.max_threads,
        };
    }

    pub fn reset(self: *ResourceTracker) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.memory_used.store(0, .monotonic);
        self.file_handles.store(0, .monotonic);
        self.threads.store(0, .monotonic);
    }
};

pub const ResourceStats = struct {
    memory_used: usize,
    memory_max: usize,
    file_handles: u32,
    file_handles_max: u32,
    threads: u32,
    threads_max: u32,

    pub fn memoryUsagePercent(self: ResourceStats) f32 {
        if (self.memory_max == 0) return 0.0;
        return @as(f32, @floatFromInt(self.memory_used)) / @as(f32, @floatFromInt(self.memory_max)) * 100.0;
    }

    pub fn fileHandleUsagePercent(self: ResourceStats) f32 {
        if (self.file_handles_max == 0) return 0.0;
        return @as(f32, @floatFromInt(self.file_handles)) / @as(f32, @floatFromInt(self.file_handles_max)) * 100.0;
    }

    pub fn threadUsagePercent(self: ResourceStats) f32 {
        if (self.threads_max == 0) return 0.0;
        return @as(f32, @floatFromInt(self.threads)) / @as(f32, @floatFromInt(self.threads_max)) * 100.0;
    }
};

pub const TrackedAllocator = struct {
    parent_allocator: std.mem.Allocator,
    tracker: *ResourceTracker,

    pub fn init(parent: std.mem.Allocator, tracker: *ResourceTracker) TrackedAllocator {
        return .{
            .parent_allocator = parent,
            .tracker = tracker,
        };
    }

    pub fn allocator(self: *TrackedAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = std.mem.Allocator.noRemap,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));

        self.tracker.allocate(len) catch return null;

        const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result == null) {
            self.tracker.deallocate(len);
        }
        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));

        if (new_len > buf.len) {
            const delta = new_len - buf.len;
            self.tracker.allocate(delta) catch return false;
        }

        const result = self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);

        if (!result and new_len > buf.len) {
            const delta = new_len - buf.len;
            self.tracker.deallocate(delta);
        } else if (result and new_len < buf.len) {
            const delta = buf.len - new_len;
            self.tracker.deallocate(delta);
        }

        return result;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));

        self.tracker.deallocate(buf.len);
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }
};

test "ResourceTracker basic operations" {
    var tracker = ResourceTracker.init(10, 5, 2);

    try tracker.allocate(1024 * 1024);
    try std.testing.expectEqual(@as(usize, 1024 * 1024), tracker.getMemoryUsage());

    tracker.deallocate(512 * 1024);
    try std.testing.expectEqual(@as(usize, 512 * 1024), tracker.getMemoryUsage());

    try tracker.openFileHandle();
    try std.testing.expectEqual(@as(u32, 1), tracker.getFileHandleCount());

    tracker.closeFileHandle();
    try std.testing.expectEqual(@as(u32, 0), tracker.getFileHandleCount());
}

test "ResourceTracker limits" {
    var tracker = ResourceTracker.init(1, 1, 1);

    try tracker.allocate(512 * 1024);

    try std.testing.expectError(ResourceError.MemoryLimitExceeded, tracker.allocate(1024 * 1024));

    try tracker.openFileHandle();
    try std.testing.expectError(ResourceError.FileHandleLimitExceeded, tracker.openFileHandle());

    try tracker.startThread();
    try std.testing.expectError(ResourceError.ThreadLimitExceeded, tracker.startThread());
}

test "TrackedAllocator" {
    var tracker = ResourceTracker.init(10, 10, 10);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var tracked = TrackedAllocator.init(gpa.allocator(), &tracker);
    const allocator = tracked.allocator();

    const memory = try allocator.alloc(u8, 1024);
    defer allocator.free(memory);

    try std.testing.expectEqual(@as(usize, 1024), tracker.getMemoryUsage());
}
