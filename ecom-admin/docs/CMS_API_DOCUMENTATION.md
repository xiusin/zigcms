# CMS 系统 API 接口文档

## 接口概览

本文档包含 CMS 系统所有 API 接口的详细说明，包括请求参数、响应格式和使用示例。

**基础 URL**: `/api/cms`

**响应格式**:
```typescript
{
  code: number,      // 200-成功 其他-失败
  msg: string,       // 响应消息
  data: any          // 响应数据
}
```

---

## 1. 内容模型管理

### 1.1 获取模型列表
```
GET /api/cms/models
```

**查询参数**:
- `page`: 页码（默认 1）
- `pageSize`: 每页数量（默认 20）
- `keyword`: 搜索关键词

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "name": "文章",
        "slug": "article",
        "fields": [...],
        "enable_category": true,
        "enable_tag": true,
        "enable_version": true,
        "content_count": 25
      }
    ],
    "total": 2,
    "page": 1,
    "pageSize": 20
  }
}
```

### 1.2 获取模型详情
```
GET /api/cms/models/:id
```

### 1.3 创建模型
```
POST /api/cms/models
```

**请求体**:
```json
{
  "name": "文章",
  "slug": "article",
  "description": "文章内容模型",
  "enable_category": true,
  "enable_tag": true,
  "enable_version": true,
  "enable_i18n": false
}
```

### 1.4 更新模型
```
PUT /api/cms/models/:id
```

### 1.5 删除模型
```
DELETE /api/cms/models/:id
```

---

## 2. 字段管理

### 2.1 添加字段
```
POST /api/cms/models/:modelId/fields
```

**请求体**:
```json
{
  "label": "标题",
  "key": "title",
  "type": "text",
  "required": true,
  "unique": false,
  "searchable": true,
  "default_value": "",
  "placeholder": "请输入标题",
  "help_text": "文章标题",
  "validation_rules": {
    "min_length": 5,
    "max_length": 100
  },
  "sort": 1
}
```

### 2.2 更新字段
```
PUT /api/cms/models/:modelId/fields/:fieldId
```

### 2.3 删除字段
```
DELETE /api/cms/models/:modelId/fields/:fieldId
```

### 2.4 字段排序
```
POST /api/cms/models/:modelId/fields/sort
```

**请求体**:
```json
{
  "fieldIds": [1, 2, 3, 4]
}
```

---

## 3. 内容管理

### 3.1 获取内容列表
```
GET /api/cms/contents/:modelId
```

**查询参数**:
- `page`: 页码
- `pageSize`: 每页数量
- `keyword`: 搜索关键词
- `category_id`: 分类 ID
- `status`: 状态（0-草稿 1-待审核 2-已发布 3-已归档）

### 3.2 获取内容详情
```
GET /api/cms/contents/:modelId/:id
```

### 3.3 创建内容
```
POST /api/cms/contents/:modelId
```

**请求体**:
```json
{
  "category_id": 1,
  "tag_ids": [1, 2],
  "status": 0,
  "fields": {
    "title": "示例文章",
    "author": "张三",
    "content": "<p>文章内容</p>"
  }
}
```

### 3.4 更新内容
```
PUT /api/cms/contents/:modelId/:id
```

### 3.5 删除内容
```
DELETE /api/cms/contents/:modelId/:id
```

### 3.6 发布内容
```
POST /api/cms/contents/:modelId/:id/publish
```

### 3.7 下线内容
```
POST /api/cms/contents/:modelId/:id/unpublish
```

### 3.8 批量发布
```
POST /api/cms/contents/:modelId/batch/publish
```

**请求体**:
```json
{
  "ids": [1, 2, 3]
}
```

### 3.9 批量删除
```
POST /api/cms/contents/:modelId/batch/delete
```

---

## 4. 版本控制

### 4.1 获取版本列表
```
GET /api/cms/contents/:modelId/:contentId/versions
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "version": 1,
      "data": { "title": "标题 v1" },
      "change_summary": "初始版本",
      "created_by_name": "张三",
      "created_at": "2026-02-25 10:00:00"
    }
  ]
}
```

### 4.2 版本回滚
```
POST /api/cms/contents/:modelId/:contentId/versions/:versionId/rollback
```

### 4.3 版本对比
```
GET /api/cms/contents/:modelId/:contentId/versions/compare?v1=1&v2=2
```

---

## 5. 分类管理

### 5.1 获取分类列表
```
GET /api/cms/categories
```

### 5.2 获取分类树
```
GET /api/cms/categories/tree
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "name": "公司新闻",
      "slug": "company-news",
      "children": [
        {
          "id": 2,
          "name": "产品发布",
          "slug": "product-release",
          "children": []
        }
      ]
    }
  ]
}
```

### 5.3 创建分类
```
POST /api/cms/categories
```

**请求体**:
```json
{
  "name": "公司新闻",
  "slug": "company-news",
  "parent_id": null,
  "sort": 1,
  "status": 1,
  "description": "公司相关新闻",
  "seo_title": "公司新闻",
  "seo_keywords": "公司,新闻",
  "seo_description": "公司新闻描述"
}
```

### 5.4 更新分类
```
PUT /api/cms/categories/:id
```

### 5.5 删除分类
```
DELETE /api/cms/categories/:id
```

### 5.6 分类排序
```
POST /api/cms/categories/sort
```

**请求体**:
```json
{
  "id": 1,
  "parent_id": null,
  "sort": 1
}
```

---

## 6. 标签管理

### 6.1 获取标签列表
```
GET /api/cms/tags
```

**查询参数**:
- `page`: 页码
- `pageSize`: 每页数量
- `keyword`: 搜索关键词

### 6.2 创建标签
```
POST /api/cms/tags
```

**请求体**:
```json
{
  "name": "热门",
  "slug": "hot",
  "color": "#f5222d",
  "status": 1
}
```

### 6.3 更新标签
```
PUT /api/cms/tags/:id
```

### 6.4 删除标签
```
DELETE /api/cms/tags/:id
```

### 6.5 合并标签
```
POST /api/cms/tags/merge
```

**请求体**:
```json
{
  "sourceId": 1,
  "targetId": 2
}
```

---

## 7. 媒体库

### 7.1 获取媒体列表
```
GET /api/cms/media
```

**查询参数**:
- `page`: 页码
- `pageSize`: 每页数量
- `folder_id`: 文件夹 ID
- `keyword`: 搜索关键词
- `type`: 文件类型（image/video/document）

### 7.2 上传文件
```
POST /api/cms/media/upload
```

**请求体**: FormData
- `file`: 文件
- `folder_id`: 文件夹 ID

### 7.3 删除文件
```
DELETE /api/cms/media/:id
```

### 7.4 批量删除
```
POST /api/cms/media/batch/delete
```

**请求体**:
```json
{
  "ids": [1, 2, 3]
}
```

### 7.5 分片上传
```
POST /api/cms/media/upload/chunk
```

### 7.6 合并分片
```
POST /api/cms/media/upload/merge
```

**请求体**:
```json
{
  "fileId": "xxx-xxx-xxx"
}
```

---

## 8. 媒体文件夹

### 8.1 获取文件夹列表
```
GET /api/cms/media/folders
```

### 8.2 获取文件夹树
```
GET /api/cms/media/folders/tree
```

### 8.3 创建文件夹
```
POST /api/cms/media/folders
```

**请求体**:
```json
{
  "name": "产品图片",
  "parent_id": null
}
```

### 8.4 更新文件夹
```
PUT /api/cms/media/folders/:id
```

### 8.5 删除文件夹
```
DELETE /api/cms/media/folders/:id
```

---

## 9. 工作流管理

### 9.1 获取工作流列表
```
GET /api/cms/workflows
```

### 9.2 创建工作流
```
POST /api/cms/workflows
```

**请求体**:
```json
{
  "name": "文章审批流程",
  "model_id": 1,
  "nodes": [
    {
      "name": "初审",
      "approver_id": 2,
      "sort": 1
    },
    {
      "name": "终审",
      "approver_id": 1,
      "sort": 2
    }
  ],
  "status": 1
}
```

### 9.3 更新工作流
```
PUT /api/cms/workflows/:id
```

### 9.4 删除工作流
```
DELETE /api/cms/workflows/:id
```

---

## 10. 定时发布

### 10.1 获取定时发布列表
```
GET /api/cms/schedules
```

### 10.2 取消定时发布
```
POST /api/cms/schedules/:id/cancel
```

---

## 11. 审批记录

### 11.1 获取审批记录
```
GET /api/cms/approvals
```

**查询参数**:
- `status`: 审批状态（0-待审批 1-已通过 2-已拒绝）
- `dateRange`: 时间范围

### 11.2 审批操作
```
POST /api/cms/approvals/:id/approve
```

**请求体**:
```json
{
  "status": 1,
  "remark": "审批通过"
}
```

---

## 12. 模板管理

### 12.1 获取模板列表
```
GET /api/cms/templates
```

### 12.2 创建模板
```
POST /api/cms/templates
```

**请求体**:
```json
{
  "name": "文章详情模板",
  "code": "article_detail",
  "content": "<div>{{title}}</div>",
  "status": 1
}
```

### 12.3 更新模板
```
PUT /api/cms/templates/:id
```

### 12.4 删除模板
```
DELETE /api/cms/templates/:id
```

---

## 13. 翻译管理

### 13.1 获取翻译列表
```
GET /api/cms/translations/:contentId
```

### 13.2 保存翻译
```
POST /api/cms/translations/:contentId
```

**请求体**:
```json
{
  "language": "en",
  "fields": {
    "title": "English Title",
    "content": "English Content"
  }
}
```

---

## 14. SEO 工具

### 14.1 生成 Sitemap
```
POST /api/cms/seo/sitemap/generate
```

### 14.2 获取 Sitemap 状态
```
GET /api/cms/seo/sitemap/status
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "lastGenerated": "2026-02-25 10:00:00",
    "totalUrls": 150,
    "status": "success"
  }
}
```

---

## 15. 缓存管理

### 15.1 清除缓存
```
POST /api/cms/cache/clear
```

**请求体**:
```json
{
  "type": "page" | "api" | "all"
}
```

### 15.2 获取缓存统计
```
GET /api/cms/cache/stats
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "pageCache": {
      "size": "125MB",
      "hits": 15000,
      "misses": 500
    },
    "apiCache": {
      "size": "45MB",
      "hits": 8000,
      "misses": 200
    },
    "totalSize": "170MB"
  }
}
```

---

## 16. CMS 统计

### 16.1 获取统计数据
```
GET /api/cms/stats
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "totalContents": 35,
    "publishedContents": 25,
    "pendingApprovals": 3,
    "totalMedia": 30
  }
}
```

### 16.2 获取最近内容
```
GET /api/cms/contents/recent
```

**响应**:
```json
{
  "code": 200,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "title": "示例文章1",
      "model_name": "文章",
      "status": 2,
      "created_at": "2026-02-25 10:00:00"
    }
  ]
}
```

---

## 错误码说明

| 错误码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未授权 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 500 | 服务器错误 |

---

## 使用示例

### TypeScript 示例

```typescript
import { getModelList, createContent } from '@/api/cms';

// 获取模型列表
const fetchModels = async () => {
  const res = await getModelList({ page: 1, pageSize: 20 });
  console.log(res.data.items);
};

// 创建内容
const createArticle = async () => {
  const res = await createContent(1, {
    category_id: 1,
    tag_ids: [1, 2],
    status: 0,
    fields: {
      title: '示例文章',
      content: '<p>文章内容</p>',
    },
  });
  console.log(res.data);
};
```

### Axios 示例

```javascript
// 获取内容列表
axios.get('/api/cms/contents/1', {
  params: {
    page: 1,
    pageSize: 20,
    keyword: '搜索关键词',
  },
}).then(res => {
  console.log(res.data);
});

// 创建分类
axios.post('/api/cms/categories', {
  name: '公司新闻',
  slug: 'company-news',
  status: 1,
}).then(res => {
  console.log(res.data);
});
```

---

## 总结

本文档包含了 CMS 系统的所有 API 接口，共计 **60+ 个接口**，涵盖：

- 内容模型管理（5 个接口）
- 字段管理（4 个接口）
- 内容管理（9 个接口）
- 版本控制（3 个接口）
- 分类管理（6 个接口）
- 标签管理（5 个接口）
- 媒体库（6 个接口）
- 媒体文件夹（5 个接口）
- 工作流管理（4 个接口）
- 定时发布（2 个接口）
- 审批记录（2 个接口）
- 模板管理（4 个接口）
- 翻译管理（2 个接口）
- SEO 工具（2 个接口）
- 缓存管理（2 个接口）
- CMS 统计（2 个接口）

所有接口均已实现 Mock 数据，可直接用于前端开发和测试。
