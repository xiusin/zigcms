# ZigCMS - 优化后的项目结构

## 概述
ZigCMS 项目已经重构为整洁架构（Clean Architecture）模式，提高代码组织性和可维护性。项目采用现代化的 Zig 项目结构，使用 `mod.zig` 约定实现模块化。

## 新的目录结构
```
zigcms/
├── api/                    # API 层 - 处理 HTTP 请求和响应
│   ├── controllers/       # HTTP 控制器 (仅处理协议逻辑)
│   ├── dto/               # 数据传输对象 (Request/Response)
│   └── middleware/        # HTTP 中间件
├── application/           # 应用层 - 协调业务流程
│   ├── services/          # 应用服务 (包含所有业务逻辑，如 AuthService, UserService)
│   ├── usecases/          # 业务用例
│   └── mod.zig            # 应用层入口
├── domain/                # 领域层 - 核心业务模型 (内层，无外部依赖)
│   ├── entities/          # 业务实体 (包含 RAII 内存管理)
│   └── repositories/      # 仓库接口契约
├── infrastructure/        # 基础设施层 - 外部实现
│   ├── database/          # 数据库仓储实现 (Sqlite, MySQL)
│   ├── cache/             # 缓存实现 (标准化 CacheInterface 驱动)
│   └── http/              # HTTP 客户端实现
├── shared/                # 共享层 - 通用基础设施
│   ├── di/                # 依赖注入系统 (Arena 托管模式)
│   ├── config/            # 类型化配置加载器
│   └── utils/             # 通用工具函数 (JWT, Strings)
├── commands/              # 命令行工具集 (职责子目录化)
│   ├── codegen/           # 代码生成 (拆分为 main 和 generators)
│   ├── migrate/           # 数据库迁移管理
│   ├── plugin_gen/        # 插件脚手架生成
│   └── config_gen/        # 配置结构自动生成
├── main.zig              # 程序入口 (Compose Root，保持极简)
├── root.zig              # 库根模块 (自动装配各层配置)
└── build.zig             # 构建系统 (模块化命令管理)
```

## 架构说明

### 1. API 层 (api/)
- **职责**: 处理 HTTP 请求和响应，验证请求参数，返回响应
- **包含**: 控制器、DTO、中间件
- **依赖**: 仅依赖 Application 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("api/controllers")` 简洁导入

### 2. 应用层 (application/)
- **职责**: 协调业务流程，处理用例逻辑，事务管理
- **包含**: 应用服务、业务用例
- **依赖**: 仅依赖 Domain 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("application")` 简洁导入

### 3. 领域层 (domain/)
- **职责**: 包含核心业务逻辑和规则，业务实体和值对象
- **包含**: 实体、值对象、领域服务、仓库接口
- **依赖**: 无外部依赖（最内层）
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("domain")` 简洁导入

### 4. 基础设施层 (infrastructure/)
- **职责**: 实现外部服务接口（数据库、缓存、HTTP 客户端等）
- **包含**: 数据库实现、缓存实现、HTTP 客户端实现
- **依赖**: 仅依赖 Domain 层
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("infrastructure")` 简洁导入

### 5. 共享层 (shared/)
- **职责**: 提供跨层共享的工具和原语
- **包含**: 通用工具、基础原语、通用类型
- **依赖**: 无外部依赖
- **模块化**: 使用 `mod.zig` 模块入口，支持 `@import("shared")` 简洁导入

## 模块化改进

### 1. 使用 `mod.zig` 约定
所有主要模块（如 `api/controllers`, `api/dto`, `api/middleware`, `application`, `domain`, `infrastructure`, `shared`）都使用 `mod.zig` 作为模块入口文件。

### 2. 简洁的导入方式
支持以下导入方式：
- `@import("api/controllers")` - 在同一目录层级
- `@import("api/controllers/mod.zig")` - 在不同层级或根目录
- `@import("domain")` - 领域层入口
- `@import("application")` - 应用层入口

### 3. 分组和命名空间组织
- **控制器分组**: `controllers.auth.Login`, `controllers.admin.Menu`, `controllers.common.Crud`
- **DTO 分组**: `dtos.user.Login`, `dtos.menu.Save`, `dtos.common.Page`
- **中间件分组**: `middleware.authMiddleware`, `middleware.logMiddleware`

## 主要改进

1. **职责分离**: 每层都有明确的职责，代码更加模块化
2. **依赖规则**: 严格遵循依赖规则，外层依赖内层，内层不依赖外层
3. **可测试性**: 各层可以独立测试，提高代码质量
4. **可维护性**: 代码组织更清晰，便于长期维护
5. **可扩展性**: 新功能可以更容易地添加到合适的位置
6. **模块化**: 遵循 Zig `mod.zig` 约定，支持简洁的导入方式
7. **命名空间组织**: 按功能分组组织代码，提高可读性

## 构建和运行

构建项目:
```bash
zig build
```

运行开发服务器:
```bash
zig build run
```

## 文件路径更新

- 原 `src/controllers/` → `api/controllers/`
- 原 `src/dto/` → `api/dto/`
- 原 `src/middlewares/` → `api/middleware/`
- 原 `src/models/` → `domain/entities/`
- 原 `src/services/` → `application/services/`
- 原 `src/modules/` → `shared/utils/`
- 原 `src/global/` → `shared/primitives/`

所有导入路径已在主要文件中更新以匹配新的结构。

## 模块入口文件更新

- `api/controllers/controllers.zig` → `api/controllers/mod.zig`
- `api/dto/dtos.zig` → `api/dto/mod.zig`
- `api/middleware/middlewares.zig` → `api/middleware/mod.zig`
- `domain/Domain.zig` → `domain/mod.zig`
- `application/Application.zig` → `application/mod.zig`
- `infrastructure/Infrastructure.zig` → `infrastructure/mod.zig`
- `shared/Shared.zig` → `shared/mod.zig`

这些改进使项目结构更加现代化、模块化和易于维护。