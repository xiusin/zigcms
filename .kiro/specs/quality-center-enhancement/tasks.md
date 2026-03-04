# 质量中心完善功能 - 实现任务列表

## 概述

本任务列表基于需求文档和设计文档，按照依赖关系和优先级组织，遵循 ZigCMS 整洁架构和 Zig 语言最佳实践。

## 任务执行原则

1. **按顺序执行**: 任务按依赖关系排序，先实现基础层（domain → infrastructure → application → api → frontend）
2. **增量验证**: 每个任务完成后验证核心功能
3. **测试驱动**: 可选的测试任务标记为 `*`，可根据时间决定是否实现
4. **检查点**: 在关键节点设置检查点，确保所有测试通过

## 任务列表

### 阶段 1: 数据库和基础设施准备

- [ ] 1. 创建数据库迁移文件
  - 创建 `migrations/20260303_quality_center_enhancement.sql`
  - 定义所有表结构（test_cases, test_executions, projects, modules, requirements, feedbacks, bugs, link_records）
  - 添加索引优化（单列索引、复合索引、覆盖索引）
  - 添加外键约束和唯一约束
  - _需求: 9.10, 10.1_
  - _验收标准: 执行迁移后所有表创建成功，索引生效_

- [ ] 2. 执行数据库迁移
  - 运行迁移命令创建表
  - 验证表结构和索引
  - 插入测试数据（至少 3 个项目、10 个模块、50 个测试用例）
  - _需求: 9.10_
  - _验收标准: 所有表创建成功，测试数据插入成功_

### 阶段 2: 领域层实现（Domain Layer）

- [ ] 3. 实现领域实体
  - [ ] 3.1 创建测试用例实体
    - 创建 `src/domain/entities/test_case.model.zig`
    - 定义 TestCase 结构体（包含所有字段、枚举类型、关系定义）
    - 定义 Priority 和 TestCaseStatus 枚举
    - 定义关系（executions, requirement, bugs）
    - _需求: 1.1, 10.2_

  - [ ] 3.2 创建测试执行记录实体
    - 创建 `src/domain/entities/test_execution.model.zig`
    - 定义 TestExecution 结构体
    - 定义 ExecutionStatus 枚举
    - _需求: 1.6, 10.2_

  - [ ] 3.3 创建项目实体
    - 创建 `src/domain/entities/project.model.zig`
    - 定义 Project 结构体
    - 定义 ProjectStatus 枚举
    - 定义关系（modules, test_cases, requirements）
    - _需求: 3.1, 10.2_

  - [ ] 3.4 创建模块实体
    - 创建 `src/domain/entities/module.model.zig`
    - 定义 Module 结构体
    - 定义关系（children, test_cases）
    - _需求: 4.1, 10.2_

  - [ ] 3.5 创建需求实体
    - 创建 `src/domain/entities/requirement.model.zig`
    - 定义 Requirement 结构体
    - 定义 Priority 和 RequirementStatus 枚举
    - 定义关系（test_cases）
    - _需求: 5.1, 10.2_

  - [ ] 3.6 创建反馈实体
    - 创建 `src/domain/entities/feedback.model.zig`
    - 定义 Feedback 结构体
    - 定义 FeedbackType, Severity, FeedbackStatus 枚举
    - _需求: 7.1, 10.2_

  - [ ] 3.7 创建 Bug 实体
    - 创建 `src/domain/entities/bug.model.zig`
    - 定义 Bug 结构体
    - 定义 BugStatus 和 BugSeverity 枚举
    - _需求: 1.8, 10.2_

  - [ ] 3.8 创建关联记录实体
    - 创建 `src/domain/entities/link_record.model.zig`
    - 定义 LinkRecord 结构体（用于多对多关系）
    - _需求: 1.8, 10.2_

- [ ] 4. 实现仓储接口
  - [ ] 4.1 创建测试用例仓储接口
    - 创建 `src/domain/repositories/test_case_repository.zig`
    - 定义 TestCaseRepository 接口（VTable 模式）
    - 定义方法：findById, findByProject, findByModule, save, delete, batchDelete, batchUpdateStatus, batchUpdateAssignee, search
    - 定义 PageQuery, SearchQuery, PageResult 类型
    - _需求: 1.1, 1.3, 1.4, 1.5, 1.9, 10.7_

  - [ ] 4.2 创建测试执行记录仓储接口
    - 创建 `src/domain/repositories/test_execution_repository.zig`
    - 定义 TestExecutionRepository 接口
    - 定义方法：findById, findByTestCase, save, delete
    - _需求: 1.6, 1.7, 10.7_

  - [ ] 4.3 创建项目仓储接口
    - 创建 `src/domain/repositories/project_repository.zig`
    - 定义 ProjectRepository 接口
    - 定义方法：findById, findAll, save, delete, archive, restore
    - _需求: 3.1, 3.7, 10.7_

  - [ ] 4.4 创建模块仓储接口
    - 创建 `src/domain/repositories/module_repository.zig`
    - 定义 ModuleRepository 接口
    - 定义方法：findById, findByProject, findTree, save, delete, move
    - _需求: 4.1, 4.2, 4.4, 10.7_

  - [ ] 4.5 创建需求仓储接口
    - 创建 `src/domain/repositories/requirement_repository.zig`
    - 定义 RequirementRepository 接口
    - 定义方法：findById, findByProject, save, delete, linkTestCase, unlinkTestCase
    - _需求: 5.1, 5.8, 10.7_

  - [ ] 4.6 创建反馈仓储接口
    - 创建 `src/domain/repositories/feedback_repository.zig`
    - 定义 FeedbackRepository 接口
    - 定义方法：findById, findAll, save, delete, addFollowUp, batchAssign, batchUpdateStatus
    - _需求: 7.1, 7.3, 7.6, 10.7_

- [ ] 5. 实现 AI 生成器接口
  - 创建 `src/domain/services/ai_generator_interface.zig`
  - 定义 AIGeneratorInterface 接口（VTable 模式）
  - 定义方法：generateTestCases, generateRequirement, analyzeFeedback
  - 定义 GenerateOptions, GeneratedTestCase, GeneratedRequirement, FeedbackAnalysis 类型
  - _需求: 2.1, 2.2, 2.3, 5.3, 7.5_

### 阶段 3: 基础设施层实现（Infrastructure Layer）

- [ ] 6. 实现数据库仓储
  - [ ] 6.1 实现测试用例仓储
    - 创建 `src/infrastructure/database/mysql_test_case_repository.zig`
    - 实现 TestCaseRepository 接口的所有方法
    - 使用 ORM QueryBuilder 构建查询（禁止 rawExec）
    - 使用参数化查询防止 SQL 注入
    - 使用 whereIn 优化批量查询
    - 使用关系预加载（with 方法）避免 N+1 查询
    - 使用 Arena Allocator 或深拷贝管理 ORM 查询结果内存
    - _需求: 1.1, 1.3, 1.4, 1.5, 1.9, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ] 6.2 实现测试执行记录仓储
    - 创建 `src/infrastructure/database/mysql_test_execution_repository.zig`
    - 实现 TestExecutionRepository 接口
    - 使用 ORM QueryBuilder 和参数化查询
    - _需求: 1.6, 1.7, 9.1, 9.2, 9.3_

  - [ ] 6.3 实现项目仓储
    - 创建 `src/infrastructure/database/mysql_project_repository.zig`
    - 实现 ProjectRepository 接口
    - 使用关系预加载优化统计查询
    - _需求: 3.1, 3.5, 3.7, 9.1, 9.2, 9.5_

  - [ ] 6.4 实现模块仓储
    - 创建 `src/infrastructure/database/mysql_module_repository.zig`
    - 实现 ModuleRepository 接口
    - 实现树形结构查询（递归 CTE 或多次查询）
    - 实现拖拽移动逻辑（更新 parent_id 和 sort_order）
    - _需求: 4.1, 4.2, 4.3, 4.4, 9.1, 9.2_

  - [ ] 6.5 实现需求仓储
    - 创建 `src/infrastructure/database/mysql_requirement_repository.zig`
    - 实现 RequirementRepository 接口
    - 实现关联测试用例的添加和移除
    - _需求: 5.1, 5.7, 5.8, 9.1, 9.2_

  - [ ] 6.6 实现反馈仓储
    - 创建 `src/infrastructure/database/mysql_feedback_repository.zig`
    - 实现 FeedbackRepository 接口
    - 实现跟进记录的 JSON 序列化和反序列化
    - _需求: 7.1, 7.3, 7.6, 7.8, 9.1, 9.2_

- [ ] 7. 实现 AI 生成器
  - [ ] 7.1 实现 OpenAI 生成器
    - 创建 `src/infrastructure/ai/openai_generator.zig`
    - 实现 AIGeneratorInterface 接口
    - 实现 generateTestCases 方法（构建 Prompt、调用 OpenAI API、解析响应）
    - 实现 generateRequirement 方法
    - 实现 analyzeFeedback 方法
    - 使用 HTTP 客户端发送请求
    - 处理流式响应（可选）
    - 实现错误处理和重试机制
    - _需求: 2.1, 2.2, 2.3, 2.9, 5.3, 7.5_

  - [ ]* 7.2 编写 AI 生成器单元测试
    - 测试 Prompt 构建逻辑
    - 测试响应解析逻辑
    - 测试错误处理
    - _需求: 2.9, 10.10_

- [ ] 8. 实现缓存层
  - 创建 `src/infrastructure/cache/quality_center_cache.zig`
  - 实现缓存键生成函数（testCase, project, moduleTree, projectStatistics）
  - 实现缓存失效策略（按前缀删除）
  - 实现缓存预热函数
  - _需求: 12.5, 12.6, 12.7_

### 阶段 4: 应用层实现（Application Layer）

- [ ] 9. 实现测试用例服务
  - 创建 `src/application/services/test_case_service.zig`
  - 实现 TestCaseService 结构体（包含 allocator, test_case_repo, execution_repo, cache）
  - 实现 create 方法（验证必填字段、创建测试用例、清除缓存）
  - 实现 update 方法（查询、更新、清除缓存）
  - 实现 delete 方法（删除、清除缓存）
  - 实现 batchDelete 方法（批量删除、清除缓存）
  - 实现 batchUpdateStatus 方法
  - 实现 batchUpdateAssignee 方法
  - 实现 execute 方法（创建执行记录、更新测试用例状态）
  - 实现 search 方法（带缓存）
  - 实现 findById 方法（带缓存）
  - 使用 errdefer 确保资源释放
  - _需求: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.9, 10.3, 10.9, 12.5_

- [ ] 10. 实现项目服务
  - 创建 `src/application/services/project_service.zig`
  - 实现 ProjectService 结构体
  - 实现 create, update, delete, archive, restore 方法
  - 实现 getStatistics 方法（计算用例总数、执行次数、通过率、Bug 数量、需求覆盖率）
  - 实现 warmupCache 方法（预加载统计数据、模块树、热门测试用例）
  - _需求: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.10, 12.5_

- [ ] 11. 实现模块服务
  - 创建 `src/application/services/module_service.zig`
  - 实现 ModuleService 结构体
  - 实现 create, update, delete 方法
  - 实现 getTree 方法（构建树形结构）
  - 实现 move 方法（拖拽移动、验证层级深度不超过 5 层）
  - 实现 getStatistics 方法（计算用例总数、通过率、Bug 数量、覆盖率）
  - _需求: 4.1, 4.2, 4.3, 4.4, 4.6, 4.10_

- [ ] 12. 实现需求服务
  - 创建 `src/application/services/requirement_service.zig`
  - 实现 RequirementService 结构体
  - 实现 create, update, delete 方法
  - 实现 updateStatus 方法（验证状态流转合法性、记录变更历史）
  - 实现 linkTestCase, unlinkTestCase 方法
  - 实现 calculateCoverage 方法（计算覆盖率）
  - 实现 importFromExcel, exportToExcel 方法
  - _需求: 5.1, 5.2, 5.4, 5.5, 5.6, 5.7, 5.8, 5.10_

- [ ] 13. 实现反馈服务
  - 创建 `src/application/services/feedback_service.zig`
  - 实现 FeedbackService 结构体
  - 实现 create, update, delete 方法
  - 实现 addFollowUp 方法（添加跟进记录、更新跟进次数和最后跟进时间、发送通知）
  - 实现 batchAssign, batchUpdateStatus 方法
  - 实现 exportToExcel 方法
  - 集成 AI 生成器分析反馈内容
  - _需求: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.8, 7.9, 7.10_

- [ ] 14. 实现统计服务
  - 创建 `src/application/services/statistics_service.zig`
  - 实现 StatisticsService 结构体
  - 实现 getModuleDistribution 方法（按模块分类统计）
  - 实现 getBugDistribution 方法（按类型分类统计）
  - 实现 getFeedbackDistribution 方法（按状态分类统计）
  - 实现 getQualityTrend 方法（按时间范围统计通过率、Bug 数量、执行次数）
  - 实现 exportChart 方法（导出为 PNG/SVG/PDF）
  - 使用缓存优化查询性能
  - _需求: 6.1, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 12.5_

- [ ] 15. Checkpoint - 确保所有服务测试通过
  - 运行所有服务层单元测试
  - 验证核心业务逻辑正确性
  - 验证缓存策略生效
  - 验证错误处理正确
  - 如有问题，询问用户并修复

### 阶段 5: API 层实现（API Layer）

- [ ] 16. 实现 DTO
  - [ ] 16.1 创建测试用例 DTO
    - 创建 `src/api/dto/test_case_create.dto.zig`（CreateTestCaseDto）
    - 创建 `src/api/dto/test_case_update.dto.zig`（UpdateTestCaseDto）
    - 创建 `src/api/dto/test_case_execute.dto.zig`（ExecuteTestCaseDto）
    - 创建 `src/api/dto/batch_delete.dto.zig`（BatchDeleteDto）
    - 创建 `src/api/dto/batch_update_status.dto.zig`（BatchUpdateStatusDto）
    - 创建 `src/api/dto/batch_update_assignee.dto.zig`（BatchUpdateAssigneeDto）
    - _需求: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [ ] 16.2 创建项目 DTO
    - 创建 `src/api/dto/project_create.dto.zig`
    - 创建 `src/api/dto/project_update.dto.zig`
    - _需求: 3.1, 3.2_

  - [ ] 16.3 创建模块 DTO
    - 创建 `src/api/dto/module_create.dto.zig`
    - 创建 `src/api/dto/module_update.dto.zig`
    - 创建 `src/api/dto/module_move.dto.zig`
    - _需求: 4.1, 4.2, 4.4_

  - [ ] 16.4 创建需求 DTO
    - 创建 `src/api/dto/requirement_create.dto.zig`
    - 创建 `src/api/dto/requirement_update.dto.zig`
    - 创建 `src/api/dto/requirement_link_test_case.dto.zig`
    - _需求: 5.1, 5.2, 5.8_

  - [ ] 16.5 创建反馈 DTO
    - 创建 `src/api/dto/feedback_create.dto.zig`
    - 创建 `src/api/dto/feedback_update.dto.zig`
    - 创建 `src/api/dto/feedback_follow_up.dto.zig`
    - _需求: 7.1, 7.2, 7.8_

  - [ ] 16.6 创建 AI 生成 DTO
    - 创建 `src/api/dto/ai_generate_test_cases.dto.zig`
    - 创建 `src/api/dto/ai_generate_requirement.dto.zig`
    - 创建 `src/api/dto/ai_analyze_feedback.dto.zig`
    - _需求: 2.1, 5.3, 7.5_

- [ ] 17. 实现控制器
  - [ ] 17.1 实现测试用例控制器
    - 创建 `src/api/controllers/test_case.controller.zig`
    - 实现 create 方法（解析请求体、调用服务、返回响应）
    - 实现 get 方法（解析路径参数、调用服务、返回响应）
    - 实现 update 方法
    - 实现 delete 方法
    - 实现 search 方法（解析查询参数）
    - 实现 batchDelete 方法（验证参数、限制最多 1000 条）
    - 实现 batchUpdateStatus 方法
    - 实现 batchUpdateAssignee 方法
    - 实现 execute 方法
    - 实现 getExecutions 方法
    - 实现错误处理（返回 400/403/404/500 错误）
    - _需求: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.9, 10.8, 12.3_

  - [ ] 17.2 实现 AI 生成控制器
    - 创建 `src/api/controllers/ai.controller.zig`
    - 实现 generateTestCases 方法（解析请求体、调用 AI 生成器、返回响应）
    - 实现 generateRequirement 方法
    - 实现 analyzeFeedback 方法
    - 实现进度推送（可选，使用 WebSocket 或 SSE）
    - _需求: 2.1, 2.4, 5.3, 7.5_

  - [ ] 17.3 实现项目控制器
    - 创建 `src/api/controllers/project.controller.zig`
    - 实现 create, get, update, delete 方法
    - 实现 archive, restore 方法
    - 实现 getStatistics 方法
    - _需求: 3.1, 3.2, 3.5, 3.6, 3.7, 3.8_

  - [ ] 17.4 实现模块控制器
    - 创建 `src/api/controllers/module.controller.zig`
    - 实现 create, get, update, delete 方法
    - 实现 getTree 方法
    - 实现 move 方法
    - 实现 getStatistics 方法
    - _需求: 4.1, 4.2, 4.4, 4.6_

  - [ ] 17.5 实现需求控制器
    - 创建 `src/api/controllers/requirement.controller.zig`
    - 实现 create, get, update, delete 方法
    - 实现 linkTestCase, unlinkTestCase 方法
    - 实现 importFromExcel, exportToExcel 方法
    - _需求: 5.1, 5.2, 5.8, 5.10_

  - [ ] 17.6 实现反馈控制器
    - 创建 `src/api/controllers/feedback.controller.zig`
    - 实现 create, get, update, delete 方法
    - 实现 addFollowUp 方法
    - 实现 batchAssign, batchUpdateStatus 方法
    - 实现 exportToExcel 方法
    - _需求: 7.1, 7.2, 7.3, 7.6, 7.8, 7.10_

  - [ ] 17.7 实现统计控制器
    - 创建 `src/api/controllers/statistics.controller.zig`
    - 实现 getModuleDistribution 方法
    - 实现 getBugDistribution 方法
    - 实现 getFeedbackDistribution 方法
    - 实现 getQualityTrend 方法（支持时间范围筛选）
    - 实现 exportChart 方法
    - _需求: 6.1, 6.3, 6.4, 6.5, 6.6, 6.7_

- [ ] 18. 注册路由
  - 在 `src/api/bootstrap.zig` 中注册所有质量中心路由
  - 注册测试用例路由（POST/GET/PUT/DELETE /api/quality/test-cases）
  - 注册 AI 生成路由（POST /api/quality/ai/*）
  - 注册项目路由（POST/GET/PUT/DELETE /api/quality/projects）
  - 注册模块路由（POST/GET/PUT/DELETE /api/quality/modules）
  - 注册需求路由（POST/GET/PUT/DELETE /api/quality/requirements）
  - 注册反馈路由（POST/GET/PUT/DELETE /api/quality/feedbacks）
  - 注册统计路由（GET /api/quality/statistics/*）
  - 添加权限中间件（可选）
  - _需求: 10.5_

- [ ] 19. 注册到 DI 容器
  - 在 `root.zig` 中创建 registerQualityCenterServices 函数
  - 注册所有仓储实例（MysqlTestCaseRepository, MysqlProjectRepository 等）
  - 注册 AI 生成器实例（OpenAIGenerator）
  - 注册所有服务（TestCaseService, ProjectService 等）
  - 使用 factory 函数解析依赖
  - _需求: 10.6_

- [ ] 20. Checkpoint - 确保所有 API 测试通过
  - 使用 Postman 或 curl 测试所有 API 端点
  - 验证请求体解析正确
  - 验证响应格式正确
  - 验证错误处理正确
  - 验证权限控制正确（如果实现）
  - 如有问题，询问用户并修复

### 阶段 6: 前端实现（Frontend）

- [ ] 21. 创建 API 客户端
  - 创建 `ecom-admin/src/api/quality-center.ts`
  - 定义所有 API 接口函数（searchTestCases, createTestCase, batchDeleteTestCases 等）
  - 定义 TypeScript 类型（TestCase, Project, Module, Requirement, Feedback 等）
  - 使用 axios 发送请求
  - 实现错误处理和重试机制
  - _需求: 11.1_

- [ ] 22. 实现测试用例管理页面
  - [ ] 22.1 创建测试用例列表页面
    - 创建 `ecom-admin/src/views/quality-center/test-case/index.vue`
    - 使用 TestCaseTable 组件展示列表
    - 实现搜索和筛选功能
    - 实现分页功能
    - 实现批量操作（批量删除、批量更新状态、批量分配）
    - _需求: 1.1, 1.3, 1.4, 1.5, 1.9, 1.10, 11.1, 11.2_

  - [ ] 22.2 创建测试用例表格组件
    - 创建 `ecom-admin/src/views/quality-center/test-case/components/TestCaseTable.vue`
    - 使用 Arco Design Table 组件
    - 实现列定义（ID、标题、状态、优先级、负责人、创建时间、操作）
    - 实现行选择（checkbox）
    - 实现操作按钮（查看、编辑、执行、删除）
    - 实现批量操作栏
    - _需求: 1.1, 1.3, 1.4, 1.5, 11.1, 11.9_

  - [ ] 22.3 创建测试用例表单组件
    - 创建 `ecom-admin/src/views/quality-center/test-case/components/TestCaseForm.vue`
    - 实现表单字段（标题、项目、模块、需求、优先级、前置条件、测试步骤、预期结果、负责人、标签）
    - 实现表单验证（必填字段、长度限制）
    - 实现提交和取消按钮
    - _需求: 1.1, 1.2, 11.1_

  - [ ] 22.4 创建 AI 生成对话框组件
    - 创建 `ecom-admin/src/views/quality-center/test-case/components/AIGenerateDialog.vue`
    - 实现步骤 1：选择需求（下拉框、需求详情展示）
    - 实现步骤 2：生成中（加载动画、进度条、进度文本）
    - 实现步骤 3：预览和编辑（生成结果列表、批量编辑、批量保存）
    - 实现重新生成按钮
    - _需求: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 11.1, 11.3_

  - [ ] 22.5 创建执行历史组件
    - 创建 `ecom-admin/src/views/quality-center/test-case/components/ExecutionHistory.vue`
    - 使用 Arco Design Timeline 组件展示执行历史
    - 显示执行时间、执行人、执行状态、实际结果、备注
    - _需求: 1.6, 1.7, 11.1_

- [ ] 23. 实现项目管理页面
  - [ ] 23.1 创建项目列表页面
    - 创建 `ecom-admin/src/views/quality-center/project/index.vue`
    - 使用 ProjectCard 组件展示项目卡片
    - 实现创建项目按钮
    - 实现搜索和筛选功能
    - _需求: 3.1, 11.1, 11.2_

  - [ ] 23.2 创建项目卡片组件
    - 创建 `ecom-admin/src/views/quality-center/project/components/ProjectCard.vue`
    - 显示项目名称、描述、状态、负责人
    - 显示项目统计数据（用例总数、通过率、Bug 数量）
    - 实现操作按钮（查看详情、编辑、归档、删除）
    - _需求: 3.1, 3.5, 11.1_

  - [ ] 23.3 创建项目详情页面
    - 创建 `ecom-admin/src/views/quality-center/project/detail.vue`
    - 显示项目基本信息
    - 显示项目统计数据（使用 ProjectStatistics 组件）
    - 显示项目成员列表
    - 显示项目设置
    - 实现编辑和删除按钮
    - _需求: 3.1, 3.3, 3.4, 3.5, 11.1_

  - [ ] 23.4 创建项目统计组件
    - 创建 `ecom-admin/src/views/quality-center/project/components/ProjectStatistics.vue`
    - 使用 Arco Design Statistic 组件展示统计数据
    - 显示用例总数、执行次数、通过率、Bug 数量、需求覆盖率
    - 实现骨架屏加载效果
    - _需求: 3.5, 3.6, 11.1, 11.8_

- [ ] 24. 实现模块管理页面
  - [ ] 24.1 创建模块管理页面
    - 创建 `ecom-admin/src/views/quality-center/module/index.vue`
    - 使用 ModuleTree 组件展示模块树
    - 实现创建模块按钮
    - 实现搜索和高亮功能
    - _需求: 4.1, 4.2, 4.8, 11.1_

  - [ ] 24.2 创建模块树组件
    - 创建 `ecom-admin/src/views/quality-center/module/components/ModuleTree.vue`
    - 使用 Arco Design Tree 组件
    - 实现树形结构展示（最多 5 层）
    - 实现拖拽调整层级和顺序
    - 实现展开和折叠状态记忆
    - 实现节点操作按钮（编辑、删除、添加子模块）
    - 显示模块统计数据（用例总数、通过率）
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.9, 11.1, 11.10_

  - [ ] 24.3 创建模块表单组件
    - 创建 `ecom-admin/src/views/quality-center/module/components/ModuleForm.vue`
    - 实现表单字段（模块名称、父模块、描述）
    - 实现表单验证（名称唯一性、层级深度限制）
    - _需求: 4.1, 4.3, 4.10, 11.1_

- [ ] 25. 实现需求管理页面
  - [ ] 25.1 创建需求列表页面
    - 创建 `ecom-admin/src/views/quality-center/requirement/index.vue`
    - 使用 RequirementTable 组件展示列表
    - 实现搜索和筛选功能（按项目、状态、优先级、负责人、关键字）
    - 实现 AI 生成需求按钮
    - 实现导入和导出按钮
    - _需求: 5.1, 5.3, 5.9, 5.10, 11.1_

  - [ ] 25.2 创建需求表格组件
    - 创建 `ecom-admin/src/views/quality-center/requirement/components/RequirementTable.vue`
    - 使用 Arco Design Table 组件
    - 实现列定义（ID、标题、状态、优先级、负责人、覆盖率、创建时间、操作）
    - 实现操作按钮（查看、编辑、删除）
    - _需求: 5.1, 5.6, 11.1_

  - [ ] 25.3 创建需求详情页面
    - 创建 `ecom-admin/src/views/quality-center/requirement/detail.vue`
    - 显示需求基本信息
    - 显示需求状态流转历史
    - 显示关联测试用例列表（使用 LinkedTestCases 组件）
    - 实现编辑和删除按钮
    - _需求: 5.1, 5.4, 5.5, 5.7, 11.1_

  - [ ] 25.4 创建关联测试用例组件
    - 创建 `ecom-admin/src/views/quality-center/requirement/components/LinkedTestCases.vue`
    - 显示关联测试用例列表
    - 实现添加关联按钮（弹出测试用例选择对话框）
    - 实现移除关联按钮
    - _需求: 5.7, 5.8, 11.1_

- [ ] 26. 实现反馈管理页面
  - [ ] 26.1 创建反馈列表页面
    - 创建 `ecom-admin/src/views/quality-center/feedback/index.vue`
    - 使用 FeedbackTable 组件展示列表
    - 实现高级筛选（按状态、负责人、严重程度、提交时间、关键字）
    - 实现批量操作（批量指派、批量修改状态、批量删除）
    - 实现导出按钮
    - _需求: 7.1, 7.2, 7.3, 7.6, 7.7, 7.10, 11.1_

  - [ ] 26.2 创建反馈表格组件
    - 创建 `ecom-admin/src/views/quality-center/feedback/components/FeedbackTable.vue`
    - 使用 Arco Design Table 组件
    - 实现列定义（ID、标题、类型、严重程度、状态、负责人、跟进进度、提交时间、操作）
    - 实现行选择（checkbox）
    - 实现操作按钮（查看、编辑、删除）
    - _需求: 7.1, 7.2, 7.3, 7.4, 11.1_

  - [ ] 26.3 创建反馈详情页面
    - 创建 `ecom-admin/src/views/quality-center/feedback/detail.vue`
    - 显示反馈基本信息
    - 显示 AI 分析结果（Bug 类型、严重程度、影响范围、建议操作）
    - 显示跟进时间线（使用 FollowUpTimeline 组件）
    - 实现添加跟进记录按钮
    - 实现编辑和删除按钮
    - _需求: 7.1, 7.4, 7.5, 7.8, 11.1_

  - [ ] 26.4 创建跟进时间线组件
    - 创建 `ecom-admin/src/views/quality-center/feedback/components/FollowUpTimeline.vue`
    - 使用 Arco Design Timeline 组件
    - 显示跟进记录（时间、跟进人、内容）
    - 支持富文本显示（图片、链接、代码块）
    - _需求: 7.4, 7.8, 11.1_

- [ ] 27. 实现数据可视化页面
  - [ ] 27.1 创建质量中心首页
    - 创建 `ecom-admin/src/views/quality-center/dashboard/index.vue`
    - 使用 ModuleDistribution, BugDistribution, FeedbackDistribution, QualityTrend 组件
    - 实现时间范围筛选（最近 7 天、最近 30 天、最近 90 天、自定义）
    - 实现导出按钮
    - _需求: 6.1, 6.3, 6.4, 6.5, 6.6, 6.7, 11.1, 11.2_

  - [ ] 27.2 创建模块质量分布图组件
    - 创建 `ecom-admin/src/views/quality-center/dashboard/components/ModuleDistribution.vue`
    - 使用 ECharts 饼图
    - 实现点击跳转到模块详情页
    - 实现悬停显示详细数据
    - _需求: 6.1, 6.2, 6.9, 11.1_

  - [ ] 27.3 创建 Bug 质量分布图组件
    - 创建 `ecom-admin/src/views/quality-center/dashboard/components/BugDistribution.vue`
    - 使用 ECharts 饼图或柱状图
    - 按类型分类（功能缺陷、性能问题、UI 问题、兼容性问题）
    - _需求: 6.3, 6.9, 11.1_

  - [ ] 27.4 创建反馈状态分布图组件
    - 创建 `ecom-admin/src/views/quality-center/dashboard/components/FeedbackDistribution.vue`
    - 使用 ECharts 饼图
    - 按状态分类（待处理、处理中、已解决、已关闭）
    - _需求: 6.4, 6.9, 11.1_

  - [ ] 27.5 创建质量趋势图组件
    - 创建 `ecom-admin/src/views/quality-center/dashboard/components/QualityTrend.vue`
    - 使用 ECharts 折线图
    - 显示通过率、Bug 数量、执行次数趋势
    - 支持时间范围筛选
    - 支持缩放和平移
    - _需求: 6.5, 6.6, 6.9, 11.1_

- [ ] 28. 实现脑图视图页面
  - [ ] 28.1 创建脑图视图页面
    - 创建 `ecom-admin/src/views/quality-center/mindmap/index.vue`
    - 使用 MindMapCanvas 组件
    - 实现搜索和高亮功能
    - 实现缩放和平移控制
    - 实现导出按钮
    - _需求: 8.1, 8.2, 8.6, 8.7, 8.8, 8.9, 11.1_

  - [ ] 28.2 创建脑图画布组件
    - 创建 `ecom-admin/src/views/quality-center/mindmap/components/MindMapCanvas.vue`
    - 使用 Canvas 或 SVG 绘制脑图
    - 实现自适应缩放（根据节点数量）
    - 实现节点大小自动调整（根据子节点数量）
    - 实现平滑动画过渡（300 毫秒）
    - 使用贝塞尔曲线绘制连接线
    - 实现虚拟渲染（节点超过 100 个时）
    - 实现节点点击事件（展示详细信息）
    - _需求: 8.1, 8.2, 8.3, 8.4, 8.5, 8.8, 8.9, 8.10, 11.1_

  - [ ] 28.3 创建脑图节点组件
    - 创建 `ecom-admin/src/views/quality-center/mindmap/components/MindMapNode.vue`
    - 显示节点标题
    - 显示节点统计数据（测试用例数、通过率、Bug 数量）
    - 实现展开和折叠按钮
    - _需求: 8.10, 11.1_

- [ ] 29. 实现前端优化
  - [ ] 29.1 实现响应式设计
    - 适配桌面端（1920x1080）
    - 适配平板端（768x1024）
    - 适配移动端（375x667）
    - 使用 Arco Design 响应式栅格系统
    - _需求: 11.2_

  - [ ] 29.2 实现操作反馈
    - 所有操作在 200 毫秒内提供视觉反馈（加载动画、按钮状态变化）
    - 使用 Toast 提示操作结果（成功、失败、警告）
    - 使用 Modal 确认危险操作（删除、批量操作）
    - _需求: 11.3, 11.4, 11.5_

  - [ ] 29.3 实现键盘快捷键
    - Ctrl+S 保存
    - Ctrl+F 搜索
    - Esc 关闭弹窗
    - _需求: 11.6_

  - [ ] 29.4 实现主题切换
    - 支持暗色模式和亮色模式切换
    - 使用 Arco Design 主题配置
    - _需求: 11.7_

  - [ ] 29.5 实现骨架屏
    - 在所有列表和详情页面添加骨架屏
    - 使用 Arco Design Skeleton 组件
    - _需求: 11.8_

  - [ ] 29.6 实现表格优化
    - 支持表格列宽调整
    - 支持表格列显示隐藏
    - 支持表格排序和筛选状态记忆（使用 localStorage）
    - _需求: 11.9, 11.10_

- [ ] 30. Checkpoint - 确保所有前端功能测试通过
  - 测试所有页面加载正常
  - 测试所有表单提交正常
  - 测试所有批量操作正常
  - 测试所有图表渲染正常
  - 测试响应式设计在不同设备上正常
  - 测试键盘快捷键正常
  - 测试主题切换正常
  - 如有问题，询问用户并修复

### 阶段 7: 测试实现

- [ ] 31. 实现后端单元测试
  - [ ]* 31.1 测试测试用例服务
    - 创建 `test/test_case_service_test.zig`
    - 测试 create 方法（成功场景、标题为空、标题过长、无效项目 ID、无效模块 ID）
    - 测试 update 方法
    - 测试 delete 方法
    - 测试 batchDelete 方法
    - 测试 batchUpdateStatus 方法
    - 测试 batchUpdateAssignee 方法
    - 测试 execute 方法
    - 测试 search 方法
    - _需求: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.9, 10.10_

  - [ ]* 31.2 测试项目服务
    - 创建 `test/project_service_test.zig`
    - 测试 create, update, delete, archive, restore 方法
    - 测试 getStatistics 方法
    - _需求: 3.1, 3.5, 3.7, 10.10_

  - [ ]* 31.3 测试模块服务
    - 创建 `test/module_service_test.zig`
    - 测试 create, update, delete 方法
    - 测试 getTree 方法
    - 测试 move 方法（验证层级深度限制）
    - 测试 getStatistics 方法
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.6, 10.10_

  - [ ]* 31.4 测试需求服务
    - 创建 `test/requirement_service_test.zig`
    - 测试 create, update, delete 方法
    - 测试 updateStatus 方法（验证状态流转合法性）
    - 测试 linkTestCase, unlinkTestCase 方法
    - 测试 calculateCoverage 方法
    - _需求: 5.1, 5.4, 5.6, 5.8, 10.10_

  - [ ]* 31.5 测试反馈服务
    - 创建 `test/feedback_service_test.zig`
    - 测试 create, update, delete 方法
    - 测试 addFollowUp 方法
    - 测试 batchAssign, batchUpdateStatus 方法
    - _需求: 7.1, 7.3, 7.6, 7.8, 10.10_

  - [ ]* 31.6 测试统计服务
    - 创建 `test/statistics_service_test.zig`
    - 测试 getModuleDistribution 方法
    - 测试 getBugDistribution 方法
    - 测试 getFeedbackDistribution 方法
    - 测试 getQualityTrend 方法
    - _需求: 6.1, 6.3, 6.4, 6.5, 10.10_

- [ ] 32. 实现后端属性测试
  - [ ]* 32.1 测试测试用例 CRUD 操作完整性
    - 创建 `test/test_case_properties_test.zig`
    - 实现属性 1：对于任何有效的测试用例，创建后应能通过 ID 查询到相同的测试用例
    - 实现属性 2：对于任何缺少必填字段的测试用例创建请求，系统应拒绝
    - 实现属性 3：对于任何测试用例 ID 集合，批量删除后，所有指定 ID 的测试用例都应无法查询到
    - 实现属性 4：对于任何测试用例 ID 集合和目标状态，批量更新后，所有指定 ID 的测试用例状态都应为目标状态
    - 实现属性 5：对于任何测试用例 ID 集合和负责人，批量分配后，所有指定 ID 的测试用例负责人都应为指定负责人
    - 使用 quickcheck 库生成随机输入
    - 运行至少 100 次迭代
    - _需求: 1.1, 1.2, 1.3, 1.4, 1.5, 10.10_
    - _验证属性: 1, 2, 3, 4, 5_

  - [ ]* 32.2 测试测试执行记录完整性
    - 实现属性 6：对于任何测试用例执行操作，系统应创建包含执行结果、执行时间和执行人的执行记录
    - 实现属性 7：对于任何测试用例，多次执行后，执行历史记录数量应等于执行次数
    - _需求: 1.6, 1.7, 10.10_
    - _验证属性: 6, 7_

  - [ ]* 32.3 测试关联关系双向性
    - 实现属性 8：对于任何测试用例和需求/Bug/反馈的关联操作，从测试用例应能查询到关联对象，从关联对象也应能查询到测试用例
    - _需求: 1.8, 10.10_
    - _验证属性: 8_

  - [ ]* 32.4 测试搜索和分页准确性
    - 实现属性 9：对于任何搜索条件，返回的所有测试用例都应满足所有指定条件
    - 实现属性 10：对于任何测试用例查询，每页返回的记录数应不超过 20 条，且所有页的记录总数应等于总记录数
    - _需求: 1.9, 1.10, 10.10_
    - _验证属性: 9, 10_

  - [ ]* 32.5 测试 AI 生成完整性
    - 实现属性 11：对于任何需求，AI 生成的测试用例应包含标题、前置条件、测试步骤和预期结果四个必需字段
    - 实现属性 12：对于任何 AI 生成过程，进度值应在 0-100 之间单调递增
    - 实现属性 13：对于任何生成的测试用例集合，批量保存后，数据库中应存在相同数量的测试用例记录
    - 实现属性 14：对于任何从需求生成并保存的测试用例，其 requirement_id 字段应等于源需求的 ID
    - _需求: 2.3, 2.4, 2.7, 2.8, 10.10_
    - _验证属性: 11, 12, 13, 14_

  - [ ]* 32.6 测试项目统计准确性
    - 实现属性 16：对于任何项目，统计的用例总数应等于该项目下所有测试用例的数量，通过率应等于通过用例数除以总用例数
    - _需求: 3.5, 10.10_
    - _验证属性: 16_

  - [ ]* 32.7 测试模块层级约束
    - 实现属性 20：对于任何模块，其层级深度应不超过 5 层
    - 实现属性 22：对于任何同一父模块下的模块，名称应唯一，尝试创建重名模块应被拒绝
    - _需求: 4.3, 4.10, 10.10_
    - _验证属性: 20, 22_

  - [ ]* 32.8 测试需求状态流转合法性
    - 实现属性 23：对于任何需求状态变更，新状态应符合状态流转规则
    - 实现属性 24：对于任何需求状态变更，系统应记录包含时间、操作人、原状态和新状态的历史记录
    - 实现属性 25：对于任何需求，覆盖率应等于关联测试用例数除以建议测试用例数
    - _需求: 5.4, 5.5, 5.6, 10.10_
    - _验证属性: 23, 24, 25_

  - [ ]* 32.9 测试 JSON 序列化 Round-Trip
    - 实现属性 50：对于任何有效的实体对象，序列化为 JSON 后再反序列化，应产生等价对象
    - 实现属性 51：对于任何包含错误类型字段的 JSON 请求，系统应拒绝并返回类型错误信息
    - 实现属性 52：对于任何缺少可选字段的 JSON 请求，反序列化后应使用字段的默认值
    - _需求: 13.5, 13.6, 13.7, 10.10_
    - _验证属性: 50, 51, 52_

  - [ ]* 32.10 测试 SQL 注入防护
    - 实现属性 35：对于任何包含 SQL 注入攻击载荷的输入，系统应拒绝执行并返回错误
    - _需求: 9.3, 10.10_
    - _验证属性: 35_

  - [ ]* 32.11 测试批量查询性能优化
    - 实现属性 36：对于任何批量查询操作，使用 whereIn 的查询次数应等于 1，而不是 N
    - 实现属性 37：对于任何包含关联数据的查询，使用关系预加载的查询次数应少于不使用预加载的查询次数
    - _需求: 9.4, 9.5, 10.10_
    - _验证属性: 36, 37_

- [ ] 33. 实现前端单元测试
  - [ ]* 33.1 测试测试用例表格组件
    - 创建 `ecom-admin/test/test-case-table.spec.ts`
    - 测试渲染测试用例列表
    - 测试行选择
    - 测试批量删除
    - 测试批量更新状态
    - 测试批量分配负责人
    - 使用 Vitest 和 @vue/test-utils
    - _需求: 1.1, 1.3, 1.4, 1.5, 11.1_

  - [ ]* 33.2 测试 AI 生成对话框组件
    - 创建 `ecom-admin/test/ai-generate-dialog.spec.ts`
    - 测试步骤切换
    - 测试需求选择
    - 测试生成进度显示
    - 测试结果预览和编辑
    - 测试批量保存
    - _需求: 2.1, 2.4, 2.5, 2.6, 2.7, 11.1_

  - [ ]* 33.3 测试模块树组件
    - 创建 `ecom-admin/test/module-tree.spec.ts`
    - 测试树形结构渲染
    - 测试拖拽调整层级
    - 测试展开和折叠
    - 测试搜索和高亮
    - _需求: 4.1, 4.2, 4.4, 4.8, 4.9, 11.1_

  - [ ]* 33.4 测试图表组件
    - 创建 `ecom-admin/test/charts.spec.ts`
    - 测试模块质量分布图渲染
    - 测试 Bug 质量分布图渲染
    - 测试反馈状态分布图渲染
    - 测试质量趋势图渲染
    - 测试图表交互（悬停、点击、缩放）
    - _需求: 6.1, 6.3, 6.4, 6.5, 6.9, 11.1_

  - [ ]* 33.5 测试脑图组件
    - 创建 `ecom-admin/test/mindmap.spec.ts`
    - 测试脑图渲染
    - 测试节点展开和折叠
    - 测试缩放和平移
    - 测试搜索和高亮
    - _需求: 8.1, 8.2, 8.3, 8.6, 8.8, 8.9, 11.1_

- [ ] 34. Checkpoint - 确保所有测试通过
  - 运行所有后端单元测试：`zig build test`
  - 运行所有后端属性测试：`zig build test`
  - 运行所有前端单元测试：`npm run test`
  - 验证测试覆盖率达到 80% 以上
  - 如有测试失败，询问用户并修复

### 阶段 8: 集成和部署

- [ ] 35. 集成测试
  - [ ] 35.1 测试完整的测试用例管理流程
    - 创建项目 → 创建模块 → 创建测试用例 → 执行测试用例 → 查看执行历史
    - 验证数据一致性
    - 验证缓存生效
    - _需求: 1.1, 1.6, 1.7, 3.1, 4.1_

  - [ ] 35.2 测试 AI 生成流程
    - 创建需求 → AI 生成测试用例 → 批量保存 → 验证关联关系
    - 验证生成结果准确性
    - 验证性能符合要求（30 秒内完成）
    - _需求: 2.1, 2.2, 2.3, 2.7, 2.8, 2.10_

  - [ ] 35.3 测试批量操作流程
    - 批量删除 → 验证数据删除 → 验证缓存清除
    - 批量更新状态 → 验证状态更新
    - 批量分配负责人 → 验证负责人更新
    - _需求: 1.3, 1.4, 1.5, 7.6_

  - [ ] 35.4 测试数据可视化流程
    - 查看质量中心首页 → 验证图表渲染 → 点击图表跳转 → 验证跳转正确
    - 切换时间范围 → 验证数据更新
    - 导出图表 → 验证导出成功
    - _需求: 6.1, 6.2, 6.5, 6.6, 6.7, 6.8_

  - [ ] 35.5 测试性能要求
    - 测试用例列表查询 < 500ms
    - 项目统计查询 < 1s
    - 图表加载 < 1s
    - 模块拖拽更新 < 200ms
    - 操作视觉反馈 < 200ms
    - _需求: 3.6, 4.5, 6.8, 11.3, 12.1, 12.2_

- [ ] 36. 性能优化验证
  - 验证关系预加载避免 N+1 查询
  - 验证批量查询使用 whereIn
  - 验证缓存命中率 > 80%
  - 验证虚拟渲染优化大数据集渲染
  - 验证索引优化查询性能
  - _需求: 9.4, 9.5, 9.10, 8.5, 12.5_

- [ ] 37. 安全性验证
  - 验证所有数据库操作使用参数化查询
  - 验证禁止使用 rawExec
  - 验证 SQL 注入防护生效
  - 验证输入验证正确
  - 验证权限控制正确（如果实现）
  - _需求: 9.1, 9.2, 9.3_

- [ ] 38. 内存安全验证
  - 验证所有 ORM 查询结果正确释放
  - 验证所有深拷贝字符串正确释放
  - 验证所有 Arena Allocator 正确释放
  - 验证无内存泄漏（使用 Zig 内存检测工具）
  - _需求: 9.6, 9.7, 9.8, 9.9_

- [ ] 39. 部署准备
  - 更新 README.md 文档
  - 更新 API 文档
  - 更新用户手册
  - 准备演示数据
  - 准备演示视频

- [ ] 40. 最终验收
  - 所有需求验收标准通过
  - 所有测试通过
  - 性能指标达标
  - 安全性验证通过
  - 内存安全验证通过
  - 用户验收测试通过

## 任务完成标准

每个任务完成后应满足以下标准：

1. **代码质量**: 遵循 ZigCMS 开发范式和 Zig 语言最佳实践
2. **功能完整**: 实现所有需求验收标准
3. **测试覆盖**: 核心功能有单元测试覆盖（可选任务除外）
4. **性能达标**: 满足性能要求（响应时间、并发数、吞吐量）
5. **安全合规**: 通过安全性验证（SQL 注入防护、输入验证、权限控制）
6. **内存安全**: 通过内存安全验证（无内存泄漏、正确释放资源）
7. **文档完善**: 代码注释清晰，API 文档完整

## 预估工作量

- **阶段 1**: 数据库和基础设施准备 - 0.5 天
- **阶段 2**: 领域层实现 - 1 天
- **阶段 3**: 基础设施层实现 - 2 天
- **阶段 4**: 应用层实现 - 2 天
- **阶段 5**: API 层实现 - 1.5 天
- **阶段 6**: 前端实现 - 4 天
- **阶段 7**: 测试实现 - 2 天（可选）
- **阶段 8**: 集成和部署 - 1 天

**总计**: 约 14 天（不包括可选测试任务约 12 天）

## 优先级说明

- **P0（必须）**: 核心功能实现（阶段 1-6）
- **P1（重要）**: 集成测试和部署（阶段 8）
- **P2（可选）**: 单元测试和属性测试（阶段 7）

## 注意事项

1. **内存管理**: 所有 ORM 查询结果必须使用 Arena Allocator 或深拷贝字符串字段，避免悬垂指针
2. **SQL 安全**: 禁止使用 rawExec，所有查询必须使用 ORM QueryBuilder 和参数化查询
3. **性能优化**: 使用关系预加载（with 方法）避免 N+1 查询，使用 whereIn 优化批量查询
4. **错误处理**: 使用 try/catch/errdefer 显式处理错误，确保资源正确释放
5. **缓存策略**: 高频查询使用缓存，数据更新时清除相关缓存
6. **前端优化**: 大数据集使用虚拟渲染，操作提供及时反馈，使用骨架屏优化加载体验
7. **测试驱动**: 可选的测试任务标记为 `*`，建议优先实现核心功能，时间充裕再补充测试

## 后续建议

完成本任务列表后，老铁可以考虑以下改进方向：

1. **权限控制增强**: 实现基于角色的访问控制（RBAC），细化权限粒度
2. **通知系统**: 实现邮件通知、站内通知、WebSocket 实时通知
3. **报表系统**: 实现自定义报表模板，支持多种导出格式
4. **插件系统**: 实现插件化 AI 生成器，支持多种 AI 模型
5. **国际化**: 支持多语言切换（中文、英文）
6. **移动端优化**: 开发移动端专用界面，优化触摸交互
7. **性能监控**: 集成 APM 工具，监控系统性能和错误
8. **自动化测试**: 实现 E2E 测试，覆盖完整业务流程
9. **CI/CD**: 配置自动化构建、测试、部署流程
10. **文档完善**: 编写详细的开发文档、API 文档、用户手册

祝老铁开发顺利！🚀
