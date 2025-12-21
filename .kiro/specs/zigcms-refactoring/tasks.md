# Implementation Plan: ZigCMS 全面优化重构

## Overview

本实现计划将 ZigCMS 项目的优化重构分解为 11 个主要步骤，每个步骤完成后进行 Git 提交。实现遵循 Zig 语言的内存安全最佳实践，确保代码优雅、可维护。

## Tasks

- [x] 1. 内存安全分析与优化
  - [x] 1.1 审查 ServiceManager 的资源所有权和释放顺序
    - 检查 init/deinit 配对
    - 确保 errdefer 正确使用
    - _Requirements: 1.1, 1.2_
  - [x] 1.2 审查 Database 连接池的生命周期管理
    - 检查连接获取和释放
    - 确保池化连接正确清理
    - _Requirements: 1.5_
  - [x] 1.3 审查 ORM 查询结果的内存所有权
    - 检查 mapResults 函数
    - 确保 freeModel/freeModels 正确实现
    - _Requirements: 1.6, 1.7_
  - [x] 1.4 审查 global.zig 的初始化和清理逻辑
    - 检查单例模式实现
    - 确保 deinit 按正确顺序清理
    - _Requirements: 1.2_
  - [ ]* 1.5 编写内存安全属性测试
    - **Property 1: Memory Lifecycle Consistency**
    - **Validates: Requirements 1.1, 1.2, 1.7**

- [x] 2. Main.zig 结构优化
  - [x] 2.1 创建 Bootstrap 模块 (api/bootstrap.zig)
    - 提取系统初始化逻辑
    - 提取路由注册逻辑
    - _Requirements: 2.1, 2.3_
  - [x] 2.2 重构 main.zig 使用 Bootstrap
    - 简化 main 函数
    - 保持职责清晰
    - _Requirements: 2.2, 2.5_
  - [x] 2.3 添加启动日志摘要
    - 显示配置信息
    - 显示注册的路由数量
    - _Requirements: 2.6_


- [x] 3. 项目结构工程化
  - [x] 3.1 整理各层 mod.zig 导出
    - 确保公共 API 清晰
    - 添加模块文档注释
    - _Requirements: 3.2_
  - [x] 3.2 验证层间依赖关系
    - 确保 shared 层不依赖业务层
    - 检查循环依赖
    - _Requirements: 3.3_
  - [x] 3.3 更新 build.zig 支持库构建
    - 添加库构建目标
    - 配置公共模块导出
    - _Requirements: 3.4_

- [x] 4. ORM/QueryBuilder 语法糖优化
  - [x] 4.1 实现 Model.use(db) 默认连接功能
    - 添加静态 default_db 变量
    - 实现 use/getDb/hasDb 方法
    - _Requirements: 4.2, 4.3_
  - [x] 4.2 实现 Laravel 风格的静态查询方法
    - 实现 Model.where() 无需传 db
    - 实现 Model.find(id) 语法
    - 实现 Model.all() 语法
    - _Requirements: 4.1, 4.6_
  - [x] 4.3 实现 Model.create(data) 语法
    - 支持结构体字面量创建
    - 返回创建的模型实例
    - _Requirements: 4.5_
  - [x] 4.4 完善 Model.List 自动内存管理
    - 实现 collect() 方法
    - 实现 List.deinit() 自动清理
    - _Requirements: 4.8_
  - [x] 4.5 编写 ORM 属性测试
    - **Property 3: QueryBuilder Fluent Chaining**
    - **Property 4: Model CRUD Operations**
    - **Property 5: Model Memory Cleanup**
    - **Validates: Requirements 4.1, 4.5, 4.6, 4.8**

- [x] 5. 缓存服务统一契约
  - [x] 5.1 完善 CacheInterface 接口定义
    - 确保所有方法都有定义
    - 添加接口文档注释
    - _Requirements: 5.1_
  - [x] 5.2 实现 TypedCache 泛型缓存
    - 支持 JSON 序列化/反序列化
    - 类型安全的存取操作
    - _Requirements: 5.5_
  - [x] 5.3 确保线程安全
    - 检查 mutex 使用
    - 验证并发访问安全
    - _Requirements: 5.7_
  - [ ]* 5.4 编写缓存属性测试
    - **Property 6: Cache Contract Conformance**
    - **Property 7: Cache TTL Behavior**
    - **Property 8: Cache Typed Operations**
    - **Property 9: Cache Thread Safety**
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.7**

- [x] 6. 命令行工具优化
  - [x] 6.1 创建 commands/ 目录结构
    - 创建 commands/mod.zig
    - 创建 commands/base.zig 命令基类
    - _Requirements: 6.1_
  - [x] 6.2 重构 codegen 命令
    - 移动到 commands/codegen.zig
    - 添加 --help 支持
    - 完善模板生成
    - _Requirements: 6.2, 6.3_
  - [x] 6.3 重构 migrate 命令
    - 移动到 commands/migrate.zig
    - 支持 up/down/status/create
    - _Requirements: 6.4_
  - [x] 6.4 重构 plugin-gen 命令
    - 移动到 commands/plugin_gen.zig
    - 添加 --help 支持
    - _Requirements: 6.5_
  - [x] 6.5 重构 config-gen 命令
    - 移动到 commands/config_gen.zig
    - 添加 --help 支持
    - _Requirements: 6.6_
  - [x] 6.6 更新 build.zig 注册命令
    - 注册所有命令为构建目标
    - _Requirements: 6.8_

- [x] 7. Checkpoint - 确保前6步测试通过
  - 运行 `zig build test` 确保所有测试通过
  - 如有问题，询问用户

- [x] 8. 配置加载优化
  - [x] 8.1 实现 ConfigLoader 模块
    - 创建 shared/config/config_loader.zig
    - 实现 TOML 文件解析
    - _Requirements: 7.1_
  - [x] 8.2 定义 SystemConfig 结构体
    - 创建 shared/config/system_config.zig
    - 定义 ApiConfig, AppConfig, DomainConfig, InfraConfig
    - 文件名对应结构体名
    - _Requirements: 7.2_
  - [x] 8.3 实现默认值和验证
    - 缺失配置文件使用默认值
    - 无效值返回描述性错误
    - _Requirements: 7.3, 7.4_
  - [x] 8.4 实现环境变量覆盖
    - 敏感值支持环境变量覆盖
    - _Requirements: 7.5_
  - [x] 8.5 启动时验证配置
    - 验证所有必需字段
    - _Requirements: 7.6_
  - [ ]* 8.6 编写配置属性测试
    - **Property 10: Config TOML Parsing**
    - **Property 11: Config Environment Override**
    - **Validates: Requirements 7.1, 7.5**

- [x] 9. 脚本优化
  - [x] 9.1 优化 common.sh 共享工具
    - 统一颜色输出函数
    - 统一错误处理函数
    - _Requirements: 8.2_
  - [x] 9.2 优化 build.sh
    - 支持 debug, release, fast, small, clean, cross 模式
    - 清晰的帮助信息
    - _Requirements: 8.3_
  - [x] 9.3 优化 dev.sh
    - 支持文件监视热重载 (fswatch)
    - _Requirements: 8.4_
  - [x] 9.4 优化 test.sh
    - 运行单元测试和集成测试
    - 报告覆盖率
    - _Requirements: 8.5_
  - [x] 9.5 确保脚本 POSIX 兼容
    - 在 macOS 和 Linux 上测试
    - 清晰的错误信息和退出码
    - _Requirements: 8.6, 8.7_

- [x] 10. 编译测试与覆盖
  - [x] 10.1 运行完整测试套件
    - 执行 `zig build test`
    - 确保所有单元测试通过
    - _Requirements: 9.1_
  - [x] 10.2 运行集成测试
    - 测试数据库操作
    - 测试 API 端点
    - _Requirements: 9.2_
  - [x] 10.3 验证内存安全
    - 使用 GPA 检测泄漏
    - 测试失败时报告详细信息
    - _Requirements: 9.6_
  - [x] 10.4 验证测试覆盖率
    - 核心模块达到 80% 覆盖率
    - _Requirements: 9.7_

- [x] 11. 代码注释规范
  - [x] 11.1 添加模块级文档注释
    - 每个源文件开头添加 `//!` 模块说明
    - _Requirements: 10.1_
  - [x] 11.2 添加公共函数文档
    - 所有 pub fn 添加 `///` 文档注释
    - 复杂函数添加参数说明
    - _Requirements: 10.2, 10.3_
  - [x] 11.3 添加错误条件文档
    - 可能返回错误的函数说明错误条件
    - _Requirements: 10.4_
  - [x] 11.4 添加复杂逻辑内联注释
    - 算法和复杂逻辑添加解释
    - _Requirements: 10.6_

- [x] 12. Final Checkpoint - 最终验证
  - 运行所有测试确保通过
  - 验证无内存泄漏
  - 确认所有功能正常工作
  - 如有问题，询问用户

## Notes

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 开发
- 每个任务引用具体需求以便追溯
- Checkpoint 任务用于增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
- 每个步骤完成后需要进行 Git 提交（中文提交信息，不 push/reset）
- 提交信息格式：`步骤N: 具体完成内容描述`
