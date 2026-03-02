# OAuth 高级功能扩展文档

## 📋 功能概述

本文档记录 ZigCMS OAuth 模块的 4 个高级功能扩展：

1. ✅ **Token 刷新机制** - 自动续期访问令牌
2. ✅ **账户绑定功能** - 已登录用户绑定第三方账户
3. ✅ **审计日志系统** - 记录所有 OAuth 操作
4. ✅ **多提供商支持** - 微信、QQ、GitHub 等

---

## 1️⃣ Token 刷新机制

### 功能说明
使用 `refresh_token` 自动换取新的 `access_token`，避免用户频繁重新登录。

### 后端实现

#### API 接口
```
POST /api/oauth/refresh
Content-Type: application/json

{
  "provider": "feishu",
  "refresh_token": "rt-xxxxxxxxxxxxxxxx"
}
```

#### 响应示例
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "access_token": "at-xxxxxxxxxxxxxxxx",
    "refresh_token": "rt-yyyyyyyyyyyyyyyy",
    "expires_in": 7200
  }
}
```

#### 实现文件
- `src/api/controllers/oauth.controller.zig` - `refresh()` 方法
- `src/application/services/oauth/feishu_oauth.service.zig` - `refreshAccessToken()` 方法

### 前端集成

#### 自动刷新拦截器（建议）
```typescript
// ecom-admin/src/api/request.ts
import axios from 'axios';
import { refreshOAuthToken } from '@/api/oauth';

axios.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401) {
      const refreshToken = localStorage.getItem('oauth_refresh_token');
      const provider = localStorage.getItem('oauth_provider');
      
      if (refreshToken && provider) {
        try {
          const res = await refreshOAuthToken({ provider, refresh_token: refreshToken });
          localStorage.setItem('oauth_access_token', res.data.access_token);
          localStorage.setItem('oauth_refresh_token', res.data.refresh_token);
          
          // 重试原请求
          error.config.headers.Authorization = `Bearer ${res.data.access_token}`;
          return axios.request(error.config);
        } catch (refreshError) {
          // 刷新失败，跳转登录
          window.location.href = '/login';
        }
      }
    }
    return Promise.reject(error);
  }
);
```

---

## 2️⃣ 账户绑定功能

### 功能说明
已登录用户可以绑定第三方 OAuth 账户，实现多种登录方式。

### 后端实现

#### API 接口
```
POST /api/oauth/bind
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "provider": "feishu",
  "code": "授权码"
}
```

#### 响应示例
```json
{
  "code": 0,
  "msg": "绑定成功",
  "data": {
    "msg": "绑定成功"
  }
}
```

#### 业务逻辑
1. 验证用户登录状态（JWT Token）
2. 使用授权码换取第三方用户信息
3. 检查该第三方账户是否已被其他用户绑定
4. 创建绑定记录到 `sys_oauth_bind` 表

#### 实现文件
- `src/api/controllers/oauth.controller.zig` - `bind()` 方法

### 前端集成

#### 绑定流程
```typescript
// 1. 用户点击"绑定飞书账户"按钮
const handleBindFeishu = () => {
  const authUrl = buildOAuthAuthorizeUrl('feishu');
  // 存储绑定标识
  sessionStorage.setItem('oauth_action', 'bind');
  window.location.href = authUrl;
};

// 2. 回调页面处理
// ecom-admin/src/views/oauth/callback/index.vue
const action = sessionStorage.getItem('oauth_action');

if (action === 'bind') {
  // 调用绑定接口
  const res = await bindOAuthAccount({
    provider: provider as 'feishu',
    code: code as string,
  });
  
  if (res.code === 0) {
    Message.success('绑定成功！');
    router.push('/user/settings');
  }
} else {
  // 正常登录流程
  // ...
}
```

---

## 3️⃣ 审计日志系统

### 功能说明
记录所有 OAuth 操作（登录、绑定、解绑、刷新），用于安全审计和问题排查。

### 数据库表结构

#### sys_oauth_log 表
```sql
CREATE TABLE sys_oauth_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id INT DEFAULT NULL COMMENT '用户ID（未登录时为NULL）',
    provider VARCHAR(32) NOT NULL COMMENT 'OAuth提供商',
    action VARCHAR(32) NOT NULL COMMENT '操作类型（login/bind/unbind/refresh）',
    provider_user_id VARCHAR(128) DEFAULT '',
    ip_address VARCHAR(64) DEFAULT '',
    user_agent VARCHAR(500) DEFAULT '',
    status TINYINT DEFAULT 1 COMMENT '1成功/0失败',
    error_msg VARCHAR(500) DEFAULT '',
    extra_data TEXT COMMENT 'JSON格式额外数据',
    created_at BIGINT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 索引
CREATE INDEX idx_oauth_log_user_id ON sys_oauth_log(user_id);
CREATE INDEX idx_oauth_log_provider ON sys_oauth_log(provider);
CREATE INDEX idx_oauth_log_action ON sys_oauth_log(action);
CREATE INDEX idx_oauth_log_created_at ON sys_oauth_log(created_at);
```

### 实体模型
- `src/domain/entities/sys_oauth_log.model.zig` - `SysOAuthLog` 结构体

### 使用示例（待实现）

#### 记录登录日志
```zig
const log = models.SysOAuthLog{
    .user_id = user.id,
    .provider = "feishu",
    .action = "login",
    .provider_user_id = user_info.open_id,
    .ip_address = req.getHeader("x-real-ip") orelse "unknown",
    .user_agent = req.getHeader("user-agent") orelse "",
    .status = 1,
    .created_at = std.time.timestamp(),
};
_ = try OrmOAuthLog.Create(log);
```

#### 查询日志
```zig
// 查询某用户的所有 OAuth 操作记录
var q = OrmOAuthLog.WhereEq("user_id", user_id);
defer q.deinit();
_ = q.orderBy("created_at", "DESC");
_ = q.limit(100);
const logs = try q.get();
defer OrmOAuthLog.freeModels(logs);
```

---

## 4️⃣ 多提供商支持

### 功能说明
支持飞书、微信、QQ、GitHub 等多种 OAuth 提供商，统一接口设计。

### 架构设计

#### 抽象接口
- `src/application/services/oauth/oauth_provider.interface.zig`
- 定义统一的 `OAuthProvider` 接口
- 提供 `OAuthProviderFactory` 工厂类

#### 提供商实现

| 提供商 | 实现文件 | 状态 |
|--------|---------|------|
| 飞书 | `feishu_oauth.service.zig` | ✅ 已实现 |
| 微信 | `wechat_oauth.service.zig` | ✅ 框架完成 |
| QQ | `qq_oauth.service.zig` | ✅ 框架完成 |
| GitHub | 待实现 | ⏳ 计划中 |

### 微信 OAuth 集成

#### 配置环境变量
```bash
# 微信开放平台配置
WECHAT_APP_ID=wxxxxxxxxxxxxxxxxx
WECHAT_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WECHAT_REDIRECT_URI=https://yourdomain.com/oauth/callback
```

#### 授权 URL
```
https://open.weixin.qq.com/connect/qrconnect?appid={APP_ID}&redirect_uri={REDIRECT_URI}&response_type=code&scope=snsapi_login&state=wechat_oauth
```

#### API 文档
- [微信开放平台 - 网站应用微信登录](https://developers.weixin.qq.com/doc/oplatform/Website_App/WeChat_Login/Wechat_Login.html)

### QQ OAuth 集成

#### 配置环境变量
```bash
# QQ 互联配置
QQ_APP_ID=xxxxxxxxxx
QQ_APP_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
QQ_REDIRECT_URI=https://yourdomain.com/oauth/callback
```

#### 授权 URL
```
https://graph.qq.com/oauth2.0/authorize?response_type=code&client_id={APP_ID}&redirect_uri={REDIRECT_URI}&state=qq_oauth
```

#### API 文档
- [QQ 互联 - OAuth 2.0 开发文档](https://wiki.connect.qq.com/)

### 使用示例

#### 后端控制器扩展（建议）
```zig
// 支持多提供商的通用处理
pub fn callback(self: *Self, req: zap.Request) !void {
    const provider = parsed.value.provider;
    
    if (std.mem.eql(u8, provider, "feishu")) {
        // 飞书逻辑
        var feishu_service = FeishuOAuthService.init(self.allocator, feishu_config);
        // ...
    } else if (std.mem.eql(u8, provider, "wechat")) {
        // 微信逻辑
        var wechat_service = WechatOAuthService.init(self.allocator, wechat_config);
        // ...
    } else if (std.mem.eql(u8, provider, "qq")) {
        // QQ 逻辑
        var qq_service = QQOAuthService.init(self.allocator, qq_config);
        // ...
    }
}
```

---

## 🔧 完整 API 接口列表

| 接口 | 方法 | 功能 | 状态 |
|------|------|------|------|
| `/api/oauth/authorize` | GET | 获取授权 URL | ✅ |
| `/api/oauth/callback` | POST | 处理回调登录 | ✅ |
| `/api/oauth/refresh` | POST | 刷新 Token | ✅ |
| `/api/oauth/bind` | POST | 绑定账户 | ✅ |
| `/api/oauth/bind/list` | GET | 获取绑定列表 | ✅ |
| `/api/oauth/unbind` | DELETE | 解绑账户 | ✅ |

---

## 📊 数据库表总览

| 表名 | 用途 | 状态 |
|------|------|------|
| `sys_oauth_bind` | 存储绑定关系 | ✅ 已创建 |
| `sys_oauth_log` | 审计日志 | ✅ 已创建 |

---

## 🚀 测试指南

### 1. Token 刷新测试
```bash
# 1. 登录获取 refresh_token
curl -X POST http://localhost:3000/api/oauth/callback \
  -H "Content-Type: application/json" \
  -d '{"provider":"feishu","code":"xxx","state":"xxx"}'

# 2. 使用 refresh_token 刷新
curl -X POST http://localhost:3000/api/oauth/refresh \
  -H "Content-Type: application/json" \
  -d '{"provider":"feishu","refresh_token":"rt-xxx"}'
```

### 2. 账户绑定测试
```bash
# 1. 已登录用户获取 JWT Token
# 2. 绑定飞书账户
curl -X POST http://localhost:3000/api/oauth/bind \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"provider":"feishu","code":"xxx"}'

# 3. 查看绑定列表
curl -X GET http://localhost:3000/api/oauth/bind/list \
  -H "Authorization: Bearer <jwt_token>"
```

### 3. 审计日志测试
```sql
-- 查询最近的 OAuth 操作记录
SELECT * FROM sys_oauth_log 
ORDER BY created_at DESC 
LIMIT 20;

-- 查询某用户的所有操作
SELECT * FROM sys_oauth_log 
WHERE user_id = 1 
ORDER BY created_at DESC;

-- 统计各提供商的使用情况
SELECT provider, action, COUNT(*) as count 
FROM sys_oauth_log 
GROUP BY provider, action;
```

---

## 📝 后续优化建议

### 立即可做
1. **实现审计日志记录** - 在所有 OAuth 操作中添加日志记录
2. **前端自动刷新** - 实现 Token 过期自动刷新拦截器
3. **GitHub OAuth** - 实现 GitHub 登录支持

### 中期规划
1. **账户合并** - 支持多个第三方账户绑定到同一用户
2. **安全增强** - 绑定时验证用户密码
3. **日志分析** - 提供 OAuth 操作统计和分析页面

### 长期规划
1. **更多提供商** - 支持钉钉、企业微信、Google 等
2. **单点登录（SSO）** - 实现企业级 SSO 功能
3. **权限映射** - 第三方账户权限自动映射到本地角色

---

## 🔒 安全注意事项

1. **Token 存储**
   - `access_token` 和 `refresh_token` 必须加密存储
   - 生产环境使用 HTTPS 传输

2. **CSRF 防护**
   - 使用 `state` 参数防止 CSRF 攻击
   - 验证回调时的 `state` 参数

3. **审计日志**
   - 记录所有敏感操作
   - 定期清理过期日志（建议保留 90 天）

4. **权限控制**
   - 绑定/解绑操作需要用户登录
   - 验证用户身份后才能操作

---

**文档版本**：v2.0  
**更新时间**：2026-03-02  
**维护者**：ZigCMS 开发团队
