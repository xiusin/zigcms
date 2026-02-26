//! Example Context Controller - AppContext 使用示例控制器
//!
//! 本控制器展示如何使用 AppContext 替代全局状态
//! 使用显式依赖注入模式，提升可测试性和可维护性
//!
//! ## 使用模式
//! ```zig
//! // 初始化控制器（在 bootstrap 中）
//! const ctrl = ExampleContextController.init(app_context);
//!
//! // 在控制器中访问资源
//! const db = ctrl.ctx.getDatabase();
//! const cache = try ctrl.ctx.getCache();
//! ```

const std = @import("std");
const AppContext = @import("../../shared/context/app_context.zig").AppContext;
const base = @import("base.fn.zig");

/// 使用 AppContext 的示例控制器
///
/// 展示了架构重构后的推荐模式：
/// - 通过构造函数注入 AppContext
/// - 使用 ctx.getDatabase() 等方法获取资源
/// - 避免直接访问全局状态
pub const ExampleContextController = struct {
    ctx: *AppContext,
    
    const Self = @This();
    
    /// 初始化控制器
    ///
    /// 参数：
    /// - app_context: 应用上下文（借用引用）
    ///
    /// 返回：控制器实例
    pub fn init(app_context: *AppContext) Self {
        return .{
            .ctx = app_context,
        };
    }
    
    /// 示例：获取数据库统计信息
    ///
    /// GET /api/example/db-stats
    ///
    /// 响应示例：
    /// ```json
    /// {
    ///   "code": 200,
    ///   "message": "success",
    ///   "data": {
    ///     "driver": "sqlite",
    ///     "has_connection": true
    ///   }
    /// }
    /// ```
    pub fn getDbStats(self: *Self, req: *base.zap.Request) !void {
        // 从上下文获取数据库连接（而不是 global.get_db()）
        const db = self.ctx.getDatabase();
        
        const allocator = db.allocator;
        
        // 构建响应数据
        const response = try std.fmt.allocPrint(allocator, 
            \\{{"driver": "sqlite", "has_connection": true}}
        , .{});
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 示例：获取缓存统计信息
    ///
    /// GET /api/example/cache-stats
    ///
    /// 响应示例：
    /// ```json
    /// {
    ///   "code": 200,
    ///   "message": "success",
    ///   "data": {
    ///     "entries": 10,
    ///     "expired": 2,
    ///     "hits": 100,
    ///     "misses": 20
    ///   }
    /// }
    /// ```
    pub fn getCacheStats(self: *Self, req: *base.zap.Request) !void {
        // 从上下文获取缓存服务（而不是直接访问 global）
        const cache = try self.ctx.getCache();
        const stats = cache.stats();
        
        const db = self.ctx.getDatabase();
        const allocator = db.allocator;
        
        // 构建响应
        const response = try std.fmt.allocPrint(allocator,
            \\{{"entries": {}, "expired": {}, "hits": {}, "misses": {}}}
        , .{ stats.entries, stats.expired, stats.hits, stats.misses });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
    
    /// 示例：测试缓存操作
    ///
    /// POST /api/example/test-cache
    ///
    /// 请求体：
    /// ```json
    /// {
    ///   "key": "test_key",
    ///   "value": "test_value"
    /// }
    /// ```
    pub fn testCache(self: *Self, req: *base.zap.Request) !void {
        const cache = try self.ctx.getCache();
        const db = self.ctx.getDatabase();
        const allocator = db.allocator;
        
        // 写入缓存
        try cache.set("example:test", "Hello from AppContext!", 60);
        
        // 读取缓存
        if (try cache.get("example:test", allocator)) |value| {
            defer allocator.free(value);
            
            const response = try std.fmt.allocPrint(allocator,
                \\{{"message": "Cache test successful", "value": "{s}"}}
            , .{value});
            defer allocator.free(response);
            
            return base.send_json_ok(req, response);
        }
        
        return base.send_failed(req, "Cache test failed");
    }
    
    /// 示例：获取配置信息
    ///
    /// GET /api/example/config
    pub fn getConfig(self: *Self, req: *base.zap.Request) !void {
        // 从上下文获取配置
        const config = self.ctx.getConfig();
        const db = self.ctx.getDatabase();
        const allocator = db.allocator;
        
        const response = try std.fmt.allocPrint(allocator,
            \\{{"env": "{s}", "port": {}}}
        , .{ config.env, config.server.port });
        defer allocator.free(response);
        
        return base.send_json_ok(req, response);
    }
};
