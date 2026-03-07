# 需求管理增强功能实现指南

## 概述

本文档描述了需求管理模块的增强功能实现，包括权限控制、状态流转规则、批量操作、导出优化、实时通知、评论功能、附件管理、版本历史和关联关系可视化。

## 已完成功能

### 1. 路由配置 ✅

已在 `ecom-admin/src/router/routes/modules/quality-center.ts` 中添加：

- `/quality-center/requirement` - 需求列表页
- `/quality-center/requirement/:id` - 需求详情页

权限配置：
- 角色：所有用户（`roles: ['*']`）
- 权限：`quality:center:requirement`

### 2. 基础 CRUD 功能 ✅

- 创建需求
- 查看需求详情
- 编辑需求
- 删除需求
- 搜索和筛选
- 分页查询

### 3. AI 集成 ✅

- AI 生成需求功能
- 基于项目描述自动生成需求

### 4. 数据导入导出 ✅

- Excel 格式导入
- Excel 格式导出

### 5. 关联管理 ✅

- 添加测试用例关联
- 移除测试用例关联
- 关联用例列表展示

## 待实现增强功能

### 1. 权限控制增强

**目标**：根据用户角色细化操作权限

**实现文件**：
- `ecom-admin/src/composables/usePermission.ts`
- `ecom-admin/src/views/quality-center/requirement/index.vue`
- `ecom-admin/src/views/quality-center/requirement/detail.vue`

**权限矩阵**：

| 操作 | 超级管理员 | 管理员 | 测试人员 | 开发人员 | 访客 |
|------|-----------|--------|---------|---------|------|
| 查看需求 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 创建需求 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 编辑需求 | ✅ | ✅ | 仅自己创建 | 仅自己创建 | ❌ |
| 删除需求 | ✅ | ✅ | ❌ | ❌ | ❌ |
| AI 生成 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 导入导出 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 关联用例 | ✅ | ✅ | ✅ | ✅ | ❌ |

**实现步骤**：

1. 创建权限组合式函数
2. 在组件中使用权限检查
3. 根据权限显示/隐藏操作按钮

### 2. 状态流转规则验证

**目标**：确保需求状态按照业务规则流转

**状态流转图**：
```
待评审 → 已评审 → 开发中 → 待测试 → 测试中 → 已完成 → 已关闭
   ↓        ↓        ↓        ↓        ↓        ↓
  已关闭   已关闭   已关闭   已关闭   已关闭   已关闭
```

**实现文件**：
- `ecom-admin/src/utils/requirement-status.ts`
- `ecom-admin/src/views/quality-center/requirement/detail.vue`

### 3. 批量操作功能

**目标**：支持批量删除、批量修改状态、批量分配负责人

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/index.vue`
- `ecom-admin/src/views/quality-center/requirement/components/RequirementTable.vue`

**功能列表**：
- 批量删除需求
- 批量修改状态
- 批量分配负责人
- 批量导出

### 4. 导出优化

**目标**：支持自定义导出字段和格式

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/components/ExportDialog.vue`
- `ecom-admin/src/utils/export.ts`

**功能特性**：
- 自定义导出字段
- 支持多种格式（Excel、CSV、PDF）
- 导出模板保存
- 导出历史记录

### 5. 实时通知

**目标**：需求状态变更时通知相关人员

**实现文件**：
- `ecom-admin/src/services/websocket.ts`
- `ecom-admin/src/components/notification/NotificationCenter.vue`

**通知场景**：
- 需求创建通知负责人
- 状态变更通知相关人员
- 关联用例变更通知
- 评论@提及通知

### 6. 评论功能

**目标**：支持在需求详情页添加评论和讨论

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/components/CommentSection.vue`
- `ecom-admin/src/components/editor/RichTextEditor.vue`

**功能特性**：
- 富文本评论
- @提及用户
- 评论回复
- 评论编辑和删除
- 评论点赞

### 7. 附件管理

**目标**：支持上传需求相关的附件文档

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/components/AttachmentList.vue`
- `ecom-admin/src/components/upload/AttachmentUpload.vue`

**功能特性**：
- 多文件上传
- 文件预览
- 文件下载
- 文件删除
- 支持的文件类型：PDF、Word、Excel、图片、压缩包

### 8. 版本历史

**目标**：记录需求的修改历史，支持版本对比

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/components/VersionHistory.vue`
- `ecom-admin/src/views/quality-center/requirement/components/VersionDiff.vue`

**功能特性**：
- 自动记录每次修改
- 显示修改人和修改时间
- 版本对比（diff）
- 版本回滚

### 9. 关联关系可视化

**目标**：使用图表展示需求与测试用例的关联关系

**实现文件**：
- `ecom-admin/src/views/quality-center/requirement/components/RelationshipGraph.vue`

**功能特性**：
- 关系图谱展示
- 节点点击查看详情
- 关系筛选
- 导出关系图

## 实现优先级

### P0（立即实现）
1. ✅ 路由配置
2. ✅ 基础 CRUD
3. ✅ 关联管理
4. 权限控制增强
5. 状态流转规则

### P1（本周实现）
6. 批量操作
7. 评论功能
8. 附件管理

### P2（下周实现）
9. 实时通知
10. 导出优化
11. 版本历史

### P3（后续优化）
12. 关联关系可视化

## 技术栈

- Vue 3 + TypeScript
- Arco Design
- Pinia（状态管理）
- WebSocket（实时通知）
- ECharts（关系图谱）
- Diff（版本对比）

## 下一步行动

1. 创建权限组合式函数
2. 实现状态流转规则验证
3. 添加批量操作功能
4. 实现评论和附件功能
5. 集成实时通知
6. 优化导出功能
7. 实现版本历史
8. 开发关系图谱

## 参考文档

- [Arco Design 组件库](https://arco.design/vue/docs/start)
- [Vue 3 组合式 API](https://cn.vuejs.org/guide/extras/composition-api-faq.html)
- [WebSocket API](https://developer.mozilla.org/zh-CN/docs/Web/API/WebSocket)
- [ECharts 关系图](https://echarts.apache.org/zh/option.html#series-graph)
