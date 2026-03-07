# 安全告警/通知集成指南

## 快速开始

本指南将帮助你在 5 分钟内完成安全告警/通知功能的集成。

---

## 前置条件

- ✅ 后端已编译通过
- ✅ 前端开发环境已配置
- ✅ 已安装所有依赖

---

## 集成步骤

### Step 1: 导入安全路由 (1分钟)

**文件**：`ecom-admin/src/router/index.ts`

找到路由配置文件，添加安全模块路由：

```typescript
// 在文件顶部添加导入
import securityRoutes from './modules/security';

// 在 routes 数组中添加
const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/dashboard',
  },
  // ... 其他路由
  securityRoutes,  // 👈 添加这一行
];
```

**验证**：
```bash
# 检查文件是否存在
ls ecom-admin/src/router/modules/security.ts
```

---

### Step 2: 添加通知组件到 Header (2分钟)

**文件**：`ecom-admin/src/layout/components/Header.vue`

在 Header 组件中添加安全告警通知图标：

```vue
<template>
  <div class="header">
    <!-- 左侧：Logo 和菜单 -->
    <div class="header-left">
      <!-- ... 现有内容 -->
    </div>

    <!-- 右侧：用户信息和通知 -->
    <div class="header-right">
      <!-- 👇 在用户信息前添加通知组件 -->
      <AlertNotification />
      
      <!-- 用户信息 -->
      <a-dropdown>
        <!-- ... 现有内容 -->
      </a-dropdown>
    </div>
  </div>
</template>

<script setup lang="ts">
// 👇 添加导入
import AlertNotification from '@/components/security/AlertNotification.vue';

// ... 其他代码
</script>

<style scoped lang="less">
.header-right {
  display: flex;
  align-items: center;
  gap: 16px;  // 👈 添加间距
}
</style>
```

**验证**：
```bash
# 检查组件文件是否存在
ls ecom-admin/src/components/security/AlertNotification.vue
```

---

### Step 3: 初始化安全 Store (1分钟)

**文件**：`ecom-admin/src/main.ts`

在应用启动后初始化安全 Store：

```typescript
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);
app.use(router);

// 挂载应用
app.mount('#app');

// 👇 添加以下代码：初始化安全 Store
import { useSecurityStore } from '@/store/modules/security';

// 等待应用挂载后初始化
router.isReady().then(() => {
  const securityStore = useSecurityStore();
  
  // 加载通知配置
  securityStore.loadNotificationConfig();
  
  // 启动实时告警轮询（30秒间隔）
  securityStore.startRealtimePolling(30000);
  
  console.log('[安全管理] 已启动实时告警轮询');
});
```

**验证**：
```bash
# 检查 Store 文件是否存在
ls ecom-admin/src/store/modules/security/index.ts
```

---

### Step 4: 添加告警声音文件 (1分钟)

**创建目录和文件**：

```bash
# 创建 sounds 目录
mkdir -p ecom-admin/public/sounds

# 下载或复制告警声音文件到该目录
# 文件名必须是：alert.mp3
```

**如果没有声音文件，可以临时禁用声音**：

在 `AlertNotification.vue` 中，声音播放会自动处理错误，所以即使没有文件也不会影响功能。

**可选**：使用在线声音生成器创建简单的提示音：
- https://www.zapsplat.com/
- https://freesound.org/

---

## 验证集成

### 1. 启动后端

```bash
# 在项目根目录
zig build run
```

**预期输出**：
```
[INFO] Server started on http://0.0.0.0:3000
[INFO] Registered 217 routes
```

### 2. 启动前端

```bash
# 在 ecom-admin 目录
cd ecom-admin
npm run dev
```

**预期输出**：
```
VITE v5.x.x  ready in xxx ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

### 3. 访问页面

打开浏览器访问：

1. **安全仪表板**：http://localhost:5173/security/dashboard
2. **安全告警**：http://localhost:5173/security/alerts
3. **安全事件**：http://localhost:5173/security/events
4. **审计日志**：http://localhost:5173/security/audit-log

### 4. 检查通知功能

1. **查看通知图标**：
   - Header 右侧应该显示一个通知图标
   - 如果有未读告警，会显示红色徽章

2. **点击通知图标**：
   - 应该打开通知面板
   - 显示最近的告警列表

3. **测试桌面通知**：
   - 点击通知设置按钮（齿轮图标）
   - 启用桌面通知
   - 点击"请求权限"按钮
   - 浏览器会弹出权限请求

4. **查看控制台**：
   ```
   [安全管理] 已启动实时告警轮询
   [安全管理][fetchAlerts][成功] { total: 0, count: 0 }
   ```

---

## 常见问题

### Q1: 通知图标不显示

**原因**：Header 组件未正确导入 AlertNotification

**解决**：
1. 检查 `Header.vue` 是否添加了导入语句
2. 检查组件文件路径是否正确
3. 重启前端开发服务器

### Q2: 路由 404 错误

**原因**：安全路由未正确注册

**解决**：
1. 检查 `router/index.ts` 是否导入了 `securityRoutes`
2. 检查路由配置是否添加到 routes 数组
3. 清除浏览器缓存并刷新

### Q3: API 调用失败

**原因**：后端未启动或路由未注册

**解决**：
1. 确认后端已启动：`zig build run`
2. 检查后端日志是否有错误
3. 访问 http://localhost:3000/api/security/alerts 测试 API

### Q4: 桌面通知不工作

**原因**：浏览器未授权或不支持

**解决**：
1. 检查浏览器是否支持 Notification API
2. 在通知设置中点击"请求权限"
3. 确保浏览器允许通知（检查浏览器设置）

### Q5: 声音不播放

**原因**：声音文件不存在或路径错误

**解决**：
1. 检查 `public/sounds/alert.mp3` 是否存在
2. 在浏览器控制台查看是否有 404 错误
3. 临时禁用声音：在通知设置中关闭"声音提醒"

---

## 功能测试清单

### 基础功能
- [ ] Header 显示通知图标
- [ ] 点击图标打开通知面板
- [ ] 通知面板显示告警列表
- [ ] 未读徽章显示正确数量
- [ ] 点击通知跳转到告警详情

### 通知功能
- [ ] 实时轮询获取新告警（30秒）
- [ ] 新告警自动添加到通知列表
- [ ] 桌面通知正常弹出
- [ ] 声音提醒正常播放
- [ ] 标记已读功能正常
- [ ] 清除通知功能正常

### 页面功能
- [ ] 安全仪表板数据加载
- [ ] 安全告警列表加载
- [ ] 安全事件列表加载
- [ ] 审计日志列表加载
- [ ] 筛选和搜索功能
- [ ] 分页功能
- [ ] 导出功能

### 配置功能
- [ ] 通知设置保存到本地存储
- [ ] 刷新页面后配置保持
- [ ] 最低通知级别过滤生效
- [ ] 通知类型过滤生效

---

## 性能优化建议

### 1. 调整轮询间隔

如果告警不频繁，可以增加轮询间隔：

```typescript
// main.ts
securityStore.startRealtimePolling(60000);  // 改为 60 秒
```

### 2. 限制通知数量

通知列表默认保留 100 条，可以在 Store 中调整：

```typescript
// store/modules/security/index.ts
if (this.notifications.length > 50) {  // 改为 50
  this.notifications = this.notifications.slice(0, 50);
}
```

### 3. 禁用不需要的功能

如果不需要某些功能，可以在配置中禁用：

```typescript
// 禁用声音
notificationConfig.sound = false;

// 禁用桌面通知
notificationConfig.desktop = false;

// 只通知严重告警
notificationConfig.minLevel = 'critical';
```

---

## 下一步优化

### 短期（1-2周）
1. 完善告警详情弹窗
2. 添加告警处理表单
3. 实现批量操作功能
4. 完善审计日志页面

### 中期（1个月）
1. 使用 WebSocket 替代轮询
2. 添加告警规则配置界面
3. 实现安全报告生成
4. 添加性能监控

### 长期（3个月）
1. AI 智能告警分析
2. 告警趋势预测
3. 自动化响应策略
4. 安全态势感知

---

## 技术支持

如果遇到问题，请检查：

1. **浏览器控制台**：查看 JavaScript 错误
2. **网络面板**：查看 API 请求是否成功
3. **后端日志**：查看服务器错误信息
4. **文档**：查看 `BUSINESS_CLOSURE_COMPLETE.md`

---

**集成完成时间**：约 5 分钟
**难度等级**：⭐⭐ (简单)
**状态**：✅ 准备就绪
