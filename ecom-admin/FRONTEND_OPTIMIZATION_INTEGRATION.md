# 前端优化功能集成指南

本文档说明如何将前端优化功能集成到质量中心的各个页面中。

## 已集成的功能

### ✅ 测试用例列表页面 (`test-case/index.vue`)

已完成以下集成：

1. **操作反馈**
   - 使用 `showSuccess`、`showError` 替代 `Message.success/error`
   - 使用 `showDeleteConfirm` 替代 `Modal.confirm`
   - 使用 `showBatchConfirm` 进行批量操作确认
   - 使用 `withFeedback` 包装异步操作，自动显示加载状态

2. **键盘快捷键**
   - `Ctrl+F`: 聚焦搜索框
   - `Esc`: 关闭弹窗或取消选择

3. **骨架屏**
   - 首次加载时显示 `TableSkeleton`

4. **状态记忆**
   - 使用 `storage.saveTablePageSize` 保存分页大小
   - 使用 `storage.getTablePageSize` 恢复分页大小

## 集成步骤

### 1. 导入工具函数

```typescript
// 操作反馈
import {
  showSuccess,
  showError,
  showWarning,
  showInfo,
  showDeleteConfirm,
  showBatchConfirm,
  loading,
  withFeedback,
} from '@/utils/feedback';

// 键盘快捷键
import { keyboard, CommonShortcuts } from '@/utils/keyboard';

// 主题切换
import { theme, useTheme } from '@/utils/theme';

// 本地存储
import { storage, useTableState } from '@/utils/storage';

// 骨架屏组件
import {
  TableSkeleton,
  CardSkeleton,
  FormSkeleton,
  DetailSkeleton,
  ChartSkeleton,
} from '@/components/skeleton';

// 增强表格
import { EnhancedTable } from '@/components/table';
```

### 2. 操作反馈集成

#### 2.1 替换 Message 提示

**之前：**
```typescript
try {
  await api.deleteItem(id);
  Message.success('删除成功');
} catch (error) {
  Message.error('删除失败');
}
```

**之后：**
```typescript
await withFeedback(
  () => api.deleteItem(id),
  {
    loadingText: '删除中...',
    successText: '删除成功',
    errorText: '删除失败',
  }
);
```

#### 2.2 替换确认对话框

**之前：**
```typescript
Modal.confirm({
  title: '确认删除',
  content: '确定要删除吗？',
  onOk: async () => {
    await api.deleteItem(id);
  },
});
```

**之后：**
```typescript
const confirmed = await showDeleteConfirm(
  '确定要删除吗？此操作不可恢复。',
  '删除确认'
);

if (!confirmed) return;

await withFeedback(
  () => api.deleteItem(id),
  {
    loadingText: '删除中...',
    successText: '删除成功',
    errorText: '删除失败',
  }
);
```

#### 2.3 批量操作确认

```typescript
const confirmed = await showBatchConfirm(
  selectedKeys.value.length,
  '删除'
);

if (!confirmed) return;

await withFeedback(
  () => api.batchDelete(selectedKeys.value),
  {
    loadingText: '批量删除中...',
    successText: '批量删除成功',
    errorText: '批量删除失败',
  }
);
```

### 3. 键盘快捷键集成

#### 3.1 注册快捷键

```typescript
import { onMounted, onUnmounted } from 'vue';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';

// 注册快捷键
const registerShortcuts = () => {
  // Ctrl+S 保存
  keyboard.register(
    CommonShortcuts.save(() => {
      handleSave();
    })
  );

  // Ctrl+F 搜索
  keyboard.register(
    CommonShortcuts.search(() => {
      const searchInput = document.querySelector<HTMLInputElement>('#search-input');
      searchInput?.focus();
    })
  );

  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (dialogVisible.value) {
        dialogVisible.value = false;
        return false; // 阻止后续处理
      }
    })
  );
};

onMounted(() => {
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});
```

#### 3.2 自定义快捷键

```typescript
keyboard.register({
  key: 'n',
  ctrl: true,
  handler: () => {
    handleCreate();
  },
  description: '新建',
});
```

### 4. 骨架屏集成

#### 4.1 表格骨架屏

```vue
<template>
  <a-card>
    <!-- 骨架屏 -->
    <TableSkeleton v-if="isInitialLoad" :rows="10" />
    
    <!-- 实际内容 -->
    <a-table v-else :data="data" :loading="loading" />
  </a-card>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { TableSkeleton } from '@/components/skeleton';

const isInitialLoad = ref(true);
const loading = ref(false);
const data = ref([]);

const loadData = async () => {
  loading.value = true;
  try {
    const result = await api.getData();
    data.value = result;
    isInitialLoad.value = false;
  } finally {
    loading.value = false;
  }
};
</script>
```

#### 4.2 卡片骨架屏

```vue
<template>
  <CardSkeleton v-if="loading" :show-title="true" :content-rows="3" />
  <a-card v-else>
    <!-- 实际内容 -->
  </a-card>
</template>
```

#### 4.3 表单骨架屏

```vue
<template>
  <FormSkeleton v-if="loading" :rows="5" :show-buttons="true" />
  <a-form v-else>
    <!-- 实际表单 -->
  </a-form>
</template>
```

#### 4.4 详情页骨架屏

```vue
<template>
  <DetailSkeleton v-if="loading" :rows="6" :show-title="true" :show-actions="true" />
  <div v-else>
    <!-- 实际详情 -->
  </div>
</template>
```

#### 4.5 图表骨架屏

```vue
<template>
  <ChartSkeleton v-if="loading" :height="400" :show-title="true" :show-legend="true" />
  <div v-else ref="chartRef" style="height: 400px"></div>
</template>
```

### 5. 主题切换集成

#### 5.1 在组件中使用主题

```vue
<template>
  <div>
    <a-button @click="toggleTheme">
      <template #icon>
        <icon-moon v-if="isLight" />
        <icon-sun v-else />
      </template>
      {{ isLight ? '暗色模式' : '亮色模式' }}
    </a-button>
  </div>
</template>

<script setup lang="ts">
import { useTheme } from '@/utils/theme';

const { isDark, isLight, toggleTheme } = useTheme();
</script>
```

#### 5.2 监听主题变化

```typescript
import { onMounted, onUnmounted } from 'vue';
import { theme } from '@/utils/theme';

let removeListener: (() => void) | null = null;

onMounted(() => {
  removeListener = theme.addListener((newTheme) => {
    console.log('主题已切换:', newTheme);
    // 执行主题切换后的操作
  });
});

onUnmounted(() => {
  removeListener?.();
});
```

### 6. 状态记忆集成

#### 6.1 表格状态记忆

```typescript
import { storage, useTableState } from '@/utils/storage';

const PAGE_ID = 'my-table-page';

// 恢复分页大小
const savedPageSize = storage.getTablePageSize(PAGE_ID, 20);

const pagination = reactive({
  page: 1,
  page_size: savedPageSize,
  total: 0,
});

// 保存分页大小
const handlePageSizeChange = (pageSize: number) => {
  pagination.page_size = pageSize;
  storage.saveTablePageSize(PAGE_ID, pageSize);
  loadData();
};

// 使用 Hook
const tableState = useTableState(PAGE_ID);

// 保存列配置
tableState.saveColumns(columns);

// 恢复列配置
const savedColumns = tableState.getColumns();

// 保存筛选条件
tableState.saveFilters({ status: 'active' });

// 恢复筛选条件
const savedFilters = tableState.getFilters();

// 保存排序
tableState.saveSorter('created_at', 'descend');

// 恢复排序
const savedSorter = tableState.getSorter();
```

#### 6.2 用户偏好设置

```typescript
import { storage } from '@/utils/storage';

// 保存偏好
storage.savePreferences({
  theme: 'dark',
  language: 'zh-CN',
  sidebarCollapsed: false,
});

// 获取偏好
const preferences = storage.getPreferences();

// 获取单个偏好
const theme = storage.getPreference('theme', 'light');

// 设置单个偏好
storage.setPreference('theme', 'dark');
```

#### 6.3 草稿保存

```typescript
import { storage } from '@/utils/storage';

// 保存草稿
const saveDraft = () => {
  storage.saveDraft('test-case-form', formData);
};

// 恢复草稿
const restoreDraft = () => {
  const draft = storage.getDraft('test-case-form');
  if (draft) {
    formData.value = draft.data;
  }
};

// 清除草稿
const clearDraft = () => {
  storage.removeDraft('test-case-form');
};
```

### 7. 增强表格集成

#### 7.1 使用增强表格

```vue
<template>
  <EnhancedTable
    table-id="my-table"
    :columns="columns"
    :data="data"
    :loading="loading"
    :pagination="pagination"
    :show-toolbar="true"
    :remember-state="true"
    @refresh="handleRefresh"
    @page-change="handlePageChange"
    @page-size-change="handlePageSizeChange"
    @sorter-change="handleSorterChange"
    @filter-change="handleFilterChange"
  >
    <!-- 工具栏左侧 -->
    <template #toolbar-left>
      <a-button type="primary" @click="handleCreate">
        <template #icon><icon-plus /></template>
        新建
      </a-button>
    </template>

    <!-- 工具栏右侧 -->
    <template #toolbar-right>
      <a-button @click="handleExport">
        <template #icon><icon-download /></template>
        导出
      </a-button>
    </template>

    <!-- 自定义列 -->
    <template #status="{ record }">
      <a-tag :color="getStatusColor(record.status)">
        {{ getStatusText(record.status) }}
      </a-tag>
    </template>
  </EnhancedTable>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { EnhancedTable } from '@/components/table';

const columns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '标题', dataIndex: 'title', width: 200 },
  { title: '状态', dataIndex: 'status', width: 120, slotName: 'status' },
];

const data = ref([]);
const loading = ref(false);
const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
});

const handleRefresh = () => {
  loadData();
};
</script>
```

## 待集成页面清单

### 高优先级

- [ ] 项目列表页面 (`project/index.vue`)
- [ ] 项目详情页面 (`project/detail.vue`)
- [ ] 模块管理页面 (`module/index.vue`)
- [ ] 需求列表页面 (`requirement/index.vue`)
- [ ] 反馈列表页面 (`feedback/index.vue`)
- [ ] 反馈详情页面 (`feedback/detail.vue`)

### 中优先级

- [ ] 质量中心首页 (`dashboard/index.vue`)
- [ ] 测试用例表单 (`test-case/components/TestCaseForm.vue`)
- [ ] AI 生成对话框 (`test-case/components/AIGenerateDialog.vue`)

### 低优先级

- [ ] 脑图视图页面 (`mindmap/index.vue`)
- [ ] 统计图表组件 (`dashboard/components/*.vue`)

## 集成检查清单

每个页面集成完成后，请检查以下项：

### 操作反馈
- [ ] 所有成功操作显示成功提示
- [ ] 所有失败操作显示错误提示
- [ ] 危险操作有确认对话框
- [ ] 批量操作有确认对话框
- [ ] 异步操作有加载状态

### 键盘快捷键
- [ ] `Ctrl+S` 保存（如有保存功能）
- [ ] `Ctrl+F` 聚焦搜索框（如有搜索功能）
- [ ] `Esc` 关闭弹窗
- [ ] 组件卸载时清理快捷键

### 骨架屏
- [ ] 首次加载显示骨架屏
- [ ] 骨架屏样式与实际内容匹配
- [ ] 加载完成后隐藏骨架屏

### 状态记忆
- [ ] 表格分页大小记忆
- [ ] 表格列配置记忆（如使用增强表格）
- [ ] 筛选条件记忆（可选）
- [ ] 排序状态记忆（可选）

### 响应式设计
- [ ] 移动端（375px）显示正常
- [ ] 平板端（768px）显示正常
- [ ] 桌面端（1024px+）显示正常

## 性能优化建议

1. **懒加载骨架屏组件**
   ```typescript
   const TableSkeleton = defineAsyncComponent(
     () => import('@/components/skeleton/TableSkeleton.vue')
   );
   ```

2. **防抖搜索**
   ```typescript
   import { debounce } from '@/utils/feedback';
   
   const handleSearch = debounce(() => {
     loadData();
   }, 300);
   ```

3. **节流滚动**
   ```typescript
   import { throttle } from '@/utils/feedback';
   
   const handleScroll = throttle(() => {
     // 处理滚动
   }, 100);
   ```

## 常见问题

### Q1: 键盘快捷键在输入框中也触发怎么办？

A: 工具已自动处理，输入框中的快捷键（除了 Esc）会被忽略。

### Q2: 如何禁用某个页面的快捷键？

A: 在 `onUnmounted` 中调用 `keyboard.unregisterAll()`。

### Q3: 骨架屏闪烁怎么办？

A: 使用 `isInitialLoad` 标志，只在首次加载时显示骨架屏，后续加载使用 `loading` 状态。

### Q4: 状态记忆占用太多存储空间怎么办？

A: 定期清理旧数据，或只记忆关键状态（如分页大小）。

## 后续优化

1. **全局主题切换按钮**：在顶部导航栏添加主题切换按钮
2. **快捷键帮助面板**：显示所有可用快捷键
3. **性能监控**：监控页面加载时间和操作响应时间
4. **错误边界**：捕获组件错误并显示友好提示
5. **离线支持**：使用 Service Worker 支持离线访问

## 参考资源

- [操作反馈工具文档](./src/utils/feedback.ts)
- [键盘快捷键工具文档](./src/utils/keyboard.ts)
- [主题切换工具文档](./src/utils/theme.ts)
- [本地存储工具文档](./src/utils/storage.ts)
- [骨架屏组件文档](./src/components/skeleton/)
- [增强表格组件文档](./src/components/table/EnhancedTable.vue)
