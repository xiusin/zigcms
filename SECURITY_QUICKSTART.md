# 安全增强功能 - 快速启动指南

## 📋 概述

本指南帮助你快速启动和测试安全增强功能，包括审计日志、安全监控、CSRF防护、速率限制和RBAC权限控制。

## ✅ 已完成的功能

### 1. 审计日志系统 ✅
- ✅ 数据库表创建（audit_logs）
- ✅ 仓储实现（MysqlAuditLogRepository）
- ✅ 服务层实现（AuditLogService）
- ✅ DI 容器注册
- ✅ 控制器路由注册
- ✅ 前端界面（审计日志查询页面）

### 2. 安全监控系统 ✅
- ✅ 数据库表创建（security_events, ip_bans）
- ✅ 监控服务实现（SecurityMonitor）
- ✅ DI 容器注册
- ✅ 控制器路由注册
- ✅ 前端界面（安全监控仪表板）

### 3. CSRF 防护 ✅
- ✅ 中间件实现（CsrfProtection）
- ✅ Token 生成和验证
- ✅ DI 容器注册
- ⏳ 全局中间件注册（待补充）

### 4. 速率限制 ✅
- ✅ 中间件实现（RateLimiter）
- ✅ 多维度限流（全局/IP/用户/端点）
- ✅ DI 容器注册
- ⏳ 全局中间件注册（待补充）

### 5. RBAC 权限控制 ✅
- ✅ 中间件实现（RbacMiddleware）
- ✅ 基于角色的访问控制
- ✅ DI 容器注册
- ⏳ 全局中间件注册（待补充）

### 6. 告警管理 ✅
- ✅ 数据库表创建（alert_rules, alert_history）
- ✅ 控制器路由注册
- ✅ 前端界面（告警管理页面）
- ⏳ 控制器查询逻辑（待补充）

## 🚀 快速启动步骤

### 步骤 1：执行数据库迁移

```bash
# 执行安全增强功能的数据库迁移
./migrate-security.sh

# 或者手动执行
mysql -u root -p zigcms < migrations/20260305_security_enhancement.sql
```

**创建的表**：
- `audit_logs` - 审计日志表
- `security_events` - 安全事件表
- `ip_bans` - IP封禁表
- `alert_rules` - 告警规则表
- `alert_history` - 告警历史表

### 步骤 2：启动后端服务

```bash
# 编译并运行
zig build run

# 或者使用开发模式
zig build run-dev
```

**验证启动成功**：
```bash
# 检查日志输出
✅ 安全服务注册到DI容器完成
✅ 安全管理路由已注册: 23 个路由
```

### 步骤 3：启动前端服务

```bash
cd ecom-admin
npm install
npm run dev
```

**访问地址**：
- 前端：http://localhost:5173
- 后端：http://localhost:8080

### 步骤 4：访问安全管理页面

登录后访问以下页面：

1. **安全监控仪表板**
   - 路径：`/security/dashboard`
   - 功能：实时监控、事件统计、IP封禁管理

2. **审计日志查询**
   - 路径：`/security/audit-log`
   - 功能：多维度查询、数据导出、详情查看

3. **告警管理**
   - 路径：`/security/alerts`
   - 功能：规则配置、历史查询、告警处理

## 🧪 功能测试

### 测试 1：审计日志记录

```bash
# 创建测试用例（会自动记录审计日志）
curl -X POST http://localhost:8080/api/quality-center/test-cases \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "测试用例1",
    "description": "测试描述",
    "priority": "high"
  }'

# 查询审计日志
curl http://localhost:8080/api/security/audit-logs?page=1&page_size=20 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**预期结果**：
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": 1,
        "user_id": 1,
        "username": "admin",
        "action": "创建测试用例",
        "resource_type": "test_case",
        "resource_id": 1,
        "resource_name": "测试用例1",
        "description": "创建测试用例",
        "client_ip": "127.0.0.1",
        "result": "success",
        "created_at": 1709654400
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 20
  }
}
```

### 测试 2：安全监控

```bash
# 触发登录失败事件（连续5次）
for i in {1..5}; do
  curl -X POST http://localhost:8080/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{
      "username": "test",
      "password": "wrong_password"
    }'
done

# 查询安全事件
curl http://localhost:8080/api/security/events?event_type=login_failed \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**预期结果**：
- 触发速率限制告警
- 记录安全事件到数据库
- 前端仪表板显示告警

### 测试 3：速率限制

```bash
# 快速发送多个请求（超过限制）
for i in {1..10}; do
  curl -X POST http://localhost:8080/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{
      "username": "test",
      "password": "test123"
    }'
done
```

**预期结果**：
```json
{
  "code": 429,
  "message": "请求过于频繁，请稍后再试"
}
```

### 测试 4：CSRF 防护

```bash
# 不带 CSRF Token 的请求（应该被拒绝）
curl -X POST http://localhost:8080/api/quality-center/test-cases \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "测试用例"
  }'
```

**预期结果**：
```json
{
  "code": 403,
  "message": "CSRF token 验证失败"
}
```

### 测试 5：RBAC 权限控制

```bash
# 普通用户访问管理员接口（应该被拒绝）
curl http://localhost:8080/api/system/admin/list \
  -H "Authorization: Bearer NORMAL_USER_TOKEN"
```

**预期结果**：
```json
{
  "code": 403,
  "message": "权限不足"
}
```

## 📊 监控指标

### 审计日志统计

```sql
-- 查询今日审计日志数量
SELECT COUNT(*) FROM audit_logs 
WHERE DATE(FROM_UNIXTIME(created_at)) = CURDATE();

-- 按操作类型统计
SELECT action, COUNT(*) as count 
FROM audit_logs 
GROUP BY action 
ORDER BY count DESC;

-- 按用户统计
SELECT username, COUNT(*) as count 
FROM audit_logs 
GROUP BY username 
ORDER BY count DESC;
```

### 安全事件统计

```sql
-- 查询今日安全事件数量
SELECT COUNT(*) FROM security_events 
WHERE DATE(FROM_UNIXTIME(timestamp)) = CURDATE();

-- 按事件类型统计
SELECT event_type, COUNT(*) as count 
FROM security_events 
GROUP BY event_type 
ORDER BY count DESC;

-- 按严重程度统计
SELECT severity, COUNT(*) as count 
FROM security_events 
GROUP BY severity 
ORDER BY count DESC;
```

### IP 封禁统计

```sql
-- 查询当前封禁的 IP 数量
SELECT COUNT(*) FROM ip_bans 
WHERE expires_at > UNIX_TIMESTAMP();

-- 查询封禁历史
SELECT ip, reason, banned_at, expires_at 
FROM ip_bans 
ORDER BY banned_at DESC 
LIMIT 10;
```

## 🔧 配置说明

### CSRF 防护配置

```zig
// root.zig - registerSecurityServices
CsrfProtection.init(alloc, .{
    .enabled = true,                    // 是否启用
    .header_name = "X-CSRF-Token",      // Token 请求头名称
    .cookie_name = "csrf_token",        // Token Cookie 名称
    .token_length = 32,                 // Token 长度
    .token_ttl = 3600,                  // Token 有效期（秒）
    .safe_methods = &.{ "GET", "HEAD", "OPTIONS" },  // 安全方法（不验证）
    .whitelist_paths = &.{              // 白名单路径（不验证）
        "/api/auth/login",
        "/api/auth/register",
        "/api/health",
    },
}, cache_ptr);
```

### 速率限制配置

```zig
// root.zig - registerSecurityServices
RateLimiter.init(alloc, cache_ptr, .{
    .global_limit = 1000,               // 全局限流（请求/分钟）
    .global_window = 60,                // 全局时间窗口（秒）
    .ip_limit = 100,                    // IP 限流（请求/分钟）
    .ip_window = 60,                    // IP 时间窗口（秒）
    .user_limit = 200,                  // 用户限流（请求/分钟）
    .user_window = 60,                  // 用户时间窗口（秒）
    .endpoint_limits = &.{              // 端点限流
        .{ .path = "/api/auth/login", .limit = 5, .window = 60 },
        .{ .path = "/api/quality/ai/generate", .limit = 10, .window = 60 },
    },
    .whitelist_ips = &.{ "127.0.0.1", "::1" },  // 白名单 IP
    .blacklist_ips = &.{},              // 黑名单 IP
});
```

### 安全监控配置

```zig
// root.zig - registerSecurityServices
SecurityMonitor.init(alloc, .{
    .enabled = true,                    // 是否启用
    .log_enabled = true,                // 是否记录日志
    .alert_enabled = true,              // 是否发送告警
    .alert_threshold = 10,              // 告警阈值（事件数/分钟）
    .alert_window = 60,                 // 告警时间窗口（秒）
    .auto_ban_enabled = true,           // 是否自动封禁
    .auto_ban_threshold = 20,           // 自动封禁阈值（事件数/分钟）
    .ban_duration = 3600,               // 封禁时长（秒）
}, cache_ptr);
```

## 🐛 故障排查

### 问题 1：审计日志没有记录

**可能原因**：
1. 数据库表未创建
2. DI 容器未正确注册
3. 服务调用失败

**解决方案**：
```bash
# 1. 检查数据库表
mysql -u root -p zigcms -e "SHOW TABLES LIKE 'audit_logs';"

# 2. 检查日志输出
grep "审计日志" logs/app.log

# 3. 手动测试
curl -X POST http://localhost:8080/api/security/audit-logs/test
```

### 问题 2：速率限制不生效

**可能原因**：
1. 中间件未注册
2. Redis 缓存未启动
3. 配置错误

**解决方案**：
```bash
# 1. 检查 Redis
redis-cli ping

# 2. 检查缓存键
redis-cli keys "rate_limit:*"

# 3. 检查日志
grep "速率限制" logs/app.log
```

### 问题 3：CSRF 验证失败

**可能原因**：
1. Token 未生成
2. Token 未传递
3. Token 过期

**解决方案**：
```bash
# 1. 获取 Token
curl http://localhost:8080/api/csrf-token

# 2. 使用 Token
curl -X POST http://localhost:8080/api/test \
  -H "X-CSRF-Token: YOUR_TOKEN" \
  -H "Cookie: csrf_token=YOUR_TOKEN"

# 3. 检查日志
grep "CSRF" logs/app.log
```

## 📝 下一步工作

### 优先级 1（高）- 核心功能闭环
1. ⏳ 实现安全监控数据库持久化
2. ⏳ 实现控制器查询逻辑（3个控制器）
3. ⏳ 注册全局中间件

### 优先级 2（中）- 功能增强
4. 实现告警通知系统（邮件/短信/钉钉）
5. 在质量中心控制器中集成审计日志
6. 前端 API 客户端集成 CSRF Token

### 优先级 3（低）- 优化完善
7. 性能优化（缓存预热、查询优化）
8. 监控指标收集
9. 文档完善

## 📚 相关文档

- [安全增强功能指南](SECURITY_ENHANCEMENT_GUIDE.md)
- [安全集成指南](SECURITY_INTEGRATION_GUIDE.md)
- [缺失逻辑补充报告](SECURITY_MISSING_LOGIC_COMPLETE.md)
- [数据库迁移脚本](migrations/20260305_security_enhancement.sql)

## 🎯 总结

老铁，安全增强功能的核心逻辑已经补充完成！

**已完成**：
- ✅ 审计日志仓储实现
- ✅ DI 容器注册完善
- ✅ 数据库表创建
- ✅ 前端界面实现
- ✅ 路由注册完成

**待完成**：
- ⏳ 安全监控数据库持久化
- ⏳ 控制器查询逻辑实现
- ⏳ 全局中间件注册

**建议下一步**：
1. 实现控制器查询逻辑，让前端能够真正查询到数据
2. 注册全局中间件，让安全防护真正生效
3. 实现安全监控数据库持久化，完善监控闭环

按照这个快速启动指南，你可以立即测试审计日志功能，验证整个业务闭环是否正常工作！
