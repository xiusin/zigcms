# Implementation Plan: ZigCMS 前后端知识文档生成系统

## Overview

本实现计划将 ZigCMS 前后端知识文档生成系统分解为可执行的开发任务。系统采用 Zig 语言实现，包含代码分析、文档生成、模板渲染和多格式输出功能。实现过程遵循增量开发原则，每个任务都构建在前一个任务的基础上，确保系统逐步完善且可测试。

## Tasks （本任务非开发性质）

- [ ] 1. 搭建项目基础架构
  - 创建项目目录结构（src/analyzer, src/generator, src/template, src/output）
  - 配置 build.zig 构建系统
  - 设置测试框架和 CI/CD 配置
  - 创建核心数据结构定义（Module, Layer, Dependency, Document）
  - _Requirements: 9.2_

- [ ] 2. 实现代码分析器核心功能
  - [ ] 2.1 实现 Zig 代码解析器
    - 使用 std.zig.parse 和 std.zig.Ast 解析 Zig 源文件
    - 提取模块名称、导出符号、导入依赖
    - 识别结构体、函数、常量定义
    - _Requirements: 1.1, 1.4_
  
  - [ ] 2.2 编写属性测试：架构层识别
    - **Property 1: Architecture Layer Recognition**
    - **Validates: Requirements 1.1**
    - 生成随机项目结构，验证五层架构识别
    - 100次迭代，确保识别准确性
  
  - [ ] 2.3 实现 TypeScript/Vue 代码解析器
    - 集成 TypeScript Compiler API 解析 TS 文件
    - 使用 @vue/compiler-sfc 解析 Vue 单文件组件
    - 提取组件、接口、类型定义
    - _Requirements: 4.1, 4.2_
  
  - [ ] 2.4 编写属性测试：前端技术栈识别
    - **Property 7: Frontend Technology Stack Recognition**
    - **Validates: Requirements 4.1**
    - 验证 Vue 3 + Pinia + Router + Arco Design 识别

- [ ] 3. 实现架构分析器
  - [ ] 3.1 实现层次识别算法
    - 根据目录结构识别 API、Application、Domain、Infrastructure、Shared 层
    - 分析模块归属和职责
    - _Requirements: 1.1_
  
  - [ ] 3.2 实现依赖关系分析
    - 分析模块间的导入/导出关系
    - 构建依赖图
    - 检测循环依赖和架构违规
    - _Requirements: 1.2, 1.3_
  
  - [ ] 3.3 编写属性测试：依赖可视化
    - **Property 3: Dependency Visualization**
    - **Validates: Requirements 1.3**
    - 验证生成的 Mermaid 图表包含所有依赖关系

- [ ] 4. 实现 ORM 和数据库驱动分析
  - [ ] 4.1 实现 ORM API 模式识别
    - 识别 QueryBuilder 链式方法（where, whereIn, whereRaw）
    - 提取参数化查询示例
    - 识别关系预加载（with 方法）
    - _Requirements: 2.1, 2.3_
  
  - [ ] 4.2 编写属性测试：API 模式识别
    - **Property 5: API Pattern Recognition**
    - **Validates: Requirements 2.1**
    - 验证识别所有 QueryBuilder 公共方法
  
  - [ ] 4.3 实现数据库驱动检测
    - 分析导入语句识别 MySQL、SQLite、PostgreSQL 驱动
    - 提取连接配置和连接池设置
    - _Requirements: 3.1, 3.4_
  
  - [ ] 4.4 编写属性测试：数据库驱动检测
    - **Property 6: Database Driver Detection**
    - **Validates: Requirements 3.1**
    - 验证正确识别所有数据库驱动类型

- [ ] 5. Checkpoint - 确保分析器功能完整
  - 运行所有分析器测试，确保通过
  - 验证能够正确分析 ZigCMS 和 ecom-admin 代码
  - 如有问题，询问用户并调整

- [ ] 6. 实现模板引擎
  - [ ] 6.1 实现 Mustache 模板解析器
    - 解析模板语法（变量、条件、循环）
    - 实现模板缓存机制
    - _Requirements: 9.1, 9.3_
  
  - [ ] 6.2 实现模板渲染器
    - 变量替换
    - 条件渲染（{{#if}}）
    - 循环渲染（{{#each}}）
    - _Requirements: 9.1_
  
  - [ ] 6.3 创建文档模板
    - 后端架构文档模板
    - ORM 使用文档模板
    - 前端架构文档模板
    - API 接口文档模板
    - _Requirements: 1.2, 2.2, 4.2, 6.2_

- [ ] 7. 实现文档生成器
  - [ ] 7.1 实现后端架构文档生成
    - 生成整洁架构五层说明
    - 生成 DI 容器使用文档
    - 包含代码示例和 Mermaid 图表
    - _Requirements: 1.2, 1.3, 1.4_
  
  - [ ] 7.2 编写属性测试：文档完整性
    - **Property 2: Documentation Completeness**
    - **Validates: Requirements 1.2, 2.2, 3.2, 4.2**
    - 验证生成的文档包含所有必需部分
  
  - [ ] 7.3 实现 ORM 文档生成
    - 生成 QueryBuilder 使用指南
    - 包含参数化查询示例
    - 说明关系预加载和内存管理
    - _Requirements: 2.2, 2.3, 2.4, 2.5_
  
  - [ ] 7.4 实现数据库驱动文档生成
    - 生成每种驱动的配置文档
    - 包含连接示例和测试指南
    - _Requirements: 3.2, 3.3, 3.5_
  
  - [ ] 7.5 实现前端架构文档生成
    - 生成 Vue 3 项目结构文档
    - 说明 Pinia 状态管理
    - 说明路由和权限控制
    - _Requirements: 4.2, 4.3, 4.4, 4.5_
  
  - [ ] 7.6 编写属性测试：代码示例语法有效性
    - **Property 4: Code Example Syntax Validity**
    - **Validates: Requirements 1.5**
    - 验证生成的 Zig/TypeScript 代码可编译

- [ ] 8. 实现 Mock 系统和接口文档生成
  - [ ] 8.1 实现 Mock 系统检测
    - 识别 Mock 数据文件（src/mock/*.ts）
    - 分析 Mock 切换机制
    - _Requirements: 5.1_
  
  - [ ] 8.2 编写属性测试：Mock 系统检测
    - **Property 8: Mock System Detection**
    - **Validates: Requirements 5.1**
    - 验证识别 Mock 文件和切换机制
  
  - [ ] 8.3 实现 RESTful API 文档生成
    - 识别 API 端点（路由、方法、参数）
    - 生成接口规范文档
    - 包含请求/响应示例
    - _Requirements: 6.1, 6.2, 6.5_
  
  - [ ] 8.4 编写属性测试：RESTful API 识别
    - **Property 9: RESTful API Pattern Recognition**
    - **Validates: Requirements 6.1**
    - 验证识别所有 API 端点信息

- [ ] 9. 实现认证授权文档生成
  - [ ] 9.1 实现认证机制检测
    - 识别 JWT 认证代码
    - 提取 Token 生成和验证逻辑
    - _Requirements: 7.1_
  
  - [ ] 9.2 编写属性测试：认证机制检测
    - **Property 10: Authentication Mechanism Detection**
    - **Validates: Requirements 7.1**
    - 验证识别 JWT 认证组件
  
  - [ ] 9.3 生成认证授权文档
    - 说明登录流程和 Token 管理
    - 说明权限模型（角色、菜单、按钮）
    - 包含前后端权限控制示例
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

- [ ] 10. Checkpoint - 确保文档生成功能完整
  - 运行所有文档生成测试，确保通过
  - 生成 ZigCMS 完整文档集，人工审查质量
  - 如有问题，询问用户并调整

- [ ] 11. 实现开发环境配置文档生成
  - [ ] 11.1 实现依赖提取
    - 从 build.zig.zon 提取 Zig 依赖
    - 从 package.json 提取 Node.js 依赖
    - 识别数据库依赖
    - _Requirements: 8.1_
  
  - [ ] 11.2 编写属性测试：依赖提取
    - **Property 11: Dependency Extraction**
    - **Validates: Requirements 8.1**
    - 验证提取所有依赖及版本信息
  
  - [ ] 11.3 生成环境配置文档
    - 生成安装步骤（Zig、Node.js、数据库）
    - 生成项目初始化命令
    - 列出环境变量说明
    - 包含故障排查指南
    - _Requirements: 8.2, 8.3, 8.4, 8.5_

- [ ] 12. 实现输出格式化和转换
  - [ ] 12.1 实现 Markdown 输出
    - 生成符合规范的 Markdown 文档
    - 包含语法高亮的代码块
    - 生成多级目录和锚点链接
    - _Requirements: 9.1, 9.3, 9.5_
  
  - [ ] 12.2 编写属性测试：输出格式有效性
    - **Property 12: Output Format Validity**
    - **Validates: Requirements 9.1, 9.3, 9.4**
    - 验证 Markdown 语法正确，可转换为 HTML/PDF
  
  - [ ] 12.3 实现 HTML 转换
    - 使用 markdown-it 转换 Markdown 到 HTML
    - 应用样式和主题
    - _Requirements: 10.5_
  
  - [ ] 12.4 实现 PDF 转换
    - 使用 puppeteer 或 wkhtmltopdf 生成 PDF
    - 保持格式和样式
    - _Requirements: 10.5_

- [ ] 13. 实现文档组织和元数据管理
  - [ ] 13.1 实现文档分类
    - 按照后端、前端、接口、开发指南分类
    - 生成主索引文档
    - _Requirements: 9.2_
  
  - [ ] 13.2 编写属性测试：文档结构一致性
    - **Property 13: Documentation Structure Consistency**
    - **Validates: Requirements 9.2, 9.5**
    - 验证文档分类和目录结构
  
  - [ ] 13.3 实现元数据管理
    - 为每个文档添加生成时间、版本、作者信息
    - 实现文档版本控制
    - _Requirements: 10.2_
  
  - [ ] 13.4 编写属性测试：元数据包含
    - **Property 15: Metadata Inclusion**
    - **Validates: Requirements 10.2**
    - 验证所有文档包含完整元数据

- [ ] 14. 实现文档更新和维护功能
  - [ ] 14.1 实现增量生成
    - 使用文件哈希检测代码变化
    - 只重新生成变化的文档
    - _Requirements: 10.1_
  
  - [ ] 14.2 编写属性测试：文档再生成幂等性
    - **Property 14: Documentation Regeneration Idempotency**
    - **Validates: Requirements 10.1**
    - 验证未变化代码生成相同文档
  
  - [ ] 14.3 实现过时内容检测
    - 比较代码和文档，检测不一致
    - 在文档中添加警告标记
    - _Requirements: 10.3_
  
  - [ ] 14.4 实现手动编辑保留
    - 识别手动编辑的文档部分
    - 在重新生成时保留手动内容
    - _Requirements: 10.4_

- [ ] 15. 实现命令行工具
  - [ ] 15.1 创建 CLI 入口
    - 解析命令行参数（--source, --output, --type, --template）
    - 实现帮助信息和版本显示
  
  - [ ] 15.2 集成所有组件
    - 连接分析器、生成器、模板引擎、输出管理器
    - 实现完整的文档生成流程
  
  - [ ] 15.3 实现进度显示
    - 显示分析进度
    - 显示生成进度
    - 显示错误和警告

- [ ] 16. 编写边界情况测试
  - [ ] 16.1 编写属性测试：空代码库处理
    - **Property 16: Empty Codebase Handling**
    - **Validates: Requirements 1.1, 3.1, 4.1 (edge case)**
    - 验证空项目生成有效文档和警告
  
  - [ ] 16.2 编写属性测试：混合语言处理
    - **Property 17: Mixed Language Handling**
    - **Validates: Requirements 1.1, 4.1 (edge case)**
    - 验证多语言项目正确分析和文档生成

- [ ] 17. 集成测试和文档验证
  - [ ] 17.1 运行完整测试套件
    - 运行所有单元测试
    - 运行所有属性测试（17个属性，每个100次迭代）
    - 确保测试覆盖率 > 85%
  
  - [ ] 17.2 生成 ZigCMS 完整文档
    - 对 ZigCMS 后端和 ecom-admin 前端运行文档生成器
    - 生成 Markdown、HTML、PDF 格式
    - 人工审查文档质量和完整性
  
  - [ ] 17.3 性能测试
    - 测试大型代码库的分析性能
    - 优化内存使用和生成速度

- [ ] 18. 最终 Checkpoint - 确保所有功能正常
  - 所有测试通过（单元测试 + 属性测试）
  - 文档生成完整且格式正确
  - 命令行工具可用且稳定
  - 询问用户是否满意，如有问题进行调整

## Notes

- 所有测试任务都是必需的，确保系统质量和正确性
- 每个任务都引用了具体的需求编号，确保可追溯性
- Checkpoint 任务确保增量验证，及时发现问题
- 属性测试每个运行 100 次迭代，确保全面覆盖
- 单元测试验证具体功能，属性测试验证通用正确性
- 实现语言：Zig（与 ZigCMS 后端保持一致）
