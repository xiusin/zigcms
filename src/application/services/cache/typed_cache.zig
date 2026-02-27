//! 类型安全缓存包装器 (Typed Cache Wrappers)
//!
//! 提供类型安全的缓存访问，支持：
//! - JSON 序列化/反序列化的泛型缓存
//! - 带前缀的命名空间隔离
//! - 懒加载缓存
//!
//! ## TypedCache 使用示例
//!
//! ```zig
//! const User = struct {
//!     id: i64,
//!     name: []const u8,
//!     email: ?[]const u8 = null,
//! };
//!
//! // 创建类型化缓存
//! var cache_service = CacheService.init(allocator);
//! defer cache_service.deinit();
//!
//! var typed_cache = TypedCache(User).init(&cache_service, allocator);
//!
//! // 存储用户对象（自动 JSON 序列化）
//! const user = User{ .id = 1, .name = "张三", .email = "test@example.com" };
//! try typed_cache.set("user:1", user, 300);
//!
//! // 获取用户对象（自动 JSON 反序列化）
//! if (try typed_cache.get("user:1")) |cached_user| {
//!     defer typed_cache.freeValue(&cached_user);
//!     std.debug.print("用户名: {s}\n", .{cached_user.name});
//! }
//! ```
//!
//! ## PrefixedCache 使用示例
//!
//! ```zig
//! var inner = base_cache.Cache(i32).init(allocator, .{});
//! defer inner.deinit();
//!
//! var users = PrefixedCache(i32).init(&inner, "user", allocator);
//! var orders = PrefixedCache(i32).init(&inner, "order", allocator);
//!
//! try users.set("1", 100, null);  // 实际键: "user:1"
//! try orders.set("1", 200, null); // 实际键: "order:1"
//! ```

const std = @import("std");
const base_cache = @import("cache.zig");
const cache_contract = @import("contract.zig");

// ============================================================================
// TypedCache - 支持 JSON 序列化的泛型缓存
// ============================================================================

/// 类型化缓存错误
pub const TypedCacheError = error{
    /// JSON 序列化失败
    SerializationFailed,
    /// JSON 反序列化失败
    DeserializationFailed,
    /// 缓存操作失败
    CacheOperationFailed,
    /// 内存分配失败
    OutOfMemory,
};

/// 类型化缓存 - 支持 JSON 序列化/反序列化的泛型缓存
///
/// 将任意 Zig 结构体序列化为 JSON 存储到缓存中，
/// 获取时自动反序列化为原始类型。
///
/// 特性：
/// - 类型安全：编译时检查类型匹配
/// - 自动序列化：使用 std.json 进行序列化/反序列化
/// - 内存安全：提供 freeValue 方法释放反序列化的内存
/// - 接口兼容：可以使用任何实现 CacheInterface 的缓存后端
///
/// 参数:
/// - T: 要缓存的值类型，必须支持 JSON 序列化
pub fn TypedCache(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 底层缓存服务
        cache: *base_cache.CacheService,
        /// 内存分配器
        allocator: std.mem.Allocator,

        /// 创建类型化缓存实例
        ///
        /// 参数:
        /// - cache: 底层缓存服务实例
        /// - allocator: 用于序列化/反序列化的内存分配器
        pub fn init(cache: *base_cache.CacheService, allocator: std.mem.Allocator) Self {
            return .{
                .cache = cache,
                .allocator = allocator,
            };
        }

        /// 设置缓存项（自动 JSON 序列化）
        ///
        /// 将值序列化为 JSON 字符串后存入缓存。
        ///
        /// 参数:
        /// - key: 缓存键
        /// - value: 要缓存的值
        /// - ttl: 过期时间（秒），null 使用默认 TTL
        ///
        /// 错误:
        /// - SerializationFailed: JSON 序列化失败
        /// - CacheOperationFailed: 缓存写入失败
        pub fn set(self: *Self, key: []const u8, value: T, ttl: ?u64) !void {
            // 序列化为 JSON
            const json_str = std.json.stringifyAlloc(self.allocator, value, .{}) catch {
                return TypedCacheError.SerializationFailed;
            };
            defer self.allocator.free(json_str);

            // 存入缓存
            self.cache.set(key, json_str, ttl) catch {
                return TypedCacheError.CacheOperationFailed;
            };
        }

        /// 获取缓存项（自动 JSON 反序列化）
        ///
        /// 从缓存获取 JSON 字符串并反序列化为原始类型。
        ///
        /// 参数:
        /// - key: 缓存键
        ///
        /// 返回:
        /// - 反序列化后的值（调用者需要调用 freeValue 释放内存）
        /// - null（如果键不存在或已过期）
        ///
        /// 错误:
        /// - DeserializationFailed: JSON 反序列化失败
        ///
        /// 注意: 返回的值包含分配的内存，必须调用 freeValue 释放
        pub fn get(self: *Self, key: []const u8) !?T {
            // 从缓存获取 JSON 字符串
            const json_str = self.cache.get(key) orelse return null;

            // 反序列化为目标类型
            const parsed = std.json.parseFromSlice(T, self.allocator, json_str, .{}) catch {
                return TypedCacheError.DeserializationFailed;
            };

            return parsed.value;
        }

        /// 释放反序列化值的内存
        ///
        /// 当使用 get() 获取值后，必须调用此方法释放内存。
        ///
        /// 参数:
        /// - value: 要释放的值指针
        pub fn freeValue(self: *Self, value: *const T) void {
            // 使用 std.json 的内存释放机制
            const info = @typeInfo(T);
            switch (info) {
                .@"struct" => {
                    inline for (std.meta.fields(T)) |field| {
                        const field_info = @typeInfo(field.type);
                        switch (field_info) {
                            .pointer => |ptr| {
                                if (ptr.size == .Slice and ptr.child == u8) {
                                    // 释放字符串切片
                                    const slice = @field(value.*, field.name);
                                    if (slice.len > 0) {
                                        self.allocator.free(slice);
                                    }
                                }
                            },
                            .optional => |opt| {
                                const opt_info = @typeInfo(opt.child);
                                if (opt_info == .pointer) {
                                    const ptr = opt_info.pointer;
                                    if (ptr.size == .Slice and ptr.child == u8) {
                                        if (@field(value.*, field.name)) |slice| {
                                            if (slice.len > 0) {
                                                self.allocator.free(slice);
                                            }
                                        }
                                    }
                                }
                            },
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }

        /// 删除缓存项
        ///
        /// 参数:
        /// - key: 要删除的缓存键
        pub fn del(self: *Self, key: []const u8) !void {
            try self.cache.del(key);
        }

        /// 检查缓存项是否存在
        ///
        /// 参数:
        /// - key: 要检查的缓存键
        ///
        /// 返回:
        /// - true: 键存在且未过期
        /// - false: 键不存在或已过期
        pub fn exists(self: *Self, key: []const u8) bool {
            return self.cache.exists(key);
        }

        /// 获取或设置缓存（Remember 模式）
        ///
        /// 如果缓存存在则返回缓存值，否则调用回调函数生成值并缓存。
        ///
        /// 参数:
        /// - key: 缓存键
        /// - ttl: 过期时间（秒）
        /// - loader: 加载函数，当缓存未命中时调用
        ///
        /// 返回:
        /// - 缓存值或新生成的值
        pub fn remember(
            self: *Self,
            key: []const u8,
            ttl: ?u64,
            comptime loader: fn () anyerror!T,
        ) !T {
            if (try self.get(key)) |value| {
                return value;
            }

            const value = try loader();
            try self.set(key, value, ttl);
            return value;
        }

        /// 带上下文的 Remember 模式
        ///
        /// 参数:
        /// - key: 缓存键
        /// - ttl: 过期时间（秒）
        /// - ctx: 传递给加载函数的上下文
        /// - loader: 加载函数
        pub fn rememberCtx(
            self: *Self,
            key: []const u8,
            ttl: ?u64,
            ctx: anytype,
            comptime loader: fn (@TypeOf(ctx)) anyerror!T,
        ) !T {
            if (try self.get(key)) |value| {
                return value;
            }

            const value = try loader(ctx);
            try self.set(key, value, ttl);
            return value;
        }
    };
}

/// 使用 CacheInterface 的类型化缓存
///
/// 与 TypedCache 类似，但使用 CacheInterface 接口，
/// 可以与任何实现该接口的缓存后端配合使用。
pub fn TypedCacheInterface(comptime T: type) type {
    return struct {
        const Self = @This();

        /// 底层缓存接口
        cache: cache_contract.CacheInterface,
        /// 内存分配器
        allocator: std.mem.Allocator,

        /// 创建类型化缓存接口实例
        pub fn init(cache: cache_contract.CacheInterface, allocator: std.mem.Allocator) Self {
            return .{
                .cache = cache,
                .allocator = allocator,
            };
        }

        /// 设置缓存项（自动 JSON 序列化）
        pub fn set(self: *Self, key: []const u8, value: T, ttl: ?u64) !void {
            const json_str = std.json.stringifyAlloc(self.allocator, value, .{}) catch {
                return TypedCacheError.SerializationFailed;
            };
            defer self.allocator.free(json_str);

            self.cache.set(key, json_str, ttl) catch {
                return TypedCacheError.CacheOperationFailed;
            };
        }

        /// 获取缓存项（自动 JSON 反序列化）
        pub fn get(self: *Self, key: []const u8) !?T {
            const json_str = self.cache.get(key) orelse return null;

            const parsed = std.json.parseFromSlice(T, self.allocator, json_str, .{}) catch {
                return TypedCacheError.DeserializationFailed;
            };

            return parsed.value;
        }

        /// 释放反序列化值的内存
        pub fn freeValue(self: *Self, value: *const T) void {
            const info = @typeInfo(T);
            switch (info) {
                .@"struct" => {
                    inline for (std.meta.fields(T)) |field| {
                        const field_info = @typeInfo(field.type);
                        switch (field_info) {
                            .pointer => |ptr| {
                                if (ptr.size == .Slice and ptr.child == u8) {
                                    const slice = @field(value.*, field.name);
                                    if (slice.len > 0) {
                                        self.allocator.free(slice);
                                    }
                                }
                            },
                            .optional => |opt| {
                                const opt_info = @typeInfo(opt.child);
                                if (opt_info == .pointer) {
                                    const ptr = opt_info.pointer;
                                    if (ptr.size == .Slice and ptr.child == u8) {
                                        if (@field(value.*, field.name)) |slice| {
                                            if (slice.len > 0) {
                                                self.allocator.free(slice);
                                            }
                                        }
                                    }
                                }
                            },
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }

        /// 删除缓存项
        pub fn del(self: *Self, key: []const u8) !void {
            try self.cache.del(key);
        }

        /// 检查缓存项是否存在
        pub fn exists(self: *Self, key: []const u8) bool {
            return self.cache.exists(key);
        }
    };
}

// ============================================================================
// PrefixedCache - 带前缀的缓存包装器
// ============================================================================

/// 带前缀的缓存包装器
///
/// 自动为所有键添加前缀，方便命名空间隔离。
/// 适用于多租户场景或按功能模块隔离缓存。
///
/// 示例:
/// ```zig
/// var users = PrefixedCache(i32).init(&inner, "user", allocator);
/// try users.set("1", 100, null);  // 实际键: "user:1"
/// ```
pub fn PrefixedCache(comptime V: type) type {
    return struct {
        const Self = @This();
        const InnerCache = base_cache.Cache(V);

        /// 内部缓存实例
        inner: *InnerCache,
        /// 键前缀
        prefix: []const u8,
        /// 内存分配器
        allocator: std.mem.Allocator,

        /// 创建带前缀的缓存包装器
        ///
        /// 参数:
        /// - inner: 内部缓存实例
        /// - prefix: 键前缀（会自动添加 ":" 分隔符）
        /// - allocator: 用于构建前缀键的分配器
        pub fn init(inner: *InnerCache, prefix: []const u8, allocator: std.mem.Allocator) Self {
            return .{
                .inner = inner,
                .prefix = prefix,
                .allocator = allocator,
            };
        }

        /// 构建带前缀的键
        fn prefixedKey(self: *Self, key: []const u8) ![]const u8 {
            return try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ self.prefix, key });
        }

        /// 设置缓存项
        pub fn set(self: *Self, key: []const u8, value: V, ttl_ms: ?u64) !void {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            try self.inner.set(pkey, value, ttl_ms);
        }

        /// 获取缓存项
        pub fn get(self: *Self, key: []const u8) !?V {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            return self.inner.get(pkey);
        }

        /// 删除缓存项
        pub fn delete(self: *Self, key: []const u8) !bool {
            const pkey = try self.prefixedKey(key);
            defer self.allocator.free(pkey);
            return self.inner.delete(pkey);
        }
    };
}

// ============================================================================
// LazyCache - 懒加载缓存
// ============================================================================

/// 懒加载缓存
///
/// 当缓存未命中时，自动调用 loader 函数加载数据并缓存。
/// 适用于需要从数据库或外部服务加载数据的场景。
///
/// 示例:
/// ```zig
/// const Loader = struct {
///     db: *Database,
///     pub fn load(self: @This(), key: []const u8) !User {
///         return try self.db.findUser(key);
///     }
/// };
///
/// var cache = LazyCache(User, Loader).init(allocator, .{ .db = db }, 60_000);
/// defer cache.deinit();
///
/// // 第一次调用触发 loader，后续使用缓存
/// const user = try cache.get("user:1");
/// ```
pub fn LazyCache(comptime V: type, comptime Loader: type) type {
    return struct {
        const Self = @This();
        const InnerCache = base_cache.Cache(V);

        /// 内部缓存实例
        inner: InnerCache,
        /// 数据加载器
        loader: Loader,
        /// 默认 TTL（毫秒）
        default_ttl: ?u64,

        /// 创建懒加载缓存
        ///
        /// 参数:
        /// - allocator: 内存分配器
        /// - loader: 数据加载器实例
        /// - default_ttl: 默认过期时间（毫秒）
        pub fn init(
            allocator: std.mem.Allocator,
            loader: Loader,
            default_ttl: ?u64,
        ) Self {
            return .{
                .inner = InnerCache.init(allocator, .{}),
                .loader = loader,
                .default_ttl = default_ttl,
            };
        }

        /// 释放缓存资源
        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        /// 获取缓存，未命中时自动加载
        ///
        /// 如果缓存存在则直接返回，否则调用 loader 加载数据并缓存。
        ///
        /// 参数:
        /// - key: 缓存键
        ///
        /// 返回:
        /// - 缓存值或新加载的值
        pub fn get(self: *Self, key: []const u8) !V {
            if (self.inner.get(key)) |value| {
                return value;
            }

            // 调用 loader 加载
            const value = try self.loader.load(key);
            try self.inner.set(key, value, self.default_ttl);
            return value;
        }

        /// 使缓存项失效
        ///
        /// 参数:
        /// - key: 要失效的缓存键
        ///
        /// 返回:
        /// - true: 成功删除
        /// - false: 键不存在
        pub fn invalidate(self: *Self, key: []const u8) bool {
            return self.inner.delete(key);
        }

        /// 刷新缓存项
        ///
        /// 删除现有缓存并重新加载数据。
        ///
        /// 参数:
        /// - key: 要刷新的缓存键
        ///
        /// 返回:
        /// - 新加载的值
        pub fn refresh(self: *Self, key: []const u8) !V {
            _ = self.inner.delete(key);
            return try self.get(key);
        }
    };
}

// ============================================================================
// 测试
// ============================================================================

test "TypedCache: JSON 序列化/反序列化" {
    const allocator = std.testing.allocator;

    // 定义测试结构体
    const User = struct {
        id: i64,
        name: []const u8,
        age: u32,
    };

    // 创建缓存服务
    var cache_service = base_cache.CacheService.init(allocator);
    defer cache_service.deinit();

    // 创建类型化缓存
    var typed_cache = TypedCache(User).init(&cache_service, allocator);

    // 测试设置和获取
    const user = User{ .id = 1, .name = "张三", .age = 25 };
    try typed_cache.set("user:1", user, null);

    // 获取并验证
    if (try typed_cache.get("user:1")) |cached_user| {
        defer typed_cache.freeValue(&cached_user);
        try std.testing.expectEqual(@as(i64, 1), cached_user.id);
        try std.testing.expectEqualStrings("张三", cached_user.name);
        try std.testing.expectEqual(@as(u32, 25), cached_user.age);
    } else {
        try std.testing.expect(false); // 应该能获取到值
    }

    // 测试不存在的键
    const result = try typed_cache.get("user:nonexistent");
    try std.testing.expect(result == null);

    // 测试删除
    try typed_cache.del("user:1");
    try std.testing.expect(!typed_cache.exists("user:1"));
}

test "TypedCache: 简单类型" {
    const allocator = std.testing.allocator;

    // 定义简单结构体
    const Config = struct {
        enabled: bool,
        count: i32,
    };

    var cache_service = base_cache.CacheService.init(allocator);
    defer cache_service.deinit();

    var typed_cache = TypedCache(Config).init(&cache_service, allocator);

    const config = Config{ .enabled = true, .count = 42 };
    try typed_cache.set("config:app", config, null);

    if (try typed_cache.get("config:app")) |cached_config| {
        try std.testing.expectEqual(true, cached_config.enabled);
        try std.testing.expectEqual(@as(i32, 42), cached_config.count);
    } else {
        try std.testing.expect(false);
    }
}

test "TypedCacheInterface: 使用接口" {
    const allocator = std.testing.allocator;

    const Item = struct {
        id: i32,
        value: i32,
    };

    var cache_service = base_cache.CacheService.init(allocator);
    defer cache_service.deinit();

    // 获取接口
    const cache_interface = cache_service.asInterface();

    // 创建类型化缓存接口
    var typed_cache = TypedCacheInterface(Item).init(cache_interface, allocator);

    const item = Item{ .id = 100, .value = 200 };
    try typed_cache.set("item:100", item, null);

    if (try typed_cache.get("item:100")) |cached_item| {
        try std.testing.expectEqual(@as(i32, 100), cached_item.id);
        try std.testing.expectEqual(@as(i32, 200), cached_item.value);
    } else {
        try std.testing.expect(false);
    }

    try std.testing.expect(typed_cache.exists("item:100"));
    try typed_cache.del("item:100");
    try std.testing.expect(!typed_cache.exists("item:100"));
}

test "LazyCache: 懒加载" {
    const Loader = struct {
        call_count: *usize,

        pub fn load(self: @This(), key: []const u8) !i32 {
            self.call_count.* += 1;
            // 模拟从数据库加载
            if (std.mem.eql(u8, key, "user:1")) return 100;
            if (std.mem.eql(u8, key, "user:2")) return 200;
            return error.NotFound;
        }
    };

    const allocator = std.testing.allocator;
    var call_count: usize = 0;
    var c = LazyCache(i32, Loader).init(allocator, .{ .call_count = &call_count }, 60_000);
    defer c.deinit();

    // 第一次调用，触发 loader
    const v1 = try c.get("user:1");
    try std.testing.expectEqual(@as(i32, 100), v1);
    try std.testing.expectEqual(@as(usize, 1), call_count);

    // 第二次调用，使用缓存
    const v2 = try c.get("user:1");
    try std.testing.expectEqual(@as(i32, 100), v2);
    try std.testing.expectEqual(@as(usize, 1), call_count); // 没有再次调用 loader

    // 刷新缓存
    _ = try c.refresh("user:1");
    try std.testing.expectEqual(@as(usize, 2), call_count);
}
