//! Cache with Context - 带上下文的缓存操作扩展
//!
//! 为缓存操作添加超时和取消支持
//! 集成 RequestContext，提供超时保护的缓存操作
//!
//! ## 使用示例
//! ```zig
//! var ctx = try RequestContext.withTimeout(allocator, app_ctx, 2000);
//! defer ctx.deinit();
//!
//! if (try getWithContext(&ctx, "user:123")) |value| {
//!     defer allocator.free(value);
//!     // 使用缓存值
//! }
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const RequestContext = @import("../../../shared/context/request_context.zig").RequestContext;
const CacheInterface = @import("contract.zig").CacheInterface;

/// 带超时的缓存获取
///
/// 参数：
/// - ctx: 请求上下文
/// - key: 缓存键
///
/// 返回：
/// - 缓存值（调用者必须释放）
/// - null: 缓存未命中或超时
pub fn getWithContext(
    ctx: *RequestContext,
    key: []const u8,
) !?[]const u8 {
    if (ctx.isDone()) {
        return null;
    }
    
    const cache = try ctx.getCache();
    const db = ctx.getDatabase();
    
    const value = cache.get(key, db.allocator) catch |err| {
        if (ctx.isDone()) {
            return null;
        }
        return err;
    };
    
    if (ctx.isDone()) {
        if (value) |v| {
            db.allocator.free(v);
        }
        return null;
    }
    
    return value;
}

/// 带超时的缓存设置
///
/// 参数：
/// - ctx: 请求上下文
/// - key: 缓存键
/// - value: 缓存值
/// - ttl: 过期时间（秒）
///
/// 返回：
/// - true: 设置成功
/// - false: 超时
pub fn setWithContext(
    ctx: *RequestContext,
    key: []const u8,
    value: []const u8,
    ttl: ?u64,
) !bool {
    if (ctx.isDone()) {
        return false;
    }
    
    const cache = try ctx.getCache();
    
    cache.set(key, value, ttl) catch |err| {
        if (ctx.isDone()) {
            return false;
        }
        return err;
    };
    
    return !ctx.isDone();
}

/// 带超时的缓存删除
///
/// 参数：
/// - ctx: 请求上下文
/// - key: 缓存键
///
/// 返回：
/// - true: 删除成功
/// - false: 超时
pub fn deleteWithContext(
    ctx: *RequestContext,
    key: []const u8,
) !bool {
    if (ctx.isDone()) {
        return false;
    }
    
    const cache = try ctx.getCache();
    
    cache.del(key) catch |err| {
        if (ctx.isDone()) {
            return false;
        }
        return err;
    };
    
    return !ctx.isDone();
}

/// 带超时的 GetOrSet 操作
///
/// 参数：
/// - ctx: 请求上下文
/// - key: 缓存键
/// - compute_fn: 计算函数（缓存未命中时调用）
/// - ttl: 过期时间
///
/// 返回：
/// - 缓存值（调用者必须释放）
/// - null: 超时
///
/// 示例：
/// ```zig
/// const value = try getOrSetWithContext(ctx, "expensive:data", struct {
///     fn compute(allocator: Allocator) ![]const u8 {
///         // 执行昂贵的计算
///         return try allocator.dupe(u8, "computed_result");
///     }
/// }.compute, 300);
/// ```
pub fn getOrSetWithContext(
    ctx: *RequestContext,
    key: []const u8,
    compute_fn: *const fn (Allocator) anyerror![]const u8,
    ttl: ?u64,
) !?[]const u8 {
    // 先尝试获取
    if (try getWithContext(ctx, key)) |cached| {
        return cached;
    }
    
    if (ctx.isDone()) {
        return null;
    }
    
    // 计算新值
    const db = ctx.getDatabase();
    const value = compute_fn(db.allocator) catch |err| {
        if (ctx.isDone()) {
            return null;
        }
        return err;
    };
    errdefer db.allocator.free(value);
    
    if (ctx.isDone()) {
        db.allocator.free(value);
        return null;
    }
    
    // 设置缓存
    const success = try setWithContext(ctx, key, value, ttl);
    if (!success) {
        db.allocator.free(value);
        return null;
    }
    
    return value;
}

/// 带超时的批量获取
///
/// 参数：
/// - ctx: 请求上下文
/// - keys: 缓存键数组
///
/// 返回：
/// - 键值对数组（调用者必须释放）
/// - null: 超时
pub fn multiGetWithContext(
    ctx: *RequestContext,
    keys: []const []const u8,
) !?std.StringHashMap([]const u8) {
    if (ctx.isDone()) {
        return null;
    }
    
    const db = ctx.getDatabase();
    var result = std.StringHashMap([]const u8).init(db.allocator);
    errdefer {
        var it = result.iterator();
        while (it.next()) |entry| {
            db.allocator.free(entry.key_ptr.*);
            db.allocator.free(entry.value_ptr.*);
        }
        result.deinit();
    }
    
    for (keys) |key| {
        // 检查超时
        if (ctx.isDone()) {
            var it = result.iterator();
            while (it.next()) |entry| {
                db.allocator.free(entry.key_ptr.*);
                db.allocator.free(entry.value_ptr.*);
            }
            result.deinit();
            return null;
        }
        
        // 获取缓存值
        if (try getWithContext(ctx, key)) |value| {
            const key_copy = try db.allocator.dupe(u8, key);
            errdefer db.allocator.free(key_copy);
            
            try result.put(key_copy, value);
        }
    }
    
    return result;
}

/// 带超时的批量设置
///
/// 参数：
/// - ctx: 请求上下文
/// - entries: 键值对
/// - ttl: 过期时间
///
/// 返回：
/// - 成功设置的数量
/// - null: 超时
pub fn multiSetWithContext(
    ctx: *RequestContext,
    entries: std.StringHashMap([]const u8),
    ttl: ?u64,
) !?usize {
    if (ctx.isDone()) {
        return null;
    }
    
    var count: usize = 0;
    var it = entries.iterator();
    
    while (it.next()) |entry| {
        if (ctx.isDone()) {
            return null;
        }
        
        const success = try setWithContext(ctx, entry.key_ptr.*, entry.value_ptr.*, ttl);
        if (!success) {
            return null;
        }
        
        count += 1;
    }
    
    return count;
}
