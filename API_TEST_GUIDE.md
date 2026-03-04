# 质量中心 API 测试指南

## 概述

本文档提供质量中心 API 的完整测试指南，包括自动化测试脚本和手动测试步骤。

## 前置条件

1. 确保后端服务已启动（默认端口 3000）
2. 确保数据库已初始化并执行了迁移脚本
3. 确保有测试数据（至少 1 个项目、1 个模块、1 个需求）

## 自动化测试

### 使用 Bash 脚本测试

```bash
# 赋予执行权限
chmod +x test_quality_center_api.sh

# 运行测试（使用默认 URL）
./test_quality_center_api.sh

# 运行测试（指定 URL）
./test_quality_center_api.sh http://localhost:3000
```

### 测试覆盖范围

脚本会测试以下 API 端点：

1. **项目管理** (8 个端点)
   - POST /api/quality/projects - 创建项目
   - GET /api/quality/projects - 查询项目列表
   - GET /api/quality/projects/:id - 查询项目详情
   - PUT /api/quality/projects/:id - 更新项目
   - GET /api/quality/projects/:id/statistics - 获取项目统计
   - POST /api/quality/projects/:id/archive - 归档项目
   - POST /api/quality/projects/:id/restore - 恢复项目
   - DELETE /api/quality/projects/:id - 删除项目

2. **模块管理** (7 个端点)
   - POST /api/quality/modules - 创建模块
   - GET /api/quality/modules - 查询模块列表
   - GET /api/quality/modules/tree - 查询模块树
   - GET /api/quality/modules/:id - 查询模块详情
   - PUT /api/quality/modules/:id - 更新模块
   - POST /api/quality/modules/:id/move - 移动模块
   - GET /api/quality/modules/:id/statistics - 获取模块统计

3. **需求管理** (7 个端点)
   - POST /api/quality/requirements - 创建需求
   - GET /api/quality/requirements - 查询需求列表
   - GET /api/quality/requirements/:id - 查询需求详情
   - PUT /api/quality/requirements/:id - 更新需求
   - POST /api/quality/requirements/:id/test-cases - 关联测试用例
   - DELETE /api/quality/requirements/:id/test-cases/:test_case_id - 取消关联
   - GET /api/quality/requirements/export - 导出需求

4. **测试用例管理** (9 个端点)
   - POST /api/quality/test-cases - 创建测试用例
   - GET /api/quality/test-cases - 搜索测试用例
   - GET /api/quality/test-cases/:id - 查询测试用例详情
   - PUT /api/quality/test-cases/:id - 更新测试用例
   - POST /api/quality/test-cases/:id/execute - 执行测试用例
   - GET /api/quality/test-cases/:id/executions - 查询执行历史
   - POST /api/quality/test-cases/batch-delete - 批量删除
   - POST /api/quality/test-cases/batch-update-status - 批量更新状态
   - POST /api/quality/test-cases/batch-update-assignee - 批量分配负责人

5. **AI 生成** (3 个端点)
   - POST /api/quality/ai/generate-test-cases - AI 生成测试用例
   - POST /api/quality/ai/generate-requirement - AI 生成需求
   - POST /api/quality/ai/analyze-feedback - AI 分析反馈

6. **反馈管理** (8 个端点)
   - POST /api/quality/feedbacks - 创建反馈
   - GET /api/quality/feedbacks - 查询反馈列表
   - GET /api/quality/feedbacks/:id - 查询反馈详情
   - PUT /api/quality/feedbacks/:id - 更新反馈
   - POST /api/quality/feedbacks/:id/follow-ups - 添加跟进记录
   - POST /api/quality/feedbacks/batch-assign - 批量指派
   - POST /api/quality/feedbacks/batch-update-status - 批量更新状态
   - GET /api/quality/feedbacks/export - 导出反馈

7. **统计分析** (5 个端点)
   - GET /api/quality/statistics/module-distribution - 模块质量分布
   - GET /api/quality/statistics/bug-distribution - Bug 质量分布
   - GET /api/quality/statistics/feedback-distribution - 反馈状态分布
   - GET /api/quality/statistics/quality-trend - 质量趋势
   - GET /api/quality/statistics/export-chart - 导出图表

8. **错误处理** (5 个测试)
   - 404 错误测试
   - 无效 ID 测试
   - 缺少必填字段测试
   - 无效 JSON 测试
   - 批量操作超限测试

**总计：52 个测试用例**

## 手动测试

### 使用 curl 测试

#### 1. 创建项目

```bash
curl -X POST http://localhost:3000/api/quality/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "测试项目",
    "description": "这是一个测试项目",
    "owner": "admin"
  }'
```

**预期响应**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "name": "测试项目",
    "description": "这是一个测试项目",
    "owner": "admin",
    "status": "active",
    "created_at": 1234567890
  }
}
```

#### 2. 查询项目列表

```bash
curl -X GET "http://localhost:3000/api/quality/projects?page=1&page_size=20"
```

**预期响应**：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [...],
    "total": 10,
    "page": 1,
    "page_size": 20
  }
}
```

#### 3. 创建测试用例

```bash
curl -X POST http://localhost:3000/api/quality/test-cases \
  -H "Content-Type: application/json" \
  -d '{
    "title": "测试用例1",
    "project_id": 1,
    "module_id": 1,
    "priority": "high",
    "precondition": "前置条件",
    "steps": "测试步骤",
    "expected_result": "预期结果"
  }'
```

#### 4. 执行测试用例

```bash
curl -X POST http://localhost:3000/api/quality/test-cases/1/execute \
  -H "Content-Type: application/json" \
  -d '{
    "status": "passed",
    "actual_result": "实际结果",
    "executor": "admin"
  }'
```

#### 5. 批量删除测试用例

```bash
curl -X POST http://localhost:3000/api/quality/test-cases/batch-delete \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1, 2, 3]
  }'
```

### 使用 Postman 测试

1. 导入 `quality_center_api.postman_collection.json`
2. 设置环境变量：
   - `base_url`: http://localhost:3000
   - `api_prefix`: /api/quality
3. 按顺序执行测试用例

## 验证清单

### 1. 请求体解析验证

- [ ] JSON 格式正确解析
- [ ] 必填字段验证生效
- [ ] 可选字段正确处理
- [ ] 字段类型验证生效
- [ ] 字段长度限制生效

### 2. 响应格式验证

- [ ] 成功响应格式统一（code, message, data）
- [ ] 错误响应格式统一（code, message, error）
- [ ] 分页响应包含 total, page, page_size
- [ ] 时间戳格式正确（Unix 时间戳）
- [ ] 枚举值正确返回

### 3. 错误处理验证

- [ ] 404 错误：资源不存在
- [ ] 400 错误：参数验证失败
- [ ] 500 错误：服务器内部错误
- [ ] 错误信息清晰易懂
- [ ] 错误堆栈不暴露给客户端

### 4. 业务逻辑验证

- [ ] 创建操作返回完整对象
- [ ] 更新操作正确修改数据
- [ ] 删除操作正确删除数据
- [ ] 批量操作正确处理多条记录
- [ ] 关联关系正确建立和解除

### 5. 性能验证

- [ ] 列表查询 < 500ms
- [ ] 详情查询 < 200ms
- [ ] 创建操作 < 300ms
- [ ] 更新操作 < 300ms
- [ ] 批量操作 < 1s（100 条以内）

### 6. 安全性验证

- [ ] SQL 注入防护生效
- [ ] XSS 防护生效
- [ ] CSRF 防护生效（如果实现）
- [ ] 权限控制生效（如果实现）
- [ ] 敏感信息不暴露

## 常见问题

### 1. 连接被拒绝

**问题**：`curl: (7) Failed to connect to localhost port 3000`

**解决**：
- 确认后端服务已启动
- 检查端口是否正确
- 检查防火墙设置

### 2. 404 错误

**问题**：所有请求返回 404

**解决**：
- 确认路由已正确注册
- 检查 API 前缀是否正确
- 查看后端日志

### 3. 500 错误

**问题**：请求返回 500 内部错误

**解决**：
- 查看后端日志
- 检查数据库连接
- 确认数据库表已创建

### 4. 参数验证失败

**问题**：请求返回 400 参数错误

**解决**：
- 检查请求体格式
- 确认必填字段已提供
- 检查字段类型是否正确

## 测试报告模板

```markdown
# 质量中心 API 测试报告

## 测试信息
- 测试时间：2026-03-05
- 测试人员：[姓名]
- 测试环境：[开发/测试/生产]
- 后端版本：[版本号]

## 测试结果
- 总测试数：52
- 通过数：50
- 失败数：2
- 通过率：96.2%

## 失败用例
1. POST /api/quality/ai/generate-test-cases
   - 错误：AI 服务未配置
   - 状态码：500
   - 建议：配置 OpenAI API Key

2. GET /api/quality/statistics/export-chart
   - 错误：图表导出功能未实现
   - 状态码：501
   - 建议：实现图表导出功能

## 性能测试
- 平均响应时间：150ms
- 最慢接口：GET /api/quality/statistics/quality-trend (800ms)
- 最快接口：GET /api/quality/projects/:id (50ms)

## 建议
1. 优化统计查询性能
2. 添加缓存机制
3. 实现图表导出功能
4. 配置 AI 服务
```

## 下一步

测试通过后，可以继续执行：
- 任务 21：创建前端 API 客户端
- 任务 22-28：实现前端页面
- 任务 31-34：编写单元测试和属性测试
