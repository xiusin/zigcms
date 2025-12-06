//! 服务层入口
//!
//! 统一导出所有服务模块，支持延迟初始化的 DI 容器。
//!
//! ## 使用示例
//!
//! ```zig
//! var di = Registry(AppServices).init(allocator);
//! defer di.deinit();
//!
//! // 服务只在第一次访问时初始化
//! const cache = try di.get("intCache");
//! try cache.set("count", 100, null);
//!
//! // 检查服务是否已初始化
//! if (di.isInitialized("strCache")) {
//!     // ...
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const cache = @import("cache/mod.zig");
pub const datetime = @import("datetime/mod.zig");
pub const http = @import("http/mod.zig");
pub const logger = @import("logger/mod.zig");
pub const orm = @import("orm/orm.zig");
pub const pool = @import("pool/mod.zig");
pub const redis = @import("redis/redis.zig");

// ============================================================================
// 延迟初始化支持
// ============================================================================

/// 延迟初始化包装器
pub fn Lazy(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const ValueType = T;

        value: ?T = null,
        initialized: bool = false,
        mu: std.Thread.Mutex = .{},

        pub fn getOrInit(self: *Self, initFn: anytype, args: anytype) !*T {
            if (self.initialized) return &self.value.?;

            self.mu.lock();
            defer self.mu.unlock();

            if (self.initialized) return &self.value.?;

            const result = @call(.auto, initFn, args);
            if (@typeInfo(@TypeOf(result)) == .error_union) {
                self.value = try result;
            } else {
                self.value = result;
            }
            self.initialized = true;
            return &self.value.?;
        }

        pub fn isInitialized(self: *Self) bool {
            return self.initialized;
        }

        pub fn getValue(self: *Self) ?*T {
            if (self.initialized) return &self.value.?;
            return null;
        }
    };
}

/// 服务注册表
pub fn Registry(comptime Services: type) type {
    return struct {
        const Self = @This();
        const Deps = if (@hasDecl(Services, "Deps")) Services.Deps else struct {};

        allocator: Allocator,
        deps: Deps,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator, .deps = .{} };
        }

        pub fn deinit(self: *Self) void {
            inline for (std.meta.fields(Deps)) |field| {
                const lazy = &@field(self.deps, field.name);
                if (lazy.initialized) {
                    if (@hasDecl(@TypeOf(lazy.value.?), "deinit")) {
                        lazy.value.?.deinit();
                    }
                }
            }
        }

        pub fn get(self: *Self, comptime name: []const u8) !*LazyValueType(name) {
            const lazy = &@field(self.deps, name);
            const initFnName = comptime blk: {
                var buf: [64]u8 = undefined;
                @memcpy(buf[0..4], "init");
                buf[4] = std.ascii.toUpper(name[0]);
                for (name[1..], 0..) |c, i| buf[5 + i] = c;
                break :blk buf[0 .. 5 + name.len - 1];
            };

            if (@hasDecl(Services, initFnName)) {
                return lazy.getOrInit(@field(Services, initFnName), .{self.allocator});
            } else {
                @compileError("Services 缺少: " ++ initFnName);
            }
        }

        pub fn isInitialized(self: *Self, comptime name: []const u8) bool {
            return @field(self.deps, name).isInitialized();
        }

        pub fn initializedCount(self: *Self) usize {
            var count: usize = 0;
            inline for (std.meta.fields(Deps)) |field| {
                if (@field(self.deps, field.name).initialized) count += 1;
            }
            return count;
        }

        fn LazyValueType(comptime name: []const u8) type {
            return @TypeOf(@field(@as(Deps, undefined), name)).ValueType;
        }
    };
}

/// 缓存配置
pub const CacheConfig = struct {
    cleanup_interval_ms: u64 = 60_000,
    default_ttl_ms: u64 = 300_000,
    max_items: usize = 10_000,
};

/// 应用服务定义
///
/// 使用延迟初始化模式，服务只在第一次访问时才会被创建。
pub const AppServices = struct {
    /// 依赖声明
    pub const Deps = struct {
        intCache: Lazy(cache.Cache(i64)) = .{},
        strCache: Lazy(cache.Cache([]const u8)) = .{},
        cacheMgr: Lazy(cache.CacheManager([]const u8)) = .{},
        config: Lazy(ConfigService) = .{},
    };

    // 默认缓存配置
    var cacheConfig: cache.CacheConfig = .{
        .cleanup_interval_ms = 60_000,
        .default_ttl_ms = 300_000,
    };

    /// 设置缓存配置（在初始化前调用）
    pub fn setCacheConfig(config: cache.CacheConfig) void {
        cacheConfig = config;
    }

    /// 整数缓存初始化
    pub fn initIntCache(allocator: Allocator) cache.Cache(i64) {
        std.log.debug("[DI] 初始化 intCache 服务", .{});
        return cache.Cache(i64).init(allocator, cacheConfig);
    }

    /// 字符串缓存初始化
    pub fn initStrCache(allocator: Allocator) cache.Cache([]const u8) {
        std.log.debug("[DI] 初始化 strCache 服务", .{});
        return cache.Cache([]const u8).init(allocator, cacheConfig);
    }

    /// 缓存管理器初始化
    pub fn initCacheMgr(allocator: Allocator) cache.CacheManager([]const u8) {
        std.log.debug("[DI] 初始化 cacheMgr 服务", .{});
        return cache.CacheManager([]const u8).init(allocator, cacheConfig);
    }

    /// 配置服务初始化
    pub fn initConfig(allocator: Allocator) ConfigService {
        std.log.debug("[DI] 初始化 config 服务", .{});
        return ConfigService.init(allocator);
    }
};

/// 配置服务
pub const ConfigService = struct {
    data: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) ConfigService {
        return .{
            .data = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *ConfigService, key: []const u8, value: []const u8) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        const owned_val = try self.allocator.dupe(u8, value);
        try self.data.put(owned_key, owned_val);
    }

    pub fn get(self: *ConfigService, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn deinit(self: *ConfigService) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }
};

/// DI 容器便捷类型
pub const Container = Registry(AppServices);

/// 创建 DI 容器
pub fn createContainer(allocator: Allocator) Container {
    return Container.init(allocator);
}

/// 创建带配置的 DI 容器
pub fn createContainerWithConfig(allocator: Allocator, config: CacheConfig) Container {
    AppServices.setCacheConfig(.{
        .cleanup_interval_ms = config.cleanup_interval_ms,
        .default_ttl_ms = config.default_ttl_ms,
    });
    return Container.init(allocator);
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取缓存统计（需要传入已初始化的容器）
pub fn getCacheStats(di: *Container) ?CacheStats {
    var stats = CacheStats{};

    if (di.isInitialized("intCache")) {
        const s = di.deps.intCache.getValue().?.getStats();
        stats.int_hits = s.hits;
        stats.int_misses = s.misses;
        stats.total_sets += s.sets;
    }

    if (di.isInitialized("strCache")) {
        const s = di.deps.strCache.getValue().?.getStats();
        stats.str_hits = s.hits;
        stats.str_misses = s.misses;
        stats.total_sets += s.sets;
    }

    return stats;
}

/// 清理所有已初始化缓存的过期项
pub fn cleanupExpired(di: *Container) usize {
    var count: usize = 0;

    if (di.isInitialized("intCache")) {
        count += di.deps.intCache.getValue().?.cleanup();
    }
    if (di.isInitialized("strCache")) {
        count += di.deps.strCache.getValue().?.cleanup();
    }
    if (di.isInitialized("cacheMgr")) {
        count += di.deps.cacheMgr.getValue().?.cleanupAll();
    }

    return count;
}

pub const CacheStats = struct {
    int_hits: u64 = 0,
    int_misses: u64 = 0,
    str_hits: u64 = 0,
    str_misses: u64 = 0,
    total_sets: u64 = 0,

    pub fn totalHitRate(self: CacheStats) f64 {
        const hits = self.int_hits + self.str_hits;
        const total = hits + self.int_misses + self.str_misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(hits)) / @as(f64, @floatFromInt(total));
    }
};

// ============================================================================
// 测试
// ============================================================================

test "Container: 延迟初始化" {
    const allocator = std.testing.allocator;
    var di = createContainer(allocator);
    defer di.deinit();

    // 初始状态：无服务初始化
    try std.testing.expectEqual(@as(usize, 0), di.initializedCount());

    // 访问 intCache
    const intCache = try di.get("intCache");
    try std.testing.expectEqual(@as(usize, 1), di.initializedCount());
    try std.testing.expect(di.isInitialized("intCache"));
    try std.testing.expect(!di.isInitialized("strCache"));

    try intCache.set("count", 100, null);
    try std.testing.expectEqual(@as(?i64, 100), intCache.get("count"));
}

test "Container: 多服务延迟初始化" {
    const allocator = std.testing.allocator;
    var di = createContainer(allocator);
    defer di.deinit();

    // 只访问需要的服务
    const config = try di.get("config");
    try config.set("app_name", "zigcms");

    // 验证只有 config 被初始化
    try std.testing.expect(di.isInitialized("config"));
    try std.testing.expect(!di.isInitialized("intCache"));
    try std.testing.expect(!di.isInitialized("strCache"));
    try std.testing.expect(!di.isInitialized("cacheMgr"));

    try std.testing.expectEqualStrings("zigcms", config.get("app_name").?);
}

test "Container: 同一实例" {
    const allocator = std.testing.allocator;
    var di = createContainer(allocator);
    defer di.deinit();

    const cache1 = try di.get("intCache");
    try cache1.set("x", 1, null);

    const cache2 = try di.get("intCache");
    try std.testing.expectEqual(@as(?i64, 1), cache2.get("x"));

    // 修改 cache2 应该影响 cache1
    try cache2.set("x", 2, null);
    try std.testing.expectEqual(@as(?i64, 2), cache1.get("x"));
}

test "Container: 统计信息" {
    const allocator = std.testing.allocator;
    var di = createContainer(allocator);
    defer di.deinit();

    // 初始无统计
    const stats1 = getCacheStats(&di);
    try std.testing.expectEqual(@as(u64, 0), stats1.?.total_sets);

    // 使用缓存
    const intCache = try di.get("intCache");
    try intCache.set("a", 1, null);
    try intCache.set("b", 2, null);

    const stats2 = getCacheStats(&di);
    try std.testing.expectEqual(@as(u64, 2), stats2.?.total_sets);
}

test "Container: 带配置初始化" {
    const allocator = std.testing.allocator;
    var di = createContainerWithConfig(allocator, .{
        .cleanup_interval_ms = 30_000,
        .default_ttl_ms = 120_000,
        .max_items = 5_000,
    });
    defer di.deinit();

    const cache1 = try di.get("intCache");
    try cache1.set("test", 42, null);
    try std.testing.expectEqual(@as(?i64, 42), cache1.get("test"));
}

test "EntityMeta: 编译期 SQL" {
    const User = struct {
        id: ?i32,
        name: []const u8,
        age: i32,
    };

    const Meta = orm.EntityMeta(User);

    // 编译期生成的 SQL
    const insert = Meta.insertSQL("public");
    try std.testing.expect(std.mem.indexOf(u8, insert, "INSERT INTO") != null);
    try std.testing.expect(std.mem.indexOf(u8, insert, "name") != null);
    try std.testing.expect(std.mem.indexOf(u8, insert, "age") != null);

    const update = Meta.updateSQL("public");
    try std.testing.expect(std.mem.indexOf(u8, update, "UPDATE") != null);
    try std.testing.expect(std.mem.indexOf(u8, update, "SET") != null);
}

test "EntityMeta: toParams" {
    const User = struct {
        id: ?i32,
        name: []const u8,
        age: i32,
    };

    const Meta = orm.EntityMeta(User);
    const user = User{ .id = 1, .name = "张三", .age = 25 };
    const params = Meta.toParams(user);

    try std.testing.expectEqualStrings("张三", params[0]);
    try std.testing.expectEqual(@as(i32, 25), params[1]);
}
