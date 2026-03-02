# OAuth 第三方登录完整集成指南

## 📋 功能概述

ZigCMS 已完成飞书 OAuth 第三方登录的**完整前后端实现**，支持：
- ✅ 飞书扫码登录
- ✅ 自动创建用户（首次登录）
- ✅ 账户绑定管理
- ✅ JWT Token 认证
- ✅ 前后端完整联调

---

## 🏗️ 架构流程

```
用户点击"飞书登录"
    ↓
前端构建授权 URL（或调用后端 /api/oauth/authorize）
    ↓
跳转到飞书授权页面
    ↓
用户扫码授权
    ↓
飞书回调到前端 /oauth/callback?code=xxx&state=xxx
    ↓
前端调用后端 POST /api/oauth/callback
    ↓
后端处理：
  1. 换取 access_token（飞书 API）
  2. 获取用户信息（飞书 API）
  3. 查询/创建本地用户
  4. 创建/更新绑定记录
  5. 生成 JWT Token
    ↓
返回登录成功 + access_token
    ↓
前端存储 Token 并跳转到首页
```

---

## 🔧 后端配置

### 1. 环境变量配置

创建 `.env` 文件（或在系统环境变量中配置）：

```bash
# 飞书 OAuth 配置
FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FEISHU_REDIRECT_URI=http://localhost:5173/oauth/callback

# JWT 密钥（生产环境请使用强随机字符串）
JWT_SECRET=zigcms-jwt-secret-key-2024
```

### 2. 后端 API 接口

#### 2.1 获取授权 URL（可选）
```
GET /api/oauth/authorize?provider=feishu
```

**响应示例**：
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "url": "https://open.feishu.cn/open-apis/authen/v1/authorize?app_id=cli_xxx&redirect_uri=http://localhost:5173/oauth/callback&state=feishu_oauth"
  }
}
```

#### 2.2 处理 OAuth 回调（核心）
```
POST /api/oauth/callback
Content-Type: application/json

{
  "provider": "feishu",
  "code": "授权码",
  "state": "状态参数"
}
```

**响应示例**：
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 7200,
    "user": {
      "id": 1,
      "username": "feishu_ou_xxxxx",
      "nickname": "张三",
      "email": "zhangsan@example.com",
      "avatar_url": "https://..."
    }
  }
}
```

#### 2.3 获取绑定列表
```
GET /api/oauth/bind/list
Authorization: Bearer <access_token>
```

#### 2.4 解绑账户
```
DELETE /api/oauth/unbind?provider=feishu
Authorization: Bearer <access_token>
```

---

## 🎨 前端配置

### 1. 环境变量配置

创建 `ecom-admin/.env.development`：

```bash
# OAuth 功能开关
VITE_OAUTH_ENABLED=true

# 飞书 OAuth 配置
VITE_FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
VITE_FEISHU_REDIRECT_URI=http://localhost:5173/oauth/callback

# GitHub OAuth 配置（可选）
VITE_GITHUB_CLIENT_ID=Ov23xxxxxxxxxxxxxx
VITE_GITHUB_REDIRECT_URI=http://localhost:5173/oauth/callback

# 后端 API 地址
VITE_API_BASE_URL=http://localhost:3000
```

### 2. 前端已实现功能

#### 2.1 登录页面 OAuth 按钮
文件：`ecom-admin/src/views/login/components/login-form.vue`

```vue
<!-- 飞书登录按钮 -->
<a-button class="oauth-btn feishu-btn" @click="handleOAuthLogin('feishu')">
  <template #icon>
    <!-- 飞书图标 -->
  </template>
</a-button>

<script setup>
import { buildOAuthAuthorizeUrl } from '@/api/oauth';

const handleOAuthLogin = (provider: 'feishu' | 'github') => {
  const authUrl = buildOAuthAuthorizeUrl(provider);
  window.location.href = authUrl; // 跳转到飞书授权页面
};
</script>
```

#### 2.2 OAuth 回调页面
文件：`ecom-admin/src/views/oauth/callback/index.vue`

功能：
- ✅ 验证 state 防止 CSRF
- ✅ 调用后端 `/api/oauth/callback`
- ✅ 存储 JWT Token
- ✅ 存储用户信息
- ✅ 自动跳转到首页

#### 2.3 API 封装
文件：`ecom-admin/src/api/oauth.ts`

提供的方法：
- `getOAuthUrl(provider)` - 获取授权 URL（后端）
- `buildOAuthAuthorizeUrl(provider)` - 前端构建授权 URL
- `handleOAuthCallback(params)` - 处理回调
- `bindOAuthAccount(params)` - 绑定账户
- `unbindOAuthAccount(provider)` - 解绑账户
- `getOAuthBindList()` - 获取绑定列表

---

## 🚀 部署与测试

### 1. 飞书开放平台配置

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用
3. 获取 `App ID` 和 `App Secret`
4. 配置重定向 URL：`http://localhost:5173/oauth/callback`（开发环境）
5. 开启权限：
   - `contact:user.base:readonly` - 获取用户基本信息
   - `contact:user.email:readonly` - 获取用户邮箱

### 2. 本地开发测试

#### 启动后端
```bash
cd /Users/tuoke/products/zigcms

# 配置环境变量
export FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
export FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export FEISHU_REDIRECT_URI=http://localhost:5173/oauth/callback

# 启动服务
zig build run
```

#### 启动前端
```bash
cd /Users/tuoke/products/zigcms/ecom-admin

# 确保 .env.development 已配置
npm run dev
```

#### 测试流程
1. 访问 `http://localhost:5173/login`
2. 点击"飞书登录"按钮
3. 扫码授权
4. 自动跳转回 `/oauth/callback`
5. 处理完成后跳转到首页
6. 检查浏览器控制台和网络请求

### 3. 生产环境部署

#### 后端配置
```bash
# 生产环境变量
FEISHU_APP_ID=cli_prod_xxxxxxxx
FEISHU_APP_SECRET=prod_secret_xxxxxxxx
FEISHU_REDIRECT_URI=https://yourdomain.com/oauth/callback
JWT_SECRET=<强随机字符串>
```

#### 前端配置
```bash
# .env.production
VITE_OAUTH_ENABLED=true
VITE_FEISHU_APP_ID=cli_prod_xxxxxxxx
VITE_FEISHU_REDIRECT_URI=https://yourdomain.com/oauth/callback
VITE_API_BASE_URL=https://api.yourdomain.com
```

---

## 📊 数据库表结构

### sys_oauth_bind 表
```sql
CREATE TABLE IF NOT EXISTS sys_oauth_bind (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,                    -- 关联的本地用户ID
    provider VARCHAR(32) NOT NULL,           -- OAuth提供商（feishu/github）
    provider_user_id VARCHAR(128) NOT NULL,  -- 第三方用户ID
    nickname VARCHAR(128) DEFAULT '',        -- 第三方昵称
    avatar_url VARCHAR(500) DEFAULT '',      -- 第三方头像
    email VARCHAR(128) DEFAULT '',           -- 第三方邮箱
    access_token VARCHAR(500) DEFAULT '',    -- 访问令牌
    refresh_token VARCHAR(500) DEFAULT '',   -- 刷新令牌
    token_expires_at BIGINT DEFAULT NULL,    -- 令牌过期时间
    bind_time BIGINT DEFAULT NULL,           -- 绑定时间
    last_login_time BIGINT DEFAULT NULL,     -- 最后登录时间
    status TINYINT DEFAULT 1,                -- 状态（1启用/0禁用）
    created_at BIGINT DEFAULT NULL,
    updated_at BIGINT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 索引
CREATE INDEX idx_oauth_bind_user_id ON sys_oauth_bind(user_id);
CREATE INDEX idx_oauth_bind_provider ON sys_oauth_bind(provider);
CREATE UNIQUE INDEX idx_oauth_bind_provider_user ON sys_oauth_bind(provider, provider_user_id);
```

---

## 🔍 故障排查

### 1. 授权失败
- ✅ 检查 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET` 是否正确
- ✅ 检查飞书开放平台的重定向 URL 配置
- ✅ 检查应用权限是否开启

### 2. 回调失败
- ✅ 检查前端 `VITE_FEISHU_REDIRECT_URI` 与飞书平台配置一致
- ✅ 检查后端 `FEISHU_REDIRECT_URI` 与飞书平台配置一致
- ✅ 检查网络请求是否到达后端 `/api/oauth/callback`

### 3. Token 无效
- ✅ 检查 JWT 密钥配置
- ✅ 检查 Token 是否正确存储到 localStorage
- ✅ 检查请求头是否携带 `Authorization: Bearer <token>`

### 4. 用户信息获取失败
- ✅ 检查飞书 API 权限
- ✅ 检查网络连接（飞书 API 需要外网访问）
- ✅ 查看后端日志中的错误信息

---

## 📝 开发注意事项

### 1. 安全性
- ✅ **CSRF 防护**：前端使用 `state` 参数并存储到 `sessionStorage`
- ✅ **Token 安全**：JWT 密钥使用强随机字符串
- ✅ **HTTPS**：生产环境必须使用 HTTPS
- ✅ **密钥管理**：敏感配置不提交到代码仓库

### 2. 用户体验
- ✅ **加载状态**：回调页面显示加载动画
- ✅ **错误提示**：授权失败时显示友好错误信息
- ✅ **自动跳转**：登录成功后自动跳转到首页

### 3. 扩展性
- ✅ **多提供商支持**：代码已支持 GitHub 等其他 OAuth 提供商
- ✅ **账户绑定**：支持已登录用户绑定第三方账户
- ✅ **解绑功能**：支持解除第三方账户绑定

---

## 🎯 后续优化建议

1. **多提供商支持**
   - 实现 GitHub OAuth
   - 实现微信/QQ 登录

2. **账户绑定增强**
   - 支持多个第三方账户绑定到同一用户
   - 绑定时验证用户密码

3. **Token 刷新机制**
   - 实现 refresh_token 自动刷新
   - Token 过期前自动续期

4. **审计日志**
   - 记录所有 OAuth 登录行为
   - 记录绑定/解绑操作

---

## ✅ 完成清单

- [x] 后端 OAuth 服务实现（飞书 API 集成）
- [x] 后端 4 个 API 接口（authorize/callback/bind/unbind）
- [x] 数据库表设计与迁移 SQL
- [x] JWT Token 生成与验证
- [x] 前端登录页 OAuth 按钮
- [x] 前端回调页面处理
- [x] 前端 API 封装
- [x] 环境变量配置文档
- [x] 完整联调测试指南

---

**文档版本**：v1.0  
**更新时间**：2026-03-02  
**维护者**：ZigCMS 开发团队
