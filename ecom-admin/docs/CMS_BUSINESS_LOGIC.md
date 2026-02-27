# CMS 系统业务交互逻辑文档

## 模块间业务交互关系

### 1. 内容模型 ↔ 字段管理

**交互流程：**
1. 创建内容模型后，自动跳转到字段管理页面
2. 字段管理页面根据 `modelId` 加载对应模型的字段列表
3. 字段的增删改会实时更新模型的 `fields` 数组
4. 字段排序通过拖拽实现，自动保存 `sort` 值

**数据流向：**
```
ContentModel.fields[] ← → ModelField[]
```

**关键接口：**
- `GET /api/cms/models/:id` - 获取模型详情（含字段）
- `POST /api/cms/models/:id/fields` - 添加字段
- `PUT /api/cms/models/:id/fields/:fieldId` - 更新字段
- `DELETE /api/cms/models/:id/fields/:fieldId` - 删除字段

---

### 2. 内容模型 ↔ 内容管理

**交互流程：**
1. 从模型列表点击"内容"按钮，跳转到 `/cms/content/:modelId`
2. 内容管理页面根据模型的 `fields` 动态生成表单和表格
3. 根据模型配置显示/隐藏分类、标签、版本功能
4. 内容数据存储在 `Content.fields` 对象中

**动态表单生成：**
```typescript
// 根据字段类型生成 Amis 表单组件
generateFormItem(field: ModelField) {
  switch (field.type) {
    case 'text': return { type: 'input-text', ... }
    case 'richtext': return { type: 'input-rich-text', ... }
    // ... 20+ 种字段类型映射
  }
}
```

**数据流向：**
```
ContentModel.fields[] → 动态表单 → Content.fields{}
```

**关键接口：**
- `GET /api/cms/models/:id` - 获取模型配置
- `GET /api/cms/contents/:modelId` - 获取内容列表
- `POST /api/cms/contents/:modelId` - 创建内容
- `PUT /api/cms/contents/:modelId/:id` - 更新内容

---

### 3. 内容管理 ↔ 分类标签

**交互流程：**
1. 内容表单中根据 `model.enable_category` 显示分类选择器
2. 内容表单中根据 `model.enable_tag` 显示标签多选器
3. 分类和标签数据通过 API 动态加载
4. 内容保存时关联 `category_id` 和 `tag_ids`

**数据关联：**
```typescript
Content {
  category_id: number,        // 分类 ID
  category_name: string,      // 分类名称（冗余字段）
  tag_ids: number[],          // 标签 ID 数组
  tags: Tag[],                // 标签对象数组（冗余字段）
}
```

**关键接口：**
- `GET /api/cms/categories` - 获取分类列表（用于下拉选择）
- `GET /api/cms/tags` - 获取标签列表（用于多选）
- 内容创建/更新时携带 `category_id` 和 `tag_ids`

---

### 4. 内容管理 ↔ 媒体库

**交互流程：**
1. 内容表单中的图片/文件字段使用 Amis 的 `input-image` / `input-file` 组件
2. 上传文件时调用 `/api/cms/media/upload` 接口
3. 上传成功后返回文件 URL，存储在 `Content.fields` 中
4. 媒体库可独立管理所有上传的文件

**数据流向：**
```
文件上传 → Media 表 → 返回 URL → Content.fields.cover
```

**关键接口：**
- `POST /api/cms/media/upload` - 上传文件
- `GET /api/cms/media` - 获取媒体列表
- `DELETE /api/cms/media/:id` - 删除文件

---

### 5. 内容管理 ↔ 版本控制

**交互流程：**
1. 内容列表中根据 `model.enable_version` 显示"版本"按钮
2. 点击"版本"按钮打开版本历史弹窗
3. 每次编辑内容时自动创建新版本记录
4. 版本记录包含完整的字段快照

**版本数据结构：**
```typescript
ContentVersion {
  id: number,
  content_id: number,
  version: number,              // 版本号
  data: Record<string, any>,    // 字段快照
  change_summary: string,       // 变更摘要
  created_by: number,
  created_at: string,
}
```

**关键接口：**
- `GET /api/cms/contents/:modelId/:id/versions` - 获取版本列表
- `POST /api/cms/contents/:modelId/:id/versions/:versionId/rollback` - 回滚版本

---

### 6. 内容管理 ↔ 工作流

**交互流程：**
1. 工作流配置中绑定内容模型 `workflow.model_id`
2. 内容提交审批时创建审批记录 `ApprovalRecord`
3. 审批记录关联内容 `approval.content_id`
4. 审批通过后自动发布内容（状态变为 2）

**审批流程：**
```
内容创建 → 提交审批 → 初审 → 终审 → 自动发布
```

**数据关联：**
```typescript
Workflow {
  model_id: number,           // 绑定的模型
  nodes: WorkflowNode[],      // 审批节点
}

ApprovalRecord {
  workflow_id: number,
  content_id: number,         // 关联的内容
  current_node_id: number,    // 当前审批节点
  status: number,             // 0-待审批 1-已通过 2-已拒绝
  logs: ApprovalLog[],        // 审批日志
}
```

**关键接口：**
- `GET /api/cms/workflows` - 获取工作流列表
- `POST /api/cms/approvals` - 提交审批
- `POST /api/cms/approvals/:id/approve` - 审批操作

---

### 7. 定时发布

**交互流程：**
1. 内容编辑时可设置发布时间
2. 创建定时发布任务 `Schedule`
3. 后端定时任务扫描到期任务
4. 自动发布内容（状态变为 2）

**数据结构：**
```typescript
Schedule {
  content_id: number,
  model_id: number,
  publish_time: string,       // 发布时间
  status: number,             // 0-待发布 1-已发布 2-已取消
}
```

---

## 数据一致性保证

### 1. 分类删除时的处理
```typescript
// 删除分类时，需要处理关联的内容
DELETE /api/cms/categories/:id
→ 检查是否有内容使用该分类
→ 如果有，提示用户或自动设置为 null
```

### 2. 标签删除时的处理
```typescript
// 删除标签时，需要从内容的 tag_ids 中移除
DELETE /api/cms/tags/:id
→ 遍历所有内容，移除该标签 ID
→ 更新标签的 count 字段
```

### 3. 字段删除时的处理
```typescript
// 删除字段时，需要清理内容数据
DELETE /api/cms/models/:modelId/fields/:fieldId
→ 遍历该模型的所有内容
→ 删除 Content.fields[fieldKey]
```

### 4. 模型删除时的处理
```typescript
// 删除模型时，需要级联删除
DELETE /api/cms/models/:id
→ 删除所有关联的内容
→ 删除所有关联的工作流
→ 删除所有关联的审批记录
```

---

## 前端状态管理

### 1. 模型缓存
```typescript
// 避免重复请求模型详情
const modelCache = new Map<number, ContentModel>();

async function getModel(id: number) {
  if (modelCache.has(id)) {
    return modelCache.get(id);
  }
  const model = await fetchModel(id);
  modelCache.set(id, model);
  return model;
}
```

### 2. 分类标签缓存
```typescript
// 全局缓存分类和标签数据
const categoryStore = useCategoryStore();
const tagStore = useTagStore();

// 在应用启动时预加载
onMounted(() => {
  categoryStore.fetchAll();
  tagStore.fetchAll();
});
```

---

## 性能优化

### 1. 内容列表分页
- 默认每页 20 条
- 支持 10/20/50/100 条切换
- 后端分页查询

### 2. 字段动态加载
- 表格只显示前 5 个字段
- 详情页显示所有字段
- 富文本字段不在列表中显示

### 3. 媒体文件懒加载
- 网格视图使用虚拟滚动
- 图片使用缩略图
- 大文件分片上传

---

## 错误处理

### 1. 字段类型不匹配
```typescript
// 前端验证字段类型
if (field.type === 'number' && isNaN(value)) {
  throw new Error('请输入有效的数字');
}
```

### 2. 必填字段验证
```typescript
// Amis 表单自动验证
{ name: 'title', required: true, message: '请输入标题' }
```

### 3. 权限检查
```typescript
// 检查用户是否有操作权限
if (!hasPermission('content:create')) {
  Message.error('无权限创建内容');
  return;
}
```

---

## 扩展点

### 1. 自定义字段类型
```typescript
// 在 generateFormItem 中添加新类型
case 'custom_type':
  return {
    type: 'custom-component',
    ...
  };
```

### 2. 自定义审批节点
```typescript
// 支持条件审批、并行审批等
WorkflowNode {
  type: 'sequential' | 'parallel' | 'conditional',
  condition?: string,
}
```

### 3. 自定义内容钩子
```typescript
// 内容创建前/后钩子
onBeforeCreate(content: Content) {
  // 自定义逻辑
}

onAfterCreate(content: Content) {
  // 发送通知、更新统计等
}
```

---

## 总结

CMS 系统通过以下方式实现模块间的业务交互：

1. **数据关联**：通过外键（如 `model_id`、`category_id`）关联不同模块的数据
2. **动态生成**：根据模型配置动态生成表单、表格、验证规则
3. **状态同步**：通过 API 调用保持数据一致性
4. **事件驱动**：通过钩子函数实现模块间的解耦
5. **缓存优化**：通过缓存减少重复请求，提升性能

所有模块都围绕**内容模型**这个核心概念展开，形成了一个完整的内容管理生态系统。
