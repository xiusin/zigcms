# 中期优化计划（1个月）

## 规划时间
2026-03-07

## 执行摘要

本文档规划安全告警/通知功能的中期优化任务（1个月计划），包括 WebSocket 实时推送、告警规则配置、安全报告生成、性能监控和大数据列表优化。

---

## 🎯 优化目标

### 1. 实时性提升
- 使用 WebSocket 替代轮询，实现真正的实时推送
- 减少服务器压力，降低网络开销
- 提升用户体验，告警即时送达

### 2. 可配置性增强
- 添加告警规则配置界面
- 支持自定义告警阈值和条件
- 支持告警通知渠道配置

### 3. 数据分析能力
- 实现安全报告生成
- 支持多维度数据分析
- 支持报告导出和分享

### 4. 性能监控
- 添加系统性能监控
- 实时追踪关键指标
- 性能问题预警

### 5. 大数据优化
- 实现虚拟滚动
- 优化大数据列表渲染
- 提升列表性能

---

## 📋 任务清单

### 任务 1: WebSocket 实时推送 ⏳

**优先级**: P0（最高）  
**预计工时**: 5天  
**负责人**: 后端 + 前端

#### 后端实现

**1.1 创建 WebSocket 服务器**

**文件**: `src/infrastructure/websocket/ws_server.zig`

**功能**:
- WebSocket 连接管理
- 客户端认证
- 消息广播
- 心跳检测
- 断线重连

**实现要点**:
```zig
pub const WebSocketServer = struct {
    allocator: Allocator,
    clients: std.AutoHashMap(u32, *Client),
    
    pub fn init(allocator: Allocator) !*WebSocketServer {
        // 初始化 WebSocket 服务器
    }
    
    pub fn handleConnection(self: *Self, conn: *Connection) !void {
        // 处理新连接
    }
    
    pub fn broadcast(self: *Self, message: []const u8) !void {
        // 广播消息到所有客户端
    }
    
    pub fn sendToUser(self: *Self, user_id: u32, message: []const u8) !void {
        // 发送消息到特定用户
    }
};
```

**1.2 集成到安全监控**

**文件**: `src/infrastructure/security/security_monitor.zig`

**修改**:
```zig
// 添加 WebSocket 推送
pub fn notifyAlert(self: *Self, alert: Alert) !void {
    // 保存到数据库
    try self.saveAlert(alert);
    
    // WebSocket 推送
    const ws_server = try self.di.resolve(WebSocketServer);
    const message = try std.json.stringify(alert, .{}, self.allocator);
    defer self.allocator.free(message);
    
    try ws_server.broadcast(message);
}
```

**1.3 创建 WebSocket 控制器**

**文件**: `src/api/controllers/websocket.controller.zig`

**功能**:
- WebSocket 握手
- 消息路由
- 错误处理

#### 前端实现

**1.4 创建 WebSocket 客户端**

**文件**: `ecom-admin/src/utils/websocket.ts`

**功能**:
```typescript
export class WebSocketClient {
  private ws: WebSocket | null = null;
  private reconnectTimer: number | null = null;
  private heartbeatTimer: number | null = null;
  
  constructor(private url: string) {}
  
  connect(): Promise<void> {
    // 建立连接
  }
  
  disconnect(): void {
    // 断开连接
  }
  
  send(message: any): void {
    // 发送消息
  }
  
  on(event: string, handler: Function): void {
    // 注册事件监听器
  }
  
  private reconnect(): void {
    // 自动重连
  }
  
  private startHeartbeat(): void {
    // 心跳检测
  }
}
```

**1.5 集成到 Store**

**文件**: `ecom-admin/src/store/modules/security/index.ts`

**修改**:
```typescript
export const useSecurityStore = defineStore('security', () => {
  const wsClient = new WebSocketClient('ws://localhost:3000/ws');
  
  // 连接 WebSocket
  const connectWebSocket = () => {
    wsClient.connect();
    
    // 监听告警消息
    wsClient.on('alert', (alert: SecurityAlert) => {
      alerts.value.unshift(alert);
      showNotification(alert);
    });
    
    // 监听事件消息
    wsClient.on('event', (event: SecurityEvent) => {
      events.value.unshift(event);
    });
  };
  
  // 断开 WebSocket
  const disconnectWebSocket = () => {
    wsClient.disconnect();
  };
  
  return {
    connectWebSocket,
    disconnectWebSocket,
    // ... 其他方法
  };
});
```

**1.6 更新组件**

**文件**: `ecom-admin/src/App.vue`

**修改**:
```typescript
import { useSecurityStore } from '@/store/modules/security';

const securityStore = useSecurityStore();

onMounted(() => {
  // 连接 WebSocket
  securityStore.connectWebSocket();
});

onUnmounted(() => {
  // 断开 WebSocket
  securityStore.disconnectWebSocket();
});
```

---

### 任务 2: 告警规则配置界面 ⏳

**优先级**: P1（高）  
**预计工时**: 4天  
**负责人**: 前端 + 后端

#### 后端实现

**2.1 创建规则实体**

**文件**: `src/domain/entities/alert_rule.model.zig`

**定义**:
```zig
pub const AlertRule = struct {
    id: ?i32 = null,
    name: []const u8,
    description: []const u8,
    type: []const u8, // brute_force, sql_injection, etc.
    level: []const u8, // critical, high, medium, low
    conditions: []const u8, // JSON 格式的条件
    actions: []const u8, // JSON 格式的动作
    enabled: bool = true,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};
```

**2.2 创建规则仓储**

**文件**: `src/infrastructure/database/mysql_alert_rule_repository.zig`

**功能**:
- 创建规则
- 更新规则
- 删除规则
- 查询规则
- 启用/禁用规则

**2.3 创建规则服务**

**文件**: `src/application/services/alert_rule_service.zig`

**功能**:
- 规则 CRUD
- 规则验证
- 规则测试
- 规则应用

**2.4 创建规则控制器**

**文件**: `src/api/controllers/security/alert_rule.controller.zig`

**接口**:
- `GET /api/security/alert-rules` - 获取规则列表
- `POST /api/security/alert-rules` - 创建规则
- `PUT /api/security/alert-rules/:id` - 更新规则
- `DELETE /api/security/alert-rules/:id` - 删除规则
- `POST /api/security/alert-rules/:id/test` - 测试规则

#### 前端实现

**2.5 创建规则配置页面**

**文件**: `ecom-admin/src/views/security/alert-rules/index.vue`

**功能**:
- 规则列表
- 规则创建
- 规则编辑
- 规则删除
- 规则启用/禁用

**2.6 创建规则表单**

**文件**: `ecom-admin/src/views/security/alert-rules/components/RuleForm.vue`

**功能**:
- 基本信息配置
- 条件配置（可视化）
- 动作配置
- 通知渠道配置

**2.7 创建条件构建器**

**文件**: `ecom-admin/src/views/security/alert-rules/components/ConditionBuilder.vue`

**功能**:
- 可视化条件构建
- 支持多条件组合
- 支持逻辑运算符（AND、OR）
- 实时预览

---

### 任务 3: 安全报告生成 ⏳

**优先级**: P1（高）  
**预计工时**: 5天  
**负责人**: 后端 + 前端

#### 后端实现

**3.1 创建报告生成器**

**文件**: `src/infrastructure/report/security_report_generator.zig`

**功能**:
```zig
pub const SecurityReportGenerator = struct {
    allocator: Allocator,
    db: *Database,
    
    pub fn generateDailyReport(self: *Self, date: []const u8) !Report {
        // 生成日报
    }
    
    pub fn generateWeeklyReport(self: *Self, start_date: []const u8) !Report {
        // 生成周报
    }
    
    pub fn generateMonthlyReport(self: *Self, month: []const u8) !Report {
        // 生成月报
    }
    
    pub fn generateCustomReport(self: *Self, params: ReportParams) !Report {
        // 生成自定义报告
    }
};
```

**3.2 创建报告模板**

**文件**: `src/infrastructure/report/templates/`

**模板**:
- `daily_report.html` - 日报模板
- `weekly_report.html` - 周报模板
- `monthly_report.html` - 月报模板

**3.3 创建报告控制器**

**文件**: `src/api/controllers/security/report.controller.zig`

**接口**:
- `GET /api/security/reports` - 获取报告列表
- `POST /api/security/reports/generate` - 生成报告
- `GET /api/security/reports/:id` - 获取报告详情
- `GET /api/security/reports/:id/download` - 下载报告

#### 前端实现

**3.4 创建报告页面**

**文件**: `ecom-admin/src/views/security/reports/index.vue`

**功能**:
- 报告列表
- 报告生成
- 报告预览
- 报告下载

**3.5 创建报告生成器**

**文件**: `ecom-admin/src/views/security/reports/components/ReportGenerator.vue`

**功能**:
- 报告类型选择
- 时间范围选择
- 数据维度选择
- 报告格式选择（PDF、Excel、HTML）

**3.6 创建报告预览**

**文件**: `ecom-admin/src/views/security/reports/components/ReportPreview.vue`

**功能**:
- 报告内容展示
- 图表可视化
- 数据表格
- 导出功能

---

### 任务 4: 性能监控 ⏳

**优先级**: P2（中）  
**预计工时**: 3天  
**负责人**: 后端 + 前端

#### 后端实现

**4.1 创建性能监控器**

**文件**: `src/infrastructure/monitoring/performance_monitor.zig`

**功能**:
```zig
pub const PerformanceMonitor = struct {
    allocator: Allocator,
    metrics: std.AutoHashMap([]const u8, Metric),
    
    pub fn recordMetric(self: *Self, name: []const u8, value: f64) !void {
        // 记录指标
    }
    
    pub fn getMetrics(self: *Self, start_time: i64, end_time: i64) ![]Metric {
        // 获取指标
    }
    
    pub fn getAverageMetric(self: *Self, name: []const u8, duration: i64) !f64 {
        // 获取平均值
    }
};
```

**4.2 集成到中间件**

**文件**: `src/api/middleware/performance_tracking.zig`

**功能**:
- 请求响应时间
- 数据库查询时间
- 缓存命中率
- 内存使用情况

**4.3 创建监控控制器**

**文件**: `src/api/controllers/monitoring/performance.controller.zig`

**接口**:
- `GET /api/monitoring/metrics` - 获取指标
- `GET /api/monitoring/metrics/:name` - 获取特定指标
- `GET /api/monitoring/health` - 健康检查

#### 前端实现

**4.4 创建监控页面**

**文件**: `ecom-admin/src/views/monitoring/performance/index.vue`

**功能**:
- 实时指标展示
- 历史趋势图
- 性能告警
- 健康状态

**4.5 创建指标图表**

**文件**: `ecom-admin/src/views/monitoring/performance/components/MetricChart.vue`

**功能**:
- 实时更新
- 多指标对比
- 时间范围选择
- 数据导出

---

### 任务 5: 大数据列表优化 ⏳

**优先级**: P2（中）  
**预计工时**: 3天  
**负责人**: 前端

#### 实现方案

**5.1 创建虚拟滚动组件**

**文件**: `ecom-admin/src/components/virtual-scroll/VirtualList.vue`

**功能**:
```typescript
export interface VirtualListProps {
  items: any[];
  itemHeight: number;
  bufferSize?: number;
  onLoadMore?: () => void;
}

export const VirtualList = defineComponent({
  props: virtualListProps,
  setup(props) {
    const visibleItems = computed(() => {
      // 计算可见项
    });
    
    const scrollTop = ref(0);
    const containerHeight = ref(0);
    
    const handleScroll = (e: Event) => {
      // 处理滚动
    };
    
    return {
      visibleItems,
      handleScroll,
    };
  },
});
```

**5.2 集成到告警列表**

**文件**: `ecom-admin/src/views/security/alerts/list-enhanced.vue`

**修改**:
```vue
<template>
  <VirtualList
    :items="alerts"
    :item-height="80"
    :buffer-size="5"
    @load-more="loadMore"
  >
    <template #item="{ item }">
      <AlertCard :alert="item" />
    </template>
  </VirtualList>
</template>
```

**5.3 优化数据加载**

**策略**:
- 分页加载
- 无限滚动
- 数据缓存
- 预加载

**5.4 性能测试**

**测试场景**:
- 1000 条数据
- 10000 条数据
- 100000 条数据

**性能指标**:
- 首屏渲染时间
- 滚动流畅度
- 内存占用

---

## 📊 预期效果

### 1. WebSocket 实时推送

| 指标 | 轮询方式 | WebSocket | 提升 |
|------|----------|-----------|------|
| 延迟 | 5-10s | < 100ms | 98% ↓ |
| 服务器压力 | 高 | 低 | 80% ↓ |
| 网络开销 | 大 | 小 | 90% ↓ |
| 用户体验 | 一般 | 优秀 | ⭐⭐⭐⭐⭐ |

### 2. 告警规则配置

| 功能 | 优化前 | 优化后 |
|------|--------|--------|
| 规则配置 | 代码修改 | 界面配置 |
| 配置难度 | 高 | 低 |
| 灵活性 | 低 | 高 |
| 可维护性 | 差 | 优 |

### 3. 安全报告生成

| 功能 | 优化前 | 优化后 |
|------|--------|--------|
| 报告生成 | 手动统计 | 自动生成 |
| 报告类型 | 单一 | 多样 |
| 数据分析 | 简单 | 深入 |
| 导出格式 | 无 | PDF/Excel/HTML |

### 4. 性能监控

| 指标 | 优化前 | 优化后 |
|------|--------|--------|
| 性能可见性 | 无 | 完整 |
| 问题发现 | 被动 | 主动 |
| 性能优化 | 盲目 | 精准 |
| 告警机制 | 无 | 有 |

### 5. 大数据列表

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 渲染时间（1000条） | 2s | 0.3s | 85% ↓ |
| 渲染时间（10000条） | 20s | 0.5s | 97% ↓ |
| 内存占用 | 200MB | 50MB | 75% ↓ |
| 滚动流畅度 | 30fps | 60fps | 100% ↑ |

---

## 🗓️ 时间规划

### 第 1 周（3.8 - 3.14）
- [ ] WebSocket 后端实现（3天）
- [ ] WebSocket 前端实现（2天）

### 第 2 周（3.15 - 3.21）
- [ ] 告警规则后端实现（2天）
- [ ] 告警规则前端实现（3天）

### 第 3 周（3.22 - 3.28）
- [ ] 安全报告后端实现（2天）
- [ ] 安全报告前端实现（3天）

### 第 4 周（3.29 - 4.4）
- [ ] 性能监控实现（3天）
- [ ] 大数据列表优化（2天）
- [ ] 集成测试和文档（2天）

---

## 🧪 测试计划

### 1. WebSocket 测试
- [ ] 连接建立测试
- [ ] 消息推送测试
- [ ] 断线重连测试
- [ ] 心跳检测测试
- [ ] 并发连接测试

### 2. 告警规则测试
- [ ] 规则创建测试
- [ ] 规则验证测试
- [ ] 规则应用测试
- [ ] 规则性能测试

### 3. 报告生成测试
- [ ] 报告生成测试
- [ ] 报告格式测试
- [ ] 报告导出测试
- [ ] 大数据报告测试

### 4. 性能监控测试
- [ ] 指标采集测试
- [ ] 指标存储测试
- [ ] 指标查询测试
- [ ] 告警触发测试

### 5. 虚拟滚动测试
- [ ] 渲染性能测试
- [ ] 滚动流畅度测试
- [ ] 内存占用测试
- [ ] 兼容性测试

---

## 📚 技术选型

### 后端技术
- **WebSocket**: Zig 原生 WebSocket 支持
- **报告生成**: HTML 模板 + PDF 转换
- **性能监控**: 自定义指标采集

### 前端技术
- **WebSocket**: 原生 WebSocket API
- **虚拟滚动**: 自定义实现
- **图表**: ECharts
- **PDF 导出**: jsPDF

---

## 🎯 成功标准

### 1. WebSocket
- ✅ 延迟 < 100ms
- ✅ 支持 1000+ 并发连接
- ✅ 自动重连成功率 > 99%

### 2. 告警规则
- ✅ 支持 10+ 种规则类型
- ✅ 规则配置时间 < 5分钟
- ✅ 规则应用延迟 < 1s

### 3. 安全报告
- ✅ 报告生成时间 < 10s
- ✅ 支持 3+ 种导出格式
- ✅ 报告准确率 100%

### 4. 性能监控
- ✅ 指标采集开销 < 1%
- ✅ 指标查询时间 < 500ms
- ✅ 告警延迟 < 1s

### 5. 虚拟滚动
- ✅ 支持 100000+ 条数据
- ✅ 滚动流畅度 60fps
- ✅ 内存占用 < 100MB

---

**规划时间**: 2026-03-07  
**规划人员**: Kiro AI Assistant  
**预计完成**: 2026-04-07  
**优先级**: P0-P2  
**预计工时**: 20天  

老铁，中期优化计划已经制定完成！这些优化将大幅提升系统的实时性、可配置性和性能表现。🚀
