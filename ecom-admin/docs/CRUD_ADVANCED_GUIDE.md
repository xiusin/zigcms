# CRUD 组件高级功能指南

## 插件系统

### 概述

插件系统允许你扩展 CRUD 组件功能，无需修改核心代码。

### 使用内置插件

```typescript
import { crudPluginManager } from '@/utils/crud-plugins';

// 应用插件
const config = crudPluginManager.apply(baseConfig, [
  'auditLog',    // 审计日志
  'softDelete',  // 软删除
  'mask',        // 字段脱敏
]);
```

### 内置插件列表

| 插件名 | 功能 | 说明 |
|--------|------|------|
| `softDelete` | 软删除 | 标记删除而非物理删除，支持恢复 |
| `auditLog` | 审计日志 | 自动记录创建人、修改人、时间 |
| `cache` | 数据缓存 | 缓存列表数据，减少 API 请求 |
| `optimisticLock` | 乐观锁 | 防止并发编辑冲突 |
| `encrypt` | 数据加密 | 敏感字段自动加密/解密 |
| `mask` | 字段脱敏 | 列表中隐藏敏感信息 |
| `autoSave` | 自动保存 | 表单自动保存草稿 |

### 自定义插件

```typescript
import type { CrudPlugin } from '@/utils/crud-plugins';

const myPlugin: CrudPlugin = {
  name: 'myPlugin',
  version: '1.0.0',
  install: (config) => {
    // 修改配置
    return {
      ...config,
      fields: [
        ...config.fields,
        { name: 'custom_field', label: '自定义字段', type: 'text' },
      ],
    };
  },
  beforeRequest: (data) => {
    // 请求前处理
    console.log('请求数据:', data);
    return data;
  },
  afterResponse: (data) => {
    // 响应后处理
    console.log('响应数据:', data);
    return data;
  },
  onError: (error) => {
    // 错误处理
    console.error('请求错误:', error);
  },
};

// 注册插件
crudPluginManager.register(myPlugin);
```

## 数据导入导出

### 导出数据

```typescript
import { exportData } from '@/utils/crud-import-export';

// 导出 Excel
await exportData('/api/member/list', {
  format: 'excel',
  filename: 'users',
  fields: ['id', 'username', 'email'], // 导出字段
  headers: {
    id: 'ID',
    username: '用户名',
    email: '邮箱',
  },
  filter: { status: 1 }, // 筛选条件
  transform: (data) => {
    // 数据转换
    return data.map(item => ({
      ...item,
      status_text: item.status === 1 ? '启用' : '禁用',
    }));
  },
  onProgress: (progress) => {
    console.log(`导出进度: ${progress}%`);
  },
});

// 导出 CSV
await exportData('/api/member/list', {
  format: 'csv',
  filename: 'users',
});

// 导出 JSON
await exportData('/api/member/list', {
  format: 'json',
  filename: 'users',
});
```

### 导入数据

```typescript
import { importData, generateImportTemplate } from '@/utils/crud-import-export';

// 生成导入模板
generateImportTemplate(fields, 'excel');

// 导入数据
const result = await importData(file, {
  format: 'excel',
  fields: fields,
  validate: (row, index) => {
    // 自定义验证
    if (!row.username) {
      return '用户名不能为空';
    }
    if (!/^1[3-9]\d{9}$/.test(row.mobile)) {
      return '手机号格式不正确';
    }
  },
  transform: (row, index) => {
    // 数据转换
    return {
      ...row,
      status: row.status === '启用' ? 1 : 0,
    };
  },
  onProgress: (progress) => {
    console.log(`导入进度: ${progress}%`);
  },
  onError: (errors) => {
    console.error('导入错误:', errors);
  },
});

console.log(`成功: ${result.success}, 失败: ${result.failed}`);
```

## 性能优化

### 请求合并

```typescript
import { requestQueue } from '@/utils/crud-performance';

// 相同的请求只会执行一次
const data1 = await requestQueue.request('user_list', () =>
  fetch('/api/member/list').then(r => r.json())
);

const data2 = await requestQueue.request('user_list', () =>
  fetch('/api/member/list').then(r => r.json())
);

// data1 和 data2 是同一个请求的结果
```

### 防抖节流

```typescript
import { debounce, throttle } from '@/utils/crud-performance';

// 防抖：延迟执行，多次调用只执行最后一次
const debouncedSearch = debounce((keyword: string) => {
  console.log('搜索:', keyword);
}, 500);

// 节流：限制执行频率
const throttledScroll = throttle(() => {
  console.log('滚动事件');
}, 200);
```

### 批量请求

```typescript
import { batchRequestManager } from '@/utils/crud-performance';

// 多个请求会自动合并为一个批量请求
const user1 = await batchRequestManager.request('1', '/api/member/batch');
const user2 = await batchRequestManager.request('2', '/api/member/batch');
const user3 = await batchRequestManager.request('3', '/api/member/batch');
```

### 虚拟滚动

```typescript
import { VirtualScroller } from '@/utils/crud-performance';

const scroller = new VirtualScroller({
  itemHeight: 50,
  containerHeight: 600,
  buffer: 5,
});

// 获取可见范围
const { start, end } = scroller.getVisibleRange(scrollTop, totalItems);
const visibleItems = allItems.slice(start, end);
```

### 懒加载图片

```typescript
import { LazyImageLoader } from '@/utils/crud-performance';

const loader = new LazyImageLoader();

// 观察图片
const img = document.querySelector('img');
loader.observe(img);

// 清理
onUnmounted(() => {
  loader.disconnect();
});
```

### 数据预加载

```typescript
import { dataPreloader } from '@/utils/crud-performance';

// 预加载数据
await dataPreloader.preload('user_detail_1', () =>
  fetch('/api/member/1').then(r => r.json())
);

// 获取预加载的数据
const data = dataPreloader.get('user_detail_1');
```

### 性能监控

```typescript
import { performanceMonitor } from '@/utils/crud-performance';

// 同步函数
performanceMonitor.start('loadData');
loadData();
const duration = performanceMonitor.end('loadData');
console.log(`耗时: ${duration}ms`);

// 异步函数
await performanceMonitor.measureAsync('fetchData', async () => {
  return await fetch('/api/data').then(r => r.json());
});
```

## 完整示例

### 带插件的 CRUD

```vue
<template>
  <AmisCrud :config="config" id="user_crud" />
</template>

<script setup lang="ts">
import { crudPluginManager } from '@/utils/crud-plugins';

const baseConfig = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [
    { name: 'username', label: '用户名', type: 'text', required: true },
    { name: 'mobile', label: '手机号', type: 'phone', required: true },
    { name: 'email', label: '邮箱', type: 'email' },
    { name: 'status', label: '状态', type: 'switch' },
  ],
};

// 应用插件
const config = crudPluginManager.apply(baseConfig, [
  'auditLog',   // 自动记录创建人、修改人
  'softDelete', // 软删除
  'mask',       // 手机号、邮箱脱敏
]);
</script>
```

### 带导入导出的 CRUD

```vue
<template>
  <div>
    <a-space style="margin-bottom: 16px">
      <a-button @click="handleExport">导出数据</a-button>
      <a-upload
        :custom-request="handleImport"
        :show-file-list="false"
      >
        <a-button>导入数据</a-button>
      </a-upload>
      <a-button @click="downloadTemplate">下载模板</a-button>
    </a-space>
    
    <AmisCrud :config="config" id="user_crud" />
  </div>
</template>

<script setup lang="ts">
import { exportData, importData, generateImportTemplate } from '@/utils/crud-import-export';
import { crudInstanceManager } from '@/utils/crud-event-bus';

const config = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [...],
};

// 导出
const handleExport = async () => {
  await exportData('/api/member/export', {
    format: 'excel',
    filename: 'users',
  });
};

// 导入
const handleImport = async ({ file }: any) => {
  const result = await importData(file, {
    format: 'excel',
    fields: config.fields,
  });
  
  if (result.success > 0) {
    crudInstanceManager.refresh('user_crud');
  }
};

// 下载模板
const downloadTemplate = () => {
  generateImportTemplate(config.fields, 'excel');
};
</script>
```

### 性能优化的 CRUD

```vue
<template>
  <AmisCrud :config="config" id="user_crud" />
</template>

<script setup lang="ts">
import { debounce, requestQueue } from '@/utils/crud-performance';

const config = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [...],
  virtual: true, // 启用虚拟滚动
  virtualThreshold: 100, // 超过 100 条启用
  events: {
    onLoad: debounce((data) => {
      // 防抖处理
      console.log('数据加载完成', data);
    }, 300),
  },
  dataTransform: {
    request: async (data) => {
      // 请求合并
      return await requestQueue.request('user_list', async () => {
        const response = await fetch('/api/member/list', {
          method: 'POST',
          body: JSON.stringify(data),
        });
        return response.json();
      });
    },
  },
};
</script>
```

## 最佳实践

### 1. 插件组合

```typescript
// 推荐组合
const config = crudPluginManager.apply(baseConfig, [
  'auditLog',      // 审计日志（必备）
  'softDelete',    // 软删除（推荐）
  'mask',          // 字段脱敏（安全）
  'optimisticLock', // 乐观锁（并发控制）
]);
```

### 2. 导入验证

```typescript
validate: (row, index) => {
  // 必填验证
  if (!row.username) return '用户名不能为空';
  
  // 格式验证
  if (!/^1[3-9]\d{9}$/.test(row.mobile)) {
    return '手机号格式不正确';
  }
  
  // 业务验证
  if (row.age < 18) return '年龄必须大于18岁';
}
```

### 3. 性能优化策略

```typescript
// 1. 大数据量使用虚拟滚动
virtual: true,
virtualThreshold: 100,

// 2. 搜索使用防抖
onSearch: debounce(handleSearch, 500),

// 3. 滚动使用节流
onScroll: throttle(handleScroll, 200),

// 4. 相同请求合并
dataTransform: {
  request: (data) => requestQueue.request(key, () => fetch(api)),
}
```

### 4. 错误处理

```typescript
events: {
  onError: (error) => {
    // 记录错误
    console.error('CRUD 错误:', error);
    
    // 用户提示
    Message.error(error.message);
    
    // 上报错误
    reportError(error);
  },
}
```

## API 参考

### 插件 API

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `register` | `plugin: CrudPlugin` | `void` | 注册插件 |
| `unregister` | `name: string` | `void` | 卸载插件 |
| `apply` | `config, names?` | `CrudConfig` | 应用插件 |
| `get` | `name: string` | `CrudPlugin?` | 获取插件 |
| `list` | - | `CrudPlugin[]` | 列出所有插件 |

### 导入导出 API

| 函数 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `exportData` | `api, config` | `Promise<void>` | 导出数据 |
| `importData` | `file, config` | `Promise<Result>` | 导入数据 |
| `generateImportTemplate` | `fields, format` | `void` | 生成模板 |

### 性能优化 API

| 类/函数 | 说明 |
|---------|------|
| `requestQueue` | 请求队列管理器 |
| `debounce` | 防抖函数 |
| `throttle` | 节流函数 |
| `batchRequestManager` | 批量请求管理器 |
| `VirtualScroller` | 虚拟滚动器 |
| `LazyImageLoader` | 懒加载图片 |
| `dataPreloader` | 数据预加载器 |
| `performanceMonitor` | 性能监控器 |
