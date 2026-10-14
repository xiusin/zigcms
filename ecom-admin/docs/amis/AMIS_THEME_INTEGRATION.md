# Amis 主题与 Arco Design 集成方案

## 问题分析

之前的实现存在以下问题:

1. **硬编码颜色值**: 在 JS 中使用硬编码的 hex 颜色,无法响应 Arco Design 的主题变量变化
2. **内联样式注入**: 通过 JS 动态注入 2000+ 行 CSS,性能差且难以维护
3. **组件映射不完整**: 只覆盖了部分 Amis 组件,导致样式不一致
4. **字体大小不统一**: Amis 默认字体与项目的 12px 标准不一致

## 解决方案

### 1. 样式文件分离

创建独立的 Less 样式文件,完全基于 Arco Design 的 CSS 变量:

```
src/assets/style/
├── amis-theme.less       # 亮色主题样式
├── amis-theme-dark.less  # 暗色主题样式
└── global.less           # 引入 Amis 主题
```

### 2. 使用 Arco Design Token

所有颜色、间距、圆角等设计 token 完全使用 Arco Design 的 CSS 变量:

```less
// 亮色主题示例
.amis-wrapper .cxd-Button--primary {
  background-color: var(--color-primary) !important;
  border-color: var(--color-primary) !important;
  color: #FFFFFF !important;
}

// 暗色主题示例
.amis-wrapper .dark-Button--primary {
  background-color: var(--color-primary) !important;
  border-color: var(--color-primary) !important;
  color: #FFFFFF !important;
}
```

### 3. 完整的组件映射

覆盖了所有常用 Amis 组件,确保样式一致性:

#### 基础组件
- Page, Service, Wrapper (容器)
- Card, Panel (卡片)
- Form, Input, Textarea, Select (表单)
- Button, Action (按钮)
- Table, Pagination (表格)
- Modal, Drawer (弹窗)

#### 反馈组件
- Alert, Toast, Notify (提示)
- Tag, Badge (标签)
- Progress, Spinner (进度)
- Empty (空状态)

#### 导航组件
- Tabs, Breadcrumb, Nav (导航)
- Steps (步骤条)

#### 数据展示
- Tree (树形)
- Timeline (时间线)
- Calendar (日历)
- Json, Code (代码)

### 4. 设计规范统一

| 设计元素 | Arco Design | Amis 应用 |
|---------|-------------|----------|
| 字体大小 | 12px | 统一 12px |
| 圆角 | 4px/6px/8px | 统一使用 Arco 圆角 |
| 按钮高度 | 32px | 统一 32px |
| 输入框高度 | 32px | 统一 32px |
| 间距 | 4/8/12/16/20px | 统一使用 Arco 间距 |
| 阴影 | Arco 阴影系统 | 统一使用 Arco 阴影 |

### 5. 主题切换响应

通过 CSS 变量自动响应主题切换,无需 JS 干预:

```vue
<!-- Amis 组件会自动跟随 Arco Design 主题 -->
<AmisRenderer :schema="schema" theme="auto" />
```

## 文件变更

### 新增文件

1. `src/assets/style/amis-theme.less` - 亮色主题样式 (约 400 行)
2. `src/assets/style/amis-theme-dark.less` - 暗色主题样式 (约 450 行)

### 修改文件

1. `src/assets/style/global.less` - 引入 Amis 主题样式
2. `src/components/amis/index.vue` - 移除内联样式注入逻辑 (删除 2000+ 行)

## 优势

### 性能提升
- ✅ 移除 JS 动态注入 CSS (2000+ 行)
- ✅ 样式在构建时编译,运行时零开销
- ✅ 浏览器可以缓存 CSS 文件

### 可维护性
- ✅ 样式集中管理,易于查找和修改
- ✅ 使用 Less 变量和嵌套,代码更简洁
- ✅ 完全基于 Arco Design Token,主题一致性有保障

### 视觉一致性
- ✅ 所有组件使用统一的设计 token
- ✅ 字体大小、圆角、间距完全统一
- ✅ 主题切换无缝响应

### 开发体验
- ✅ 修改样式只需编辑 Less 文件
- ✅ 支持热更新,实时预览
- ✅ 类型安全,避免拼写错误

## 使用示例

### 基础使用

```vue
<template>
  <AmisRenderer :schema="schema" />
</template>

<script setup>
import { AmisRenderer } from '@/components/amis'

const schema = {
  type: 'page',
  title: '用户列表',
  body: {
    type: 'crud',
    api: '/api/users',
    columns: [
      { name: 'id', label: 'ID' },
      { name: 'username', label: '用户名' },
      { name: 'email', label: '邮箱' }
    ]
  }
}
</script>
```

### 自定义主题

```vue
<!-- 强制使用亮色主题 -->
<AmisRenderer :schema="schema" theme="cxd" />

<!-- 强制使用暗色主题 -->
<AmisRenderer :schema="schema" theme="dark" />

<!-- 自动跟随 Arco Design 主题 (默认) -->
<AmisRenderer :schema="schema" theme="auto" />
```

## 样式覆盖优先级

```
Amis 默认样式 < amis-theme.less < amis-theme-dark.less < 页面自定义样式
```

如需自定义特定页面的 Amis 样式,可以在页面组件的 `<style>` 中覆盖:

```vue
<style scoped>
.amis-wrapper .cxd-Button--primary {
  background-color: #FF6B6B !important;
}
</style>
```

## 注意事项

1. **不要删除 Amis 官方 CSS**: `sdk.css` 和 `dark_32627ff.css` 仍需加载,我们的样式是在此基础上覆盖
2. **使用 !important**: 由于 Amis 样式优先级较高,覆盖时需要使用 `!important`
3. **主题切换**: 确保 Arco Design 的主题切换正常工作,Amis 会自动跟随
4. **浏览器兼容性**: CSS 变量需要现代浏览器支持 (IE11 不支持)

## 测试清单

- [ ] 亮色主题下所有组件样式正常
- [ ] 暗色主题下所有组件样式正常
- [ ] 主题切换时 Amis 组件样式同步更新
- [ ] 字体大小统一为 12px
- [ ] 按钮、输入框高度统一为 32px
- [ ] 圆角、间距符合 Arco Design 规范
- [ ] 表格、表单、弹窗等复杂组件样式正常
- [ ] 页面配置预览功能正常

## 后续优化

1. **按需加载**: 可以根据使用的 Amis 组件按需加载样式
2. **主题定制**: 支持通过配置文件自定义 Amis 主题
3. **组件扩展**: 为特定业务场景定制 Amis 组件样式
4. **性能监控**: 监控样式加载和渲染性能

## 参考资料

- [Arco Design 设计 Token](https://arco.design/vue/docs/token)
- [Amis 官方文档](https://aisuda.bce.baidu.com/amis/zh-CN/docs/index)
- [Amis 主题定制](https://aisuda.bce.baidu.com/amis/zh-CN/docs/extend/theme)
