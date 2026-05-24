# 项目功能模块分析 Spec

## Why
该项目是一个电商管理系统（ecom-admin），包含后端（Zig + DDD架构）和前端（Vue 3 + TypeScript），功能覆盖面广，但当前项目定位为 CMS（内容管理系统），需要对所有功能模块进行全面分析，识别各模块在 CMS 中的必要性，为后续模块精简提供决策依据。

## What Changes
- 全面梳理并列出项目所有功能模块（前端 + 后端）
- 按功能域分组，建立模块层级大纲
- 总结每个模块的核心代码文件及函数
- 评估每个模块作为 CMS 的必要性（核心/冗余/可选）
- 标记 CMS 核心保留模块与可删除模块

## Impact
- Affected specs: 无（全新分析）
- Affected code: 全部代码文件（分析覆盖，不修改）

---

## 项目总览

### 技术栈
| 层级 | 技术 | 说明 |
|------|------|------|
| 后端 | Zig | DDD 分层架构（Core → Application → Domain → Infrastructure → API） |
| 前端 | Vue 3 + TypeScript + Pinia/Vuex + Vite | 后台管理面板 |
| 数据库 | MySQL/PostgreSQL (通过 ORM 抽象) | 关系型数据库 |
| 缓存 | Redis | 通过 cache 服务抽象 |
| 协议 | REST API + WebSocket | HTTP + 实时通信 |

### 代码目录总览
```
/workspace/
├── src/                          # 后端 Zig 源码 (DDD 分层)
│   ├── main.zig                  # 程序入口
│   ├── core/                     # 核心层：DI、配置、工具、设计模式
│   ├── application/              # 应用层：服务管理、缓存
│   ├── domain/                   # 领域层：实体、仓储接口
│   ├── infrastructure/           # 基础设施层：数据库、缓存实现
│   ├── api/                      # API 层：控制器、DTO、中间件、启动
│   ├── mcp/                      # MCP 协议模块
│   └── plugins/                  # 插件系统
├── ecom-admin/                   # 前端 Vue 3 管理面板
│   └── src/
│       ├── api/                  # API 接口层
│       ├── router/               # 路由配置
│       │   └── routes/modules/   # 按模块拆分路由
│       ├── store/                # 状态管理 (Pinia/Vuex)
│       │   └── modules/          # app、user、tab-bar
│       ├── views/                # 页面组件
│       │   ├── cms/              # CMS 模块页面
│       │   ├── business/         # 业务模块页面
│       │   ├── quality-center/   # 质量中心页面
│       │   └── system/           # 系统管理页面
│       ├── components/           # 通用组件
│       ├── layout/               # 布局组件
│       ├── utils/                # 工具函数
│       └── types/                # 类型定义
└── other files...
```

---

## 一、后端架构层（基础设施层）

### 1.1 Core 核心层
**目录**: `/workspace/src/core/`
**必要性**: ✅ CMS 核心依赖

| 子模块 | 文件 | 功能概述 |
|--------|------|----------|
| mod | core/mod.zig | 核心层入口，整合 DI、错误、日志、配置、工具 |
| config | core/config/mod.zig | 系统配置结构体、配置加载器、配置管理器 |
| di | core/di/mod.zig | 全局依赖注入容器，服务注册与解析 |
| utils | core/utils/mod.zig | 通用工具函数集合 (JWT、Redis、字符串等) |
| patterns | core/patterns/mod.zig | DDD 设计模式实现 (值对象、实体、聚合根、领域事件、仓储) |

**CMS 必要性分析**: Core 层是整个系统的基石，所有业务模块都依赖它。DI 容器、配置管理、工具函数是 CMS 运行的基础，**必须保留**。

---

### 1.2 Application 应用层
**目录**: `/workspace/src/application/`
**必要性**: ✅ CMS 核心依赖

| 子模块 | 文件 | 功能概述 |
|--------|------|----------|
| mod | application/mod.zig | 应用层入口 |
| services/mod | application/services/mod.zig | ServiceManager：缓存、插件、指标、JSON、事件总线、日志 |
| cache | application/services/cache/ | CacheService、TypedCache 缓存服务 |

**CMS 必要性分析**: 服务管理器提供的缓存、事件总线、日志是 CMS 运行的基础服务。插件系统是 CMS 可扩展性的关键。

---

### 1.3 Domain 领域层
**目录**: `/workspace/src/domain/`
**必要性**: ⚠️ 部分核心保留，部分按需删除

#### Entities（领域实体）
| 文件 | 实体 | CMS 必要性 |
|------|------|-------------|
| admin.model.zig | Admin 管理员 | ✅ 必须 |
| user.model.zig | User 用户 | ✅ 必须 |
| role.model.zig | Role 角色 | ✅ 必须 (权限) |
| menu.model.zig | Menu 菜单 | ✅ 必须 (导航) |
| dict.model.zig | Dict 字典 | ✅ 必须 (配置) |
| setting.model.zig | Setting 设置 | ✅ 必须 (站点配置) |
| upload.model.zig | Upload 上传 | ✅ 必须 (媒体) |
| task.model.zig | Task 任务 | ⚠️ 可选 (定时任务) |
| module.model.zig | Module 模块 | ⚠️ 可选 (模块管理) |
| project.model.zig | Project 项目 | ❌ 非CMS (质量中心) |
| requirement.model.zig | Requirement 需求 | ❌ 非CMS (质量中心) |
| feedback.model.zig | Feedback 反馈 | ❌ 非CMS (质量中心) |
| feedback_comment.model.zig | FeedbackComment 反馈评论 | ❌ 非CMS (质量中心) |
| sensitive_word.model.zig | SensitiveWord 敏感词 | ⚠️ 可选 (内容审核) |
| moderation_log.model.zig | ModerationLog 审核日志 | ⚠️ 可选 (内容审核) |
| integration_models.zig | SysDept/SysRole/SysMenu 等集成模型 | ✅ 必须 |
| sys_oauth_bind.model.zig | SysOAuthBind OAuth绑定 | ⚠️ 可选 (第三方登录) |
| sys_oauth_log.model.zig | SysOAuthLog OAuth日志 | ⚠️ 可选 (第三方登录) |

#### Repositories（仓储接口）
共 30+ 个仓储接口文件，对应每个实体一个仓储接口。CMS 核心需要保留：
- sys_admin, sys_role, sys_menu, sys_dept, sys_config, sys_dict, sys_dict_item
- sys_role_menu, sys_role_permission
- category, tag, media, template, model, seo, workflow (CMS内容管理)
- user

可删除：
- project, module, requirement, feedback, feedback_comment, test_case, test_execution
- sensitive_word, moderation_log
- biz_member 系列, op_task 系列

---

### 1.4 Infrastructure 基础设施层
**目录**: `/workspace/src/infrastructure/`
**必要性**: ✅ CMS 核心依赖

| 子模块 | 文件 | 功能概述 |
|--------|------|----------|
| mod | infrastructure/mod.zig | 基础设施层入口，数据库、缓存、HTTP、Redis 实现 |
| database | infrastructure/database/mod.zig | 数据库连接、事务、ORM 接口 |

**CMS 必要性分析**: 数据库和缓存实现是 CMS 持久化的基础，**必须保留**。

---

### 1.5 MCP 模块
**目录**: `/workspace/src/mcp/`
**必要性**: ⚠️ 可选

| 子模块 | 功能概述 |
|--------|----------|
| MCP 协议 | AI 辅助开发功能的核心入口 |
| 工具模块 | MCP 工具注册与执行 |
| 传输模块 | MCP 通信传输 |

**CMS 必要性分析**: MCP 主要用于 AI 辅助开发，非 CMS 核心功能。如果项目不需要 AI 开发辅助能力，可删除。

---

### 1.6 Plugins 插件系统
**目录**: `/workspace/src/plugins/`
**必要性**: ⚠️ 可选

| 子模块 | 功能概述 |
|--------|----------|
| 插件接口 | 插件标准化接口 |
| 插件管理器 | 插件注册、加载、生命周期管理 |
| 插件注册表 | 已安装插件注册 |

**CMS 必要性分析**: 插件系统提供 CMS 可扩展性。如果 CMS 需要灵活的功能扩展机制，保留；如果功能固定，可删除。

---

## 二、API 控制器层（功能模块）

### 2.1 系统管理模块 (System Management)
**目录**: `/workspace/src/api/controllers/`
**必要性**: ✅ CMS 核心

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 管理员 | system_admin.controller.zig | 管理员 CRUD、角色分配 | ✅ 必须 |
| 菜单 | system_menu.controller.zig | 菜单树、菜单导出 | ✅ 必须 |
| 角色 | system_role.controller.zig | 角色管理、权限分配 | ✅ 必须 |
| 部门 | system_dept.controller.zig | 部门树、部门 CRUD | ✅ 必须 |
| 配置 | system_config.controller.zig | 配置缓存刷新、导出导入 | ✅ 必须 |
| 字典 | system_dict.controller.zig | 字典 CRUD | ✅ 必须 |
| 字典项 | system_dict_item.controller.zig | 字典项 CRUD | ✅ 必须 |
| 设置 | setting.controller.zig | 系统设置获取/保存 | ✅ 必须 |
| 成员 | business_member.controller.zig | 业务成员管理 | ⚠️ 可选(电商) |
| 支付 | system_payment.controller.zig | 支付配置 | ❌ 非CMS |
| 版本 | system_version.controller.zig | 版本发布/升级 | ⚠️ 可选 |
| 运维任务 | operation_task.controller.zig | 运营任务管理 | ❌ 非CMS |

---

### 2.2 认证模块 (Authentication)
**目录**: `/workspace/src/api/controllers/`
**必要性**: ✅ CMS 核心

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 登录 | login.controller.zig | 登录/登出/用户信息 | ✅ 必须 |
| 公共 | public.controller.zig | 验证码、服务器时间等 | ✅ 必须 |
| OAuth | oauth.controller.zig | 第三方登录/授权 | ⚠️ 可选 |

---

### 2.3 CMS 内容管理模块
**后端对应控制器**: 当前 CMS 内容相关的控制器部分由 `dynamic.controller.zig`（动态API）和 `generic.controller.zig`（通用控制器）支撑，CMS 的领域实体（category, tag, media, template, model, seo, workflow）已有对应的仓储接口但可能没有独立的控制器文件。

| 子模块 | 仓储接口文件 | 前端页面 | CMS 必要性 |
|--------|-------------|----------|-------------|
| 内容管理 | - | views/cms/content/ | ✅ 核心 |
| 内容模型 | model_repository.zig | views/cms/model/ | ✅ 核心 |
| 内容分类 | category_repository.zig | views/cms/category/ | ✅ 核心 |
| 内容标签 | tag_repository.zig | views/cms/tag/ | ✅ 核心 |
| 媒体库 | media_repository.zig | views/cms/media/ | ✅ 核心 |
| 模板管理 | template_repository.zig | views/cms/template/ | ✅ 核心 |
| SEO 工具 | seo_repository.zig | views/cms/seo/ | ✅ 核心 |
| 工作流 | workflow_repository.zig | views/cms/workflow/ | ✅ 核心 |

---

### 2.4 质量中心模块 (Quality Center)
**目录**: `/workspace/src/api/controllers/quality_center/`, `/workspace/src/api/controllers/`
**必要性**: ❌ 非 CMS 必需

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 项目 | project.controller.zig | 项目 CRUD、归档、统计 | ❌ 测试管理 |
| 模块 | module.controller.zig | 模块树、拖拽移动 | ❌ 测试管理 |
| 需求 | requirement.controller.zig | 需求 CRUD、链接测试用例 | ❌ 测试管理 |
| 测试用例 | test_case.controller.zig | 测试用例 CRUD、批量操作、执行历史 | ❌ 测试管理 |
| 自动化测试 | auto_test.controller.zig | 测试报告上报、Bug分析 | ❌ 测试管理 |
| 质量中心 | quality_center.controller.zig | 统一API、报表、定时任务 | ❌ 测试管理 |
| 反馈 | feedback.controller.zig | 反馈 CRUD、跟进 | ❌ 测试管理 |
| 反馈评论 | quality_center/feedback_comment.controller.zig | 反馈评论管理 | ❌ 测试管理 |
| 质量报告 | quality_center/report.controller.zig | 质量报告生成 | ❌ 测试管理 |
| 关联追踪 | (前端路由 quality-center/traceability) | - | ❌ 测试管理 |
| 脑图分析 | (前端路由 quality-center/xmind) | - | ❌ 测试管理 |
| 定时报表 | (前端路由 quality-center/schedule-report) | - | ❌ 测试管理 |

---

### 2.5 安全模块 (Security)
**目录**: `/workspace/src/api/controllers/security/`
**必要性**: ⚠️ 审计日志部分保留，其余可删除

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 告警 | security/alert.controller.zig | 安全告警信息 | ❌ 非CMS |
| 告警规则 | security/alert_rule.controller.zig | 告警规则配置 | ❌ 非CMS |
| 审计日志 | security/audit_log.controller.zig | 安全操作日志记录 | ⚠️ 可选 |
| 黑名单 | security/blacklist.controller.zig | 安全黑名单管理 | ❌ 非CMS |
| 安全事件 | security/security_event.controller.zig | 安全事件记录查询 | ❌ 非CMS |
| 安全报告 | security/report.controller.zig | 安全报告 | ❌ 非CMS |

---

### 2.6 内容审核模块 (Moderation)
**目录**: `/workspace/src/api/controllers/moderation/`
**必要性**: ⚠️ 可选

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 内容审核 | moderation/moderation.controller.zig | 内容审核处理 | ⚠️ 可选 |
| 敏感词 | moderation/sensitive_word.controller.zig | 敏感词管理 | ⚠️ 可选 |
| 审核统计 | moderation/stats.controller.zig | 审核统计数据 | ⚠️ 可选 |

---

### 2.7 监控模块 (Monitoring)
**目录**: `/workspace/src/api/controllers/monitoring/`
**必要性**: ⚠️ 可选

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 性能监控 | monitoring/performance.controller.zig | 性能数据采集展示 | ⚠️ 可选 |

---

### 2.8 通用模块 (Common)
**目录**: `/workspace/src/api/controllers/`
**必要性**: ✅ CMS 核心

| 控制器 | 文件 | API 功能 | CMS 必要性 |
|--------|------|----------|-------------|
| 基础函数 | base.fn.zig | 通用工具函数 | ✅ 必须 |
| 通用 CRUD | crud.controller.zig | 基础增删改查 | ✅ 必须 |
| 通用控制器 | generic.controller.zig | 统一 RESTful 结构 | ✅ 必须 |
| 动态 API | dynamic.controller.zig | 动态路由和接口 | ✅ 必须 |
| 日志 | log.controller.zig | 操作/访问日志 | ✅ 必须 |
| 统计 | statistics.controller.zig | 统计数据接口 | ✅ 必须 |
| WebSocket | websocket.controller.zig | 实时通信 | ⚠️ 可选 |
| AI | ai.controller.zig | AI 接口 | ⚠️ 可选 |

---

### 2.9 DTO 层
**目录**: `/workspace/src/api/dto/`
**必要性**: ✅ CMS 核心依赖（数据传输对象，业务数据校验与序列化）

---

### 2.10 Middleware 中间件层
**目录**: `/workspace/src/api/middleware/`
**必要性**: ✅ CMS 核心依赖（认证、授权、日志、CORS 等）

---

## 三、前端模块

### 3.1 布局与框架
**必要性**: ✅ CMS 核心

| 组件 | 文件 | 功能 | CMS 必要性 |
|------|------|------|-------------|
| 根组件 | App.vue | 应用顶层容器 | ✅ 必须 |
| 默认布局 | layout/default-layout.vue | 导航栏、菜单、内容区、页脚 | ✅ 必须 |
| 入口 | main.ts | Vue 初始化、路由、状态管理 | ✅ 必须 |

---

### 3.2 路由配置
**必要性**: ✅ CMS 核心框架

| 路由文件 | 模块 | 路由数量 |
|----------|------|----------|
| router/index.ts | 主路由配置 + 路由守卫 | - |
| router/routes/index.ts | 路由汇总注册 | - |
| router/routes/modules/cms.ts | CMS 内容管理 | ~10 个路由 |
| router/routes/modules/business.ts | 业务管理（运营） | ~8 个路由 |
| router/routes/modules/quality-center.ts | 质量中心 | ~14 个路由 |
| router/routes/modules/system.ts | 系统管理 | ~25 个路由 |

---

### 3.3 状态管理 (Store)
**必要性**: ✅ CMS 核心

| 模块 | 文件 | 功能 | CMS 必要性 |
|------|------|------|-------------|
| app | store/modules/app/index.ts | 主题、菜单加载/转换 | ✅ 必须 |
| user | store/modules/user/index.ts | 用户信息、权限检查、登录/登出 | ✅ 必须 |
| tab-bar | store/modules/tab-bar/index.ts | 标签页管理 | ⚠️ 可选 |

---

### 3.4 CMS 模块 (前端页面)

**路由配置**: `router/routes/modules/cms.ts`

| 页面 | 路由路径 | 文件 | 功能 | CMS 必要性 |
|------|----------|------|------|-------------|
| CMS 首页 | /cms | views/cms/index.vue | CMS 仪表盘/概览 | ✅ 核心 |
| 内容管理 | /cms/content | views/cms/content/index.vue | 内容 CRUD | ✅ 核心 |
| 内容模型 | /cms/model | views/cms/model/index.vue | 内容类型/字段定义 | ✅ 核心 |
| 字段管理 | /cms/field | views/cms/field/ | 模型字段管理 | ✅ 核心 |
| 内容分类 | /cms/category | views/cms/category/index.vue | 分类树管理 | ✅ 核心 |
| 内容标签 | /cms/tag | views/cms/tag/index.vue | 标签管理 | ✅ 核心 |
| 媒体库 | /cms/media | views/cms/media/index.vue | 图片/文件管理 | ✅ 核心 |
| 模板管理 | /cms/template | views/cms/template/index.vue | 页面/内容模板 | ✅ 核心 |
| SEO 工具 | /cms/seo | views/cms/seo/index.vue | SEO 参数配置 | ✅ 核心 |
| 工作流 | /cms/workflow | views/cms/workflow/index.vue | 内容发布流程 | ✅ 核心 |

**CMS 必要性分析**: 以上是内容管理系统的核心功能，**全部必须保留**。

---

### 3.5 业务/运营模块 (前端页面)

**路由配置**: `router/routes/modules/business.ts`

| 页面 | 路由路径 | 文件 | 功能 | CMS 必要性 |
|------|----------|------|------|-------------|
| 数据概览 | /business/dashboard | views/business/dashboard/ | 业务数据总览 | ❌ 电商运营 |
| 会员管理 | /business/member | views/business/member/member.vue | 会员列表/详情 | ❌ 电商运营 |
| 订单管理 | /business/order | views/business/order/order.vue | 订单查询/处理 | ❌ 电商运营 |
| 工具箱 | /business/tool | views/business/tool/ | 运营工具集合 | ❌ 电商运营 |
| 优惠活动 | /business/coupon | views/business/coupon/ | 优惠券/活动管理 | ❌ 电商运营 |
| 机器管理 | /business/machine | views/business/machine/machine.vue | 设备管理 | ❌ 电商运营 |
| 收入管理 | /business/income | views/business/income/income.vue | 收入统计 | ❌ 电商运营 |
| 报表统计 | /business/report | views/business/report/ | 运营报表 | ❌ 电商运营 |

**CMS 必要性分析**: 业务模块属于电商运营系统功能，非 CMS 核心。如果项目定位为纯 CMS，**全部可删除**。

---

### 3.6 质量中心模块 (前端页面)

**路由配置**: `router/routes/modules/quality-center.ts`

| 页面 | 路由路径 | 文件 | 功能 | CMS 必要性 |
|------|----------|------|------|-------------|
| 质量总览 | /quality-center/dashboard | views/quality-center/dashboard/ | 质量指标仪表盘 | ❌ 测试管理 |
| 测试用例 | /quality-center/test-case | views/quality-center/test-case/ | 测试用例管理 | ❌ 测试管理 |
| 项目管理 | /quality-center/project | views/quality-center/project/ | 测试项目管理 | ❌ 测试管理 |
| 模块管理 | /quality-center/module | views/quality-center/module/ | 测试模块管理 | ❌ 测试管理 |
| 需求管理 | /quality-center/requirement | views/quality-center/requirement/ | 需求管理 | ❌ 测试管理 |
| 反馈管理 | /quality-center/feedback | views/quality-center/feedback/ | 用户反馈管理 | ❌ 测试管理 |
| 关联追踪 | /quality-center/traceability | views/quality-center/traceability/ | 需求-用例关联追踪 | ❌ 测试管理 |
| 定时报表 | /quality-center/schedule-report | views/quality-center/report/ | 定时报表配置 | ❌ 测试管理 |
| 脑图分析 | /quality-center/xmind | views/quality-center/xmind/ | 脑图可视化分析 | ❌ 测试管理 |
| 报表模板 | /quality-center/report-template | views/quality-center/report-template/ | 报表模板编辑器 | ❌ 测试管理 |
| 邮件模板 | /quality-center/mail-template | views/quality-center/mail-template/ | 邮件模板管理 | ❌ 测试管理 |
| 质量报表 | /quality-center/quality-report | views/quality-center/report/ | 质量报表查看 | ❌ 测试管理 |

**CMS 必要性分析**: 质量中心是测试/质量管理平台的功能模块，与 CMS 无关，**全部可删除**。

---

### 3.7 系统管理模块 (前端页面)

**路由配置**: `router/routes/modules/system.ts`

| 页面 | 路由路径 | 文件 | 功能 | CMS 必要性 |
|------|----------|------|------|-------------|
| 组织架构 | /system/organization | views/system/organization/ | 部门/公司架构 | ✅ 用户管理 |
| 成员管理 | /system/user-manage | views/system/user-manage/ | 管理员列表 | ✅ CMS核心 |
| 角色管理 | /system/role-manage | views/system/role-manage/ | 角色+权限配置 | ✅ CMS核心 |
| 字典管理 | /system/dict-manage | views/system/dict-manage/ | 数据字典维护 | ✅ CMS核心 |
| 职位管理 | /system/dept-position | views/system/dept-position/ | 职位设置 | ✅ CMS核心 |
| 操作记录 | /system/operation-log | views/system/operation-log/ | 操作日志查看 | ✅ CMS核心 |
| 菜单管理 | /system/menu-manage | views/system/menu-manage/ | 菜单配置 | ✅ CMS核心 |
| 配置管理 | /system/config-manage | views/system/config-manage/ | 系统参数配置 | ✅ CMS核心 |
| 支付配置 | /system/payment | views/system/payment/ | 支付方式配置 | ❌ 电商支付 |
| 版本管理 | /system/version | views/system/version/ | 系统版本管理 | ⚠️ 可选 |
| 通知中心 | /system/notification | views/system/notification/ | 消息通知 | ⚠️ 可选 |
| 报表中心 | /system/report-center | views/system/report-center/ | 管理报表 | ⚠️ 可选 |
| 操作审计 | /system/audit | views/system/audit/ | 安全审计 | ⚠️ 可选 |
| 页面配置 | /system/page-config | views/system/page-config/ | 页面动态配置 | ⚠️ 可选 |
| 低代码示例 | /system/low-code | views/system/low-code/ | 低代码演示页面 | ❌ Demo |
| 高级功能演示 | /system/advanced-demo | views/system/advanced-demo/ | 功能演示页面 | ❌ Demo |
| 完整功能演示 | /system/full-demo | views/system/full-demo/ | 完整功能演示 | ❌ Demo |
| 业务交互演示 | /system/business-demo | views/system/business-demo/ | 业务交互演示 | ❌ Demo |
| 低代码页面 | /system/low-code-page | views/system/low-code-page/ | 低代码页面 | ❌ Demo |

**CMS 必要性分析**: 组织架构、成员管理、角色管理、字典管理、菜单管理、配置管理是 CMS 的基础管理功能，**必须保留**。支付配置、版本管理、通知、审计可选。Demo 页面全部可删除。

---

### 3.8 前端 API 层
**目录**: `/workspace/ecom-admin/src/api/`
**必要性**: ✅ CMS 核心

| 文件 | 功能 |
|------|------|
| api.ts | API URL 常量定义（媒体账号列表等） |
| base.ts | API 请求函数实现（doReportedMenu, getMediaAccountList 等） |
| index.ts | API 统一导出入口 |

---

### 3.9 前端通用组件
**目录**: `/workspace/ecom-admin/src/components/`
**必要性**: ✅ CMS 核心依赖（通用 UI 组件复用）

### 3.10 前端工具与类型
**目录**: `/workspace/ecom-admin/src/utils/`, `/workspace/ecom-admin/src/types/`
**必要性**: ✅ CMS 核心依赖

---

## 四、CMS 必要性总结矩阵

### ✅ CMS 核心保留模块
| 模块 | 后端 | 前端 | 说明 |
|------|------|------|------|
| Core 核心层 | ✅ | - | DI、配置、工具、设计模式 |
| Application 应用层 | ✅ | - | 服务管理、缓存 |
| Domain 领域层(部分) | ✅ | - | Admin/User/Role/Menu/Dict/Setting/Upload/Category/Tag/Media/Template/Model/SEO/Workflow |
| Infrastructure | ✅ | - | 数据库、缓存 |
| 系统管理后端 | ✅ | - | 管理员/菜单/角色/部门/配置/字典 |
| 认证 | ✅ | - | 登录/公共API |
| 通用模块 | ✅ | - | 基础CRUD/日志/统计/动态API |
| DTO + Middleware | ✅ | - | 数据传输与中间件 |
| CMS 前端页面 | - | ✅ | 内容/模型/字段/分类/标签/媒体/模板/SEO/工作流 |
| 系统管理前端 | - | ✅(部分) | 成员/角色/组织/字典/菜单/配置/操作日志 |
| 布局/Store/路由 | - | ✅ | 框架级组件 |

### ⚠️ 可选保留模块
| 模块 | 说明 |
|------|------|
| OAuth 第三方登录 | 不需要第三方登录可删除 |
| MCP 模块 | 不需要 AI 辅助开发可删除 |
| Plugins 插件系统 | 不需要插件扩展机制可删除 |
| 内容审核 (Moderation) | 不需要内容审核功能可删除 |
| 性能监控 (Monitoring) | 不需要性能监控可删除 |
| 安全审计日志 | 不需要审计可删除 |
| WebSocket | 不需要实时推送可删除 |
| AI 接口 | 不需要 AI 能力可删除 |
| 版本管理 | 不需要版本发布功能可删除 |
| 通知中心 | 不需要站内通知可删除 |
| 标签页管理 (tab-bar store) | 不需要多标签页可删除 |

### ❌ 建议删除模块
| 模块 | 后端关联文件 | 前端关联文件 | 原因 |
|------|------------|------------|------|
| 业务/电商运营 | business_member.controller.zig 等 | router/routes/modules/business.ts, views/business/ 全部 | 电商运营功能，非 CMS |
| 质量中心 | project/requirement/feedback/test_case 等 15+ 控制器 | router/routes/modules/quality-center.ts, views/quality-center/ 全部 | 测试管理功能，非 CMS |
| 安全模块(除审计) | security/alert 等 6 控制器 | - | 安全告警功能，非 CMS |
| 支付配置 | system_payment.controller.zig | views/system/payment/ | 电商支付功能 |
| 运维任务 | operation_task.controller.zig | - | 运营任务管理 |
| Demo 页面 | - | views/system/low-code/, advanced-demo/, full-demo/, business-demo/ | 演示页面，非生产 |
| 业务会员 | biz_member 系列仓储和模型 | - | 电商会员体系 |

---

## 五、删除模块时的依赖关系注意

删除某个模块时需注意级联影响：

1. **Quality Center 删除** → 需同步删除：
   - 后端：project/requirement/feedback/test_case/auto_test/module/quality_center 控制器
   - 后端：domain/entities 中对应实体、repositories 对应仓储
   - 前端：router/routes/modules/quality-center.ts
   - 前端：views/quality-center/ 全部

2. **Business 删除** → 需同步删除：
   - 后端：business_member 控制器
   - 后端：biz_member 系列仓储和模型
   - 前端：router/routes/modules/business.ts
   - 前端：views/business/ 全部

3. **Security 删除** → 需同步删除：
   - 后端：security/ 目录下全部控制器（可保留 audit_log）
   - 前端：无直接前端页面（审计日志在系统管理中）

4. **Demo 页面删除** → 仅影响前端 views/system/ 下的演示页面和对应路由

5. **Moderation 删除** → 需同步删除 moderation/ 目录下全部控制器、sensitive_word 和 moderation_log 实体与仓储

6. **路由汇总文件** → 删除模块时需更新 router/routes/index.ts 和 bootstrap.zig 中的模块导入