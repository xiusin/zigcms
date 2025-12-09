//! 进程内缓存模块
//!
//! 特性：
//! - 支持 TTL 过期时间
//! - 并发安全（读写锁）
//! - 内存安全（自动清理）
//! - 泛型支持
//!
//! ## 基本用法
//!
//! ```zig
//! const cache = @import("services/cache/mod.zig");
//!
//! var c = cache.Cache([]const u8).init(allocator, .{
//!     .cleanup_interval_ms = 60_000,
//!     .default_ttl_ms = 300_000, // 5 分钟默认过期
//! });
//! defer c.deinit();
//!
//! // 设置缓存
//! try c.set("user:1:name", "张三", 60_000); // 1 分钟过期
//! try c.set("user:1:email", "test@example.com", null); // 使用默认过期时间
//!
//! // 获取缓存
//! if (c.get("user:1:name")) |name| {
//!     std.debug.print("用户名: {s}\n", .{name});
//! }
//!
//! // 检查是否存在
//! if (c.exists("user:1:name")) {
//!     // ...
//! }
//!
//! // 延长过期时间
//! _ = c.touch("user:1:name", 120_000); // 延长到 2 分钟
//!
//! // 删除
//! _ = c.delete("user:1:name");
//!
//! // 清空
//! c.flush();
//! ```
//!
//! ## 多表管理
//!
//! ```zig
//! var mgr = cache.CacheManager(i32).init(allocator, .{});
//! defer mgr.deinit();
//!
//! const users = try mgr.table("users");
//! const settings = try mgr.table("settings");
//!
//! try users.set("id:1", 100, null);
//! try settings.set("theme", 1, null);
//! ```
//!
//! ## 懒加载缓存
//!
//! ```zig
//! const Loader = struct {
//!     db: *Database,
//!     pub fn load(self: @This(), key: []const u8) !User {
//!         return try self.db.findUser(key);
//!     }
//! };
//!
//! var c = cache.LazyCache(User, Loader).init(allocator, .{ .db = db }, 60_000);
//! defer c.deinit();
//!
//! // 第一次调用触发 loader，后续使用缓存
//! const user = try c.get("user:1");
//! ```
//!
//! ## 前缀隔离
//!
//! ```zig
//! var inner = cache.Cache(i32).init(allocator, .{});
//! defer inner.deinit();
//!
//! var users = cache.PrefixedCache(i32).init(&inner, "user", allocator);
//! var orders = cache.PrefixedCache(i32).init(&inner, "order", allocator);
//!
//! try users.set("1", 100, null);  // 实际键: "user:1"
//! try orders.set("1", 200, null); // 实际键: "order:1"
//! ```
//!
//! ## Remember 模式（Laravel 风格）
//!
//! ```zig
//! // 基本用法：缓存不存在时调用回调生成
//! const user = try c.remember("user:1", 60_000, struct {
//!     pub fn call() !User {
//!         return try db.findUser(1);
//!     }
//! }.call);
//!
//! // 带上下文的 remember
//! const ctx = .{ .db = db, .id = user_id };
//! const user = try c.rememberCtx("user:1", 60_000, ctx, struct {
//!     pub fn call(c: @TypeOf(ctx)) !User {
//!         return try c.db.findUser(c.id);
//!     }
//! }.call);
//!
//! // 永不过期版本
//! const config = try c.rememberForever("app:config", loadConfig);
//!
//! // 其他 Laravel 风格方法
//! const v = c.pull("temp");           // 获取后删除
//! try c.forever("key", value);        // 永久设置
//! const ok = try c.add("key", value, ttl);  // 仅在不存在时设置
//! ```

const base = @import("cache.zig");
const typed = @import("typed_cache.zig");

pub const Cache = base.Cache;
pub const CacheManager = base.CacheManager;
pub const CacheConfig = base.CacheConfig;

pub const PrefixedCache = typed.PrefixedCache;
pub const LazyCache = typed.LazyCache;

test {
    _ = base;
    _ = typed;
}
