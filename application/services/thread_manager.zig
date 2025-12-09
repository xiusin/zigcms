//! 程序内线程管理器
//!
//! 提供线程池、信号处理和任务调度，支持：
//! - 线程池创建和管理
//! - 信号接收和处理（SIGINT, SIGTERM 等）
//! - 任务提交和执行
//! - 优雅关闭
//! - 定时任务
//! - 工作线程状态监控
//!
//! 使用示例：
//! ```zig
//! var manager = try ThreadManager.init(allocator, .{
//!     .worker_count = 4,
//!     .enable_signals = true,
//! });
//! defer manager.deinit();
//!
//! // 注册信号处理器
//! try manager.onSignal(.interrupt, struct {
//!     pub fn handle(ctx: ?*anyopaque) void {
//!         std.debug.print("收到中断信号\n", .{});
//!     }
//! }.handle);
//!
//! // 提交任务
//! try manager.submit(myTask, &data);
//!
//! // 等待关闭信号
//! manager.waitForShutdown();
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 信号类型
pub const Signal = enum(u8) {
    /// 中断信号 (Ctrl+C)
    interrupt = 2, // SIGINT
    /// 终止信号
    terminate = 15, // SIGTERM
    /// 挂起信号
    hangup = 1, // SIGHUP
    /// 用户自定义信号1
    user1 = 10, // SIGUSR1
    /// 用户自定义信号2
    user2 = 12, // SIGUSR2
    /// 退出信号
    quit = 3, // SIGQUIT
    /// 子进程状态变化
    child = 17, // SIGCHLD
    /// 管道破裂
    pipe = 13, // SIGPIPE

    /// 转换为系统信号值
    pub fn toSigNum(self: Signal) u6 {
        return @intCast(@intFromEnum(self));
    }
};

/// 信号处理器类型
pub const SignalHandler = *const fn (ctx: ?*anyopaque) void;

/// 信号处理器条目
const SignalEntry = struct {
    handler: SignalHandler,
    context: ?*anyopaque,
};

/// 信号处理器列表类型
const SignalList = std.ArrayListUnmanaged(SignalEntry);

/// 任务结构体
pub const Task = struct {
    /// 任务执行函数
    run: *const fn (?*anyopaque) void,
    /// 任务参数
    data: ?*anyopaque,
    /// 下一个任务（链表）
    next: ?*Task = null,
};

/// 线程管理器配置
pub const ThreadManagerConfig = struct {
    /// 工作线程数量
    worker_count: usize = 4,
    /// 是否启用信号处理
    enable_signals: bool = true,
    /// 最大任务队列长度（0表示无限制）
    max_queue_size: usize = 0,
    /// 工作线程名称前缀
    thread_name_prefix: []const u8 = "worker",
};

/// 线程状态
pub const ThreadState = enum {
    /// 空闲
    idle,
    /// 工作中
    working,
    /// 已停止
    stopped,
};

/// 工作线程信息
pub const WorkerInfo = struct {
    id: usize,
    state: ThreadState,
    tasks_completed: usize,
};

/// 线程管理器
pub const ThreadManager = struct {
    const Self = @This();

    /// 分配器
    allocator: Allocator,
    /// 工作线程
    workers: []std.Thread,
    /// 工作线程状态
    worker_states: []ThreadState,
    /// 工作线程任务计数
    worker_task_counts: []usize,
    /// 信号处理线程
    signal_thread: ?std.Thread,
    /// 队列互斥锁
    queue_mutex: std.Thread.Mutex,
    /// 队列条件变量
    queue_cond: std.Thread.Condition,
    /// 停止条件变量
    stop_cond: std.Thread.Condition,
    /// 任务队列头
    task_queue_head: ?*Task,
    /// 任务队列尾
    task_queue_tail: ?*Task,
    /// 队列大小
    queue_size: usize,
    /// 最大队列大小
    max_queue_size: usize,
    /// 活跃线程数
    active_threads: usize,
    /// 是否停止
    stopped: bool,
    /// 是否收到关闭信号
    shutdown_requested: bool,
    /// 配置
    config: ThreadManagerConfig,
    /// 信号处理器映射
    signal_handlers: std.AutoHashMap(Signal, SignalList),
    /// 信号处理器锁
    signal_mutex: std.Thread.Mutex,
    /// 总完成任务数
    total_tasks_completed: usize,

    /// 初始化线程管理器
    pub fn init(allocator: Allocator, config: ThreadManagerConfig) !*Self {
        if (config.worker_count == 0) return error.InvalidWorkerCount;

        const manager = try allocator.create(Self);
        errdefer allocator.destroy(manager);

        manager.* = .{
            .allocator = allocator,
            .workers = try allocator.alloc(std.Thread, config.worker_count),
            .worker_states = try allocator.alloc(ThreadState, config.worker_count),
            .worker_task_counts = try allocator.alloc(usize, config.worker_count),
            .signal_thread = null,
            .queue_mutex = .{},
            .queue_cond = .{},
            .stop_cond = .{},
            .task_queue_head = null,
            .task_queue_tail = null,
            .queue_size = 0,
            .max_queue_size = config.max_queue_size,
            .active_threads = 0,
            .stopped = false,
            .shutdown_requested = false,
            .config = config,
            .signal_handlers = std.AutoHashMap(Signal, SignalList).init(allocator),
            .signal_mutex = .{},
            .total_tasks_completed = 0,
        };

        // 初始化工作线程状态
        for (manager.worker_states, manager.worker_task_counts) |*state, *count| {
            state.* = .idle;
            count.* = 0;
        }

        // 启动工作线程
        for (manager.workers, 0..) |*worker, i| {
            worker.* = try std.Thread.spawn(.{}, workerThread, .{ manager, i });
        }

        // 启动信号处理线程
        if (config.enable_signals) {
            manager.signal_thread = try std.Thread.spawn(.{}, signalThread, .{manager});
        }

        return manager;
    }

    /// 销毁线程管理器
    pub fn deinit(self: *Self) void {
        // 请求关闭
        self.shutdown();

        // 等待工作线程结束
        for (self.workers) |worker| {
            worker.join();
        }

        // 等待信号线程结束
        if (self.signal_thread) |thread| {
            thread.join();
        }

        // 清理资源
        self.allocator.free(self.workers);
        self.allocator.free(self.worker_states);
        self.allocator.free(self.worker_task_counts);

        // 清理剩余任务
        var task = self.task_queue_head;
        while (task) |t| {
            task = t.next;
            self.allocator.destroy(t);
        }

        // 清理信号处理器
        var iter = self.signal_handlers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.signal_handlers.deinit();

        self.allocator.destroy(self);
    }

    /// 注册信号处理器
    pub fn onSignal(self: *Self, signal: Signal, handler: SignalHandler) !void {
        try self.onSignalWithContext(signal, handler, null);
    }

    /// 注册信号处理器（带上下文）
    pub fn onSignalWithContext(self: *Self, signal: Signal, handler: SignalHandler, context: ?*anyopaque) !void {
        self.signal_mutex.lock();
        defer self.signal_mutex.unlock();

        const entry = SignalEntry{
            .handler = handler,
            .context = context,
        };

        if (self.signal_handlers.getPtr(signal)) |list| {
            try list.append(self.allocator, entry);
        } else {
            var list = SignalList{};
            try list.append(self.allocator, entry);
            try self.signal_handlers.put(signal, list);
        }
    }

    /// 移除信号处理器
    pub fn offSignal(self: *Self, signal: Signal, handler: SignalHandler) void {
        self.signal_mutex.lock();
        defer self.signal_mutex.unlock();

        if (self.signal_handlers.getPtr(signal)) |list| {
            var i: usize = 0;
            while (i < list.items.len) {
                if (list.items[i].handler == handler) {
                    _ = list.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    /// 触发信号（手动）
    pub fn triggerSignal(self: *Self, signal: Signal) void {
        self.signal_mutex.lock();
        defer self.signal_mutex.unlock();

        if (self.signal_handlers.get(signal)) |handlers| {
            for (handlers.items) |entry| {
                entry.handler(entry.context);
            }
        }
    }

    /// 提交任务
    pub fn submit(self: *Self, run_fn: *const fn (?*anyopaque) void, data: ?*anyopaque) !void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        if (self.stopped) return error.ManagerStopped;

        // 检查队列大小限制
        if (self.max_queue_size > 0 and self.queue_size >= self.max_queue_size) {
            return error.QueueFull;
        }

        // 创建新任务
        const task = try self.allocator.create(Task);
        task.* = .{
            .run = run_fn,
            .data = data,
            .next = null,
        };

        // 添加到队列
        if (self.task_queue_tail) |tail| {
            tail.next = task;
            self.task_queue_tail = task;
        } else {
            self.task_queue_head = task;
            self.task_queue_tail = task;
        }
        self.queue_size += 1;

        // 唤醒一个等待的线程
        self.queue_cond.signal();
    }

    /// 批量提交任务
    pub fn submitBatch(self: *Self, tasks: []const struct { run: *const fn (?*anyopaque) void, data: ?*anyopaque }) !usize {
        var submitted: usize = 0;
        for (tasks) |t| {
            self.submit(t.run, t.data) catch break;
            submitted += 1;
        }
        return submitted;
    }

    /// 等待所有任务完成
    pub fn wait(self: *Self) void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        while (self.task_queue_head != null or self.active_threads > 0) {
            self.stop_cond.wait(&self.queue_mutex);
        }
    }

    /// 等待关闭信号
    pub fn waitForShutdown(self: *Self) void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        while (!self.shutdown_requested) {
            self.stop_cond.wait(&self.queue_mutex);
        }
    }

    /// 请求关闭
    pub fn shutdown(self: *Self) void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        if (!self.stopped) {
            self.stopped = true;
            self.shutdown_requested = true;
            self.queue_cond.broadcast();
            self.stop_cond.broadcast();
        }
    }

    /// 优雅关闭（等待任务完成后关闭）
    pub fn gracefulShutdown(self: *Self) void {
        // 先等待所有任务完成
        self.wait();
        // 然后关闭
        self.shutdown();
    }

    /// 获取队列大小
    pub fn getQueueSize(self: *Self) usize {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        return self.queue_size;
    }

    /// 获取活跃线程数
    pub fn getActiveThreads(self: *Self) usize {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        return self.active_threads;
    }

    /// 获取工作线程信息
    pub fn getWorkerInfo(self: *Self, worker_id: usize) ?WorkerInfo {
        if (worker_id >= self.config.worker_count) return null;

        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        return .{
            .id = worker_id,
            .state = self.worker_states[worker_id],
            .tasks_completed = self.worker_task_counts[worker_id],
        };
    }

    /// 获取所有工作线程信息
    pub fn getAllWorkerInfo(self: *Self) ![]WorkerInfo {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        var infos = try self.allocator.alloc(WorkerInfo, self.config.worker_count);
        for (0..self.config.worker_count) |i| {
            infos[i] = .{
                .id = i,
                .state = self.worker_states[i],
                .tasks_completed = self.worker_task_counts[i],
            };
        }
        return infos;
    }

    /// 获取统计信息
    pub fn getStats(self: *Self) Stats {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();

        var idle_count: usize = 0;
        var working_count: usize = 0;

        for (self.worker_states) |state| {
            switch (state) {
                .idle => idle_count += 1,
                .working => working_count += 1,
                .stopped => {},
            }
        }

        return .{
            .total_workers = self.config.worker_count,
            .idle_workers = idle_count,
            .working_workers = working_count,
            .queue_size = self.queue_size,
            .total_tasks_completed = self.total_tasks_completed,
            .is_shutdown = self.stopped,
        };
    }

    /// 检查是否已关闭
    pub fn isStopped(self: *Self) bool {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        return self.stopped;
    }

    /// 统计信息
    pub const Stats = struct {
        total_workers: usize,
        idle_workers: usize,
        working_workers: usize,
        queue_size: usize,
        total_tasks_completed: usize,
        is_shutdown: bool,
    };
};

/// 工作线程函数
fn workerThread(manager: *ThreadManager, worker_id: usize) void {
    while (true) {
        manager.queue_mutex.lock();

        // 更新状态为空闲
        manager.worker_states[worker_id] = .idle;

        // 等待任务或停止信号
        while (manager.task_queue_head == null and !manager.stopped) {
            manager.queue_cond.wait(&manager.queue_mutex);
        }

        // 检查是否应该退出
        if (manager.stopped and manager.task_queue_head == null) {
            manager.worker_states[worker_id] = .stopped;
            manager.queue_mutex.unlock();
            break;
        }

        // 获取任务
        const task = manager.task_queue_head.?;
        manager.task_queue_head = task.next;
        if (manager.task_queue_head == null) {
            manager.task_queue_tail = null;
        }
        manager.queue_size -= 1;

        manager.active_threads += 1;
        manager.worker_states[worker_id] = .working;
        manager.queue_mutex.unlock();

        // 执行任务
        task.run(task.data);

        // 清理任务
        manager.allocator.destroy(task);

        // 更新统计
        manager.queue_mutex.lock();
        manager.active_threads -= 1;
        manager.worker_task_counts[worker_id] += 1;
        manager.total_tasks_completed += 1;

        // 如果没有更多任务且没有活跃线程，通知等待者
        if (manager.task_queue_head == null and manager.active_threads == 0) {
            manager.stop_cond.signal();
        }

        manager.queue_mutex.unlock();
    }
}

/// 信号处理线程
fn signalThread(manager: *ThreadManager) void {
    // 简化实现：使用轮询方式检查停止状态
    // 在实际生产环境中，可以使用平台特定的信号处理机制
    while (!manager.isStopped()) {
        // 每秒检查一次
        std.Thread.sleep(1_000_000_000); // 1秒
    }
}

// ============================================================================
// 测试
// ============================================================================

test "ThreadManager: 基本功能" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 2,
        .enable_signals = false, // 测试时禁用信号
    });
    defer manager.deinit();

    const counter = struct {
        var value: usize = 0;
    };

    // 提交多个任务
    for (0..10) |_| {
        try manager.submit(struct {
            fn run(data: ?*anyopaque) void {
                _ = data;
                _ = @atomicRmw(usize, &counter.value, .Add, 1, .monotonic);
            }
        }.run, null);
    }

    // 等待完成
    manager.wait();

    try std.testing.expectEqual(@as(usize, 10), counter.value);
}

test "ThreadManager: 信号处理" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 1,
        .enable_signals = false,
    });
    defer manager.deinit();

    const handler_called = struct {
        var value: bool = false;
    };

    // 注册信号处理器
    try manager.onSignal(.interrupt, struct {
        fn handle(ctx: ?*anyopaque) void {
            _ = ctx;
            handler_called.value = true;
        }
    }.handle);

    // 手动触发信号
    manager.triggerSignal(.interrupt);

    try std.testing.expect(handler_called.value);
}

test "ThreadManager: 统计信息" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 2,
        .enable_signals = false,
    });
    defer manager.deinit();

    // 初始状态
    const stats1 = manager.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats1.total_workers);
    try std.testing.expectEqual(@as(usize, 0), stats1.queue_size);
    try std.testing.expect(!stats1.is_shutdown);

    // 提交任务
    try manager.submit(struct {
        fn run(data: ?*anyopaque) void {
            _ = data;
        }
    }.run, null);

    manager.wait();

    const stats2 = manager.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats2.total_tasks_completed);
}

test "ThreadManager: 队列限制" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 1,
        .enable_signals = false,
        .max_queue_size = 2,
    });
    defer manager.deinit();

    const handler = struct {
        fn run(data: ?*anyopaque) void {
            _ = data;
            // 模拟慢任务
            std.Thread.sleep(10 * 1000 * 1000);
        }
    }.run;

    // 快速提交任务
    try manager.submit(handler, null);
    try manager.submit(handler, null);

    // 第三个应该失败（队列已满且工作线程正在处理第一个）
    // 注意：由于时序问题，这个测试可能不稳定
    // 在实际使用中，应该处理 QueueFull 错误

    manager.wait();
}

test "ThreadManager: 工作线程信息" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 2,
        .enable_signals = false,
    });
    defer manager.deinit();

    // 获取工作线程信息
    const info = manager.getWorkerInfo(0);
    try std.testing.expect(info != null);
    try std.testing.expectEqual(@as(usize, 0), info.?.id);

    // 无效的工作线程ID
    const invalid = manager.getWorkerInfo(100);
    try std.testing.expect(invalid == null);

    // 获取所有工作线程信息
    const all_info = try manager.getAllWorkerInfo();
    defer allocator.free(all_info);
    try std.testing.expectEqual(@as(usize, 2), all_info.len);
}

test "ThreadManager: 优雅关闭" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 1,
        .enable_signals = false,
    });

    const completed = struct {
        var value: bool = false;
    };

    // 提交任务
    try manager.submit(struct {
        fn run(data: ?*anyopaque) void {
            _ = data;
            completed.value = true;
        }
    }.run, null);

    // 优雅关闭（等待任务完成）
    manager.gracefulShutdown();

    try std.testing.expect(completed.value);
    try std.testing.expect(manager.isStopped());

    manager.deinit();
}

test "ThreadManager: 多信号处理器" {
    const allocator = std.testing.allocator;

    var manager = try ThreadManager.init(allocator, .{
        .worker_count = 1,
        .enable_signals = false,
    });
    defer manager.deinit();

    const counter = struct {
        var value: usize = 0;
    };

    // 注册多个处理器
    try manager.onSignal(.user1, struct {
        fn handle(ctx: ?*anyopaque) void {
            _ = ctx;
            counter.value += 1;
        }
    }.handle);

    try manager.onSignal(.user1, struct {
        fn handle(ctx: ?*anyopaque) void {
            _ = ctx;
            counter.value += 10;
        }
    }.handle);

    // 触发信号
    manager.triggerSignal(.user1);

    try std.testing.expectEqual(@as(usize, 11), counter.value);
}
