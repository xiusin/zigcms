# 脑图视图增强功能文档

## 概述

本文档描述了质量中心脑图视图的所有增强功能，包括节点搜索、悬停提示、展开折叠动画、自定义主题、PDF 导出和数据对比等高级特性。

## 已实现功能清单

### ✅ 1. 核心功能（任务 28）

#### 1.1 脑图视图页面 (`index.vue`)
- **三种脑图模式**：
  - 模块质量脑图：展示各模块通过率、Bug、用例分布
  - Bug 关联脑图：展示 Bug 与用例/反馈的关联关系
  - 反馈分类脑图：按类型/状态分层展示反馈
- **缩放控制**：
  - 鼠标滚轮缩放（30%-300%）
  - 缩放按钮（放大/缩小/重置）
  - 实时显示缩放比例
- **平移控制**：
  - 鼠标拖拽平移
  - 平滑动画过渡（0.2s）
- **节点交互**：
  - 点击节点跳转详情页
  - 智能识别节点类型（Bug/反馈/模块）
- **数据刷新**：
  - 手动刷新按钮
  - 自动缓存优化（staleTime）
- **AI 分析集成**：
  - 根据当前模式提供 AI 分析建议
  - 上下文感知分析

#### 1.2 脑图画布组件 (`MindMapCanvas.vue`)
- **SVG 渲染**：
  - 高性能矢量图形
  - 自适应布局算法
  - 贝塞尔曲线连接线
- **节点大小自动调整**：
  - 根据文本长度动态调整
  - 根据层级调整样式
- **平滑动画过渡**：
  - 300ms 缓动动画
  - CSS3 硬件加速
- **节点点击事件**：
  - 事件委托优化性能
  - 支持节点数据回调

#### 1.3 脑图节点组件 (`MindMapNode.vue`)
- **节点显示**：
  - 标题显示
  - 统计数据展示（通过率、Bug 数、用例数）
  - 颜色主题支持
- **展开/折叠**：
  - 折叠按钮
  - 子节点数量指示器
  - 折叠状态记忆

### ✅ 2. 增强功能（后续建议）

#### 2.1 节点搜索和高亮
**文件**: `MindMapCanvas.vue`

**功能**：
- 实时搜索节点
- 高亮匹配节点（金色边框 + 脉冲动画）
- 搜索结果导航（上一个/下一个）
- 搜索结果计数显示
- 清除搜索功能

**使用方法**：
```vue
<MindMapCanvas
  :data="mindMapData"
  :searchable="true"
/>
```

**快捷键**：
- `Ctrl+F`: 聚焦搜索框（待实现）
- `Enter`: 下一个结果
- `Shift+Enter`: 上一个结果（待实现）

#### 2.2 节点悬停提示（Tooltip）
**文件**: `MindMapCanvas.vue`

**功能**：
- 鼠标悬停显示详细信息
- 自动定位（跟随鼠标）
- 显示节点统计数据
- 优雅的淡入淡出动画

**数据格式**：
```typescript
interface MindMapNode {
  label: string;
  stats?: {
    '通过率': string;
    'Bug数量': number;
    '用例数': number;
    '反馈数': number;
  };
}
```

#### 2.3 节点展开/折叠动画
**文件**: `MindMapCanvas.vue`

**功能**：
- 点击折叠按钮展开/折叠子节点
- 平滑的展开/折叠动画（300ms）
- 折叠状态持久化
- 全部展开/全部折叠按钮

**API**：
```typescript
// 展开所有节点
expandAll()

// 折叠所有节点
collapseAll()

// 切换单个节点
toggleNodeCollapse(label: string)
```

#### 2.4 自定义颜色主题
**文件**: `MindMapCanvas.vue`

**功能**：
- 5 种预设主题：
  - 默认主题（蓝色系）
  - 海洋主题（青色系）
  - 森林主题（绿色系）
  - 日落主题（紫色系）
  - 秋天主题（橙色系）
- 主题实时切换
- 主题预览色块
- 主题持久化（待实现）

**主题配置**：
```typescript
const themes = [
  {
    name: 'default',
    label: '默认',
    colors: ['#165DFF', '#00B42A', '#F53F3F', '#FF7D00', '#722ED1'],
  },
  // ... 更多主题
];
```

#### 2.5 多格式导出
**文件**: `export.ts`, `index.vue`

**支持格式**：
1. **SVG 导出**：
   - 矢量图形，无损缩放
   - 文件小，加载快
   - 适合打印和编辑

2. **PNG 导出**：
   - 高分辨率位图（2x）
   - 支持水印
   - 适合分享和展示

3. **PDF 导出** ⭐ 新增：
   - 多页支持（自动分页）
   - 支持水印
   - 添加标题和页脚
   - 适合归档和报告

**使用方法**：
```typescript
// SVG 导出
exportMindMapSVG(tree, 'mindmap.svg');

// PNG 导出（含水印）
await exportMindMapPNG(tree, 'mindmap.png', {
  text: 'ZigCMS质量中心',
  opacity: 0.06,
});

// PDF 导出（含水印）
await exportMindMapPDF(tree, 'mindmap.pdf', {
  title: '模块质量脑图',
  orientation: 'landscape',
  watermark: true,
});
```

#### 2.6 数据对比功能 ⭐ 新增
**文件**: `MindMapComparison.vue`

**功能**：
- 时间维度数据对比
- 基准时间 vs 对比时间
- 总体变化统计：
  - 平均通过率变化
  - Bug 总数变化
  - 用例总数变化
  - 质量评分变化
- 详细对比表格：
  - 按模块展示变化
  - 颜色标识正负变化
  - 支持排序和筛选
- 趋势分析图表：
  - ECharts 柱状图
  - 对比可视化
  - 交互式图表

**使用方法**：
```vue
<MindMapComparison :mode="currentMode" />
```

## 性能优化

### 1. 虚拟渲染（待实现）
**场景**: 节点数量超过 100 个时

**优化方案**：
- 只渲染可视区域内的节点
- 使用 Intersection Observer API
- 懒加载子节点

### 2. 缓存优化
**已实现**：
- 数据缓存（staleTime: 5 分钟）
- SVG 内容缓存
- 搜索结果缓存

### 3. 动画性能
**已实现**：
- CSS3 硬件加速（transform, opacity）
- 使用 `will-change` 提示浏览器
- 避免重排重绘（使用 transform 代替 top/left）

## 用户体验优化

### 1. 响应式设计
- 适配桌面端（1920x1080）
- 适配平板端（768x1024）
- 适配移动端（375x667）

### 2. 键盘快捷键（待实现）
- `Ctrl+F`: 搜索
- `Ctrl+S`: 导出
- `Esc`: 关闭弹窗
- `+/-`: 缩放
- `Space`: 拖拽模式

### 3. 无障碍支持（待实现）
- ARIA 标签
- 键盘导航
- 屏幕阅读器支持

## API 文档

### MindMapCanvas 组件

#### Props
```typescript
interface Props {
  data: MindMapNode;           // 脑图数据
  searchable?: boolean;        // 是否启用搜索（默认 true）
  themeable?: boolean;         // 是否启用主题切换（默认 true）
  collapsible?: boolean;       // 是否启用折叠（默认 true）
  initialScale?: number;       // 初始缩放比例（默认 1）
}
```

#### Events
```typescript
interface Emits {
  nodeClick: (node: MindMapNode) => void;      // 节点点击
  nodeHover: (node: MindMapNode | null) => void; // 节点悬停
}
```

#### Methods
```typescript
// 缩放控制
zoomIn(): void;
zoomOut(): void;
resetView(): void;

// 搜索控制
handleSearch(): void;
clearSearch(): void;
nextSearchResult(): void;
prevSearchResult(): void;

// 折叠控制
expandAll(): void;
collapseAll(): void;
toggleNodeCollapse(label: string): void;

// 主题控制
handleThemeChange(themeName: string): void;
```

### MindMapNode 组件

#### Props
```typescript
interface Props {
  node: MindMapNode;           // 节点数据
  level?: number;              // 层级（默认 0）
  collapsed?: boolean;         // 是否折叠（默认 false）
  highlighted?: boolean;       // 是否高亮（默认 false）
  showStats?: boolean;         // 是否显示统计（默认 true）
}
```

#### Events
```typescript
interface Emits {
  click: (node: MindMapNode) => void;
  toggleCollapse: (node: MindMapNode) => void;
  mouseEnter: (node: MindMapNode) => void;
  mouseLeave: (node: MindMapNode) => void;
}
```

### MindMapComparison 组件

#### Props
```typescript
interface Props {
  mode: 'quality' | 'bug-link' | 'feedback'; // 对比模式
}
```

#### Methods
```typescript
// 执行对比
handleCompare(): Promise<void>;

// 导出对比报告
handleExport(): void;
```

## 数据格式

### MindMapNode 接口
```typescript
interface MindMapNode {
  label: string;                              // 节点标签
  children?: MindMapNode[];                   // 子节点
  color?: string;                             // 节点颜色
  stats?: Record<string, string | number>;    // 统计数据
  collapsed?: boolean;                        // 折叠状态
}
```

### 示例数据
```typescript
const mindMapData: MindMapNode = {
  label: '质量中心总览',
  color: '#165DFF',
  stats: {
    '总用例数': 150,
    '总Bug数': 25,
    '平均通过率': '85%',
  },
  children: [
    {
      label: '用户模块',
      color: '#00B42A',
      stats: {
        '通过率': '90%',
        'Bug数': 5,
        '用例数': 30,
      },
      children: [
        { label: '登录功能', stats: { '通过率': '95%' } },
        { label: '注册功能', stats: { '通过率': '88%' } },
      ],
    },
    // ... 更多模块
  ],
};
```

## 最佳实践

### 1. 数据准备
```typescript
// ✅ 推荐：使用工具函数构建脑图数据
const tree = buildQualityMindMap(moduleQuality, '模块质量总览');

// ❌ 避免：手动构建复杂的嵌套结构
const tree = {
  label: '...',
  children: [
    { label: '...', children: [...] },
    // 容易出错
  ],
};
```

### 2. 性能优化
```typescript
// ✅ 推荐：使用 Arena Allocator 批量处理
const result = await q.getWithArena(arena_allocator);

// ✅ 推荐：使用关系预加载避免 N+1 查询
_ = q.with(&.{"menus", "permissions"});

// ❌ 避免：在循环中查询数据库
for (items) |item| {
  const related = await fetchRelated(item.id); // N+1 问题
}
```

### 3. 用户体验
```typescript
// ✅ 推荐：提供加载状态
loading.value = true;
try {
  await fetchData();
} finally {
  loading.value = false;
}

// ✅ 推荐：提供操作反馈
Message.success('导出成功');
Message.error('导出失败');

// ✅ 推荐：使用防抖优化搜索
const debouncedSearch = debounce(handleSearch, 300);
```

## 故障排查

### 问题 1: 脑图不显示
**原因**: 数据格式错误或为空

**解决方案**：
```typescript
// 检查数据格式
console.log('脑图数据:', JSON.stringify(mindMapData, null, 2));

// 确保至少有根节点
if (!mindMapData || !mindMapData.label) {
  mindMapData = { label: '空数据', children: [] };
}
```

### 问题 2: 节点点击无响应
**原因**: 事件委托失败或 data-label 属性缺失

**解决方案**：
```typescript
// 确保 SVG 元素有 data-label 属性
nodes += `<rect ... data-label="${escapeXml(node.label)}" />`;

// 检查事件监听
const target = e.target as SVGElement;
const label = target.getAttribute('data-label');
console.log('点击节点:', label);
```

### 问题 3: 导出失败
**原因**: 浏览器兼容性或权限问题

**解决方案**：
```typescript
// 添加错误处理
try {
  await exportMindMapPDF(tree, filename);
} catch (error) {
  console.error('导出失败:', error);
  Message.error(`导出失败: ${error.message}`);
}

// 检查浏览器支持
if (!document.createElement('canvas').getContext) {
  Message.error('浏览器不支持 Canvas，无法导出');
}
```

## 未来规划

### 短期（1-2 周）
- [ ] 实现虚拟渲染（节点 > 100 时）
- [ ] 添加键盘快捷键支持
- [ ] 实现主题持久化
- [ ] 优化移动端体验

### 中期（1 个月）
- [ ] 添加节点拖拽重排功能
- [ ] 实现自定义节点样式
- [ ] 添加连接线动画效果
- [ ] 支持批量导出多个模式

### 长期（3 个月）
- [ ] 实现协作编辑功能
- [ ] 添加版本历史记录
- [ ] 支持自定义脑图模板
- [ ] 集成 AI 自动生成脑图

## 参考资源

- [ECharts 文档](https://echarts.apache.org/zh/index.html)
- [jsPDF 文档](https://github.com/parallax/jsPDF)
- [html2canvas 文档](https://html2canvas.hertzen.com/)
- [Arco Design Vue 文档](https://arco.design/vue/docs/start)

## 更新日志

### v1.2.0 (2026-03-05)
- ✨ 新增节点搜索和高亮功能
- ✨ 新增节点悬停提示（Tooltip）
- ✨ 新增节点展开/折叠动画
- ✨ 新增 5 种自定义颜色主题
- ✨ 新增 PDF 格式导出
- ✨ 新增数据对比功能
- 🐛 修复节点点击事件冒泡问题
- 🐛 修复缩放时节点位置偏移
- ⚡ 优化 SVG 渲染性能
- 📝 完善文档和示例

### v1.1.0 (2026-03-04)
- ✨ 实现三种脑图模式
- ✨ 实现缩放和平移控制
- ✨ 实现节点点击跳转
- ✨ 实现 SVG/PNG 导出
- ✨ 集成 AI 分析

### v1.0.0 (2026-03-03)
- 🎉 初始版本发布
- ✨ 基础脑图渲染功能
- ✨ 数据统计卡片
- ✨ 水印支持

---

**维护者**: ZigCMS 团队  
**最后更新**: 2026-03-05  
**文档版本**: v1.2.0
