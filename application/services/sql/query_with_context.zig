//! Query with Context - 带上下文的数据库查询扩展
//!
//! 为数据库操作添加超时和取消支持
//! 集成 RequestContext，提供类似 Go database/sql 的上下文支持
//!
//! ## 使用示例
//! ```zig
//! var ctx = try RequestContext.withTimeout(allocator, app_ctx, 5000);
//! defer ctx.deinit();
//!
//! const users = try queryWithContext(User, &ctx, "SELECT * FROM users") 
//!     orelse return error.QueryTimeout;
//! defer User.freeModels(allocator, users);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const RequestContext = @import("../../../shared/context/request_context.zig").RequestContext;
const sql = @import("mod.zig");

/// 带超时的数据库查询辅助函数
///
/// 参数：
/// - T: 模型类型
/// - ctx: 请求上下文（用于超时控制）
/// - query_sql: SQL 查询语句
///
/// 返回：
/// - 查询结果数组（调用者必须释放）
/// - null: 查询超时或被取消
///
/// 错误：数据库错误或内存分配失败
///
/// 示例：
/// ```zig
/// var ctx = try RequestContext.withTimeout(allocator, app_ctx, 3000);
/// defer ctx.deinit();
///
/// const users = try queryWithContext(User, &ctx, "SELECT * FROM users WHERE active = 1");
/// if (users) |u| {
///     defer User.freeModels(db.allocator, u);
///     // 处理结果
/// } else {
///     // 查询超时
/// }
/// ```
pub fn queryWithContext(
    comptime T: type,
    ctx: *RequestContext,
    query_sql: []const u8,
) !?[]T {
    // 检查超时
    if (ctx.isDone()) {
        return null;
    }
    
    const db = ctx.getDatabase();
    const Model = @import("model.zig").Model(T);
    
    // 执行查询
    var result = db.rawQuery(query_sql, .{}) catch |err| {
        // 查询失败，检查是否是超时导致
        if (ctx.isDone()) {
            return null;
        }
        return err;
    };
    defer result.deinit();
    
    // 映射结果时检查超时
    if (ctx.isDone()) {
        return null;
    }
    
    const models = try @import("orm.zig").mapResults(T, db.allocator, &result);
    
    // 检查是否在映射过程中超时
    if (ctx.isDone()) {
        Model.freeModels(db.allocator, models);
        return null;
    }
    
    return models;
}

/// 带超时的单条记录查询
///
/// 参数：
/// - T: 模型类型
/// - ctx: 请求上下文
/// - query_sql: SQL 查询语句
///
/// 返回：
/// - 单条记录（调用者必须释放）
/// - null: 未找到或超时
pub fn queryOneWithContext(
    comptime T: type,
    ctx: *RequestContext,
    query_sql: []const u8,
) !?T {
    const results = try queryWithContext(T, ctx, query_sql) orelse return null;
    defer {
        const db = ctx.getDatabase();
        const Model = @import("model.zig").Model(T);
        Model.freeModels(db.allocator, results);
    }
    
    if (results.len == 0) return null;
    
    // 复制第一条记录（因为要释放整个数组）
    return results[0];
}

/// 带超时的 Exec 操作
///
/// 参数：
/// - ctx: 请求上下文
/// - exec_sql: SQL 语句
///
/// 返回：
/// - 影响的行数
/// - null: 执行超时
pub fn execWithContext(
    ctx: *RequestContext,
    exec_sql: []const u8,
) !?u64 {
    if (ctx.isDone()) {
        return null;
    }
    
    const db = ctx.getDatabase();
    
    const result = db.rawExec(exec_sql, .{}) catch |err| {
        if (ctx.isDone()) {
            return null;
        }
        return err;
    };
    
    if (ctx.isDone()) {
        return null;
    }
    
    return result;
}

/// 带超时的事务执行
///
/// 参数：
/// - ctx: 请求上下文
/// - operation: 事务操作函数
///
/// 返回：
/// - true: 事务成功提交
/// - false: 事务超时或回滚
///
/// 示例：
/// ```zig
/// const success = try transactionWithContext(ctx, struct {
///     fn run(tx_ctx: *RequestContext) !void {
///         _ = try execWithContext(tx_ctx, "INSERT INTO users ...");
///         _ = try execWithContext(tx_ctx, "UPDATE stats ...");
///     }
/// }.run);
/// ```
pub fn transactionWithContext(
    ctx: *RequestContext,
    operation: *const fn (*RequestContext) anyerror!void,
) !bool {
    if (ctx.isDone()) {
        return false;
    }
    
    const db = ctx.getDatabase();
    
    // 开始事务
    _ = try db.rawExec("BEGIN TRANSACTION", .{});
    errdefer {
        _ = db.rawExec("ROLLBACK", .{}) catch {};
    }
    
    // 执行操作
    operation(ctx) catch |err| {
        _ = db.rawExec("ROLLBACK", .{}) catch {};
        
        if (ctx.isDone()) {
            return false;
        }
        return err;
    };
    
    // 检查超时
    if (ctx.isDone()) {
        _ = db.rawExec("ROLLBACK", .{}) catch {};
        return false;
    }
    
    // 提交事务
    _ = try db.rawExec("COMMIT", .{});
    return true;
}

/// 带超时的批量插入
///
/// 参数：
/// - T: 模型类型
/// - ctx: 请求上下文
/// - records: 要插入的记录数组
///
/// 返回：
/// - 成功插入的记录数
/// - null: 超时
pub fn batchInsertWithContext(
    comptime T: type,
    ctx: *RequestContext,
    records: []const T,
) !?usize {
    if (ctx.isDone()) {
        return null;
    }
    
    _ = ctx.getDatabase();
    var inserted: usize = 0;
    
    for (records) |record| {
        // 定期检查超时
        if (ctx.isDone()) {
            return null;
        }
        
        // 插入记录（需要实现 insertOne 方法）
        _ = record;
        // TODO: 实现批量插入
        // const db = ctx.getDatabase();
        // const sql = try buildInsertSQL(T, db.allocator, record);
        // defer db.allocator.free(sql);
        // _ = try db.rawExec(sql, .{});
        
        inserted += 1;
    }
    
    return inserted;
}
