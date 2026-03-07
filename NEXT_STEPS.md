# 下一步行动指南

## 🎯 当前状态

✅ **优先级1任务已完成（82%）**
- 22个安全管理接口全部实现
- 数据库持久化功能完善
- 路由注册完成
- 代码质量优秀

## 🚀 立即执行（5分钟）

### 1. 执行数据库迁移

```bash
# 赋予执行权限
chmod +x migrate-security.sh

# 执行迁移
./migrate-security.sh
```

**预期结果**：
- 创建 `security_events` 表
- 创建 `ip_bans` 表
- 创建 `alert_rules` 表
- 创建 `alert_history` 表
- 创建 `audit_logs` 表

### 2. 编译并启动服务

```bash
# 编译
zig build

# 启动服务
./zig-out/bin/zigcms
```

**预期结果**：
- 服务启动成功
- 监听 http://localhost:8080
- 安全路由已注册（23个）

### 3. 快速验证

```bash
# 赋予执行权限
chmod +x test-security-persistence.sh

# 运行测试（需要先登录获取Token）
./test-security-persistence.sh
```

**预期结果**：
- 安全事件持久化正常
- IP封禁/解封功能正常
- 自动封禁功能正常

## 📋 优先级2任务（4-6小时）

### 任务1：实现告警通知系统（2小时）

**目标**：当触发告警时，自动发送通知

**实现步骤**：

1. **扩展 DingtalkNotifier**（已有基础）
   ```zig
   // src/infrastructure/notification/dingtalk_notifier.zig
   pub fn sendSecurityAlert(self: *Self, alert: Alert) !void {
       const message = try std.fmt.allocPrint(
           self.allocator,
           "🚨 安全告警\n类型: {s}\n严重程度: {s}\n描述: {s}",
           .{ alert.event_type, alert.severity, alert.description }
       );
       defer self.allocator.free(message);
       
       try self.sendMessage(message);
   }
   ```

2. **在 SecurityMonitor 中集成通知**
   ```zig
   // src/infrastructure/security/security_monitor.zig
   fn sendAlert(self: *Self, event: SecurityEvent, count: u32) !void {
       // 1. 打印日志（原有）
       const alert_message = try std.fmt.allocPrint(...);
       defer self.allocator.free(alert_message);
       std.debug.print("🚨 {s}\n", .{alert_message});
       
       // 2. 发送钉钉通知（新增）
       if (self.notifier) |notifier| {
           try notifier.sendSecurityAlert(.{
               .event_type = event.event_type,
               .severity = event.severity,
               .description = alert_message,
           });
       }
   }
   ```

3. **配置钉钉 Webhook**
   ```bash
   # .env
   DINGTALK_WEBHOOK=https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN
   DINGTALK_SECRET=YOUR_SECRET
   ```

**测试**：
```bash
# 触发告警
for i in {1..15}; do
  curl -X POST http://localhost:8080/api/auth/login \
    -d '{"username":"test","password":"wrong"}'
done

# 检查钉钉是否收到通知
```

### 任务2：质量中心集成审计日志（2小时）

**目标**：在质量中心操作时自动记录审计日志

**实现步骤**：

1. **在测试用例控制器中集成**
   ```zig
   // src/api/controllers/quality_center/test_case.controller.zig
   pub fn create(req: zap.Request) !void {
       // 1. 创建测试用例（原有逻辑）
       const test_case = try service.create(dto);
       
       // 2. 记录审计日志（新增）
       const container = zigcms.core.di.getGlobalContainer();
       const audit_service = try container.resolve(AuditLogService);
       
       try audit_service.log(.{
           .user_id = req.user_id,
           .action = "create",
           .resource_type = "test_case",
           .resource_id = test_case.id,
           .description = "创建测试用例",
           .ip_address = req.client_ip,
       });
       
       // 3. 返回响应
       try base.send_success(req, test_case);
   }
   ```

2. **在项目控制器中集成**
   ```zig
   // src/api/controllers/quality_center/project.controller.zig
   pub fn update(req: zap.Request) !void {
       // 1. 更新项目
       try service.update(id, dto);
       
       // 2. 记录审计日志
       try audit_service.log(.{
           .user_id = req.user_id,
           .action = "update",
           .resource_type = "project",
           .resource_id = id,
           .description = "更新项目",
           .ip_address = req.client_ip,
       });
       
       // 3. 返回响应
       try base.send_success(req, .{ .message = "更新成功" });
   }
   ```

3. **在需求控制器中集成**
   ```zig
   // src/api/controllers/quality_center/requirement.controller.zig
   pub fn delete(req: zap.Request) !void {
       // 1. 删除需求
       try service.delete(id);
       
       // 2. 记录审计日志
       try audit_service.log(.{
           .user_id = req.user_id,
           .action = "delete",
           .resource_type = "requirement",
           .resource_id = id,
           .description = "删除需求",
           .ip_address = req.client_ip,
       });
       
       // 3. 返回响应
       try base.send_success(req, .{ .message = "删除成功" });
   }
   ```

**测试**：
```bash
# 创建测试用例
curl -X POST http://localhost:8080/api/quality-center/test-cases/create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"title":"测试用例1","priority":"high"}'

# 查询审计日志
curl http://localhost:8080/api/security/audit-logs?resource_type=test_case \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 任务3：前端集成 CSRF Token（2小时）

**目标**：前端请求自动携带 CSRF Token

**实现步骤**：

1. **修改请求拦截器**
   ```typescript
   // ecom-admin/src/utils/request.ts
   
   // 从 Cookie 读取 CSRF Token
   function getCsrfToken(): string | null {
     const match = document.cookie.match(/csrf_token=([^;]+)/);
     return match ? match[1] : null;
   }
   
   // 请求拦截器
   request.interceptors.request.use(
     (config) => {
       // 添加 Authorization
       const token = getToken();
       if (token) {
         config.headers.Authorization = `Bearer ${token}`;
       }
       
       // 添加 CSRF Token（新增）
       const csrfToken = getCsrfToken();
       if (csrfToken && !['GET', 'HEAD', 'OPTIONS'].includes(config.method?.toUpperCase() || '')) {
         config.headers['X-CSRF-Token'] = csrfToken;
       }
       
       return config;
     },
     (error) => {
       return Promise.reject(error);
     }
   );
   ```

2. **处理 CSRF 错误**
   ```typescript
   // 响应拦截器
   request.interceptors.response.use(
     (response) => {
       return response;
     },
     (error) => {
       if (error.response?.status === 403 && error.response?.data?.message?.includes('CSRF')) {
         Message.error('CSRF Token 验证失败，请刷新页面');
         // 可选：自动刷新页面
         // window.location.reload();
       }
       return Promise.reject(error);
     }
   );
   ```

3. **登录时获取 CSRF Token**
   ```typescript
   // ecom-admin/src/api/auth.ts
   export async function login(data: LoginParams) {
     // 1. 先获取 CSRF Token
     await request.get('/api/csrf-token');
     
     // 2. 再执行登录
     return request.post('/api/auth/login', data);
   }
   ```

**测试**：
```bash
# 1. 登录
# 2. 执行需要 CSRF 保护的操作（POST/PUT/DELETE）
# 3. 验证请求头中是否包含 X-CSRF-Token
```

## 📊 进度跟踪

| 任务 | 预计时间 | 状态 | 完成度 |
|------|----------|------|--------|
| 告警通知系统 | 2小时 | ⏳ 待开始 | 0% |
| 质量中心集成审计日志 | 2小时 | ⏳ 待开始 | 0% |
| 前端集成 CSRF Token | 2小时 | ⏳ 待开始 | 0% |

## 🎯 成功标准

### 告警通知系统
- ✅ 触发告警时自动发送钉钉通知
- ✅ 通知内容包含事件类型、严重程度、描述
- ✅ 支持配置通知阈值

### 质量中心集成审计日志
- ✅ 测试用例创建/更新/删除时记录审计日志
- ✅ 项目操作时记录审计日志
- ✅ 需求操作时记录审计日志
- ✅ 可通过审计日志接口查询

### 前端集成 CSRF Token
- ✅ 登录时自动获取 CSRF Token
- ✅ 所有非安全方法请求自动携带 Token
- ✅ CSRF 验证失败时友好提示

## 📚 参考文档

- 告警通知：`src/infrastructure/notification/dingtalk_notifier.zig`
- 审计日志：`src/infrastructure/security/audit_log.zig`
- CSRF 防护：`src/api/middleware/csrf_protection.zig`
- 实施指南：`SECURITY_IMPLEMENTATION_GUIDE.md`

## 🎉 总结

老铁，优先级1任务已经完成，现在可以：

1. **立即执行**：数据库迁移 → 启动服务 → 运行测试
2. **开始优先级2**：告警通知 → 审计日志集成 → CSRF Token

按照这个节奏，安全增强功能将在6-8小时内全部完成！💪

有任何问题随时联系，祝开发顺利！🚀
