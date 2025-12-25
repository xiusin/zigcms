# ZigCMS 架构优化与工程化方案 (TODO)

本计划旨在通过工程化手段优化 ZigCMS 架构，引入完善的依赖注入机制，并确保内存释放的优雅与安全。

## 第一阶段：架构与依赖注入 (核心)
- [x] **分析 `shared/di` 与 `root.zig`**：深入理解现有的服务管理和 DI 容器实现。
- [x] **重构 DI 容器**：确保容器支持单例 (Singleton) 和瞬态 (Transient) 注册，并提供健壮的依赖解析能力。
- [x] **Bootstrap 深度集成**：更新 `api/bootstrap.zig`，使用 DI 容器自动解析控制器和服务，减少手动初始化代码。
- [x] **接口契约标准化**：确保 `application/services` 下的所有服务都遵循清晰的接口规范（vtable 模式），以便于 Mock 测试和依赖注入。

## 第二阶段：内存管理与安全审计
- [x] **内存安全审计**：对 `UserService`、`LoginController` 等核心业务代码进行深度审计，确保手动内存管理正确，排除重复释放 (Double Free) 和内存泄漏。
- [x] **RAII 模式强化**：确保所有资源结构体都实现了 `deinit` 方法，并在使用处正确调用 `defer`。
- [x] **局部 Arena 优化 (可选)**：仅在涉及大量临时分配的复杂逻辑块（如复杂 JSON 解析）中使用局部 `ArenaAllocator`，不改变全局分配策略。

## 第三阶段：MVC 与主程序清理
- [x] **`main.zig` 瘦身**：确保 `main.zig` 仅包含最基础的内存初始化、配置加载和启动命令，将业务初始化逻辑完全移至 `bootstrap`。
- [x] **控制器职责细化**：通过重构 `LoginController` 并引入 `AuthService`，确保控制器层只处理 HTTP 逻辑，业务逻辑已下沉到 Service 层。
- [x] **目录规范化**：将所有应用服务移至 `application/services`，符合整洁架构规范。

## 第四阶段：ORM 与 QueryBuilder (Laravel 风格)
- [x] **语法糖增强**：优化 QueryBuilder，支持像 Laravel 相同的链式调用（例如：`User.where(...).update(...)`, `User.firstOrFail()`）。
- [x] **模型定义简化**：添加了 `FindOrFail`, `FirstOrFail`, `When` 等静态方法，减少冗余代码。
- [x] **字段提取与增减**：实现了 `value()`, `increment()`, `decrement()` 等便捷操作。

## 第五阶段：统一缓存与配置加载
- [x] **统一缓存契约**：在 `application/services/cache/contract.zig` 中定义了统一的 `CacheInterface`，并重构了基础设施驱动。
- [x] **类型化配置 (SystemConfig)**：优化了 `ConfigLoader` 和 `root.zig` 的加载逻辑，实现了从 `configs/*.json` 到结构体的自动映射，移除了冗余的手动覆盖逻辑。
- [x] **驱动无感切换**：确保系统支持内存和 Redis 驱动的无缝互换。

## 第六阶段：命令行工具与脚本优化
- [x] **CLI 工具重组**：将 `codegen`, `migrate`, `plugin_gen`, `config_gen` 移入各自的职责子目录，结构更加清晰。
- [x] **`codegen` 逻辑解耦**：将生成逻辑拆分为 `main.zig` 和 `generators.zig`，提升了代码的可维护性。
- [x] **构建配置更新**：同步更新了 `build.zig` 的构建步骤，确保命令路径正确。
- [x] **脚本系统验证**：审计了 `scripts/` 下的 shell 脚本，确认其已实现高度模块化与工程化。

## 第七阶段：质量保证与文档 (完成)
- [x] **全量编译测试**：在 Zig 0.15.2 下完成 `zig build` 和 `zig build test` 验证，系统稳定。
- [x] **文档注释加固**：为核心组件、ORM 语法糖、DI 容器等添加了丰富的注释。
- [x] **架构闭环检查**：确认项目已完全符合整洁架构、工程化和内存安全的高级标准。

---
**重构完成！ZigCMS 现在拥有了一个优雅、现代且高度工程化的核心。**