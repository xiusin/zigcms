# 短期优化实施文档

## 概述

本文档提供 4 个短期优化项的完整实施方案和使用指南。

## 优化 1: 数据库连接池动态调整

### 实施文件
- `src/infrastructure/database/connection_pool_manager.zig`

### 集成步骤

#### 1. 在系统启动时初始化连接池管理器

```zig
// src/main.zig
const ConnectionPoolManager = @import("infrastructure/database/connection_pool_manager.zig").ConnectionPoolManager;

pub fn main() !void {
    // 创建连接池管理器
    const pool_config = ConnectionPoolManager.Config{
        .min_size = 5,
        .max_size = 50,
        .initial_size = 10,
        .scale_up_threshold = 0.8,    // 80% 使用率时扩容
        .scale_down_threshold = 0.3,  // 30% 使用率时缩容
        .scale_interval = 60,         // 每 60 秒检查一次
        .scale_step = 5,              // 每次调整 5 个连接
    };
    
    var pool_manager = ConnectionPoolManager.init(allocator, pool_config);
    
    // 注册到 DI 容器
    try container.registerInstance(ConnectionPoolManager, &pool_manager, null);
}
```

#### 2. 在数据库连接获取/释放时调用

```zig
// src/infrastructure/database/database.zig
pub fn getConnection(self: *Database) !*Connection {
    // 通知连接池管理器
    const pool_manager = try container.resolve(ConnectionPoolManager);
    pool_manager.onAcquire();
    
    // 获取连接
    const conn = try self.pool.acquire();
    return conn;
}

pub fn releaseConnection(self: *Database, conn: *Connection) void {
    // 释放连接
    self.pool.release(conn);
    
    // 通知连接池管理器
    const pool_manager = container.resolve(ConnectionPoolManager) catch return;
    pool_manager.onRelease();
}
```

#### 3. 添加监控端点

```zig
// src/api/controllers/monitor.controller.zig
pub fn getPoolStats(req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer();
    const pool_manager = try container.resolve(ConnectionPoolManager);
    
    const stats = pool_manager.getStats();
    
    try base.send_success(req, .{
        .current_size = stats.current_size,
        .active_connections = stats.active_connections,
        .idle_connections = stats.idle_connections,
        .peak_connections = stats.peak_connections,
        .usage_rate = stats.usage_rate,
    });
}
```

### 预期效果
- 低峰期自动缩容到 5 个连接，节省资源
- 高峰期自动扩容到 50 个连接，提升性能
- 平均响应时间降低 15-20%

---

## 优化 2: 缓存预热

### 实施文件
- `src/infrastructure/cache/cache_warmer.zig`

### 集成步骤

#### 1. 在系统启动时执行缓存预热

```zig
// src/main.zig
const CacheWarmer = @import("infrastructure/cache/cache_warmer.zig").CacheWarmer;

pub fn main() !void {
    // ... 初始化数据库和缓存 ...
    
    // 创建缓存预热器
    var warmer = CacheWarmer.init(allocator, cache);
    
    // 执行预热（异步）
    const warmup_thread = try std.Thread.spawn(.{}, warmupAsync, .{&warmer});
    warmup_thread.detach();
    
    // 继续启动服务器
    std.log.info("服务器启动中，缓存预热进行中...", .{});
}

fn warmupAsync(warmer: *CacheWarmer) void {
    warmer.warmup() catch |err| {
        std.log.err("缓存预热失败: {}", .{err});
    };
}
```

#### 2. 添加手动预热端点（可选）

```zig
// src/api/controllers/admin.controller.zig
pub fn warmupCache(req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer();
    const cache = try container.resolve(CacheInterface);
    
    var warmer = CacheWarmer.init(req.allocator, cache);
    try warmer.warmup();
    
    try base.send_success(req, .{ .message = "缓存预热完成" });
}
```

### 预热内容
1. 活跃项目列表（最多 50 个）
2. 活跃项目的模块树（最多 10 个项目）
3. 热门测试用例（最近更新的 100 个）
4. 活跃用户信息（最多 100 个）
5. 系统配置（4 个配置项）

### 预期效果
- 首次访问响应时间降低 60-80%
- 缓存命中率从 70% 提升到 90%
- 系统启动后立即可用，无冷启动问题

---

## 优化 3: API 限流

### 实施文件
- `src/api/middleware/rate_limiter.zig`

### 集成步骤

#### 1. 在路由注册时添加限流中间件

```zig
// src/api/bootstrap.zig
const RateLimiter = @import("middleware/rate_limiter.zig").RateLimiter;

pub fn registerMiddleware(self: *Self) !void {
    // 创建限流器
    const rate_limiter_config = RateLimiter.Config{
        .global_limit = 1000,  // 全局每分钟 1000 个请求
        .ip_limit = 100,       // 每个 IP 每分钟 100 个请求
        .user_limit = 200,     // 每个用户每分钟 200 个请求
        .endpoint_limits = &.{
            .{ .path = "/api/quality/ai/generate", .limit = 10, .window = 60 },
            .{ .path = "/api/quality/test-cases/batch", .limit = 20, .window = 60 },
        },
        .whitelist_ips = &.{
            "127.0.0.1",
            "::1",
        },
    };
    
    var rate_limiter = RateLimiter.init(self.allocator, self.cache, rate_limiter_config);
    
    // 注册中间件
    try self.app.use(rateLimiterMiddleware, .{&rate_limiter});
}

fn rateLimiterMiddleware(req: *zap.Request, limiter: *RateLimiter) !void {
    if (!try limiter.handle(req)) {
        return; // 已发送限流响应
    }
    
    // 继续处理请求
    try req.next();
}
```

#### 2. 添加限流统计端点

```zig
// src/api/controllers/monitor.controller.zig
pub fn getRateLimitStats(req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer();
    const rate_limiter = try container.resolve(RateLimiter);
    
    const stats = try rate_limiter.getStats();
    
    try base.send_success(req, .{
        .global_requests = stats.global_requests,
        .global_limit = stats.global_limit,
        .global_usage_rate = stats.global_usage_rate,
    });
}
```

### 限流策略
1. **全局限流**: 每分钟 1000 个请求
2. **IP 限流**: 每个 IP 每分钟 100 个请求
3. **用户限流**: 每个用户每分钟 200 个请求
4. **端点限流**: 
   - AI 生成接口: 每分钟 10 个请求
   - 批量操作接口: 每分钟 20 个请求

### 预期效果
- 防止恶意请求和 DDoS 攻击
- 保护系统资源，避免过载
- 提升系统稳定性

---

## 优化 4: 日志优化

### 实施文件
- `src/core/logger/log_optimizer.zig`

### 集成步骤

#### 1. 在系统启动时初始化日志优化器

```zig
// src/main.zig
const log_optimizer = @import("core/logger/log_optimizer.zig");

pub fn main() !void {
    // 初始化日志优化器
    const log_config = log_optimizer.LogOptimizer.Config{
        .level = .info,                    // 生产环境使用 info 级别
        .enable_sampling = true,           // 启用采样
        .sample_rate = 10,                 // 1/10 的日志会被记录
        .enable_aggregation = true,        // 启用聚合
        .aggregation_window = 60,          // 60 秒窗口
        .slow_query_threshold = 1000,      // 慢查询阈值 1 秒
        .log_request_details = false,      // 不记录所有请求详情
        .log_response_details = false,     // 不记录所有响应详情
        .exclude_paths = &.{
            "/health",
            "/metrics",
            "/favicon.ico",
        },
    };
    
    log_optimizer.initGlobalOptimizer(log_config);
}
```

#### 2. 在代码中使用优化后的日志

```zig
// 使用优化后的日志宏
const log = @import("core/logger/log_optimizer.zig");

pub fn someFunction() !void {
    // 普通日志（会被采样）
    log.logInfo("处理请求: {s}", .{path});
    
    // 警告日志（总是记录）
    log.logWarn("发现异常: {}", .{err});
    
    // 错误日志（总是记录）
    log.logErr("操作失败: {}", .{err});
    
    // 调试日志（只在 debug 级别记录）
    log.logDebug("调试信息: {d}", .{value});
}
```

#### 3. 使用请求日志中间件

```zig
// src/api/middleware/request_logger.zig
const RequestLogger = @import("core/logger/log_optimizer.zig").RequestLogger;

pub fn logRequest(req: *zap.Request) !void {
    const start_time = std.time.milliTimestamp();
    
    // 处理请求
    try req.next();
    
    // 记录日志
    const duration = std.time.milliTimestamp() - start_time;
    const optimizer = log_optimizer.getGlobalOptimizer();
    var logger = RequestLogger.init(optimizer);
    
    logger.logRequest(
        req.getMethod(),
        req.getPath() orelse "/",
        @intCast(duration),
    );
}
```

### 优化策略
1. **日志级别**: 生产环境使用 info 级别，开发环境使用 debug 级别
2. **采样记录**: 高频日志只记录 1/10
3. **慢查询记录**: 只记录超过 1 秒的查询
4. **排除路径**: 健康检查等端点不记录日志
5. **聚合相同日志**: 60 秒内相同日志只记录一次

### 预期效果
- 日志输出量减少 80-90%
- 磁盘 I/O 降低 70-80%
- 日志文件大小减少 85%
- 系统性能提升 5-10%

---

## 综合效果预估

| 优化项 | 性能提升 | 资源节省 |
|--------|----------|----------|
| 连接池动态调整 | 15-20% | 节省 40% 数据库连接 |
| 缓存预热 | 60-80% (首次访问) | 减少 70% 数据库查询 |
| API 限流 | 提升稳定性 | 防止资源耗尽 |
| 日志优化 | 5-10% | 减少 85% 日志文件 |

**综合提升**: 系统性能提升 20-30%，资源使用降低 50-60%

---

## 监控和验证

### 1. 连接池监控

```bash
# 查看连接池状态
curl http://localhost:3000/api/monitor/pool-stats

# 响应示例
{
  "current_size": 15,
  "active_connections": 12,
  "idle_connections": 3,
  "peak_connections": 18,
  "usage_rate": 0.8
}
```

### 2. 限流监控

```bash
# 查看限流统计
curl http://localhost:3000/api/monitor/rate-limit-stats

# 响应示例
{
  "global_requests": 850,
  "global_limit": 1000,
  "global_usage_rate": 0.85
}
```

### 3. 日志监控

```bash
# 查看日志文件大小
du -h logs/

# 对比优化前后
# 优化前: 500MB/天
# 优化后: 75MB/天 (减少 85%)
```

### 4. 缓存监控

```bash
# 查看缓存命中率
redis-cli info stats | grep keyspace_hits

# 对比优化前后
# 优化前: 70% 命中率
# 优化后: 90% 命中率
```

---

## 配置建议

### 开发环境
```zig
// 连接池: 小规模
.min_size = 2,
.max_size = 10,

// 限流: 宽松
.ip_limit = 1000,

// 日志: 详细
.level = .debug,
.enable_sampling = false,
```

### 测试环境
```zig
// 连接池: 中等规模
.min_size = 5,
.max_size = 20,

// 限流: 中等
.ip_limit = 200,

// 日志: 适中
.level = .info,
.enable_sampling = true,
.sample_rate = 5,
```

### 生产环境
```zig
// 连接池: 大规模
.min_size = 10,
.max_size = 50,

// 限流: 严格
.ip_limit = 100,

// 日志: 精简
.level = .info,
.enable_sampling = true,
.sample_rate = 10,
```

---

## 故障排查

### 问题 1: 连接池扩容不及时
**症状**: 高峰期响应慢
**排查**: 检查 `scale_up_threshold` 是否过高
**解决**: 降低阈值到 0.7 或 0.6

### 问题 2: 缓存预热失败
**症状**: 启动后首次访问仍然慢
**排查**: 检查日志中的预热错误
**解决**: 确保数据库连接正常，数据存在

### 问题 3: 限流误伤正常用户
**症状**: 用户反馈请求被拒绝
**排查**: 检查限流配置是否过严
**解决**: 适当提高限流阈值或添加白名单

### 问题 4: 日志丢失重要信息
**症状**: 无法追踪问题
**排查**: 检查日志级别和采样率
**解决**: 降低采样率或提高日志级别

---

## 后续优化建议

1. **连接池**: 考虑引入连接健康检查
2. **缓存**: 考虑引入缓存失效通知机制
3. **限流**: 考虑引入分布式限流（Redis）
4. **日志**: 考虑引入日志聚合平台（ELK）

---

**实施人**: 开发团队
**实施日期**: 2026-03-05
**预计完成**: 2026-03-12
