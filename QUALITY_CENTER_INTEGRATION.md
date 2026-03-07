# 质量中心完整集成方案

## 概述

本文档描述质量中心功能的完整集成方案，包括后端集成、前端集成和告警系统实现。

## 1. 后端集成（优先级：高）

### 1.1 DI 容器注册 (root.zig)

需要在 `root.zig` 中注册质量中心相关服务：

```zig
// 注册质量中心服务
fn registerQualityCenterServices(container: *DIContainer, allocator: Allocator, db: *Database) !void {
    // 1. 注册仓储
    try registerQualityCenterRepositories(container, allocator, db);
    
    // 2. 注册服务
    try registerQualityCenterApplicationServices(container, allocator);
    
    // 3. 注册控制器
    try registerQualityCenterControllers(container, allocator);
}
```

### 1.2 中间件注册 (bootstrap.zig)

需要在 `src/api/bootstrap.zig` 中注册中间件：

```zig
// 注册质量中心中间件
fn registerQualityCenterMiddleware(self: *Self) !void {
    // 1. CSRF 保护
    try self.app.use(csrf_protection.middleware);
    
    // 2. RBAC 权限检查
    try self.app.use(rbac.middleware);
    
    // 3. 速率限制
    try self.app.use(rate_limiter.middleware);
    
    // 4. 审计日志
    try self.app.use(audit_log.middleware);
}
```

### 1.3 路由注册

需要在 `src/api/bootstrap.zig` 中注册质量中心路由：

```zig
// 注册质量中心路由
fn registerQualityCenterRoutes(self: *Self) !void {
    const prefix = "/api/quality";
    
    // 测试用例路由
    try self.app.route("POST", prefix ++ "/test-cases", test_case_controller.create);
    try self.app.route("GET", prefix ++ "/test-cases/:id", test_case_controller.get);
    // ... 更多路由
}
```

## 2. 前端集成（优先级：高）

### 2.1 CSRF Token 集成 (request.ts)

需要在 `ecom-admin/src/utils/request.ts` 中集成 CSRF Token：

```typescript
// 请求拦截器
request.interceptors.request.use((config) => {
  // 添加 CSRF Token
  const csrfToken = getCsrfToken();
  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken;
  }
  
  return config;
});
```

### 2.2 路由注册

需要在主路由文件中注册质量中心路由：

```typescript
// ecom-admin/src/router/index.ts
import qualityCenterRoutes from './routes/modules/quality-center';

const routes = [
  // ... 其他路由
  ...qualityCenterRoutes,
];
```

### 2.3 菜单配置

需要在菜单配置文件中添加质量中心菜单：

```typescript
// ecom-admin/src/config/menu.ts
export const menuConfig = [
  {
    name: 'quality-center',
    title: '质量中心',
    icon: 'icon-check-circle',
    children: [
      { name: 'test-case', title: '测试用例' },
      { name: 'project', title: '项目管理' },
      // ... 更多菜单项
    ],
  },
];
```

## 3. 告警系统实现（优先级：低）

### 3.1 邮件告警

**实现文件**：`src/infrastructure/notification/email_notifier.zig`

**功能**：
- SMTP 邮件发送
- 邮件模板支持
- 异步发送队列
- 发送失败重试

### 3.2 短信告警

**实现文件**：`src/infrastructure/notification/sms_notifier.zig`

**功能**：
- 短信服务商集成（阿里云、腾讯云）
- 短信模板管理
- 发送限流
- 发送记录

### 3.3 钉钉/企业微信告警

**实现文件**：`src/infrastructure/notification/dingtalk_notifier.zig`

**功能**：
- Webhook 集成
- 消息格式化
- @指定人员
- 消息卡片支持

## 4. 现有功能检查

### 4.1 已存在的功能

✅ **邮箱值对象**：`src/domain/entities/value_objects/email.zig`
✅ **安全监控**：`src/infrastructure/security/security_monitor.zig`
✅ **审计日志**：`src/infrastructure/security/audit_log.zig`
✅ **RBAC 中间件**：`src/api/middleware/rbac.zig`
✅ **CSRF 保护**：`src/api/middleware/csrf_protection.zig`
✅ **速率限制**：`src/api/middleware/rate_limiter.zig`

### 4.2 需要新增的功能

🔲 **邮件通知服务**
🔲 **短信通知服务**
🔲 **钉钉/企业微信通知服务**
🔲 **统一通知接口**
🔲 **通知模板管理**

## 5. 实现优先级

### 高优先级（立即实现）
1. DI 容器注册
2. 中间件注册
3. 路由注册
4. 前端 CSRF Token 集成
5. 前端路由和菜单配置

### 中优先级（本周完成）
1. 邮件告警系统
2. 统一通知接口

### 低优先级（后续迭代）
1. 短信告警系统
2. 钉钉/企业微信告警系统
3. 通知模板管理

## 6. 实施步骤

### 步骤 1：后端集成
1. 创建质量中心服务注册函数
2. 在 root.zig 中调用注册函数
3. 在 bootstrap.zig 中注册中间件和路由
4. 测试后端 API

### 步骤 2：前端集成
1. 更新 request.ts 添加 CSRF Token
2. 注册质量中心路由
3. 配置质量中心菜单
4. 测试前端页面

### 步骤 3：告警系统
1. 实现邮件通知服务
2. 实现统一通知接口
3. 集成到质量中心业务流程
4. 测试告警功能

---

## 附录：代码示例

### A. DI 容器注册示例

```zig
// root.zig
fn registerQualityCenterServices(container: *DIContainer, allocator: Allocator, db: *Database) !void {
    // 注册测试用例仓储
    const test_case_repo = try allocator.create(MysqlTestCaseRepository);
    test_case_repo.* = MysqlTestCaseRepository.init(allocator, db);
    try container.registerInstance(TestCaseRepository, test_case_repo, null);
    
    // 注册测试用例服务
    try container.registerSingleton(TestCaseService, TestCaseService, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*TestCaseService {
            const repo = try di.resolve(TestCaseRepository);
            const cache = try di.resolve(CacheInterface);
            
            const service = try alloc.create(TestCaseService);
            service.* = TestCaseService.init(alloc, repo.*, cache);
            return service;
        }
    }.factory, null);
}
```

### B. 中间件注册示例

```zig
// src/api/bootstrap.zig
fn registerMiddleware(self: *Self) !void {
    // CSRF 保护
    const csrf = try self.container.resolve(CsrfProtection);
    try self.app.use(csrf.middleware);
    
    // RBAC 权限检查
    const rbac = try self.container.resolve(RbacMiddleware);
    try self.app.use(rbac.middleware);
}
```

### C. 前端 CSRF Token 示例

```typescript
// ecom-admin/src/utils/request.ts
import Cookies from 'js-cookie';

const getCsrfToken = (): string | undefined => {
  return Cookies.get('csrf_token');
};

request.interceptors.request.use((config) => {
  const csrfToken = getCsrfToken();
  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken;
  }
  return config;
});
```

---

**文档版本**：v1.0
**最后更新**：2026-03-06
**维护人员**：开发团队
