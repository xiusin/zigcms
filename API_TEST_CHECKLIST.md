# 质量中心 API 测试检查清单

## 测试信息
- 测试日期：____________________
- 测试人员：____________________
- 后端版本：____________________
- 测试环境：[ ] 开发 [ ] 测试 [ ] 生产

## 测试步骤

### 1. 环境准备
- [ ] 后端服务已启动
- [ ] 数据库已初始化
- [ ] 迁移脚本已执行
- [ ] 测试工具已准备（curl/Postman）

### 2. 健康检查
```bash
chmod +x check_api_health.sh
./check_api_health.sh
```
- [ ] 服务连接正常
- [ ] 数据库连接正常
- [ ] 路由注册正常

### 3. 准备测试数据
```bash
chmod +x prepare_test_data.sh
./prepare_test_data.sh
```
- [ ] 测试项目创建成功
- [ ] 测试模块创建成功
- [ ] 测试需求创建成功
- [ ] 测试用例创建成功
- [ ] 测试反馈创建成功

### 4. 运行自动化测试
```bash
chmod +x test_quality_center_api.sh
./test_quality_center_api.sh
```

## API 端点测试结果

### 项目管理 API
- [ ] POST /api/quality/projects - 创建项目
- [ ] GET /api/quality/projects - 查询项目列表
- [ ] GET /api/quality/projects/:id - 查询项目详情
- [ ] PUT /api/quality/projects/:id - 更新项目
- [ ] GET /api/quality/projects/:id/statistics - 获取项目统计
- [ ] POST /api/quality/projects/:id/archive - 归档项目
- [ ] POST /api/quality/projects/:id/restore - 恢复项目
- [ ] DELETE /api/quality/projects/:id - 删除项目

### 模块管理 API
- [ ] POST /api/quality/modules - 创建模块
- [ ] GET /api/quality/modules - 查询模块列表
- [ ] GET /api/quality/modules/tree - 查询模块树
- [ ] GET /api/quality/modules/:id - 查询模块详情
- [ ] PUT /api/quality/modules/:id - 更新模块
- [ ] POST /api/quality/modules/:id/move - 移动模块
- [ ] GET /api/quality/modules/:id/statistics - 获取模块统计
- [ ] DELETE /api/quality/modules/:id - 删除模块

### 需求管理 API
- [ ] POST /api/quality/requirements - 创建需求
- [ ] GET /api/quality/requirements - 查询需求列表
- [ ] GET /api/quality/requirements/:id - 查询需求详情
- [ ] PUT /api/quality/requirements/:id - 更新需求
- [ ] POST /api/quality/requirements/:id/test-cases - 关联测试用例
- [ ] DELETE /api/quality/requirements/:id/test-cases/:id - 取消关联
- [ ] GET /api/quality/requirements/export - 导出需求
- [ ] DELETE /api/quality/requirements/:id - 删除需求

### 测试用例管理 API
- [ ] POST /api/quality/test-cases - 创建测试用例
- [ ] GET /api/quality/test-cases - 搜索测试用例
- [ ] GET /api/quality/test-cases/:id - 查询测试用例详情
- [ ] PUT /api/quality/test-cases/:id - 更新测试用例
- [ ] POST /api/quality/test-cases/:id/execute - 执行测试用例
- [ ] GET /api/quality/test-cases/:id/executions - 查询执行历史
- [ ] POST /api/quality/test-cases/batch-delete - 批量删除
- [ ] POST /api/quality/test-cases/batch-update-status - 批量更新状态
- [ ] POST /api/quality/test-cases/batch-update-assignee - 批量分配
- [ ] DELETE /api/quality/test-cases/:id - 删除测试用例

### AI 生成 API
- [ ] POST /api/quality/ai/generate-test-cases - AI 生成测试用例
- [ ] POST /api/quality/ai/generate-requirement - AI 生成需求
- [ ] POST /api/quality/ai/analyze-feedback - AI 分析反馈

### 反馈管理 API
- [ ] POST /api/quality/feedbacks - 创建反馈
- [ ] GET /api/quality/feedbacks - 查询反馈列表
- [ ] GET /api/quality/feedbacks/:id - 查询反馈详情
- [ ] PUT /api/quality/feedbacks/:id - 更新反馈
- [ ] POST /api/quality/feedbacks/:id/follow-ups - 添加跟进记录
- [ ] POST /api/quality/feedbacks/batch-assign - 批量指派
- [ ] POST /api/quality/feedbacks/batch-update-status - 批量更新状态
- [ ] GET /api/quality/feedbacks/export - 导出反馈
- [ ] DELETE /api/quality/feedbacks/:id - 删除反馈

### 统计分析 API
- [ ] GET /api/quality/statistics/module-distribution - 模块质量分布
- [ ] GET /api/quality/statistics/bug-distribution - Bug 质量分布
- [ ] GET /api/quality/statistics/feedback-distribution - 反馈状态分布
- [ ] GET /api/quality/statistics/quality-trend - 质量趋势
- [ ] GET /api/quality/statistics/export-chart - 导出图表

## 功能验证

### 请求体解析
- [ ] JSON 格式正确解析
- [ ] 必填字段验证生效
- [ ] 可选字段正确处理
- [ ] 字段类型验证生效
- [ ] 字段长度限制生效

### 响应格式
- [ ] 成功响应格式统一
- [ ] 错误响应格式统一
- [ ] 分页响应正确
- [ ] 时间戳格式正确
- [ ] 枚举值正确返回

### 错误处理
- [ ] 404 错误正确返回
- [ ] 400 错误正确返回
- [ ] 500 错误正确处理
- [ ] 错误信息清晰
- [ ] 错误堆栈不暴露

### 业务逻辑
- [ ] 创建操作正确
- [ ] 更新操作正确
- [ ] 删除操作正确
- [ ] 批量操作正确
- [ ] 关联关系正确

### 性能测试
- [ ] 列表查询 < 500ms
- [ ] 详情查询 < 200ms
- [ ] 创建操作 < 300ms
- [ ] 更新操作 < 300ms
- [ ] 批量操作 < 1s

### 安全性测试
- [ ] SQL 注入防护
- [ ] XSS 防护
- [ ] CSRF 防护（如果实现）
- [ ] 权限控制（如果实现）
- [ ] 敏感信息不暴露

## 测试结果统计

- 总测试数：______
- 通过数：______
- 失败数：______
- 通过率：______%

## 失败用例记录

| 端点 | 错误类型 | 错误信息 | 建议 |
|------|---------|---------|------|
|      |         |         |      |
|      |         |         |      |
|      |         |         |      |

## 性能问题记录

| 端点 | 响应时间 | 预期时间 | 建议 |
|------|---------|---------|------|
|      |         |         |      |
|      |         |         |      |

## 问题和建议

### 发现的问题
1. 
2. 
3. 

### 改进建议
1. 
2. 
3. 

## 测试结论

- [ ] 所有测试通过，可以继续下一阶段
- [ ] 部分测试失败，需要修复后重新测试
- [ ] 测试失败较多，需要全面检查

## 签名

测试人员：____________________  日期：____________________

审核人员：____________________  日期：____________________
