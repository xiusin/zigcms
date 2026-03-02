# 飞书 OAuth 集成指南

## 概述

ZigCMS 已集成飞书 OAuth 2.0 认证，支持用户使用飞书账号登录系统。

## 功能特性

- ✅ 飞书扫码登录
- ✅ 自动创建用户账户
- ✅ 绑定/解绑飞书账号
- ✅ 令牌自动刷新
- ✅ 用户信息同步

## 架构设计

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   前端页面   │ ───> │  飞书授权页   │ ───> │  OAuth回调  │
└─────────────┘      └──────────────┘      └─────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────┐
│                    后端 API                              │
├─────────────────────────────────────────────────────────┤
│  OAuth Controller                                        │
│  ├─ callback()      - 处理 OAuth 回调                   │
│  ├─ bindList()      - 获取绑定列表                      │
│  └─ unbind()        - 解绑账户                          │
├─────────────────────────────────────────────────────────┤
│  Feishu OAuth Service                                    │
│  ├─ getAppAccessToken()      - 获取应用令牌             │
│  ├─ getUserAccessToken()     - 获取用户令牌             │
│  ├─ getUserInfo()            - 获取用户信息             │
│  └─ refreshAccessToken()     - 刷新令牌                 │
├─────────────────────────────────────────────────────────┤
│  Database (sys_oauth_bind)                               │
│  ├─ user_id                  - 用户ID                   │
│  ├─ provider                 - OAuth提供商              │
│  ├─ provider_user_id         - 第三方用户ID             │
│  ├─ access_token             - 访问令牌                 │
│  └─ refresh_token            - 刷新令牌                 │
└─────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 配置飞书应用

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用
3. 获取 `App ID` 和 `App Secret`
4. 配置回调地址：`http://your-domain.com/oauth/callback`
5. 开启权限：
   - `获取用户统一ID` (contact:user.id:readonly)
   - `获取用户邮箱` (contact:user.email:readonly)
   - `获取用户手机号` (contact:user.phone:readonly)

### 2. 配置环境变量

复制 `.env.oauth.example` 到 `.env`：

```bash
cp .env.oauth.example .env
```

编辑 `.env` 文件：

```bash
# 飞书 OAuth 配置
FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FEISHU_REDIRECT_URI=http://localhost:5173/oauth/callback

# OAuth 功能开关
OAUTH_ENABLED=true
```

### 3. 运行数据库迁移

```bash
sqlite3 data/zigcms.db < migrations/20260302_create_oauth_bind.sql
```

### 4. 启动服务

```bash
zig build run
```

### 5. 前端配置

前端已经配置好，确保 `ecom-admin/.env.development` 包含：

```bash
# OAuth 配置
VITE_OAUTH_ENABLED=true
VITE_FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
VITE_FEISHU_REDIRECT_URI=http://localhost:5173/oauth/callback
```

## API 接口

### 1. 处理 OAuth 回调

**接口**: `POST /api/oauth/callback`

**请求体**:
```json
{
  "provider": "feishu",
  "code": "xxx",
  "state": "xxx"
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 7200,
    "user": {
      "id": 1,
      "username": "zhangsan@example.com",
      "nickname": "张三",
      "email": "zhangsan@example.com",
      "avatar_url": "https://..."
    }
  }
}
```

### 2. 获取绑定列表

**接口**: `GET /api/oauth/bind/list`

**请求头**:
```
x-user-id: 1
```

**响应**:
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "list": [
      {
        "provider": "feishu",
        "provider_user_id": "ou_xxxxxxxxxxxxx",
        "nickname": "张三",
        "avatar_url": "https://...",
        "bind_time": 1709366400
      }
    ]
  }
}
```

### 3. 解绑 OAuth 账户

**接口**: `DELETE /api/oauth/unbind?provider=feishu`

**请求头**:
```
x-user-id: 1
```

**响应**:
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "message": "解绑成功"
  }
}
```

## 数据库表结构

### sys_oauth_bind

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| user_id | INTEGER | 用户ID |
| provider | TEXT | OAuth提供商 (feishu, github) |
| provider_user_id | TEXT | 第三方用户ID |
| nickname | TEXT | 昵称 |
| avatar_url | TEXT | 头像URL |
| email | TEXT | 邮箱 |
| access_token | TEXT | 访问令牌 |
| refresh_token | TEXT | 刷新令牌 |
| token_expires_at | INTEGER | 令牌过期时间 |
| bind_time | INTEGER | 绑定时间 |
| last_login_time | INTEGER | 最后登录时间 |
| status | INTEGER | 状态 (1=正常 0=禁用) |
| created_at | INTEGER | 创建时间 |
| updated_at | INTEGER | 更新时间 |

**索引**:
- `idx_oauth_bind_user_id` - 用户ID索引
- `idx_oauth_bind_provider` - 提供商索引
- `idx_oauth_bind_provider_user` - 提供商+用户ID唯一索引

## 前端集成

### 登录页面

前端已集成飞书登录按钮，点击后会跳转到飞书授权页面：

```vue
<template>
  <a-button class="oauth-btn feishu-btn" @click="handleOAuthLogin('feishu')">
    <template #icon>
      <svg><!-- 飞书图标 --></svg>
    </template>
  </a-button>
</template>

<script setup>
import { buildOAuthAuthorizeUrl } from '@/api/oauth';

const handleOAuthLogin = (provider) => {
  const authUrl = buildOAuthAuthorizeUrl(provider);
  window.location.href = authUrl;
};
</script>
```

### OAuth 回调页面

前端已实现 `/oauth/callback` 页面，自动处理回调：

```vue
<script setup>
import { handleOAuthCallback } from '@/api/oauth';

onMounted(async () => {
  const { code, state, provider } = route.query;
  
  // 验证 state 防止 CSRF
  const savedState = sessionStorage.getItem('oauth_state');
  if (state !== savedState) {
    // 错误处理
    return;
  }
  
  // 调用后端接口
  const res = await handleOAuthCallback({ provider, code, state });
  
  // 存储令牌并跳转
  userStore.setToken(res.data.access_token);
  router.push('/');
});
</script>
```

## 安全性

### 1. CSRF 防护

前端生成随机 `state` 参数并存储到 `sessionStorage`，回调时验证：

```javascript
const state = `${provider}_${Date.now()}_${Math.random().toString(36).substring(7)}`;
sessionStorage.setItem('oauth_state', state);
```

### 2. 令牌加密存储

数据库中的 `access_token` 和 `refresh_token` 应该加密存储（TODO）。

### 3. 令牌过期处理

后端自动检查令牌过期时间，过期时使用 `refresh_token` 刷新。

### 4. 权限控制

OAuth 登录的用户默认为普通用户，需要管理员手动分配角色和权限。

## 扩展其他 OAuth 提供商

### 1. 创建服务

参考 `feishu_oauth.service.zig`，创建新的 OAuth 服务：

```zig
// src/application/services/oauth/github_oauth.service.zig
pub const GitHubOAuthService = struct {
    // 实现 GitHub OAuth 流程
};
```

### 2. 更新控制器

在 `oauth.controller.zig` 中添加新提供商的处理逻辑：

```zig
if (std.mem.eql(u8, provider, "github")) {
    // 处理 GitHub OAuth
}
```

### 3. 前端配置

在 `ecom-admin/src/api/oauth.ts` 中添加新提供商的配置：

```typescript
const clientIdMap: Record<OAuthProvider, string> = {
  feishu: VITE_FEISHU_APP_ID,
  github: VITE_GITHUB_CLIENT_ID,
};
```

## 故障排查

### 1. 回调失败

**问题**: 飞书回调后显示 "OAuth 回调处理失败"

**解决**:
- 检查 `.env` 中的 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET` 是否正确
- 检查飞书应用的回调地址是否配置正确
- 查看后端日志：`tail -f logs/zigcms.log`

### 2. 用户信息获取失败

**问题**: 登录成功但用户信息为空

**解决**:
- 检查飞书应用权限是否开启
- 检查用户是否授权了相关权限
- 查看飞书 API 返回的错误信息

### 3. 令牌过期

**问题**: 登录后一段时间无法访问

**解决**:
- 实现令牌自动刷新机制（TODO）
- 提示用户重新登录

## 测试

### 1. 单元测试

```bash
zig test src/application/services/oauth/feishu_oauth.service.zig
```

### 2. 集成测试

```bash
# 启动服务
zig build run

# 测试回调接口
curl -X POST http://localhost:3000/api/oauth/callback \
  -H "Content-Type: application/json" \
  -d '{"provider":"feishu","code":"xxx","state":"xxx"}'
```

### 3. 前端测试

1. 访问 `http://localhost:5173/login`
2. 点击"飞书登录"按钮
3. 扫码授权
4. 验证是否成功登录

## 性能优化

### 1. 缓存应用令牌

应用令牌有效期较长，可以缓存避免频繁请求：

```zig
// TODO: 实现令牌缓存
const cached_token = try cache.get("feishu:app_token");
if (cached_token) |token| {
    return token;
}
```

### 2. 异步处理

用户信息同步可以异步处理，提升响应速度：

```zig
// TODO: 实现异步任务队列
try task_queue.push(.{
    .type = .sync_user_info,
    .user_id = user_id,
});
```

## 参考资料

- [飞书开放平台文档](https://open.feishu.cn/document/home/index)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [ZigCMS 认证架构](./AUTHENTICATION.md)

## 常见问题

### Q: 如何支持多个飞书应用？

A: 可以在数据库中添加 `app_id` 字段，支持多租户场景。

### Q: 如何实现账号合并？

A: 当检测到邮箱已存在时，提示用户绑定现有账户而不是创建新账户。

### Q: 如何处理飞书用户离职？

A: 定期同步飞书通讯录，自动禁用离职用户账户。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
