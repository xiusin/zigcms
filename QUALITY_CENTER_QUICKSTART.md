# 质量中心快速启动指南

## 前置条件

- Zig 0.13.0+
- MySQL 8.0+
- Node.js 18+
- Redis 6.0+（可选，用于缓存）

## 1. 数据库初始化

### 1.1 创建数据库

```bash
mysql -u root -p
```

```sql
CREATE DATABASE zigcms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE zigcms;
```

### 1.2 执行迁移

```bash
# 执行基础表结构迁移
mysql -u root -p zigcms < migrations/20260305_security_enhancement.sql

# 执行质量中心菜单迁移
mysql -u root -p zigcms < migrations/20260306_quality_center_menu.sql
```

### 1.3 验证数据

```sql
-- 验证菜单数据
SELECT 
    m1.id,
    m1.menu_name,
    m1.path,
    m1.component,
    m2.menu_name AS parent_name
FROM sys_menu m1
LEFT JOIN sys_menu m2 ON m1.parent_id = m2.id
WHERE m1.menu_name LIKE '%质量%' OR m2.menu_name LIKE '%质量%'
ORDER BY m1.parent_id, m1.sort;

-- 验证权限分配
SELECT 
    r.role_name,
    m.menu_name,
    m.path
FROM sys_role r
JOIN sys_role_menu rm ON r.id = rm.role_id
JOIN sys_menu m ON rm.menu_id = m.id
WHERE m.menu_name LIKE '%质量%'
ORDER BY r.id, m.sort;
```

## 2. 后端配置

### 2.1 配置数据库连接

编辑 `configs/infra.toml`:

```toml
[infra]
db_engine = "mysql"
db_host = "127.0.0.1"
db_port = 3306
db_name = "zigcms"
db_user = "root"
db_password = "your_password"
db_pool_size = 10
```

### 2.2 配置通知系统（可选）

复制配置模板：

```bash
cp configs/notification.toml.example configs/notification.toml
```

编辑 `configs/notification.toml`，填写实际配置：

```toml
[notification.email]
enabled = true
smtp_host = "smtp.example.com"
smtp_port = 587
username = "noreply@example.com"
password = "your_password"
from_address = "noreply@example.com"
from_name = "ZigCMS 质量中心"
```

或者使用环境变量：

```bash
export SMTP_HOST="smtp.example.com"
export SMTP_PORT="587"
export SMTP_USER="noreply@example.com"
export SMTP_PASSWORD="your_password"
```

### 2.3 编译和启动后端

```bash
# 编译
zig build

# 启动服务
zig build run
```

验证启动成功：

```bash
# 检查服务状态
curl http://localhost:8080/api/system/menu/list

# 检查质量中心路由
curl http://localhost:8080/api/quality-center/overview
```

## 3. 前端配置

### 3.1 安装依赖

```bash
cd ecom-admin
npm install
```

### 3.2 配置环境变量

编辑 `ecom-admin/.env.development`:

```env
VITE_NODE_ENV=development
VITE_API_BASE_URL=http://localhost:8080
```

### 3.3 启动前端开发服务器

```bash
npm run dev
```

访问 http://localhost:5173

## 4. 功能验证

### 4.1 登录系统

1. 访问 http://localhost:5173
2. 使用管理员账号登录（默认：admin/admin123）
3. 登录成功后应该能看到左侧菜单

### 4.2 验证质量中心菜单

1. 在左侧菜单中找到"质量中心"菜单项
2. 展开菜单，应该能看到以下子菜单：
   - 质量概览
   - 项目管理
   - 模块管理
   - 需求管理
   - 测试用例
   - 反馈管理
   - 思维导图

### 4.3 验证页面功能

#### 质量概览（Dashboard）

1. 点击"质量概览"菜单
2. 应该能看到：
   - 统计卡片（测试用例数、反馈数、Bug 数等）
   - 趋势图表
   - 模块质量分布
   - Bug 分布图
   - 反馈分布图

#### 项目管理

1. 点击"项目管理"菜单
2. 应该能看到项目列表
3. 测试功能：
   - 创建项目
   - 编辑项目
   - 删除项目
   - 查看项目详情

#### 反馈管理

1. 点击"反馈管理"菜单
2. 应该能看到反馈列表
3. 测试功能：
   - 创建反馈
   - 查看反馈详情
   - 添加跟进记录
   - 修改反馈状态
   - 批量操作

### 4.4 验证 CSRF 保护

打开浏览器开发者工具（F12），切换到 Network 标签：

1. 执行任意 POST 请求（如创建项目）
2. 查看请求头，应该包含 `X-CSRF-Token`
3. 如果缺少 CSRF token，请求应该被拒绝（403 Forbidden）

### 4.5 验证 JWT 认证

1. 退出登录
2. 尝试直接访问质量中心页面
3. 应该被重定向到登录页面
4. 登录后应该能正常访问

## 5. 通知系统测试（可选）

### 5.1 测试邮件通知

```bash
# 使用 curl 测试邮件发送
curl -X POST http://localhost:8080/api/quality-center/test-email \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "test@example.com",
    "subject": "测试邮件",
    "body": "这是一封测试邮件"
  }'
```

### 5.2 测试钉钉通知

```bash
# 使用 curl 测试钉钉通知
curl -X POST http://localhost:8080/api/quality-center/test-dingtalk \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "这是一条测试消息"
  }'
```

## 6. 常见问题

### 6.1 菜单不显示

**问题**: 登录后看不到"质量中心"菜单

**解决方案**:
1. 检查数据库中是否有菜单数据：
   ```sql
   SELECT * FROM sys_menu WHERE menu_name LIKE '%质量%';
   ```
2. 检查用户角色是否有菜单权限：
   ```sql
   SELECT * FROM sys_role_menu WHERE menu_id IN (
     SELECT id FROM sys_menu WHERE menu_name LIKE '%质量%'
   );
   ```
3. 清除浏览器缓存，重新登录

### 6.2 API 请求失败

**问题**: 前端调用 API 返回 404 或 500 错误

**解决方案**:
1. 检查后端服务是否正常运行：
   ```bash
   curl http://localhost:8080/api/quality-center/overview
   ```
2. 检查后端日志，查看错误信息
3. 验证路由是否正确注册：
   ```bash
   # 查看后端启动日志，应该显示路由统计
   ```

### 6.3 CSRF Token 错误

**问题**: POST 请求返回 403 Forbidden

**解决方案**:
1. 检查请求头是否包含 `X-CSRF-Token`
2. 检查 cookie 中是否有 `XSRF-TOKEN`
3. 清除浏览器缓存，重新登录

### 6.4 JWT Token 过期

**问题**: 请求返回 401 Unauthorized

**解决方案**:
1. 重新登录获取新的 JWT token
2. 检查 token 是否正确存储在 localStorage
3. 检查 token 是否正确添加到请求头

### 6.5 数据库连接失败

**问题**: 后端启动失败，提示数据库连接错误

**解决方案**:
1. 检查 MySQL 服务是否运行：
   ```bash
   systemctl status mysql
   ```
2. 检查数据库配置是否正确（`configs/infra.toml`）
3. 验证数据库用户权限：
   ```sql
   SHOW GRANTS FOR 'root'@'localhost';
   ```

## 7. 性能优化建议

### 7.1 数据库索引

为常用查询字段添加索引：

```sql
-- 反馈表索引
CREATE INDEX idx_feedback_status ON qc_feedback(status);
CREATE INDEX idx_feedback_severity ON qc_feedback(severity);
CREATE INDEX idx_feedback_created_at ON qc_feedback(created_at);

-- 测试用例表索引
CREATE INDEX idx_test_case_module_id ON qc_test_case(module_id);
CREATE INDEX idx_test_case_priority ON qc_test_case(priority);

-- 项目表索引
CREATE INDEX idx_project_status ON qc_project(status);
```

### 7.2 启用 Redis 缓存

编辑 `configs/infra.toml`:

```toml
[infra]
cache_enabled = true
cache_host = "127.0.0.1"
cache_port = 6379
cache_password = ""
cache_ttl = 300
```

### 7.3 前端构建优化

```bash
cd ecom-admin

# 生产构建
npm run build

# 分析构建产物
npm run build -- --report
```

## 8. 下一步

- [ ] 配置通知系统，实现自动告警
- [ ] 添加更多测试用例，提高代码覆盖率
- [ ] 配置 CI/CD 流程，实现自动化部署
- [ ] 添加监控和日志聚合
- [ ] 优化查询性能，添加缓存策略

## 9. 技术支持

如有问题，请查看以下资源：

- **集成文档**: `QUALITY_CENTER_INTEGRATION_COMPLETE.md`
- **API 文档**: `docs/api/quality-center.md`
- **前端文档**: `ecom-admin/README.md`
- **后端文档**: `README.md`

或联系开发团队获取支持。

---

老铁，祝你使用愉快！💪
