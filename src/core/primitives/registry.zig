//! 依赖注入容器
//!
//! 提供服务的统一管理和延迟初始化。
//!
//! ## 使用示例
//!
//! ```zig
//! const Services = struct {
//!     pub const Deps = struct {
//!         cache: Lazy(Cache(i64)),
//!         redis: Lazy(RedisClient),
//!     };
//!
//!     pub fn initCache(allocator: Allocator) Cache(i64) {
//!         return Cache(i64).init(allocator, .{});
//!     }
//!
//!     pub fn initRedis(allocator: Allocator) !RedisClient {
//!         return RedisClient.connect(allocator, "127.0.0.1", 6379);
//!     }
//! };
//!
//! var di = Registry(Services).init(allocator);
//! defer di.deinit();
//!
//! // 第一次访问时才初始化
//! const cache = try di.get("cache");
//! try cache.set("count", 100, null);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 延迟初始化包装器
///
/// 服务只在第一次访问时才会被创建。
pub fn Lazy(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = T;

        value: ?T = null,
        initialized: bool = false,
        mu: std.Thread.Mutex = .{},

        /// 获取或初始化服务
        pub fn getOrInit(self: *Self, initFn: anytype, args: anytype) !*T {
            // 快速路径：已初始化
            if (self.initialized) {
                return &self.value.?;
            }

            // 慢路径：需要初始化
            self.mu.lock();
            defer self.mu.unlock();

            // 双重检查
            if (self.initialized) {
                return &self.value.?;
            }

            // 调用初始化函数
            const result = @call(.auto, initFn, args);

            // 处理可能返回 error 的初始化函数
            if (@typeInfo(@TypeOf(result)) == .error_union) {
                self.value = try result;
            } else {
                self.value = result;
            }

            self.initialized = true;
            return &self.value.?;
        }

        /// 检查是否已初始化
        pub fn isInitialized(self: *Self) bool {
            return self.initialized;
        }

        /// 手动设置值（用于测试或特殊场景）
        pub fn setValue(self: *Self, value: T) void {
            self.mu.lock();
            defer self.mu.unlock();
            self.value = value;
            self.initialized = true;
        }

        /// 重置（用于测试）
        pub fn reset(self: *Self) void {
            self.mu.lock();
            defer self.mu.unlock();
            self.value = null;
            self.initialized = false;
        }

        /// 获取值（如果已初始化）
        pub fn getValue(self: *Self) ?*T {
            if (self.initialized) {
                return &self.value.?;
            }
            return null;
        }
    };
}

/// 服务注册表（依赖注入容器）
///
/// 支持延迟初始化和类型安全的服务访问。
pub fn Registry(comptime Services: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        deps: Deps,
        mu: std.Thread.Mutex = .{},

        // 从 Services 获取依赖定义
        const Deps = if (@hasDecl(Services, "Deps")) Services.Deps else struct {};

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .deps = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            // 清理已初始化的服务
            inline for (std.meta.fields(Deps)) |field| {
                const lazy = &@field(self.deps, field.name);
                if (lazy.initialized) {
                    if (@hasDecl(@TypeOf(lazy.value.?), "deinit")) {
                        lazy.value.?.deinit();
                    }
                }
            }
            std.log.debug("Registry deinit (lazy services cleaned)", .{});
        }

        /// 获取服务（延迟初始化）
        ///
        /// 如果服务未初始化，会调用 Services 中对应的 init{Name} 方法。
        pub fn get(self: *Self, comptime name: []const u8) !*LazyValueType(name) {
            const lazy = &@field(self.deps, name);
            const initFnName = comptime blk: {
                var buf: [64]u8 = undefined;
                buf[0] = 'i';
                buf[1] = 'n';
                buf[2] = 'i';
                buf[3] = 't';
                buf[4] = std.ascii.toUpper(name[0]);
                for (name[1..], 0..) |c, i| {
                    buf[5 + i] = c;
                }
                break :blk buf[0 .. 5 + name.len - 1];
            };

            if (@hasDecl(Services, initFnName)) {
                return lazy.getOrInit(@field(Services, initFnName), .{self.allocator});
            } else {
                @compileError("Services 缺少初始化方法: " ++ initFnName);
            }
        }

        /// 检查服务是否已初始化
        pub fn isInitialized(self: *Self, comptime name: []const u8) bool {
            return @field(self.deps, name).isInitialized();
        }

        /// 获取已初始化的服务数量
        pub fn initializedCount(self: *Self) usize {
            var count: usize = 0;
            inline for (std.meta.fields(Deps)) |field| {
                if (@field(self.deps, field.name).initialized) {
                    count += 1;
                }
            }
            return count;
        }

        fn LazyValueType(comptime name: []const u8) type {
            const LazyType = @TypeOf(@field(@as(Deps, undefined), name));
            // 通过 ValueType 常量提取 Lazy(T) 中的 T
            return LazyType.ValueType;
        }
    };
}

// ============================================================================
// 示例服务定义
// ============================================================================

/// 简单计数器服务
pub const Counter = struct {
    value: i64 = 0,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Counter {
        std.log.debug("Counter 服务初始化", .{});
        return .{ .allocator = allocator };
    }

    pub fn increment(self: *Counter) i64 {
        self.value += 1;
        return self.value;
    }

    pub fn get(self: *Counter) i64 {
        return self.value;
    }

    pub fn deinit(self: *Counter) void {
        _ = self;
        std.log.debug("Counter 服务销毁", .{});
    }
};

/// 配置服务
pub const Config = struct {
    data: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Config {
        std.log.debug("Config 服务初始化", .{});
        return .{
            .data = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        const owned_val = try self.allocator.dupe(u8, value);
        try self.data.put(owned_key, owned_val);
    }

    pub fn getValue(self: *Config, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn deinit(self: *Config) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
        std.log.debug("Config 服务销毁", .{});
    }
};

/// 示例：延迟加载服务定义
pub const LazyServices = struct {
    /// 依赖声明（使用 Lazy 包装）
    pub const Deps = struct {
        counter: Lazy(Counter) = .{},
        config: Lazy(Config) = .{},
    };

    /// Counter 初始化方法
    pub fn initCounter(allocator: Allocator) Counter {
        return Counter.init(allocator);
    }

    /// Config 初始化方法
    pub fn initConfig(allocator: Allocator) Config {
        return Config.init(allocator);
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Lazy: 基本延迟初始化" {
    var lazy: Lazy(i32) = .{};

    try std.testing.expect(!lazy.isInitialized());

    const initFn = struct {
        fn init(_: Allocator) i32 {
            return 42;
        }
    }.init;

    const value = try lazy.getOrInit(initFn, .{std.testing.allocator});
    try std.testing.expectEqual(@as(i32, 42), value.*);
    try std.testing.expect(lazy.isInitialized());

    // 再次获取返回同一实例
    const value2 = try lazy.getOrInit(initFn, .{std.testing.allocator});
    try std.testing.expectEqual(value, value2);
}

test "Lazy: 手动设置值" {
    var lazy: Lazy([]const u8) = .{};

    lazy.setValue("hello");
    try std.testing.expect(lazy.isInitialized());
    try std.testing.expectEqualStrings("hello", lazy.getValue().?.*);
}

test "Registry: 延迟初始化服务" {
    const allocator = std.testing.allocator;
    var di = Registry(LazyServices).init(allocator);
    defer di.deinit();

    // 初始状态：无服务初始化
    try std.testing.expectEqual(@as(usize, 0), di.initializedCount());
    try std.testing.expect(!di.isInitialized("counter"));
    try std.testing.expect(!di.isInitialized("config"));

    // 访问 counter 服务
    const counter = try di.get("counter");
    try std.testing.expectEqual(@as(usize, 1), di.initializedCount());
    try std.testing.expect(di.isInitialized("counter"));

    _ = counter.increment();
    _ = counter.increment();
    try std.testing.expectEqual(@as(i64, 2), counter.get());

    // 访问 config 服务
    const config = try di.get("config");
    try std.testing.expectEqual(@as(usize, 2), di.initializedCount());

    try config.set("app", "zigcms");
    try std.testing.expectEqualStrings("zigcms", config.getValue("app").?);
}

test "Registry: 多次获取返回同一实例" {
    const allocator = std.testing.allocator;
    var di = Registry(LazyServices).init(allocator);
    defer di.deinit();

    const counter1 = try di.get("counter");
    _ = counter1.increment();

    const counter2 = try di.get("counter");
    try std.testing.expectEqual(@as(i64, 1), counter2.get());

    // 应该是同一个实例
    _ = counter2.increment();
    try std.testing.expectEqual(@as(i64, 2), counter1.get());
}
