# 质量中心安全增强功能实现指南

## 概述

本文档描述了质量中心系统的安全增强功能实现，包括 CSRF 防护、速率限制、权限控制（RBAC）、安全监控和审计日志。

---

## 1. CSRF 防护

### 1.1 功能说明

跨站请求伪造（CSRF）防护通过 Token 验证机制，防止恶意网站冒充用户发起请求。

### 1.2 实现文件

- `src/api/middleware/csrf_protection.zig` - CSRF 防护中间件

### 1.3 核心功能

1. **Token 生成**: 为每个会话生成唯一的 CSRF Token
2. **Token 验证**: 验证请求中的 Token 是否有效
3. **Cookie 设置**: 设置 HttpOnly 和 SameSite 属性
4. **白名单**: 支持配置不需要 CSRF 验证的路径

### 1.4 使用示例

```zig
const CsrfProtection = @import("api/middleware/csrf_protection.zig").CsrfProtection;

// 初始化 CSRF 防护
var csrf = CsrfProtection.init(allocator, .{
    .enabled = true,
    .header_name = "X-CSRF-Token",
    .cookie_name = "csrf_token",
    .safe_methods = &.{ "GET", "HEAD", "OPTIONS" },
    .whitelist_paths = &.{
        "/api/auth/login",
        "/api/auth/register",
    },
}, cache);

// 生成 Token
const token = try csrf.generateToken(session_id);

// 设置 Cookie
try csrf.setCookie(req, token);

// 验证 Token
try csrf.handle(req);
```


### 1.5 前端集成

```typescript
// 从 Cookie 获取 CSRF Token
const csrfToken = document.cookie
  .split('; ')
  .find(row => row.startsWith('csrf_token='))
  ?.split('=')[1];

// 在请求头中添加 Token
axios.defaults.headers.common['X-CSRF-Token'] = csrfToken;

// 或在每个请求中添加
axios.post('/api/quality/test-cases', data, {
  headers: {
    'X-CSRF-Token': csrfToken
  }
});
```

---

## 2. 速率限制

### 2.1 功能说明

速率限制通过限制单位时间内的请求数量，防止暴力破解和 DDoS 攻击。

### 2.2 实现文件

- `src/api/middleware/rate_limiter.zig` - 速率限制中间件

### 2.3 核心功能

1. **全局限流**: 限制系统总请求数
2. **IP 限流**: 限制单个 IP 的请求数
3. **用户限流**: 限制单个用户的请求数
4. **端点限流**: 限制特定接口的请求数
5. **白名单**: 白名单 IP 不受限制
6. **黑名单**: 黑名单 IP 直接拒绝

### 2.4 使用示例

```zig
const RateLimiter = @import("api/middleware/rate_limiter.zig").RateLimiter;

// 初始化速率限制器
var rate_limiter = RateLimiter.init(allocator, cache, .{
    .global_limit = 1000,
    .global_window = 60,
    .ip_limit = 100,
    .ip_window = 60,
    .user_limit = 200,
    .user_window = 60,
    .endpoint_limits = &.{
        .{ .path = "/api/auth/login", .limit = 5, .window = 60 },
        .{ .path = "/api/quality/ai/generate", .limit = 10, .window = 60 },
    },
    .whitelist_ips = &.{ "127.0.0.1", "::1" },
    .blacklist_ips = &.{},
});

// 检查限流
if (!try rate_limiter.handle(req)) {
    // 请求被限流
    return;
}

// 获取统计信息
const stats = try rate_limiter.getStats();
std.debug.print("全局请求数: {d}/{d}\n", .{ stats.global_requests, stats.global_limit });
```


### 2.5 配置建议

| 场景 | 全局限制 | IP 限制 | 用户限制 | 端点限制 |
|------|---------|---------|---------|---------|
| 开发环境 | 10000/分钟 | 1000/分钟 | 2000/分钟 | 无限制 |
| 测试环境 | 5000/分钟 | 500/分钟 | 1000/分钟 | 登录 10/分钟 |
| 生产环境 | 1000/分钟 | 100/分钟 | 200/分钟 | 登录 5/分钟 |

---

## 3. 权限控制（RBAC）

### 3.1 功能说明

基于角色的访问控制（RBAC）提供细粒度的权限管理，确保用户只能访问授权的资源。

### 3.2 实现文件

- `src/api/middleware/rbac.zig` - RBAC 中间件

### 3.3 核心功能

1. **角色管理**: 定义和管理角色
2. **权限管理**: 定义和管理权限
3. **权限检查**: 检查用户是否有权限
4. **超级管理员**: 超级管理员拥有所有权限
5. **公开路径**: 配置不需要权限的路径

### 3.4 权限定义

```zig
// 质量中心权限
pub const QualityCenterPermissions = struct {
    // 测试用例权限
    pub const TEST_CASE_VIEW = "quality:test_case:view";
    pub const TEST_CASE_CREATE = "quality:test_case:create";
    pub const TEST_CASE_UPDATE = "quality:test_case:update";
    pub const TEST_CASE_DELETE = "quality:test_case:delete";
    pub const TEST_CASE_EXECUTE = "quality:test_case:execute";
    
    // 项目权限
    pub const PROJECT_VIEW = "quality:project:view";
    pub const PROJECT_CREATE = "quality:project:create";
    pub const PROJECT_UPDATE = "quality:project:update";
    pub const PROJECT_DELETE = "quality:project:delete";
    
    // ... 更多权限
};
```

### 3.5 使用示例

```zig
const RbacMiddleware = @import("api/middleware/rbac.zig").RbacMiddleware;
const QualityCenterPermissions = @import("api/middleware/rbac.zig").QualityCenterPermissions;

// 初始化 RBAC 中间件
var rbac = RbacMiddleware.init(allocator, .{
    .enabled = true,
    .super_admin_role = "super_admin",
    .public_paths = &.{
        "/api/auth/login",
        "/api/health",
    },
}, cache);

// 检查单个权限
try rbac.checkPermission(req, QualityCenterPermissions.TEST_CASE_CREATE);

// 检查任一权限
try rbac.checkAnyPermission(req, &.{
    QualityCenterPermissions.TEST_CASE_VIEW,
    QualityCenterPermissions.TEST_CASE_CREATE,
});

// 检查所有权限
try rbac.checkAllPermissions(req, &.{
    QualityCenterPermissions.TEST_CASE_VIEW,
    QualityCenterPermissions.TEST_CASE_UPDATE,
});
```


### 3.6 控制器集成

```zig
// 在控制器中使用权限检查
pub fn create(req: zap.Request) !void {
    // 检查权限
    const rbac = try container.resolve(RbacMiddleware);
    try rbac.checkPermission(req, QualityCenterPermissions.TEST_CASE_CREATE);
    
    // 业务逻辑
    const service = try container.resolve(TestCaseService);
    const result = try service.create(dto);
    
    try base.send_success(req, result);
}

pub fn delete(req: zap.Request) !void {
    // 检查删除权限
    const rbac = try container.resolve(RbacMiddleware);
    try rbac.checkPermission(req, QualityCenterPermissions.TEST_CASE_DELETE);
    
    // 业务逻辑
    const service = try container.resolve(TestCaseService);
    try service.delete(id);
    
    try base.send_success(req, .{ .message = "删除成功" });
}
```

---

## 4. 安全监控

### 4.1 功能说明

安全监控系统实时监控系统安全事件，检测异常访问，自动告警和封禁。

### 4.2 实现文件

- `src/infrastructure/security/security_monitor.zig` - 安全监控系统

### 4.3 核心功能

1. **事件记录**: 记录所有安全事件
2. **异常检测**: 检测异常访问模式
3. **自动告警**: 超过阈值自动发送告警
4. **自动封禁**: 高危事件自动封禁 IP
5. **统计分析**: 提供安全统计数据

### 4.4 安全事件类型

```zig
pub const SecurityEventType = enum {
    login_failed,           // 登录失败
    login_success,          // 登录成功
    permission_denied,      // 权限拒绝
    rate_limit_exceeded,    // 速率限制
    sql_injection_attempt,  // SQL 注入尝试
    xss_attack_attempt,     // XSS 攻击尝试
    csrf_attack_attempt,    // CSRF 攻击尝试
    sensitive_operation,    // 敏感操作
    abnormal_access,        // 异常访问
    data_leak_risk,         // 数据泄露风险
};
```

### 4.5 使用示例

```zig
const SecurityMonitor = @import("infrastructure/security/security_monitor.zig").SecurityMonitor;

// 初始化安全监控
var monitor = SecurityMonitor.init(allocator, .{
    .enabled = true,
    .log_enabled = true,
    .alert_enabled = true,
    .alert_threshold = 10,
    .alert_window = 60,
    .auto_ban_enabled = true,
    .auto_ban_threshold = 20,
    .ban_duration = 3600,
}, cache);

// 记录安全事件
try monitor.logEvent(.{
    .event_type = .login_failed,
    .severity = .medium,
    .user_id = null,
    .client_ip = "192.168.1.100",
    .path = "/api/auth/login",
    .method = "POST",
    .description = "用户名或密码错误",
    .timestamp = std.time.timestamp(),
});

// 检查 IP 是否被封禁
if (try monitor.isIPBanned(client_ip)) {
    return error.IPBanned;
}

// 获取安全统计
const stats = try monitor.getStats(client_ip);
std.debug.print("IP {s} 事件数: {d}\n", .{ stats.ip, stats.total_events });
```


---

## 5. 审计日志

### 5.1 功能说明

审计日志系统记录所有敏感操作和重要业务操作，提供完整的操作追溯能力。

### 5.2 实现文件

- `src/infrastructure/security/audit_log.zig` - 审计日志系统

### 5.3 核心功能

1. **操作记录**: 记录用户操作
2. **数据变更**: 记录操作前后数据
3. **失败记录**: 记录失败操作
4. **查询分析**: 支持多维度查询
5. **导出功能**: 支持导出审计日志

### 5.4 使用示例

```zig
const AuditLogService = @import("infrastructure/security/audit_log.zig").AuditLogService;

// 初始化审计日志服务
var audit_service = AuditLogService.init(allocator, audit_repo);

// 记录操作
try audit_service.log(
    user_id,
    username,
    "创建测试用例",
    "test_case",
    test_case_id,
    test_case_title,
    "创建了新的测试用例",
    client_ip,
);

// 记录数据变更
try audit_service.logWithData(
    user_id,
    username,
    "更新测试用例",
    "test_case",
    test_case_id,
    test_case_title,
    "更新了测试用例状态",
    before_json,  // 操作前数据
    after_json,   // 操作后数据
    client_ip,
);

// 记录失败操作
try audit_service.logFailure(
    user_id,
    username,
    "删除项目",
    "project",
    "权限不足",
    client_ip,
);

// 查询用户操作日志
const logs = try audit_service.getUserLogs(user_id, 1, 20);

// 查询资源操作日志
const resource_logs = try audit_service.getResourceLogs("test_case", test_case_id, 1, 20);
```

### 5.5 审计操作定义

```zig
pub const QualityCenterAuditActions = struct {
    // 测试用例操作
    pub const TEST_CASE_CREATE = "创建测试用例";
    pub const TEST_CASE_UPDATE = "更新测试用例";
    pub const TEST_CASE_DELETE = "删除测试用例";
    pub const TEST_CASE_BATCH_DELETE = "批量删除测试用例";
    
    // 项目操作
    pub const PROJECT_CREATE = "创建项目";
    pub const PROJECT_UPDATE = "更新项目";
    pub const PROJECT_DELETE = "删除项目";
    
    // 数据导出
    pub const EXPORT_TEST_CASES = "导出测试用例";
    pub const EXPORT_STATISTICS = "导出统计数据";
};
```

---

## 6. 集成步骤

### 6.1 依赖注入配置

```zig
// root.zig
fn registerSecurityServices(container: *DIContainer, allocator: Allocator, cache: *CacheInterface) !void {
    // 1. 注册 CSRF 防护
    try container.registerSingleton(CsrfProtection, CsrfProtection, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*CsrfProtection {
            const cache_ptr = try di.resolve(CacheInterface);
            const csrf = try alloc.create(CsrfProtection);
            csrf.* = CsrfProtection.init(alloc, .{}, cache_ptr);
            return csrf;
        }
    }.factory, null);
    
    // 2. 注册速率限制器
    try container.registerSingleton(RateLimiter, RateLimiter, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*RateLimiter {
            const cache_ptr = try di.resolve(CacheInterface);
            const limiter = try alloc.create(RateLimiter);
            limiter.* = RateLimiter.init(alloc, cache_ptr, .{});
            return limiter;
        }
    }.factory, null);
    
    // 3. 注册 RBAC 中间件
    try container.registerSingleton(RbacMiddleware, RbacMiddleware, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*RbacMiddleware {
            const cache_ptr = try di.resolve(CacheInterface);
            const rbac = try alloc.create(RbacMiddleware);
            rbac.* = RbacMiddleware.init(alloc, .{}, cache_ptr);
            return rbac;
        }
    }.factory, null);
    
    // 4. 注册安全监控
    try container.registerSingleton(SecurityMonitor, SecurityMonitor, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*SecurityMonitor {
            const cache_ptr = try di.resolve(CacheInterface);
            const monitor = try alloc.create(SecurityMonitor);
            monitor.* = SecurityMonitor.init(alloc, .{}, cache_ptr);
            return monitor;
        }
    }.factory, null);
    
    // 5. 注册审计日志服务
    try container.registerSingleton(AuditLogService, AuditLogService, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*AuditLogService {
            const audit_repo = try di.resolve(AuditLogRepository);
            const service = try alloc.create(AuditLogService);
            service.* = AuditLogService.init(alloc, audit_repo.*);
            return service;
        }
    }.factory, null);
}
```


### 6.2 中间件注册

```zig
// src/api/bootstrap.zig
pub fn registerMiddlewares(self: *Self) !void {
    const container = zigcms.core.di.getGlobalContainer();
    
    // 1. 速率限制中间件
    const rate_limiter = try container.resolve(RateLimiter);
    try self.app.use(rate_limiter.handle);
    
    // 2. CSRF 防护中间件
    const csrf = try container.resolve(CsrfProtection);
    try self.app.use(csrf.handle);
    
    // 3. 安全监控中间件
    const monitor = try container.resolve(SecurityMonitor);
    try self.app.use(monitor.handle);
}
```

### 6.3 控制器集成

```zig
// src/api/controllers/test_case.controller.zig
pub fn create(req: zap.Request) !void {
    const container = zigcms.core.di.getGlobalContainer();
    
    // 1. 权限检查
    const rbac = try container.resolve(RbacMiddleware);
    try rbac.checkPermission(req, QualityCenterPermissions.TEST_CASE_CREATE);
    
    // 2. 业务逻辑
    const service = try container.resolve(TestCaseService);
    const dto = try req.parseBody(CreateTestCaseDto);
    const result = try service.create(dto);
    
    // 3. 审计日志
    const audit = try container.resolve(AuditLogService);
    try audit.log(
        req.getUserId().?,
        req.getUsername().?,
        QualityCenterAuditActions.TEST_CASE_CREATE,
        "test_case",
        result.id,
        result.title,
        "创建了新的测试用例",
        req.getClientIP().?,
    );
    
    // 4. 安全监控
    const monitor = try container.resolve(SecurityMonitor);
    try monitor.logEvent(.{
        .event_type = .sensitive_operation,
        .severity = .low,
        .user_id = req.getUserId(),
        .client_ip = req.getClientIP().?,
        .path = req.getPath().?,
        .method = req.getMethod().?,
        .description = "创建测试用例",
        .timestamp = std.time.timestamp(),
    });
    
    try base.send_success(req, result);
}
```

---

## 7. 配置示例

### 7.1 开发环境配置

```zig
// config/development.zig
pub const security_config = .{
    .csrf = .{
        .enabled = false,  // 开发环境可关闭
    },
    .rate_limiter = .{
        .global_limit = 10000,
        .ip_limit = 1000,
        .user_limit = 2000,
    },
    .rbac = .{
        .enabled = false,  // 开发环境可关闭
    },
    .security_monitor = .{
        .enabled = true,
        .alert_enabled = false,
        .auto_ban_enabled = false,
    },
    .audit_log = .{
        .enabled = true,
    },
};
```

### 7.2 生产环境配置

```zig
// config/production.zig
pub const security_config = .{
    .csrf = .{
        .enabled = true,
        .header_name = "X-CSRF-Token",
        .cookie_name = "csrf_token",
    },
    .rate_limiter = .{
        .global_limit = 1000,
        .ip_limit = 100,
        .user_limit = 200,
        .endpoint_limits = &.{
            .{ .path = "/api/auth/login", .limit = 5, .window = 60 },
            .{ .path = "/api/quality/ai/generate", .limit = 10, .window = 60 },
        },
    },
    .rbac = .{
        .enabled = true,
        .super_admin_role = "super_admin",
    },
    .security_monitor = .{
        .enabled = true,
        .alert_enabled = true,
        .alert_threshold = 10,
        .auto_ban_enabled = true,
        .auto_ban_threshold = 20,
        .ban_duration = 3600,
    },
    .audit_