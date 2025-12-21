//! 依赖注入容器
//!
//! 类似 Laravel 的 bind/resolve 模式。
//!
//! ## 使用示例
//!
//! ```zig
//! // 定义服务
//! const Services = struct {
//!     pub const Bindings = struct {
//!         cache: Cache,
//!         config: Config,
//!     };
//!
//!     pub fn makeCache(alloc: Allocator) Cache {
//!         return Cache.init(alloc);
//!     }
//!
//!     pub fn makeConfig(alloc: Allocator) Config {
//!         return Config.init(alloc);
//!     }
//! };
//!
//! var app = Container(Services).init(allocator);
//! defer app.deinit();
//!
//! // 解析（延迟初始化）
//! const cache = try app.resolve("cache");
//! try cache.set("key", value);
//!
//! // 手动绑定
//! app.bind("config", myConfig);
//! ```
//!
//! ## 依赖说明
//! 此模块是共享层的一部分，不依赖任何业务层。

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 类型安全的依赖注入容器
///
/// 支持 Laravel 风格的 bind/resolve 模式。
pub fn Container(comptime ServiceDefs: type) type {
    const Bindings = ServiceDefs.Bindings;
    const fields = std.meta.fields(Bindings);

    return struct {
        const Self = @This();

        allocator: Allocator,
        resolved_flags: [fields.len]bool,
        services: Services,
        mu: std.Thread.Mutex = .{},

        // 服务存储结构
        const Services = blk: {
            var service_fields: [fields.len]std.builtin.Type.StructField = undefined;
            for (fields, 0..) |field, i| {
                service_fields[i] = .{
                    .name = field.name,
                    .type = field.type,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(field.type),
                };
            }
            break :blk @Type(.{ .@"struct" = .{
                .layout = .auto,
                .fields = &service_fields,
                .decls = &.{},
                .is_tuple = false,
            } });
        };

        /// 初始化容器
        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .resolved_flags = [_]bool{false} ** fields.len,
                .services = undefined,
            };
        }

        /// 销毁容器（自动清理已解析的服务）
        pub fn deinit(self: *Self) void {
            inline for (fields, 0..) |field, i| {
                if (self.resolved_flags[i]) {
                    if (@hasDecl(field.type, "deinit")) {
                        @field(self.services, field.name).deinit();
                    }
                }
            }
        }

        /// 解析服务（延迟初始化）
        ///
        /// 首次调用时执行 make{Name} 工厂方法创建实例。
        /// 后续调用返回同一实例（单例模式）。
        pub fn resolve(self: *Self, comptime name: []const u8) !*FieldType(name) {
            const idx = fieldIndex(name);

            // 快速路径：已解析
            if (self.resolved_flags[idx]) {
                return &@field(self.services, name);
            }

            self.mu.lock();
            defer self.mu.unlock();

            // 双重检查
            if (self.resolved_flags[idx]) {
                return &@field(self.services, name);
            }

            // 调用工厂方法
            const factoryName = comptime makeFactoryName(name);
            if (@hasDecl(ServiceDefs, factoryName)) {
                const factory = @field(ServiceDefs, factoryName);
                const result = factory(self.allocator);

                if (@typeInfo(@TypeOf(result)) == .error_union) {
                    @field(self.services, name) = try result;
                } else {
                    @field(self.services, name) = result;
                }
                self.resolved_flags[idx] = true;
                return &@field(self.services, name);
            }

            return error.NoFactoryMethod;
        }

        /// 手动绑定服务实例
        ///
        /// 直接设置服务实例，跳过工厂方法。
        pub fn bind(self: *Self, comptime name: []const u8, value: FieldType(name)) void {
            self.mu.lock();
            defer self.mu.unlock();

            const idx = fieldIndex(name);
            @field(self.services, name) = value;
            self.resolved_flags[idx] = true;
        }

        /// 检查服务是否已解析
        pub fn isResolved(self: *Self, comptime name: []const u8) bool {
            return self.resolved_flags[fieldIndex(name)];
        }

        /// 获取已解析服务数量
        pub fn resolvedCount(self: *Self) usize {
            var count: usize = 0;
            for (self.resolved_flags) |flag| {
                if (flag) count += 1;
            }
            return count;
        }

        /// 强制重新解析（重置并重新创建）
        pub fn refresh(self: *Self, comptime name: []const u8) !*FieldType(name) {
            const idx = fieldIndex(name);

            self.mu.lock();
            defer self.mu.unlock();

            // 先清理旧实例
            if (self.resolved_flags[idx]) {
                if (@hasDecl(FieldType(name), "deinit")) {
                    @field(self.services, name).deinit();
                }
            }
            self.resolved_flags[idx] = false;

            self.mu.unlock();
            defer self.mu.lock();
            return self.resolve(name);
        }

        fn FieldType(comptime name: []const u8) type {
            return @TypeOf(@field(@as(Bindings, undefined), name));
        }

        fn fieldIndex(comptime name: []const u8) comptime_int {
            comptime {
                for (fields, 0..) |field, i| {
                    if (std.mem.eql(u8, field.name, name)) return i;
                }
                @compileError("未知服务: " ++ name);
            }
        }

        fn makeFactoryName(comptime name: []const u8) []const u8 {
            comptime {
                var buf: [68]u8 = undefined;
                @memcpy(buf[0..4], "make");
                buf[4] = std.ascii.toUpper(name[0]);
                for (name[1..], 0..) |c, i| buf[5 + i] = c;
                return buf[0 .. 5 + name.len - 1];
            }
        }
    };
}

// ============================================================================
// 示例服务
// ============================================================================

/// 缓存服务
pub const Cache = struct {
    data: std.StringHashMap(i64),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Cache {
        std.debug.print("[DI] 创建 Cache 服务\n", .{});
        return .{
            .data = std.StringHashMap(i64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Cache, key: []const u8, value: i64) !void {
        // 检查是否已存在，避免重复分配内存
        if (self.data.getPtr(key)) |ptr| {
            ptr.* = value;
            return;
        }
        const owned = try self.allocator.dupe(u8, key);
        try self.data.put(owned, value);
    }

    pub fn get(self: *Cache, key: []const u8) ?i64 {
        return self.data.get(key);
    }

    pub fn deinit(self: *Cache) void {
        var iter = self.data.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.data.deinit();
    }
};

/// 配置服务
pub const Config = struct {
    values: std.StringHashMap([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Config {
        std.debug.print("[DI] 创建 Config 服务\n", .{});
        return .{
            .values = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) !void {
        const k = try self.allocator.dupe(u8, key);
        const v = try self.allocator.dupe(u8, value);
        try self.values.put(k, v);
    }

    pub fn get(self: *Config, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn deinit(self: *Config) void {
        var iter = self.values.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }
};

/// 日志服务
pub const Logger = struct {
    prefix: []const u8,
    level: Level,

    pub const Level = enum { debug, info, warn, err };

    pub fn init(_: Allocator) Logger {
        std.debug.print("[DI] 创建 Logger 服务\n", .{});
        return .{ .prefix = "[App]", .level = .info };
    }

    pub fn log(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        std.debug.print("{s} " ++ fmt ++ "\n", .{self.prefix} ++ args);
    }
};

// ============================================================================
// 示例应用服务定义
// ============================================================================

/// 应用服务定义
pub const AppServices = struct {
    /// 服务绑定声明
    pub const Bindings = struct {
        cache: Cache,
        config: Config,
        logger: Logger,
    };

    /// 工厂方法：创建 Cache
    pub fn makeCache(allocator: Allocator) Cache {
        return Cache.init(allocator);
    }

    /// 工厂方法：创建 Config
    pub fn makeConfig(allocator: Allocator) Config {
        return Config.init(allocator);
    }

    /// 工厂方法：创建 Logger
    pub fn makeLogger(allocator: Allocator) Logger {
        return Logger.init(allocator);
    }
};

/// 便捷类型
pub const App = Container(AppServices);

// ============================================================================
// 测试
// ============================================================================

test "Container: resolve 延迟初始化" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    // 初始状态：无服务解析
    try std.testing.expectEqual(@as(usize, 0), app.resolvedCount());
    try std.testing.expect(!app.isResolved("cache"));

    // 解析 cache
    const cache = try app.resolve("cache");
    try std.testing.expectEqual(@as(usize, 1), app.resolvedCount());
    try std.testing.expect(app.isResolved("cache"));

    try cache.set("count", 100);
    try std.testing.expectEqual(@as(?i64, 100), cache.get("count"));
}

test "Container: resolve 返回同一实例" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const cache1 = try app.resolve("cache");
    try cache1.set("x", 1);

    const cache2 = try app.resolve("cache");
    try std.testing.expectEqual(@as(?i64, 1), cache2.get("x"));

    // 修改 cache2 影响 cache1（同一实例）
    try cache2.set("x", 2);
    try std.testing.expectEqual(@as(?i64, 2), cache1.get("x"));
}

test "Container: bind 手动绑定" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    // 手动绑定自定义实例
    var custom_cache = Cache.init(allocator);
    try custom_cache.set("preset", 999);

    app.bind("cache", custom_cache);

    try std.testing.expect(app.isResolved("cache"));
    const cache = try app.resolve("cache");
    try std.testing.expectEqual(@as(?i64, 999), cache.get("preset"));
}

test "Container: 多服务解析" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    const cache = try app.resolve("cache");
    const config = try app.resolve("config");
    _ = try app.resolve("logger");

    try cache.set("user_id", 123);
    try config.set("app_name", "zigcms");

    try std.testing.expectEqual(@as(usize, 3), app.resolvedCount());
    try std.testing.expectEqual(@as(?i64, 123), cache.get("user_id"));
    try std.testing.expectEqualStrings("zigcms", config.get("app_name").?);
}

test "Container: 部分服务解析" {
    const allocator = std.testing.allocator;
    var app = App.init(allocator);
    defer app.deinit();

    // 只解析 config
    const config = try app.resolve("config");
    try config.set("key", "value");

    // cache 和 logger 未解析
    try std.testing.expect(!app.isResolved("cache"));
    try std.testing.expect(app.isResolved("config"));
    try std.testing.expect(!app.isResolved("logger"));
    try std.testing.expectEqual(@as(usize, 1), app.resolvedCount());
}
