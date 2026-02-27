# CRUD 组件业务交互指南

## 概述

CRUD 组件提供了完整的事件系统、状态管理和数据联动功能，支持与其他页面进行深度业务交互。

## 核心功能

### 1. 事件系统

#### 全局事件总线

```typescript
import { crudEventBus, CrudEvents } from '@/utils/crud-event-bus';

// 订阅数据加载事件
crudEventBus.on(CrudEvents.DATA_LOADED, ({ id, data }) => {
  console.log(`CRUD ${id} 数据已加载:`, data);
});

// 订阅数据更新事件
crudEventBus.on(CrudEvents.DATA_UPDATED, ({ id, data }) => {
  console.log(`CRUD ${id} 数据已更新:`, data);
  // 刷新其他相关 CRUD
  crudInstanceManager.refresh('related_crud_id');
});

// 一次性订阅
crudEventBus.once(CrudEvents.DATA_ADDED, ({ id, data }) => {
  console.log('首次添加数据:', data);
});
```

#### 组件内事件配置

```vue
<template>
  <AmisCrud
    :config="crudConfig"
    id="user_crud"
  />
</template>

<script setup lang="ts">
const crudConfig = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [...],
  events: {
    // 初始化完成
    onInit: (config) => {
      console.log('CRUD 初始化完成', config);
    },
    
    // 数据加载完成
    onLoad: (data) => {
      console.log('数据加载完成', data);
    },
    
    // 新增前处理
    onAdd: async (data) => {
      // 可以修改数据或执行验证
      data.created_by = userStore.username;
    },
    
    // 新增成功
    onAddSuccess: (data) => {
      Message.success('添加成功');
      // 刷新其他相关列表
      crudInstanceManager.refresh('department_crud');
    },
    
    // 编辑前处理
    onEdit: async (data) => {
      // 权限检查
      if (!hasPermission('user:edit')) {
        Message.error('无编辑权限');
        throw new Error('无权限');
      }
    },
    
    // 编辑成功
    onEditSuccess: (data) => {
      Message.success('编辑成功');
    },
    
    // 删除前确认
    onDelete: async (data) => {
      // 返回 false 阻止删除
      if (data.is_system) {
        Message.warning('系统数据不可删除');
        return false;
      }
      return true;
    },
    
    // 删除成功
    onDeleteSuccess: (data) => {
      Message.success('删除成功');
    },
    
    // 批量操作
    onBulkAction: (action, items) => {
      console.log(`批量${action}`, items);
    },
    
    // 行点击
    onRowClick: (row) => {
      router.push(`/user/detail/${row.id}`);
    },
    
    // 选择变化
    onSelectionChange: (rows) => {
      console.log('已选择', rows.length, '条数据');
    },
  },
};
</script>
```

### 2. 状态管理

```typescript
import { crudStateManager } from '@/utils/crud-event-bus';

// 获取 CRUD 状态
const state = crudStateManager.get('user_crud');
console.log('当前页码:', state?.page);
console.log('选中行:', state?.selectedRows);

// 更新状态
crudStateManager.update('user_crud', {
  filters: { status: 1 },
});

// 监听状态变化
crudEventBus.on('crud:state:user_crud', (state) => {
  console.log('状态已更新:', state);
});
```

### 3. 实例管理

```typescript
import { crudInstanceManager } from '@/utils/crud-event-bus';

// 刷新指定 CRUD（保持筛选条件）
crudInstanceManager.refresh('user_crud');

// 重新加载（清空筛选条件）
crudInstanceManager.reload('user_crud');

// 获取选中行
const selectedRows = crudInstanceManager.getSelectedRows('user_crud');

// 清空选择
crudInstanceManager.clearSelection('user_crud');
```

### 4. 数据联动

```typescript
import { crudLinkageManager } from '@/utils/crud-event-bus';

// 添加联动规则：选择部门后，用户列表自动筛选
crudLinkageManager.addRule({
  source: 'department_crud', // 源 CRUD
  target: 'user_crud',       // 目标 CRUD
  sourceField: 'id',         // 源字段
  targetField: 'dept_id',    // 目标字段
  transform: (value) => value, // 数据转换（可选）
});

// 监听联动事件
crudEventBus.on('crud:linkage:user_crud', ({ field, value }) => {
  // 更新用户列表筛选条件
  crudStateManager.update('user_crud', {
    filters: { [field]: value },
  });
  crudInstanceManager.refresh('user_crud');
});
```

### 5. 自定义操作

```typescript
const crudConfig = {
  title: '订单管理',
  api: '/api/order/list',
  fields: [...],
  customActions: [
    {
      label: '导出报表',
      icon: 'download',
      level: 'primary',
      position: 'toolbar', // 工具栏按钮
      onClick: async () => {
        const rows = crudInstanceManager.getSelectedRows('order_crud');
        if (rows.length === 0) {
          Message.warning('请先选择数据');
          return;
        }
        await exportReport(rows);
      },
    },
    {
      label: '发货',
      icon: 'truck',
      level: 'success',
      position: 'row', // 行操作按钮
      visible: (row) => row.status === 'paid', // 仅已支付订单显示
      onClick: async (row) => {
        await shipOrder(row.id);
        crudInstanceManager.refresh('order_crud');
      },
    },
  ],
};
```

### 6. 数据转换

```typescript
const crudConfig = {
  title: '商品管理',
  api: '/api/product/list',
  fields: [...],
  dataTransform: {
    // 请求前转换
    request: (data) => {
      // 价格转换为分
      if (data.price) {
        data.price = Math.round(data.price * 100);
      }
      return data;
    },
    // 响应后转换
    response: (data) => {
      // 价格转换为元
      if (data.items) {
        data.items = data.items.map(item => ({
          ...item,
          price: item.price / 100,
        }));
      }
      return data;
    },
  },
};
```

### 7. 自定义验证

```typescript
const crudConfig = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [...],
  validation: {
    rules: {
      username: (value, data) => {
        if (!/^[a-zA-Z0-9_]{4,20}$/.test(value)) {
          return '用户名必须是4-20位字母、数字或下划线';
        }
      },
      email: (value, data) => {
        if (!/^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$/.test(value)) {
          return '邮箱格式不正确';
        }
      },
      password: (value, data) => {
        if (data.id) return; // 编辑时不验证密码
        if (value.length < 6) {
          return '密码至少6位';
        }
      },
    },
  },
};
```

## 实战场景

### 场景1：主从表联动

```vue
<template>
  <div class="master-detail">
    <!-- 主表：部门列表 -->
    <AmisCrud
      :config="deptConfig"
      id="dept_crud"
      class="master"
    />
    
    <!-- 从表：部门下的用户 -->
    <AmisCrud
      :config="userConfig"
      id="user_crud"
      class="detail"
    />
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { crudEventBus, CrudEvents } from '@/utils/crud-event-bus';

const deptConfig = {
  title: '部门列表',
  api: '/api/department/list',
  fields: [...],
  events: {
    onRowClick: (row) => {
      // 点击部门，加载该部门的用户
      crudEventBus.emit('dept:selected', row.id);
    },
  },
};

const userConfig = {
  title: '部门用户',
  api: '/api/member/list',
  fields: [...],
};

// 监听部门选择
const handleDeptSelected = (deptId: number) => {
  crudStateManager.update('user_crud', {
    filters: { dept_id: deptId },
  });
  crudInstanceManager.refresh('user_crud');
};

onMounted(() => {
  crudEventBus.on('dept:selected', handleDeptSelected);
});

onUnmounted(() => {
  crudEventBus.off('dept:selected', handleDeptSelected);
});
</script>
```

### 场景2：跨页面数据同步

```typescript
// 页面 A：用户管理
const userConfig = {
  title: '用户管理',
  api: '/api/member/list',
  fields: [...],
  events: {
    onAddSuccess: (data) => {
      // 通知其他页面用户已添加
      crudEventBus.emit('user:added', data);
    },
    onEditSuccess: (data) => {
      crudEventBus.emit('user:updated', data);
    },
  },
};

// 页面 B：订单管理
onMounted(() => {
  // 监听用户更新，刷新订单列表
  crudEventBus.on('user:updated', (user) => {
    crudInstanceManager.refresh('order_crud');
  });
});
```

### 场景3：批量操作确认

```typescript
const orderConfig = {
  title: '订单管理',
  api: '/api/order/list',
  fields: [...],
  bulkActions: [
    {
      label: '批量发货',
      action: 'ship',
      confirm: true,
      api: '/api/order/bulk-ship',
    },
  ],
  events: {
    onBulkAction: async (action, items) => {
      if (action === 'ship') {
        // 检查是否都是已支付状态
        const unpaid = items.filter(item => item.status !== 'paid');
        if (unpaid.length > 0) {
          Message.error(`有 ${unpaid.length} 个订单未支付，无法发货`);
          return;
        }
        
        // 执行批量发货
        await bulkShipOrders(items.map(item => item.id));
        Message.success('批量发货成功');
        crudInstanceManager.refresh('order_crud');
      }
    },
  },
};
```

## 最佳实践

### 1. 使用唯一 ID

```vue
<!-- ✅ 推荐：使用唯一 ID -->
<AmisCrud :config="config" id="user_crud" />

<!-- ❌ 不推荐：不指定 ID -->
<AmisCrud :config="config" />
```

### 2. 及时清理事件监听

```typescript
onMounted(() => {
  crudEventBus.on('custom:event', handler);
});

onUnmounted(() => {
  crudEventBus.off('custom:event', handler);
});
```

### 3. 使用 ref 访问实例方法

```vue
<template>
  <AmisCrud ref="crudRef" :config="config" />
  <a-button @click="handleRefresh">刷新</a-button>
</template>

<script setup lang="ts">
const crudRef = ref();

const handleRefresh = () => {
  crudRef.value?.refresh();
};
</script>
```

### 4. 错误处理

```typescript
const config = {
  events: {
    onAdd: async (data) => {
      try {
        await validateData(data);
      } catch (error) {
        Message.error(error.message);
        throw error; // 阻止提交
      }
    },
  },
};

// 监听错误事件
crudEventBus.on(CrudEvents.ERROR, ({ id, error }) => {
  console.error(`CRUD ${id} 错误:`, error);
});
```

## API 参考

### CrudConfig 新增配置

| 配置项 | 类型 | 说明 |
|--------|------|------|
| `events` | `Object` | 事件回调配置 |
| `dataTransform` | `Object` | 数据转换配置 |
| `linkage` | `Array` | 数据联动配置 |
| `validation` | `Object` | 自定义验证配置 |
| `customActions` | `Array` | 自定义操作按钮 |

### 事件类型

| 事件 | 参数 | 说明 |
|------|------|------|
| `onInit` | `(config)` | 初始化完成 |
| `onLoad` | `(data)` | 数据加载完成 |
| `onAdd` | `(data)` | 新增前 |
| `onAddSuccess` | `(data)` | 新增成功 |
| `onEdit` | `(data)` | 编辑前 |
| `onEditSuccess` | `(data)` | 编辑成功 |
| `onDelete` | `(data)` | 删除前 |
| `onDeleteSuccess` | `(data)` | 删除成功 |
| `onBulkAction` | `(action, items)` | 批量操作 |
| `onRowClick` | `(row)` | 行点击 |
| `onSelectionChange` | `(rows)` | 选择变化 |

### 实例方法

| 方法 | 参数 | 说明 |
|------|------|------|
| `refresh()` | - | 刷新数据（保持筛选） |
| `reload()` | - | 重新加载（清空筛选） |
| `getSelectedRows()` | - | 获取选中行 |
| `clearSelection()` | - | 清空选择 |
